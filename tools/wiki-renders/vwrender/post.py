"""Image post: contact shadow, Neon glow, premultiplied downscale and WebP output.

Images are float (h, w, 4) premultiplied RGBA in sRGB, 0..1.
"""
import io

import numpy as np
from PIL import Image, ImageFilter, features

SHADOW_ALPHA = 0.45
GLOW_RADIUS = 0.015  # of the image side
GLOW_STRENGTH = 0.9


def check_webp():
    if not features.check("webp"):
        raise SystemExit("Pillow bez obsługi WebP (Pillow without WebP support): py -3 -m pip install -U Pillow")


def shadow(cam, centre, radii, hovers):
    """Alpha (size, size) of a soft black ellipse on the ground plane y = 0."""
    d = cam.rays()
    with np.errstate(divide="ignore", invalid="ignore"):
        t = -cam.eye[1] / d[..., 1]
    x = cam.eye[0] + t * d[..., 0]
    z = cam.eye[2] + t * d[..., 2]
    r = np.sqrt(((x - centre[0]) / radii[0]) ** 2 + ((z - centre[1]) / radii[1]) ** 2)
    a = np.clip(1 - r, 0, 1) ** 1.6
    a = np.where((d[..., 1] < 0) & np.isfinite(r), a, 0)
    return a * SHADOW_ALPHA * (0.5 if hovers else 1.0)


def glow(img, neon_rgb, neon_mask):
    """Adds a blurred copy of the Neon pixels (colour and alpha) to a premultiplied image."""
    if not neon_mask.any():
        return img
    size = img.shape[0]
    src = np.zeros(img.shape)
    src[..., :3] = neon_rgb * neon_mask[..., None]
    src[..., 3] = neon_mask
    pil = Image.fromarray(np.round(np.clip(src, 0, 1) * 255).astype(np.uint8), "RGBA")
    # the blur must not treat colour and alpha differently: blur premultiplied channels independently
    channels = [c.filter(ImageFilter.GaussianBlur(GLOW_RADIUS * size)) for c in pil.split()]
    blurred = np.stack([np.asarray(c, float) / 255 for c in channels], axis=2)
    out = img + blurred * GLOW_STRENGTH
    out[..., 3] = np.clip(out[..., 3], 0, 1)
    out[..., :3] = np.minimum(out[..., :3], out[..., 3:4])
    return out


def to_image(premul):
    """Float premultiplied RGBA -> PIL "RGBa" image."""
    data = np.round(np.clip(premul, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(data, "RGBa")


def downscale(img, size):
    """Premultiplied (RGBa) Lanczos resize, back to straight RGBA: no dark fringes."""
    if img.mode != "RGBa":
        img = img.convert("RGBa")
    return img.resize((size, size), Image.LANCZOS).convert("RGBA")


def webp_bytes(img, quality, alpha_quality=90):
    buf = io.BytesIO()
    img.save(buf, "WEBP", quality=quality, method=6, alpha_quality=alpha_quality)
    return buf.getvalue()
