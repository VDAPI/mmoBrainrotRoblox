# Vaelthorn effect texture generator (S112, DESIGN-16 §4, docs/ANIMACJE.md "Tekstury efektów").
# Draws the effect textures into art/vfx/ (white shapes on transparent, the shape only in alpha; the game tints them)
# and writes art/vfx/manifest.json. Deterministic: each texture has its own random.Random seeded from its key, and
# the manifest stores a hash of the pixels (not of the PNG file, which another Pillow may compress differently).
#
#   python tools/vfx/make_textures.py                 # all textures into art/vfx/ + manifest.json
#   python tools/vfx/make_textures.py --only glow,smoke
#   python tools/vfx/make_textures.py --check         # draws in memory, compares with the manifest; exit 1 on a diff
#   python tools/vfx/make_textures.py --preview build/vfx_preview.png
#
# A row with "custom": true in the manifest is the owner's own texture: never overwritten, skipped by --check's hash.
# Order of TEXTURES is fixed (new ones at the end): src/shared/Data/VfxTextures.luau has the same keys in this order.
import argparse
import json
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfx_draw import (  # noqa: E402
    alpha_to_rgba,
    blur,
    canvas,
    circle,
    clamp01,
    edge_window,
    field,
    grid,
    lighter,
    margin_ok,
    multiply,
    noise_sampler,
    pixel_hash,
    place,
    polyline,
    rng_for,
    scale,
    smoothstep,
    supersample,
    tile_check,
    value_noise,
    wrap_blur,
)

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(ROOT, "art", "vfx")
MANIFEST = os.path.join(OUT_DIR, "manifest.json")
MARGIN = 0.02  # nothing drawn within 2% of an edge (U edges of wrapping textures excepted)
TAU = math.pi * 2


# Particles ---------------------------------------------------------------------------------------------------------


def draw_glow(key, w, h):
    def fn(x, y):
        r = math.hypot(x / w - 0.5, y / h - 0.5)
        a = math.exp(-((r / 0.32) ** 2) * 2.2)
        return a * (1 - smoothstep(0.42, 0.48, r))

    return field(w, h, fn)


def draw_spark(key, w, h):
    def fn(x, y):
        dx = abs(x / w - 0.5)
        yy = (y / h - 0.5) / 0.45  # -1..1 over 90% of the height
        if abs(yy) >= 1:
            return 0.0
        along = 1 - abs(yy) ** 1.6
        core = 1 - smoothstep(0.024, 0.036, dx)
        halo = 0.35 * (1 - smoothstep(0.03, 0.09, dx))
        return max(core, halo) * along

    return blur(field(w, h, fn), 1)


def draw_star(key, w, h):
    def rays(draw, img, k):
        cx, cy = w * k / 2, h * k / 2
        for i, (length, base) in enumerate([(0.48, 0.07)] * 4 + [(0.26, 0.05)] * 4):
            angle = (i % 4) * math.pi / 2 + (math.pi / 4 if i >= 4 else 0)
            L, half = length * w * k, base * w * k / 2
            pts = [(0, -half), (L, 0), (0, half)]
            c, s = math.cos(angle), math.sin(angle)
            draw.polygon([(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts], fill=255)

    ray_img = blur(supersample(rays, w, h), 1.5)

    def core(x, y):
        r = math.hypot(x / w - 0.5, y / h - 0.5)
        return math.exp(-((r / 0.2) ** 2) * 2.2) * (1 - smoothstep(0.18, 0.22, r))

    out = lighter(ray_img, field(w, h, core))
    return multiply(out, edge_window(w, h, 0.025, 0.025))


SMOKE_FRAMES = 16


def draw_smoke(key, w, h):
    rng = rng_for(key)
    fs = w // 4
    blobs = []
    for _ in range(rng.randint(7, 9)):
        a = rng.uniform(0, TAU)
        d = rng.uniform(0.0, 0.07)
        blobs.append((math.cos(a) * d, math.sin(a) * d, rng.uniform(0.12, 0.22), rng.uniform(10, 18)))
    noise = noise_sampler(value_noise(rng, fs, fs, 6, 3), fs, fs)
    frames = []
    for i in range(SMOKE_FRAMES):
        t = i / (SMOKE_FRAMES - 1)
        spread = 1 + 0.9 * t
        cloud = canvas(fs, fs)
        for bx, by, r, b in blobs:
            layer = canvas(fs, fs)
            d = ImageDraw.Draw(layer)
            circle(d, fs * (0.5 + bx * spread), fs * (0.5 + by * spread), fs * r, fill=200)
            cloud = lighter(cloud, blur(layer, b))
        threshold = 0.25 + 0.35 * t
        fade = 0.85 * (1 - i / SMOKE_FRAMES)
        px = cloud.load()

        def fn(x, y, px=px, threshold=threshold, fade=fade):
            a = px[int(x), int(y)] / 200
            keep = clamp01((noise(x, y) + a * 0.6 - threshold) / 0.3)
            r = math.hypot(x / fs - 0.5, y / fs - 0.5)
            return a * keep * fade * (1 - smoothstep(0.42, 0.47, r))

        frames.append(field(fs, fs, fn))
    return grid(frames, 4, fs)


FIRE_FRAMES = 16


def draw_fire(key, w, h):
    rng = rng_for(key)
    fs = w // 4
    n1 = noise_sampler(value_noise(rng, fs, fs, 3, 2), fs, fs)
    n2 = noise_sampler(value_noise(rng, fs, fs, 5, 3), fs, fs)
    top, bottom = 0.06, 0.92

    def width_at(t):
        if t < 0.72:
            return 0.28 * (t / 0.72) ** 0.7
        u = (t - 0.72) / (1 - 0.72)
        return 0.28 * math.sqrt(max(0.0, 1 - u * u))

    frames = []
    for i in range(FIRE_FRAMES):
        shift = i * fs / FIRE_FRAMES  # the noise moves up 1/16 of the frame per frame and loops after 16

        def fn(x, y, shift=shift):
            v = y / fs
            t = (v - top) / (bottom - top)
            if t <= 0 or t >= 1:
                return 0.0
            wd = width_at(t)
            if wd <= 0.001:
                return 0.0
            sway = (n1(x, y + shift) - 0.5) * 0.16 * (1 - t)
            d = abs(x / fs - 0.5 - sway) / wd
            f = 1 - d - (n2(x, y + shift) - 0.5) * 0.7 * (1 - 0.5 * t)
            core = smoothstep(0.38, 0.5, f)
            edge = 0.55 * smoothstep(0.0, 0.08, f)
            return max(core, edge)

        frames.append(blur(field(fs, fs, fn), 3))
    return grid(frames, 4, fs)


def draw_dust(key, w, h):
    rng = rng_for(key)

    def blobs(draw, img, k):
        for _ in range(5):
            a = rng.uniform(0, TAU)
            d = rng.uniform(0, 0.1)
            circle(draw, w * k * (0.5 + math.cos(a) * d), h * k * (0.5 + math.sin(a) * d), w * k * rng.uniform(0.12, 0.2),
                   fill=255)

    cloud = blur(supersample(blobs, w, h, 2), 14)
    noise = noise_sampler(value_noise(rng, w, h, 4, 2), w, h)
    px = cloud.load()

    def fn(x, y):
        r = math.hypot(x / w - 0.5, y / h - 0.5)
        return px[int(x), int(y)] / 255 * (0.55 + 0.45 * noise(x, y)) * 0.7 * (1 - smoothstep(0.42, 0.47, r))

    return field(w, h, fn)


def draw_ice_shard(key, w, h):
    rng = rng_for(key)
    n = rng.randint(5, 7)
    pts = []
    for i in range(n):
        a = i / n * TAU + rng.uniform(-0.2, 0.2)
        r = rng.uniform(0.75, 1.0)
        pts.append((math.cos(a) * r * 0.19, math.sin(a) * r * 0.45))  # 2.4 : 1, long along y
    pts[0] = (0.0, -0.45)

    def body(draw, img, k):
        cx, cy = w * k / 2, h * k / 2
        mid = (cx + rng.uniform(-0.02, 0.02) * w * k, cy + rng.uniform(-0.06, 0.06) * h * k)
        world = [(cx + x * w * k, cy + y * h * k) for x, y in pts]
        for i in range(n):
            a, b = world[i], world[(i + 1) % n]
            draw.polygon([mid, a, b], fill=int(255 * rng.uniform(0.55, 0.95)))
        draw.line(world + [world[0]], fill=255, width=max(1, int(0.012 * w * k)), joint="curve")

    return supersample(body, w, h)


BUBBLE_FRAMES = 16


def draw_poison_bubble(key, w, h):
    rng = rng_for(key)
    fs = w // 4
    drops = [(i / 6 * TAU + rng.uniform(-0.25, 0.25), rng.uniform(0.8, 1.1)) for i in range(6)]
    gaps = rng.uniform(0, TAU)
    frames = []
    for i in range(BUBBLE_FRAMES):

        def frame(draw, img, k, i=i):
            c = fs * k / 2
            unit = fs * k
            if i < 10:
                r = (0.15 + (0.38 - 0.15) * i / 9) * unit
                circle(draw, c, c, r, fill=70)
                circle(draw, c, c, r, outline=255, width=0.035 * unit)
                hx, hy = c - r * 0.42, c - r * 0.42
                circle(draw, hx, hy, r * 0.18, fill=255)
            elif i < 12:
                r = 0.4 * unit
                spread = 0.15 if i == 10 else 0.32
                for j in range(6):
                    a0 = math.degrees(gaps + j / 6 * TAU + spread)
                    a1 = math.degrees(gaps + (j + 1) / 6 * TAU - spread)
                    draw.arc((c - r, c - r, c + r, c + r), a0, a1, fill=255, width=int(0.03 * unit))
            else:
                u = (i - 11) / 5  # 0.2 .. 1
                for a, speed in drops:
                    d = (0.3 + 0.15 * u * speed) * unit
                    alpha = int(255 * (1 - (i - 12) / 4) * 0.9)
                    circle(draw, c + math.cos(a) * d, c + math.sin(a) * d, (0.05 - 0.02 * u) * unit, fill=alpha)

        frames.append(supersample(frame, fs, fs))
    return grid(frames, 4, fs)


def draw_feather(key, w, h):
    rng = rng_for(key)
    barbs = rng.randint(22, 28)

    def body(draw, img, k):
        unit = w * k

        def shaft(t):  # quill (t = 0, bottom left) to tip (t = 1, top right), bending a little
            x = 0.16 + 0.68 * t
            y = 0.84 - 0.68 * t - 0.08 * math.sin(math.pi * t)
            return x * unit, y * unit

        pts = [shaft(i / 40) for i in range(41)]
        draw.line(pts, fill=230, width=max(1, int(0.014 * unit)), joint="curve")
        for i in range(barbs):
            t = 0.2 + 0.78 * i / (barbs - 1)
            x, y = shaft(t)
            x2, y2 = shaft(min(1, t + 0.01))
            ang = math.atan2(y2 - y, x2 - x)
            length = (0.2 * (1 - t) ** 0.6 + 0.04) * unit
            for side in (-1, 1):
                a = ang + side * math.radians(35)  # the barbs lean towards the tip
                end = (x + math.cos(a) * length, y + math.sin(a) * length)
                draw.line([(x, y), end], fill=217, width=max(1, int(0.006 * unit)))

    return multiply(supersample(body, w, h), edge_window(w, h, 0.025, 0.025))


def draw_dark_spark(key, w, h):
    def body(draw, img, k):
        unit = w * k
        cx, cy = unit / 2, unit * 0.62
        r = unit * 0.2
        circle(draw, cx, cy, r, fill=255)
        draw.polygon([(cx - r * 0.93, cy - r * 0.35), (cx, unit * 0.06), (cx + r * 0.93, cy - r * 0.35)], fill=255)

    return supersample(body, w, h)


# Slash arcs, rings, decals ------------------------------------------------------------------------------------------


def slash(w, h, span, inner, outer):
    half = math.radians(span / 2)

    def fn(x, y):
        dx, dy = x / w - 0.5, y / h - 0.5
        r = math.hypot(dx, dy)
        if r < inner - 0.01 or r > outer + 0.01:
            return 0.0
        # 0 = forward along +U (the beam runs from the caster forwards, Vfx/Library.slash), + = to the left drawn
        # towards -V; the blade sweeps left to right, so the leading edge is at the +V side (bottom of the image)
        phi = math.atan2(-dy, dx)
        if abs(phi) > half:
            return 0.0
        s = (half - phi) / (2 * half)  # 1 at the leading (right) edge, 0 at the tail
        along = s**1.8 * smoothstep(0, 0.03, 1 - s)
        px = 1 / w
        out_edge = 1 - smoothstep(outer - 2 * px, outer, r)
        in_edge = smoothstep(inner, inner + 0.3 * (outer - inner), r)
        across = out_edge * in_edge
        streak = 0.0
        for k in (0.38, 0.6, 0.82):
            rr = inner + k * (outer - inner)
            streak = max(streak, 0.2 * (1 - smoothstep(0, 2.5 * px, abs(r - rr))))
        return min(1.0, (across + streak * across) * along)

    return field(w, h, fn)


def draw_slash_wide(key, w, h):
    return slash(w, h, 200, 0.30, 0.48)


def draw_slash_narrow(key, w, h):
    return slash(w, h, 110, 0.34, 0.48)


def draw_ring(key, w, h):
    sigma = 0.05 / 2.355

    def fn(x, y):
        r = math.hypot(x / w - 0.5, y / h - 0.5)
        band = math.exp(-0.5 * ((r - 0.44) / sigma) ** 2)
        inner = 0.15 * smoothstep(0.30, 0.44, r) if r < 0.44 else 0.0
        return max(band, inner) * (1 - smoothstep(0.47, 0.48, r))

    return field(w, h, fn)


def draw_cracks(key, w, h):
    rng = rng_for(key)
    arms = rng.randint(7, 9)

    def walk(points, angle, length_left, width, branched):
        x, y = points[-1]
        total = length_left
        while length_left > 0:
            step = rng.uniform(0.03, 0.06)
            angle += math.radians(rng.uniform(-25, 25))
            nx, ny = x + math.cos(angle) * step, y + math.sin(angle) * step
            if math.hypot(nx - 0.5, ny - 0.5) > 0.45:
                break
            points.append((nx, ny))
            x, y = nx, ny
            length_left -= step
            if not branched and length_left < total / 2:
                branched = True
                if rng.random() < 0.3:
                    yield from walk([(x, y)], angle + rng.choice((-1, 1)) * math.radians(rng.uniform(25, 45)),
                                    length_left * 0.7, width * 0.6, True)
        yield points, width

    paths = []
    for i in range(arms):
        a = i / arms * TAU + rng.uniform(-0.3, 0.3)
        start = (0.5 + math.cos(a) * 0.04, 0.5 + math.sin(a) * 0.04)
        paths.extend(walk([start], a, rng.uniform(0.3, 0.42), 0.022, False))

    def body(draw, img, k):
        unit = w * k
        for points, width in paths:
            n = len(points)
            for j in range(n - 1):
                t = j / max(1, n - 1)
                wd = (width + (0.004 - width) * t) * unit
                a, b = points[j], points[j + 1]
                polyline(draw, [(a[0] * unit, a[1] * unit), (b[0] * unit, b[1] * unit)], wd, fill=230)
        # the crater: an irregular blob
        blob = []
        for j in range(14):
            a = j / 14 * TAU
            r = 0.08 * rng.uniform(0.75, 1.15)
            blob.append(((0.5 + math.cos(a) * r) * unit, (0.5 + math.sin(a) * r) * unit))
        draw.polygon(blob, fill=230)

    return supersample(body, w, h)


# Rune circles --------------------------------------------------------------------------------------------------------

FUTHARK = [
    [[(0, -1), (0, 1)], [(0, -1), (0.6, -0.4)]],
    [[(0, -1), (0, 1)], [(0, -1), (0.6, -0.4)], [(0, -0.2), (0.6, 0.4)]],
    [[(0, -1), (0, 1)], [(-0.6, -0.4), (0.6, 0.4)]],
    [[(0, -1), (0, 1)], [(0, 0), (0.6, -0.6)], [(0, 0), (-0.6, -0.6)]],
    [[(0, -1), (0, 1)], [(0, -0.5), (0.6, 0)], [(0.6, 0), (0, 0.5)]],
    [[(-0.4, -1), (-0.4, 1)], [(0.4, -1), (0.4, 1)], [(-0.4, -0.6), (0.4, 0.2)]],
    [[(0, -1), (0, 1)], [(0, -0.3), (-0.6, 0.3)]],
    [[(0, -1), (0, 1)], [(-0.6, -1), (0.6, -0.2)], [(0.6, -1), (-0.6, -0.2)]],
]


def ring_line(draw, c, r, width):
    circle(draw, c, c, r, outline=255, width=width)


def draw_rune_warrior(key, w, h):
    rng = rng_for(key)

    def body(draw, img, k):
        u = w * k
        c = u / 2
        lw = 0.012 * u
        ring_line(draw, c, 0.47 * u, lw)
        ring_line(draw, c, 0.40 * u, lw)
        for i in range(12):
            a = i / 12 * TAU
            gx, gy = c + math.sin(a) * 0.435 * u, c - math.cos(a) * 0.435 * u
            for stroke in FUTHARK[rng.randrange(len(FUTHARK))]:
                polyline(draw, place(stroke, gx, gy, a, 0.024 * u), lw * 0.9)
        # two crossed swords (blade, guard, grip, pommel)
        for sign in (-1, 1):
            ang = sign * math.pi / 4
            blade = [(-0.022, -0.24), (0, -0.27), (0.022, -0.24), (0.022, 0.1), (-0.022, 0.1)]
            draw.polygon(place(blade, c, c, ang, u), fill=255)
            polyline(draw, place([(-0.07, 0.11), (0.07, 0.11)], c, c, ang, u), lw * 1.4)
            polyline(draw, place([(0, 0.11), (0, 0.2)], c, c, ang, u), lw * 1.2)
            circle(draw, *place([(0, 0.22)], c, c, ang, u)[0], 0.018 * u, fill=255)

    return supersample(body, w, h)


def draw_rune_hunter(key, w, h):
    rng = rng_for(key)

    def body(draw, img, k):
        u = w * k
        c = u / 2
        lw = 0.012 * u
        ring_line(draw, c, 0.47 * u, lw)
        ring_line(draw, c, 0.36 * u, lw * 0.8)
        for i in range(16):
            a = i / 16 * TAU
            long = 0.06 if i % 4 == 0 else 0.035
            p0 = (c + math.sin(a) * 0.47 * u, c - math.cos(a) * 0.47 * u)
            p1 = (c + math.sin(a) * (0.47 - long) * u, c - math.cos(a) * (0.47 - long) * u)
            polyline(draw, [p0, p1], lw)
        for i in range(8):  # arrowheads and leaves in the band, alternating
            a = (i + 0.5) / 8 * TAU
            gx, gy = c + math.sin(a) * 0.405 * u, c - math.cos(a) * 0.405 * u
            if i % 2 == 0:
                draw.polygon(place([(0, -1), (0.7, 0.6), (0, 0.2), (-0.7, 0.6)], gx, gy, a + math.pi / 2, 0.028 * u),
                             fill=255)
            else:
                leaf = [(math.sin(t / 10 * math.pi) * 0.45, -1 + 2 * t / 10) for t in range(11)]
                leaf += [(-x, y) for x, y in reversed(leaf)]
                draw.polygon(place(leaf, gx, gy, a + math.pi / 2, 0.026 * u), fill=255)
        # crosshair with a gap and a small circle
        gap, arm = 0.05, 0.27
        for a in range(4):
            ang = a * math.pi / 2
            polyline(draw, place([(0, -gap), (0, -arm)], c, c, ang, u), lw * 1.1)
        circle(draw, c, c, 0.025 * u, outline=255, width=lw * 0.9)
        circle(draw, c, c, 0.16 * u, outline=255, width=lw * 0.7)
        _ = rng

    return supersample(body, w, h)


def draw_rune_mage(key, w, h):
    rng = rng_for(key)

    def body(draw, img, k):
        u = w * k
        c = u / 2
        lw = 0.011 * u
        for r in (0.47, 0.41, 0.22):
            ring_line(draw, c, r * u, lw)
        verts = []
        for i in range(6):
            a = i / 6 * TAU
            verts.append((c + math.sin(a) * 0.41 * u, c - math.cos(a) * 0.41 * u))
        for tri in (verts[0::2], verts[1::2]):
            polyline(draw, tri + [tri[0]], lw)
        for x, y in verts:
            circle(draw, x, y, 0.022 * u, fill=0)
            circle(draw, x, y, 0.022 * u, outline=255, width=lw * 0.8)
        for i in range(18):
            a = (i + 0.5) / 18 * TAU
            gx, gy = c + math.sin(a) * 0.44 * u, c - math.cos(a) * 0.44 * u
            kind = rng.randrange(3)
            if kind == 0:  # an arc
                r = 0.012 * u
                ang = math.degrees(a)
                draw.arc((gx - r, gy - r, gx + r, gy + r), ang, ang + 180, fill=255, width=int(lw * 0.8))
            elif kind == 1:  # a dot and a dash
                circle(draw, *place([(0, -0.6)], gx, gy, a, 0.02 * u)[0], 0.005 * u, fill=255)
                polyline(draw, place([(-0.6, 0.5), (0.6, 0.5)], gx, gy, a, 0.02 * u), lw * 0.7)
            else:  # two short strokes
                polyline(draw, place([(-0.5, -0.7), (-0.5, 0.7)], gx, gy, a, 0.02 * u), lw * 0.7)
                polyline(draw, place([(0.4, -0.7), (0.4, 0.2)], gx, gy, a, 0.02 * u), lw * 0.7)

    return supersample(body, w, h)


def draw_rune_cleric(key, w, h):
    def body(draw, img, k):
        u = w * k
        c = u / 2
        lw = 0.012 * u
        ring_line(draw, c, 0.47 * u, lw)
        for i in range(24):
            a = i / 24 * TAU
            inner = 0.36 if i % 2 == 0 else 0.41
            p0 = (c + math.sin(a) * 0.462 * u, c - math.cos(a) * 0.462 * u)  # the round cap ends on 0.47
            p1 = (c + math.sin(a) * inner * u, c - math.cos(a) * inner * u)
            polyline(draw, [p0, p1], lw * (1.2 if i % 2 == 0 else 0.9))
        ring_line(draw, c, 0.18 * u, lw)
        for a in range(4):  # a cross with flared arms
            arm = [(-0.025, -0.02), (-0.06, -0.15), (0.06, -0.15), (0.025, -0.02)]
            draw.polygon(place(arm, c, c, a * math.pi / 2, u), fill=255)
        circle(draw, c, c, 0.03 * u, fill=255)

    return supersample(body, w, h)


def draw_magic_circle(key, w, h):
    rng = rng_for(key)

    def body(draw, img, k):
        u = w * k
        c = u / 2
        thick, thin = 0.012 * u, 0.006 * u
        for r, lw in ((0.47, thick), (0.445, thin), (0.36, thick), (0.2, thin)):
            ring_line(draw, c, r * u, lw)
        squares = []
        for s in range(2):
            pts = []
            for i in range(4):
                a = i / 4 * TAU + s * math.pi / 4 + math.pi / 4
                pts.append((c + math.sin(a) * 0.36 * u, c - math.cos(a) * 0.36 * u))
            squares.append(pts)
            polyline(draw, pts + [pts[0]], thin * 1.4)
        # points where the two squares cross (an eight-pointed star): on the circle 0.36 * cos(45°/2) / cos(...)
        rin = 0.36 * math.cos(math.pi / 4) / math.cos(math.pi / 8)
        for i in range(8):
            a = (i + 0.5) / 8 * TAU
            circle(draw, c + math.sin(a) * rin * u, c - math.cos(a) * rin * u, 0.009 * u, fill=255)
        for i in range(4):
            a = i / 4 * TAU
            circle(draw, c + math.sin(a) * 0.36 * u, c - math.cos(a) * 0.36 * u, 0.012 * u, fill=255)
        for i in range(32):
            a = (i + 0.5) / 32 * TAU
            gx, gy = c + math.sin(a) * 0.4025 * u, c - math.cos(a) * 0.4025 * u
            stroke = FUTHARK[rng.randrange(len(FUTHARK))]
            for line in stroke:
                polyline(draw, place(line, gx, gy, a, 0.016 * u), thin)
        circle(draw, c, c, 0.05 * u, outline=255, width=thin)

    return supersample(body, w, h, 2)


# Beams and trails (U along the beam) ----------------------------------------------------------------------------------


def wrap_draw(w, h, k, fn):
    """Draws fn(draw, offset_x, k) three times side by side (offsets -w, 0, w in supersampled pixels) on a 3w canvas
    and returns the middle third scaled down: a texture that tiles along U."""
    big = canvas(w * k * 3, h * k)
    draw = ImageDraw.Draw(big)
    for i in range(3):
        fn(draw, i * w * k, k)
    small = big.resize((w * 3, h), Image.Resampling.LANCZOS)
    return small


def middle(img3):
    w3, h = img3.size
    w = w3 // 3
    return img3.crop((w, 0, 2 * w, h))


def wrap_glow(img3, radius):
    return blur(img3, radius)


def draw_beam_lightning(key, w, h):
    rng = rng_for(key)
    steps = rng.randint(12, 16)
    pts = [(0.0, 0.5)]
    for i in range(1, steps):
        pts.append((i / steps, 0.5 + rng.uniform(-0.28, 0.28)))
    pts.append((1.0, 0.5))
    branches = []
    for _ in range(rng.randint(1, 2)):
        j = rng.randrange(2, steps - 2)
        x, y = pts[j]
        branch = [(x, y)]
        ang = rng.uniform(-0.9, 0.9)
        for _ in range(3):
            x += 0.05
            y += math.sin(ang) * 0.08 + rng.uniform(-0.04, 0.04)
            branch.append((x, max(0.14, min(0.86, y))))
        branches.append(branch)

    def lines(width, alpha):
        def fn(draw, off, k):
            for line, wd in [(pts, width)] + [(b, width * 0.6) for b in branches]:
                polyline(draw, [(off + x * w * k, y * h * k) for x, y in line], wd * k, fill=alpha)

        return wrap_draw(w, h, 4, fn)

    core = lines(3, 255)
    halo = blur(lines(10, 102), 4)
    return multiply(middle(lighter(core, halo)), edge_window(w, h, 0, 0.03))


def draw_beam_holy(key, w, h):
    rng = rng_for(key)
    sigma = 0.18
    streaks = []
    for _ in range(rng.randint(10, 14)):
        streaks.append((rng.uniform(0, 1), rng.uniform(0.3, 0.9), rng.uniform(0.3, 0.7), rng.uniform(0.2, 0.6),
                        rng.uniform(0.6, 1.4)))

    def fn(x, y):
        u, v = x / w, y / h
        a = 0.6 * math.exp(-0.5 * ((v - 0.5) / sigma) ** 2)
        for start, length, row, bright, thick in streaks:
            du = (u - start) % 1.0
            if du < length:
                fade = math.sin(math.pi * du / length)
                a += bright * fade * (1 - smoothstep(0, thick / h, abs(v - row) - 0.5 / h))
        return min(1.0, a) * smoothstep(0.02, 0.1, min(v, 1 - v))

    return field(w, h, fn)


def draw_beam_arcane(key, w, h):
    amp = 0.25

    def fn(draw, off, k):
        for phase in (0, math.pi):
            pts = []
            for i in range(129):
                u = i / 128
                pts.append((off + u * w * k, (0.5 + amp * math.sin(u * TAU * 2 + phase)) * h * k))
            polyline(draw, pts, 4 * k)
        for i in range(8):
            u = i / 8
            circle(draw, off + u * w * k, 0.5 * h * k, 3 * k, fill=255)

    core = wrap_draw(w, h, 4, fn)
    halo = scale(blur(core, 5), 0.6)
    return multiply(middle(lighter(core, halo)), edge_window(w, h, 0, 0.03))


def draw_beam_poison(key, w, h):
    rng = rng_for(key)
    noise = noise_sampler(value_noise(rng, w, h, 8, 3), w, h)
    bubbles = [(rng.uniform(0, 1), rng.uniform(0.38, 0.62), rng.uniform(4, 9)) for _ in range(rng.randint(8, 12))]

    def band(x, y):
        u, v = x / w, y / h
        centre = 0.5 + 0.1 * math.sin(u * TAU)
        half = 0.2 + 0.08 * (noise(x, y) - 0.5) * 2
        d = abs(v - centre) / half
        return 0.55 * (1 - smoothstep(0.75, 1.0, d))

    base = field(w, h, band)

    def bub(draw, off, k):
        for u, v, r in bubbles:
            circle(draw, off + u * w * k, v * h * k, r * k, fill=60)
            circle(draw, off + u * w * k, v * h * k, r * k, outline=255, width=1.5 * k)

    rings = middle(wrap_draw(w, h, 4, bub))
    return multiply(lighter(base, rings), edge_window(w, h, 0, 0.03))


def draw_trail_soft(key, w, h):
    def fn(x, y):
        u, v = x / w, y / h
        across = math.exp(-0.5 * ((v - 0.5) / 0.17) ** 2) * smoothstep(0.02, 0.08, min(v, 1 - v))
        return across * (1 - u**1.3)

    return field(w, h, fn)


def draw_trail_streak(key, w, h):
    rng = rng_for(key)
    lines = []
    for _ in range(rng.randint(14, 20)):
        v = 0.1 + 0.8 * rng.random() ** 1.8  # denser near V = 0 (the weapon's tip)
        lines.append((v, rng.uniform(0.3, 1.0), rng.uniform(1, 3)))

    def body(draw, img, k):
        for v, length, thick in lines:
            steps = 24
            for i in range(steps):
                u0, u1 = i / steps * length, (i + 1) / steps * length
                alpha = int(255 * (1 - u0 / length) * (1 - 0.5 * v))
                draw.line([(u0 * w * k, v * h * k), (u1 * w * k, v * h * k)], fill=alpha, width=max(1, int(thick * k)))

    return multiply(supersample(body, w, h), edge_window(w, h, 0, 0.03))


# The list (fixed order; new textures at the end) ----------------------------------------------------------------------

# key, file, w, h, kind, grid, frames, wrap, draw
TEXTURES = [
    ("glow", "glow.png", 256, 256, "particle", None, None, False, draw_glow),
    ("spark", "spark.png", 128, 128, "particle", None, None, False, draw_spark),
    ("star", "star.png", 256, 256, "particle", None, None, False, draw_star),
    ("smoke", "smoke.png", 1024, 1024, "particle", "4x4", 16, False, draw_smoke),
    ("fire", "fire.png", 1024, 1024, "particle", "4x4", 16, False, draw_fire),
    ("dust", "dust.png", 256, 256, "particle", None, None, False, draw_dust),
    ("slashWide", "slash_wide.png", 512, 512, "beam", None, None, False, draw_slash_wide),
    ("slashNarrow", "slash_narrow.png", 512, 512, "beam", None, None, False, draw_slash_narrow),
    ("ring", "ring.png", 512, 512, "beam", None, None, False, draw_ring),
    ("cracks", "cracks.png", 512, 512, "decal", None, None, False, draw_cracks),
    ("runeWarrior", "rune_warrior.png", 512, 512, "beam", None, None, False, draw_rune_warrior),
    ("runeHunter", "rune_hunter.png", 512, 512, "beam", None, None, False, draw_rune_hunter),
    ("runeMage", "rune_mage.png", 512, 512, "beam", None, None, False, draw_rune_mage),
    ("runeCleric", "rune_cleric.png", 512, 512, "beam", None, None, False, draw_rune_cleric),
    ("magicCircle", "magic_circle.png", 1024, 1024, "beam", None, None, False, draw_magic_circle),
    ("beamLightning", "beam_lightning.png", 256, 128, "beam", None, None, True, draw_beam_lightning),
    ("beamHoly", "beam_holy.png", 256, 128, "beam", None, None, True, draw_beam_holy),
    ("beamArcane", "beam_arcane.png", 256, 128, "beam", None, None, True, draw_beam_arcane),
    ("beamPoison", "beam_poison.png", 256, 128, "beam", None, None, True, draw_beam_poison),
    ("trailSoft", "trail_soft.png", 256, 64, "trail", None, None, False, draw_trail_soft),
    ("trailStreak", "trail_streak.png", 256, 64, "trail", None, None, False, draw_trail_streak),
    ("iceShard", "ice_shard.png", 256, 256, "particle", None, None, False, draw_ice_shard),
    ("poisonBubble", "poison_bubble.png", 1024, 1024, "particle", "4x4", 16, False, draw_poison_bubble),
    ("feather", "feather.png", 256, 256, "particle", None, None, False, draw_feather),
    ("darkSpark", "dark_spark.png", 128, 128, "particle", None, None, False, draw_dark_spark),
]


def render(entry):
    key, _file, w, h, _kind, _grid, _frames, _wrap, fn = entry
    mask = fn(key, w, h)
    assert mask.size == (w, h), f"{key}: drawn {mask.size}, expected {(w, h)}"
    return alpha_to_rgba(mask)


def frames_of(img, grid_name):
    n = int(grid_name.split("x")[0])
    fs = img.size[0] // n
    return [img.crop(((i % n) * fs, (i // n) * fs, (i % n + 1) * fs, (i // n + 1) * fs)) for i in range(n * n)]


def quality(entry, img):
    """Problems of a drawn texture (margin, seam, flipbook frames): a list of texts, empty when fine."""
    key, _file, _w, _h, kind, grid_name, _frames, wrap, _fn = entry
    problems = []
    parts = frames_of(img, grid_name) if grid_name else [img]
    along_u = wrap or kind == "trail"  # a trail starts at U = 0 by design
    for i, part in enumerate(parts):
        if not margin_ok(part, MARGIN, along_u):
            problems.append(f"{key}: touches the edge" + (f" (frame {i + 1})" if grid_name else ""))
    if wrap and not tile_check(img):
        problems.append(f"{key}: seam along U")
    return problems


def manifest_row(entry, img, custom=False, hash_value=None):
    key, file, w, h, kind, grid_name, frames, _wrap, _fn = entry
    return {
        "key": key,
        "file": file,
        "w": w,
        "h": h,
        "kind": kind,
        "grid": grid_name,
        "frames": frames,
        "hash": hash_value or pixel_hash(img),
        "custom": custom,
    }


def load_manifest():
    if not os.path.exists(MANIFEST):
        return None
    with open(MANIFEST, encoding="utf-8") as f:
        return json.load(f)


def write_manifest(rows):
    data = {"version": 1, "generator": "tools/vfx/make_textures.py", "textures": rows}
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def build(only):
    os.makedirs(OUT_DIR, exist_ok=True)
    old = load_manifest()
    old_rows = {r["key"]: r for r in (old or {}).get("textures", [])}
    rows = []
    problems = []
    for entry in TEXTURES:
        key, file = entry[0], entry[1]
        prev = old_rows.get(key)
        path = os.path.join(OUT_DIR, file)
        if prev and prev.get("custom"):
            rows.append(prev)
            print(f"  {key}: custom, kept")
            continue
        if only and key not in only:
            if prev:
                rows.append(prev)
                continue
        img = render(entry)
        problems += quality(entry, img)
        img.save(path, "PNG")
        rows.append(manifest_row(entry, img))
        print(f"  {key}: {file} {entry[2]}x{entry[3]}")
    write_manifest(rows)
    for p in problems:
        print("WARNING", p)
    return 0


def check():
    data = load_manifest()
    if not data:
        print("art/vfx/manifest.json is missing")
        return 1
    rows = {r["key"]: r for r in data.get("textures", [])}
    diffs = []
    keys = [r["key"] for r in data.get("textures", [])]
    if keys != [e[0] for e in TEXTURES]:
        diffs.append("manifest keys / order differ from TEXTURES")
    for entry in TEXTURES:
        key, file, w, h = entry[0], entry[1], entry[2], entry[3]
        row = rows.get(key)
        path = os.path.join(OUT_DIR, file)
        if not row:
            diffs.append(f"{key}: no manifest row")
            continue
        if not os.path.exists(path):
            diffs.append(f"{key}: {file} is missing")
            continue
        with Image.open(path) as f:
            on_disk = f.convert("RGBA")
        if on_disk.size != (w, h) or (row["w"], row["h"]) != (w, h):
            diffs.append(f"{key}: size {on_disk.size}, manifest {(row['w'], row['h'])}, generator {(w, h)}")
            continue
        if row.get("custom"):
            continue
        drawn = pixel_hash(render(entry))
        if drawn != row["hash"]:
            diffs.append(f"{key}: drawn hash {drawn} != manifest {row['hash']}")
        if pixel_hash(on_disk) != row["hash"]:
            diffs.append(f"{key}: {file} pixels differ from the manifest (rebuild, or mark it custom)")
    for d in diffs:
        print("DIFF", d)
    print(f"{len(TEXTURES)} textures, {len(diffs)} differences")
    return 1 if diffs else 0


TINTS = [(0xFF, 0x7A, 0x1A), (0x7F, 0xD4, 0xFF), (0xE8, 0xC2, 0x5A)]
CELL = 256


def checker(size):
    img = Image.new("RGB", (size, size), (24, 24, 28))
    d = ImageDraw.Draw(img)
    step = 16
    for y in range(0, size, step):
        for x in range(0, size, step):
            if (x // step + y // step) % 2:
                d.rectangle((x, y, x + step - 1, y + step - 1), fill=(34, 34, 40))
    return img


def fit(img, size):
    w, h = img.size
    f = min(size / w, size / h)
    return img.resize((max(1, int(w * f)), max(1, int(h * f))), Image.Resampling.LANCZOS)


def tinted(img, rgb):
    r, g, b = rgb
    a = img.getchannel("A")
    return Image.merge("RGBA", (Image.new("L", img.size, r), Image.new("L", img.size, g), Image.new("L", img.size, b), a))


def preview(path):
    blocks = []
    for i, entry in enumerate(TEXTURES):
        img = render(entry)
        cells = [img, tinted(img, TINTS[i % len(TINTS)])]
        if entry[5]:
            frames = frames_of(img, entry[5])
            cells += [frames[0], frames[len(frames) // 2 - 1], frames[-1]]
        blocks.append((entry[0], cells))
    per_row, block_cells, label = 2, 5, 18
    rows = (len(blocks) + per_row - 1) // per_row
    sheet = Image.new("RGB", (per_row * block_cells * CELL, rows * (CELL + label)), (12, 12, 14))
    d = ImageDraw.Draw(sheet)
    for i, (key, cells) in enumerate(blocks):
        bx = (i % per_row) * block_cells * CELL
        by = (i // per_row) * (CELL + label)
        d.text((bx + 4, by + 3), key, fill=(230, 230, 230))
        for j, cell in enumerate(cells):
            bg = checker(CELL)
            small = fit(cell, CELL)
            bg.paste(small, ((CELL - small.size[0]) // 2, (CELL - small.size[1]) // 2), small)
            sheet.paste(bg, (bx + j * CELL, by + label))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    sheet.save(path, "PNG")
    print(f"preview: {path}")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Vaelthorn effect textures (S112)")
    parser.add_argument("--only", help="comma-separated keys to redraw")
    parser.add_argument("--check", action="store_true", help="compare drawn pixels with the manifest")
    parser.add_argument("--preview", help="write a preview sheet to this path")
    args = parser.parse_args()
    if args.check:
        return check()
    if args.preview:
        return preview(args.preview)
    only = set(args.only.split(",")) if args.only else None
    return build(only)


if __name__ == "__main__":
    sys.exit(main())
