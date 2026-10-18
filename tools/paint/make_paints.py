"""W10: face paint textures (Data/BodyLooks.paints): white on transparent, tinted in the game with the paint colour.

A decal on the front of a dynamic head covers the head's whole front face (its bounding box, neck included): u = 0..1
left to right as the viewer sees it, v = 0..1 top to bottom; the eyes sit near v 0.47, the nose tip near 0.55, the
mouth near 0.64. No blood, wounds or scars.

    py -3 tools/paint/make_paints.py      ->  art/paint/<paint id>.png (512 x 512)
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

SIZE = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "art", "paint")

EYE_V = 0.47
EYES_U = (0.37, 0.63)


def canvas():
    return Image.new("L", (SIZE, SIZE), 0)


def px(u, v):
    return (u * SIZE, v * SIZE)


def save(name, alpha, blur=1.2):
    alpha = alpha.filter(ImageFilter.GaussianBlur(blur))
    img = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    img.putalpha(alpha)
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, f"{name}.png"))


def freckles():
    a = canvas()
    d = ImageDraw.Draw(a)
    rng = random.Random(11)
    for side in (-1, 1):
        cx = 0.5 + side * 0.15
        for _ in range(22):
            u = cx + rng.uniform(-0.075, 0.075)
            v = 0.545 + rng.uniform(-0.03, 0.035)
            r = rng.uniform(0.007, 0.012) * SIZE
            x, y = px(u, v)
            d.ellipse((x - r, y - r, x + r, y + r), fill=rng.randint(150, 220))
    for _ in range(8):  # across the bridge of the nose
        u = 0.5 + rng.uniform(-0.05, 0.05)
        v = 0.515 + rng.uniform(-0.012, 0.012)
        r = rng.uniform(0.006, 0.009) * SIZE
        x, y = px(u, v)
        d.ellipse((x - r, y - r, x + r, y + r), fill=rng.randint(140, 200))
    save("paint_freckles", a, 1.6)


def stripes():
    a = canvas()
    d = ImageDraw.Draw(a)
    for side in (-1, 1):
        for i, v in enumerate((0.525, 0.56)):
            inner = 0.5 + side * 0.07
            outer = 0.5 + side * (0.26 - i * 0.02)
            top = v - 0.013
            bottom = v + 0.013
            # a stroke that thins toward the ear
            d.polygon(
                [px(inner, top), px(outer, v - 0.005), px(outer, v + 0.005), px(inner, bottom)], fill=235
            )
    save("paint_stripes", a, 1.6)


def rune():
    a = canvas()
    d = ImageDraw.Draw(a)
    cx, cy = 0.5, 0.345
    w = 11
    pts = [px(cx, cy - 0.045), px(cx + 0.035, cy), px(cx, cy + 0.045), px(cx - 0.035, cy)]
    d.line(pts + [pts[0]], fill=240, width=w)
    d.line([px(cx, cy - 0.07), px(cx, cy + 0.07)], fill=240, width=w)
    d.line([px(cx - 0.05, cy + 0.02), px(cx - 0.02, cy + 0.045)], fill=220, width=w - 1)
    d.line([px(cx + 0.05, cy + 0.02), px(cx + 0.02, cy + 0.045)], fill=220, width=w - 1)
    save("paint_rune", a, 1.0)


def tribal():
    a = canvas()
    d = ImageDraw.Draw(a)
    # one side: a line from the brow over the eye down the cheek, with three ticks
    side = 1
    u0 = EYES_U[1]
    path = [px(u0 + 0.01, 0.39), px(u0 + 0.02, 0.44), px(u0 + 0.015, 0.5), px(u0 + 0.03, 0.57), px(u0 + 0.06, 0.62)]
    d.line(path, fill=235, width=16, joint="curve")
    for i, v in enumerate((0.52, 0.56, 0.6)):
        x0 = u0 + 0.02 + i * 0.012
        d.line([px(x0, v), px(x0 + side * 0.05, v - 0.01)], fill=220, width=12)
    # chin: three short vertical lines
    for du in (-0.03, 0, 0.03):
        d.line([px(0.5 + du, 0.67), px(0.5 + du, 0.705)], fill=225, width=13)
    save("paint_tribal", a, 1.4)


def ash():
    a = canvas()
    d = ImageDraw.Draw(a)
    # a soft band across the eyes, uneven at the edges
    rng = random.Random(5)
    for i in range(60):
        u = 0.2 + i / 60 * 0.6
        v = EYE_V + rng.uniform(-0.012, 0.012)
        h = rng.uniform(0.028, 0.04) * SIZE
        x, y = px(u, v)
        d.ellipse((x - 22, y - h, x + 22, y + h), fill=rng.randint(170, 210))
    save("paint_ash", a, 12)


if __name__ == "__main__":
    freckles()
    stripes()
    rune()
    tribal()
    ash()
    print("art/paint: 5 textures")
