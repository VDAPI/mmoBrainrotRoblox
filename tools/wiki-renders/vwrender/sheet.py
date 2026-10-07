"""Contact sheet of every render (out/contact.png): 8 columns of 160 px tiles, variants of a kind side by side,
monsters by region, then bosses and pets."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

COLUMNS = 8
TILE = 160
LABEL = 18
BG = "#14161B"
BORDER = "#3A3F4C"
TEXT = "#C9C4B8"
VARIANTS = {"normal": 0, "elite": 1, "elite2": 2, "boss": 3, "pet": 4}
KINDS = {"monster": 0, "boss": 1, "pet": 2}


def order(entries):
    return sorted(entries, key=lambda e: (KINDS[e["kind"]], e.get("region") or 0, e["id"], VARIANTS[e["variant"]]))


def build(entries, out_dir, path):
    entries = order(entries)
    rows = (len(entries) + COLUMNS - 1) // COLUMNS
    sheet = Image.new("RGB", (COLUMNS * TILE, rows * (TILE + LABEL)), "#0B0C0F")
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.load_default(size=11)
    except TypeError:
        font = ImageFont.load_default()
    for i, e in enumerate(entries):
        x, y = (i % COLUMNS) * TILE, (i // COLUMNS) * (TILE + LABEL)
        draw.rectangle([x, y, x + TILE - 1, y + TILE + LABEL - 1], fill=BG, outline=BORDER)
        src = Path(out_dir) / f"{e['file']}.webp"
        if src.is_file():
            img = Image.open(src).convert("RGBA").resize((TILE - 4, TILE - 4), Image.LANCZOS)
            sheet.paste(img, (x + 2, y + 2), img)
        draw.text((x + 4, y + TILE), f"{e['id']} · {e['variant']}", fill=TEXT, font=font)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    return path
