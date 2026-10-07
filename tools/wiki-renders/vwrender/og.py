"""Open Graph base images (1200 x 630, no text: S39 adds titles in wiki/scripts/og-images.mjs).

base.png         dark background, 135 degree stripes like the mock-up placeholder, warm glow at the bottom,
                 inner frame 2 px #C9A45C (16 px in) and 1 px #7A6438 (22 px in)
default-art.png  base + the hero boss render (<id>-1024.webp) on the right with a glow in its aura colour
Layout for S39: render area x 640-1160, y 40-600; text area x 64-600.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 1200, 630
BG = (0x14, 0x16, 0x1B)
STRIPE_A = (0x16, 0x18, 0x1D)
STRIPE_B = (0x1B, 0x1D, 0x23)
STRIPE = 24
GOLD = "#C9A45C"
GOLD_DARK = "#7A6438"
RENDER_BOX = (640, 40, 1160, 600)


def _hex(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def _glow(size, centre, radii, color, strength):
    """RGBA layer with a soft elliptical glow."""
    w, h = size
    y, x = np.mgrid[0:h, 0:w]
    r = np.sqrt(((x - centre[0]) / radii[0]) ** 2 + ((y - centre[1]) / radii[1]) ** 2)
    a = np.clip(1 - r, 0, 1) ** 2 * strength
    layer = np.zeros((h, w, 4), np.uint8)
    layer[..., :3] = color
    layer[..., 3] = np.round(a * 255).astype(np.uint8)
    return Image.fromarray(layer, "RGBA")


def base():
    y, x = np.mgrid[0:H, 0:W]
    band = ((x + y) // STRIPE) % 2 == 0
    arr = np.where(band[..., None], np.array(STRIPE_A, np.uint8), np.array(STRIPE_B, np.uint8)).astype(np.uint8)
    img = Image.fromarray(arr, "RGB").convert("RGBA")
    img.alpha_composite(_glow((W, H), (W / 2, H + 40), (W * 0.62, H * 0.55), _hex("#FF8A3A"), 0.22))
    draw = ImageDraw.Draw(img)
    draw.rectangle([16, 16, W - 17, H - 17], outline=GOLD, width=2)
    draw.rectangle([22, 22, W - 23, H - 23], outline=GOLD_DARK, width=1)
    return img


def default_art(mobs_dir, boss):
    img = base()
    if boss is None:
        return img
    src = Path(mobs_dir) / f"{boss['file']}-1024.webp"
    if not src.is_file():
        return img
    x0, y0, x1, y1 = RENDER_BOX
    cx = (x0 + x1) / 2
    aura = _hex(boss.get("aura") or "#D64A3E")
    img.alpha_composite(_glow((W, H), (cx, y1 - 120), (300, 240), aura, 0.4).filter(ImageFilter.GaussianBlur(20)))
    art = Image.open(src).convert("RGBA")
    side = min(x1 - x0, y1 - y0)
    art = art.convert("RGBa").resize((side, side), Image.LANCZOS).convert("RGBA")
    img.alpha_composite(art, (int(cx - side / 2), y1 - side))
    # redraw the frame over the art
    draw = ImageDraw.Draw(img)
    draw.rectangle([16, 16, W - 17, H - 17], outline=GOLD, width=2)
    draw.rectangle([22, 22, W - 23, H - 23], outline=GOLD_DARK, width=1)
    return img


def build(og_dir, mobs_dir, boss):
    og_dir = Path(og_dir)
    og_dir.mkdir(parents=True, exist_ok=True)
    a, b = og_dir / "base.png", og_dir / "default-art.png"
    base().convert("RGB").save(a, optimize=True)
    default_art(mobs_dir, boss).convert("RGB").save(b, optimize=True)
    return [a, b]
