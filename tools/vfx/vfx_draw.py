# Drawing helpers of the Vaelthorn effect texture generator (S112, tools/vfx/make_textures.py).
# Everything is deterministic: randomness only through rng_for(key) (one random.Random per texture, seeded from the
# key), no time, no os.urandom, no Image.effect_noise. Shapes live in the alpha channel; the colour is always white
# (the game tints it with Color / Color3).
import hashlib
import math
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

BICUBIC = Image.Resampling.BICUBIC
LANCZOS = Image.Resampling.LANCZOS


def rng_for(key):
    seed = int(hashlib.sha256(key.encode("utf-8")).hexdigest()[:8], 16)
    return random.Random(seed)


def canvas(w, h):
    """An empty alpha mask (mode L, 0 = transparent)."""
    return Image.new("L", (w, h), 0)


def supersample(draw_fn, w, h, k=4):
    """Calls draw_fn(draw, img, k) on a k-times bigger mask and scales it down (smooth edges)."""
    big = canvas(w * k, h * k)
    draw_fn(ImageDraw.Draw(big), big, k)
    return big.resize((w, h), LANCZOS) if k > 1 else big


def clamp01(x):
    return 0.0 if x < 0 else (1.0 if x > 1 else x)


def smoothstep(e0, e1, x):
    if e0 == e1:
        return 0.0 if x < e0 else 1.0
    t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def field(w, h, fn):
    """A mask from fn(x, y) -> alpha 0..1 evaluated at every pixel centre (x, y in pixels)."""
    data = []
    for y in range(h):
        cy = y + 0.5
        for x in range(w):
            data.append(int(round(clamp01(fn(x + 0.5, cy)) * 255)))
    img = canvas(w, h)
    img.putdata(data)
    return img


def radial_alpha(size, falloff, power=1.0):
    """Soft disc: alpha = (1 - r / falloff) ** power, r in units of the side (0.5 = edge)."""

    def fn(x, y):
        r = math.hypot(x / size - 0.5, y / size - 0.5)
        return clamp01(1 - r / falloff) ** power

    return field(size, size, fn)


def value_noise(rng, w, h, cells, octaves):
    """Periodic value noise (tiles in both axes): a list of w * h floats 0..1, `cells` cells across x at the first
    octave, each next octave twice as fine and half as strong."""
    acc = [0.0] * (w * h)
    amp = 1.0
    for o in range(octaves):
        cw = max(2, cells * 2**o)
        ch = max(2, round(cw * h / w))
        grid = canvas(cw, ch)
        grid.putdata([rng.randrange(256) for _ in range(cw * ch)])
        big = canvas(cw * 3, ch * 3)
        for gx in range(3):
            for gy in range(3):
                big.paste(grid, (gx * cw, gy * ch))
        big = big.resize((w * 3, h * 3), BICUBIC).crop((w, h, 2 * w, 2 * h))
        for i, v in enumerate(big.getdata()):
            acc[i] += amp * v
        amp *= 0.5
    lo, hi = min(acc), max(acc)
    span = (hi - lo) or 1.0
    return [(a - lo) / span for a in acc]


def noise_sampler(values, w, h):
    """Nearest lookup into a value_noise list with wrap-around (x, y in pixels)."""

    def at(x, y):
        return values[(int(y) % h) * w + (int(x) % w)]

    return at


def blur(img, radius):
    return img.filter(ImageFilter.GaussianBlur(radius)) if radius > 0 else img


def wrap_blur(img, radius):
    """Blur of a texture that tiles along U: blurred between copies of itself, so the seam stays invisible."""
    w, h = img.size
    big = canvas(w * 3, h)
    for i in range(3):
        big.paste(img, (i * w, 0))
    return blur(big, radius).crop((w, 0, 2 * w, h))


def lighter(*imgs):
    out = imgs[0]
    for img in imgs[1:]:
        out = ImageChops.lighter(out, img)
    return out


def scale(img, factor):
    """Multiplies the mask by factor (0..1+), clamped."""
    return img.point(lambda v: min(255, int(round(v * factor))))


def multiply(a, b):
    return ImageChops.multiply(a, b)


def edge_window(w, h, mx, my, pad=0.022):
    """0 within `pad` of each side, rising to 1 over the next `mx` / `my` fraction (keeps the margin clean); a zero
    width leaves that axis untouched."""

    def fn(x, y):
        u, v = x / w, y / h
        fx = 1.0 if mx <= 0 else smoothstep(pad, pad + mx, min(u, 1 - u))
        fy = 1.0 if my <= 0 else smoothstep(pad, pad + my, min(v, 1 - v))
        return fx * fy

    return field(w, h, fn)


def alpha_to_rgba(mask):
    white = Image.new("L", mask.size, 255)
    return Image.merge("RGBA", (white, white, white, mask))


def tile_check(img):
    """True when a texture that wraps along U has no seam: the step from the last column back to the first is no
    bigger than the biggest step between neighbouring columns inside the image (+2/255)."""
    a = img.getchannel("A") if img.mode == "RGBA" else img
    w, h = a.size
    px = a.load()

    def step(x0, x1):
        return max(abs(px[x0, y] - px[x1, y]) for y in range(h))

    inner = max(step(x, x + 1) for x in range(w - 1))
    return step(w - 1, 0) <= inner + 2


def margin_ok(img, frac, wrap_u=False):
    """True when nothing is drawn within `frac` of the edge (the U edges are skipped for wrapping textures)."""
    a = img.getchannel("A") if img.mode == "RGBA" else img
    w, h = a.size
    mx, my = int(math.floor(w * frac)), int(math.floor(h * frac))
    px = a.load()
    for y in range(h):
        for x in range(w):
            if px[x, y] > 2:
                inside_x = wrap_u or (mx <= x < w - mx)
                if not inside_x or not (my <= y < h - my):
                    return False
    return True


def grid(frames, cols, frame_size):
    """Lays the frames of a flipbook out row by row (frame 1 top left)."""
    rows = (len(frames) + cols - 1) // cols
    sheet = canvas(cols * frame_size, rows * frame_size)
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % cols) * frame_size, (i // cols) * frame_size))
    return sheet


def pixel_hash(img):
    return hashlib.sha256(img.convert("RGBA").tobytes()).hexdigest()[:16]


# Drawing in supersampled space -------------------------------------------------------------------------------------


def circle(draw, cx, cy, r, fill=None, outline=None, width=1):
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill, outline=outline, width=max(1, int(round(width))))


def polyline(draw, points, width, fill=255):
    draw.line(points, fill=fill, width=max(1, int(round(width))), joint="curve")
    r = width / 2
    for x, y in (points[0], points[-1]):
        circle(draw, x, y, r, fill=fill)


def rotate_point(x, y, angle):
    c, s = math.cos(angle), math.sin(angle)
    return x * c - y * s, x * s + y * c


def place(points, cx, cy, angle, unit):
    """Local glyph points (unit coordinates, y up the radius) placed at (cx, cy) turned by `angle`."""
    out = []
    for x, y in points:
        rx, ry = rotate_point(x * unit, y * unit, angle)
        out.append((cx + rx, cy + ry))
    return out
