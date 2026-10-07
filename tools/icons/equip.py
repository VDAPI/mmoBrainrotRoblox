# Equipment base icons: one silhouette per base type, material layer (m) tinted by tier in game.
from core import Icon, S, S2, S4, OUT

HL = 'stroke="#ffffff" stroke-opacity=".6" stroke-width="3" fill="none" stroke-linecap="round"'
HLs = 'stroke="#ffffff" stroke-opacity=".45" stroke-width="2" fill="none" stroke-linecap="round"'
SH = 'stroke="#000" stroke-opacity=".28" stroke-width="2" fill="none" stroke-linecap="round"'


def wraps(x0, x1, y0, y1, step=6):
    d = " ".join(f"M{x0} {y} L{x1} {y + 4}" for y in range(y0, y1, step))
    return ("b", f'<path d="{d}" stroke="{OUT}" stroke-width="1.6" fill="none"/>')


def thick(layer, d, fill, w_out=11, w_in=7):
    """A stroked limb (bow, chain, prod): dark outline stroke plus coloured inner stroke."""
    return [(layer, f'<path d="{d}" fill="none" stroke="{OUT}" stroke-width="{w_out}" stroke-linecap="round" stroke-linejoin="round"/>'),
            (layer, f'<path d="{d}" fill="none" stroke="{fill}" stroke-width="{w_in}" stroke-linecap="round" stroke-linejoin="round"/>')]


# ---------------------------------------------------------------- weapons: warrior
def sword1h():
    return Icon("eq/sword1h", [
        ("m", f'<path d="M64 6 L73 20 L72 82 L56 82 L55 20 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M64 14 L64 78" {HL}/>'),
        ("b", f'<path d="M67 20 L69 24 L68.5 78" {SH}/>'),
        ("m", f'<path d="M38 82 C40 78 48 79 52 80 L76 80 C80 79 88 78 90 82 C88 88 80 89 76 88 L52 88 C48 89 40 88 38 82 Z" fill="url(#met)" {S}/>'),
        ("b", f'<rect x="59" y="89" width="10" height="22" rx="2" fill="url(#lea)" {S}/>'),
        wraps(59, 69, 93, 109),
        ("m", f'<circle cx="64" cy="116" r="6.5" fill="url(#met)" {S}/>'),
    ], "rotate(45 64 64) translate(0 2)")


def axe1h():
    return Icon("eq/axe1h", [
        ("b", f'<rect x="60" y="22" width="8" height="98" rx="3" fill="url(#wood)" {S}/>'),
        ("b", f'<rect x="59" y="92" width="10" height="24" rx="2" fill="url(#lea)" {S}/>'),
        wraps(59, 69, 96, 114),
        ("m", f'<path d="M68 26 C84 16 104 20 112 32 C114 50 106 66 92 72 C86 62 78 56 68 56 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M108 30 C111 42 109 56 98 66" {HL}/>'),
        ("m", f'<path d="M60 30 L44 37 L60 46 Z" fill="url(#met)" {S}/>'),
        ("m", f'<rect x="57" y="22" width="14" height="38" rx="3" fill="url(#met)" {S}/>'),
        ("m", f'<rect x="58.5" y="116" width="11" height="7" rx="2" fill="url(#met)" {S}/>'),
    ], "rotate(-28 64 64) translate(-4 0)")


def mace1h():
    return Icon("eq/mace1h", [
        ("b", f'<rect x="60" y="44" width="8" height="70" rx="3" fill="url(#wood)" {S}/>'),
        ("b", f'<rect x="59" y="86" width="10" height="26" rx="2" fill="url(#lea)" {S}/>'),
        wraps(59, 69, 90, 110),
        ("m", f'<path d="M64 4 L72 16 L84 18 L78 30 L84 42 L72 44 L64 56 L56 44 L44 42 L50 30 L44 18 L56 16 Z" fill="url(#met)" {S}/>'),
        ("m", f'<circle cx="64" cy="30" r="10" fill="url(#met)" {S2}/>'),
        ("b", f'<path d="M58 22 C60 19 63 18 66 18" {HL}/>'),
        ("m", f'<rect x="55" y="52" width="18" height="8" rx="3" fill="url(#met)" {S}/>'),
        ("m", f'<circle cx="64" cy="117" r="5.5" fill="url(#met)" {S}/>'),
    ], "rotate(40 64 64)")


def saber1h():
    return Icon("eq/saber1h", [
        ("m", f'<path d="M58 84 C56 58 62 30 82 6 C78 34 72 60 70 84 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M62 80 C61 58 66 36 78 14" {HL}/>'),
        *thick("m", "M72 90 C90 96 88 116 70 118", "url(#met)", 9, 5),
        ("m", f'<path d="M46 84 L80 84 C84 84 84 92 80 92 L46 92 C42 92 42 84 46 84 Z" fill="url(#met)" {S}/>'),
        ("b", f'<rect x="59" y="92" width="10" height="22" rx="2" fill="url(#leaD)" {S}/>'),
        wraps(59, 69, 96, 112),
        ("m", f'<circle cx="64" cy="117" r="5" fill="url(#met)" {S}/>'),
    ], "rotate(42 64 64) translate(0 2)")


def sword2h():
    return Icon("eq/sword2h", [
        ("m", f'<path d="M64 -10 L75 6 L74 76 L54 76 L53 6 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M64 0 L64 72" {HL}/>'),
        ("b", f'<path d="M68 8 L70 12 L69.5 72" {SH}/>'),
        ("m", f'<path d="M30 74 C30 68 38 70 44 72 L84 72 C90 70 98 68 98 74 C98 82 90 82 84 80 L44 80 C38 82 30 82 30 74 Z" fill="url(#met)" {S}/>'),
        ("m", f'<rect x="58" y="80" width="12" height="8" fill="url(#met)" {S2}/>'),
        ("b", f'<rect x="59" y="88" width="10" height="34" rx="2" fill="url(#leaD)" {S}/>'),
        wraps(59, 69, 92, 120),
        ("m", f'<path d="M64 120 L72 128 L64 136 L56 128 Z" fill="url(#met)" {S}/>'),
    ], "rotate(45 64 64)")


def axe2h():
    return Icon("eq/axe2h", [
        ("b", f'<rect x="59" y="8" width="10" height="118" rx="4" fill="url(#wood)" {S}/>'),
        ("b", f'<path d="M59 96 L69 100 M59 102 L69 106 M59 108 L69 112" stroke="{OUT}" stroke-width="1.5"/>'),
        ("m", f'<path d="M69 20 C92 12 114 20 118 40 C114 60 92 68 69 60 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M59 24 C42 18 30 28 28 40 C30 52 42 60 59 56 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M114 28 C116 36 116 44 114 52" {HL}/>'),
        ("b", f'<path d="M32 32 C30 38 30 44 32 48" {HLs}/>'),
        ("m", f'<rect x="56" y="16" width="16" height="48" rx="3" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M64 0 L70 10 L58 10 Z" fill="url(#met)" {S}/>'),
    ], "rotate(-30 64 64)")


def hammer2h():
    return Icon("eq/hammer2h", [
        ("b", f'<rect x="60" y="22" width="8" height="108" rx="3" fill="url(#wood)" {S}/>'),
        ("b", f'<rect x="59" y="98" width="10" height="26" rx="2" fill="url(#lea)" {S}/>'),
        wraps(59, 69, 102, 122),
        ("m", f'<path d="M36 6 L88 6 L92 12 L92 34 L88 40 L36 40 L32 34 L32 12 Z" fill="url(#met)" {S}/>'),
        ("m", f'<rect x="20" y="2" width="14" height="42" rx="3" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M92 14 L116 23 L92 32 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M38 11 L86 11" {HL}/>'),
        ("b", f'<path d="M24 8 L24 38" {HLs}/>'),
        ("b", f'<path d="M48 18 L48 30 M60 18 L60 30 M72 18 L72 30" stroke="{OUT}" stroke-opacity=".5" stroke-width="2"/>'),
        ("m", f'<rect x="55" y="40" width="18" height="10" rx="3" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M58 128 L70 128 L64 138 Z" fill="url(#met)" {S}/>'),
    ], "translate(64 64) scale(0.88) translate(-64 -64) rotate(-38 64 64) translate(4 -2)")


def spear2h():
    return Icon("eq/spear2h", [
        ("b", f'<rect x="61" y="34" width="6" height="100" rx="3" fill="url(#wood)" {S}/>'),
        ("m", f'<path d="M64 -8 C76 8 78 24 71 40 L57 40 C50 24 52 8 64 -8 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M64 0 L64 36" stroke="#000" stroke-opacity=".3" stroke-width="2"/>'),
        ("b", f'<path d="M60 6 C57 14 57 24 60 32" {HLs}/>'),
        ("m", f'<rect x="57" y="38" width="14" height="14" rx="3" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M58 52 C50 58 48 70 52 78 C56 72 58 64 62 58 Z" fill="url(#cloR)" {S2}/>'),
        ("b", f'<path d="M70 52 C76 60 76 68 72 74 C70 68 68 62 66 58 Z" fill="url(#cloR)" {S2}/>'),
        ("m", f'<rect x="59.5" y="128" width="9" height="8" rx="2" fill="url(#met)" {S}/>'),
    ], "rotate(45 64 64)")


# ---------------------------------------------------------------- weapons: hunter
def _bow(key, d, tips, string, grip, rot, fittings=()):
    els = [*thick("b", d, "url(#wood)", 12, 7),
           ("m", f'<path d="{d}" fill="none" stroke="url(#metV)" stroke-width="3.6" transform="translate(-2.2 0)"/>'),
           ("b", f'<path d="{string}" stroke="#efe6d4" stroke-width="1.8" fill="none"/>'),
           ("b", f'<rect x="{grip[0]}" y="{grip[1]}" width="{grip[2]}" height="{grip[3]}" rx="3" fill="url(#lea)" {S}/>')]
    for f in fittings:
        els.append(("m", f))
    for (x, y) in tips:
        els.append(("m", f'<circle cx="{x}" cy="{y}" r="5.5" fill="url(#met)" {S}/>'))
    return Icon(key, els, rot)


def shortbow():
    d = "M84 14 C82 20 78 22 74 24 C56 36 50 50 50 64 C50 78 56 92 74 104 C78 106 82 108 84 114"
    return _bow("eq/shortbow", d, [(84, 14), (84, 114)], "M84 14 L84 114", (45, 55, 10, 18), "rotate(-35 64 64)",
                [f'<rect x="44" y="50" width="12" height="5" rx="2" fill="url(#met)" {S2}/>',
                 f'<rect x="44" y="73" width="12" height="5" rx="2" fill="url(#met)" {S2}/>'])


def bow():
    d = "M80 6 C36 30 36 98 80 122"
    return _bow("eq/bow", d, [(80, 6), (80, 122)], "M80 7 L80 121", (42, 54, 10, 20), "rotate(-35 64 64)",
                [f'<rect x="41" y="49" width="12" height="5" rx="2" fill="url(#met)" {S2}/>',
                 f'<rect x="41" y="74" width="12" height="5" rx="2" fill="url(#met)" {S2}/>'])


def longbow():
    d = "M76 -8 C48 30 48 98 76 136"
    return _bow("eq/longbow", d, [(76, -8), (76, 136)], "M76 -7 L76 135", (50, 54, 10, 20), "translate(64 64) scale(0.93) translate(-64 -64) rotate(-45 64 64)",
                [f'<rect x="49" y="49" width="12" height="5" rx="2" fill="url(#met)" {S2}/>',
                 f'<rect x="49" y="74" width="12" height="5" rx="2" fill="url(#met)" {S2}/>'])


def crossbow():
    return Icon("eq/crossbow", [
        ("b", f'<path d="M57 30 L71 30 L73 92 L84 116 L66 122 L55 96 Z" fill="url(#wood)" {S}/>'),
        ("b", f'<path d="M64 34 L64 88" stroke="{OUT}" stroke-opacity=".55" stroke-width="2"/>'),
        ("b", f'<path d="M22 42 L64 60 L106 42" stroke="#efe6d4" stroke-width="2" fill="none"/>'),
        *thick("m", "M20 44 C40 28 88 28 108 44", "url(#metH)", 12, 7),
        ("b", f'<path d="M64 16 L64 58" stroke="url(#wood)" stroke-width="4"/>'),
        ("m", f'<path d="M64 8 L69 18 L59 18 Z" fill="url(#met)" {S2}/>'),
        ("b", f'<path d="M64 54 L58 62 M64 54 L70 62" stroke="#c0503c" stroke-width="3"/>'),
        ("m", f'<rect x="55" y="26" width="18" height="10" rx="3" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M66 76 L74 80 L72 90 L66 86 Z" fill="url(#met)" {S2}/>'),
    ], "rotate(-35 64 64) translate(0 4)")


def heavycrossbow():
    return Icon("eq/heavycrossbow", [
        ("b", f'<path d="M54 30 L74 30 L76 92 L88 118 L66 124 L52 96 Z" fill="url(#leaD)" {S}/>'),
        ("b", f'<path d="M64 34 L64 88" stroke="{OUT}" stroke-opacity=".55" stroke-width="2"/>'),
        ("b", f'<path d="M14 46 L64 64 L114 46" stroke="#efe6d4" stroke-width="2.4" fill="none"/>'),
        *thick("m", "M12 48 C36 24 92 24 116 48", "url(#metH)", 15, 10),
        ("b", f'<path d="M20 40 C40 28 88 28 108 40" {HLs}/>'),
        ("b", f'<path d="M64 14 L64 60" stroke="url(#wood)" stroke-width="5"/>'),
        ("m", f'<path d="M64 4 L70 16 L58 16 Z" fill="url(#met)" {S2}/>'),
        ("m", f'<rect x="52" y="24" width="24" height="14" rx="3" fill="url(#met)" {S}/>'),
        ("m", f'<rect x="53" y="56" width="22" height="7" rx="2" fill="url(#met)" {S2}/>'),
        ("m", f'<rect x="54" y="84" width="22" height="7" rx="2" fill="url(#met)" {S2}/>'),
        ("m", f'<circle cx="80" cy="104" r="11" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M80 95 L80 113 M71 104 L89 104" stroke="{OUT}" stroke-width="2.4"/>'),
        ("m", f'<circle cx="80" cy="104" r="3.5" fill="url(#met)" {S2}/>'),
    ], "rotate(-35 64 64) translate(0 2)")


# ---------------------------------------------------------------- weapons: mage (elemental accent)
def wand():
    return Icon("eq/wand", [
        ("a", '<circle cx="64" cy="26" r="22" fill="url(#glowA)"/>'),
        ("b", f'<rect x="60" y="40" width="8" height="78" rx="3" fill="url(#wood)" {S}/>'),
        ("b", f'<path d="M62 48 L62 110" {HLs}/>'),
        ("m", f'<path d="M54 42 L74 42 L70 34 L58 34 Z" fill="url(#met)" {S}/>'),
        ("m", f'<rect x="57" y="96" width="14" height="6" rx="2" fill="url(#met)" {S2}/>'),
        ("m", f'<circle cx="64" cy="118" r="4.5" fill="url(#met)" {S2}/>'),
        ("a", f'<circle cx="64" cy="26" r="10.5" fill="url(#accR)" {S}/>'),
        ("a", '<path d="M30 20 l3 -7 l3 7 l7 3 l-7 3 l-3 7 l-3 -7 l-7 -3 Z" fill="#ffffff"/>'),
        ("a", '<path d="M92 46 l2 -4 l2 4 l4 2 l-4 2 l-2 4 l-2 -4 l-4 -2 Z" fill="#ffffff"/>'),
    ], "rotate(40 64 64)", accent="#FF7A1A")


def staff():
    return Icon("eq/staff", [
        ("a", '<circle cx="64" cy="22" r="26" fill="url(#glowA)"/>'),
        ("b", f'<rect x="60" y="30" width="8" height="100" rx="3" fill="url(#wood)" {S}/>'),
        ("b", f'<path d="M62 40 L62 124" {HLs}/>'),
        ("b", f'<rect x="59" y="62" width="10" height="16" rx="2" fill="url(#lea)" {S2}/>'),
        ("m", f'<path d="M48 42 C46 28 54 22 64 34 C74 22 82 28 80 42 L70 46 L58 46 Z" fill="url(#met)" {S}/>'),
        ("a", f'<path d="M64 2 L76 20 L64 38 L52 20 Z" fill="url(#accR)" {S}/>'),
        ("a", '<path d="M60 12 L64 7 L67 12" stroke="#fff" stroke-width="2" fill="none"/>'),
        ("m", f'<rect x="59" y="126" width="10" height="6" rx="2" fill="url(#met)" {S2}/>'),
    ], "rotate(32 64 64)", accent="#9FE0FF")


def runestaff():
    return Icon("eq/runestaff", [
        ("a", '<circle cx="64" cy="24" r="28" fill="url(#glowA)"/>'),
        ("b", f'<rect x="60" y="40" width="8" height="94" rx="3" fill="url(#leaD)" {S}/>'),
        ("a", '<path d="M62 56 L66 60 L62 64 M66 74 L62 78 L66 82 M62 92 L66 96 L62 100" stroke="#ffffff" stroke-width="2" fill="none"/>'),
        *thick("m", "M64 46 C40 46 40 4 64 4 C88 4 88 46 64 46", "url(#met)", 11, 6),
        ("m", f'<path d="M56 40 L72 40 L70 52 L58 52 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M64 0 L68 -8 L60 -8 Z" fill="url(#met)" {S2}/>'),
        ("a", f'<path d="M64 12 L74 20 L74 32 L64 40 L54 32 L54 20 Z" fill="url(#accR)" {S}/>'),
        ("a", '<path d="M60 20 L64 16 L68 20" stroke="#fff" stroke-width="2" fill="none"/>'),
        ("m", f'<rect x="59" y="128" width="10" height="7" rx="2" fill="url(#met)" {S2}/>'),
    ], "rotate(35 64 64) translate(0 2)", accent="#F2E85A")


# ---------------------------------------------------------------- weapons: cleric
def scepter():
    return Icon("eq/scepter", [
        ("b", '<circle cx="64" cy="26" r="24" fill="url(#glowW)" opacity=".7"/>'),
        ("b", f'<rect x="60" y="44" width="8" height="72" rx="3" fill="url(#leaD)" {S}/>'),
        ("m", f'<path d="M46 36 L50 14 L57 25 L64 6 L71 25 L78 14 L82 36 Z" fill="url(#met)" {S}/>'),
        ("m", f'<rect x="46" y="34" width="36" height="10" rx="3" fill="url(#met)" {S}/>'),
        ("b", f'<circle cx="64" cy="26" r="6" fill="url(#gemY)" {S2}/>'),
        ("b", f'<path d="M52 20 L55 30" {HLs}/>'),
        ("m", f'<rect x="57" y="70" width="14" height="6" rx="2" fill="url(#met)" {S2}/>'),
        ("m", f'<rect x="57" y="96" width="14" height="6" rx="2" fill="url(#met)" {S2}/>'),
        ("m", f'<circle cx="64" cy="118" r="5" fill="url(#met)" {S2}/>'),
    ], "rotate(40 64 64)")


def flail1h():
    links = []
    for (x, y, r) in [(68, 58, -40), (74, 50, 40), (80, 42, -40)]:
        links.append(("m", f'<ellipse cx="{x}" cy="{y}" rx="4" ry="6.5" transform="rotate({r} {x} {y})" fill="none" stroke="{OUT}" stroke-width="5"/>'))
        links.append(("m", f'<ellipse cx="{x}" cy="{y}" rx="4" ry="6.5" transform="rotate({r} {x} {y})" fill="none" stroke="url(#met)" stroke-width="2.5"/>'))
    spikes = " ".join(
        f"M{86 + 14 * c:.1f} {28 + 14 * s:.1f} L{86 + 24 * c:.1f} {28 + 24 * s:.1f} L{86 + 14 * c2:.1f} {28 + 14 * s2:.1f} Z"
        for c, s, c2, s2 in [(1, -0.3, 0.75, 0.66), (0.3, -1, 0.95, -0.3), (-0.75, -0.66, -0.3, -0.95),
                             (-1, 0.3, -0.95, -0.3), (-0.3, 1, -0.66, 0.75), (0.66, 0.75, 1, 0.1)])
    return Icon("eq/flail1h", [
        ("b", f'<rect x="57" y="68" width="12" height="54" rx="3" fill="url(#wood)" {S}/>'),
        ("b", f'<rect x="56" y="92" width="14" height="26" rx="2" fill="url(#lea)" {S}/>'),
        wraps(56, 70, 96, 116),
        ("m", f'<rect x="55" y="62" width="16" height="10" rx="3" fill="url(#met)" {S}/>'),
        *links,
        ("m", f'<path d="{spikes}" fill="url(#met)" {S2}/>'),
        ("m", f'<circle cx="86" cy="28" r="15" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M78 20 C80 17 84 16 88 16" {HL}/>'),
        ("b", '<circle cx="86" cy="28" r="2.5" fill="#16110c" opacity=".5"/>'),
    ], "rotate(-8 64 64) translate(-6 0)")


def holystaff():
    rays = " ".join(f"M{64 + 18 * c:.1f} {24 + 18 * s:.1f} L{64 + 27 * c:.1f} {24 + 27 * s:.1f}"
                    for c, s in [(1, 0), (0.7, -0.7), (0, -1), (-0.7, -0.7), (-1, 0), (-0.7, 0.7), (0.7, 0.7)])
    return Icon("eq/holystaff", [
        ("b", '<circle cx="64" cy="24" r="30" fill="url(#glowW)"/>'),
        ("b", f'<rect x="60" y="40" width="8" height="92" rx="3" fill="url(#woodL)" {S}/>'),
        ("b", f'<rect x="59" y="72" width="10" height="16" rx="2" fill="url(#cloW)" {S2}/>'),
        ("m", f'<path d="{rays}" stroke="{OUT}" stroke-width="7" stroke-linecap="round"/>'),
        ("m", f'<path d="{rays}" stroke="url(#met)" stroke-width="3.5" stroke-linecap="round"/>'),
        *thick("m", "M64 40 C50 40 46 30 46 24 C46 14 54 6 64 6 C74 6 82 14 82 24 C82 30 78 40 64 40", "url(#met)", 10, 5),
        ("m", f'<path d="M61 12 L67 12 L67 21 L74 21 L74 27 L67 27 L67 38 L61 38 L61 27 L54 27 L54 21 L61 21 Z" fill="url(#met)" {S2}/>'),
        ("b", f'<circle cx="64" cy="24" r="3.5" fill="url(#gemY)" {S2}/>'),
        ("m", f'<rect x="57" y="40" width="14" height="8" rx="2" fill="url(#met)" {S}/>'),
    ], "rotate(32 64 64) translate(0 2)")


# ---------------------------------------------------------------- off-hands
def shield():
    return Icon("eq/shield", [
        ("m", f'<path d="M64 8 L110 20 C110 70 94 104 64 122 C34 104 18 70 18 20 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M64 19 L99 28 C98 68 85 95 64 109 C43 95 30 68 29 28 Z" fill="url(#clo)" stroke="{OUT}" stroke-width="2"/>'),
        ("b", '<path d="M64 21 L64 107 M32 46 L96 46" stroke="#d9c38a" stroke-width="5"/>'),
        ("m", f'<circle cx="64" cy="54" r="10" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M26 24 C28 60 40 88 58 104" {HL}/>'),
    ])


def quiver():
    return Icon("eq/quiver", [
        ("b", f'<path d="M48 16 L52 34 M60 12 L62 34 M72 14 L70 34" stroke="url(#wood)" stroke-width="4"/>'),
        ("b", f'<path d="M48 16 L52 34 M60 12 L62 34 M72 14 L70 34" stroke="{OUT}" stroke-width="1" fill="none"/>'),
        ("b", f'<path d="M42 6 L48 16 L44 20 Z M54 2 L60 12 L56 16 Z M66 4 L72 14 L68 18 Z" fill="#c0503c" {S2}/>'),
        ("b", f'<path d="M48 4 L48 16 L52 12 Z M60 0 L60 12 L64 8 Z M72 2 L72 14 L76 10 Z" fill="#efe6d4" {S2}/>'),
        ("b", f'<path d="M40 30 L84 30 L80 120 L48 120 Z" fill="url(#lea)" {S}/>'),
        ("b", f'<path d="M46 36 L52 114" {HLs}/>'),
        ("b", f'<path d="M30 40 C40 70 70 100 96 112" stroke="{OUT}" stroke-width="8" fill="none"/>'),
        ("b", f'<path d="M30 40 C40 70 70 100 96 112" stroke="url(#leaD)" stroke-width="5" fill="none"/>'),
        ("m", f'<path d="M39 30 L85 30 L84 40 L40 40 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M45 100 L82 100 L81 110 L46 110 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M47 118 L81 118 L79 126 L49 126 Z" fill="url(#met)" {S}/>'),
    ], "translate(64 64) scale(0.94) translate(-64 -64) rotate(18 64 64) translate(2 -1)")


def tome():
    return Icon("eq/tome", [
        ("b", f'<rect x="34" y="18" width="70" height="94" rx="3" fill="url(#cloW)" {S}/>'),
        ("b", '<path d="M38 104 L100 104 M38 108 L100 108" stroke="#8f8670" stroke-width="1.2"/>'),
        ("b", f'<rect x="24" y="12" width="74" height="98" rx="4" fill="url(#cloR)" {S}/>'),
        ("b", f'<rect x="24" y="12" width="12" height="98" rx="3" fill="url(#leaD)" {S}/>'),
        ("m", f'<path d="M98 12 L98 30 L82 12 Z M98 110 L98 92 L82 110 Z" fill="url(#met)" {S2}/>'),
        ("m", f'<path d="M36 12 L36 26 L50 12 Z M36 110 L36 96 L50 110 Z" fill="url(#met)" {S2}/>'),
        ("m", f'<circle cx="67" cy="61" r="17" fill="url(#met)" {S}/>'),
        ("b", f'<circle cx="67" cy="61" r="11" fill="#2a1f50" stroke="{OUT}" stroke-width="2"/>'),
        ("b", f'<path d="M67 51 L70 58 L77 61 L70 64 L67 71 L64 64 L57 61 L64 58 Z" fill="url(#gemP)" {S2}/>'),
        ("m", f'<rect x="92" y="52" width="16" height="18" rx="3" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M40 18 L40 104" {HLs}/>'),
    ], "rotate(-8 64 64)")


def orb():
    return Icon("eq/orb", [
        ("b", '<circle cx="64" cy="50" r="40" fill="url(#glowP)"/>'),
        ("m", f'<path d="M40 112 L88 112 C92 112 94 118 88 120 L40 120 C34 118 36 112 40 112 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M56 112 L58 90 L70 90 L72 112 Z" fill="url(#met)" {S}/>'),
        ("b", f'<circle cx="64" cy="52" r="32" fill="url(#gemP)" {S}/>'),
        ("b", '<path d="M44 58 C50 40 70 36 82 46 C72 44 58 48 54 62 Z" fill="#ffffff" fill-opacity=".25"/>'),
        ("b", '<circle cx="52" cy="38" r="6" fill="#ffffff" fill-opacity=".65"/>'),
        ("m", f'<path d="M46 92 C36 84 32 72 34 64 L40 66 C40 74 46 82 54 86 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M82 92 C92 84 96 72 94 64 L88 66 C88 74 82 82 74 86 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M52 92 L76 92 L72 84 L56 84 Z" fill="url(#met)" {S}/>'),
    ])


def relic():
    rays = " ".join(f"M{64 + 24 * c:.1f} {50 + 24 * s:.1f} L{64 + 36 * c:.1f} {50 + 36 * s:.1f}"
                    for c, s in [(1, 0), (0.87, -0.5), (0.5, -0.87), (0, -1), (-0.5, -0.87), (-0.87, -0.5), (-1, 0),
                                 (0.87, 0.5), (-0.87, 0.5)])
    return Icon("eq/relic", [
        ("b", '<circle cx="64" cy="50" r="42" fill="url(#glowW)"/>'),
        ("m", f'<path d="{rays}" stroke="{OUT}" stroke-width="8" stroke-linecap="round"/>'),
        ("m", f'<path d="{rays}" stroke="url(#met)" stroke-width="4" stroke-linecap="round"/>'),
        ("m", f'<path d="M40 116 L88 116 C92 116 92 122 88 122 L40 122 C36 122 36 116 40 116 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M56 116 L60 76 L68 76 L72 116 Z" fill="url(#met)" {S}/>'),
        ("m", f'<circle cx="64" cy="50" r="24" fill="url(#met)" {S}/>'),
        ("b", f'<circle cx="64" cy="50" r="15" fill="#fff6dc" stroke="{OUT}" stroke-width="2"/>'),
        ("b", f'<path d="M61 40 L67 40 L67 47 L73 47 L73 53 L67 53 L67 61 L61 61 L61 53 L55 53 L55 47 L61 47 Z" fill="url(#gld)" {S2}/>'),
        ("b", f'<path d="M46 40 C48 34 54 30 60 28" {HL}/>'),
        ("m", f'<rect x="54" y="88" width="20" height="7" rx="3" fill="url(#met)" {S2}/>'),
    ])


# ---------------------------------------------------------------- jewellery
def necklace():
    return Icon("eq/necklace", [
        *thick("m", "M26 12 C26 52 46 74 64 78 C82 74 102 52 102 12", "url(#met)", 7, 3.5),
        ("b", f'<path d="M26 12 C26 52 46 74 64 78 C82 74 102 52 102 12" stroke="{OUT}" stroke-width="1.4" stroke-dasharray="1.5 4" fill="none"/>'),
        ("m", f'<circle cx="64" cy="80" r="5" fill="none" stroke="{OUT}" stroke-width="5"/>'),
        ("m", f'<circle cx="64" cy="80" r="5" fill="none" stroke="url(#met)" stroke-width="2.5"/>'),
        ("m", f'<path d="M64 86 C80 86 86 98 82 108 C78 116 70 120 64 124 C58 120 50 116 46 108 C42 98 48 86 64 86 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M64 94 C72 94 76 100 74 106 C72 110 68 113 64 115 C60 113 56 110 54 106 C52 100 56 94 64 94 Z" fill="url(#gem)" {S2}/>'),
        ("b", '<path d="M58 99 C60 97 62 96 64 96" stroke="#fff" stroke-width="2" fill="none"/>'),
    ])


def ring():
    return Icon("eq/ring", [
        ("m", f'<ellipse cx="64" cy="76" rx="34" ry="30" fill="none" stroke="{OUT}" stroke-width="16"/>'),
        ("m", f'<ellipse cx="64" cy="76" rx="34" ry="30" fill="none" stroke="url(#met)" stroke-width="10"/>'),
        ("b", f'<path d="M36 64 C40 52 50 46 60 46" {HL}/>'),
        ("m", f'<path d="M48 44 L80 44 L74 30 L54 30 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M64 8 L80 26 L64 44 L48 26 Z" fill="url(#gem)" {S}/>'),
        ("b", '<path d="M58 18 L64 12 L68 17" stroke="#fff" stroke-width="2" fill="none"/>'),
    ])


def talisman():
    return Icon("eq/talisman", [
        ("b", '<path d="M40 8 C40 30 52 36 64 36 C76 36 88 30 88 8" fill="none" stroke="#c9a45c" stroke-width="3"/>'),
        ("m", f'<circle cx="64" cy="76" r="38" fill="url(#met)" {S}/>'),
        ("b", f'<circle cx="64" cy="76" r="28" fill="#2a2f3a" stroke="{OUT}" stroke-width="2"/>'),
        ("b", f'<path d="M64 54 L70 70 L86 76 L70 82 L64 98 L58 82 L42 76 L58 70 Z" fill="#e8c56a" stroke="{OUT}" stroke-width="2"/>'),
        ("b", f'<circle cx="64" cy="40" r="7" fill="url(#gem)" {S}/>'),
        ("b", f'<path d="M34 64 C38 52 48 44 58 42" {HL}/>'),
    ])


# ---------------------------------------------------------------- heavy armour (warrior, cleric)
def helmet_heavy():
    return Icon("eq/helmet_heavy", [
        ("m", f'<path d="M28 60 C28 28 44 14 64 14 C84 14 100 28 100 60 L100 104 C90 112 76 114 64 114 C52 114 38 112 28 104 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M64 14 L64 114" stroke="{OUT}" stroke-width="2" stroke-opacity=".6"/>'),
        ("b", f'<rect x="34" y="58" width="60" height="7" rx="3" fill="{OUT}"/>'),
        ("b", f'<path d="M52 76 L52 98 M60 78 L60 102 M68 78 L68 102 M76 76 L76 98" stroke="{OUT}" stroke-width="3"/>'),
        ("b", f'<path d="M36 50 C38 32 48 22 60 20" {HL}/>'),
        ("b", f'<circle cx="40" cy="96" r="2.5" fill="#e8c56a" stroke="{OUT}" stroke-width="1"/>'),
        ("b", f'<circle cx="88" cy="96" r="2.5" fill="#e8c56a" stroke="{OUT}" stroke-width="1"/>'),
    ])


def armor_heavy():
    return Icon("eq/armor_heavy", [
        ("b", f'<path d="M50 20 C56 28 72 28 78 20 L80 30 L48 30 Z" fill="url(#dark)" {S2}/>'),
        ("m", f'<path d="M36 24 C44 20 52 22 56 30 L72 30 C76 22 84 20 92 24 L98 52 L94 102 C80 114 48 114 34 102 L30 52 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M12 34 C14 22 28 16 40 22 L38 50 C26 50 16 46 12 34 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M116 34 C114 22 100 16 88 22 L90 50 C102 50 112 46 116 34 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M64 32 L64 84" stroke="{OUT}" stroke-opacity=".45" stroke-width="2"/>'),
        ("b", f'<path d="M40 36 C42 52 44 64 50 76" {HL}/>'),
        ("b", f'<path d="M16 32 C20 26 26 23 32 23" {HLs}/>'),
        ("b", f'<path d="M30 84 L98 84 L97 96 L31 96 Z" fill="url(#lea)" {S}/>'),
        ("b", f'<rect x="57" y="82" width="14" height="16" rx="2" fill="url(#gld)" {S2}/>'),
        ("b", f'<path d="M36 104 C48 110 80 110 92 104" stroke="{OUT}" stroke-width="2" fill="none"/>'),
        ("b", ''.join(f'<circle cx="{x}" cy="{y}" r="2.2" fill="#e8c56a" stroke="{OUT}" stroke-width="1"/>'
                      for x, y in [(38, 40), (90, 40), (36, 70), (92, 70), (20, 40), (108, 40)])),
    ])


def gloves_heavy():
    fingers = ""
    for i, x in enumerate([48, 60, 72, 84]):
        top = [24, 16, 18, 26][i]
        fingers += (f'<rect x="{x - 5}" y="{top}" width="11" height="{48 - top}" rx="5" fill="url(#met)" {S}/>')
    return Icon("eq/gloves_heavy", [
        ("m", fingers),
        ("b", "".join(f'<path d="M{x - 5} {y} L{x + 6} {y}" stroke="{OUT}" stroke-width="1.6"/>'
                      for x, y in [(48, 36), (60, 30), (72, 32), (84, 38)])),
        ("m", f'<path d="M30 58 C26 50 28 42 34 40 C40 40 44 46 46 54 L48 66 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M40 44 L92 44 C94 60 92 76 88 88 L44 88 C40 76 38 60 40 44 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M42 58 L90 58 M43 72 L89 72" stroke="{OUT}" stroke-opacity=".6" stroke-width="2"/>'),
        ("m", f'<path d="M40 86 L92 86 L100 120 L32 120 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M38 100 L94 100" stroke="{OUT}" stroke-opacity=".6" stroke-width="2"/>'),
        ("b", f'<path d="M46 50 L46 82" {HL}/>'),
        ("b", ''.join(f'<circle cx="{x}" cy="93" r="2" fill="#e8c56a" stroke="{OUT}" stroke-width="1"/>' for x in (44, 66, 88))),
    ])


def boots_heavy():
    return Icon("eq/boots_heavy", [
        ("m", f'<path d="M30 10 L66 10 L66 70 C66 78 70 82 78 84 L104 90 C112 92 116 98 114 106 L30 106 Z" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M30 30 L66 30 M30 50 L66 50 M66 84 C70 92 70 100 66 106 M84 88 C86 94 86 100 84 106" stroke="{OUT}" stroke-opacity=".6" stroke-width="2" fill="none"/>'),
        ("m", f'<path d="M24 64 C24 56 30 52 36 52 L40 76 L26 76 Z" fill="url(#met)" {S}/>'),
        ("b", f'<rect x="26" y="102" width="92" height="12" rx="4" fill="url(#dark)" {S}/>'),
        ("b", f'<path d="M36 16 L36 96" {HL}/>'),
        ("b", ''.join(f'<circle cx="{x}" cy="{y}" r="2.2" fill="#e8c56a" stroke="{OUT}" stroke-width="1"/>'
                      for x, y in [(60, 20), (60, 40), (60, 60)])),
    ])


# ---------------------------------------------------------------- medium armour (hunter)
def helmet_medium():
    return Icon("eq/helmet_medium", [
        ("b", f'<path d="M64 8 C92 8 108 32 106 62 C104 84 98 104 92 116 L36 116 C30 104 24 84 22 62 C20 32 36 8 64 8 Z" fill="url(#cloG)" {S}/>'),
        ("b", f'<path d="M64 30 C82 30 90 46 88 66 C86 82 78 96 64 98 C50 96 42 82 40 66 C38 46 46 30 64 30 Z" fill="#1a1612" {S}/>'),
        ("b", f'<path d="M30 40 C36 22 50 14 62 12" {HL}/>'),
        *thick("m", "M64 30 C82 30 90 46 88 66 C86 82 78 96 64 98 C50 96 42 82 40 66 C38 46 46 30 64 30 Z", "url(#met)", 10, 5.5),
        ("b", f'<path d="M36 116 C44 106 54 100 64 100 C74 100 84 106 92 116" fill="url(#lea)" {S}/>'),
        ("m", f'<circle cx="64" cy="108" r="7" fill="url(#met)" {S}/>'),
        ("b", '<circle cx="64" cy="108" r="2.5" fill="#16110c" opacity=".55"/>'),
    ])


def armor_medium():
    return Icon("eq/armor_medium", [
        ("b", f'<path d="M40 16 L56 22 C60 30 68 30 72 22 L88 16 L112 34 L102 56 L94 52 L94 112 C80 118 48 118 34 112 L34 52 L26 56 L16 34 Z" fill="url(#lea)" {S}/>'),
        ("b", f'<path d="M64 30 L64 112" stroke="{OUT}" stroke-width="2"/>'),
        ("b", '<path d="M58 40 L70 46 M58 50 L70 56 M58 60 L70 66 M70 40 L58 46 M70 50 L58 56 M70 60 L58 66" stroke="#e7d3a8" stroke-width="1.6"/>'),
        ("m", f'<path d="M18 34 L40 18 L48 28 L28 48 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M110 34 L88 18 L80 28 L100 48 Z" fill="url(#met)" {S}/>'),
        ("b", f'<rect x="34" y="84" width="60" height="9" fill="url(#leaD)" stroke="{OUT}" stroke-width="2"/>'),
        ("m", f'<rect x="57" y="82" width="14" height="13" rx="2" fill="url(#met)" {S2}/>'),
        ("m", ''.join(f'<circle cx="{x}" cy="{y}" r="2.6" fill="url(#met)" stroke="{OUT}" stroke-width="1.2"/>'
                      for x, y in [(42, 60), (42, 72), (86, 60), (86, 72), (44, 104), (84, 104)])),
        ("b", f'<path d="M40 56 L40 80" {HLs}/>'),
    ])


def gloves_medium():
    return Icon("eq/gloves_medium", [
        ("b", f'<path d="M44 20 L86 20 C90 40 90 56 86 66 L44 66 C40 56 40 40 44 20 Z" fill="url(#lea)" {S}/>'),
        ("b", ''.join(f'<rect x="{x}" y="8" width="9" height="16" rx="4" fill="url(#lea)" {S2}/>' for x in (46, 57, 68))),
        ("b", f'<path d="M28 44 C24 36 28 28 34 28 C40 30 42 36 44 42 L44 56 Z" fill="url(#lea)" {S}/>'),
        ("b", f'<path d="M36 64 L94 64 L98 120 L32 120 Z" fill="url(#leaD)" {S}/>'),
        ("m", f'<path d="M38 74 L92 74 L93 86 L37 86 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M35 100 L95 100 L96 112 L34 112 Z" fill="url(#met)" {S}/>'),
        ("b", '<path d="M50 70 L50 118 M80 70 L80 118" stroke="#e7d3a8" stroke-width="1.4" stroke-dasharray="3 3"/>'),
        ("b", f'<path d="M48 26 L48 60" {HLs}/>'),
    ])


def boots_medium():
    return Icon("eq/boots_medium", [
        ("b", f'<path d="M30 18 L62 18 L62 74 C62 80 66 84 74 86 L104 92 C112 94 114 100 112 108 L30 108 Z" fill="url(#lea)" {S}/>'),
        ("b", f'<rect x="28" y="100" width="86" height="12" rx="4" fill="url(#dark)" {S}/>'),
        ("m", f'<rect x="27" y="14" width="38" height="14" rx="3" fill="url(#met)" {S}/>'),
        ("b", f'<path d="M30 46 L62 46" stroke="{OUT}" stroke-width="5"/>'),
        ("m", f'<rect x="40" y="41" width="12" height="10" rx="2" fill="url(#met)" {S2}/>'),
        ("m", f'<path d="M96 90 C108 92 114 98 112 104 L94 104 Z" fill="url(#met)" {S2}/>'),
        ("b", f'<path d="M36 32 L36 96" {HLs}/>'),
    ])


# ---------------------------------------------------------------- light armour (mage, cleric)
def helmet_light():
    return Icon("eq/helmet_light", [
        ("m", f'<ellipse cx="64" cy="74" rx="48" ry="22" fill="none" stroke="{OUT}" stroke-width="14"/>'),
        ("m", f'<ellipse cx="64" cy="74" rx="48" ry="22" fill="none" stroke="url(#metV)" stroke-width="8"/>'),
        ("b", '<path d="M22 70 C30 58 46 52 60 52" stroke="#fff" stroke-opacity=".55" stroke-width="2.5" fill="none"/>'),
        ("m", f'<path d="M64 26 L82 54 L74 96 L64 104 L54 96 L46 54 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M40 60 L48 46 L52 64 Z M88 60 L80 46 L76 64 Z" fill="url(#met)" {S2}/>'),
        ("b", f'<path d="M64 46 L74 62 L64 82 L54 62 Z" fill="url(#gemB)" {S2}/>'),
        ("b", '<path d="M60 56 L64 50 L67 55" stroke="#fff" stroke-width="2" fill="none"/>'),
    ])


def armor_light():
    return Icon("eq/armor_light", [
        ("b", f'<path d="M42 12 L54 16 C58 24 70 24 74 16 L86 12 L114 40 L104 58 L92 50 L98 120 L30 120 L36 50 L24 58 L14 40 Z" fill="url(#cloP)" {S}/>'),
        ("b", f'<path d="M54 16 C58 26 70 26 74 16 L68 40 L64 120 L60 40 Z" fill="#1d1630" {S2}/>'),
        ("m", f'<path d="M54 16 L60 40 L62 120 M74 16 L68 40 L66 120" stroke="{OUT}" stroke-width="7" fill="none"/>'),
        ("m", '<path d="M54 16 L60 40 L62 120 M74 16 L68 40 L66 120" stroke="url(#metV)" stroke-width="3.5" fill="none"/>'),
        ("m", f'<path d="M30 116 L98 116 L98 122 L30 122 Z" fill="url(#met)" {S2}/>'),
        ("m", f'<path d="M14 40 L24 58 L30 54 L19 36 Z M114 40 L104 58 L98 54 L109 36 Z" fill="url(#met)" {S2}/>'),
        ("b", f'<path d="M36 70 L92 70 L92 80 L36 80 Z" fill="url(#leaD)" {S2}/>'),
        ("m", f'<circle cx="64" cy="75" r="6" fill="url(#met)" {S2}/>'),
        ("b", f'<path d="M40 56 L36 112" {HLs}/>'),
    ])


def gloves_light():
    return Icon("eq/gloves_light", [
        ("b", f'<path d="M44 14 C56 8 76 8 86 14 C90 36 90 56 86 70 L44 70 C40 56 40 36 44 14 Z" fill="url(#cloP)" {S}/>'),
        ("b", f'<path d="M30 46 C24 38 28 28 36 28 C42 30 44 38 44 44 L44 58 Z" fill="url(#cloP)" {S}/>'),
        ("b", '<path d="M56 16 L56 40 M66 14 L66 40 M76 16 L76 40" stroke="#16110c" stroke-opacity=".45" stroke-width="2"/>'),
        ("b", f'<path d="M38 68 L92 68 L100 118 L30 118 Z" fill="url(#cloP)" {S}/>'),
        ("m", f'<path d="M37 64 L93 64 L94 76 L36 76 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M31 110 L99 110 L100 120 L30 120 Z" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M64 84 L72 92 L64 100 L56 92 Z" fill="url(#met)" {S2}/>'),
        ("b", f'<circle cx="64" cy="92" r="3" fill="url(#gemB)" {S2}/>'),
        ("b", f'<path d="M48 20 L48 60" {HLs}/>'),
    ])


def boots_light():
    return Icon("eq/boots_light", [
        ("b", f'<path d="M34 20 L62 20 L62 72 C62 80 68 84 78 86 L106 94 C114 96 114 106 106 108 L34 108 Z" fill="url(#cloP)" {S}/>'),
        ("b", f'<rect x="32" y="102" width="80" height="9" rx="4" fill="url(#lea)" {S}/>'),
        ("m", f'<rect x="31" y="16" width="34" height="11" rx="3" fill="url(#met)" {S}/>'),
        ("m", f'<path d="M62 70 C70 80 84 84 98 86" stroke="{OUT}" stroke-width="7" fill="none"/>'),
        ("m", '<path d="M62 70 C70 80 84 84 98 86" stroke="url(#met)" stroke-width="3.5" fill="none"/>'),
        ("b", '<path d="M38 40 L60 40 M38 56 L60 56" stroke="#16110c" stroke-opacity=".45" stroke-width="2"/>'),
        ("m", f'<path d="M48 30 L52 36 L48 42 L44 36 Z" fill="url(#met)" {S2}/>'),
        ("b", f'<path d="M40 30 L40 96" {HLs}/>'),
    ])


ALL = [sword1h, axe1h, mace1h, saber1h, sword2h, axe2h, hammer2h, spear2h,
       shortbow, bow, longbow, crossbow, heavycrossbow, wand, staff, runestaff,
       scepter, flail1h, holystaff, shield, quiver, tome, orb, relic, necklace, ring, talisman,
       helmet_heavy, armor_heavy, gloves_heavy, boots_heavy,
       helmet_medium, armor_medium, gloves_medium, boots_medium,
       helmet_light, armor_light, gloves_light, boots_light]


def icons():
    return [f() for f in ALL]
