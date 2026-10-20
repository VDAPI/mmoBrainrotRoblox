"""Runs clip_extra.py for every biped monster and merges the new frames and slots into Data/MonsterClips/<id>.luau."""
import base64, json, os, re, subprocess, sys

S = os.path.dirname(os.path.abspath(__file__))
REPO = 'D:/Dev/mmoBrainrotRoblox-wyglad/'
DL = 'D:/Users/vdapi/Downloads/'
MAG = DL + 'Magic Spell Pack/'
PY = 'D:/Dev/cache/python313/python.exe'
C = {
    'SS': DL + 'Sword And Shield Slash.fbx', 'SS1': DL + 'Sword And Shield Slash (1).fbx',
    'GS': DL + 'Great Sword Slash.fbx', 'GS1': DL + 'Great Sword Slash (1).fbx', 'GS2': DL + 'Great Sword Slash (2).fbx',
    'MP': DL + 'Mutant Punch.fbx', 'MH': DL + 'Standing Melee Attack Horizontal.fbx',
    'M1': MAG + 'Standing 2H Magic Attack 01.fbx', 'M1h': MAG + 'Standing 1H Magic Attack 01.fbx',
    'CAST': MAG + 'Standing 2H Cast Spell 01.fbx', 'AREA': MAG + 'Standing 2H Magic Area Attack 01.fbx',
    'HIT': DL + 'HitReaction.fbx',
}
PLAN = {
    'bandit': ('SS', 'SS1', None), 'skeletonGuard': ('SS', 'SS1', None), 'frozenKnight': ('GS', 'SS', None),
    'dragonspawn': ('SS', 'GS1', None), 'ashOrc': ('GS', 'GS1', None), 'frostGiant': ('GS1', 'MP', None),
    'hrimvald': ('GS', 'GS2', 'AREA'), 'grimrok': ('GS', 'GS2', 'GS1'), 'flameSmith': ('GS2', 'MP', None),
    'fireGolem': ('MP', 'MH', None), 'magmaGolem': ('MP', 'MH', None), 'crystalGuardian': ('MP', 'MH', None),
    'azgor': ('MP', 'GS', 'AREA'), 'swampTroll': ('MP', 'MH', None), 'yeti': ('MP', 'MH', None),
    'werewolf': ('MP', 'MH', None), 'desertMummy': ('MP', 'MH', None), 'renegadeDwarf': ('MH', 'SS', None),
    'koboldMiner': ('MH', 'SS', None), 'goblinScout': ('MH', 'SS', None), 'fireImp': ('MH', 'M1h', 'M1h'),
    'necromancer': ('M1h', 'M1', 'CAST'), 'goblinShaman': ('M1h', 'M1', 'CAST'), 'marshWitch': ('M1h', 'M1', 'CAST'),
    'darkCultist': ('M1h', 'M1', 'CAST'), 'morvane': ('M1', 'AREA', 'CAST'), 'forestWraith': ('M1h', 'M1', 'CAST'),
}
B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

only = sys.argv[1:]
os.makedirs(S + '/extra', exist_ok=True)
for mid, (a1, a2, cast) in PLAN.items():
    if only and mid not in only:
        continue
    path = REPO + 'src/shared/Data/MonsterClips/%s.luau' % mid
    src = open(path, encoding='utf-8').read()
    bones = re.findall(r'"(\w+)",', src.split('frames =')[0])
    frames0 = int(re.search(r'frames = (\d+)', src).group(1))
    args = ['attack1=' + C[a1], 'attack2=' + C[a2], 'hit=' + C['HIT']]
    if cast:
        args.append('cast=' + C[cast])
    out = S + '/extra/%s.json' % mid
    code = ("import bpy,sys; sys.argv=['x','--',%r,%r,%r] + %r; exec(open(%r).read())"
            % (DL + 'monsters_ready/%s.fbx' % mid, out, ','.join(bones), args, S + '/clip_extra.py'))
    r = subprocess.run([PY, '-c', code], capture_output=True, text=True, encoding='utf-8', errors='replace')
    line = [l for l in r.stdout.splitlines() if l.startswith('EXTRA')]
    if not line:
        print('FAIL', mid, r.stdout[-800:], r.stderr[-800:])
        continue
    extra = json.load(open(out))
    # merge: the old frames (only the first frames0, a rerun replaces the earlier extra), then the new ones
    old = base64.b64decode(re.search(r'data = "([^"]*)"', src).group(1))
    stride = len(bones) * 6 + 6
    old = old[:frames0 * stride] if '-- extra' not in src else old[:int(re.search(r'base = (\d+)', src).group(1)) * stride]
    base = len(old) // stride
    new = base64.b64decode(extra['data'])
    data = base64.b64encode(old + new).decode()
    slots = []
    for name in ('attack1', 'attack2', 'cast', 'hit'):
        sl = extra['slots'].get(name)
        if not sl:
            continue
        rate = 1.3 if name == 'hit' else 1
        slots.append('\t\t%s = { from = %d, to = %d, rate = %s, hit = %s },' % (name, base + sl['from'], base + sl['to'], rate, sl['hit']))
    names = ', '.join('"%s"' % b for b in bones)
    head = src.split('return {')[0]
    head = head.replace('from its imported KeyframeSequence.', 'from its imported KeyframeSequence (idle, walk, run, the old attack, death);\n-- extra: the weapon attacks, the spell and the hit (Mixamo, retargeted in Blender, tools/... see SESJE-W W26).')
    text = (head + 'return {\n\tbones = {\n' + ''.join('\t\t"%s",\n' % b for b in bones) + '\t},\n'
            + '\tframes = %d,\n' % (base + extra['frames'])
            + '\tbase = %d, -- extra: frames before the extra clips\n' % base
            + '\tslots = {\n' + '\n'.join(slots) + '\n\t},\n'
            + '\tdata = "%s",\n}\n' % data)
    open(path, 'w', encoding='utf-8', newline='\n').write(text)
    print('OK', mid, base, extra['frames'], extra['slots'])
