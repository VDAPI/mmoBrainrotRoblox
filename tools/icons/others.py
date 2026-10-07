# Named mythic boss items, materials, consumables, tools, backpacks and UI currency icons.
import math
import core
from core import Icon, S, S2, S4, OUT, lin, rad, tri
from equip import thick, wraps, HL, HLs, SH

core.DEFS += "".join([
    lin("gob", tri("#b9bea0", "#6f755c", "#2c3022")),
    lin("rust", tri("#c47a4a", "#8a4a26", "#4a2210")),
    lin("obs", tri("#7a7090", "#3a3348", "#120f18")),
    lin("ice", tri("#ffffff", "#a8def5", "#3a7aa6")),
    lin("iceV", tri("#ffffff", "#a8def5", "#3a7aa6"), 0, 1),
    lin("lava", tri("#fff0a0", "#ff7a1a", "#8a1a00")),
    lin("violet", tri("#cfa8ff", "#7a48d0", "#2a1050")),
    lin("boneD", tri("#e8dcc0", "#a8977a", "#4f4430")),
    lin("silver", tri("#ffffff", "#cfd6de", "#6a7480")),
    lin("fur", tri("#c8c8c8", "#8e8e8e", "#4a4a4a")),
    lin("furW", tri("#ffffff", "#e6eef4", "#9aa8b4")),
    lin("green", tri("#c8f080", "#6aa83a", "#2a5014")),
    lin("ivory", tri("#fffaf0", "#e8dcc8", "#9a8a6a")),
    lin("paper", tri("#fbf1d6", "#e6d3a4", "#a8915c")),
    lin("coin", tri("#fff6c0", "#f0c040", "#8a6200")),
    rad("lavaR", [(0, "#ffffff", None), (0.25, "#ffd060", None), (0.6, "#ff5a1a", None), (1, "#6a0a00", None)]),
    rad("iceR", [(0, "#ffffff", None), (0.35, "#c8f0ff", None), (1, "#2a6a9a", None)]),
    rad("vioR", [(0, "#ffffff", None), (0.3, "#d8b8ff", None), (1, "#3c1470", None)]),
    rad("goo", [(0, "#f0fff8", None), (0.35, "#9fe0c9", None), (1, "#2a7a5a", None)]),
    rad("orangeR", [(0, "#ffffff", None), (0.3, "#ffc060", None), (1, "#a83a00", None)]),
])


def star(cx, cy, r1, r2, n=4, rot=0):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n - 90)
        pts.append(f"{cx + r * math.cos(a):.1f} {cy + r * math.sin(a):.1f}")
    return "M" + " L".join(pts) + " Z"


def sparkle(cx, cy, r, color="#ffffff", layer="b"):
    return (layer, f'<path d="{star(cx, cy, r, r * 0.28)}" fill="{color}"/>')


# ================================================================ named mythic boss items (fixed colours)
def grimrok_cleaver():
    return Icon("uniq/unique_grimrok_cleaver", [
        ("b", f'<rect x="59" y="20" width="10" height="100" rx="3" fill="url(#boneD)" {S}/>'),
        ("b", '<path d="M59 30 L69 34 M59 46 L69 50 M59 62 L69 66" stroke="#4f4430" stroke-width="2"/>'),
        ("b", f'<rect x="58" y="90" width="12" height="26" rx="2" fill="url(#rust)" {S}/>'),
        wraps(58, 70, 94, 114),
        ("b", f'<path d="M68 14 L112 8 L118 22 L112 30 L118 40 L110 50 L116 62 L104 70 L68 64 Z" fill="url(#gob)" {S}/>'),
        ("b", '<path d="M110 14 L114 22 L108 30 L114 40 L106 50 L112 60" stroke="#fff" stroke-opacity=".55" stroke-width="2.5" fill="none"/>'),
        ("b", '<circle cx="84" cy="30" r="5" fill="#8a4a26" opacity=".7"/><circle cx="96" cy="48" r="4" fill="#8a4a26" opacity=".6"/>'),
        ("b", f'<circle cx="78" cy="22" r="3" fill="#2a2a2a" {S2}/><circle cx="78" cy="56" r="3" fill="#2a2a2a" {S2}/>'),
        ("b", f'<path d="M56 64 C44 66 40 76 44 86 C48 78 52 74 58 72 Z" fill="url(#cloR)" {S2}/>'),
        ("b", f'<path d="M57 16 L71 16 L71 68 L57 68 Z" fill="url(#gob)" {S}/>'),
        ("b", f'<path d="M58 118 L70 118 L64 128 Z" fill="url(#boneD)" {S2}/>'),
    ], "translate(64 64) scale(0.86) translate(-64 -64) rotate(-28 64 64) translate(-6 2)")


def grimrok_fang():
    return Icon("uniq/unique_grimrok_fang", [
        ("b", f'<ellipse cx="64" cy="82" rx="34" ry="28" fill="none" stroke="{OUT}" stroke-width="16"/>'),
        ("b", '<ellipse cx="64" cy="82" rx="34" ry="28" fill="none" stroke="url(#gob)" stroke-width="10"/>'),
        ("b", '<path d="M36 72 C40 60 50 54 60 54" stroke="#fff" stroke-opacity=".4" stroke-width="3" fill="none"/>'),
        ("b", f'<path d="M44 58 L84 58 L78 46 L50 46 Z" fill="url(#rust)" {S}/>'),
        ("b", f'<path d="M50 48 C46 30 56 12 80 6 C70 18 66 32 72 48 Z" fill="url(#ivory)" {S}/>'),
        ("b", '<path d="M56 40 C54 28 60 18 72 12" stroke="#fff" stroke-opacity=".7" stroke-width="2" fill="none"/>'),
        ("b", f'<circle cx="64" cy="52" r="5" fill="url(#gemG)" {S2}/>'),
    ])


def grimrok_totem():
    return Icon("uniq/unique_grimrok_totem", [
        ("b", '<path d="M40 6 C40 24 50 30 58 32 M88 6 C88 24 78 30 70 32" fill="none" stroke="#7a4f27" stroke-width="3"/>'),
        ("b", '<circle cx="64" cy="72" r="44" fill="url(#glowG)" opacity=".7"/>'),
        ("b", f'<path d="M30 46 C22 54 20 70 26 80 L34 66 Z" fill="url(#cloR)" {S2}/>'),
        ("b", f'<path d="M98 46 C106 54 108 70 102 80 L94 66 Z" fill="#e8c56a" {S2}/>'),
        ("b", f'<path d="M44 32 L84 32 L90 50 L86 100 L76 116 L52 116 L42 100 L38 50 Z" fill="url(#wood)" {S}/>'),
        ("b", f'<path d="M44 32 L84 32 L80 22 L48 22 Z" fill="url(#boneD)" {S}/>'),
        ("b", f'<path d="M48 54 L58 50 L60 60 L50 62 Z M80 54 L70 50 L68 60 L78 62 Z" fill="#1a1a10" {S2}/>'),
        ("b", '<circle cx="54" cy="56" r="3" fill="#9fff7a"/><circle cx="74" cy="56" r="3" fill="#9fff7a"/>'),
        ("b", f'<path d="M54 80 L74 80 L70 96 L58 96 Z" fill="#1a1a10" {S2}/>'),
        ("b", '<path d="M58 80 L60 86 L62 80 M66 80 L68 86 L70 80" fill="#f4ecd8"/>'),
        ("b", '<path d="M48 40 L52 100" stroke="#fff" stroke-opacity=".3" stroke-width="3" fill="none"/>'),
    ])


def morvane_shroud():
    return Icon("uniq/unique_morvane_shroud", [
        ("b", '<path d="M64 6 C100 20 110 70 112 124 L16 124 C18 70 28 20 64 6 Z" fill="url(#glowP)" opacity=".8"/>'),
        ("b", f'<path d="M64 8 C84 10 94 26 94 44 L112 70 L100 76 L98 122 L30 122 L28 76 L16 70 L34 44 C34 26 44 10 64 8 Z" fill="url(#obs)" {S}/>'),
        ("b", f'<path d="M64 18 C76 18 84 28 84 42 C84 54 76 62 64 62 C52 62 44 54 44 42 C44 28 52 18 64 18 Z" fill="#0a0812" {S2}/>'),
        ("b", '<circle cx="57" cy="42" r="3" fill="#d8b8ff"/><circle cx="71" cy="42" r="3" fill="#d8b8ff"/>'),
        ("b", '<path d="M64 64 L64 122" stroke="#b47aff" stroke-width="2.5"/>'),
        ("b", '<path d="M32 120 L40 108 L48 120 L56 108 L64 120 L72 108 L80 120 L88 108 L96 120" stroke="#b47aff" stroke-width="2" fill="none"/>'),
        ("b", f'<path d="M56 64 L72 64 L68 74 L60 74 Z" fill="url(#silver)" {S2}/>'),
        ("b", f'<circle cx="64" cy="69" r="3" fill="url(#gemP)" {S2}/>'),
        ("b", '<path d="M38 50 C34 70 34 96 36 116" stroke="#fff" stroke-opacity=".25" stroke-width="3" fill="none"/>'),
    ])


def morvane_scepter():
    return Icon("uniq/unique_morvane_scepter", [
        ("b", '<circle cx="64" cy="24" r="28" fill="url(#glowP)"/>'),
        ("b", f'<rect x="60" y="48" width="8" height="70" rx="3" fill="url(#obs)" {S}/>'),
        ("b", f'<path d="M50 44 C46 30 52 20 64 20 C76 20 82 30 78 44 L72 52 L56 52 Z" fill="url(#bone)" {S}/>'),
        ("b", f'<path d="M54 34 L60 32 L60 40 L54 40 Z M74 34 L68 32 L68 40 L74 40 Z" fill="#1a0f28" {S2}/>'),
        ("b", '<circle cx="57" cy="37" r="2" fill="#d8b8ff"/><circle cx="71" cy="37" r="2" fill="#d8b8ff"/>'),
        ("b", '<path d="M58 46 L60 50 L62 46 L64 50 L66 46 L68 50 L70 46" stroke="#16110c" stroke-width="1.5" fill="none"/>'),
        ("b", f'<path d="M64 -2 L72 12 L64 22 L56 12 Z" fill="url(#vioR)" {S}/>'),
        ("b", f'<rect x="56" y="70" width="16" height="6" rx="2" fill="url(#silver)" {S2}/>'),
        ("b", f'<rect x="56" y="98" width="16" height="6" rx="2" fill="url(#silver)" {S2}/>'),
        ("b", f'<path d="M64 116 L70 124 L64 130 L58 124 Z" fill="url(#vioR)" {S2}/>'),
    ], "rotate(38 64 64) translate(0 2)")


def morvane_bow():
    d = "M80 6 C36 30 36 98 80 122"
    return Icon("uniq/unique_morvane_bow", [
        ("b", '<path d="M80 7 L80 121" stroke="#c48aff" stroke-width="5" stroke-opacity=".35"/>'),
        ("b", '<path d="M80 7 L80 121" stroke="#e8d8ff" stroke-width="2"/>'),
        *thick("b", d, "url(#boneD)", 13, 8),
        ("b", f'<path d="{d}" fill="none" stroke="#fff" stroke-opacity=".35" stroke-width="2" transform="translate(-3 0)"/>'),
        ("b", f'<path d="M52 30 L42 24 L50 36 Z M44 50 L32 48 L42 56 Z M44 78 L32 80 L42 72 Z M52 98 L42 104 L50 92 Z" fill="url(#obs)" {S2}/>'),
        ("b", f'<rect x="41" y="54" width="11" height="20" rx="3" fill="url(#obs)" {S}/>'),
        ("b", f'<circle cx="46.5" cy="64" r="4" fill="url(#vioR)" {S2}/>'),
        ("b", f'<path d="M80 6 L86 -2 L76 2 Z M80 122 L86 130 L76 126 Z" fill="url(#vioR)" {S2}/>'),
    ], "translate(64 64) scale(0.9) translate(-64 -64) rotate(-35 64 64)")


def azgor_heart():
    return Icon("uniq/unique_azgor_heart", [
        *thick("b", "M26 12 C26 52 46 70 64 74 C82 70 102 52 102 12", "url(#obs)", 8, 4),
        ("b", '<circle cx="64" cy="94" r="34" fill="url(#glowR)"/>'),
        ("b", f'<path d="M64 76 L76 72 L84 82 L80 96 L64 120 L48 96 L44 82 L52 72 Z" fill="url(#obs)" {S}/>'),
        ("b", f'<path d="M64 112 C52 102 46 94 46 88 C46 82 50 78 55 78 C59 78 62 80 64 84 C66 80 69 78 73 78 C78 78 82 82 82 88 C82 94 76 102 64 112 Z" fill="url(#lavaR)" {S2}/>'),
        ("b", '<path d="M54 84 C55 82 57 81 59 81" stroke="#fff" stroke-width="2" fill="none"/>'),
        ("b", '<path d="M64 84 L62 94 L66 100" stroke="#fff0a0" stroke-width="1.5" fill="none"/>'),
    ])


def azgor_staff():
    return Icon("uniq/unique_azgor_staff", [
        ("b", '<circle cx="64" cy="24" r="30" fill="url(#glowR)"/>'),
        ("b", f'<rect x="60" y="36" width="8" height="96" rx="3" fill="url(#obs)" {S}/>'),
        ("b", '<path d="M62 50 L66 56 L62 62 M66 76 L62 82 L66 88 M62 100 L66 106" stroke="#ff7a1a" stroke-width="2" fill="none"/>'),
        ("b", f'<path d="M54 40 C40 36 34 24 38 8 C42 20 48 26 58 30 Z" fill="url(#obs)" {S}/>'),
        ("b", f'<path d="M74 40 C88 36 94 24 90 8 C86 20 80 26 70 30 Z" fill="url(#obs)" {S}/>'),
        ("b", f'<path d="M64 0 L76 16 L72 34 L64 40 L56 34 L52 16 Z" fill="url(#lavaR)" {S}/>'),
        ("b", '<path d="M60 10 L64 5 L68 10" stroke="#fff" stroke-width="2" fill="none"/>'),
        ("b", f'<rect x="56" y="36" width="16" height="8" rx="2" fill="url(#obs)" {S2}/>'),
    ], "rotate(32 64 64) translate(0 2)")


def azgor_helm():
    return Icon("uniq/unique_azgor_helm", [
        ("b", f'<path d="M30 52 C18 46 10 32 12 10 C20 26 28 32 40 36 Z" fill="url(#boneD)" {S}/>'),
        ("b", f'<path d="M98 52 C110 46 118 32 116 10 C108 26 100 32 88 36 Z" fill="url(#boneD)" {S}/>'),
        ("b", f'<path d="M30 62 C30 32 46 18 64 18 C82 18 98 32 98 62 L98 104 C88 112 76 116 64 116 C52 116 40 112 30 104 Z" fill="url(#obs)" {S}/>'),
        ("b", '<path d="M44 34 L50 46 L46 56 M84 30 L78 44 L84 52 M40 88 L48 96 M88 86 L80 98" stroke="#ff7a1a" stroke-width="2" fill="none"/>'),
        ("b", f'<path d="M38 62 L58 60 L64 66 L70 60 L90 62 L88 70 L70 70 L64 74 L58 70 L40 70 Z" fill="#1a0800" {S2}/>'),
        ("b", '<path d="M42 65 L58 64 M70 64 L86 65" stroke="#ffb040" stroke-width="2.5"/>'),
        ("b", f'<path d="M64 74 L64 112" stroke="{OUT}" stroke-width="2"/>'),
        ("b", '<path d="M38 52 C40 36 50 26 60 24" stroke="#fff" stroke-opacity=".35" stroke-width="3" fill="none"/>'),
    ])


def vaelgrath_fang():
    return Icon("uniq/unique_vaelgrath_fang", [
        ("b", '<path d="M64 -6 L76 10 L75 76 L53 76 L52 10 Z" fill="url(#glowI)" transform="translate(64 34) scale(1.25) translate(-64 -34)"/>'),
        ("b", f'<path d="M64 -10 L76 6 L74 76 L54 76 L52 6 Z" fill="url(#ice)" {S}/>'),
        ("b", '<path d="M64 0 L64 72" stroke="#fff" stroke-width="3"/>'),
        ("b", '<path d="M58 20 L62 26 M68 34 L64 40 M58 50 L62 56" stroke="#3a7aa6" stroke-width="1.6"/>'),
        ("b", f'<path d="M28 70 C34 80 44 78 50 74 L78 74 C84 78 94 80 100 70 C94 72 88 70 84 66 L44 66 C40 70 34 72 28 70 Z" fill="url(#silver)" {S}/>'),
        ("b", f'<circle cx="64" cy="72" r="5" fill="url(#gemI)" {S2}/>'),
        ("b", f'<rect x="58" y="78" width="12" height="40" rx="2" fill="url(#obs)" {S}/>'),
        wraps(58, 70, 82, 116),
        ("b", f'<path d="M64 116 L74 126 L64 138 L54 126 Z" fill="url(#iceR)" {S}/>'),
    ], "rotate(45 64 64)")


def vaelgrath_scale():
    scales = ""
    for row, y in enumerate([30, 48, 66, 84]):
        n = 4 if row < 3 else 3
        for i in range(n):
            x = 64 + (i - (n - 1) / 2) * 18
            scales += f'<path d="M{x - 9} {y} C{x - 9} {y + 12} {x + 9} {y + 12} {x + 9} {y} Z" fill="url(#ice)" stroke="#2a5a80" stroke-width="1.6"/>'
    return Icon("uniq/unique_vaelgrath_scale", [
        ("b", '<circle cx="64" cy="64" r="58" fill="url(#glowI)" opacity=".7"/>'),
        ("b", f'<path d="M64 6 L112 18 C112 70 94 104 64 124 C34 104 16 70 16 18 Z" fill="url(#silver)" {S}/>'),
        ("b", f'<path d="M64 16 L102 26 C101 68 86 96 64 112 C42 96 27 68 26 26 Z" fill="#1d3a5a" stroke="{OUT}" stroke-width="2"/>'),
        ("b", scales),
        ("b", f'<path d="M64 16 L102 26 C101 68 86 96 64 112 C42 96 27 68 26 26 Z" fill="none" stroke="{OUT}" stroke-width="2"/>'),
        ("b", f'<path d="M52 6 L58 -2 L60 8 Z M76 6 L70 -2 L68 8 Z" fill="url(#silver)" {S2}/>'),
        ("b", '<path d="M24 22 C26 58 38 86 56 102" stroke="#fff" stroke-opacity=".5" stroke-width="3" fill="none"/>'),
    ], "translate(64 64) scale(0.92) translate(-64 -62)")


def vaelgrath_eye():
    return Icon("uniq/unique_vaelgrath_eye", [
        ("b", '<circle cx="64" cy="52" r="44" fill="url(#glowI)"/>'),
        ("b", f'<path d="M40 112 L88 112 C92 112 94 118 88 120 L40 120 C34 118 36 112 40 112 Z" fill="url(#silver)" {S}/>'),
        ("b", f'<path d="M56 112 L58 90 L70 90 L72 112 Z" fill="url(#silver)" {S}/>'),
        ("b", f'<circle cx="64" cy="52" r="32" fill="url(#iceR)" {S}/>'),
        ("b", f'<path d="M36 52 C46 38 82 38 92 52 C82 66 46 66 36 52 Z" fill="#dff6ff" stroke="#2a5a80" stroke-width="2"/>'),
        ("b", '<circle cx="64" cy="52" r="11" fill="#5ac8ff" stroke="#16405a" stroke-width="2"/>'),
        ("b", '<path d="M64 42 C61 47 61 57 64 62 C67 57 67 47 64 42 Z" fill="#0a1a28"/>'),
        ("b", '<circle cx="50" cy="36" r="5" fill="#fff" fill-opacity=".7"/>'),
        ("b", f'<path d="M42 96 C30 84 28 68 32 60 L40 62 C38 72 42 82 54 88 Z" fill="url(#silver)" {S}/>'),
        ("b", f'<path d="M86 96 C98 84 100 68 96 60 L88 62 C90 72 86 82 74 88 Z" fill="url(#silver)" {S}/>'),
        ("b", f'<path d="M52 94 L76 94 L72 84 L56 84 Z" fill="url(#silver)" {S}/>'),
    ])


# ================================================================ materials
def essence_dust():
    return Icon("mat/essence_dust", [
        ("b", '<ellipse cx="64" cy="86" rx="46" ry="30" fill="url(#glowB)" opacity=".6"/>'),
        ("b", f'<path d="M22 100 C26 78 44 62 64 60 C84 62 102 78 106 100 C92 108 36 108 22 100 Z" fill="#9fb6c9" {S}/>'),
        ("b", '<path d="M34 92 C40 80 52 72 64 70" stroke="#fff" stroke-opacity=".6" stroke-width="3" fill="none"/>'),
        ("b", "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#e8f4ff"/>' for x, y, r in
                      [(46, 88, 2), (58, 80, 1.6), (74, 84, 2.2), (86, 94, 1.6), (64, 96, 1.8), (52, 98, 1.4), (80, 76, 1.4)])),
        sparkle(40, 50, 10, "#dff6ff"), sparkle(84, 40, 13, "#ffffff"), sparkle(64, 26, 7, "#dff6ff"),
    ])


def essence_shard():
    return Icon("mat/essence_shard", [
        ("b", '<circle cx="64" cy="70" r="50" fill="url(#glowB)" opacity=".8"/>'),
        ("b", f'<path d="M40 110 L30 70 L44 48 L54 80 Z" fill="url(#gemB)" {S}/>'),
        ("b", f'<path d="M88 112 L100 64 L88 52 L76 86 Z" fill="url(#gemB)" {S}/>'),
        ("b", f'<path d="M50 114 L54 50 L66 12 L80 52 L78 114 Z" fill="url(#gemB)" {S}/>'),
        ("b", '<path d="M66 12 L64 114 M54 50 L66 60 L80 52" stroke="#16405a" stroke-width="1.6" fill="none"/>'),
        ("b", '<path d="M58 54 L64 24" stroke="#fff" stroke-width="3" stroke-opacity=".8"/>'),
        sparkle(98, 30, 9),
    ])


def essence_crystal():
    return Icon("mat/essence_crystal", [
        ("b", '<circle cx="64" cy="66" r="56" fill="url(#glowP)" opacity=".8"/>'),
        ("b", f'<path d="M22 112 L18 72 L32 56 L42 92 Z" fill="url(#gemP)" {S}/>'),
        ("b", f'<path d="M104 112 L112 66 L98 52 L88 92 Z" fill="url(#gemP)" {S}/>'),
        ("b", f'<path d="M38 116 L42 46 L64 6 L86 46 L90 116 Z" fill="url(#gemP)" {S}/>'),
        ("b", '<path d="M64 6 L64 116 M42 46 L64 58 L86 46" stroke="#2a1050" stroke-width="2" fill="none"/>'),
        ("b", '<path d="M48 50 L60 18" stroke="#fff" stroke-width="3.5" stroke-opacity=".8"/>'),
        ("b", f'<path d="M14 116 L114 116" {S}/>'),
        sparkle(100, 26, 10),
    ])


def legend_core():
    return Icon("mat/legend_core", [
        ("b", '<circle cx="64" cy="64" r="60" fill="url(#glowR)"/>'),
        ("b", f'<circle cx="64" cy="64" r="30" fill="url(#orangeR)" {S}/>'),
        ("b", '<path d="M50 58 L58 52 L64 60 L72 50 L80 58 M48 72 L56 78 L64 70 L72 80 L80 72" stroke="#fff0b0" stroke-width="2" fill="none"/>'),
        ("b", f'<path d="M64 26 C86 26 102 42 102 64 C102 86 86 102 64 102 C42 102 26 86 26 64 C26 42 42 26 64 26" fill="none" stroke="{OUT}" stroke-width="10"/>'),
        ("b", '<path d="M64 26 C86 26 102 42 102 64 C102 86 86 102 64 102 C42 102 26 86 26 64 C26 42 42 26 64 26" fill="none" stroke="url(#gld)" stroke-width="5" stroke-dasharray="14 8"/>'),
        ("b", f'<path d="{star(64, 64, 52, 40, 8, 22.5)}" fill="none" stroke="#ffd060" stroke-opacity=".7" stroke-width="2"/>'),
        ("b", '<circle cx="54" cy="52" r="6" fill="#fff" fill-opacity=".75"/>'),
    ])


def ore():
    return Icon("mat/ore", [
        ("b", f'<path d="M16 88 L28 46 L58 26 L94 32 L114 62 L108 100 L74 116 L34 112 Z" fill="url(#stone)" {S}/>'),
        ("b", '<path d="M28 46 L58 26 L94 32 L70 50 L44 56 Z" fill="#ffffff" fill-opacity=".18"/>'),
        ("b", '<path d="M70 50 L94 32 L114 62 L88 70 Z" fill="#000" fill-opacity=".18"/>'),
        ("a", f'<path d="M42 66 L58 58 L68 70 L54 80 Z" fill="url(#acc)" stroke="{OUT}" stroke-width="2.4"/>'),
        ("a", f'<path d="M76 78 L94 72 L98 88 L82 94 Z" fill="url(#acc)" stroke="{OUT}" stroke-width="2.4"/>'),
        ("a", f'<path d="M50 92 L64 88 L68 100 L54 104 Z" fill="url(#acc)" stroke="{OUT}" stroke-width="2.4"/>'),
        ("a", f'<path d="M72 44 L82 42 L84 52 L74 54 Z" fill="url(#acc)" stroke="{OUT}" stroke-width="2"/>'),
        ("a", '<path d="M46 64 L56 60 M80 76 L90 74 M54 90 L62 88" stroke="#fff" stroke-width="2"/>'),
    ], accent="#B87333")


def herb():
    petals = ""
    for cx, cy, r in [(46, 40, 12), (82, 30, 13), (70, 60, 10)]:
        for k in range(5):
            a = math.radians(k * 72 - 90)
            petals += f'<ellipse cx="{cx + r * 0.75 * math.cos(a):.1f}" cy="{cy + r * 0.75 * math.sin(a):.1f}" rx="{r * 0.55:.1f}" ry="{r * 0.38:.1f}" transform="rotate({k * 72} {cx + r * 0.75 * math.cos(a):.1f} {cy + r * 0.75 * math.sin(a):.1f})" fill="url(#acc)" stroke="{OUT}" stroke-width="1.8"/>'
    return Icon("mat/herb", [
        ("b", f'<path d="M64 120 C62 96 52 70 46 42 M64 120 C68 90 76 60 82 30 M64 120 C66 100 68 80 70 60" stroke="{OUT}" stroke-width="6" fill="none" stroke-linecap="round"/>'),
        ("b", '<path d="M64 120 C62 96 52 70 46 42 M64 120 C68 90 76 60 82 30 M64 120 C66 100 68 80 70 60" stroke="#4f8a3a" stroke-width="3" fill="none" stroke-linecap="round"/>'),
        ("b", f'<path d="M58 96 C42 94 30 84 26 72 C40 72 52 80 58 96 Z" fill="url(#green)" {S2}/>'),
        ("b", f'<path d="M68 92 C82 88 94 76 98 64 C84 64 72 74 68 92 Z" fill="url(#green)" {S2}/>'),
        ("b", f'<path d="M62 112 C50 112 40 106 36 98 C48 96 58 102 62 112 Z" fill="url(#green)" {S2}/>'),
        ("a", petals),
        ("b", "".join(f'<circle cx="{x}" cy="{y}" r="4" fill="#ffd060" stroke="{OUT}" stroke-width="1.4"/>' for x, y in [(46, 40), (82, 30), (70, 60)])),
    ], accent="#E8E4B0")


def fish():
    return Icon("mat/fish", [
        ("b", f'<path d="M92 64 L118 40 C116 56 116 72 118 88 Z" fill="url(#fur)" {S}/>'),
        ("b", f'<path d="M46 40 C56 26 72 24 80 36 L60 46 Z M48 88 C56 100 68 102 74 94 L60 82 Z" fill="url(#fur)" {S2}/>'),
        ("a", f'<path d="M10 64 C22 38 54 30 78 38 C88 42 96 54 98 64 C96 74 88 86 78 90 C54 98 22 90 10 64 Z" fill="url(#accV)" {S}/>'),
        ("a", '<path d="M44 46 C48 56 48 72 44 82" stroke="#16110c" stroke-width="2" fill="none" stroke-opacity=".6"/>'),
        ("a", "".join(f'<path d="M{x} {y} C{x + 4} {y + 4} {x + 4} {y + 8} {x} {y + 12}" stroke="#16110c" stroke-opacity=".35" stroke-width="1.5" fill="none"/>'
                      for x, y in [(56, 48), (66, 50), (76, 52), (56, 66), (66, 66), (76, 64)])),
        ("a", '<path d="M20 58 C30 44 50 40 64 42" stroke="#fff" stroke-width="3" stroke-opacity=".7" fill="none"/>'),
        ("b", f'<circle cx="26" cy="58" r="5" fill="#fff" {S2}/>'),
        ("b", '<circle cx="27" cy="58" r="2.4" fill="#16110c"/>'),
    ], accent="#B89B5A")


def wolf_pelt():
    return Icon("mat/wolf_pelt", [
        ("b", f'<path d="M64 10 C78 10 82 20 80 30 L100 24 L94 44 L114 52 L98 64 L110 84 L90 84 L92 106 L76 98 L64 120 L52 98 L36 106 L38 84 L18 84 L30 64 L14 52 L34 44 L28 24 L48 30 C46 20 50 10 64 10 Z" fill="url(#fur)" {S}/>'),
        ("b", '<path d="M64 30 C74 40 76 70 64 100 C52 70 54 40 64 30 Z" fill="#6a6a6a" opacity=".55"/>'),
        ("b", '<path d="M44 50 L50 56 M84 50 L78 56 M40 72 L48 74 M88 72 L80 74 M52 88 L56 82 M76 88 L72 82" stroke="#3a3a3a" stroke-width="2"/>'),
        ("b", '<path d="M58 20 L62 26 M70 20 L66 26" stroke="#2a2a2a" stroke-width="2.4"/>'),
    ])


def boar_tusk():
    return Icon("mat/boar_tusk", [
        ("b", f'<path d="M24 112 C20 74 44 36 92 14 C98 12 104 16 100 22 C66 44 50 76 50 112 Z" fill="url(#ivory)" {S}/>'),
        ("b", '<path d="M34 100 C34 72 52 46 86 24" stroke="#fff" stroke-width="3" stroke-opacity=".75" fill="none"/>'),
        ("b", '<path d="M30 92 L46 94 M34 76 L50 80 M42 62 L56 68" stroke="#9a8a6a" stroke-width="1.6"/>'),
        ("b", f'<path d="M20 108 L54 108 L52 120 L22 120 Z" fill="url(#lea)" {S}/>'),
    ])


def spider_silk():
    return Icon("mat/spider_silk", [
        ("b", '<path d="M10 20 L118 108 M118 20 L10 108 M64 6 L64 122 M6 64 L122 64" stroke="#d8d2e8" stroke-opacity=".35" stroke-width="1.2"/>'),
        ("b", f'<ellipse cx="64" cy="64" rx="30" ry="40" fill="url(#cloW)" {S}/>'),
        ("b", "".join(f'<path d="M{34 + i * 2} {44 + i * 9} C50 {38 + i * 9} 78 {50 + i * 9} {94 - i * 2} {44 + i * 9}" stroke="#a89fc0" stroke-width="1.6" fill="none"/>' for i in range(5))),
        ("b", '<path d="M44 40 C50 30 58 26 66 26" stroke="#fff" stroke-width="3" fill="none"/>'),
        ("b", '<path d="M64 104 C66 112 70 116 76 120" stroke="#d8d2e8" stroke-width="2" fill="none"/>'),
    ])


def goblin_ear():
    return Icon("mat/goblin_ear", [
        ("b", f'<path d="M34 112 C22 96 24 72 38 56 C54 38 84 20 118 8 C108 30 98 52 90 72 C84 88 76 98 66 104 C58 116 44 120 34 112 Z" fill="url(#green)" {S}/>'),
        ("b", f'<path d="M46 98 C40 84 44 70 54 60 C66 48 82 38 98 28 C90 46 82 62 76 76 C70 90 60 98 46 98 Z" fill="#3f6e22" stroke="#22400f" stroke-width="2"/>'),
        ("b", '<path d="M56 86 C54 76 60 68 68 64" stroke="#22400f" stroke-width="2.5" fill="none"/>'),
        ("b", f'<path d="M96 22 L104 30 L98 34" fill="#6aa83a" {S2}/>'),
        ("b", f'<circle cx="44" cy="110" r="7" fill="none" stroke="{OUT}" stroke-width="6"/>'),
        ("b", '<circle cx="44" cy="110" r="7" fill="none" stroke="url(#gld)" stroke-width="3"/>'),
        ("b", '<path d="M34 66 C46 48 70 30 100 16" stroke="#fff" stroke-opacity=".4" stroke-width="3" fill="none"/>'),
    ])


def werewolf_claw():
    return Icon("mat/werewolf_claw", [
        ("b", f'<path d="M40 112 C30 90 34 60 56 36 C70 22 90 12 108 10 C96 26 86 44 82 66 C78 88 66 104 52 116 Z" fill="url(#obs)" {S}/>'),
        ("b", '<path d="M50 96 C46 76 52 56 68 40 C78 30 90 22 100 18" stroke="#fff" stroke-opacity=".35" stroke-width="3" fill="none"/>'),
        ("b", f'<path d="M24 104 C24 92 34 86 46 88 L58 112 C46 122 28 118 24 104 Z" fill="url(#fur)" {S}/>'),
        ("b", '<path d="M30 100 L38 98 M34 108 L42 106" stroke="#3a3a3a" stroke-width="2"/>'),
    ])


def ectoplasm():
    return Icon("mat/ectoplasm", [
        ("b", '<circle cx="64" cy="70" r="54" fill="url(#glowG)" opacity=".7"/>'),
        ("b", f'<path d="M28 108 C18 90 22 54 40 36 C52 24 76 22 88 34 C104 50 108 84 100 108 C92 100 86 112 78 104 C72 114 62 104 56 112 C48 102 40 112 28 108 Z" fill="url(#goo)" {S}/>'),
        ("b", '<ellipse cx="52" cy="60" rx="6" ry="9" fill="#0a2a1e"/><ellipse cx="78" cy="60" rx="6" ry="9" fill="#0a2a1e"/>'),
        ("b", '<path d="M56 84 C62 90 70 90 76 84" stroke="#0a2a1e" stroke-width="3" fill="none"/>'),
        ("b", '<path d="M38 52 C42 40 52 32 62 30" stroke="#fff" stroke-width="3" stroke-opacity=".75" fill="none"/>'),
    ])


def _scale(key, fill, ridge):
    rows = ""
    for r, y in enumerate([34, 52, 70, 88]):
        n = [2, 3, 3, 2][r]
        for i in range(n):
            x = 64 + (i - (n - 1) / 2) * 20
            rows += f'<path d="M{x - 10} {y} C{x - 10} {y + 14} {x + 10} {y + 14} {x + 10} {y}" stroke="{ridge}" stroke-width="2.2" fill="none"/>'
    return Icon(key, [
        ("b", f'<path d="M64 8 C92 22 108 50 104 78 C100 102 82 118 64 122 C46 118 28 102 24 78 C20 50 36 22 64 8 Z" fill="url(#{fill})" {S}/>'),
        ("b", rows),
        ("b", '<path d="M40 40 C46 28 54 20 62 16" stroke="#fff" stroke-opacity=".6" stroke-width="3" fill="none"/>'),
    ])


def salamander_scale():
    return _scale("mat/salamander_scale", "lava", "#7a1a00")


def frost_scale():
    return _scale("mat/frost_scale", "ice", "#2a5a80")


def magma_shard():
    return Icon("mat/magma_shard", [
        ("b", '<circle cx="64" cy="70" r="54" fill="url(#glowR)" opacity=".7"/>'),
        ("b", f'<path d="M30 112 L20 74 L44 32 L70 10 L84 40 L108 62 L98 110 Z" fill="url(#obs)" {S}/>'),
        ("b", '<path d="M44 32 L54 60 L40 84 L56 108 M70 10 L66 48 L84 70 L78 96 M84 40 L96 74" stroke="#ff7a1a" stroke-width="3.5" fill="none"/>'),
        ("b", '<path d="M44 32 L54 60 L40 84 L56 108 M70 10 L66 48 L84 70 L78 96 M84 40 L96 74" stroke="#fff0a0" stroke-width="1.2" fill="none"/>'),
    ])


def yeti_fur():
    bumps = "M20 84 C10 72 16 56 30 56 C30 40 46 32 58 40 C64 26 84 26 88 42 C102 38 114 52 106 64 C120 72 116 92 102 94 C100 108 82 114 72 104 C62 116 40 114 36 102 C22 104 14 94 20 84 Z"
    hair = " ".join(f"M{x} {y} C{x + 3} {y + 6} {x + 1} {y + 12} {x - 2} {y + 16}" for x, y in
                    [(36, 62), (50, 50), (66, 44), (82, 50), (96, 62), (44, 80), (60, 72), (76, 74), (90, 84), (54, 92), (72, 92)])
    return Icon("mat/yeti_fur", [
        ("b", f'<path d="{bumps}" fill="url(#furW)" {S}/>'),
        ("b", f'<path d="{hair}" stroke="#7d8e9c" stroke-width="2" fill="none" stroke-linecap="round"/>'),
        ("b", f'<path d="M58 30 C62 56 62 86 56 112" stroke="{OUT}" stroke-width="10" fill="none"/>'),
        ("b", '<path d="M58 30 C62 56 62 86 56 112" stroke="url(#lea)" stroke-width="6" fill="none"/>'),
        ("b", '<path d="M30 60 C34 48 44 42 54 42" stroke="#fff" stroke-width="3" fill="none"/>'),
    ])


def thick_hide():
    edge = "M24 30 C36 22 46 30 64 24 C82 18 92 28 106 22 C102 40 112 52 106 66 C112 82 100 92 108 108 C90 104 80 112 64 106 C48 112 36 102 20 108 C26 92 16 80 22 66 C14 50 28 42 24 30 Z"
    stitch = "M32 36 C42 32 50 38 64 33 C80 28 90 36 98 32 C96 46 102 54 98 66 C102 80 94 88 98 98 C86 96 78 102 64 98 C50 102 40 94 30 98 C34 86 26 78 30 66 C24 54 34 46 32 36 Z"
    return Icon("mat/thick_hide", [
        ("b", f'<path d="{edge}" fill="url(#lea)" {S}/>'),
        ("b", f'<path d="{stitch}" stroke="#e8d0a0" stroke-width="2" stroke-dasharray="5 4" fill="none"/>'),
        ("b", '<ellipse cx="52" cy="58" rx="9" ry="6" fill="#352012" opacity=".45"/><ellipse cx="78" cy="78" rx="11" ry="7" fill="#352012" opacity=".45"/><ellipse cx="74" cy="48" rx="5" ry="4" fill="#352012" opacity=".4"/>'),
        ("b", f'<path d="M82 104 C90 92 104 92 108 108 C98 112 88 110 82 104 Z" fill="url(#leaD)" {S2}/>'),
        ("b", '<path d="M30 40 C40 32 52 34 62 30" stroke="#fff" stroke-opacity=".35" stroke-width="3" fill="none"/>'),
    ])


def venom_sac():
    return Icon("mat/venom_sac", [
        ("b", '<circle cx="62" cy="62" r="50" fill="url(#glowG)" opacity=".6"/>'),
        ("b", f'<path d="M62 14 C84 14 100 38 100 62 C100 86 84 100 62 100 C40 100 24 86 24 62 C24 38 40 14 62 14 Z" fill="url(#goo)" {S}/>'),
        ("b", '<path d="M40 70 C44 54 56 48 70 50 C64 60 56 72 40 70 Z" fill="#2a7a5a" opacity=".5"/>'),
        ("b", '<path d="M38 44 C44 30 54 24 64 24" stroke="#fff" stroke-width="3.5" stroke-opacity=".8" fill="none"/>'),
        ("b", f'<path d="M82 100 C82 108 86 114 90 120 C94 114 98 108 98 100 C98 94 94 90 90 90 C86 90 82 94 82 100 Z" fill="url(#gemG)" {S2}/>'),
        ("b", f'<path d="M56 8 L68 8 L66 16 L58 16 Z" fill="url(#leaD)" {S2}/>'),
    ])


def feather():
    barbs = "".join(f'<path d="M{64 + i * 0.6:.1f} {24 + i * 7} C{50 - i:.0f} {30 + i * 7} {40 - i:.0f} {36 + i * 7} {34 - i:.0f} {44 + i * 7}" stroke="#16110c" stroke-opacity=".35" stroke-width="1.4" fill="none"/>' for i in range(10))
    return Icon("mat/feather", [
        ("b", f'<path d="M66 10 C90 22 98 56 86 86 C80 100 70 106 64 108 C52 102 34 90 30 70 C26 48 44 22 66 10 Z" fill="url(#obs)" {S}/>'),
        ("b", barbs),
        ("b", f'<path d="M66 12 C68 44 66 84 50 124" stroke="{OUT}" stroke-width="5" fill="none"/>'),
        ("b", '<path d="M66 12 C68 44 66 84 50 124" stroke="#d8d0c0" stroke-width="2.5" fill="none"/>'),
        ("b", '<path d="M74 22 C84 34 88 52 84 70" stroke="#a8b8d8" stroke-opacity=".6" stroke-width="2.5" fill="none"/>'),
    ], "rotate(20 64 64)")


def cursed_bone():
    return Icon("mat/cursed_bone", [
        ("b", '<circle cx="64" cy="64" r="54" fill="url(#glowP)" opacity=".6"/>'),
        ("b", f'<path d="M30 30 C22 22 30 10 40 16 C44 10 56 14 52 24 L104 84 C112 80 120 90 112 98 C118 106 108 116 100 110 C96 118 84 114 88 104 L36 44 C28 48 18 40 24 32 Z" fill="url(#bone)" {S}/>'),
        ("b", '<path d="M54 46 L58 52 L54 58 M66 62 L72 64 L68 70 M80 76 L86 78 L82 84" stroke="#b47aff" stroke-width="2.5" fill="none"/>'),
        ("b", '<path d="M44 34 L96 94" stroke="#fff" stroke-opacity=".5" stroke-width="2.5"/>'),
    ])


# ================================================================ consumables
def _potion(key, glass, liquid, extras=(), top=(), transform=""):
    els = [("b", f'<path d="{glass}" fill="url(#glassV)" fill-opacity=".45" stroke="none"/>')]
    els += list(top)
    els += [("a", f'<path d="{liquid}" fill="url(#accV)"/>'),
            ("a", f'<path d="{glass}" fill="none" {S}/>')]
    els += list(extras)
    return Icon(key, els, transform, accent="#C2352E")


def potion_1():
    glass = "M56 20 L72 20 L72 30 C72 34 76 36 76 40 L76 108 C76 116 70 120 64 120 C58 120 52 116 52 108 L52 40 C52 36 56 34 56 30 Z"
    liquid = "M54 66 C58 62 70 62 74 66 L74 108 C74 114 70 118 64 118 C58 118 54 114 54 108 Z"
    return _potion("pot/1", glass, liquid,
                   [("a", '<path d="M58 72 L58 108" stroke="#fff" stroke-width="3" stroke-opacity=".7"/>'),
                    ("b", f'<rect x="54" y="10" width="20" height="12" rx="3" fill="url(#wood)" {S}/>')],
                   [("b", '<path d="M58 44 L58 60" stroke="#fff" stroke-width="3" stroke-opacity=".6"/>')])


def potion_2():
    glass = "M54 14 L74 14 L74 40 L98 104 C102 114 96 120 88 120 L40 120 C32 120 26 114 30 104 L54 40 Z"
    liquid = "M44 74 C54 70 74 70 84 74 L96 106 C98 114 94 118 86 118 L42 118 C34 118 30 114 32 106 Z"
    return _potion("pot/2", glass, liquid,
                   [("a", '<path d="M42 104 L48 86" stroke="#fff" stroke-width="3.5" stroke-opacity=".7"/>'),
                    ("b", f'<rect x="50" y="6" width="28" height="12" rx="3" fill="url(#wood)" {S}/>')],
                   [("b", '<path d="M58 30 L58 46" stroke="#fff" stroke-width="3" stroke-opacity=".6"/>')])


def potion_3():
    glass = "M54 14 L74 14 L74 40 C94 48 104 64 104 82 C104 104 86 118 64 118 C42 118 24 104 24 82 C24 64 34 48 54 40 Z"
    liquid = "M30 80 C30 104 46 112 64 112 C82 112 98 104 98 80 C86 86 74 74 64 78 C52 82 42 74 30 80 Z"
    return _potion("pot/3", glass, liquid,
                   [("a", '<circle cx="80" cy="96" r="4" fill="#fff" fill-opacity=".6"/><circle cx="70" cy="104" r="2.5" fill="#fff" fill-opacity=".6"/>'),
                    ("b", f'<rect x="50" y="6" width="28" height="12" rx="3" fill="url(#wood)" {S}/>')],
                   [("b", '<path d="M36 70 C38 60 44 54 52 50" stroke="#fff" stroke-opacity=".8" stroke-width="4" fill="none"/>')])


def potion_4():
    glass = "M52 18 L76 18 L76 36 C100 44 112 64 112 84 C112 106 92 122 64 122 C36 122 16 106 16 84 C16 64 28 44 52 36 Z"
    liquid = "M20 82 C20 106 40 118 64 118 C88 118 108 106 108 82 C94 90 80 74 64 78 C48 82 36 72 20 82 Z"
    return _potion("pot/4", glass, liquid,
                   [("a", '<circle cx="88" cy="98" r="5" fill="#fff" fill-opacity=".6"/><circle cx="76" cy="108" r="3" fill="#fff" fill-opacity=".6"/>'),
                    ("b", f'<rect x="48" y="30" width="32" height="9" rx="3" fill="url(#silver)" {S2}/>'),
                    ("b", f'<path d="M46 4 L82 4 L80 20 L48 20 Z" fill="url(#wood)" {S}/>'),
                    ("b", f'<path d="M80 40 C100 30 110 44 102 56" stroke="{OUT}" stroke-width="7" fill="none"/>'),
                    ("b", '<path d="M80 40 C100 30 110 44 102 56" stroke="url(#silver)" stroke-width="3.5" fill="none"/>')],
                   [("b", '<path d="M28 70 C32 58 40 50 50 46" stroke="#fff" stroke-opacity=".8" stroke-width="4.5" fill="none"/>')])


def potion_5():
    glass = "M54 22 L74 22 L74 36 C96 42 110 60 110 80 C110 104 90 120 64 120 C38 120 18 104 18 80 C18 60 32 42 54 36 Z"
    liquid = "M22 80 C22 104 42 116 64 116 C86 116 106 104 106 80 C92 88 78 72 64 76 C50 80 36 70 22 80 Z"
    return _potion("pot/5", glass, liquid,
                   [("a", '<circle cx="86" cy="96" r="5" fill="#fff" fill-opacity=".6"/>'),
                    ("b", f'<path d="M30 84 C30 62 46 48 64 48 C82 48 98 62 98 84" stroke="url(#gld)" stroke-width="3" fill="none"/>'),
                    ("b", f'<path d="M22 66 C10 60 6 44 14 34 C18 46 26 52 36 52 Z M106 66 C118 60 122 44 114 34 C110 46 102 52 92 52 Z" fill="url(#gld)" {S2}/>'),
                    ("b", f'<rect x="50" y="32" width="28" height="8" rx="3" fill="url(#gld)" {S2}/>'),
                    ("b", f'<path d="M64 0 L76 12 L64 24 L52 12 Z" fill="url(#gemY)" {S}/>')],
                   [("b", '<path d="M30 70 C34 58 42 50 52 46" stroke="#fff" stroke-opacity=".8" stroke-width="4.5" fill="none"/>')],
                   "translate(64 64) scale(0.93) translate(-64 -62)")


def _blessing(key, glow, ring, emblem):
    rays = " ".join(f"M{64 + 40 * math.cos(math.radians(a)):.1f} {64 + 40 * math.sin(math.radians(a)):.1f} L{64 + 54 * math.cos(math.radians(a)):.1f} {64 + 54 * math.sin(math.radians(a)):.1f}" for a in range(0, 360, 30))
    return Icon(key, [
        ("b", f'<circle cx="64" cy="64" r="60" fill="url(#{glow})"/>'),
        ("b", f'<path d="{rays}" stroke="{ring}" stroke-width="4" stroke-linecap="round" stroke-opacity=".8"/>'),
        ("b", f'<circle cx="64" cy="64" r="38" fill="url(#gld)" {S}/>'),
        ("b", f'<circle cx="64" cy="64" r="30" fill="{ring}" stroke="{OUT}" stroke-width="2"/>'),
        ("b", '<circle cx="64" cy="64" r="30" fill="url(#glowA)" opacity=".35"/>'),
        ("b", emblem),
        ("b", '<path d="M36 50 C40 40 48 32 58 30" stroke="#fff" stroke-opacity=".7" stroke-width="3" fill="none"/>'),
    ])


def blessings():
    sword = lambda r: f'<g transform="rotate({r} 64 64)"><path d="M64 38 L68 44 L67 76 L61 76 L60 44 Z" fill="#f4f4f4" {S2}/><rect x="54" y="76" width="20" height="4" rx="2" fill="#e8c56a" {S2}/><rect x="62" y="80" width="4" height="9" fill="#5a3a1a" {S2}/></g>'
    return [
        _blessing("bless/warrior", "glowR", "#9a2a20", sword(-35) + sword(35)),
        _blessing("bless/hunter", "glowG", "#2f6a34",
                  f'<path d="M50 40 C38 54 38 74 50 88" stroke="{OUT}" stroke-width="6" fill="none"/><path d="M50 40 C38 54 38 74 50 88" stroke="#c99a62" stroke-width="3" fill="none"/>'
                  f'<path d="M50 40 L50 88" stroke="#efe6d4" stroke-width="1.5"/><path d="M44 64 L88 64" stroke="#f4ecd8" stroke-width="3"/><path d="M84 58 L94 64 L84 70 Z" fill="#f4f4f4" {S2}/><path d="M48 58 L42 64 L48 70 L52 64 Z" fill="#c0503c"/>'),
        _blessing("bless/sage", "glowB", "#1f3f7a",
                  f'<path d="M40 52 C50 46 58 48 64 54 C70 48 78 46 88 52 L88 82 C78 76 70 78 64 84 C58 78 50 76 40 82 Z" fill="#f4ecd8" {S2}/><path d="M64 54 L64 84" stroke="{OUT}" stroke-width="2"/>'
                  f'<path d="{star(64, 42, 9, 3.5, 4)}" fill="#dff6ff"/>'),
        _blessing("bless/guardian", "glowI", "#4a5868",
                  f'<path d="M64 40 L86 46 C86 70 78 84 64 92 C50 84 42 70 42 46 Z" fill="url(#silver)" {S2}/><path d="M64 48 L64 84 M50 58 L78 58" stroke="#3a5a8c" stroke-width="4"/>'),
        _blessing("bless/fortune", "glowW", "#8a6200",
                  f'<circle cx="64" cy="64" r="18" fill="url(#coin)" {S2}/><path d="M64 52 L64 76 M58 56 C58 52 70 52 70 58 C70 64 58 62 58 70 C58 76 70 76 70 72" stroke="#7a5200" stroke-width="2.5" fill="none"/>'),
    ]


def elixir():
    glass = "M56 6 L72 6 L72 26 C80 30 84 38 84 46 L84 110 C84 118 76 122 64 122 C52 122 44 118 44 110 L44 46 C44 38 48 30 56 26 Z"
    liquid = "M46 58 C54 54 74 54 82 58 L82 110 C82 116 76 120 64 120 C52 120 46 116 46 110 Z"
    return Icon("pot/elixir", [
        ("b", f'<path d="{glass}" fill="url(#glassV)" fill-opacity=".45"/>'),
        ("b", '<path d="M50 40 L50 52" stroke="#fff" stroke-width="3" stroke-opacity=".6"/>'),
        ("a", f'<path d="{liquid}" fill="url(#accV)"/>'),
        ("a", f'<path d="{glass}" fill="none" {S}/>'),
        ("a", '<path d="M52 64 L52 110" stroke="#fff" stroke-width="3" stroke-opacity=".65"/>'),
        ("b", f'<path d="M64 70 L78 74 C78 92 72 100 64 106 C56 100 50 92 50 74 Z" fill="url(#silver)" {S2}/>'),
        ("b", '<path d="M64 76 L64 100" stroke="#3a5a8c" stroke-width="3"/>'),
        ("b", f'<rect x="52" y="0" width="24" height="10" rx="3" fill="url(#gld)" {S}/>'),
        ("b", f'<rect x="54" y="22" width="20" height="6" rx="2" fill="url(#gld)" {S2}/>'),
    ], "translate(64 64) scale(0.92) translate(-64 -61)", accent="#FF7A1A")


def stone():
    return Icon("misc/stone", [
        ("a", '<circle cx="64" cy="64" r="56" fill="url(#glowA)" opacity=".75"/>'),
        ("b", f'<path d="M64 10 C92 14 110 40 108 70 C106 100 86 118 62 118 C36 116 20 96 20 68 C20 38 38 8 64 10 Z" fill="url(#stone)" {S}/>'),
        ("b", '<path d="M34 50 C40 32 52 22 66 20" stroke="#fff" stroke-opacity=".35" stroke-width="3.5" fill="none"/>'),
        ("a", f'<path d="M64 34 L64 94 M64 34 L82 50 M64 64 L46 50 M64 64 L82 78 M64 94 L46 80" stroke="{OUT}" stroke-width="8" stroke-linecap="round" fill="none"/>'),
        ("a", '<path d="M64 34 L64 94 M64 34 L82 50 M64 64 L46 50 M64 64 L82 78 M64 94 L46 80" stroke="#ffffff" stroke-width="4" stroke-linecap="round" fill="none"/>'),
    ], accent="#4A8FE7")


def scroll():
    return Icon("misc/scroll", [
        ("b", f'<path d="M30 22 L98 22 L98 104 L30 104 Z" fill="url(#paper)" {S}/>'),
        ("b", "".join(f'<path d="M40 {y} L{88 - (y % 3) * 4} {y}" stroke="#8a6b4a" stroke-width="2" stroke-opacity=".7"/>' for y in (36, 46, 56, 66))),
        ("b", f'<rect x="22" y="12" width="84" height="14" rx="7" fill="url(#paper)" {S}/>'),
        ("b", f'<rect x="22" y="100" width="84" height="14" rx="7" fill="url(#paper)" {S}/>'),
        ("b", f'<rect x="14" y="14" width="10" height="10" rx="3" fill="url(#wood)" {S2}/><rect x="104" y="14" width="10" height="10" rx="3" fill="url(#wood)" {S2}/>'),
        ("b", f'<rect x="14" y="102" width="10" height="10" rx="3" fill="url(#wood)" {S2}/><rect x="104" y="102" width="10" height="10" rx="3" fill="url(#wood)" {S2}/>'),
        ("a", f'<path d="M72 84 L66 118 L74 112 L80 120 L82 86 Z" fill="url(#acc)" {S2}/>'),
        ("a", f'<circle cx="76" cy="84" r="13" fill="url(#accR)" {S}/>'),
        ("a", f'<path d="{star(76, 84, 7, 3, 5)}" fill="#ffffff" fill-opacity=".55" stroke="{OUT}" stroke-width="1.2"/>'),
    ], accent="#C0503C")


def pickaxe():
    return Icon("tool/pickaxe", [
        ("b", f'<rect x="60" y="24" width="8" height="100" rx="3" fill="url(#wood)" {S}/>'),
        ("b", f'<rect x="59" y="96" width="10" height="24" rx="2" fill="url(#lea)" {S}/>'),
        ("b", f'<path d="M14 40 C30 18 56 12 64 14 C72 12 98 18 114 40 C96 30 80 28 70 30 L58 30 C48 28 32 30 14 40 Z" fill="url(#silver)" {S}/>'),
        ("b", '<path d="M24 32 C36 22 50 18 60 18" stroke="#fff" stroke-width="2.5" stroke-opacity=".7" fill="none"/>'),
        ("b", f'<rect x="56" y="14" width="16" height="22" rx="3" fill="url(#silver)" {S}/>'),
    ], "rotate(-30 64 64)")


def fishing_rod():
    return Icon("tool/fishing_rod", [
        ("b", f'<path d="M22 118 L104 12" stroke="{OUT}" stroke-width="8" stroke-linecap="round"/>'),
        ("b", '<path d="M22 118 L104 12" stroke="url(#woodL)" stroke-width="4.5" stroke-linecap="round"/>'),
        ("b", f'<path d="M22 118 L40 95" stroke="{OUT}" stroke-width="10" stroke-linecap="round"/>'),
        ("b", '<path d="M22 118 L40 95" stroke="url(#leaD)" stroke-width="6.5" stroke-linecap="round"/>'),
        ("b", f'<circle cx="44" cy="96" r="8" fill="url(#silver)" {S2}/>'),
        ("b", '<path d="M104 12 C110 40 108 70 100 86" stroke="#efe6d4" stroke-width="1.6" fill="none"/>'),
        ("b", f'<path d="M100 86 C100 80 108 80 108 86 L104 96 Z" fill="#c0503c" {S2}/>'),
        ("b", f'<path d="M100 86 C100 92 108 92 108 86 Z" fill="#f4f4f4" {S2}/>'),
    ])


def backpack():
    return Icon("misc/backpack", [
        ("a", f'<path d="M28 44 C28 26 44 16 64 16 C84 16 100 26 100 44 L104 110 C104 118 96 122 88 122 L40 122 C32 122 24 118 24 110 Z" fill="url(#acc)" {S}/>'),
        ("a", f'<path d="M30 46 C34 32 48 26 64 26 C80 26 94 32 98 46 L98 70 C86 76 42 76 30 70 Z" fill="url(#acc)" {S}/>'),
        ("a", f'<path d="M38 84 L90 84 L88 112 L40 112 Z" fill="url(#acc)" {S}/>'),
        ("b", f'<path d="M50 6 C50 0 78 0 78 6 L78 18 L70 18 L70 10 L58 10 L58 18 L50 18 Z" fill="url(#leaD)" {S2}/>'),
        ("b", f'<path d="M46 60 L46 90 M82 60 L82 90" stroke="{OUT}" stroke-width="8"/>'),
        ("b", '<path d="M46 60 L46 90 M82 60 L82 90" stroke="url(#leaD)" stroke-width="5"/>'),
        ("b", f'<rect x="40" y="64" width="12" height="10" rx="2" fill="url(#gld)" {S2}/><rect x="76" y="64" width="12" height="10" rx="2" fill="url(#gld)" {S2}/>'),
        ("b", '<path d="M36 42 C40 32 50 28 60 28" stroke="#fff" stroke-opacity=".45" stroke-width="3" fill="none"/>'),
        ("b", '<path d="M42 96 L86 96" stroke="#16110c" stroke-opacity=".4" stroke-width="1.5" stroke-dasharray="3 3"/>'),
    ], accent="#B89B5A")


# ================================================================ UI currency
def gold():
    coins = "".join(f'<ellipse cx="{x}" cy="{y}" rx="22" ry="9" fill="url(#coin)" {S2}/>' for x, y in
                    [(44, 106), (44, 98), (44, 90), (44, 82), (84, 108), (84, 100), (84, 92)])
    return Icon("ui/gold", [
        ("b", coins),
        ("b", f'<circle cx="68" cy="50" r="28" fill="url(#coin)" {S}/>'),
        ("b", f'<circle cx="68" cy="50" r="20" fill="none" stroke="#a87a10" stroke-width="2"/>'),
        ("b", f'<path d="{star(68, 50, 12, 5, 4)}" fill="#fff6c0" stroke="#a87a10" stroke-width="1.5"/>'),
        ("b", '<path d="M48 40 C52 30 60 26 66 26" stroke="#fff" stroke-width="3" stroke-opacity=".8" fill="none"/>'),
    ])


def exp():
    return Icon("ui/exp", [
        ("b", '<circle cx="64" cy="64" r="58" fill="url(#glowG)"/>'),
        ("b", f'<circle cx="64" cy="64" r="34" fill="url(#gemG)" {S}/>'),
        ("b", f'<path d="{star(64, 64, 22, 9, 4)}" fill="#f4ffe8" stroke="#2a6a1a" stroke-width="1.5"/>'),
        ("b", '<circle cx="52" cy="50" r="6" fill="#fff" fill-opacity=".7"/>'),
        sparkle(106, 26, 10), sparkle(22, 100, 8),
    ])


def dragon_shard():
    return Icon("ui/dragon", [
        ("b", '<circle cx="64" cy="66" r="56" fill="url(#glowR)" opacity=".8"/>'),
        ("b", f'<path d="M64 6 L92 40 L80 116 L48 116 L36 40 Z" fill="url(#gem)" {S}/>'),
        ("b", '<path d="M64 6 L64 116 M36 40 L64 52 L92 40" stroke="#4a0a10" stroke-width="2" fill="none"/>'),
        ("b", '<path d="M50 44 L60 18" stroke="#fff" stroke-width="3.5" stroke-opacity=".8"/>'),
        sparkle(100, 24, 9),
    ])


def icons():
    out = [grimrok_cleaver(), grimrok_fang(), grimrok_totem(), morvane_shroud(), morvane_scepter(), morvane_bow(),
           azgor_heart(), azgor_staff(), azgor_helm(), vaelgrath_fang(), vaelgrath_scale(), vaelgrath_eye(),
           essence_dust(), essence_shard(), essence_crystal(), legend_core(), ore(), herb(), fish(),
           wolf_pelt(), boar_tusk(), spider_silk(), goblin_ear(), werewolf_claw(), ectoplasm(), salamander_scale(),
           magma_shard(), yeti_fur(), frost_scale(), thick_hide(), venom_sac(), feather(), cursed_bone(),
           potion_1(), potion_2(), potion_3(), potion_4(), potion_5()]
    out += blessings()
    out += [elixir(), stone(), scroll(), pickaxe(), fishing_rod(), backpack(), gold(), exp(), dragon_shard()]
    return out
