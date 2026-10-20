"""Builds one game-ready monster FBX from a Tripo model (W25/W26).

python monster_build.py <model.fbx|glb> <out_dir> <id> [maxTris] [clip=path ...]

* clears the scene, imports the model, drops its own (merged) Tripo animation,
* for a Mixamo-boned rig: appends the given Mixamo clips one after another on ONE action (in place: the hips' forward
  drift removed, the bob kept), and writes <id>.clips.json with each clip's frame range (30 fps),
* decimates meshes over maxTris (default 12000),
* exports <out_dir>/<id>.fbx with the texture embedded.
"""
import bpy, sys, os, json

argv = sys.argv[1:]
src, out_dir, mid = argv[0], argv[1], argv[2]
max_tris = int(argv[3]) if len(argv) > 3 and argv[3].isdigit() else 12000
clips = [a.split('=', 1) for a in argv[3:] if '=' in a]


def clear():
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials,
                 bpy.data.images):
        for x in list(coll):
            coll.remove(x)


def imp(path):
    before = set(bpy.data.objects)
    if path.lower().endswith('.fbx'):
        bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


clear()
objs = imp(src)
arm = next((o for o in objs if o.type == 'ARMATURE'), None)
meshes = [o for o in objs if o.type == 'MESH']
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
if arm and arm.animation_data:
    arm.animation_data.action = None

ranges = {}
if arm and clips and any(b.name.startswith('mixamorig') for b in arm.data.bones):
    import mathutils
    combined = bpy.data.actions.new(mid + '_clips')
    arm.animation_data_create()
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    Ot = arm.matrix_world.to_quaternion()
    tb = arm.data.bones
    # armature-space rest rotations and the order parents-first
    order = [b for b in tb]  # Blender lists bones parents before children
    rest_q = {b.name: b.matrix_local.to_quaternion() for b in tb}
    keys = {}  # (bone, kind) -> list of (frame, value tuple)
    cursor = 0
    hips_name = 'mixamorig:Hips'
    t_hips = tb.get(hips_name)
    for name, path in clips:
        got = imp(path)
        sarm = next((o for o in got if o.type == 'ARMATURE'), None)
        act = sarm.animation_data.action if sarm and sarm.animation_data else None
        if not act:
            for o in got:
                bpy.data.objects.remove(o, do_unlink=True)
            continue
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        Os = sarm.matrix_world
        Osq = Os.to_quaternion()
        sb = sarm.data.bones
        s_hips = sb.get(hips_name)
        # leg length ratio (rest hip height above the lowest bone) target / source, both in world units
        def hip_h(armobj, bones):
            hw = (armobj.matrix_world @ bones[hips_name].head_local)
            low = min((armobj.matrix_world @ b.head_local).z for b in bones)
            return max(1e-6, hw.z - low)
        def hip_h_posed(armobj):
            bpy.context.scene.frame_set(f0)
            hw = armobj.matrix_world @ armobj.pose.bones[hips_name].head
            low = min((armobj.matrix_world @ pb.head).z for pb in armobj.pose.bones)
            return max(1e-6, hw.z - low)
        ratio = hip_h(arm, tb) / hip_h_posed(sarm) if s_hips and t_hips else 1.0
        rest_head_s = None
        if s_hips:
            bpy.context.scene.frame_set(f0)
            rest_head_s = (Os @ sarm.pose.bones[hips_name].head).copy()
        # some clips (uploaded with a character lying down) carry a constant tilt: turn the whole clip so the
        # spine of its first frame points straight up
        corr = mathutils.Quaternion()
        spine = sb.get('mixamorig:Spine2') or sb.get('mixamorig:Spine1') or sb.get('mixamorig:Spine')
        if s_hips and spine:
            # the REST skeleton of a clip may lie down (uploaded character): stand it up
            v = (Os @ spine.head_local) - (Os @ s_hips.head_local)
            if v.length > 1e-6:
                corr = v.normalized().rotation_difference(mathutils.Vector((0, 0, 1)))
        samples = []
        for f in range(f0, f1 + 1):
            bpy.context.scene.frame_set(f)
            world = {}
            for b in order:
                spb = sarm.pose.bones.get(b.name)
                if spb is None:
                    continue
                d = (Osq @ spb.matrix.to_quaternion()) @ (corr @ Osq @ sb[b.name].matrix_local.to_quaternion()).inverted()
                world[b.name] = d @ (Ot @ rest_q[b.name])
            hip_d = None
            if s_hips:
                hip_d = (Os @ sarm.pose.bones[hips_name].head) - rest_head_s
            samples.append((f, world, hip_d))
        # in place: remove the straight horizontal drift of the hips between the first and the last frame
        if samples and samples[0][2] is not None:
            first, last = samples[0][2], samples[-1][2]
            n = max(1, len(samples) - 1)
        for i, (f, world, hip_d) in enumerate(samples):
            fr = f - f0 + cursor
            arm_q = {k: Ot.inverted() @ v for k, v in world.items()}
            for b in order:
                if b.name not in arm_q:
                    continue
                M = arm_q[b.name]
                if b.parent and b.parent.name in arm_q:
                    rel = rest_q[b.parent.name].inverted() @ rest_q[b.name]
                    basis = rel.inverted() @ arm_q[b.parent.name].inverted() @ M
                elif b.parent:
                    basis = rest_q[b.name].inverted() @ M
                else:
                    basis = rest_q[b.name].inverted() @ M
                keys.setdefault((b.name, 'rot'), []).append((fr, tuple(basis)))
            if hip_d is not None and t_hips is not None:
                t = i / n
                drift = first.lerp(last, t)
                d = hip_d - mathutils.Vector((drift.x, drift.y, 0))
                d = d * ratio
                d_arm = Ot.inverted() @ d
                loc = rest_q[hips_name].inverted() @ d_arm
                keys.setdefault((hips_name, 'loc'), []).append((fr, tuple(loc)))
        ranges[name] = [cursor, cursor + (f1 - f0)]
        cursor += (f1 - f0) + 10
        for o in got:
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.actions.remove(act)
    arm.animation_data.action = combined
    for (bone, kind), pts in keys.items():
        path = f'pose.bones["{bone}"].' + ('rotation_quaternion' if kind == 'rot' else 'location')
        width = 4 if kind == 'rot' else 3
        if kind == 'rot':
            prev = None
            fixed = []
            for fr, q in pts:
                q = mathutils.Quaternion(q)
                if prev is not None and prev.dot(q) < 0:
                    q = -q
                prev = q
                fixed.append((fr, tuple(q)))
            pts = fixed
        for idx in range(width):
            fc = combined.fcurve_ensure_for_datablock(arm, path, index=idx)
            fc.keyframe_points.add(len(pts))
            for i, (fr, v) in enumerate(pts):
                fc.keyframe_points[i].co = (fr, v[idx])
                fc.keyframe_points[i].interpolation = 'LINEAR'
            fc.update()
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = int(cursor)
    bpy.context.scene.render.fps = 30

# decimate heavy meshes
total = sum(sum(len(p.vertices) - 2 for p in m.data.polygons) for m in meshes)
if total > max_tris:
    r = max_tris / total
    for m in meshes:
        mod = m.modifiers.new('dec', 'DECIMATE')
        mod.ratio = r
        bpy.context.view_layer.objects.active = m
        bpy.ops.object.modifier_apply(modifier=mod.name)

for img in bpy.data.images:
    try:
        img.pack()
    except Exception:
        pass

os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, mid + '.fbx')
bpy.ops.export_scene.fbx(
    filepath=out,
    path_mode='COPY',
    embed_textures=True,
    add_leaf_bones=False,
    bake_anim=bool(ranges),
    bake_anim_use_all_actions=False,
    bake_anim_use_nla_strips=False,
    bake_anim_force_startend_keying=True,
    bake_anim_simplify_factor=0.5,
)
after = sum(sum(len(p.vertices) - 2 for p in m.data.polygons) for m in meshes)
json.dump({'id': mid, 'clips': ranges, 'fps': 30, 'tris': after, 'bones': len(arm.data.bones) if arm else 0},
          open(os.path.join(out_dir, mid + '.clips.json'), 'w'), indent=1)
print('BUILT', out, after, ranges)
