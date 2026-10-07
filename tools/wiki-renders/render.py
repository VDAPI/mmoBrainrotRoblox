"""Wiki renders of monsters, bosses and pets (S38). Usually run through `npm run renders` in wiki/.

py -3 tools/wiki-renders/render.py --looks tools/wiki-renders/out/looks.json --out wiki/public/img/mobs
    --manifest tools/wiki-renders/manifest.json [--only id1,id2] [--force] [--sheet] [--og] [--og-boss id] [--jobs N]

Looks come from `lune run tools/lookdump.luau --wiki <looks.json>`. A look whose hash (entry + override +
RENDERER_VERSION + sizes) matches the manifest and whose files exist is skipped.
"""
import argparse
import json
import multiprocessing
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from vwrender import RENDERER_VERSION, manifest, post, scene  # noqa: E402

SUPERSAMPLE = 2
FULL, THUMB, HERO = 512, 128, 1024
SIZES = {"full": FULL, "thumb": THUMB, "hero": HERO, "supersample": SUPERSAMPLE}
BUDGET_FULL = 60 * 1024
BUDGET_THUMB = 8 * 1024
BUDGET_FOLDER = 10 * 1024 * 1024


def outputs_of(entry):
    f = entry["file"]
    names = [f"{f}.webp", f"{f}-128.webp"]
    if entry["kind"] == "boss":
        names.append(f"{f}-1024.webp")
        for ph in entry.get("phases") or []:
            names.append(f"{f}-p{ph['phase']}.webp")
    return names


def render_one(job):
    """Worker: renders every output of one look; returns (file, {name: bytes}, warnings)."""
    entry, override, out_dir = job
    warnings = []

    def warn(text):
        warnings.append(f"{entry['file']}: {text}")

    files = {}
    big = HERO if entry["kind"] == "boss" else FULL
    img = post.to_image(scene.render(entry, big * SUPERSAMPLE, override, warn=warn))
    full = post.downscale(img, FULL)
    files[f"{entry['file']}.webp"] = post.webp_bytes(full, 86)
    files[f"{entry['file']}-128.webp"] = post.webp_bytes(post.downscale(full, THUMB), 80)
    if entry["kind"] == "boss":
        files[f"{entry['file']}-1024.webp"] = post.webp_bytes(post.downscale(img, HERO), 86)
        for ph in entry.get("phases") or []:
            pieces = scene.tinted(entry["pieces"], ph)
            pimg = post.to_image(scene.render(entry, FULL * SUPERSAMPLE, override, pieces=pieces, warn=warn))
            files[f"{entry['file']}-p{ph['phase']}.webp"] = post.webp_bytes(post.downscale(pimg, FULL), 86)
    for name, data in files.items():
        (Path(out_dir) / name).write_bytes(data)
        limit = BUDGET_THUMB if name.endswith("-128.webp") else BUDGET_FULL if not name.endswith("-1024.webp") else None
        if limit and len(data) > limit:
            warnings.append(f"{name}: {len(data) // 1024} KB > {limit // 1024} KB")
    return entry["file"], {n: len(d) for n, d in files.items()}, warnings


def main():
    ap = argparse.ArgumentParser(description="Vaelthorn wiki renders")
    ap.add_argument("--looks", default="tools/wiki-renders/out/looks.json")
    ap.add_argument("--out", default="wiki/public/img/mobs")
    ap.add_argument("--manifest", default="tools/wiki-renders/manifest.json")
    ap.add_argument("--overrides", default=str(HERE / "overrides.json"))
    ap.add_argument("--only", default="", help="comma separated ids or files")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--sheet", action="store_true", help="write tools/wiki-renders/out/contact.png")
    ap.add_argument("--og", action="store_true", help="write wiki/public/img/og/base.png and default-art.png")
    ap.add_argument("--og-boss", default="", help="boss of the home page hero (default: highest level)")
    ap.add_argument("--jobs", type=int, default=max(1, min(8, (os.cpu_count() or 2) - 1)))
    args = ap.parse_args()

    post.check_webp()
    looks = json.loads(Path(args.looks).read_text(encoding="utf-8"))
    entries = looks["looks"]
    overrides = json.loads(Path(args.overrides).read_text(encoding="utf-8")) if Path(args.overrides).is_file() else {}
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    old = manifest.load(args.manifest)
    only = {s.strip() for s in args.only.split(",") if s.strip()}

    files = {}
    jobs = []
    skipped = 0
    for e in entries:
        o = overrides.get(e["file"])
        h = manifest.entry_hash(e, o, SIZES)
        names = outputs_of(e)
        record = {"hash": h, "id": e["id"], "kind": e["kind"], "variant": e["variant"], "asset": e["asset"],
                  "outputs": names, "bytes": 0}
        prev = old.get("files", {}).get(e["file"])
        selected = not only or e["id"] in only or e["file"] in only
        if not selected and not prev:
            continue  # never rendered and not asked for: stays out of the manifest
        exists = all((out_dir / n).is_file() for n in names)
        if selected and (args.force or not prev or prev.get("hash") != h or not exists):
            jobs.append((e, o, str(out_dir)))
        else:
            skipped += 1
            if prev:
                record = dict(prev)
                if not selected and prev.get("hash") != h:
                    record["hash"] = prev.get("hash")  # still stale: a later full run renders it
        files[e["file"]] = record

    removed = 0
    if not only:
        for f in manifest.orphans(old, files):
            removed += manifest.remove_outputs(out_dir, old["files"][f])

    start = time.time()
    warnings = []
    done = 0
    if jobs:
        results = map(render_one, jobs) if args.jobs <= 1 or len(jobs) == 1 else None
        if results is None:
            with multiprocessing.Pool(args.jobs) as pool:
                results = list(pool.imap_unordered(render_one, jobs))
        for file, sizes, warn in results:
            files[file]["bytes"] = sum(sizes.values())
            warnings += warn
            done += 1
            print(f"  {file} ({files[file]['bytes'] // 1024} KB)", flush=True)

    manifest.save(args.manifest, {"rendererVersion": RENDERER_VERSION, "files": dict(sorted(files.items()))})
    total = manifest.folder_bytes(out_dir)
    for w in warnings:
        print("UWAGA (warning):", w)
    print(f"wyrenderowano {done}, pominięto {skipped}, usunięto {removed} "
          f"(rendered {done}, skipped {skipped}, removed {removed}) w {time.time() - start:.1f} s; "
          f"folder {total / 1024 / 1024:.2f} MB")
    if total > BUDGET_FOLDER:
        print(f"UWAGA (warning): {out_dir} > {BUDGET_FOLDER // 1024 // 1024} MB")

    if args.sheet:
        from vwrender import sheet
        path = sheet.build(entries, out_dir, HERE / "out" / "contact.png")
        print("arkusz kontrolny (contact sheet):", path)
    if args.og:
        from vwrender import og
        bosses = [e for e in entries if e["kind"] == "boss"]
        boss = next((b for b in bosses if b["id"] == args.og_boss), None)
        if boss is None and bosses:
            boss = max(bosses, key=lambda b: (b["scale"], b["id"]))
        og_dir = out_dir.parent / "og"
        print("og:", ", ".join(str(p) for p in og.build(og_dir, out_dir, boss)))


if __name__ == "__main__":
    main()
