"""Assembles the city's houses from the CC0 Quaternius Medieval Village MegaKit (modular glTF pieces on a 2 x 3 m grid)
into one mesh each and exports FBX for Assets.Kit.city (Data/Kit `house:*` slots: the front faces -Z in Roblox).

python -c "import bpy, sys; sys.argv=['x', '<kit glTF dir>', '<out_dir>']; exec(open('tools/kit/build_houses.py').read())"

A house: W x D studs of plan (multiples of 2, W along the front), `floors` storeys of 3, the ground floor in uneven brick
with a round door in the middle of the front, upper floors in plaster with timber or windows, wooden corner posts, a
round-tile roof W x D with brick gables, a chimney. The kit's outer face of a wall is -Y.
"""
import bpy, sys, os, math, mathutils

argv = sys.argv[1:]
KIT, OUT = argv[0], argv[1]
os.makedirs(OUT, exist_ok=True)
STOREY = 3.0

HOUSES = {
    'city_cottage_01': dict(w=4, d=6, floors=1, ground='brick', upper='plaster', seed=1),
    'city_house_01': dict(w=6, d=8, floors=3, ground='brick', upper='grid', seed=2),
    'city_house_02': dict(w=6, d=8, floors=2, ground='brick', upper='plaster', seed=3),
    'city_house_03': dict(w=4, d=8, floors=2, ground='plaster', upper='grid', seed=4),
    'city_workshop_01': dict(w=8, d=8, floors=1, ground='brick', upper='brick', seed=5, wide=True),
    'city_house_04': dict(w=8, d=10, floors=3, ground='brick', upper='plaster', seed=6),
}

cache = {}


def clear():
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for x in list(coll):
            coll.remove(x)
    cache.clear()


def piece(name, x, y, z, rot=0.0):
    """Places a copy of kit piece `name` at (x, y, z) turned `rot` degrees about Z."""
    if name not in cache:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(KIT, name + '.gltf'))
        got = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
        for o in bpy.data.objects:
            if o not in before and o.type != 'MESH':
                bpy.data.objects.remove(o, do_unlink=True)
        for o in got:
            o.hide_set(True)
            o.hide_render = True
        cache[name] = got
    out = []
    for src in cache[name]:
        o = src.copy()
        o.data = src.data
        bpy.context.scene.collection.objects.link(o)
        o.hide_set(False)
        o.hide_render = False
        m = mathutils.Matrix.Translation((x, y, z)) @ mathutils.Matrix.Rotation(math.radians(rot), 4, 'Z')
        o.matrix_world = m @ src.matrix_world
        out.append(o)
    return out


def wall_name(style, kind, rnd):
    if style == 'brick':
        base = 'Wall_UnevenBrick_'
        windows = ['Window_Wide_Round', 'Window_Thin_Round', 'Window_Wide_Flat']
    else:
        base = 'Wall_Plaster_'
        windows = ['Window_Wide_Round', 'Window_Thin_Round', 'Window_Wide_Flat']
    if kind == 'door':
        return base + 'Door_Round', None
    if kind == 'window':
        w = windows[rnd % len(windows)]
        glass = {'Window_Wide_Round': 'Window_Wide_Round1', 'Window_Thin_Round': 'Window_Thin_Round1',
                 'Window_Wide_Flat': 'Window_Wide_Flat1'}[w]
        return base + w, glass
    if style == 'grid':
        return 'Wall_Plaster_WoodGrid', None
    return base + 'Straight', None


def side(walls, n, x0, y0, dx, dy, rot, z, style, door_at, rnd):
    """`n` wall modules from (x0, y0) along (dx, dy), outer face turned by `rot`."""
    for i in range(n):
        x = x0 + dx * (2 * i + 1)
        y = y0 + dy * (2 * i + 1)
        if door_at is not None and i == door_at:
            kind = 'door'
        elif (i + rnd) % 2 == 0 or n <= 2:
            kind = 'window'
        else:
            kind = 'wall'
        name, glass = wall_name(style, kind, rnd + i)
        piece(name, x, y, z, rot)
        if glass:
            piece(glass, x, y, z, rot)
        if kind == 'door':
            piece('Door_1_Round', x, y, z, rot)


def house(name, w, d, floors, ground, upper, seed, wide=False):
    clear()
    hw, hd = w / 2, d / 2
    nx, ny = w // 2, d // 2
    for f in range(floors):
        z = f * STOREY
        style = ground if f == 0 else ('grid' if upper == 'grid' and f % 2 == 1 else ('brick' if upper == 'brick' else 'plaster'))
        rnd = seed + f
        door = nx // 2 if f == 0 else None
        # front (-Y), back (+Y), left (-X), right (+X)
        side(None, nx, -hw, -hd, 1, 0, 0, z, style, door, rnd)
        side(None, nx, hw, hd, -1, 0, 180, z, style, None, rnd + 1)
        side(None, ny, -hw, hd, 0, -1, -90, z, style, None, rnd + 2)
        side(None, ny, hw, -hd, 0, 1, 90, z, style, None, rnd + 3)
        post = 'Corner_Exterior_Brick' if style == 'brick' else 'Corner_Exterior_Wood'
        for cx, cy, r in ((-hw, -hd, 0), (hw, -hd, 90), (hw, hd, 180), (-hw, hd, -90)):
            piece(post, cx, cy, z, r)
        if f > 0:
            for i in range(nx):
                piece('Wall_BottomCover', -hw + 2 * i + 1, -hd, z, 0)
    top = floors * STOREY
    piece(f'Roof_RoundTiles_{w}x{d}', 0, 0, top, 0)
    piece(f'Roof_Front_Brick{w}', 0, -hd, top, 0)
    piece(f'Roof_Front_Brick{w}', 0, hd, top, 180)
    piece('Prop_Chimney', hw * 0.45, hd * 0.4, top + 0.6, 0)
    # one mesh: realise the copies, join them
    objs = [o for o in bpy.context.scene.collection.objects if o.type == 'MESH' and not o.hide_render]
    for o in bpy.data.objects:
        o.select_set(False)
    for o in objs:
        o.data = o.data.copy()
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    for coll in cache.values():
        for src in coll:
            bpy.data.objects.remove(src, do_unlink=True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    vs = [v.co for v in obj.data.vertices]
    lo = mathutils.Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = mathutils.Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    shift = mathutils.Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in obj.data.vertices:
        v.co -= shift
    obj.name = name
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, name + '.fbx'),
        path_mode='COPY',
        embed_textures=True,
        apply_scale_options='FBX_SCALE_ALL',
        axis_forward='-Z',
        axis_up='Y',
    )
    print('HOUSE', name, len(obj.data.polygons), [round(x, 2) for x in (hi - lo)])


only = set(argv[2:])
for name, spec in HOUSES.items():
    if only and name not in only:
        continue
    house(name, **spec)
