# Copies the owner's item pictures from his Graphics folder (PORADNIK-GRAFIKA.md layout, S52) into art/icons/src as
# finished 128 px cells (crop to the picture, 6% margin, Lanczos, light sharpening: import_png.cells_of), so the repo
# keeps small sources and never the 1024 px originals. Then run import_png.py to pack them.
#   py -3 tools/icons/import_graphics.py [--src <Graphics>] [--dry-run] [--prune] [--key FF00FF] [--ids ids.json]
#                                        [--report] [--selftest]
# S118: every name is checked against the game (tools/icons/ids.luau: Items.byId, quest objective items, blessing
# lines); a picture without an item is rejected with the closest id as a hint and never copied. Quest items
# (tylko_2d/questy/quest_<item>.png) become "quest/<item>". A report (groups, coverage per map, rejected files, the
# folders left for the UI session S119) goes to the screen and to build/icons/import_graphics.md.
# The Graphics folder is read only: nothing is ever written there.
import argparse
import difflib
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image, ImageDraw  # noqa: E402

import content_block  # noqa: E402
import import_png  # noqa: E402

DEFAULT_SRC = "D:/Users/vdapi/Downloads/Graphics"
TIERED = re.compile(r"^([a-z0-9_]+?)_(\d+)$")
# Copies and test files the owner keeps next to the real picture (never a key of their own).
COPY = re.compile(r"(\s*\(\d+\)|_v\d+|_wersja\d*|[-_ ]kopia\d*|[-_ ]copy\d*)$", re.IGNORECASE)
# tylko_2d/<folder> -> group of a per-item key "<group>/<file name>".
ITEM_FOLDERS = {
    "materialy": "mat",
    "mikstury": "pot",
    "zwoje": "misc",
    "kamienie": "misc",
    "plecaki": "misc",
    "narzedzia": "tool",
    "unikaty": "uniq",
}
# Item folders in scan order (report order too).
FOLDER_ORDER = ["ekwipunek", "unikaty", "materialy", "questy", "mikstury", "blogoslawienstwa", "zwoje", "kamienie",
                "plecaki", "narzedzia"]
# Report groups of tools/icons/ids.luau and the art group of their own picture.
REPORT_GROUPS = ["weapon", "offhand", "armor", "jewelry", "unique", "material", "potion", "elixir", "blessing",
                 "scroll", "stone", "backpack", "tool", "quest"]
MAPS = [(1, 20, "kraina 1 (1–20)"), (25, 45, "kraina 2 (25–45)"), (50, 70, "kraina 3 (50–70)"),
        (75, 100, "kraina 4 (75–100)")]
# Report groups each item folder is meant for (a picture elsewhere still maps, with a warning).
FOLDER_GROUPS = {
    "materialy": ("material",),
    "mikstury": ("potion", "elixir"),
    "zwoje": ("scroll",),
    "kamienie": ("stone",),
    "plecaki": ("backpack",),
    "narzedzia": ("tool",),
    "unikaty": ("unique",),
}
# Folders of interface pictures (S119) and owner notes never read as item icons.
SKIP_DIRS = {"szkic", "model", "_uklad"}


class Mapping:
    """Result of a scan: accepted (path, key), rejected (path, reason), other folders, non-PNG files."""

    def __init__(self):
        self.mapped = []
        self.rejected = []
        self.later = []
        self.formats = []
        self.warnings = []
        self.blocked = []  # (path, key, why): content block list, never imported


def run_ids(root):
    """tools/icons/ids.luau output (JSON dict) via Lune; raises SystemExit with a hint when Lune is missing."""
    lune = shutil.which("lune")
    if not lune:
        raise SystemExit("Brak Lune w PATH: uruchom `lune run tools/icons/ids.luau build/icons/ids.json` i podaj "
                         "--ids build/icons/ids.json (sprawdzenie nazw z grą jest obowiązkowe).")
    out = subprocess.run([lune, "run", "tools/icons/ids.luau"], cwd=root, capture_output=True, text=True,
                         encoding="utf-8")
    if out.returncode != 0:
        raise SystemExit("tools/icons/ids.luau: " + (out.stderr or out.stdout).strip())
    return json.loads(out.stdout)


def read_ids(root, path=None):
    """Item ids of the game: {"items": {id: {...}}, "questItems": {item: true}, "blessingLines": [...]}."""
    data = json.load(open(path, encoding="utf-8")) if path else run_ids(root)
    data.setdefault("questItems", {})
    data.setdefault("blessingLines", [])
    unused = data.get("unusedQuestItems") or []
    data["unusedQuestItems"] = list(unused) if isinstance(unused, list) else []
    return data


def item_of_key(key):
    """Item id a per-item key stands for ("eq/sword1h@5" -> "sword1h_5", "mat/ore_copper" -> "ore_copper"); None for
    shared keys (bless/<line>) and quest items."""
    group, rest = key.split("/", 1)
    if group == "eq":
        base, _, tier = rest.partition("@")
        return f"{base}_{tier}" if tier else None
    if group in ("quest", "bless") and not rest.startswith("blessing_"):
        return None
    return rest


def _hint(name, pool):
    near = difflib.get_close_matches(name, pool, n=1, cutoff=0.6)
    return f" (może {near[0]}?)" if near else ""


def _key_for(folder, base, ids, tiers):
    """(key, None) or (None, reason) for a picture in tylko_2d/<folder> named <base>.png."""
    items = ids["items"]
    m = TIERED.match(base)
    if folder == "ekwipunek":
        if m and int(m.group(2)) in tiers and base in items:
            return f"eq/{m.group(1)}@{int(m.group(2))}", None
        if m and base in items:
            return None, f"próg {m.group(2)} bez obrazka w grze (dozwolone {tiers})"
        return None, "nieznany przedmiot" + _hint(base, list(items))
    if folder == "questy":
        item = base[len("quest_"):] if base.startswith("quest_") else None
        if item and item in ids["questItems"]:
            return f"quest/{item}", None
        return None, "nieznany przedmiot questowy" + _hint(item or base, list(ids["questItems"]))
    if folder == "blogoslawienstwa":
        line = base[len("blessing_"):] if base.startswith("blessing_") else None
        if line and line in ids["blessingLines"]:
            return f"bless/{line}", None
        if base in items and items[base]["group"] == "blessing":
            return f"bless/{base}", None
        return None, "nieznane błogosławieństwo" + _hint(line or base, list(ids["blessingLines"]))
    info = items.get(base)
    if info is None:
        return None, "nieznany przedmiot" + _hint(base, list(items))
    if info["group"] in ("weapon", "offhand", "armor", "jewelry"):
        return _key_for("ekwipunek", base, ids, tiers)
    # The key comes from the item (what Logic/ItemIcons looks up), never from the folder (S118 B3.5).
    key = own_key(base, info)
    if key is None:
        return None, "przedmiot bez własnej ikony w grze"
    return key, None


def mapping(src, ids):
    """Mapping of the Graphics folder (rules of docs/archiwum/sesje/S118.md B3 on the S52 layout)."""
    res = Mapping()
    tiers = set(import_png.TIER_LIST)
    items = ids["items"]
    weapons = os.path.join(src, "modele_3d", "bronie")
    for kind in sorted(os.listdir(weapons)) if os.path.isdir(weapons) else []:
        folder = os.path.join(weapons, kind)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            path = os.path.join(folder, name)
            if os.path.isdir(path):
                continue
            base, ext = os.path.splitext(name)
            if ext.lower() != ".png":
                res.formats.append(path)
                continue
            base = base.strip()
            m = TIERED.match(base)
            if COPY.search(base):
                res.rejected.append((path, f"kopia albo inna wersja (gra bierze {COPY.sub('', base)}.png)"))
            elif kind.startswith("unique_") and base == kind:
                if kind in items:
                    res.mapped.append((path, f"uniq/{kind}"))
                else:
                    res.rejected.append((path, "nieznany unikat" + _hint(kind, list(items))))
            elif m and m.group(1) == kind and int(m.group(2)) in tiers and base in items:
                res.mapped.append((path, f"eq/{kind}@{int(m.group(2))}"))
            else:
                pool = [i for i in items if i.startswith(kind + "_")]
                res.rejected.append((path, "inna wersja albo test (nie ma swojego klucza)" + _hint(base, pool)))
    flat = os.path.join(src, "tylko_2d")
    folders = sorted(os.listdir(flat)) if os.path.isdir(flat) else []
    for folder in sorted(folders, key=lambda f: (FOLDER_ORDER.index(f) if f in FOLDER_ORDER else 99, f)):
        fdir = os.path.join(flat, folder)
        if not os.path.isdir(fdir):
            continue
        for dirpath, dirs, files in os.walk(fdir):
            dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
            for name in sorted(files):
                path = os.path.join(dirpath, name)
                base, ext = os.path.splitext(name)
                if folder not in FOLDER_ORDER:
                    if ext.lower() == ".png":
                        res.later.append(path)
                    continue
                if ext.lower() != ".png":
                    res.formats.append(path)
                    continue
                base = base.strip()
                if COPY.search(base):
                    res.rejected.append((path, f"kopia albo inna wersja (gra bierze {COPY.sub('', base)}.png)"))
                    continue
                key, reason = _key_for(folder, base, ids, tiers)
                if key:
                    res.mapped.append((path, key))
                    group = ids["items"].get(base, {}).get("group")
                    if folder in FOLDER_GROUPS and group not in FOLDER_GROUPS[folder]:
                        res.warnings.append(f"{_rel(path, src)}: inny folder niż grupa ({group}), klucz {key}")
                else:
                    res.rejected.append((path, reason))
    return res


def _tree(path, src):
    rel = os.path.relpath(path, src).replace(os.sep, "/")
    return rel.split("/", 1)[0]


def resolve_duplicates(res, src, cells):
    """Same key from two files: equal pictures -> one (warning "duplikat"); different pictures -> tylko_2d wins over
    modele_3d (warning); two different pictures in one tree -> error. Returns [(path, key)] without duplicates."""
    by_key = {}
    for path, key in res.mapped:
        by_key.setdefault(key, []).append(path)
    out, errors = [], []
    for key, paths in by_key.items():
        if len(paths) == 1:
            out.append((paths[0], key))
            continue
        hashes = {p: hashlib.sha1(cells[p].tobytes()).hexdigest() for p in paths if p in cells}
        rels = [os.path.relpath(p, src).replace(os.sep, "/") for p in paths]
        if len(set(hashes.values())) <= 1:
            res.warnings.append(f"{key}: duplikat ({', '.join(rels)}), biorę {rels[0]}")
            out.append((paths[0], key))
            continue
        flat = [p for p in paths if _tree(p, src) == "tylko_2d"]
        if len(flat) == 1:
            res.warnings.append(f"{key}: dwa różne obrazki ({', '.join(rels)}), wygrywa "
                                f"{os.path.relpath(flat[0], src).replace(os.sep, '/')}")
            out.append((flat[0], key))
        else:
            errors.append(f"{key}: dwa różne obrazki w jednym drzewie: {', '.join(rels)}")
    if errors:
        raise import_png.PackError("\n".join(errors))
    return out


def own_key(item_id, info):
    """Atlas key of an item's own picture (what the game looks for first, Logic/ItemIcons.candidates)."""
    group = info["group"]
    t = info.get("type")
    if group == "unique":
        return f"uniq/{item_id}"
    if group in ("weapon", "offhand", "armor", "jewelry"):
        return f"eq/{t}@{info['tier']}" if info.get("tier") and item_id == f"{t}_{info['tier']}" else None
    if group == "material":
        return f"mat/{item_id}"
    if group in ("potion", "elixir"):
        return f"pot/{item_id}"
    if group in ("scroll", "stone", "backpack"):
        return f"misc/{item_id}"
    if group == "tool":
        return f"tool/{item_id}"
    if group == "blessing":
        return f"bless/{item_id}"
    return None


def coverage(ids, keys):
    """{group: [items, own, lower]} and {map label: [items, own, lower]} for equipment (lower = a lower tier picture
    of the same type, Logic/ArtTiers), plus quest items as group "quest"."""
    groups = {g: [0, 0, 0] for g in REPORT_GROUPS}
    maps = {label: [0, 0, 0] for _, _, label in MAPS}
    by_type = {}
    for k in keys:
        if k.startswith("eq/") and "@" in k:
            base, tier = k[3:].split("@")
            by_type.setdefault(base, set()).add(int(tier))
    for item_id, info in ids["items"].items():
        g = info["group"]
        row = groups.setdefault(g, [0, 0, 0])
        row[0] += 1
        own = own_key(item_id, info) in keys
        if g == "blessing":
            line = re.match(r"^blessing_([a-z]+)_", item_id)
            own = own or bool(line and f"bless/{line.group(1)}" in keys)
        lower = False
        if not own and g in ("weapon", "offhand", "armor", "jewelry") and info.get("tier"):
            lower = any(t <= info["tier"] for t in by_type.get(info["type"], ()))
        row[1] += 1 if own else 0
        row[2] += 1 if lower else 0
        if g in ("weapon", "offhand", "armor", "jewelry") and info.get("tier"):
            for lo, hi, label in MAPS:
                if lo <= info["tier"] <= hi:
                    maps[label][0] += 1
                    maps[label][1] += 1 if own else 0
                    maps[label][2] += 1 if lower else 0
    quest = groups["quest"]
    quest[0] = len(ids["questItems"])
    quest[1] = sum(1 for item in ids["questItems"] if f"quest/{item}" in keys)
    return groups, maps


def _rel(path, src):
    return os.path.relpath(path, src).replace(os.sep, "/")


def report(res, src, ids, keys, written, pruned, extra, files_by_group):
    """Report lines (Markdown); printed and saved to build/icons/import_graphics.md."""
    groups, maps = coverage(ids, keys)
    out = ["# Import ikon przedmiotów (tools/icons/import_graphics.py)", ""]
    out.append(f"Obrazki przedmiotów: {len(res.mapped)} dopasowanych, {written} zapisanych w art/icons/src, "
               f"{len(res.rejected)} odrzuconych, {len(res.formats)} w innym formacie.")
    out += ["", "| Grupa | Plików | Dopasowanych | Przedmiotów w grze | Własna ikona | Niższy próg |", "|---|---|---|---|---|---|"]
    for g in REPORT_GROUPS:
        files, matched = files_by_group.get(g, (0, 0))
        n, own, lower = groups.get(g, [0, 0, 0])
        if n or files:
            out.append(f"| {g} | {files} | {matched} | {n} | {own} | {lower} |")
    out += ["", "| Ekwipunek | Przedmiotów | Własna ikona | Niższy próg |", "|---|---|---|---|"]
    for _, _, label in MAPS:
        n, own, lower = maps[label]
        out.append(f"| {label} | {n} | {own} | {lower} |")
    if ids["unusedQuestItems"]:
        out += ["", "## Nieużywane przedmioty questowe (tekst bez celu questu)"]
        out += [f"- `{item}`" for item in sorted(ids["unusedQuestItems"])]
    if res.rejected:
        out += ["", "## Odrzucone"]
        for path, reason in res.rejected:
            out.append(f"- `{_rel(path, src)}`: {reason}")
    if res.blocked:
        out += ["", "## Zablokowane (treść, tools/icons/content_block.json; gra bierze zapas)"]
        for path, key, why in res.blocked:
            out.append(f"- `{_rel(path, src)}` (`{key}`): {why}")
    if res.formats:
        out += ["", "## Pominięty format (tylko .png)"]
        out += [f"- `{_rel(p, src)}`" for p in res.formats]
    if res.warnings:
        out += ["", "## Ostrzeżenia"]
        out += [f"- {w}" for w in res.warnings]
    if extra:
        out += ["", "## W art/icons/src, brak pliku w folderze grafik" + (" (usunięte, --prune)" if pruned else "")]
        out += [f"- `{k}`" for k in extra]
    if res.later:
        out += ["", "## Grafiki interfejsu (bez ikony przedmiotu, S119)"]
        folders = {}
        for p in res.later:
            folders.setdefault(os.path.dirname(_rel(p, src)), []).append(os.path.splitext(os.path.basename(p))[0])
        for f, names in sorted(folders.items()):
            out.append(f"- `{f}` ({len(names)}): {', '.join(names)}")
    return out


def src_keys(out_root):
    """{key: path} of the cells in art/icons/src (only plain pictures, the files this tool writes)."""
    keys = {}
    if not os.path.isdir(out_root):
        return keys
    for group in sorted(os.listdir(out_root)):
        gdir = os.path.join(out_root, group)
        if not os.path.isdir(gdir):
            continue
        for name in sorted(os.listdir(gdir)):
            m = import_png.NAME.match(name)
            if m and not m.group(3):
                keys[f"{group}/{m.group(1)}" + (f"@{m.group(2)}" if m.group(2) else "")] = os.path.join(gdir, name)
    return keys


def _target(out_root, key):
    group, name = key.split("/", 1)
    return os.path.join(out_root, group, f"{name}.png")


def run(root, src, ids, dry_run=False, prune=False, key_color=None, quiet=False, report_path=None, blocks=None):
    """Imports `src` into art/icons/src of `root`. Returns (mapping, written keys, report lines). `blocks`: content
    block list (content_block.load(); default: tools/icons/content_block.json)."""
    out_root = os.path.join(root, "art", "icons", "src")
    res = mapping(src, ids)
    if blocks is None:
        blocks = content_block.load()
    res.mapped, blocked, warnings = content_block.split(res.mapped, src, blocks)
    res.blocked = [(p, k, why) for (p, k), why in blocked]
    res.warnings += warnings
    blocked_keys = {k for _, k, _ in res.blocked} - {k for _, k in res.mapped}
    cells = {}
    accepted = []
    failed = set()  # keys whose file is there but was rejected: never "missing", never pruned
    for path, key in res.mapped:
        try:
            cells[path] = import_png.cells_of(key, {"b": path}, key_color)[0][1]
            accepted.append((path, key))
        except import_png.PackError as e:
            res.rejected.append((path, str(e).split(": ", 1)[-1]))
            failed.add(key)
    res.mapped = accepted
    res.mapped = resolve_duplicates(res, src, cells)
    written = []
    for path, key in res.mapped:
        target = _target(out_root, key)
        img = cells[path]
        if os.path.exists(target):
            old = Image.open(target).convert("RGBA")
            if import_png._same_pixels(old, img):
                continue
        written.append(key)
        if not dry_run:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            import_png.save_png(img, target)
    present = src_keys(out_root)
    for k in sorted(blocked_keys):
        if k in present:
            written.append(k)
            if not dry_run:
                os.remove(present[k])
            del present[k]
    mapped_keys = {k for _, k in res.mapped}
    extra = sorted(k for k in present if k not in mapped_keys and k not in failed and not k.startswith("ui/"))
    if prune and not dry_run:
        for k in extra:
            os.remove(present[k])
    keys = set(mapped_keys) | ({k for k in present if k not in extra} if prune else set(present))
    files_by_group = {}
    for _, key in res.mapped:
        row = files_by_group.setdefault(_group_of_key(key, ids), [0, 0])
        row[0] += 1
        row[1] += 1
    for path, _ in res.rejected:
        files_by_group.setdefault(_group_of_path(path, src, ids), [0, 0])[0] += 1
    lines = report(res, src, ids, keys, len(written), prune, extra, files_by_group)
    if report_path is None:
        report_path = os.path.join(root, "build", "icons", "import_graphics.md")
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    if not quiet:
        print("\n".join(lines))
        print(f"\nRaport: {os.path.relpath(report_path, root)}")
        if written and not dry_run:
            print("Dalej: py -3 tools/icons/import_png.py (pakuje art/icons/src w atlasy).")
    return res, written, lines


def _group_of_key(key, ids):
    group = key.split("/", 1)[0]
    if group == "quest":
        return "quest"
    if group == "bless":
        return "blessing"
    item = item_of_key(key)
    info = ids["items"].get(item or "")
    return info["group"] if info else group


def _group_of_path(path, src, ids):
    rel = _rel(path, src).split("/")
    if rel[0] == "modele_3d":
        kind = rel[2] if len(rel) > 2 else ""
        if kind.startswith("unique_"):
            return "unique"
        for info in ids["items"].values():
            if info.get("type") == kind:
                return info["group"]
        return "weapon"
    folder = rel[1] if len(rel) > 1 else ""
    m = TIERED.match(os.path.splitext(rel[-1])[0])
    if folder == "ekwipunek" and m:
        for info in ids["items"].values():
            if info.get("type") == m.group(1):
                return info["group"]
    return {"ekwipunek": "armor", "unikaty": "unique", "materialy": "material", "questy": "quest",
            "mikstury": "potion", "blogoslawienstwa": "blessing", "zwoje": "scroll", "kamienie": "stone",
            "plecaki": "backpack", "narzedzia": "tool"}.get(folder, "other")


# ------------------------------------------------------------------------------------------------ selftest

SELFTEST_IDS = {
    "items": {
        "sword1h_5": {"category": "equipment", "type": "sword1h", "tier": 5, "group": "weapon"},
        "sword1h_25": {"category": "equipment", "type": "sword1h", "tier": 25, "group": "weapon"},
        "armor_heavy_1": {"category": "equipment", "type": "armor_heavy", "tier": 1, "group": "armor"},
        "unique_grimrok_cleaver": {"category": "equipment", "type": "axe1h", "tier": 10, "group": "unique"},
        "ore_copper": {"category": "material", "type": "ore", "group": "material"},
        "potion_hp_4": {"category": "consumable", "type": "potion_hp", "tier": 4, "group": "potion"},
        "blessing_sage_1": {"category": "consumable", "type": "blessing", "group": "blessing"},
        "blessing_sage_2": {"category": "consumable", "type": "blessing", "group": "blessing"},
        "stone_return": {"category": "stone", "type": "stone", "group": "stone"},
        "boar_tusk": {"category": "material", "type": "trophy", "group": "material"},
    },
    "questItems": {"aleBarrel": True, "sheepBell": True},
    "blessingLines": ["sage"],
    "unusedQuestItems": [],
}


def _pic(path, color, size=300, alpha=True, checker=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if checker:
        img = Image.new("RGB", (size, size), (204, 204, 204))
        d = ImageDraw.Draw(img)
        for y in range(0, size, 16):
            for x in range((y // 16) % 2 * 16, size, 32):
                d.rectangle((x, y, x + 15, y + 15), fill=(255, 255, 255))
        d.ellipse((size // 4, size // 4, size * 3 // 4, size * 3 // 4), fill=color)
    elif alpha:
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(img).ellipse((size // 4, size // 4, size * 3 // 4, size * 3 // 4), fill=color + (255,))
    else:
        img = Image.new("RGB", (size, size), (255, 0, 255))
        ImageDraw.Draw(img).ellipse((size // 4, size // 4, size * 3 // 4, size * 3 // 4), fill=color)
    img.save(path)


def selftest():
    """Synthetic Graphics folder: mapping rules, rejections with reasons, duplicates, quest and blessing keys,
    idempotence and --prune, all under build/icons/selftest_graphics (art/ and src/ untouched)."""
    root = os.path.abspath(os.path.join(HERE, "..", ".."))
    work = os.path.join(root, "build", "icons", "selftest_graphics")
    shutil.rmtree(work, ignore_errors=True)
    src = os.path.join(work, "Graphics")
    repo = os.path.join(work, "repo")
    os.makedirs(os.path.join(repo, "art", "icons", "src"))
    b = os.path.join(src, "modele_3d", "bronie")
    t = os.path.join(src, "tylko_2d")
    _pic(os.path.join(b, "sword1h", "sword1h_5.png"), (200, 200, 210))
    _pic(os.path.join(b, "sword1h", "sword1h_5_wersja2.png"), (200, 0, 0))
    _pic(os.path.join(b, "sword1h", "_test_start.png"), (200, 0, 0))
    _pic(os.path.join(b, "sword1h", "szkic", "sword1h_5.png"), (0, 0, 200))
    _pic(os.path.join(b, "unique_grimrok_cleaver", "unique_grimrok_cleaver.png"), (90, 90, 90))
    _pic(os.path.join(t, "unikaty", "unique_grimrok_cleaver.png"), (120, 60, 30))  # different: tylko_2d wins
    _pic(os.path.join(t, "ekwipunek", "heavy", "armor_heavy_1.png"), (150, 150, 150))
    _pic(os.path.join(t, "ekwipunek", "heavy", "armor_heavy_25.png"), (150, 150, 150))  # unknown id
    _pic(os.path.join(t, "materialy", "ore_copper.png"), (190, 110, 60), alpha=False)  # magenta, needs --key
    _pic(os.path.join(t, "materialy", "ore_coper.png"), (190, 110, 60))  # typo -> hint ore_copper
    _pic(os.path.join(t, "mikstury", "potion_hp_4.png"), (200, 30, 30), checker=True)  # no alpha
    _pic(os.path.join(t, "mikstury", "potion_hp_4 (1).png"), (200, 30, 30))  # copy
    _pic(os.path.join(t, "questy", "quest_aleBarrel.png"), (130, 80, 40))
    _pic(os.path.join(t, "questy", "quest_aleBarel.png"), (130, 80, 40))  # typo -> hint aleBarrel
    _pic(os.path.join(t, "blogoslawienstwa", "blessing_sage.png"), (60, 120, 220))
    _pic(os.path.join(t, "blogoslawienstwa", "blessing_sage_2.png"), (60, 220, 120))
    _pic(os.path.join(t, "kamienie", "stone_return.png"), (100, 140, 200), size=100)  # too small
    _pic(os.path.join(t, "zwoje", "boar_tusk.png"), (230, 220, 190))  # material in the scroll folder: mat/, warning
    _pic(os.path.join(t, "hud", "attack.png"), (0, 0, 0))  # interface: S119
    os.makedirs(os.path.join(t, "zwoje"), exist_ok=True)
    open(os.path.join(t, "zwoje", "scroll_x.webp"), "wb").write(b"RIFF")
    ok = True

    def check(cond, msg):
        nonlocal ok
        if not cond:
            ok = False
            print("selftest: " + msg)

    res, written, _ = run(repo, src, SELFTEST_IDS, blocks={}, key_color=None, quiet=True,
                          report_path=os.path.join(work, "r1.md"))
    keys = {k for _, k in res.mapped}
    reasons = {_rel(p, src): r for p, r in res.rejected}
    expect = {"eq/sword1h@5", "uniq/unique_grimrok_cleaver", "eq/armor_heavy@1", "quest/aleBarrel", "bless/sage",
              "bless/blessing_sage_2", "mat/boar_tusk"}
    check(keys == expect, f"klucze {sorted(keys)} zamiast {sorted(expect)}")
    check("aleBarrel" in reasons.get("tylko_2d/questy/quest_aleBarel.png", ""), "brak podpowiedzi aleBarrel")
    check("ore_copper" in reasons.get("tylko_2d/materialy/ore_coper.png", ""), "brak podpowiedzi ore_copper")
    check("przezroczysto" in reasons.get("tylko_2d/materialy/ore_copper.png", ""), "magenta bez --key przeszła")
    check("przezroczysto" in reasons.get("tylko_2d/mikstury/potion_hp_4.png", ""), "szachownica przeszła")
    check("kopia" in reasons.get("tylko_2d/mikstury/potion_hp_4 (1).png", ""), "kopia (1) przeszła")
    check("kopia" in reasons.get("modele_3d/bronie/sword1h/sword1h_5_wersja2.png", ""), "wersja2 przeszła")
    check("256" in reasons.get("tylko_2d/kamienie/stone_return.png", ""), "za mały obrazek przeszedł")
    check("nieznany" in reasons.get("tylko_2d/ekwipunek/heavy/armor_heavy_25.png", ""), "nieznane id przeszło")
    check(not any("szkic" in r for r in reasons), "szkic był czytany")
    check([_rel(p, src) for p in res.formats] == ["tylko_2d/zwoje/scroll_x.webp"], "inny format nie zgłoszony")
    check([_rel(p, src) for p in res.later] == ["tylko_2d/hud/attack.png"], "folder S119 nie na liście")
    check(any("wygrywa tylko_2d/unikaty" in w for w in res.warnings), "konflikt cleaver bez ostrzeżenia")
    check(any("boar_tusk" in w and "inny folder" in w for w in res.warnings), "boar_tusk w zwoje/ bez ostrzeżenia")
    cleaver = Image.open(os.path.join(repo, "art", "icons", "src", "uniq", "unique_grimrok_cleaver.png"))
    px = cleaver.convert("RGBA").getpixel((64, 64))
    check(max(abs(a - b) for a, b in zip(px[:3], (120, 60, 30))) <= 3, f"cleaver nie z tylko_2d ({px})")
    # With --key the magenta picture is accepted.
    res2, written2, _ = run(repo, src, SELFTEST_IDS, blocks={}, key_color=import_png.parse_key("magenta"), quiet=True,
                            report_path=os.path.join(work, "r2.md"))
    check(written2 == ["mat/ore_copper"], f"--key: zapisane {written2}")
    # Idempotent.
    _, written3, _ = run(repo, src, SELFTEST_IDS, blocks={}, key_color=import_png.parse_key("magenta"), quiet=True,
                         report_path=os.path.join(work, "r3.md"))
    check(written3 == [], f"drugi przebieg zapisał {written3}")
    # Two different pictures for one key in the same tree: error.
    _pic(os.path.join(t, "ekwipunek", "light", "armor_heavy_1.png"), (10, 10, 10))
    try:
        run(repo, src, SELFTEST_IDS, blocks={}, quiet=True, report_path=os.path.join(work, "r4.md"))
        check(False, "konflikt w jednym drzewie bez błędu")
    except import_png.PackError:
        pass
    os.remove(os.path.join(t, "ekwipunek", "light", "armor_heavy_1.png"))
    # A removed source stays (report) until --prune.
    os.remove(os.path.join(t, "questy", "quest_aleBarrel.png"))
    _, _, lines = run(repo, src, SELFTEST_IDS, blocks={}, quiet=True, report_path=os.path.join(work, "r5.md"))
    check(any("quest/aleBarrel" in ln for ln in lines), "brak pliku nie zgłoszony")
    check(os.path.exists(os.path.join(repo, "art", "icons", "src", "quest", "aleBarrel.png")), "usunięte bez --prune")
    run(repo, src, SELFTEST_IDS, blocks={}, prune=True, quiet=True, report_path=os.path.join(work, "r6.md"))
    check(not os.path.exists(os.path.join(repo, "art", "icons", "src", "quest", "aleBarrel.png")), "--prune nie usunął")
    # The magenta ore_copper is there but rejected without --key: --prune keeps its earlier cell.
    check(os.path.exists(os.path.join(repo, "art", "icons", "src", "mat", "ore_copper.png")), "--prune usunął odrzucony")
    # Content block list: a listed file with the same bytes is skipped and its cell removed even without --prune;
    # the same path with other bytes (regenerated) is imported again with a warning.
    sage = os.path.join(t, "blogoslawienstwa", "blessing_sage.png")
    blocks = {"tylko_2d/blogoslawienstwa/blessing_sage.png": {
        "path": "tylko_2d/blogoslawienstwa/blessing_sage.png", "sha256": content_block.file_hash(sage), "why": "test"}}
    res7, _, lines7 = run(repo, src, SELFTEST_IDS, blocks=blocks, quiet=True, report_path=os.path.join(work, "r7.md"))
    check("bless/sage" not in {k for _, k in res7.mapped}, "zablokowany plik dopasowany")
    check(not os.path.exists(os.path.join(repo, "art", "icons", "src", "bless", "sage.png")), "zablokowany został")
    check(any("Zablokowane" in ln for ln in lines7), "brak sekcji Zablokowane w raporcie")
    _pic(sage, (10, 200, 10))
    res8, written8, _ = run(repo, src, SELFTEST_IDS, blocks=blocks, quiet=True, report_path=os.path.join(work, "r8.md"))
    check("bless/sage" in written8 and any("blokad" in w for w in res8.warnings), "zmieniony plik z listy blokad")
    groups, maps = coverage(SELFTEST_IDS, {"eq/sword1h@5", "bless/sage", "pot/potion_hp_4", "quest/sheepBell"})
    check(groups["weapon"] == [2, 1, 1], f"pokrycie broni {groups['weapon']}")
    check(groups["blessing"] == [2, 2, 0], f"pokrycie błogosławieństw {groups['blessing']}")
    check(groups["quest"] == [2, 1, 0], f"pokrycie questów {groups['quest']}")
    check(maps["kraina 2 (25–45)"] == [1, 0, 1], f"pokrycie krainy 2 {maps['kraina 2 (25–45)']}")
    print("selftest: OK" if ok else "selftest: BŁĄD")
    return ok


def main():
    ap = argparse.ArgumentParser(description="Kopiuje ikony przedmiotów z folderu Graphics do art/icons/src (128 px).")
    ap.add_argument("--src", default=None, help="folder grafik (domyślnie VAELTHORN_GRAPHICS albo " + DEFAULT_SRC + ")")
    ap.add_argument("--dry-run", action="store_true", help="tylko raport, nic nie zapisuje poza build/")
    ap.add_argument("--prune", action="store_true", help="usuń z art/icons/src klucze, których pliku już nie ma")
    ap.add_argument("--key", help="kolor tła bez alfy do usunięcia: FF00FF, #FF00FF albo magenta")
    ap.add_argument("--ids", help="plik JSON z tools/icons/ids.luau (bez niego narzędzie uruchamia Lune)")
    ap.add_argument("--report", action="store_true", help="sam raport pokrycia z art/icons/src (bez folderu grafik)")
    ap.add_argument("--selftest", action="store_true", help="sprawdza reguły na sztucznym folderze w build/")
    a = ap.parse_args()
    if a.selftest:
        sys.exit(0 if selftest() else 1)
    root = os.getcwd()
    if not os.path.isdir(os.path.join(root, "art", "icons")):
        sys.exit("Uruchom z katalogu repozytorium.")
    ids = read_ids(root, a.ids)
    if a.report:
        groups, maps = coverage(ids, set(src_keys(os.path.join(root, "art", "icons", "src"))))
        for g in REPORT_GROUPS:
            n, own, lower = groups.get(g, [0, 0, 0])
            print(f"{g}: {n} przedmiotów, własna ikona {own}, niższy próg {lower}")
        for _, _, label in MAPS:
            n, own, lower = maps[label]
            print(f"{label}: {n} sztuk ekwipunku, własna ikona {own}, niższy próg {lower}")
        return
    src = a.src or os.environ.get("VAELTHORN_GRAPHICS") or DEFAULT_SRC
    if not os.path.isdir(src):
        sys.exit(f"Brak folderu grafik: {src} (podaj --src albo VAELTHORN_GRAPHICS). Nic nie zmieniono.")
    try:
        run(root, src, ids, dry_run=a.dry_run, prune=a.prune, key_color=import_png.parse_key(a.key))
    except import_png.PackError as e:
        sys.exit(f"Błąd:\n{e}")


if __name__ == "__main__":
    main()
