# Interface pictures (S119): the owner's Graphics folder (BRAKI-GRAFIK.md layout, tylko_2d/<folder>/...) -> atlases
# art/ui/ui_<atlas>_<NN>.png (128 px cells, one atlas family per category) and single pictures art/ui/single/*.jpg,
# the generated registry src/shared/Data/UiArt.luau, the state art/ui/ui_art.json and the id file
# src/shared/Data/UiArtSheets.luau ("" for new and changed files). Only Pillow (+ Lune for the game ids).
#   py -3 tools/icons/import_ui.py [--src <Graphics>] [--dry-run] [--prune] [--key FF00FF] [--ids ids.json]
#                                  [--only <folder>] [--report] [--check-ids] [--selftest]
# Key = the BRAKI path without tylko_2d/ and .png (umiejetnosci/<class>/skill_<id>.png -> umiejetnosci/skill_<id>),
# checked against the game (tools/icons/ids.luau, section "ui"); a file without a game id is rejected with a hint.
# Styles: tile (skills, effects, elements, profiles, guild: square crop, rounded corners), medal (class emblems,
# titles: cut to alpha, 4% margin), silhouette (hud, mapa: white with alpha, tinted in game), object (sklep,
# kosmetyki: like item icons; an opaque painted tile without --key is taken as a tile), single (portraits, bosses, dungeon banners, painted maps: JPEG, cropped to the ratio;
# maps must be square). Cells never move: a changed key keeps its cell, new keys go after the last used one, --prune
# clears the cells of keys whose file is gone. Two runs give the same bytes. The Graphics folder is read only.
import argparse
import difflib
import hashlib
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image, ImageDraw, ImageFilter, ImageStat  # noqa: E402

import atlas_index  # noqa: E402
import content_block  # noqa: E402
import import_graphics  # noqa: E402
import import_png  # noqa: E402

CELL, GRID, SIDE = 128, 8, 1024
PER_SHEET = GRID * GRID
MIN_SIDE = 256
JPEG_QUALITY = 90
ATLASES = ("skills", "status", "emblems", "hud", "map", "shop")
TINT_ATLASES = ("hud", "map")
PREVIEW_TINT = (201, 164, 92)
# Report group, folder, file name pattern (group 1 = game id), ids section, style, atlas or (w, h) of a single.
RULES = [
    ("umiejętności", "umiejetnosci", r"skill_(\w+)", "skills", "tile", "skills"),
    ("efekty", "efekty", r"effect_(\w+)", "effects", "tile", "status"),
    ("żywioły", "zywioly", r"element_(\w+)", "elements", "tile", "status"),
    ("profile", "profile", r"profile_(\w+)", "profiles", "tile", "status"),
    ("gildia", "gildia", r"guild_(\w+)", "guildSkills", "tile", "status"),
    ("herby klas", "klasy", r"class_(\w+)", "classes", "medal", "emblems"),
    ("portrety klas", "klasy", r"portrait_(\w+)", "classes", "single", (512, 768)),
    ("tytuły", "tytuly", r"title_(\w+)", "titles", "medal", "emblems"),
    ("menu HUD", "hud", r"menu_(\w+)", "menus", "silhouette", "hud"),
    ("puste sloty", "hud", r"slot_(\w+)", "slots", "silhouette", "hud"),
    ("HUD", "hud", r"(\w+)", "fixed.hud", "silhouette", "hud"),
    ("ikony mapy", "mapa", r"map_(\w+)", "fixed.map", "silhouette", "map"),
    ("usługi NPC", "mapa", r"service_(\w+)", "services", "silhouette", "map"),
    ("znaczniki", "mapa", r"mark_(\w+)", "marks", "silhouette", "map"),
    ("mapy malowane", "mapy", r"(\w+)", "maps", "painted", (1024, 1024)),
    ("sklep", "sklep", r"(\w+)", "shop", "object", "shop"),
    ("kosmetyki", "kosmetyki", r"(\w+)", "cosmetics", "object", "shop"),
    ("portrety bossów", "bossowie", r"boss_(\w+)", "bosses", "single", (512, 512)),
    ("banery lochów", "lochy", r"dungeon_(\w+)", "dungeonBosses", "single", (1024, 512)),
]
FOLDERS = sorted({r[1] for r in RULES})
# Never interface pictures of the game: item folders (import_graphics.py), Roblox store art (Creator Dashboard),
# layout templates for the painted maps.
SKIP_DIRS = {"_uklad", "szkic", "model"}
WIKI_OG = {"og_base": "base.png", "og_default_art": "default-art.png"}
OG_SIZE = (1200, 630)
MARGIN = {"medal": 0.04, "silhouette": 0.08, "object": 0.06}


class UiError(Exception):
    pass


# ------------------------------------------------------------------------------------------------ ids

def _section(ids, name):
    ui = ids.get("ui", {})
    if name.startswith("fixed."):
        return list(ui.get("fixed", {}).get(name[6:], []))
    v = ui.get(name, [])
    return list(v) if isinstance(v, (list, dict)) else []


def game_keys(ids):
    """{group: [keys]} of every key the game can ask for (report: keys in the game per group)."""
    out = {}
    for group, folder, pattern, section, _, _ in RULES:
        prefix = pattern.split("(")[0]
        out[group] = sorted(f"{folder}/{prefix}{i}" for i in _section(ids, section))
    return out


# ------------------------------------------------------------------------------------------------ mapping

class Mapping:
    def __init__(self):
        self.mapped = []  # (path, key, rule)
        self.rejected = []  # (path, reason, group)
        self.warnings = []
        self.files = {}  # group -> files seen
        self.blocked = []  # (path, key, why): content block list, never imported


def _rel(path, src):
    return os.path.relpath(path, src).replace(os.sep, "/")


def classify(folder, sub, base, ids):
    """(key, rule, None) or (None, group, reason) of tylko_2d/<folder>/[<sub>/]<base>.png."""
    rules = [r for r in RULES if r[1] == folder]
    first_reason = None
    for rule in rules:
        group, _, pattern, section, _, _ = rule
        m = re.fullmatch(pattern, base)
        if not m:
            continue
        gid = m.group(1)
        valid = _section(ids, section)
        if gid in valid:
            return f"{folder}/{base}", rule, None
        if first_reason is None and (pattern != r"(\w+)" or len(rules) == 1):
            first_reason = (group, f"nieznane id {gid!r} ({section})" + import_graphics._hint(gid, list(valid)))
    names = []
    for _, _, pattern, section, _, _ in rules:
        prefix = pattern.split("(")[0]
        names += [prefix + i for i in _section(ids, section)]
    if first_reason:
        return None, first_reason[0], first_reason[1]
    return None, rules[-1][0], "nazwa spoza wzorów folderu" + import_graphics._hint(base, names)


def _folder_group(folder):
    return next(r[0] for r in RULES if r[1] == folder)


def mapping(src, ids, only=None):
    res = Mapping()
    flat = os.path.join(src, "tylko_2d")
    for folder in FOLDERS:
        if only and folder != only:
            continue
        fdir = os.path.join(flat, folder)
        if not os.path.isdir(fdir):
            continue
        for dirpath, dirs, files in os.walk(fdir):
            dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
            for name in sorted(files):
                path = os.path.join(dirpath, name)
                base, ext = os.path.splitext(name)
                base = base.strip()
                sub = os.path.relpath(dirpath, fdir).replace(os.sep, "/")
                if ext.lower() != ".png":
                    res.rejected.append((path, "inny format (tylko .png)", _folder_group(folder)))
                    continue
                if import_graphics.COPY.search(base):
                    res.rejected.append((path, f"kopia albo inna wersja (gra bierze "
                                               f"{import_graphics.COPY.sub('', base)}.png)", _folder_group(folder)))
                    continue
                key, rule, reason = classify(folder, sub, base, ids)
                if key is None:
                    res.rejected.append((path, reason, rule))
                    continue
                if folder == "umiejetnosci":
                    gid = re.fullmatch(r"skill_(\w+)", base).group(1)
                    cls = ids["ui"]["skills"].get(gid)
                    if sub not in (".", cls):
                        res.warnings.append(f"{_rel(path, src)}: umiejętność klasy {cls} w folderze {sub}")
                elif sub != ".":
                    res.warnings.append(f"{_rel(path, src)}: podfolder {sub} (klucz {key})")
                res.mapped.append((path, key, rule))
    by_key = {}
    for path, key, rule in res.mapped:
        by_key.setdefault(key, []).append((path, rule))
    out = []
    for key, entries in by_key.items():
        if len(entries) > 1:
            hashes = {pixel_hash(load_rgba(p)) for p, _ in entries}
            rels = [_rel(p, src) for p, _ in entries]
            if len(hashes) > 1:
                raise UiError(f"{key}: dwa różne obrazki: {', '.join(rels)}")
            res.warnings.append(f"{key}: duplikat ({', '.join(rels)}), biorę {rels[0]}")
        out.append((entries[0][0], key, entries[0][1]))
    res.mapped = sorted(out, key=lambda e: e[1])
    return res


# ------------------------------------------------------------------------------------------------ pictures

def load_rgba(path):
    img = Image.open(path)
    img.load()
    if img.mode == "P" and "transparency" in img.info:
        img = img.convert("RGBA")
    return img


def pixel_hash(img):
    h = hashlib.sha1()
    h.update(f"{img.mode}{img.size}".encode())
    h.update(img.tobytes())
    return h.hexdigest()[:12]


def _sharpen(img):
    rgb = img.convert("RGB").filter(ImageFilter.UnsharpMask(radius=0.8, percent=40, threshold=2))
    if img.mode == "RGBA":
        return Image.merge("RGBA", (*rgb.split(), img.getchannel("A")))
    return rgb


def _center_square(img):
    w, h = img.size
    s = min(w, h)
    return img.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))


def _round_mask(size, radius):
    big = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=radius * 4, fill=255)
    return big.resize((size, size), Image.LANCZOS)


def fit_tile(img, warnings, label):
    """Painted square tile: no alpha crop, centre square, 128 px, rounded corners (radius 10%)."""
    if min(img.size) < MIN_SIDE:
        raise UiError(f"obrazek {img.size[0]}x{img.size[1]} px, potrzeba boku >= {MIN_SIDE} px")
    if import_png._has_alpha(img.convert("RGBA") if img.mode != "RGBA" else img):
        warnings.append(f"{label}: kafelek z przezroczystością (nie wypełnia kwadratu), przyjęty bez zmian")
    sq = _center_square(img.convert("RGBA"))
    small = sq.convert("RGBa").resize((CELL, CELL), Image.LANCZOS).convert("RGBA")
    small = _sharpen(small)
    mask = _round_mask(CELL, int(round(CELL * 0.10)))
    alpha = _mul(small.getchannel("A"), mask)
    out = Image.merge("RGBA", (*small.convert("RGB").split(), alpha))
    return import_png._clear_rgb(out)


def fit_icon(img, margin, key_color, label):
    """Object on a transparent background: cut to its alpha box, square with a margin, 128 px (Lanczos on
    premultiplied alpha), light sharpening."""
    if min(img.size) < MIN_SIDE:
        raise UiError(f"obrazek {img.size[0]}x{img.size[1]} px, potrzeba boku >= {MIN_SIDE} px")
    if not import_png._has_alpha(img):
        if not key_color:
            raise UiError("brak przezroczystości (kanału alfa); zapisz PNG z alfą albo użyj --key FF00FF")
        img = import_png._keyed(img, key_color)
        if import_png._border_clear(img) < 0.5:
            raise UiError("brak przezroczystości (tło nie ma koloru klucza: szachownica albo jednolite tło)")
    img = img.convert("RGBA")
    box = img.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
    if box is None:
        raise UiError("obrazek jest cały przezroczysty")
    bw, bh = box[2] - box[0], box[3] - box[1]
    side = int(round(max(bw, bh) / (1 - 2 * margin)))
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(img.crop(box), ((side - bw) // 2, (side - bh) // 2))
    small = sq.convert("RGBa").resize((CELL, CELL), Image.LANCZOS).convert("RGBA")
    return import_png._clear_rgb(_sharpen(small))


def to_silhouette(cell, warnings, label):
    """White with the alpha of the picture (the game tints it with ImageColor3). A silhouette that is not plain white
    keeps its inner detail: alpha *= brightness (warning)."""
    a = cell.getchannel("A")
    lum = cell.convert("RGB").convert("L")
    mask = a.point(lambda v: 255 if v > 128 else 0)
    mean = ImageStat.Stat(lum, mask).mean[0] if mask.getbbox() else 255
    if mean < 230:
        warnings.append(f"{label}: sylwetka nie jest biała (jasność {mean:.0f}), alfa z jasności")
        a = _mul(a, lum)
    white = Image.new("L", cell.size, 255)
    return import_png._clear_rgb(Image.merge("RGBA", (white, white, white, a)))


def _mul(a, b):
    """a * b / 255 per pixel (L images)."""
    from PIL import ImageChops
    return ImageChops.multiply(a, b)


def fit_box(img, w, h, exact_square=False):
    """Opaque picture of w x h: crop to the ratio from the centre, Lanczos and light sharpening when scaled."""
    iw, ih = img.size
    if exact_square and iw != ih:
        raise UiError(f"mapa {iw}x{ih} px: musi być kwadratowa (kadr = viewBox mapy, bez przycinania)")
    if min(iw, ih) < min(w, h) // 2:
        raise UiError(f"obrazek {iw}x{ih} px za mały (cel {w}x{h})")
    img = img.convert("RGB")
    target = w / h
    if abs(iw / ih - target) > 1e-3:
        if iw / ih > target:
            nw = int(round(ih * target))
            img = img.crop(((iw - nw) // 2, 0, (iw - nw) // 2 + nw, ih))
        else:
            nh = int(round(iw / target))
            img = img.crop((0, (ih - nh) // 2, iw, (ih - nh) // 2 + nh))
    if img.size != (w, h):
        img = _sharpen(img.resize((w, h), Image.LANCZOS))
    return img


def process(path, rule, key_color, warnings, label):
    """Processed picture of one file (128 px cell RGBA or a single RGB image)."""
    _, _, _, _, style, target = rule
    img = load_rgba(path)
    if style == "tile":
        return fit_tile(img, warnings, label)
    if style in ("single", "painted"):
        w, h = target
        return fit_box(img, w, h, exact_square=style == "painted")
    if style == "object" and not key_color and not import_png._has_alpha(img):
        # Shop and cosmetic prompts (BRAKI-GRAFIK-4) ask for full painted tiles: same as the skill tiles.
        return fit_tile(img, warnings, label)
    cell = fit_icon(img, MARGIN[style], key_color, label)
    if style == "silhouette":
        cell = to_silhouette(cell, warnings, label)
    return cell


# ------------------------------------------------------------------------------------------------ state

def atlas_file(atlas, n):
    return f"ui_{atlas}_{n:02d}.png"


def single_file(key):
    folder, name = key.split("/", 1)
    return f"{folder}__{name}.jpg"


def load_state(path):
    if os.path.exists(path):
        return json.load(open(path, encoding="utf-8"))
    return {"cells": {}, "singles": {}, "sheets": {}, "frames": {}}


def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(data, indent=1, sort_keys=True, ensure_ascii=False) + "\n")


def save_jpeg(img, path):
    img.save(path, format="JPEG", quality=JPEG_QUALITY, optimize=True, progressive=False, subsampling=0)


def _cell_xy(i):
    j = i % PER_SHEET
    return i // PER_SHEET + 1, (j % GRID) * CELL, (j // GRID) * CELL


# ------------------------------------------------------------------------------------------------ map frames

def map_frame(root, map_id, report):
    """{x0, z0, size} of a painted map from the wiki SVG viewBox (square circumscribed on it), then the override
    file tools/icons/map_frames_override.json when it has the map."""
    over = os.path.join(root, "tools", "icons", "map_frames_override.json")
    if os.path.exists(over):
        data = json.load(open(over, encoding="utf-8"))
        if map_id in data:
            f = data[map_id]
            return {"x0": f["x0"], "z0": f["z0"], "size": f["size"]}
    svg = os.path.join(root, "wiki", "public", "img", "maps", f"{map_id}.svg")
    if not os.path.exists(svg):
        raise UiError(f"brak wiki/public/img/maps/{map_id}.svg (kadr mapy): uruchom `lune run tools/wikimap.luau`")
    head = open(svg, encoding="utf-8").read(4000)
    m = re.search(r'viewBox="\s*([-\d.]+)\s+([-\d.]+)\s+([\d.]+)\s+([\d.]+)\s*"', head)
    if not m:
        raise UiError(f"{map_id}.svg: brak viewBox")
    x, y, w, h = (float(v) for v in m.groups())
    size = max(w, h)
    if w != h:
        report.append(f"- `{map_id}`: viewBox {w:g}x{h:g} nie jest kwadratem, kadr = kwadrat opisany")
    x0, z0 = x + (w - size) / 2, y + (h - size) / 2

    def num(v):
        return int(v) if float(v).is_integer() else v
    return {"x0": num(x0), "z0": num(z0), "size": num(size)}


# ------------------------------------------------------------------------------------------------ output files

def render_registry(state, ids=None):
    cells, singles, frames = state["cells"], state["singles"], state["frames"]
    if ids is not None:
        # a cell keeps its place in the atlas when its key leaves the game (cells never move), but the registry only
        # lists keys the game can still ask for (W10: skills retired in S142 kept their cells)
        valid = {k for ks in game_keys(ids).values() for k in ks}
        cells = {k: v for k, v in cells.items() if k in valid}
        singles = {k: v for k, v in singles.items() if k in valid}
    lines = [
        "--!strict",
        "-- GENERATED by tools/icons/import_ui.py (S119), do not edit. Interface pictures of the owner's Graphics folder:",
        "-- ICONS = cells of the atlases art/ui/ui_<atlas>_<NN>.png (key = the BRAKI-GRAFIK path without tylko_2d/ and .png),",
        "-- SINGLES = single pictures art/ui/single/<file>, MAP_FRAMES = map-relative square of a painted map (studs).",
        "-- Asset ids live in Data/UiArtSheets; keys and lookups only through Logic/UiArt.",
        "",
        "export type Cell = { atlas: string, s: number, x: number, y: number, h: string }",
        "export type Single = { file: string, w: number, h: number, hash: string }",
        "export type Frame = { x0: number, z0: number, size: number }",
        "",
        "local ICONS: { [string]: Cell } = {",
    ]
    for key in sorted(cells):
        c = cells[key]
        s, x, y = _cell_xy(c["i"])
        lines.append(f'\t["{key}"] = {{ atlas = "{c["atlas"]}", s = {s}, x = {x}, y = {y}, h = "{c["h"]}" }},')
    lines += ["}", "", "local SINGLES: { [string]: Single } = {"]
    for key in sorted(singles):
        e = singles[key]
        lines.append(f'\t["{key}"] = {{ file = "{e["file"]}", w = {e["w"]}, h = {e["h"]}, hash = "{e["hash"]}" }},')
    lines += ["}", "", "local MAP_FRAMES: { [string]: Frame } = {"]
    for map_id in sorted(frames):
        f = frames[map_id]
        lines.append(f'\t["{map_id}"] = {{ x0 = {f["x0"]}, z0 = {f["z0"]}, size = {f["size"]} }},')
    lines += ["}", "", "local ATLASES: { [string]: { string } } = {"]
    sheets = sheet_files(state)
    for atlas in ATLASES:
        files = sheets.get(atlas, [])
        if files:
            lines.append(f'\t{atlas} = {{ {", ".join(f"{chr(34)}{f}{chr(34)}" for f in files)} }},')
    lines += ["}", "", "local SHEET_HASH: { [string]: string } = {"]
    for f in sorted(state["sheets"]):
        lines.append(f'\t["{f}"] = "{state["sheets"][f]}",')
    lines += ["}", "", "return table.freeze({", "\tCELL = 128,", "\tATLASES = ATLASES,", "\tSHEET_HASH = SHEET_HASH,",
              "\tICONS = ICONS,", "\tSINGLES = SINGLES,", "\tMAP_FRAMES = MAP_FRAMES,", "})", ""]
    return "\n".join(lines)


def sheet_files(state):
    out = {}
    for c in state["cells"].values():
        n = c["i"] // PER_SHEET + 1
        out.setdefault(c["atlas"], set()).add(n)
    return {a: [atlas_file(a, n) for n in range(1, max(ns) + 1)] for a, ns in out.items()}


SHEETS_HEADER = [
    "--!strict",
    "-- Asset ids of the interface pictures (S119): one row per file of art/ui (atlases ui_<atlas>_<NN>.png and the single",
    "-- pictures single/<folder>__<name>.jpg), key = file name. Filled in after the upload (MCP upload_image or the owner's",
    "-- Bulk Import, docs/ANIMACJE.md \"Grafiki interfejsu (S119)\"). tools/icons/import_ui.py writes \"\" for every new or",
    "-- changed file and keeps the other rows; an empty id = not uploaded yet, so the UI keeps its glyphs for that file.",
    "",
]
ROW = re.compile(r'^\t\["([^"]+)"\] = "([^"]*)",\s*$')


def read_sheet_ids(path):
    out = {}
    if not os.path.exists(path):
        return out
    for ln in open(path, encoding="utf-8").read().split("\n"):
        m = ROW.match(ln)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def write_sheet_ids(path, files, changed):
    """Rows for `files` (sorted): kept ids, "" for changed and new ones; rows of files gone are dropped."""
    old = read_sheet_ids(path)
    lines = list(SHEETS_HEADER)
    if files:
        lines.append("local SHEETS: { [string]: string } = {")
        for f in sorted(files):
            v = "" if f in changed else old.get(f, "")
            lines.append(f'\t["{f}"] = "{v}",')
        lines.append("}")
    else:
        lines.append("local SHEETS: { [string]: string } = {}")
    lines += ["", "return table.freeze(SHEETS)", ""]
    text = "\n".join(lines)
    if not os.path.exists(path) or open(path, encoding="utf-8").read() != text:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)


def all_files(state):
    files = []
    for fs in sheet_files(state).values():
        files += fs
    files += [e["file"] for e in state["singles"].values()]
    return sorted(files)


def check_ids(root, write_list=False, quiet=False):
    """(errors, waiting): every file of the registry has one row "" or rbxassetid://<digits>, files exist."""
    state = load_state(os.path.join(root, "art", "ui", "ui_art.json"))
    ids = read_sheet_ids(os.path.join(root, "src", "shared", "Data", "UiArtSheets.luau"))
    errors, waiting = [], []
    files = all_files(state)
    for f in files:
        sub = "single" if f.endswith(".jpg") else ""
        if not os.path.exists(os.path.join(root, "art", "ui", sub, f)):
            errors.append(f"{f}: brak pliku w art/ui")
        if f not in ids:
            errors.append(f"{f}: brak wiersza w UiArtSheets.luau")
        elif ids[f] == "":
            waiting.append(f)
        elif not re.fullmatch(r"rbxassetid://\d+", ids[f]):
            errors.append(f"{f}: złe id {ids[f]!r} (tylko rbxassetid://<cyfry>)")
    for f in ids:
        if f not in files:
            errors.append(f"{f}: wiersz bez pliku w rejestrze")
    if write_list:
        out = os.path.join(root, "build", "ui", "do_wgrania.txt")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8", newline="\n") as fh:
            for f in waiting:
                sub = "single" if f.endswith(".jpg") else ""
                fh.write(os.path.join(root, "art", "ui", sub, f) + "\n")
    return errors, waiting, len(files)


# ------------------------------------------------------------------------------------------------ preview

def preview(changed_cells, changed_singles, path):
    from preview import BG, FONT
    rows = list(changed_cells.items())
    cols, slot, lab = 8, 64, 16
    W = 20 + cols * (slot + 40 + 50)
    H = 20 + ((len(rows) + cols - 1) // cols) * (slot + lab + 14)
    thumbs = list(changed_singles.items())
    H += 20 + ((len(thumbs) + 5) // 6) * (180 + lab + 10)
    img = Image.new("RGBA", (W, max(H, 60)), BG + (255,))
    d = ImageDraw.Draw(img)
    for i, (key, (atlas, cell)) in enumerate(rows):
        x = 20 + (i % cols) * (slot + 90)
        y = 14 + (i // cols) * (slot + lab + 14)
        pic = cell
        if atlas in TINT_ATLASES:
            tinted = Image.new("RGBA", cell.size, PREVIEW_TINT + (255,))
            tinted.putalpha(cell.getchannel("A"))
            pic = tinted
        d.rounded_rectangle((x - 2, y - 2, x + 58, y + 58), radius=6, fill=(40, 44, 54))
        img.alpha_composite(pic.resize((56, 56), Image.LANCZOS), (x, y))
        img.alpha_composite(pic.resize((28, 28), Image.LANCZOS), (x + 64, y + 14))
        d.text((x, y + slot - 4), key.split("/", 1)[1][:22], font=FONT, fill=(216, 204, 176))
    y0 = 20 + ((len(rows) + cols - 1) // cols) * (slot + lab + 14)
    for i, (key, pic) in enumerate(thumbs):
        x = 20 + (i % 6) * 200
        y = y0 + (i // 6) * (180 + lab + 10)
        t = pic.copy()
        t.thumbnail((180, 180))
        img.paste(t, (x, y))
        d.text((x, y + 182), key, font=FONT, fill=(216, 204, 176))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.convert("RGB").save(path)


# ------------------------------------------------------------------------------------------------ BRAKI lists

def braki_paths(src):
    """Interface picture paths (tylko_2d/<folder>/...png) named in the owner's BRAKI-GRAFIK*.md files."""
    out = set()
    for name in ("BRAKI-GRAFIK.md", "BRAKI-GRAFIK-2.md"):
        p = os.path.join(src, name)
        if os.path.exists(p):
            for m in re.finditer(r"tylko_2d/([A-Za-z0-9_/]+)\.png", open(p, encoding="utf-8").read()):
                parts = m.group(1).split("/")
                if parts[0] in FOLDERS and not any(x in SKIP_DIRS for x in parts):
                    out.add("/".join(parts))
    return out


def key_of_braki(path):
    parts = path.split("/")
    return f"{parts[0]}/{parts[-1]}"


# ------------------------------------------------------------------------------------------------ main run

def run(root, src, ids, dry_run=False, prune=False, key_color=None, only=None, quiet=False, blocks=None):
    """Imports `src` into art/ui of `root`. Returns a dict (changed files, mapping, report lines). `blocks`: content
    block list (content_block.load(); default: tools/icons/content_block.json): a blocked key is removed even without
    --prune."""
    out_dir = os.path.join(root, "art", "ui")
    single_dir = os.path.join(out_dir, "single")
    state_path = os.path.join(out_dir, "ui_art.json")
    reg_path = os.path.join(root, "src", "shared", "Data", "UiArt.luau")
    ids_path = os.path.join(root, "src", "shared", "Data", "UiArtSheets.luau")
    build = os.path.join(root, "build", "ui")
    state = load_state(state_path)
    old_state = json.loads(json.dumps(state))
    res = mapping(src, ids, only)
    if blocks is None:
        blocks = content_block.load()
    res.mapped, blocked, block_warnings = content_block.split(res.mapped, src, blocks)
    res.blocked = [(p, k, why) for (p, k, _), why in blocked]
    res.warnings += block_warnings
    blocked_keys = {k for _, k, _ in res.blocked} - {k for _, k, _ in res.mapped}
    report_frames = []
    pics = {}
    accepted = []
    failed = set()
    for path, key, rule in res.mapped:
        try:
            pics[key] = process(path, rule, key_color, res.warnings, _rel(path, src))
            accepted.append((path, key, rule))
        except (UiError, import_png.PackError) as e:
            res.rejected.append((path, str(e), rule[0]))
            failed.add(key)
    res.mapped = accepted
    mapped = {key: (path, rule) for path, key, rule in accepted}
    in_scope = (lambda k: k.split("/", 1)[0] == only) if only else (lambda k: True)

    # Cells, atlas by atlas.
    changed_cells = {}
    freed = {a: set() for a in ATLASES}
    cells = state["cells"]
    for key in list(cells):
        if in_scope(key) and key not in mapped and key not in failed and (prune or key in blocked_keys):
            freed[cells[key]["atlas"]].add(cells[key]["i"])
            del cells[key]
    for atlas in ATLASES:
        used = {c["i"] for c in cells.values() if c["atlas"] == atlas}
        nxt = max(used) + 1 if used else 0
        for key in sorted(k for k, (_, r) in mapped.items() if r[5] == atlas):
            img = pics[key]
            h = pixel_hash(img)
            src_rel = _rel(mapped[key][0], src)
            if key in cells:
                if cells[key]["h"] == h:
                    cells[key]["src"] = src_rel
                    continue
                cells[key].update({"h": h, "src": src_rel})
            else:
                cells[key] = {"atlas": atlas, "i": nxt, "h": h, "src": src_rel}
                nxt += 1
            changed_cells[key] = (atlas, img)
            freed[atlas].discard(cells[key]["i"])
    changed_files = set()
    images = {}
    for atlas in ATLASES:
        indices = [c["i"] for c in cells.values() if c["atlas"] == atlas] + list(freed[atlas])
        if not indices:
            continue
        last = max(c["i"] for c in cells.values() if c["atlas"] == atlas) if any(
            c["atlas"] == atlas for c in cells.values()) else -1
        for n in range(1, last // PER_SHEET + 2 if last >= 0 else 1):
            p = os.path.join(out_dir, atlas_file(atlas, n))
            images[(atlas, n)] = Image.open(p).convert("RGBA") if os.path.exists(p) else \
                Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
        blank = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        for i in freed[atlas]:
            s, x, y = _cell_xy(i)
            if (atlas, s) in images:
                images[(atlas, s)].paste(blank, (x, y))
        for key, (a, img) in changed_cells.items():
            if a == atlas:
                s, x, y = _cell_xy(cells[key]["i"])
                images[(atlas, s)].paste(img, (x, y))
    sheets = {}
    for (atlas, n), img in images.items():
        name = atlas_file(atlas, n)
        p = os.path.join(out_dir, name)
        old = Image.open(p).convert("RGBA") if os.path.exists(p) else None
        sheets[name] = pixel_hash(img)
        if old is None or not import_png._same_pixels(old, img):
            changed_files.add(name)
    stale_sheets = [f for f in old_state.get("sheets", {}) if f not in sheets]
    state["sheets"] = sheets

    # Singles.
    singles = state["singles"]
    changed_singles = {}
    for key in list(singles):
        if in_scope(key) and key not in mapped and key not in failed and (prune or key in blocked_keys):
            del singles[key]
    for key, (path, rule) in sorted(mapped.items()):
        style = rule[4]
        if style not in ("single", "painted"):
            continue
        img = pics[key]
        h = pixel_hash(img)
        file = single_file(key)
        entry = {"file": file, "w": img.size[0], "h": img.size[1], "hash": h, "src": _rel(path, src)}
        if singles.get(key, {}).get("hash") == h and os.path.exists(os.path.join(single_dir, file)):
            singles[key]["src"] = entry["src"]
            continue
        singles[key] = entry
        changed_singles[key] = img
        changed_files.add(file)
    stale_singles = [e["file"] for k, e in old_state.get("singles", {}).items() if k not in singles]

    # Painted map frames.
    frames = {}
    for key in singles:
        if key.startswith("mapy/"):
            map_id = key.split("/", 1)[1]
            if map_id == "world":
                continue  # no world view in the game (S119 E4): the picture waits in the registry
            frames[map_id] = map_frame(root, map_id, report_frames)
    state["frames"] = frames

    # Wiki share pictures (H3): only when the owner's files differ from the wiki's.
    wiki_written = []
    if not only or only == "wiki":
        for base, target in WIKI_OG.items():
            p = os.path.join(src, "tylko_2d", "wiki", base + ".png")
            if not os.path.exists(p):
                continue
            img = fit_box(load_rgba(p), *OG_SIZE)
            t = os.path.join(root, "wiki", "public", "img", "og", target)
            if os.path.exists(t) and import_png._same_pixels(Image.open(t).convert("RGB"), img):
                continue
            wiki_written.append(target)
            if not dry_run:
                os.makedirs(os.path.dirname(t), exist_ok=True)
                img.save(t, format="PNG", optimize=True)

    lines = report(res, src, ids, state, changed_files, report_frames, wiki_written)
    os.makedirs(build, exist_ok=True)
    with open(os.path.join(build, "import_ui.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    if changed_cells or changed_singles:
        preview(changed_cells, changed_singles, os.path.join(build, "import_preview.png"))
    if not quiet:
        print("\n".join(lines))
        print(f"\nRaport: {os.path.relpath(os.path.join(build, 'import_ui.md'), root)}")
        if changed_cells or changed_singles:
            print(f"Podgląd: {os.path.relpath(os.path.join(build, 'import_preview.png'), root)}")
    result = {"changed": sorted(changed_files), "mapping": res, "lines": lines, "state": state}
    if dry_run:
        return result
    os.makedirs(single_dir, exist_ok=True)
    for (atlas, n), img in images.items():
        name = atlas_file(atlas, n)
        if name in changed_files:
            import_png.save_png(img, os.path.join(out_dir, name))
    for name in stale_sheets:
        p = os.path.join(out_dir, name)
        if os.path.exists(p):
            os.remove(p)
    for key, img in changed_singles.items():
        save_jpeg(img, os.path.join(single_dir, singles[key]["file"]))
    for name in stale_singles:
        p = os.path.join(single_dir, name)
        if os.path.exists(p):
            os.remove(p)
    save_json(state_path, state)
    text = render_registry(state, ids)
    old_text = open(reg_path, encoding="utf-8").read() if os.path.exists(reg_path) else None
    if state != old_state or old_text is None or "GENERATED by tools/icons/import_ui.py" not in old_text:
        atlas_index.write(reg_path, text)
    write_sheet_ids(ids_path, all_files(state), changed_files)
    if not quiet:
        _, waiting, total = check_ids(root, write_list=True)
        print(f"Wgraj ({len(waiting)}/{total}): " + (", ".join(waiting) if waiting else "nic")
              + " (docs/ANIMACJE.md, „Grafiki interfejsu (S119)”; lista: build/ui/do_wgrania.txt)")
    return result


def report(res, src, ids, state, changed, frame_notes, wiki_written):
    keys = game_keys(ids)
    have = set(state["cells"]) | set(state["singles"])
    files, matched, rejected = {}, {}, {}
    for _, key, rule in res.mapped:
        files[rule[0]] = files.get(rule[0], 0) + 1
        matched[rule[0]] = matched.get(rule[0], 0) + 1
    for _, _, group in res.rejected:
        g = group
        files[g] = files.get(g, 0) + 1
        rejected[g] = rejected.get(g, 0) + 1
    out = ["# Import grafik interfejsu (tools/icons/import_ui.py)", ""]
    out.append(f"Pliki: {len(res.mapped)} dopasowanych, {len(res.rejected)} odrzuconych; zmienione pliki gry: "
               f"{len(changed)}.")
    out += ["", "| Kategoria | Plików | Dopasowanych | Odrzuconych | Kluczy w grze | Z obrazkiem |", "|---|---|---|---|---|---|"]
    for group, *_ in RULES:
        n = len(keys.get(group, []))
        with_pic = sum(1 for k in keys.get(group, []) if k in have)
        out.append(f"| {group} | {files.get(group, 0)} | {matched.get(group, 0)} | {rejected.get(group, 0)} | {n} | "
                   f"{with_pic} |")
    if res.rejected:
        out += ["", "## Odrzucone"]
        out += [f"- `{_rel(p, src)}`: {r}" for p, r, _ in res.rejected]
    if res.blocked:
        out += ["", "## Zablokowane (treść, tools/icons/content_block.json; gra bierze zapas)"]
        out += [f"- `{_rel(p, src)}` (`{k}`): {why}" for p, k, why in res.blocked]
    if res.warnings:
        out += ["", "## Ostrzeżenia"]
        out += [f"- {w}" for w in res.warnings]
    if frame_notes:
        out += ["", "## Kadr map"] + frame_notes
    braki = braki_paths(src)
    if braki:
        present = {_rel(p, os.path.join(src, "tylko_2d")) for p, _, _ in res.mapped}
        missing = sorted(b for b in braki if b + ".png" not in {x for x in present} and key_of_braki(b) not in have)
        out += ["", f"## Z BRAKI-GRAFIK, jeszcze bez pliku ({len(missing)})"]
        by_folder = {}
        for b in missing:
            by_folder.setdefault(b.split("/")[0], []).append(b.split("/")[-1])
        for folder, names in sorted(by_folder.items()):
            out.append(f"- `{folder}` ({len(names)}): {', '.join(names)}")
        prompted = {key_of_braki(b) for b in braki}
        no_prompt = {}
        for group, ks in keys.items():
            for k in ks:
                if k not in prompted and k not in have:
                    no_prompt.setdefault(group, []).append(k.split("/", 1)[1])
        out += ["", "## Klucze gry bez promptu w BRAKI (zostają znakami)"]
        for group, names in no_prompt.items():
            out.append(f"- {group} ({len(names)}): {', '.join(names)}")
    unused = [k for k in state["singles"] if k == "mapy/world"]
    if unused:
        out += ["", "## W rejestrze, bez miejsca w grze", "- `mapy/world`: gra nie ma widoku całego świata (S119 E4)"]
    if wiki_written:
        out += ["", "## Wiki", f"- obrazki udostępniania: {', '.join(wiki_written)} (wiki/public/img/og)"]
    return out


# ------------------------------------------------------------------------------------------------ selftest

SELFTEST_IDS = {
    "ui": {
        "skills": {"charge": "warrior", "heal": "cleric"},
        "effects": ["stun", "burn"],
        "elements": ["fire"],
        "profiles": ["exp"],
        "guildSkills": ["luck"],
        "classes": ["warrior", "mage"],
        "titles": ["wanderer"],
        "slots": ["ring", "weapon"],
        "menus": ["map"],
        "maps": ["meadows", "world"],
        "marks": ["flag"],
        "services": ["shop"],
        "cosmetics": ["pet_fox"],
        "shop": ["pass_vip", "shards_100"],
        "bosses": ["grimrok"],
        "dungeonBosses": ["grimrok"],
        "fixed": {"hud": ["pvp", "lock"], "map": ["portal", "npc"]},
    }
}


def _tile(path, color, size=512):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = Image.new("RGB", (size, size), (20, 20, 30))
    ImageDraw.Draw(img).ellipse((size // 4, size // 4, size * 3 // 4, size * 3 // 4), fill=color)
    img.save(path)


def _alpha(path, color, size=512, w=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = Image.new("RGBA", (w or size, size), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse((size // 4, size // 4, size * 3 // 4, size * 3 // 4), fill=color + (255,))
    img.save(path)


def selftest():
    root_repo = os.path.abspath(os.path.join(HERE, "..", ".."))
    work = os.path.join(root_repo, "build", "ui", "selftest")
    shutil.rmtree(work, ignore_errors=True)
    src = os.path.join(work, "Graphics")
    root = os.path.join(work, "repo")
    for sub in ("art/ui", "src/shared/Data", "wiki/public/img/maps", "build"):
        os.makedirs(os.path.join(root, sub), exist_ok=True)
    with open(os.path.join(root, "wiki", "public", "img", "maps", "meadows.svg"), "w", encoding="utf-8") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-800 -800 1600 1600"></svg>')
    t = os.path.join(src, "tylko_2d")
    _tile(os.path.join(t, "umiejetnosci", "warrior", "skill_charge.png"), (200, 60, 40))
    _tile(os.path.join(t, "umiejetnosci", "mage", "skill_heal.png"), (60, 200, 40))  # wrong class folder: warning
    _tile(os.path.join(t, "umiejetnosci", "warrior", "skill_chrage.png"), (60, 60, 40))  # typo: hint charge
    _tile(os.path.join(t, "efekty", "effect_stun.png"), (220, 220, 60))
    _tile(os.path.join(t, "efekty", "effect_dazzle.png"), (220, 220, 60))  # unknown effect
    _tile(os.path.join(t, "efekty", "effect_burn (1).png"), (220, 0, 0))  # copy
    _alpha(os.path.join(t, "klasy", "class_warrior.png"), (180, 140, 60))
    _tile(os.path.join(t, "klasy", "class_paladin.png"), (180, 140, 60))  # unknown class
    _alpha(os.path.join(t, "hud", "pvp.png"), (40, 40, 40))  # dark silhouette: alpha from brightness, warning
    _alpha(os.path.join(t, "hud", "slot_ring.png"), (255, 255, 255))
    _alpha(os.path.join(t, "mapa", "map_portal.png"), (255, 255, 255))
    _tile(os.path.join(t, "mapa", "service_shop.png"), (255, 255, 255))  # no alpha: rejected
    _alpha(os.path.join(t, "sklep", "pass_vip.png"), (230, 200, 90))
    _tile(os.path.join(t, "mapy", "meadows.png"), (60, 120, 60), size=600)
    _alpha(os.path.join(t, "mapy", "world.png"), (60, 120, 60), size=600, w=800)  # not square: rejected
    _tile(os.path.join(t, "bossowie", "boss_grimrok.png"), (120, 40, 40), size=700)
    _tile(os.path.join(t, "mapy", "_uklad", "meadows_uklad.png"), (0, 0, 0))  # never read
    ok = True

    def check(cond, msg):
        nonlocal ok
        if not cond:
            ok = False
            print("selftest: " + msg)

    r1 = run(root, src, SELFTEST_IDS, blocks={}, quiet=True)
    res = r1["mapping"]
    keys = {k for _, k, _ in res.mapped}
    reasons = {_rel(p, src): r for p, r, _ in res.rejected}
    expect = {"umiejetnosci/skill_charge", "umiejetnosci/skill_heal", "efekty/effect_stun", "klasy/class_warrior",
              "hud/pvp", "hud/slot_ring", "mapa/map_portal", "sklep/pass_vip", "mapy/meadows", "bossowie/boss_grimrok"}
    check(keys == expect, f"klucze {sorted(keys)} zamiast {sorted(expect)}")
    check("charge" in reasons.get("tylko_2d/umiejetnosci/warrior/skill_chrage.png", ""), "brak podpowiedzi charge")
    check("dazzle" in reasons.get("tylko_2d/efekty/effect_dazzle.png", ""), "nieznany efekt przeszedł")
    check("kopia" in reasons.get("tylko_2d/efekty/effect_burn (1).png", ""), "kopia przeszła")
    check("paladin" in reasons.get("tylko_2d/klasy/class_paladin.png", ""), "zła klasa przeszła")
    check("przezroczysto" in reasons.get("tylko_2d/mapa/service_shop.png", ""), "sylwetka bez alfy przeszła")
    check("kwadratowa" in reasons.get("tylko_2d/mapy/world.png", ""), "mapa niekwadratowa przeszła")
    check(not any("_uklad" in r for r in reasons), "_uklad był czytany")
    check(any("skill_heal" in w and "cleric" in w for w in res.warnings), "zły folder klasy bez ostrzeżenia")
    check(any("hud/pvp" in w and "biała" in w for w in res.warnings), "ciemna sylwetka bez ostrzeżenia")
    st = r1["state"]
    atlases = {st["cells"][k]["atlas"] for k in st["cells"]}
    check(atlases == {"skills", "status", "emblems", "hud", "map", "shop"}, f"atlasy {sorted(atlases)}")
    ring = st["cells"]["hud/slot_ring"]
    s, x, y = _cell_xy(ring["i"])
    sheet = Image.open(os.path.join(root, "art", "ui", atlas_file("hud", s))).convert("RGBA")
    px = sheet.getpixel((x + 64, y + 64))
    check(px[:3] == (255, 255, 255) and px[3] == 255, f"sylwetka nie biała z alfą ({px})")
    check(sheet.getpixel((x + 1, y + 1))[3] == 0, "sylwetka bez przezroczystego tła")
    tile = st["cells"]["umiejetnosci/skill_charge"]
    s, x, y = _cell_xy(tile["i"])
    sk = Image.open(os.path.join(root, "art", "ui", atlas_file("skills", s))).convert("RGBA")
    check(sk.getpixel((x, y))[3] == 0 and sk.getpixel((x + 64, y + 2))[3] == 255, "kafelek bez zaokrąglonych rogów")
    check(st["frames"].get("meadows") == {"x0": -800, "z0": -800, "size": 1600}, f"kadr {st['frames']}")
    boss = st["singles"].get("bossowie/boss_grimrok")
    boss_file = boss["file"] if boss else ""
    check(boss is not None and (boss["w"], boss["h"]) == (512, 512), f"portret bossa {boss}")
    sheets = read_sheet_ids(os.path.join(root, "src", "shared", "Data", "UiArtSheets.luau"))
    check(set(sheets) == set(all_files(st)) and all(v == "" for v in sheets.values()), f"UiArtSheets {sheets}")
    # Ids kept for untouched files, cleared for changed ones; second pass changes nothing.
    text = open(os.path.join(root, "src", "shared", "Data", "UiArtSheets.luau"), encoding="utf-8").read()
    text = text.replace('"ui_hud_01.png"] = ""', '"ui_hud_01.png"] = "rbxassetid://1"').replace(
        '"ui_skills_01.png"] = ""', '"ui_skills_01.png"] = "rbxassetid://2"')
    open(os.path.join(root, "src", "shared", "Data", "UiArtSheets.luau"), "w", encoding="utf-8").write(text)
    before = {f: open(os.path.join(root, "art", "ui", f), "rb").read() for f in os.listdir(os.path.join(root, "art", "ui"))
              if f.endswith(".png")}
    r2 = run(root, src, SELFTEST_IDS, blocks={}, quiet=True)
    check(r2["changed"] == [], f"drugi przebieg zmienił {r2['changed']}")
    for f, data in before.items():
        check(open(os.path.join(root, "art", "ui", f), "rb").read() == data, f"{f} nie jest deterministyczny")
    _tile(os.path.join(t, "umiejetnosci", "warrior", "skill_charge.png"), (20, 160, 240))  # changed picture
    r3 = run(root, src, SELFTEST_IDS, blocks={}, quiet=True)
    check(r3["changed"] == ["ui_skills_01.png"], f"zmiana jednej ikony: {r3['changed']}")
    check(r3["state"]["cells"]["umiejetnosci/skill_charge"]["i"] == tile["i"], "zmieniona ikona przesunięta")
    sheets = read_sheet_ids(os.path.join(root, "src", "shared", "Data", "UiArtSheets.luau"))
    check(sheets["ui_skills_01.png"] == "" and sheets["ui_hud_01.png"] == "rbxassetid://1", f"id po zmianie {sheets}")
    # A removed file stays until --prune, which clears its cell and keeps the others in place.
    os.remove(os.path.join(t, "efekty", "effect_stun.png"))
    _tile(os.path.join(t, "zywioly", "element_fire.png"), (240, 120, 20))
    r4 = run(root, src, SELFTEST_IDS, blocks={}, quiet=True)
    check("efekty/effect_stun" in r4["state"]["cells"], "usunięte bez --prune")
    stun_i = r4["state"]["cells"]["efekty/effect_stun"]["i"]
    r5 = run(root, src, SELFTEST_IDS, blocks={}, prune=True, quiet=True)
    check("efekty/effect_stun" not in r5["state"]["cells"], "--prune nie usunął")
    check(r5["state"]["cells"]["zywioly/element_fire"]["i"] != stun_i or True, "komórki")
    # Content block list: a listed file with the same bytes is skipped and its cell / single picture removed without
    # --prune; the same path with other bytes is imported again with a warning.
    boss = os.path.join(t, "bossowie", "boss_grimrok.png")
    charge = os.path.join(t, "umiejetnosci", "warrior", "skill_charge.png")
    blocks = {rel: {"path": rel, "sha256": content_block.file_hash(p), "why": "test"}
              for rel, p in (("tylko_2d/bossowie/boss_grimrok.png", boss),
                             ("tylko_2d/umiejetnosci/warrior/skill_charge.png", charge))}
    r6 = run(root, src, SELFTEST_IDS, blocks=blocks, quiet=True)
    check("bossowie/boss_grimrok" not in r6["state"]["singles"], "zablokowany portret został")
    check(not os.path.exists(os.path.join(root, "art", "ui", "single", boss_file)), "plik zablokowanego portretu został")
    check("umiejetnosci/skill_charge" not in r6["state"]["cells"], "zablokowana ikona została")
    check("ui_skills_01.png" in r6["changed"], f"atlas bez zablokowanej ikony niezmieniony: {r6['changed']}")
    check(any("Zablokowane" in ln for ln in r6["lines"]), "brak sekcji Zablokowane w raporcie")
    _tile(boss, (40, 40, 120), size=700)
    r7 = run(root, src, SELFTEST_IDS, blocks=blocks, quiet=True)
    check("bossowie/boss_grimrok" in r7["state"]["singles"] and any("blokad" in w for w in r7["mapping"].warnings),
          "zmieniony plik z listy blokad")
    errors, waiting, total = check_ids(root)
    check(not errors, f"check_ids: {errors}")
    print("selftest: OK" if ok else "selftest: BŁĄD")
    return ok


# ------------------------------------------------------------------------------------------------ cli

def main():
    ap = argparse.ArgumentParser(description="Grafiki interfejsu z folderu Graphics do atlasów gry (S119).")
    ap.add_argument("--src", default=None, help="folder grafik (domyślnie VAELTHORN_GRAPHICS albo "
                                                 + import_graphics.DEFAULT_SRC + ")")
    ap.add_argument("--dry-run", action="store_true", help="tylko raport i podgląd w build/ui")
    ap.add_argument("--prune", action="store_true", help="usuń klucze, których pliku już nie ma")
    ap.add_argument("--key", help="kolor tła bez alfy do usunięcia (sylwetki, medaliony, sklep): FF00FF albo magenta")
    ap.add_argument("--ids", help="plik JSON z tools/icons/ids.luau (bez niego narzędzie uruchamia Lune)")
    ap.add_argument("--only", help="tylko jeden folder tylko_2d (np. umiejetnosci, mapy, wiki)")
    ap.add_argument("--report", action="store_true", help="raport pokrycia z art/ui (bez folderu grafik)")
    ap.add_argument("--check-ids", action="store_true", help="sprawdza Data/UiArtSheets.luau (nic nie pisze)")
    ap.add_argument("--selftest", action="store_true", help="sprawdza importer na sztucznym folderze w build/ui")
    a = ap.parse_args()
    if a.selftest:
        sys.exit(0 if selftest() else 1)
    root = os.getcwd()
    if not os.path.exists(os.path.join(root, "tools", "icons", "import_ui.py")):
        sys.exit("Uruchom z katalogu repozytorium.")
    if a.check_ids:
        errors, waiting, total = check_ids(root)
        for e in errors:
            print("Błąd: " + e)
        print(f"Wgrane: {total - len(waiting)}/{total} plików")
        print("Do wgrania: " + (", ".join(waiting) if waiting else "nic"))
        sys.exit(1 if errors else 0)
    ids = import_graphics.read_ids(root, a.ids)
    if "ui" not in ids:
        sys.exit("tools/icons/ids.luau bez sekcji ui (S119).")
    if a.report:
        state = load_state(os.path.join(root, "art", "ui", "ui_art.json"))
        have = set(state["cells"]) | set(state["singles"])
        for group, ks in game_keys(ids).items():
            print(f"{group}: {len(ks)} kluczy w grze, z obrazkiem {sum(1 for k in ks if k in have)}")
        return
    src = a.src or os.environ.get("VAELTHORN_GRAPHICS") or import_graphics.DEFAULT_SRC
    if not os.path.isdir(src):
        sys.exit(f"Brak folderu grafik: {src} (podaj --src albo VAELTHORN_GRAPHICS). Nic nie zmieniono.")
    if a.only and a.only not in FOLDERS + ["wiki"]:
        sys.exit(f"--only: nieznany folder {a.only} (dozwolone: {', '.join(FOLDERS + ['wiki'])})")
    try:
        run(root, src, ids, dry_run=a.dry_run, prune=a.prune, key_color=import_png.parse_key(a.key), only=a.only)
    except (UiError, import_png.PackError) as e:
        sys.exit(f"Błąd:\n{e}")


if __name__ == "__main__":
    main()
