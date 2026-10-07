"""Unit tests of the wiki renderer (S38): py -3 -m unittest discover -s tools/wiki-renders/tests -t tools/wiki-renders"""
import json
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

from vwrender import RENDERER_VERSION, frame, manifest, post, scene
from vwrender.mesh import MESHES, place

IDENTITY = [1, 0, 0, 0, 1, 0, 0, 0, 1]


def piece(shape="box", size=(1, 1, 1), pos=(0, 0.5, 0), color="#FF0000", material="SmoothPlastic", t=None):
    p = {"s": shape, "size": list(size), "p": list(pos), "r": IDENTITY, "c": color, "m": material, "lod": "shell"}
    if t is not None:
        p["t"] = t
    return p


def entry(pieces, kind="monster", variant="normal", hovers=False):
    return {"file": "x", "id": "x", "kind": kind, "variant": variant, "hovers": hovers, "scale": 1, "pieces": pieces}


class MeshTest(unittest.TestCase):
    def test_closed_with_outward_normals(self):
        for name, (verts, norms, tris) in MESHES.items():
            edges = {}
            keyed = [tuple(np.round(v, 6)) for v in verts]
            for t in tris:
                a, b, c = (keyed[i] for i in t)
                for e in ((a, b), (b, c), (c, a)):
                    k = tuple(sorted(e))
                    edges[k] = edges.get(k, 0) + 1
                centre = verts[list(t)].mean(axis=0)
                normal = norms[list(t)].mean(axis=0)
                self.assertGreater(float(normal @ centre), -1e-9, f"{name}: inward normal")
            self.assertTrue(all(n == 2 for n in edges.values()), f"{name}: open mesh")

    def test_scaled_normals_stay_unit(self):
        _, wn, _ = place(piece("ball", size=(4, 1, 2)))
        self.assertTrue(np.allclose(np.linalg.norm(wn, axis=1), 1))


class FrameTest(unittest.TestCase):
    def check_safe(self, pts):
        size = 400
        cam = frame.fit(pts, size)
        sx, sy, _ = cam.project(pts)
        self.assertGreaterEqual(sx.min(), size * (1 - frame.SAFE_W) / 2 - 1)
        self.assertLessEqual(sx.max(), size * (1 + frame.SAFE_W) / 2 + 1)
        self.assertLessEqual(sy.max(), size * frame.BOTTOM + 1)
        self.assertGreaterEqual(sy.min(), size * frame.TOP - 1)
        self.assertAlmostEqual((sx.min() + sx.max()) / 2, size / 2, delta=1)

    def box(self, w, h, d, y0=0.0):
        return np.array([[x, y, z] for x in (-w / 2, w / 2) for y in (y0, y0 + h) for z in (-d / 2, d / 2)])

    def test_tall_wide_and_floating_shapes_fit(self):
        self.check_safe(self.box(1, 8, 1))
        self.check_safe(self.box(12, 1, 2))
        self.check_safe(self.box(2, 2, 2, y0=4))


class PostTest(unittest.TestCase):
    def test_downscale_keeps_white_edges(self):
        arr = np.zeros((64, 64, 4))
        arr[16:48, 16:48] = 1.0  # white opaque square, premultiplied
        small = np.asarray(post.downscale(post.to_image(arr), 16), float)
        edge = small[..., 3] > 0
        self.assertTrue(edge.any())
        self.assertTrue((small[edge][:, :3] >= 250).all(), "dark fringe on a white shape")


class ManifestTest(unittest.TestCase):
    def test_hash(self):
        e = {"a": 1, "b": [1, 2]}
        h = manifest.entry_hash(e, None, {"full": 512})
        self.assertEqual(h, manifest.entry_hash({"b": [1, 2], "a": 1}, None, {"full": 512}))
        self.assertNotEqual(h, manifest.entry_hash(e, {"zoom": 1.1}, {"full": 512}))
        self.assertNotEqual(h, manifest.entry_hash(e, None, {"full": 512}, version=RENDERER_VERSION + 1))

    def test_removes_only_its_orphans(self):
        with tempfile.TemporaryDirectory() as d:
            for n in ("old.webp", "old-128.webp", "keep.webp", "foreign.webp"):
                (Path(d) / n).write_bytes(b"x")
            old = {"files": {"old": {"outputs": ["old.webp", "old-128.webp"]}, "keep": {"outputs": ["keep.webp"]}}}
            gone = manifest.orphans(old, {"keep": {}})
            self.assertEqual(gone, ["old"])
            for f in gone:
                manifest.remove_outputs(d, old["files"][f])
            self.assertEqual(sorted(p.name for p in Path(d).iterdir()), ["foreign.webp", "keep.webp"])


class RenderTest(unittest.TestCase):
    def test_red_box(self):
        e = entry([piece()])
        img = scene.render(e, 128)
        alpha = img[..., 3]
        red = (img[..., 0] > 0.3) & (alpha > 0.99)
        self.assertTrue(red.any())
        # alpha only in the silhouette and the shadow below it
        rows = np.nonzero(alpha > 0)[0]
        self.assertGreater(rows.min(), 128 * frame.TOP - 2)
        self.assertLess(rows.max(), 128)
        cols = np.nonzero(alpha.max(axis=0) > 0)[0]
        self.assertGreater(cols.min(), 0)
        self.assertLess(cols.max(), 127)
        shadow_only = (alpha > 0) & (alpha < 0.99)
        self.assertTrue((img[shadow_only][:, :3] < 1e-6).all(), "shadow must be black")
        again = scene.render(e, 128)
        self.assertEqual(post.webp_bytes(post.downscale(post.to_image(img), 64), 86),
                         post.webp_bytes(post.downscale(post.to_image(again), 64), 86))

    def test_transparent_and_neon(self):
        e = entry([piece(t=0.6), piece("ball", size=(0.4, 0.4, 0.4), pos=(0, 1.2, 0), material="Neon", color="#00FF00")])
        img = scene.render(e, 128)
        a = img[..., 3]
        self.assertTrue(((a > 0.3) & (a < 0.6)).any(), "ghost box should be half transparent")
        self.assertTrue((img[..., 1] > 0.9).any())

    def test_tinted_phase(self):
        pieces = [piece(color="#000000"), piece(material="Neon", color="#FF0000")]
        out = scene.tinted(pieces, {"tint": "#FFFFFF", "amount": 0.5, "glow": "#00FF00"})
        self.assertEqual(out[0]["c"], "#808080")
        self.assertEqual(out[1]["c"], "#00FF00")
        self.assertEqual(pieces[0]["c"], "#000000")


if __name__ == "__main__":
    unittest.main()
