"""Renders frames of a built monster FBX: python monster_render.py <in.fbx> <out_prefix> frame [frame ...]"""
import bpy, sys, math, mathutils

argv = sys.argv[1:]
src, prefix, frames = argv[0], argv[1], [int(f) for f in argv[2:]]
for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials,
             bpy.data.cameras, bpy.data.lights):
    for x in list(coll):
        coll.remove(x)
bpy.ops.import_scene.fbx(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x = 480
scene.render.resolution_y = 480
scene.frame_set(frames[0])
mn = mathutils.Vector((1e9,) * 3)
mx = mathutils.Vector((-1e9,) * 3)
for m in meshes:
    for c in m.bound_box:
        w = m.matrix_world @ mathutils.Vector(c)
        mn = mathutils.Vector(map(min, mn, w))
        mx = mathutils.Vector(map(max, mx, w))
centre = (mn + mx) / 2
size = (mx - mn).length
cam_data = bpy.data.cameras.new('cam')
cam = bpy.data.objects.new('cam', cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = centre + mathutils.Vector((size * 1.1, -size * 1.6, size * 0.5))
direction = centre - cam.location
cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
for f in frames:
    scene.frame_set(f)
    scene.render.filepath = f'{prefix}_{f}.png'
    bpy.ops.render.render(write_still=True)
print('RENDERED', frames, [round(v, 2) for v in (mx - mn)])
