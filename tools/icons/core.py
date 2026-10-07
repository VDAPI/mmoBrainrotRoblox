# Core of the Vaelthorn item icon generator.
# An icon is a list of elements (layer, svg). Layers stack bottom -> top in LAYER_ORDER:
#   m = material layer, greyscale, tinted in game with the item tier colour (ImageColor3)
#   b = base layer, fixed colours
#   a = accent layer, greyscale, tinted with an accent colour (element, potion, ore, ...)
# Each layer is rendered as its own 128x128 image. Elements of a higher layer are masked by any later
# element of a lower layer, so the stacked images reproduce the drawing order exactly.
import re

LAYER_ORDER = {"m": 0, "b": 1, "a": 2}
OUT = "#16110c"
S = f'stroke="{OUT}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"'
S2 = f'stroke="{OUT}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"'
S4 = f'stroke="{OUT}" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"'


def lin(id, stops, x2=1, y2=1):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<linearGradient id="{id}" x1="0" y1="0" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def rad(id, stops, cx=0.35, cy=0.3, r=0.8):
    s = "".join(
        f'<stop offset="{o}" stop-color="{c}"' + (f' stop-opacity="{a}"' if a is not None else "") + "/>"
        for o, c, a in stops
    )
    return f'<radialGradient id="{id}" cx="{cx}" cy="{cy}" r="{r}">{s}</radialGradient>'


def tri(l, m, d):
    return [(0, l), (0.55, m), (1, d)]


DEFS = "".join([
    lin("met", tri("#ffffff", "#c6c6c6", "#5c5c5c")),
    lin("metV", tri("#ffffff", "#c6c6c6", "#5c5c5c"), 0, 1),
    lin("metH", tri("#ffffff", "#c6c6c6", "#5c5c5c"), 1, 0),
    lin("acc", tri("#ffffff", "#c8c8c8", "#606060")),
    lin("accV", tri("#ffffff", "#c8c8c8", "#606060"), 0, 1),
    rad("accR", [(0, "#ffffff", None), (0.3, "#dcdcdc", None), (1, "#5a5a5a", None)]),
    rad("glowA", [(0, "#ffffff", 0.95), (0.45, "#ffffff", 0.5), (1, "#ffffff", 0)], 0.5, 0.5, 0.5),
    lin("wood", tri("#b07a43", "#7a4f27", "#3e2612")),
    lin("woodL", tri("#c99a62", "#9a6a3a", "#55361a")),
    lin("lea", tri("#a57048", "#6e4528", "#352012")),
    lin("leaD", tri("#7a5236", "#4a2f1c", "#24150b")),
    lin("clo", tri("#6a8ac0", "#3c5a8c", "#1f3050")),
    lin("cloP", tri("#8a6cc4", "#55408f", "#2a1f50")),
    lin("cloR", tri("#d0604a", "#8c2f22", "#4a160f")),
    lin("cloG", tri("#76a05e", "#46703a", "#22401c")),
    lin("cloW", tri("#f4efe2", "#d8cfb8", "#8f8670")),
    lin("gld", tri("#fff0b0", "#e0b64a", "#7a5a16")),
    lin("bone", tri("#fbf5e6", "#ddd0b0", "#8f7f5c")),
    lin("stone", tri("#aaa49c", "#706a63", "#3a3530")),
    lin("dark", tri("#4a4440", "#2a2522", "#141110")),
    lin("glassV", [(0, "#eaf6fb"), (1, "#a9c4d0")], 0, 1),
    rad("gem", [(0, "#ffffff", None), (0.25, "#ff6b6b", None), (1, "#7a0f1a", None)]),
    rad("gemB", [(0, "#ffffff", None), (0.25, "#7fd4ff", None), (1, "#16407a", None)]),
    rad("gemG", [(0, "#ffffff", None), (0.25, "#7ee08a", None), (1, "#15602a", None)]),
    rad("gemP", [(0, "#ffffff", None), (0.25, "#c48aff", None), (1, "#3c1470", None)]),
    rad("gemY", [(0, "#ffffff", None), (0.25, "#ffe27a", None), (1, "#8a5a00", None)]),
    rad("gemO", [(0, "#ffffff", None), (0.25, "#ffb066", None), (1, "#8a3200", None)]),
    rad("gemI", [(0, "#ffffff", None), (0.3, "#c8f0ff", None), (1, "#2a6a9a", None)]),
    rad("glowW", [(0, "#fff8e0", 0.95), (0.5, "#ffe9a0", 0.45), (1, "#ffe9a0", 0)], 0.5, 0.5, 0.5),
    rad("glowB", [(0, "#dff6ff", 0.95), (0.5, "#7fd4ff", 0.45), (1, "#7fd4ff", 0)], 0.5, 0.5, 0.5),
    rad("glowG", [(0, "#e8ffe0", 0.95), (0.5, "#7ee08a", 0.45), (1, "#7ee08a", 0)], 0.5, 0.5, 0.5),
    rad("glowP", [(0, "#f2e6ff", 0.95), (0.5, "#b47aff", 0.45), (1, "#b47aff", 0)], 0.5, 0.5, 0.5),
    rad("glowR", [(0, "#fff0d8", 0.95), (0.5, "#ff6a2a", 0.5), (1, "#ff3a1a", 0)], 0.5, 0.5, 0.5),
    rad("glowI", [(0, "#ffffff", 0.95), (0.5, "#bfeaff", 0.5), (1, "#bfeaff", 0)], 0.5, 0.5, 0.5),
    '<filter id="blk" x="-50%" y="-50%" width="200%" height="200%"><feColorMatrix type="matrix" '
    'values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0"/></filter>',
])

ID_RE = re.compile(r'(id="|url\(#)([A-Za-z]+)')


def uniq(svg: str, u: str) -> str:
    return ID_RE.sub(lambda m: f"{m.group(1)}{m.group(2)}_{u}", svg)


class Icon:
    def __init__(self, key, elements, transform="", accent=None, note=""):
        self.key = key
        self.elements = elements  # list of (layer, svg)
        self.transform = transform
        self.accent = accent  # preview accent colour
        self.note = note

    def layers(self):
        present = sorted({l for l, _ in self.elements}, key=lambda l: LAYER_ORDER[l])
        return present

    def layer_svg(self, layer: str, u: str) -> str:
        """SVG for one layer: its elements, each masked by later elements of lower layers."""
        parts = []
        masks = []
        order = LAYER_ORDER[layer]
        for i, (l, svg) in enumerate(self.elements):
            if l != layer:
                continue
            covers = [s for (lj, s) in self.elements[i + 1:] if LAYER_ORDER[lj] < order]
            if covers:
                mid = f"mk{i}"
                masks.append(
                    f'<mask id="{mid}" maskUnits="userSpaceOnUse" x="-64" y="-64" width="256" height="256">'
                    f'<rect x="-64" y="-64" width="256" height="256" fill="#fff"/>'
                    f'<g filter="url(#blk)">{"".join(covers)}</g></mask>'
                )
                parts.append(f'<g mask="url(#{mid})">{svg}</g>')
            else:
                parts.append(svg)
        body = "".join(parts)
        inner = f'<defs>{DEFS}{"".join(masks)}</defs>'
        g = f'<g transform="{self.transform}">{body}</g>' if self.transform else body
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'
               f'{inner}{g}</svg>')
        return uniq(svg, u)

    def full_svg(self, u: str, tint=None, accent=None) -> str:
        """Single SVG of the whole icon (no masks), for quick previews only (untinted)."""
        body = "".join(s for _, s in self.elements)
        g = f'<g transform="{self.transform}">{body}</g>' if self.transform else body
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'
               f'<defs>{DEFS}</defs>{g}</svg>')
        return uniq(svg, u)
