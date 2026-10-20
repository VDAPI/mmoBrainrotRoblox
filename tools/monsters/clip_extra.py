"""Retargets extra Mixamo clips onto a built monster FBX and writes Roblox bone-clip frames (W26).

python clip_extra.py -- <built.fbx> <out.json> <bone list comma> slot=path [slot=path ...]

Frames: every 2nd source frame (15 fps), per bone the Roblox Bone.Transform rotation (x, y, z of the quaternion with
w >= 0; Blender matrix_basis maps to Roblox as (-x, y, -z), checked against the Studio import) and the Hips offset
(-x, y, -z) * 100. `hit` = seconds from the clip start to the fastest hand (the blow).
"""
import bpy, sys, os, json, base64, struct, mathutils
argv = sys.argv[sys.argv.index('--') + 1:]
src_fbx, out_json, bone_list = argv[0], argv[1], argv[2].split(',')
clips = [a.split('=', 1) for a in argv[3:]]
mid = os.path.splitext(os.path.basename(src_fbx))[0]


def clear():
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials,
                 bpy.data.images):
        for x in list(coll):
            coll.remove(x)


def imp(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    return [o for o in bpy.data.objects if o not in before]


clear()
objs = imp(src_fbx)
arm = next(o for o in objs if o.type == 'ARMATURE')
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
if arm.animation_data:
    arm.animation_data.action = None
ranges = {}
if True:
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

# sample
bones = ['mixamorig:' + b for b in bone_list]
frames = []
hits = {}
scene = bpy.context.scene
for name, (a, b) in ranges.items():
    first = len(frames)
    prev = None
    best, best_t = -1, 0
    for f in range(a, b + 1, 2):
        scene.frame_set(f)
        row = []
        for bn in bones:
            pb = arm.pose.bones.get(bn)
            q = pb.matrix_basis.to_quaternion() if pb else mathutils.Quaternion()
            if q.w < 0:
                q = -q
            row.append((-q.x, q.y, -q.z))
        hp = arm.pose.bones.get('mixamorig:Hips')
        loc = hp.location if hp else mathutils.Vector()
        row.append((-loc.x, loc.y, -loc.z))
        frames.append(row)
        hands = []
        for hn in ('mixamorig:RightHand', 'mixamorig:LeftHand'):
            pb = arm.pose.bones.get(hn)
            if pb:
                hands.append(arm.matrix_world @ pb.head)
        if prev is not None and hands:
            speed = max((h - p).length for h, p in zip(hands, prev))
            if speed > best:
                best, best_t = speed, (f - a) / 30.0
        prev = hands
    hits[name] = {'from': first, 'to': len(frames) - 1, 'hit': round(best_t, 3)}
buf = bytearray()
for row in frames:
    for i, v in enumerate(row):
        if i < len(bones):
            for c in v:
                buf += struct.pack('<h', max(-32767, min(32767, round(c * 32767))))
        else:
            for c in v:
                buf += struct.pack('<h', max(-32767, min(32767, round(c * 100))))
json.dump({'id': mid, 'frames': len(frames), 'slots': hits, 'data': base64.b64encode(bytes(buf)).decode()},
          open(out_json, 'w'))
print('EXTRA', mid, len(frames), hits)

render_to = os.environ.get('CLIP_RENDER')
if render_to:
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'TEXTURE'
    sc.render.resolution_x = sc.render.resolution_y = 260
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    for name, (a, b) in ranges.items():
        f = a + int(hits[name]['hit'] * 30)
        sc.frame_set(f)
        mn = mathutils.Vector((1e9,) * 3); mx = -mn
        for m in meshes:
            for c in m.bound_box:
                w = m.matrix_world @ mathutils.Vector(c)
                mn = mathutils.Vector(map(min, mn, w)); mx = mathutils.Vector(map(max, mx, w))
        ce = (mn + mx) / 2; size = (mx - mn).length
        cam.location = ce + mathutils.Vector((0.7, -1, 0.3)).normalized() * size * 1.5
        cam.rotation_euler = (ce - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = render_to + '_' + name + '.png'
        bpy.ops.render.render(write_still=True)
