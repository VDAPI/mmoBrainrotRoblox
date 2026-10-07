"""Lighting for the dark wiki UI (light from the upper left, like the item icons), in linear RGB.

key   warm #FFF1DC from the upper left front of the camera (KEY)
fill  cool #9FB4D9 from the right (FILL)
amb   AMBIENT, slightly brighter on upward normals
rim   pow(1 - max(0, n.v), 3) in the rank colour (RIM): pulls dark silhouettes off the dark background
spec  Blinn-Phong of the key light per material (MATERIALS, every Logic/Anatomy material)
Neon is unlit (full colour) and glows in post.
"""
import numpy as np

KEY = 0.9
FILL = 0.25
AMBIENT = 0.30
RIM = 0.55
KEY_COLOR = "#FFF1DC"
FILL_COLOR = "#9FB4D9"

RANK_RIM = {"normal": "#C9A45C", "elite": "#E8C25A", "elite2": "#FF9F1C", "pet": "#E8E4DA"}

# material -> (specular strength, shininess)
MATERIALS = {
    "SmoothPlastic": (0.18, 24),
    "Fabric": (0.03, 6),
    "Leather": (0.06, 10),
    "Wood": (0.04, 8),
    "WoodPlanks": (0.04, 8),
    "Slate": (0.05, 8),
    "Basalt": (0.06, 10),
    "Rock": (0.04, 8),
    "Limestone": (0.04, 8),
    "Metal": (0.65, 40),
    "CorrodedMetal": (0.16, 14),
    "DiamondPlate": (0.5, 30),
    "Ice": (0.55, 60),
    "Glacier": (0.45, 40),
    "Glass": (0.7, 80),
    "Neon": (0.0, 1),
    "CrackedLava": (0.05, 8),
    "Grass": (0.03, 6),
    "Sand": (0.03, 6),
    "Granite": (0.08, 12),
}
GLASS_TRANSPARENCY = 0.25


def hex_rgb(h):
    return np.array([int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)], dtype=float) / 255.0


def to_linear(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def material_of(name, warn=None):
    if name in MATERIALS:
        return name
    if warn is not None:
        warn(f"unknown material {name!r}, using SmoothPlastic")
    return "SmoothPlastic"


def lights(cam):
    back = -cam.fwd
    key = -0.55 * cam.right + 0.7 * cam.up + 0.45 * back
    fill = 0.8 * cam.right + 0.05 * cam.up + 0.35 * back
    return key / np.linalg.norm(key), fill / np.linalg.norm(fill), back


def shade(normal, albedo, neon, spec, shininess, cam, rim_color):
    """Linear colour of pixels: normal (n, 3), albedo (n, 3) linear, neon (n,) bool, spec / shininess (n,)."""
    key_dir, fill_dir, view = lights(cam)
    key_c, fill_c = to_linear(hex_rgb(KEY_COLOR)), to_linear(hex_rgb(FILL_COLOR))
    nk = np.clip(normal @ key_dir, 0, 1)[:, None]
    nf = np.clip(normal @ fill_dir, 0, 1)[:, None]
    nv = np.clip(normal @ view, 0, 1)
    up = normal @ cam.up
    amb = AMBIENT * (0.85 + 0.15 * up)[:, None]
    diffuse = albedo * (amb + KEY * key_c * nk + FILL * fill_c * nf)
    half = key_dir + view
    half /= np.linalg.norm(half)
    nh = np.clip(normal @ half, 0, 1)
    highlight = (spec * np.power(nh, shininess) * (nk[:, 0] > 0))[:, None] * key_c * KEY
    rim = (RIM * (1 - nv) ** 3)[:, None] * to_linear(hex_rgb(rim_color))
    out = diffuse + highlight + rim
    out[neon] = albedo[neon]
    return out
