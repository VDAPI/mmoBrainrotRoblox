# Copies the owner's item pictures from his Graphics folder (PORADNIK-GRAFIKA.md layout, S52) into art/icons/src as
# finished 128 px cells (crop to the picture, 6% margin, Lanczos, light sharpening: import_png.cells_of), so the repo
# keeps small sources and never the 1024 px originals. Then run import_png.py to pack them.
#   py -3 tools/icons/import_graphics.py [--src D:/Users/vdapi/Downloads/Graphics] [--dry-run]
# Pictures without a place in the game (skills, effects, HUD, map, classes, ...) are only listed.
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image  # noqa: E402

import import_png  # noqa: E402

DEFAULT_SRC = "D:/Users/vdapi/Downloads/Graphics"
TIERED = re.compile(r"^([a-z0-9_]+?)_(\d+)\.png$")
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


def mapping(src):
    """([(source path, key)], [(source path, reason)]) for the Graphics folder."""
    mapped, skipped = [], []
    weapons = os.path.join(src, "modele_3d", "bronie")
    tiers = set(import_png.TIER_LIST)
    for kind in sorted(os.listdir(weapons)) if os.path.isdir(weapons) else []:
        folder = os.path.join(weapons, kind)
        for name in sorted(os.listdir(folder)):
            path = os.path.join(folder, name)
            if not name.endswith(".png"):
                continue
            m = TIERED.match(name)
            if kind.startswith("unique_") and name == f"{kind}.png":
                mapped.append((path, f"uniq/{kind}"))
            elif m and m.group(1) == kind and int(m.group(2)) in tiers:
                mapped.append((path, f"eq/{kind}@{int(m.group(2))}"))
            else:
                skipped.append((path, "inna wersja albo test (nie ma swojego klucza)"))
    flat = os.path.join(src, "tylko_2d")
    for folder in sorted(os.listdir(flat)) if os.path.isdir(flat) else []:
        fdir = os.path.join(flat, folder)
        for dirpath, _, files in os.walk(fdir):
            for name in sorted(files):
                if not name.endswith(".png"):
                    continue
                path = os.path.join(dirpath, name)
                base = name[:-4]
                m = TIERED.match(name)
                if folder == "ekwipunek" and m and int(m.group(2)) in tiers:
                    mapped.append((path, f"eq/{m.group(1)}@{int(m.group(2))}"))
                elif folder == "blogoslawienstwa" and base.startswith("blessing_"):
                    mapped.append((path, f"bless/{base[len('blessing_'):]}"))
                elif folder in ITEM_FOLDERS:
                    mapped.append((path, f"{ITEM_FOLDERS[folder]}/{base}"))
                else:
                    skipped.append((path, "gra nie ma jeszcze miejsca na ten obrazek"))
    return mapped, skipped


def main():
    ap = argparse.ArgumentParser(description="Kopiuje ikony przedmiotów z folderu Graphics do art/icons/src (128 px).")
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    root = os.getcwd()
    out_root = os.path.join(root, "art", "icons", "src")
    if not os.path.isdir(os.path.join(root, "art", "icons")):
        sys.exit("Uruchom z katalogu repozytorium.")
    mapped, skipped = mapping(a.src)
    keys = [k for _, k in mapped]
    dup = sorted({k for k in keys if keys.count(k) > 1})
    if dup:
        sys.exit("Dwa obrazki na jeden klucz: " + ", ".join(dup))
    written = 0
    for path, key in mapped:
        group, name = key.split("/", 1)
        target = os.path.join(out_root, group, f"{name}.png")
        cells = import_png.cells_of(key, {"b": path})
        img = cells[0][1]
        if os.path.exists(target):
            old = Image.open(target).convert("RGBA")
            if import_png._same_pixels(old, img):
                continue
        written += 1
        if not a.dry_run:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            import_png.save_png(img, target)
    print(f"Obrazki przedmiotów: {len(mapped)} (zapisane {written}) -> art/icons/src")
    by_reason = {}
    for path, reason in skipped:
        by_reason.setdefault(reason, []).append(os.path.relpath(path, a.src).replace(os.sep, "/"))
    for reason, paths in by_reason.items():
        print(f"Pominięte ({reason}): {len(paths)}")
        folders = {}
        for p in paths:
            folders.setdefault(os.path.dirname(p), []).append(os.path.basename(p))
        for f, names in sorted(folders.items()):
            print(f"  {f}: {len(names)}")


if __name__ == "__main__":
    main()
