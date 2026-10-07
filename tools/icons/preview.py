from PIL import Image, ImageDraw, ImageFont, ImageFilter
from render import compose, CELL

def _font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf", "C:/Windows/Fonts/georgia.ttf", "DejaVuSerif.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default()


FONT = _font(14)
FONT_B = _font(22)
BG = (27, 29, 35)


def slot_bg(size, frame):
    s = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(s)
    for r in range(size // 2, 0, -2):
        t = r / (size / 2)
        c = tuple(int(a + (b - a) * t) for a, b in zip((48, 52, 63), (25, 27, 33)))
        d.ellipse((size / 2 - r * 1.3, size * 0.42 - r * 1.3, size / 2 + r * 1.3, size * 0.42 + r * 1.3), fill=c + (255,))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=12, fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(s, (0, 0), mask)
    ImageDraw.Draw(out).rounded_rectangle((1, 1, size - 2, size - 2), radius=12, outline=frame, width=4)
    return out


def sheet(index, sheets, rows, title, cols=8, slot=112, label_h=34, frames=None):
    """rows: list of (key, label, tier, accent, frameColor)."""
    W = 40 + cols * (slot + 18)
    H = 80 + ((len(rows) + cols - 1) // cols) * (slot + label_h + 12)
    img = Image.new("RGBA", (W, H), BG + (255,))
    d = ImageDraw.Draw(img)
    d.text((40, 24), title, font=FONT_B, fill=(234, 221, 190))
    for i, (key, label, tier, accent, frame) in enumerate(rows):
        x = 40 + (i % cols) * (slot + 18)
        y = 70 + (i // cols) * (slot + label_h + 12)
        img.alpha_composite(slot_bg(slot, frame or (154, 160, 166)), (x, y))
        ic = compose(index, sheets, key, tier, accent).resize((int(slot * 0.86), int(slot * 0.86)), Image.LANCZOS)
        img.alpha_composite(ic, (x + (slot - ic.width) // 2, y + (slot - ic.height) // 2))
        tw = d.textlength(label, font=FONT)
        d.text((x + slot / 2 - tw / 2, y + slot + 6), label, font=FONT, fill=(216, 204, 176))
    return img.convert("RGB")
