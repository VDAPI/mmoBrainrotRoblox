"""
Bakes Mixamo FBX clips (any Mixamo skeleton, 30 fps, "In Place") into src/shared/Data/BipedClips/<name>.luau for the
template biped animation (Logic/BipedClip, Logic/BipedMotion; docs/ANIM-WZORCE.md).

    py -3 tools/anim/bake_biped.py CLIP.fbx NAME [--loop] [--hit SECONDS] [--start S] [--end S]
    py -3 tools/anim/bake_biped.py --batch tools/anim/clips.csv

Needs Python with the `bpy` module (Blender as a library) and numpy.

What is stored, per frame and per bone: the bone's WORLD turn relative to the clip's own rest pose, D(t) =
R(t) * R_rest^-1, in Roblox axes (up +Y, front -Z), as an int16 unit quaternion (x, y, z with w >= 0); then the Hips
offset from its rest position in units of the clip's hip height (x1000). Also the rest direction of every bone (to its
child joint), so the runtime can first turn the model's bone onto the clip's rest direction (A-pose vs T-pose) and then
apply D(t): W = D(t) * fromTo(modelRestDir, clipRestDir). Locomotion clips also get `speed` (ground speed of a planted
foot in hip heights per second, for stride-matched playback) and `contact` (the phase at which the left foot plants).
"""
import sys, os, math, argparse, base64, struct, csv
import numpy as np

# Blender (Z up, the character faces -Y) -> Roblox (Y up, faces -Z)
M = np.array([[-1.0, 0, 0], [0, 0, 1.0], [0, 1.0, 0]])

BONES = [
    "Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
    "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
    "RightShoulder", "RightArm", "RightForeArm", "RightHand",
    "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
    "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
]
CHILD = {
    "Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head", "Head": "HeadTop_End",
    "LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "LeftHand": "LeftHandMiddle1",
    "RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
    "RightHand": "RightHandMiddle1",
    "LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase", "LeftToeBase": "LeftToe_End",
    "RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase", "RightToeBase": "RightToe_End",
}
FPS = 30
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(REPO, "src", "shared", "Data", "BipedClips")


def ortho(R):
    u, _, vt = np.linalg.svd(R)
    R = u @ vt
    if np.linalg.det(R) < 0:
        R = -R
    return R


def find_bone(arm, name):
    for b in arm.data.bones:
        n = b.name
        if n == name or n.endswith(":" + name) or n.endswith("_" + name) or n == "mixamorig" + name:
            return b.name
    return None


def quat(R):
    """Unit quaternion (x, y, z, w) of a rotation matrix, w >= 0."""
    t = np.trace(R)
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        w = 0.25 * s
        x = (R[2, 1] - R[1, 2]) / s
        y = (R[0, 2] - R[2, 0]) / s
        z = (R[1, 0] - R[0, 1]) / s
    elif R[0, 0] > R[1, 1] and R[0, 0] > R[2, 2]:
        s = math.sqrt(1.0 + R[0, 0] - R[1, 1] - R[2, 2]) * 2
        w = (R[2, 1] - R[1, 2]) / s
        x = 0.25 * s
        y = (R[0, 1] + R[1, 0]) / s
        z = (R[0, 2] + R[2, 0]) / s
    elif R[1, 1] > R[2, 2]:
        s = math.sqrt(1.0 + R[1, 1] - R[0, 0] - R[2, 2]) * 2
        w = (R[0, 2] - R[2, 0]) / s
        x = (R[0, 1] + R[1, 0]) / s
        y = 0.25 * s
        z = (R[1, 2] + R[2, 1]) / s
    else:
        s = math.sqrt(1.0 + R[2, 2] - R[0, 0] - R[1, 1]) * 2
        w = (R[1, 0] - R[0, 1]) / s
        x = (R[0, 2] + R[2, 0]) / s
        y = (R[1, 2] + R[2, 1]) / s
        z = 0.25 * s
    q = np.array([x, y, z, w])
    q /= np.linalg.norm(q)
    if q[3] < 0:
        q = -q
    return q


def sample(path, start=None, end=None):
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if not arms:
        raise SystemExit(f"{path}: no skeleton")
    arm = arms[0]
    act = arm.animation_data.action if arm.animation_data else None
    if act is None:
        raise SystemExit(f"{path}: no animation")
    scene = bpy.context.scene
    f0, f1 = act.frame_range[0], act.frame_range[1]
    src_fps = scene.render.fps / scene.render.fps_base
    names = {}
    for key in BONES + list(CHILD.values()):
        if key not in names:
            names[key] = find_bone(arm, key)
    missing = [k for k in BONES if not names.get(k)]
    if missing:
        raise SystemExit(f"{path}: missing Mixamo bones {missing}")
    mw = np.array(arm.matrix_world)

    def world_of(bone_name):
        m = mw @ np.array(arm.pose.bones[bone_name].matrix)
        return M @ ortho(m[:3, :3]) @ M.T, M @ m[:3, 3]

    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    rest = {k: world_of(v) for k, v in names.items() if v}
    arm.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    # a rest pose lying down is stood up rigidly: the spine up, the left hip on the left (-X)
    up = rest["Head"][1] - rest["Hips"][1]
    side = rest["LeftUpLeg"][1] - rest["RightUpLeg"][1]

    def basis(u, s_):
        u = u / np.linalg.norm(u)
        s_ = s_ - u * np.dot(s_, u)
        s_ = s_ / np.linalg.norm(s_)
        return np.column_stack([s_, u, np.cross(s_, u)])

    Q = basis(np.array([0, 1.0, 0]), np.array([-1.0, 0, 0])) @ basis(up, side).T
    rest = {k: (Q @ R, Q @ p) for k, (R, p) in rest.items()}
    a = (start * src_fps + f0) if start is not None else f0
    b = (end * src_fps + f0) if end is not None else f1
    frames = []
    f = float(a)
    step = src_fps / FPS
    while f <= b + 1e-6:
        scene.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
        cur = {}
        for k, v in names.items():
            if v:
                R, p = world_of(v)
                cur[k] = (Q @ R, Q @ p)
        frames.append(cur)
        f += step
    return rest, frames


def bake(path, name, loop=False, hit=None, start=None, end=None):
    rest, frames = sample(path, start, end)
    ground = min(rest["LeftToeBase"][1][1], rest["RightToeBase"][1][1], rest["LeftFoot"][1][1], rest["RightFoot"][1][1])
    hip_h = max(1e-6, (rest["LeftUpLeg"][1][1] + rest["RightUpLeg"][1][1]) / 2 - ground)
    hips0 = rest["Hips"][1]
    dirs = {}
    for k in BONES:
        child = CHILD.get(k)
        if child in rest:
            d = rest[child][1] - rest[k][1]
            n = np.linalg.norm(d)
            if n > 1e-6:
                dirs[k] = d / n
    raw = bytearray()
    for fr in frames:
        for k in BONES:
            D = ortho(fr[k][0] @ rest[k][0].T)
            q = quat(D)
            raw += struct.pack("<hhh", *[int(round(max(-1, min(1, v)) * 32767)) for v in q[:3]])
        off = (fr["Hips"][1] - hips0) / hip_h
        raw += struct.pack("<hhh", *[int(round(max(-32, min(32, v)) * 1000)) for v in off])
    # locomotion: ground speed of the planted foot and the left foot's contact phase
    speed, contact = None, None
    if loop and len(frames) > 4:
        vals = []
        lows = []
        for side in ("Left", "Right"):
            ys = [fr[side + "Foot"][1][1] for fr in frames]
            lo = min(ys)
            band = lo + 0.04 * hip_h
            for i in range(1, len(frames)):
                if ys[i] < band and ys[i - 1] < band:
                    dz = (frames[i][side + "Foot"][1][2] - frames[i][ "Hips"][1][2]) - (
                        frames[i - 1][side + "Foot"][1][2] - frames[i - 1]["Hips"][1][2])
                    dx = (frames[i][side + "Foot"][1][0] - frames[i]["Hips"][1][0]) - (
                        frames[i - 1][side + "Foot"][1][0] - frames[i - 1]["Hips"][1][0])
                    vals.append(math.hypot(dx, dz) * FPS)
            if side == "Left":
                # contact: the first frame the left foot enters the low band after being above it
                for i in range(1, len(frames)):
                    if ys[i] < band <= ys[i - 1]:
                        lows.append(i)
        if vals:
            vals.sort()
            speed = float(np.median(vals)) / hip_h
            if speed < 0.05:
                speed = None
        if lows:
            contact = lows[0] / max(1, len(frames) - 1)
    lines = [
        "--!strict",
        f"-- Generated by tools/anim/bake_biped.py from {os.path.basename(path)} (Mixamo). Format: Logic/BipedClip.",
        "-- Do not edit by hand: bake again.",
        "",
        "return {",
        "\tbones = {",
    ]
    lines += [f'\t\t"{k}",' for k in BONES]
    lines.append("\t},")
    lines.append("\tdirs = {")
    for k in BONES:
        if k in dirs:
            d = dirs[k]
            lines.append(f"\t\t{k} = {{ {d[0]:.4f}, {d[1]:.4f}, {d[2]:.4f} }},")
    lines.append("\t},")
    lines.append(f"\tframes = {len(frames)},")
    lines.append(f"\tfps = {FPS},")
    lines.append(f"\tloop = {'true' if loop else 'false'},")
    if speed is not None:
        lines.append(f"\tspeed = {speed:.4f}, -- hip heights per second of the planted foot")
    if contact is not None:
        lines.append(f"\tcontact = {contact:.4f}, -- phase of the left foot's contact")
    if hit is not None:
        lines.append(f"\thit = {hit:.4f}, -- seconds to the blow")
    lines.append(f'\tdata = "{base64.b64encode(bytes(raw)).decode()}",')
    lines.append("}")
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, f"{name}.luau")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"{name}: {len(frames)} frames, speed={speed}, contact={contact} -> {out}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("fbx", nargs="?")
    ap.add_argument("name", nargs="?")
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--hit", type=float)
    ap.add_argument("--start", type=float)
    ap.add_argument("--end", type=float)
    ap.add_argument("--batch")
    a = ap.parse_args()
    if a.batch:
        base = os.path.dirname(os.path.abspath(a.batch))
        with open(a.batch, encoding="utf-8") as fh:
            for row in csv.DictReader(fh, delimiter=";"):
                if not row.get("fbx") or row["fbx"].startswith("#"):
                    continue
                fbx = row["fbx"] if os.path.isabs(row["fbx"]) else os.path.join(base, row["fbx"])
                num = lambda k: float(row[k]) if row.get(k) else None
                bake(fbx, row["name"], row.get("loop") == "1", num("hit"), num("start"), num("end"))
        return
    if not a.fbx or not a.name:
        ap.error("CLIP.fbx NAME, or --batch FILE")
    bake(a.fbx, a.name, a.loop, a.hit, a.start, a.end)


if __name__ == "__main__":
    main()
