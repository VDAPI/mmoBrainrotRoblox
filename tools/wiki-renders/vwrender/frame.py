"""Camera and automatic framing.

Fixed 3/4 view: from the front (-Z), AZIMUTH degrees to the +X side (the weapon hand), ELEVATION degrees up,
perspective with FOV degrees. The look faces the right of the image. Framing fits every vertex and the contact
shadow into SAFE_W x SAFE_H of the image, centred horizontally, the lowest point on BOTTOM (fraction of the
height from the top). Per-file overrides: azimuth, elevation, zoom (x focal length), offsetY (fraction of height).
"""
import math

import numpy as np

AZIMUTH = 35.0
ELEVATION = 15.0
FOV = 22.0
SAFE_W = 0.84
SAFE_H = 0.80
BOTTOM = 0.94
TOP = 0.12


class Camera:
    def __init__(self, eye, fwd, right, up, focal, cx, cy, size):
        self.eye, self.fwd, self.right, self.up = eye, fwd, right, up
        self.focal, self.cx, self.cy, self.size = focal, cx, cy, size

    def view(self, pts):
        rel = pts - self.eye
        return rel @ self.right, rel @ self.up, rel @ self.fwd

    def project(self, pts):
        """Screen x, y (pixels, y down) and view depth of world points."""
        x, y, z = self.view(pts)
        z = np.maximum(z, 1e-3)
        return self.cx + self.focal * x / z, self.cy - self.focal * y / z, z

    def rays(self):
        """Direction of the ray through every pixel centre (size, size, 3), not normalised."""
        s = self.size
        px = (np.arange(s) + 0.5 - self.cx) / self.focal
        py = (self.cy - (np.arange(s) + 0.5)) / self.focal
        return (self.fwd[None, None, :] + px[None, :, None] * self.right[None, None, :]
                + py[:, None, None] * self.up[None, None, :])


def direction(azimuth, elevation):
    """Unit vector from the target to the eye."""
    a, e = math.radians(azimuth), math.radians(elevation)
    return np.array([math.sin(a) * math.cos(e), math.sin(e), -math.cos(a) * math.cos(e)])


def shadow_ellipse(points):
    """Contact shadow under a look: centre (x, z) and radii from the x / z extent of its points."""
    lo, hi = points.min(axis=0), points.max(axis=0)
    centre = ((lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2)
    radii = (max(0.3, 0.42 * (hi[0] - lo[0])), max(0.3, 0.42 * (hi[2] - lo[2])))
    return centre, radii


def ellipse_points(centre, radii, n=24):
    a = np.linspace(0, 2 * math.pi, n, endpoint=False)
    return np.stack([centre[0] + radii[0] * np.cos(a), np.zeros(n), centre[1] + radii[1] * np.sin(a)], axis=1)


# Wide looks (wings, long tails) turn towards a side view when that makes the figure clearly bigger.
AZIMUTHS = (35.0, 20.0, 50.0, 65.0, 80.0)
AUTO_GAIN = 1.25


def fit(points, size, override=None):
    """Camera that frames `points` (world, (n, 3)) in a square image of `size` pixels. Without an azimuth in
    the override, tries AZIMUTHS and keeps another one only if the figure grows by AUTO_GAIN."""
    o = override or {}
    if "azimuth" in o:
        return _fit(points, size, o)
    best = _fit(points, size, o)
    gain = best.focal * AUTO_GAIN
    for az in AZIMUTHS[1:]:
        cam = _fit(points, size, dict(o, azimuth=az))
        if cam.focal > gain and cam.focal > best.focal:
            best = cam
    return best


def _fit(points, size, o):
    lo, hi = points.min(axis=0), points.max(axis=0)
    target = (lo + hi) / 2
    radius = max(float(np.linalg.norm(hi - lo)) / 2, 0.5)
    back = direction(o.get("azimuth", AZIMUTH), o.get("elevation", ELEVATION))
    eye = target + back * radius / math.tan(math.radians(FOV / 2))
    fwd = -back
    right = np.cross(fwd, [0.0, 1.0, 0.0])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    cam = Camera(eye, fwd, right, up, 1.0, 0.0, 0.0, size)
    x, y, z = cam.view(points)
    nx, ny = x / z, y / z
    w, h = nx.max() - nx.min(), ny.max() - ny.min()
    focal = min(SAFE_W * size / max(w, 1e-6), SAFE_H * size / max(h, 1e-6)) * o.get("zoom", 1.0)
    cx = size / 2 - focal * (nx.max() + nx.min()) / 2
    cy = BOTTOM * size + focal * ny.min() + o.get("offsetY", 0.0) * size
    return Camera(eye, fwd, right, up, focal, cx, cy, size)
