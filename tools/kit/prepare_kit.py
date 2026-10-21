"""Prepares CC0 Quaternius models (glTF) for the asset kit (Data/Kit, Assets.Kit): one joined mesh per model, the
base at the origin, the front towards -Y in Blender (-Z in Roblox), exported as FBX with the textures embedded.

python -c "import bpy, sys; sys.argv=['x', '<out_dir>', 'name=path.gltf', ...]; exec(open('tools/kit/prepare_kit.py').read())"

Each `name=path` writes <out_dir>/<name>.fbx (the name is the Assets.Kit model name, e.g. forest_deadtree_01).
"""
import bpy, sys, os

argv = sys.argv[1:]
out_dir = argv[0]
jobs = [a.split('=', 1) for a in argv[1:]]
os.makedirs(out_dir, exist_ok=True)


def clear():
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.armatures):
        for x in list(coll):
            coll.remove(x)


for name, path in jobs:
    clear()
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in bpy.data.objects:
        o.select_set(o.type == 'MESH')
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # the base centre at the origin
    import mathutils
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = mathutils.Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = mathutils.Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    shift = mathutils.Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in obj.data.vertices:
        v.co -= shift
    obj.name = name
    obj.data.name = name
    out = os.path.join(out_dir, name + '.fbx')
    bpy.ops.export_scene.fbx(
        filepath=out,
        use_selection=False,
        path_mode='COPY',
        embed_textures=True,
        apply_scale_options='FBX_SCALE_ALL',
        axis_forward='-Z',
        axis_up='Y',
    )
    print('KIT', name, len(obj.data.polygons), [round(x, 2) for x in (hi - lo)])
