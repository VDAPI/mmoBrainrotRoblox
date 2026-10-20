"""Procedural hand-painted skyboxes for Vaelthorn (Roblox Sky: bk dn ft lf rt up).

Everything is a function of the view direction, so the six faces meet without seams.
Roblox coordinates: X east, Y up, Z south (-Z north). Face convention (DevForum "Custom Skyboxes 101"):
standard cube faces pz->Bk, nz->Ft, nx->Lf, px->Rt, py->Up (rotated 90 CW), ny->Dn (rotated 90 CCW), with the
standard faces as jaxry's panorama-to-cubemap makes them (its axes: x=-Z, y=-X, z=Y).

Usage (owner 2026-10-20, docs/wyglad/ZAKUPY.md: painted skies at 0 zl; the ids go to Data/MapLooks.paintedSkies):
  python3 tools/sky/sky.py faces <out_dir> 1024 [names...]   six PNGs per sky in <out_dir>/<name>/
  python3 tools/sky/view.py <out_dir> sheet.png <names...>    contact sheet (views through the same face mapping)
"""

import math
import os
import sys

import numpy as np
from PIL import Image

F32 = np.float32


# ---------------------------------------------------------------- noise


def _hash(ix, iy, seed):
    h = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(F32) / F32(65535.0)


def vnoise(x, y, seed=0):
    ix = np.floor(x)
    iy = np.floor(y)
    fx = (x - ix).astype(F32)
    fy = (y - iy).astype(F32)
    ix = ix.astype(np.int64)
    iy = iy.astype(np.int64)
    ux = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
    uy = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
    a = _hash(ix, iy, seed)
    b = _hash(ix + 1, iy, seed)
    c = _hash(ix, iy + 1, seed)
    d = _hash(ix + 1, iy + 1, seed)
    return (a + (b - a) * ux) + ((c + (d - c) * ux) - (a + (b - a) * ux)) * uy


def fbm(x, y, octaves=5, seed=0, gain=0.5, lacunarity=2.03, fade=None):
    """fbm in 0..1; `fade` (0..1 array) damps the high octaves (less detail far away, no shimmer)."""
    total = np.zeros_like(x, dtype=F32)
    norm = 0.0
    amp = 1.0
    fx, fy = x, y
    for o in range(octaves):
        w = F32(amp)
        n = vnoise(fx, fy, seed + o * 31)
        if fade is not None and o >= 2:
            w = w * np.clip(fade * 1.6 - (o - 2) * 0.35, 0, 1)
            total += w * n
            norm = norm + w
        else:
            total += w * n
            norm = norm + amp
        amp *= gain
        # rotate each octave a little so the lattice does not line up
        fx, fy = fx * lacunarity * 0.8 - fy * lacunarity * 0.6 + 17.3, fx * lacunarity * 0.6 + fy * lacunarity * 0.8 + 9.1
    return (total / norm).astype(F32)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=F32)


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) else t
    return a + (b - a) * t


# ---------------------------------------------------------------- faces


def face_dirs(face, n):
    """Unit view directions (n, n, 3) in Roblox coords for a Roblox face, already in its final image orientation."""
    c = (np.arange(n, dtype=F32) + 0.5) / n * 2 - 1
    u, v = np.meshgrid(c, c)  # u: column (right), v: row (down)
    one = np.ones_like(u)
    # jaxry orientations: returns (x, y, z) in its axes
    jx = {
        "pz": (-one, -u, -v),
        "nz": (one, u, -v),
        "px": (u, -one, -v),
        "nx": (-u, one, -v),
        "py": (-v, -u, one),
        "ny": (v, -u, -one),
    }
    std = {"bk": "pz", "ft": "nz", "lf": "nx", "rt": "px", "up": "py", "dn": "ny"}[face]
    x, y, z = jx[std]
    d = np.stack([-y, z, -x], axis=-1)  # Roblox X = -y, Y = z, Z = -x
    d /= np.linalg.norm(d, axis=-1, keepdims=True)
    if face == "up":
        d = np.rot90(d, k=-1)  # image rotated 90 CW: pixel (r, c) of the result shows source (n-1-c, r)
    elif face == "dn":
        d = np.rot90(d, k=1)
    return np.ascontiguousarray(d)


def equirect_dirs(w, h):
    lon = (np.arange(w, dtype=F32) + 0.5) / w * 2 * math.pi - math.pi  # 0 at north (-Z), +90 east
    lat = math.pi / 2 - (np.arange(h, dtype=F32) + 0.5) / h * math.pi
    lo, la = np.meshgrid(lon, lat)
    return np.stack([np.cos(la) * np.sin(lo), np.sin(la), -np.cos(la) * np.cos(lo)], axis=-1).astype(F32)


def sun_dir(hour, latitude=41.733):
    """Roblox sun at an hour (no seasons): east +X, south +Z."""
    H = math.radians(15 * (hour - 12))
    phi = math.radians(latitude)
    v = np.array([-math.sin(H), math.cos(phi) * math.cos(H), math.sin(phi) * math.cos(H)], dtype=F32)
    return v / np.linalg.norm(v)


# ---------------------------------------------------------------- the painting


def paint(d, p):
    """Colour (…, 3) in 0..1 for view directions d under the palette / settings p."""
    y = d[..., 1]
    s = p["sun"]
    cosang = np.clip(d @ s, -1, 1)
    ang = np.arccos(cosang)
    # horizontal closeness to the sun's side (0 opposite .. 1 toward)
    hs = np.array([s[0], 0, s[2]], dtype=F32)
    hs /= max(1e-6, float(np.linalg.norm(hs)))
    dh = d.copy()
    dh[..., 1] = 0
    hlen = np.linalg.norm(dh, axis=-1, keepdims=True)
    side = (dh @ hs + 1) * 0.5  # unnormalised: fades to 0.5 toward the zenith (no pinch at the top)
    dh /= np.maximum(hlen, 1e-6)

    # ---- sky gradient (soft, slightly bent by the sun's side)
    e = np.clip(y, 0, 1)
    t1 = smoothstep(0.0, p.get("midAt", 0.35), e)
    t2 = smoothstep(p.get("midAt", 0.35) * 0.6, 1.0, e)
    horizon = mix(p["horizonAway"], p["horizonSun"], side ** p.get("sidePow", 2.0))
    mid = mix(p["midAway"], p["midSun"], side ** 1.5)
    col = mix(horizon, mid, t1 ** 0.8)
    col = mix(col, p["zenith"], t2 ** 1.3)

    # ---- sun glow: a broad warm scattering plus a tighter halo (Roblox draws the disc itself)
    glow = p.get("glow", 0.6) * np.exp(-((ang / p.get("glowWidth", 0.55)) ** 2))
    glow += p.get("haloStrength", 0.5) * np.exp(-((ang / p.get("haloWidth", 0.12)) ** 2))
    col = mix(col, p["glowColor"], np.clip(glow, 0, 1))

    # ---- clouds on a curved plane above (perspective: small and flat toward the horizon)
    up = np.clip(y, 0.0, 1.0)
    k = 1.0 / (up + p.get("planeBend", 0.22))
    qx = d[..., 0] * k * p["cloudScale"]
    qz = d[..., 2] * k * p["cloudScale"]
    stretch = p.get("stretch", 1.0)
    qx = qx / stretch
    detail = smoothstep(0.03, 0.45, up)  # high octaves only where the clouds are near
    wx = fbm(qx * 0.45 + 3.1, qz * 0.45 - 7.7, 3, seed=p["seed"] + 5) - 0.5
    wz = fbm(qx * 0.45 - 5.2, qz * 0.45 + 1.9, 3, seed=p["seed"] + 9) - 0.5
    warp = p.get("warp", 1.3)
    cx = qx + wx * warp
    cz = qz + wz * warp

    def density(ax, az):
        n = fbm(ax, az, p.get("octaves", 5), seed=p["seed"], fade=detail)
        big = fbm(ax * 0.23 + 11, az * 0.23 - 4, 2, seed=p["seed"] + 77)
        return n + (big - 0.5) * p.get("clump", 0.5)

    n0 = density(cx, cz)
    # thinner overhead, denser toward the horizon (as a real sky reads)
    cov = p["cover"] + up * p.get("coverRise", 0.06)
    soft = p.get("edge", 0.12)
    a = smoothstep(cov, cov + soft, n0)
    # light from the sun: compare density a step toward the sun on the plane
    sx, sz = float(hs[0]), float(hs[2])
    step = p.get("lightStep", 0.22)
    n1 = density(cx + sx * step / stretch, cz + sz * step)
    lit = np.clip(0.55 + (n0 - n1) * p.get("lightGain", 4.0), 0, 1)
    thick = smoothstep(cov, cov + 0.35, n0)
    lit = np.clip(lit - thick * p.get("bellyDark", 0.35), 0, 1)
    # painted: shading in a few soft steps
    steps = p.get("bands", 4)
    q = lit * steps
    cel = p.get("cel", 0.5)
    lit = np.clip((np.floor(q) + smoothstep(0.3, 0.7, q - np.floor(q))) / steps, 0, 1) * cel + lit * (1 - cel)
    cc = mix(p["cloudShadow"], p["cloudMid"], smoothstep(0, 0.55, lit))
    cc = mix(cc, p["cloudLit"], smoothstep(0.5, 1.0, lit))
    # silver lining: thin edges glow toward the sun
    rim = (1 - smoothstep(cov, cov + soft * 2.5, n0)) * a * np.exp(-((ang / p.get("rimWidth", 0.7)) ** 2))
    cc = mix(cc, p["rimColor"], np.clip(rim * p.get("rim", 0.9), 0, 1))
    # far clouds melt into the horizon colour
    far = 1 - smoothstep(0.0, p.get("airDepth", 0.45), up)
    cc = mix(cc, horizon * 0.6 + col * 0.4, far * p.get("airMix", 0.7))
    a = a * smoothstep(0.015, p.get("cloudLow", 0.10), up) * p.get("cloudAlpha", 1.0)
    col = mix(col, cc, a)

    # ---- distant cloud banks on the horizon (seamless in azimuth: noise on a circle)
    if p.get("banks", 0) > 0:
        r = p.get("bankFreq", 3.0)
        bx = dh[..., 0] * r
        bz = dh[..., 2] * r
        top = p.get("bankHeight", 0.07) * (0.35 + fbm(bx + 40, bz - 13, 4, seed=p["seed"] + 101) * 1.3)
        top = top * (0.6 + 0.8 * fbm(bx * 0.4 + 2, bz * 0.4, 2, seed=p["seed"] + 131))
        inside = 1 - smoothstep(top - 0.012, top + 0.006, y)
        bandShade = smoothstep(-0.02, 1.0, y / np.maximum(top, 1e-3))
        bank = mix(p["bankDark"], p["bankLit"], bandShade * (0.5 + 0.5 * side))
        bank = mix(bank, p["glowColor"], np.clip(glow * 0.5, 0, 1))
        col = mix(col, bank, inside * p["banks"] * smoothstep(-0.04, 0.0, y))

    # ---- haze band at the horizon, the ground below fades into the fog colour
    haze = np.exp(-((y / p.get("hazeWidth", 0.06)) ** 2)) * p.get("haze", 0.5)
    col = mix(col, p["hazeColor"], np.clip(haze, 0, 1))
    below = smoothstep(0.0, -0.08, y)
    ground = mix(p["fog"], p["fog"] * 0.82, smoothstep(0, -0.6, y))
    col = mix(col, ground, below)

    # ---- brush strokes: very soft, long streaks (no grain)
    bs = fbm(d[..., 0] * 9 + d[..., 2] * 2, d[..., 1] * 34, 3, seed=p["seed"] + 300) - 0.5
    # only near the horizon: contours of the height are rings around the zenith
    bs = bs * (1 - smoothstep(0.15, 0.45, np.abs(y)))
    col = col * (1 + bs[..., None] * p.get("brush", 0.05))
    if p.get("stars", 0) > 0:
        # sparse soft stars painted into the night sky (big enough not to shimmer)
        g = 160.0
        sxs, sys_ = d[..., 0] * g / (np.abs(d[..., 1]) + 0.6), d[..., 2] * g / (np.abs(d[..., 1]) + 0.6)
        cellx, cellz = np.floor(sxs), np.floor(sys_)
        hval = _hash(cellx.astype(np.int64), cellz.astype(np.int64), p["seed"] + 999)
        ox = _hash(cellx.astype(np.int64), cellz.astype(np.int64), p["seed"] + 1001)
        oz = _hash(cellx.astype(np.int64), cellz.astype(np.int64), p["seed"] + 1003)
        dist = np.hypot(sxs - cellx - (0.25 + ox * 0.5), sys_ - cellz - (0.25 + oz * 0.5))
        star = (hval > 0.965) * np.exp(-((dist / 0.09) ** 2)) * smoothstep(0.08, 0.4, y) * (1 - a)
        col = mix(col, hexc("#F4F0FF"), np.clip(star * p["stars"], 0, 1))
    return np.clip(col, 0, 1)


# ---------------------------------------------------------------- palettes (Data/Maps fog colours on the horizon)

SKIES = {
    # Meadows, 17:00: golden afternoon, soft cumulus
    "laki": dict(
        hour=17.0, seed=11,
        zenith=hexc("#3F78BE"), midAway=hexc("#7FAEDC"), midSun=hexc("#A9C4DA"),
        horizonAway=hexc("#C8D8E2"), horizonSun=hexc("#F6D8A4"), sidePow=1.6, midAt=0.32,
        glowColor=hexc("#FFE2A8"), glow=0.55, glowWidth=0.6, haloStrength=0.55, haloWidth=0.14,
        cloudScale=1.25, cover=0.55, coverRise=0.1, edge=0.12, clump=0.65, warp=1.3, bands=3, cel=0.45,
        cloudLit=hexc("#FFF6E4"), cloudMid=hexc("#EEE2D8"), cloudShadow=hexc("#AEB2CA"), rimColor=hexc("#FFE6B0"),
        bellyDark=0.15, lightGain=4.0,
        banks=0.85, bankHeight=0.06, bankDark=hexc("#C8C4C4"), bankLit=hexc("#F6E8D2"),
        haze=0.45, hazeWidth=0.05, hazeColor=hexc("#EADAB8"), fog=hexc("#E6D2AE"), brush=0.04,
    ),
    # City by day: a high sun, a clear blue painted sky with fair-weather clouds
    "miasto-dzien": dict(
        hour=12.5, seed=23,
        zenith=hexc("#3A72BA"), midAway=hexc("#78A8DA"), midSun=hexc("#8EB8E0"),
        horizonAway=hexc("#C6D6E4"), horizonSun=hexc("#D8E0E6"), sidePow=1.5, midAt=0.32,
        glowColor=hexc("#FFF6E0"), glow=0.35, glowWidth=0.5, haloStrength=0.45, haloWidth=0.1,
        cloudScale=1.3, cover=0.57, coverRise=0.1, edge=0.12, clump=0.65, warp=1.3, bands=3, cel=0.45,
        cloudLit=hexc("#FFFFFA"), cloudMid=hexc("#E8ECF2"), cloudShadow=hexc("#B0BACE"), rimColor=hexc("#FFFFFF"),
        bellyDark=0.15, lightGain=4.0,
        banks=0.8, bankHeight=0.055, bankDark=hexc("#B8C4D2"), bankLit=hexc("#EEF2F6"),
        haze=0.4, hazeWidth=0.05, hazeColor=hexc("#D6E0E8"), fog=hexc("#C9D6E3"), brush=0.04,
    ),
    # City by night: deep navy, moonlit cloud edges, a few soft stars
    "miasto-noc": dict(
        hour=0.5, seed=29, sun_override=np.array([0.35, 0.55, 0.75], dtype=F32),
        zenith=hexc("#0C1230"), midAway=hexc("#18224A"), midSun=hexc("#22305A"),
        horizonAway=hexc("#26304E"), horizonSun=hexc("#34406A"), sidePow=1.5, midAt=0.3,
        glowColor=hexc("#5A6A9A"), glow=0.25, glowWidth=0.5, haloStrength=0.3, haloWidth=0.1,
        cloudScale=1.2, cover=0.58, edge=0.14, clump=0.6, warp=1.3,
        cloudLit=hexc("#6C7AA6"), cloudMid=hexc("#36406A"), cloudShadow=hexc("#1A2040"), rimColor=hexc("#A8B6DE"),
        bellyDark=0.25, lightGain=4.0, rim=0.6,
        banks=0.7, bankHeight=0.05, bankDark=hexc("#141A34"), bankLit=hexc("#2C3658"),
        haze=0.35, hazeWidth=0.05, hazeColor=hexc("#2A3456"), fog=hexc("#1C2438"), brush=0.05, stars=0.9,
    ),
    # Duskwood, 15:30 under heavy cloud: dusk violet, layered stratus, a low pink rim toward the sun
    "bor": dict(
        hour=15.5, seed=37,
        zenith=hexc("#2C2A4C"), midAway=hexc("#4C4A6E"), midSun=hexc("#6E5E86"),
        horizonAway=hexc("#6A6C78"), horizonSun=hexc("#B08C98"), sidePow=2.0, midAt=0.3,
        glowColor=hexc("#E8B0A0"), glow=0.45, glowWidth=0.5, haloStrength=0.35, haloWidth=0.12,
        cloudScale=0.7, stretch=1.8, cover=0.42, coverRise=0.02, edge=0.25, clump=0.5, warp=1.1, octaves=5, cel=0.35,
        cloudLit=hexc("#A890AC"), cloudMid=hexc("#625A82"), cloudShadow=hexc("#3C3858"), rimColor=hexc("#F0B8A8"),
        bellyDark=0.2, lightGain=2.5, rim=0.8, rimWidth=0.6,
        banks=0.9, bankHeight=0.075, bankDark=hexc("#3A3C4A"), bankLit=hexc("#6A6478"),
        haze=0.55, hazeWidth=0.06, hazeColor=hexc("#6A7068"), fog=hexc("#4A544A"), brush=0.05,
    ),
    # Ashen Wastes, 17:12: warm dust haze at sunset, thin streaked clouds lit orange
    "pustkowia": dict(
        hour=17.2, seed=41,
        zenith=hexc("#5A5C80"), midAway=hexc("#A08490"), midSun=hexc("#E0A078"),
        horizonAway=hexc("#D8A486"), horizonSun=hexc("#FFC488"), sidePow=1.4, midAt=0.42,
        glowColor=hexc("#FFD49A"), glow=0.7, glowWidth=0.7, haloStrength=0.6, haloWidth=0.15,
        cloudScale=1.3, stretch=2.6, cover=0.47, coverRise=0.16, edge=0.24, cloudAlpha=0.85, clump=0.6, warp=1.1, octaves=5,
        cloudLit=hexc("#FFD0A0"), cloudMid=hexc("#D88E78"), cloudShadow=hexc("#8A6278"), rimColor=hexc("#FFE0A8"),
        bellyDark=0.25, lightGain=3.5, rim=1.0, rimWidth=0.8,
        banks=0.6, bankHeight=0.05, bankDark=hexc("#9A6E66"), bankLit=hexc("#E8A884"),
        haze=0.75, hazeWidth=0.09, hazeColor=hexc("#EAAE84"), fog=hexc("#E2A47A"), brush=0.05,
    ),
    # Frostpeak, 07:36: cold clear morning, pale blue, peach glow at the low sun, thin high cloud
    "szczyty": dict(
        hour=7.6, seed=53,
        zenith=hexc("#3A6AA6"), midAway=hexc("#86AED6"), midSun=hexc("#B4C8DE"),
        horizonAway=hexc("#D6E4F2"), horizonSun=hexc("#FCE2CC"), sidePow=1.8, midAt=0.33,
        glowColor=hexc("#FFE6CE"), glow=0.5, glowWidth=0.55, haloStrength=0.55, haloWidth=0.12,
        cloudScale=1.1, stretch=2.0, cover=0.56, coverRise=0.06, edge=0.15, clump=0.6, warp=1.2,
        cloudLit=hexc("#FFF6EE"), cloudMid=hexc("#DCE6F2"), cloudShadow=hexc("#94A8C8"), rimColor=hexc("#FFE8D4"),
        bellyDark=0.25, lightGain=4.0, cloudAlpha=0.9,
        banks=0.8, bankHeight=0.05, bankDark=hexc("#A8B8CE"), bankLit=hexc("#EEF2F8"),
        haze=0.5, hazeWidth=0.06, hazeColor=hexc("#E2ECF6"), fog=hexc("#D2E4F4"), brush=0.035,
    ),
}

FACES = ["bk", "dn", "ft", "lf", "rt", "up"]


def settings(name):
    p = dict(SKIES[name])
    p["sun"] = p.get("sun_override")
    if p["sun"] is None:
        p["sun"] = sun_dir(p["hour"])
    else:
        p["sun"] = p["sun"] / np.linalg.norm(p["sun"])
    return p


def to_img(col, seed=0):
    rng = np.random.default_rng(seed)
    c = col * 255 + rng.uniform(-0.5, 0.5, col.shape)  # dither against banding (half a step)
    return Image.fromarray(np.clip(c + 0.5, 0, 255).astype(np.uint8))


def render_faces(name, out_dir, n=1024, ss=1):
    p = settings(name)
    os.makedirs(out_dir, exist_ok=True)
    for f in FACES:
        d = face_dirs(f, n * ss)
        col = paint(d, p)
        img = to_img(col, FACES.index(f))
        if ss > 1:
            img = img.resize((n, n), Image.LANCZOS)
        img.save(os.path.join(out_dir, f + ".png"), optimize=True)


def render_equirect(name, w=1024):
    p = settings(name)
    d = equirect_dirs(w, w // 2)
    return to_img(paint(d, p))


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "eq":
        names = sys.argv[3:] or list(SKIES)
        for nm in names:
            render_equirect(nm, int(sys.argv[2])).save(f"eq_{nm}.png")
    elif cmd == "faces":
        out = sys.argv[2]
        n = int(sys.argv[3])
        for nm in sys.argv[4:] or list(SKIES):
            render_faces(nm, os.path.join(out, nm), n)
