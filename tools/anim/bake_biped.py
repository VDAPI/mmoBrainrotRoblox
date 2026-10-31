"""
Bakes Mixamo FBX clips (any Mixamo skeleton, 30 fps) into src/shared/Data/BipedClips/<name>.luau for the template
biped animation (Logic/BipedClip, Logic/BipedMotion; docs/ANIM-WZORCE.md).

    py -3 tools/anim/bake_biped.py CLIP.fbx NAME [--loop] [--hit S] [--strike S] [--start S] [--end S]
                                   [--root keep|inplace|end|plant] [--fps N]
    py -3 tools/anim/bake_biped.py --batch tools/anim/clips.csv --src FOLDER_WITH_THE_FBX

Needs Python with the `bpy` module (Blender as a library) and numpy. The FBX files stay out of the repo (Mixamo's
licence); tools/anim/clips.csv lists every baked clip with its source file, range, root handling and timing.

What is stored, per frame and per bone: the bone's WORLD turn relative to the clip's own rest pose, D(t) =
R(t) * R_rest^-1, in Roblox axes (up +Y, front -Z), as an int16 unit quaternion (x, y, z with w >= 0); then the Hips
offset from its rest position in units of the clip's hip height (x1000). Also the rest direction of every bone (to its
child joint), so the runtime can first turn the model's bone onto the clip's rest direction (A-pose vs T-pose) and then
apply D(t): W = D(t) * fromTo(modelRestDir, clipRestDir); and the rest knuckle line of each hand (index -> little
finger root), which fixes the arm chain's roll as well (Logic/BipedClip.fit). Locomotion clips also get `speed` (ground
speed of a planted foot in hip heights per second, for stride-matched playback) and `contact` (the phase at which the
left foot plants); actions their `hit` (seconds to the contact or release; given in seconds of the source file, stored
from the range's start) and `strike` (seconds of the fast part before it, played at the clip's own speed).

Root handling (`--root`): `keep` the Hips path as captured (a lunge that steps back, a fall); `inplace` takes the
straight drift from the first frame to the last away (a walk or run cycle, like Mixamo's "In Place"; a loop's height
drift too, so the cycle wraps without a jump); `end` moves the whole clip so it ends over the origin (getting up from
the ground); `plant` takes the ground travel away (the Hips' smoothed path) and plants each foot where it lands, the
legs solved again by two-bone IK (a stride or a spin in place).
A skinned download whose bind pose lies down has only its rest stood up (the frames stand already).
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
# the knuckle roots of each hand (the rest knuckle line: the roll of the arm chain)
KNUCKLES = {"R": ("RightHandIndex1", "RightHandPinky1"), "L": ("LeftHandIndex1", "LeftHandPinky1")}
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


def sample(path, start=None, end=None, fps=FPS):
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
    for key in BONES + list(CHILD.values()) + [k for pair in KNUCKLES.values() for k in pair]:
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
    # A skinned Mixamo download keeps the uploaded model's bind pose: it may lie down while the animation stands (the
    # armature's rest is the bind pose, its frames are upright). Then only the rest is stood up (and centred over the
    # origin, where the animation stands); a clip lying as a whole is stood up as a whole.
    lying = np.dot(up / np.linalg.norm(up), np.array([0, 1.0, 0])) < 0.9
    upright = 0.0
    for fr in range(int(f0), int(f1) + 1, 5):
        scene.frame_set(fr)
        up0 = world_of(names["Head"])[1] - world_of(names["Hips"])[1]
        upright = max(upright, up0[1] / max(1e-9, np.linalg.norm(up0)))
    turn_frames = not lying or upright < 0.7
    if lying and not turn_frames:
        c = rest["Hips"][1]
        rest = {k: (R, p - np.array([c[0], 0, c[2]])) for k, (R, p) in rest.items()}
    QF = Q if turn_frames else np.eye(3)
    a = (start * src_fps + f0) if start is not None else f0
    b = (end * src_fps + f0) if end is not None else f1
    frames = []
    f = float(a)
    step = src_fps / fps
    while f <= b + 1e-6:
        scene.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
        cur = {}
        for k, v in names.items():
            if v:
                R, p = world_of(v)
                cur[k] = (QF @ R, QF @ p)
        frames.append(cur)
        f += step
    return rest, frames


def from_to(a, b):
    """The shortest rotation taking unit vector a onto unit vector b."""
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if c < -0.999999:
        axis = np.cross(a, [1.0, 0, 0])
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(a, [0, 1.0, 0])
        axis /= np.linalg.norm(axis)
        return 2 * np.outer(axis, axis) - np.eye(3)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k / (1 + c)


def smooth(path, sigma):
    """Gaussian low-pass of a (n, k) path along its first axis (frames), the ends held."""
    n = len(path)
    r = int(math.ceil(sigma * 3))
    w = np.exp(-0.5 * (np.arange(-r, r + 1) / max(sigma, 1e-6)) ** 2)
    w /= w.sum()
    padded = np.concatenate([np.repeat(path[:1], r, 0), path, np.repeat(path[-1:], r, 0)])
    return np.array([(padded[i:i + 2 * r + 1] * w[:, None]).sum(0) for i in range(n)])


def plant(frames, hip_h, fps):
    """In place with planted feet: the Hips' smoothed ground path is taken away; each foot stays where it lands (its
    stance pinned, its swing carried from the last stance's spot to the next) and the legs are solved again."""
    n = len(frames)
    hips = np.array([fr["Hips"][1] for fr in frames])
    drift = np.zeros((n, 3))
    drift[:, [0, 2]] = smooth(hips[:, [0, 2]], 0.25 * fps)
    drift -= drift[0]
    for side in ("Left", "Right"):
        up, knee, ankle = side + "UpLeg", side + "Leg", side + "Foot"
        a = np.array([fr[ankle][1] for fr in frames])
        low = a[:, 1].min() + 0.06 * hip_h
        v = np.zeros(n)
        v[1:] = np.linalg.norm(np.diff(a[:, [0, 2]], axis=0), axis=1) * fps
        v[0] = v[1] if n > 1 else 0
        stance = (a[:, 1] < low) & (v < 0.6 * hip_h)
        # the correction that pins the foot: frozen at each landing, carried back to zero over the next swing
        corr = np.zeros((n, 3))
        i = 0
        held = np.zeros(3)
        while i < n:
            if stance[i]:
                j = i
                while j + 1 < n and stance[j + 1]:
                    j += 1
                for k in range(i, j + 1):
                    corr[k] = held + drift[k] - drift[i]
                held = corr[j]
                i = j + 1
            else:
                j = i
                while j + 1 < n and not stance[j + 1]:
                    j += 1
                if j + 1 < n:
                    for k in range(i, j + 1):
                        u = (k - i + 1) / (j - i + 2)
                        corr[k] = held * (1 - u * u * (3 - 2 * u))
                    held = np.zeros(3)
                else:
                    corr[i:j + 1] = held
                i = j + 1
        for k, fr in enumerate(frames):
            h0, k0, a0 = fr[up][1], fr[knee][1], fr[ankle][1]
            h = h0 - drift[k]
            t = a0 - drift[k] + corr[k]
            l1, l2 = np.linalg.norm(k0 - h0), np.linalg.norm(a0 - k0)
            d_vec = t - h
            # a pin the leg cannot reach slides the foot along the ground instead of lifting it
            reach = 0.96 * (l1 + l2)
            if np.linalg.norm(d_vec) > reach:
                flat = math.hypot(d_vec[0], d_vec[2])
                keep = math.sqrt(max(0.0, reach * reach - d_vec[1] * d_vec[1]))
                if flat > 1e-9:
                    d_vec = np.array([d_vec[0] * keep / flat, d_vec[1], d_vec[2] * keep / flat])
            d = min(np.linalg.norm(d_vec), 0.999 * (l1 + l2))
            nrm = d_vec / max(np.linalg.norm(d_vec), 1e-9)
            line0 = (a0 - h0) / max(np.linalg.norm(a0 - h0), 1e-9)
            pole = (k0 - h0) - line0 * np.dot(k0 - h0, line0)
            pole = pole - nrm * np.dot(pole, nrm)
            pole = pole / max(np.linalg.norm(pole), 1e-9)
            along = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
            height = math.sqrt(max(0.0, l1 * l1 - along * along))
            k1 = h + nrm * along + pole * height
            a1 = h + nrm * d
            th0, th1 = (k0 - h0) / l1, (k1 - h) / l1
            sh0, sh1 = (a0 - k0) / l2, (a1 - k1) / l2
            fr[up] = (ortho(from_to(th0, th1) @ fr[up][0]), fr[up][1])
            fr[knee] = (ortho(from_to(sh0, sh1) @ fr[knee][0]), fr[knee][1])
    for k, fr in enumerate(frames):
        for b in fr:
            fr[b] = (fr[b][0], fr[b][1] - drift[k])
    return frames


def bake(path, name, loop=False, hit=None, start=None, end=None, root="keep", fps=FPS, strike=None):
    rest, frames = sample(path, start, end, fps)
    if hit is not None and start:
        hit -= start  # given in seconds of the source file
    ground = min(rest["LeftToeBase"][1][1], rest["RightToeBase"][1][1], rest["LeftFoot"][1][1], rest["RightFoot"][1][1])
    hip_h = max(1e-6, (rest["LeftUpLeg"][1][1] + rest["RightUpLeg"][1][1]) / 2 - ground)
    hips0 = rest["Hips"][1]
    n = len(frames)
    if root == "inplace" and n > 1:
        d = frames[-1]["Hips"][1] - frames[0]["Hips"][1]
        if not loop:
            # (a loop's height drifts away too: Walking/Running/Jogging sink a little each cycle and popped back up
            # at the wrap; 2026-10-31)
            d[1] = 0
        for i, fr in enumerate(frames):
            for k in fr:
                fr[k] = (fr[k][0], fr[k][1] - d * i / (n - 1))
    elif root == "end":
        d = frames[-1]["Hips"][1] - hips0
        d[1] = 0
        for fr in frames:
            for k in fr:
                fr[k] = (fr[k][0], fr[k][1] - d)
    elif root == "plant":
        frames = plant(frames, hip_h, fps)
    elif root != "keep":
        raise SystemExit(f"unknown --root {root}")
    dirs = {}
    for k in BONES:
        child = CHILD.get(k)
        if child in rest:
            d = rest[child][1] - rest[k][1]
            nd = np.linalg.norm(d)
            if nd > 1e-6:
                dirs[k] = d / nd
    knuckles = {}
    for s_, (index, pinky) in KNUCKLES.items():
        if index in rest and pinky in rest:
            d = rest[index][1] - rest[pinky][1]
            if np.linalg.norm(d) > 1e-6:
                knuckles[s_] = d / np.linalg.norm(d)
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
                    dz = (frames[i][side + "Foot"][1][2] - frames[i]["Hips"][1][2]) - (
                        frames[i - 1][side + "Foot"][1][2] - frames[i - 1]["Hips"][1][2])
                    dx = (frames[i][side + "Foot"][1][0] - frames[i]["Hips"][1][0]) - (
                        frames[i - 1][side + "Foot"][1][0] - frames[i - 1]["Hips"][1][0])
                    vals.append(math.hypot(dx, dz) * fps)
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
    if knuckles:
        lines.append("\tknuckles = {")
        for s_ in ("R", "L"):
            if s_ in knuckles:
                d = knuckles[s_]
                lines.append(f"\t\t{s_} = {{ {d[0]:.4f}, {d[1]:.4f}, {d[2]:.4f} }},")
        lines.append("\t},")
    lines.append(f"\tframes = {len(frames)},")
    lines.append(f"\tfps = {fps},")
    lines.append(f"\tloop = {'true' if loop else 'false'},")
    if speed is not None:
        lines.append(f"\tspeed = {speed:.4f}, -- hip heights per second of the planted foot")
    if contact is not None:
        lines.append(f"\tcontact = {contact:.4f}, -- phase of the left foot's contact")
    if hit is not None:
        lines.append(f"\thit = {hit:.4f}, -- seconds to the blow")
    if strike is not None:
        lines.append(f"\tstrike = {strike:.4f}, -- seconds of the fast part before the blow")
    lines.append(f'\tdata = "{base64.b64encode(bytes(raw)).decode()}",')
    lines.append("}")
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, f"{name}.luau")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    size = os.path.getsize(out)
    print(f"{name}: {len(frames)} frames at {fps}, {size / 1024:.1f} KB, speed={speed}, contact={contact} -> {out}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("fbx", nargs="?")
    ap.add_argument("name", nargs="?")
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--hit", type=float)
    ap.add_argument("--strike", type=float)
    ap.add_argument("--start", type=float)
    ap.add_argument("--end", type=float)
    ap.add_argument("--root", default="keep")
    ap.add_argument("--fps", type=int, default=FPS)
    ap.add_argument("--batch")
    ap.add_argument("--src", help="folder of the FBX files named in the batch (default: the batch file's folder)")
    ap.add_argument("--only", help="bake only these names of the batch (comma separated)")
    a = ap.parse_args()
    if a.batch:
        base = a.src or os.path.dirname(os.path.abspath(a.batch))
        only = set(a.only.split(",")) if a.only else None
        with open(a.batch, encoding="utf-8") as fh:
            rows = [line for line in fh if line.strip() and not line.lstrip().startswith("#")]
        for row in csv.DictReader(rows, delimiter=";"):
            if not row.get("fbx") or (only and row["name"] not in only):
                continue
            fbx = row["fbx"] if os.path.isabs(row["fbx"]) else os.path.join(base, row["fbx"])
            if not os.path.exists(fbx):
                print(f"{row['name']}: skipped, {fbx} not found")
                continue
            num = lambda k: float(row[k]) if row.get(k) else None
            bake(fbx, row["name"], row.get("loop") == "1", num("hit"), num("start"), num("end"),
                 row.get("root") or "keep", int(row["fps"]) if row.get("fps") else FPS, num("strike"))
        return
    if not a.fbx or not a.name:
        ap.error("CLIP.fbx NAME, or --batch FILE")
    bake(a.fbx, a.name, a.loop, a.hit, a.start, a.end, a.root, a.fps, a.strike)


if __name__ == "__main__":
    main()
