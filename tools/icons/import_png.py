# PNG icon packer (S52): pictures from art/icons/src become cells of the PNG atlases (art/icons/items_<n>.png after
# the SVG sheets) and the PNG table of src/shared/Data/ItemIconAtlas.luau. Only Pillow; run from the repo root:
#   py -3 tools/icons/import_png.py [--dry-run] [--key FF00FF] [--selftest]
# Source names: art/icons/src/<group>/<name>[@<tier>][.m|.a].png -> key "<group>/<name>[@<tier>]" (docs/GRAFIKA.md 4.5).
# Layers of one key: <key>.png alone; <key>.m.png [+ <key>.png] [+ <key>.a.png]; <key>.png + <key>.a.png.
# A source of exactly 128x128 px is already a cell and is taken as it is (tools/icons/import_graphics.py writes those);
# any other source needs a side >= 256 px and is cropped to the common alpha box of its layers, padded to a square with
# a 6% margin, scaled to 128 px (Lanczos) and lightly sharpened.
# Cells: a changed key keeps its old cells in order, extra layers and new keys go after the last used cell, cells of
# removed keys are cleared; SVG sheets are never touched. Changed sheets get an empty id in ItemIconSheets.luau (until
# the upload the game shows the SVG icon there, never a wrong picture).
import argparse
import difflib
import os
import re
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

import atlas_index  # noqa: E402
from tiers import TIERS  # noqa: E402

CELL, GRID, SIDE = 128, 8, 1024
PER_SHEET = GRID * GRID
MIN_SIDE = 256
MARGIN = 0.06
GROUPS = ("eq", "uniq", "mat", "pot", "bless", "misc", "tool", "ui", "quest")
# Groups whose keys may name one item (`mat/ore_copper`, `pot/potion_hp_1`, `misc/stone_return`); tests/artassets checks
# the ids against Data/Items.
# S118: "quest/<item>" = a quest objective item (tests check quest.item.<item> texts). "bless/blessing_<line>_<n>"
# = one rarity of a blessing line (wins over the line picture "bless/<line>").
PER_ITEM = ("mat", "pot", "misc", "tool", "quest", "bless")
LAYER_SETS = ({"b"}, {"m"}, {"m", "b"}, {"m", "a"}, {"m", "b", "a"}, {"b", "a"})
ORDER = {"m": 0, "b": 1, "a": 2}
TIER_LIST = [t for t, _, _ in TIERS]
NAME = re.compile(r"^([a-z][A-Za-z0-9_]*)(?:@(\d+))?(?:\.([ma]))?\.png$")
KEYWORDS = {"magenta": "FF00FF", "green": "00FF00", "white": "FFFFFF", "black": "000000"}


class PackError(Exception):
    pass


# ------------------------------------------------------------------------------------------------ sources

def parse_key(arg):
    """--key FF00FF | #FF00FF | magenta -> (r, g, b) or None."""
    if not arg:
        return None
    v = KEYWORDS.get(arg.lower(), arg).lstrip("#")
    if not re.fullmatch(r"[0-9A-Fa-f]{6}", v):
        raise PackError(f"--key: nieznany kolor {arg} (np. FF00FF albo magenta)")
    return tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))


def key_sort(key):
    group, rest = key.split("/", 1)
    base, _, tier = rest.partition("@")
    return (group, base, int(tier) if tier else -1)


def scan(src, icons):
    """{key: {layer: path}} of every source picture; raises PackError on a bad name or layer set."""
    found = {}
    errors = []
    if not os.path.isdir(src):
        return found
    for group in sorted(os.listdir(src)):
        gdir = os.path.join(src, group)
        if not os.path.isdir(gdir):
            if group not in ("README.md", ".gitkeep"):
                errors.append(f"{group}: plik poza folderem grupy ({', '.join(GROUPS)})")
            continue
        if group not in GROUPS:
            errors.append(f"{group}/: nieznana grupa (dozwolone: {', '.join(GROUPS)})")
            continue
        for name in sorted(os.listdir(gdir)):
            if name in (".gitkeep", "README.md"):
                continue
            m = NAME.match(name)
            if not m:
                errors.append(f"{group}/{name}: zła nazwa (wzór <nazwa>[@<próg>][.m|.a].png)")
                continue
            base, tier, layer = m.group(1), m.group(2), m.group(3) or "b"
            key = f"{group}/{base}" + (f"@{tier}" if tier else "")
            if tier and (group != "eq" or int(tier) not in TIER_LIST):
                errors.append(f"{group}/{name}: wariant progu (@<próg>) tylko w eq/, próg z listy {TIER_LIST}")
                continue
            known = f"{group}/{base}" in icons
            if not known and group not in PER_ITEM:
                hint = difflib.get_close_matches(f"{group}/{base}", list(icons), n=1)
                errors.append(f"{group}/{name}: nieznany klucz {group}/{base}" + (f" (może {hint[0]}?)" if hint else ""))
                continue
            found.setdefault(key, {})[layer] = os.path.join(gdir, name)
    for key, layers in found.items():
        if set(layers) not in LAYER_SETS:
            errors.append(f"{key}: zły zestaw warstw {sorted(layers)} (dozwolone: .png; .m.png [+ .png] [+ .a.png]; "
                          ".png + .a.png)")
    if errors:
        raise PackError("\n".join(errors))
    return dict(sorted(found.items(), key=lambda kv: key_sort(kv[0])))


def _keyed(img, color):
    """RGBA with every pixel close to `color` made transparent (sources without alpha, --key)."""
    img = img.convert("RGBA")
    r0, g0, b0 = color
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            d = max(abs(r - r0), abs(g - g0), abs(b - b0))
            if d < 48:
                px[x, y] = (r, g, b, 0)
            elif d < 96:
                px[x, y] = (r, g, b, a * (d - 48) // 48)
    return img


def _has_alpha(img):
    return img.mode in ("RGBA", "LA", "PA") and img.getchannel("A").getextrema()[0] < 255


def _border_clear(img):
    """Share of fully transparent pixels on the outer 2% band (a keyed background clears the border)."""
    a = img.getchannel("A")
    w, h = a.size
    band = max(1, min(w, h) // 50)
    px = a.load()
    total = clear = 0
    for y in range(h):
        for x in (range(w) if y < band or y >= h - band else list(range(band)) + list(range(w - band, w))):
            total += 1
            clear += 1 if px[x, y] == 0 else 0
    return clear / total if total else 0


def _grey(img):
    """Greyscale copy keeping alpha (tinted layers m and a)."""
    a = img.getchannel("A")
    g = img.convert("L")
    return Image.merge("RGBA", (g, g, g, a))


def _clear_rgb(img):
    """Fully transparent pixels get RGB 0, so equal pictures give equal bytes."""
    r, g, b, a = img.split()
    mask = a.point(lambda v: 255 if v == 0 else 0)
    black = Image.new("L", img.size, 0)
    return Image.merge("RGBA", tuple(Image.composite(black, c, mask) for c in (r, g, b)) + (a,))


def cells_of(key, layers, key_color=None):
    """[(layer, 128 px RGBA)] of one key, layers in game order (m, b, a)."""
    imgs = {}
    for layer, path in layers.items():
        img = Image.open(path)
        img.load()
        if img.mode == "P" and "transparency" in img.info:
            img = img.convert("RGBA")
        if not _has_alpha(img):
            if not key_color:
                raise PackError(f"{os.path.relpath(path)}: brak przezroczystości (kanału alfa); "
                                "zapisz PNG z alfą albo użyj --key FF00FF dla tła magenta")
            img = _keyed(img, key_color)
            if _border_clear(img) < 0.5:
                raise PackError(f"{os.path.relpath(path)}: brak przezroczystości (tło nie ma koloru klucza: "
                                "szachownica albo jednolite tło)")
        imgs[layer] = img.convert("RGBA")
    sizes = {im.size for im in imgs.values()}
    if len(sizes) > 1:
        raise PackError(f"{key}: warstwy mają różne rozmiary {sorted(sizes)}")
    w, h = sizes.pop()
    out = []
    if (w, h) == (CELL, CELL):
        for layer in sorted(imgs, key=ORDER.get):
            im = imgs[layer]
            out.append((layer, _clear_rgb(_grey(im) if layer in ("m", "a") else im)))
        return out
    if min(w, h) < MIN_SIDE:
        raise PackError(f"{key}: obrazek {w}x{h} px, potrzeba boku >= {MIN_SIDE} px (albo dokładnie {CELL}x{CELL})")
    box = None
    for im in imgs.values():
        b = im.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    if box is None:
        raise PackError(f"{key}: obrazek jest cały przezroczysty")
    bw, bh = box[2] - box[0], box[3] - box[1]
    side = int(round(max(bw, bh) / (1 - 2 * MARGIN)))
    ox, oy = (side - bw) // 2, (side - bh) // 2
    for layer in sorted(imgs, key=ORDER.get):
        im = imgs[layer].crop(box)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(im, (ox, oy))
        # Premultiplied alpha while resampling: no dark fringe from the colour of transparent pixels.
        small = sq.convert("RGBa").resize((CELL, CELL), Image.LANCZOS).convert("RGBA")
        rgb = small.convert("RGB").filter(ImageFilter.UnsharpMask(radius=0.8, percent=40, threshold=2))
        small = Image.merge("RGBA", (*rgb.split(), small.getchannel("A")))
        out.append((layer, _clear_rgb(_grey(small) if layer in ("m", "a") else small)))
    return out


# ------------------------------------------------------------------------------------------------ packing

def _linear(L, svg_sheets):
    return (L["sheet"] - svg_sheets - 1) * PER_SHEET + (L["y"] // CELL) * GRID + L["x"] // CELL


def _cell(i, svg_sheets):
    return {"sheet": svg_sheets + 1 + i // PER_SHEET, "x": (i % PER_SHEET) % GRID * CELL, "y": (i % PER_SHEET) // GRID * CELL}


def _atlas_path(atlas_dir, n):
    return os.path.join(atlas_dir, f"items_{n}.png")


def pack(found, prev_png, svg_sheets, atlas_dir, key_color=None):
    """New PNG index and atlas images. Returns (png, images {sheet: Image}, freed {linear cells}, made {key: cells})."""
    made = {key: cells_of(key, layers, key_color) for key, layers in found.items()}
    used = {}
    for key, e in prev_png.items():
        for L in e["layers"]:
            used[_linear(L, svg_sheets)] = key
    nxt = max(used) + 1 if used else 0
    png = {}
    freed = set()
    for key, e in prev_png.items():
        old = [_linear(L, svg_sheets) for L in e["layers"]]
        new = made.get(key)
        keep = old[:len(new)] if new else []
        freed.update(set(old) - set(keep))
    for key in sorted(made, key=key_sort):
        layers = []
        old = [_linear(L, svg_sheets) for L in prev_png[key]["layers"]] if key in prev_png else []
        for j, (layer, _) in enumerate(made[key]):
            if j < len(old):
                i = old[j]
            else:
                i, nxt = nxt, nxt + 1
            c = _cell(i, svg_sheets)
            c["layer"] = layer
            layers.append(c)
        png[key] = {"accent": None, "layers": layers}
    last = max([svg_sheets] + [L["sheet"] for e in png.values() for L in e["layers"]])
    images = {}
    for n in range(svg_sheets + 1, last + 1):
        p = _atlas_path(atlas_dir, n) if atlas_dir else None
        images[n] = Image.open(p).convert("RGBA") if p and os.path.exists(p) else Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
    blank = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for i in freed:
        c = _cell(i, svg_sheets)
        if c["sheet"] in images:
            images[c["sheet"]].paste(blank, (c["x"], c["y"]))
    for key, e in png.items():
        for L, (_, img) in zip(e["layers"], made[key]):
            images[L["sheet"]].paste(img, (L["x"], L["y"]))
    return png, images, freed, made


def _same_pixels(a, b):
    return a.size == b.size and a.tobytes() == b.tobytes()


def save_png(img, path):
    """Deterministic PNG (no time or text chunks)."""
    img.save(path, format="PNG", optimize=True)


# ------------------------------------------------------------------------------------------------ sheet ids

def update_sheet_ids(path, changed, last, svg_sheets):
    """ItemIconSheets.luau: "" for changed sheets, a new "" line per new sheet, lines after `last` removed."""
    text = open(path, encoding="utf-8").read()
    lines = text.split("\n")
    entries = [(i, ln) for i, ln in enumerate(lines) if re.match(r'^\t"[^"]*", -- items_\d+\.png', ln)]
    by_sheet = {int(re.search(r"items_(\d+)", ln).group(1)): i for i, ln in entries}
    for n in changed:
        if n in by_sheet:
            lines[by_sheet[n]] = f'\t"", -- items_{n}.png'
    insert_at = max(by_sheet.values()) + 1 if by_sheet else len(lines) - 2
    for n in range(1, last + 1):
        if n not in by_sheet:
            lines.insert(insert_at, f'\t"", -- items_{n}.png')
            insert_at += 1
    lines = [ln for ln in lines if not (re.match(r'^\t"[^"]*", -- items_(\d+)\.png', ln)
                                        and int(re.search(r"items_(\d+)", ln).group(1)) > max(last, svg_sheets))]
    out = "\n".join(lines)
    if out != text:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(out)


def check_ids(root, sheets_path=None, sheets=None, write_list=False):
    """(errors, files waiting for an upload) of ItemIconSheets.luau: one line per atlas, "" or rbxassetid://<digits>.
    With write_list the waiting files go to build/icons/do_wgrania.txt (full paths, one per line)."""
    sheets_path = sheets_path or os.path.join(root, "src", "shared", "Data", "ItemIconSheets.luau")
    if sheets is None:
        sheets = atlas_index.parse(os.path.join(root, "src", "shared", "Data", "ItemIconAtlas.luau"))["sheets"]
    errors, waiting, lines = [], [], {}
    for ln in open(sheets_path, encoding="utf-8").read().split("\n"):
        m = re.match(r'^\t"([^"]*)", -- items_(\d+)\.png\s*$', ln)
        if m:
            n = int(m.group(2))
            if n in lines:
                errors.append(f"items_{n}.png: dwa wiersze")
            lines[n] = m.group(1)
    for n in range(1, sheets + 1):
        if n not in lines:
            errors.append(f"items_{n}.png: brak wiersza")
        elif lines[n] == "":
            waiting.append(f"items_{n}.png")
        elif not re.fullmatch(r"rbxassetid://\d+", lines[n]):
            errors.append(f"items_{n}.png: złe id {lines[n]!r} (tylko rbxassetid://<cyfry>)")
    for n in lines:
        if n > sheets:
            errors.append(f"items_{n}.png: wiersz bez atlasu (SHEETS = {sheets})")
        elif not os.path.exists(_atlas_path(os.path.join(root, "art", "icons"), n)):
            errors.append(f"items_{n}.png: brak pliku art/icons/items_{n}.png")
    if write_list:
        out = os.path.join(root, "build", "icons", "do_wgrania.txt")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8", newline="\n") as f:
            for name in waiting:
                f.write(os.path.join(root, "art", "icons", name) + "\n")
    return errors, waiting


# ------------------------------------------------------------------------------------------------ preview

def preview(made, before, path, tint_samples):
    """Every changed key before (old picture or the SVG icon of its key; empty for a new per-item key) and after, on a
    dark slot; m layers tinted Prosty (before) and Żelazny (after), a layers in a seal red."""
    from render import tinted
    from preview import slot_bg, BG, FONT
    rows = list(made.items())
    cols, slot, lab = 6, 96, 18
    W = 20 + cols * (2 * slot + 30)
    H = 20 + ((len(rows) + cols - 1) // cols) * (slot + lab + 14)
    img = Image.new("RGBA", (W, max(H, 60)), BG + (255,))
    d = ImageDraw.Draw(img)
    for i, (key, cells) in enumerate(rows):
        x = 20 + (i % cols) * (2 * slot + 30)
        y = 14 + (i // cols) * (slot + lab + 14)
        for k, pic in enumerate((before.get(key), cells)):
            img.alpha_composite(slot_bg(slot, (154, 160, 166)), (x + k * (slot + 6), y))
            if pic is None:
                continue
            out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            for layer, cimg in pic:
                tint = tint_samples[k % len(tint_samples)] if layer == "m" else ("#C0503C" if layer == "a" else None)
                out = Image.alpha_composite(out, tinted(cimg, tint))
            out = out.resize((int(slot * 0.86), int(slot * 0.86)), Image.LANCZOS)
            img.alpha_composite(out, (x + k * (slot + 6) + (slot - out.width) // 2, y + (slot - out.height) // 2))
        d.text((x, y + slot + 2), key, font=FONT, fill=(216, 204, 176))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.convert("RGB").save(path)


def _fallback_cells(index, key, atlas_dir):
    """Layers of what the game shows for `key` without its PNG: old PNG cells, else the SVG icon of the base key."""
    base = key.split("@")[0]
    e = index["png"].get(key) or index["icons"].get(key) or index["icons"].get(base)
    if not e:
        return None
    out = []
    for L in e["layers"]:
        p = _atlas_path(atlas_dir, L["sheet"])
        if not os.path.exists(p):
            return None
        out.append((L["layer"], Image.open(p).convert("RGBA").crop((L["x"], L["y"], L["x"] + CELL, L["y"] + CELL))))
    return out


# ------------------------------------------------------------------------------------------------ main

def run(root, dry_run=False, key_color=None, out_atlas=None, out_index=None, out_sheets=None, preview_path=None,
        quiet=False):
    """Packs art/icons/src of `root`. Returns (changed sheets, png index). Outputs default to the repo files."""
    src = os.path.join(root, "art", "icons", "src")
    atlas_dir = os.path.join(root, "art", "icons")
    index_path = os.path.join(root, "src", "shared", "Data", "ItemIconAtlas.luau")
    sheets_path = os.path.join(root, "src", "shared", "Data", "ItemIconSheets.luau")
    index = atlas_index.parse(index_path)
    svg_sheets = index["svg_sheets"]
    found = scan(src, index["icons"])
    png, images, freed, made = pack(found, index["png"], svg_sheets, atlas_dir, key_color)
    changed = []
    for n, img in images.items():
        p = _atlas_path(atlas_dir, n)
        old = Image.open(p).convert("RGBA") if os.path.exists(p) else None
        if old is None or not _same_pixels(old, img):
            changed.append(n)
    last = max(images) if images else svg_sheets
    stale = [n for n in range(last + 1, (index["sheets"] or svg_sheets) + 1) if n > svg_sheets]
    changed_keys = {}
    for key, cells in made.items():
        prev = _fallback_cells(index, key, atlas_dir) if key in index["png"] else None
        if prev is None or len(prev) != len(cells) or any(not _same_pixels(a[1], b[1]) for a, b in zip(prev, cells)):
            changed_keys[key] = cells
    if not quiet:
        print(f"Ikony PNG: {len(made)} kluczy, {sum(len(c) for c in made.values())} komórek, "
              f"atlasy PNG: {', '.join(f'items_{n}.png' for n in images) or 'brak'}")
        print(f"Zmienione ikony: {len(changed_keys)}, zwolnione komórki: {len(freed)}")
        print("Zmienione arkusze (atlasy): " + (", ".join(f"items_{n}.png" for n in changed) or "brak"))
        if stale:
            print("Niepotrzebne arkusze (do usunięcia): " + ", ".join(f"items_{n}.png" for n in stale))
    if preview_path is None:
        preview_path = os.path.join(root, "build", "icons", "import_preview.png")
    if changed_keys:
        before = {k: _fallback_cells(index, k, atlas_dir) for k in changed_keys}
        preview(changed_keys, before, preview_path, ["#B5ACA1", "#C5CCD3"])
        if not quiet:
            print(f"Podgląd: {os.path.relpath(preview_path, root)}")
    if dry_run:
        return changed, png
    out_atlas = out_atlas or atlas_dir
    for n in changed:
        save_png(images[n], _atlas_path(out_atlas, n))
    for n in stale:
        p = _atlas_path(out_atlas, n)
        if os.path.exists(p):
            os.remove(p)
    text = atlas_index.render_text(index["cell"], index["tiers"], index["icons"], svg_sheets, png, last)
    out_index = out_index or index_path
    old_text = open(out_index, encoding="utf-8").read() if os.path.exists(out_index) else None
    if png != index["png"] or last != index["sheets"] or old_text is None or "SVG_SHEETS" not in old_text:
        atlas_index.write(out_index, text)
    update_sheet_ids(out_sheets or sheets_path, changed, last, svg_sheets)
    if not quiet:
        _, waiting = check_ids(root, out_sheets or sheets_path, last, write_list=True)
        print("Wgraj: " + (", ".join(waiting) if waiting else "nic") + " (docs/ASSETS.md, „Ikony przedmiotów”)")
    return changed, png


def selftest():
    """Synthetic pictures packed into a copy under build/: fixed cells, determinism, common layer box, colour key."""
    root = os.path.abspath(os.path.join(HERE, "..", ".."))
    work = os.path.join(root, "build", "icons", "selftest")
    shutil.rmtree(work, ignore_errors=True)
    for sub in ("art/icons", "src/shared/Data"):
        os.makedirs(os.path.join(work, sub), exist_ok=True)
    for name in os.listdir(os.path.join(root, "art", "icons")):
        if name.endswith(".png"):
            shutil.copy(os.path.join(root, "art", "icons", name), os.path.join(work, "art", "icons", name))
    for name in ("ItemIconAtlas.luau", "ItemIconSheets.luau"):
        shutil.copy(os.path.join(root, "src", "shared", "Data", name), os.path.join(work, "src", "shared", "Data", name))
    index0 = atlas_index.parse(os.path.join(work, "src", "shared", "Data", "ItemIconAtlas.luau"))
    svg_bytes = {n: open(_atlas_path(os.path.join(work, "art", "icons"), n), "rb").read()
                 for n in range(1, index0["svg_sheets"] + 1)}
    src = os.path.join(work, "art", "icons", "src")
    for g in ("eq", "mat"):
        os.makedirs(os.path.join(src, g), exist_ok=True)
    tmp = tempfile.mkdtemp()
    # A sword with two layers: the metal is off-centre, the grip lower; both must share one crop box.
    m = Image.new("RGBA", (400, 300), (0, 0, 0, 0))
    ImageDraw.Draw(m).rectangle((50, 40, 120, 200), fill=(200, 200, 200, 255))
    b = Image.new("RGBA", (400, 300), (0, 0, 0, 0))
    ImageDraw.Draw(b).rectangle((60, 200, 110, 260), fill=(120, 70, 30, 255))
    m.save(os.path.join(src, "eq", "sword1h@35.m.png"))
    b.save(os.path.join(src, "eq", "sword1h@35.png"))
    k = Image.new("RGB", (300, 300), (255, 0, 255))
    ImageDraw.Draw(k).ellipse((100, 100, 200, 200), fill=(40, 160, 60))
    k.save(os.path.join(src, "mat", "wolf_pelt.png"))
    ok = True
    try:
        run(work, quiet=True)
        ok = False
        print("selftest: brak alfy bez --key powinien dać błąd")
    except PackError:
        pass
    changed, png = run(work, key_color=parse_key("magenta"), quiet=True)
    index1 = atlas_index.parse(os.path.join(work, "src", "shared", "Data", "ItemIconAtlas.luau"))
    for n, data in svg_bytes.items():
        if open(_atlas_path(os.path.join(work, "art", "icons"), n), "rb").read() != data:
            ok = False
            print(f"selftest: arkusz SVG items_{n}.png się zmienił")
    if index1["icons"] != index0["icons"]:
        ok = False
        print("selftest: ICONS się zmieniły")
    sword = png.get("eq/sword1h@35")
    if not sword or [L["layer"] for L in sword["layers"]] != ["m", "b"]:
        ok = False
        print("selftest: zła kolejność warstw eq/sword1h@35")
    sheet = Image.open(_atlas_path(os.path.join(work, "art", "icons"), sword["layers"][0]["sheet"])).convert("RGBA")
    cm = sheet.crop((sword["layers"][0]["x"], sword["layers"][0]["y"], sword["layers"][0]["x"] + CELL,
                     sword["layers"][0]["y"] + CELL)).getchannel("A").getbbox()
    cb = sheet.crop((sword["layers"][1]["x"], sword["layers"][1]["y"], sword["layers"][1]["x"] + CELL,
                     sword["layers"][1]["y"] + CELL)).getchannel("A").getbbox()
    if not cm or not cb or not (cb[1] > CELL // 2 and cm[1] < CELL // 8):
        ok = False
        print(f"selftest: warstwy nie mają wspólnej ramki ({cm} / {cb})")
    pelt = png["mat/wolf_pelt"]["layers"][0]
    corner = sheet if pelt["sheet"] == sword["layers"][0]["sheet"] else Image.open(
        _atlas_path(os.path.join(work, "art", "icons"), pelt["sheet"])).convert("RGBA")
    if corner.getpixel((pelt["x"] + 2, pelt["y"] + 2))[3] != 0 or corner.getpixel((pelt["x"] + 64, pelt["y"] + 64))[3] != 255:
        ok = False
        print("selftest: klucz kolorem nie usunął tła")
    before = {n: open(_atlas_path(os.path.join(work, "art", "icons"), n), "rb").read() for n in changed}
    again, _ = run(work, key_color=parse_key("FF00FF"), quiet=True)
    if again:
        ok = False
        print(f"selftest: drugi przebieg zmienił arkusze {again}")
    for n, data in before.items():
        if open(_atlas_path(os.path.join(work, "art", "icons"), n), "rb").read() != data:
            ok = False
            print(f"selftest: items_{n}.png nie jest deterministyczny")
    # Removing a key frees (clears) its cells and keeps the others in place.
    os.remove(os.path.join(src, "mat", "wolf_pelt.png"))
    run(work, quiet=True)
    index2 = atlas_index.parse(os.path.join(work, "src", "shared", "Data", "ItemIconAtlas.luau"))
    if index2["png"].get("eq/sword1h@35") != png["eq/sword1h@35"] or "mat/wolf_pelt" in index2["png"]:
        ok = False
        print("selftest: usunięcie klucza przesunęło inne komórki")
    shutil.rmtree(tmp, ignore_errors=True)
    print("selftest: OK" if ok else "selftest: BŁĄD")
    return ok


def main():
    ap = argparse.ArgumentParser(description="Pakuje ikony PNG z art/icons/src do atlasów (S52).")
    ap.add_argument("--dry-run", action="store_true", help="tylko wypisz, co by się zmieniło (i zrób podgląd)")
    ap.add_argument("--key", help="kolor tła bez alfy do usunięcia: FF00FF, #FF00FF albo magenta")
    ap.add_argument("--selftest", action="store_true", help="sprawdza packer na sztucznych obrazkach w build/")
    ap.add_argument("--check-ids", action="store_true", help="sprawdza id atlasów w ItemIconSheets.luau (nic nie pisze)")
    a = ap.parse_args()
    if a.selftest:
        sys.exit(0 if selftest() else 1)
    root = os.getcwd()
    if not os.path.exists(os.path.join(root, "src", "shared", "Data", "ItemIconAtlas.luau")):
        sys.exit("Uruchom z katalogu repozytorium (D:\\Dev\\mmoBrainrotRoblox).")
    if a.check_ids:
        sheets = atlas_index.parse(os.path.join(root, "src", "shared", "Data", "ItemIconAtlas.luau"))["sheets"]
        errors, waiting = check_ids(root, sheets=sheets)
        for e in errors:
            print("Błąd: " + e)
        print(f"Wgrane: {sheets - len(waiting)}/{sheets} atlasów")
        print("Do wgrania: " + (", ".join(waiting) if waiting else "nic"))
        sys.exit(1 if errors else 0)
    try:
        run(root, dry_run=a.dry_run, key_color=parse_key(a.key))
    except PackError as e:
        sys.exit(f"Błąd:\n{e}")


if __name__ == "__main__":
    main()
