# Monster animation templates (ANIM-WZORCE)

Written 2026-10-25 for the Studio session that rebuilds monster animation. Owner's brief: monsters are animated badly;
make one template per characteristic body type, the owner approves each one, then it is carried over to the other kinds
of that type ("ZRÓB TO DOBRZE"). English on purpose: the implementer is Claude. This file is a spec only: it changes no
code and no fight numbers (the motion fits the server, never the other way round, docs/ANIMACJE.md §5).

Read §0 (families), §1 (rules for every family), your family's section and §9 (requests and blockers). The humanoid
template (bandit) is built first in Studio; §2 lists only what the other humanoid-rigged kinds need on top of it.

## 0. Families, representatives, rollout

| # | Family | Representative | Drawn today (Data/MonsterAssets, Studio check 2026-10-25) | What moves today | Gets the template after approval |
|---|---|---|---|---|---|
| F1 | Humanoid | `bandit` | `rig = "bones"`: Mixamo skeleton, clips in `Data/MonsterClips/<id>` | `Anim/BoneClips` (+ `BoneOverlay`, `Gait_Body`) | every `rig = "bones"` kind: humanoids, brutes (`werewolf`, `swampTroll`, `yeti`, `ghoul`), golems (`fireGolem`, `magmaGolem`, `crystalGuardian`), `forestWraith`, bosses Grimrok, Morvane, Azgor, Hrimvald |
| F2 | Quadruped | `wolf` | `rig = "static"` with a Tripo quadruped skeleton, no clips | `Anim/BoneGait` (`Logic/BoneRoles`: leg, knee, tail, head, spine) + `Gait_Body` | `iceWolf`, `lynx`, `snowLeopard`, `wasteHyena`, `brownBear`, `blackBear`, `boar`, `iceMammoth`; `rabbit` (light, §8) |
| F3 | Flyer | `ashVulture` | `rig = "static"` with Tripo wing bones | `BoneGait` (wing = one bone) + `Gait_Body` (hover, `Amp` 1.3) | `peakHarpy`; `wyvern` and `vaelgrath` while airborne (§5.8) |
| F4 | Dragon (winged quadruped) | `youngFrostDragon` | `rig = "static"`, Tripo quadruped skeleton with wings | `BoneGait` + `Gait_Body` | `wyvern` (wings are its forelegs), `vaelgrath` (boss: `Data/BossMotions` gestures on top) |
| F5 | Rigid (no bones) | `caveSpider` | `rig = "static"`, no bones | `Gait_Body` only (whole-model CFrame) | `basilisk`, `salamander`, `bogSerpent`, `carrionCrow`, `bloodBat`, `rotEnt`, `swampToad`; probably `desertScorpion`, `iceElemental`, `specter`, `frostWyrm` (audit §1.9) |

Why these representatives:
- `wolf`: the first monster every player meets, three kinds reuse its model or rig type at once (`iceWolf` by model,
  `lynx` / `snowLeopard` / `wasteHyena` by shape), and it needs every quadruped skill: walk, trot, gallop, bite, leap.
- `ashVulture`: the crow and the bat are rigid (F5), the vulture is the flyer that has wing bones; the harpy is the same
  template with an upright torso.
- `youngFrostDragon`: four legs, wings, a long neck and a tail: the complete dragon. The wyvern and Vaelgrath derive
  from it.
- `caveSpider`: the most-seen rigid model (Mosshollow Cave, levels 14-20) and it needs every rigid trick (skitter,
  rear-up, lunge, leap, death flip).
- Not in the Studio list: `desertScorpion`, `iceElemental`, `specter`, `frostWyrm`, `rabbit` are `rig = "static"`;
  run the audit (§1.9) once: bones → F2 / F3 / F4 by shape, none → F5.

## 1. Rules for every family

### 1.1 Conventions

- Model frame = the look's pivot frame: feet at y = 0, front −Z, up +Y, right +X (`MonsterViewController` builds it so).
- Angles in degrees in this file (code: radians). **Pitch** = about +X: positive lifts a forward-pointing part (nose
  up) and swings a hanging limb forward. **Yaw** = about +Y: positive turns the front to the left. **Roll** = about +Z:
  positive raises the right side (the top leans left). Left-side bones mirror yaw and roll (the `Logic/Gait` rule).
- Sizes are measured once on the cloned look (it already carries `LookScale` and `asset.visual`): `L` = front leg
  length (rest height of the front shoulder joint), `B` = body length (chest to tail root), `h` = drawn height,
  `Rs` = how far the snout / beak / fangs reach ahead of the model centre. "0.1 L" = a tenth of the leg length.
- Bone writes: `Transform = rest⁻¹ · C · rest`, `rest` = the bone's rest rotation in model space, `C` = its turn in model
  axes relative to its parent (the convention of `Logic/NpcPose` and `Anim/BoneOverlay`; any export's bone orientation
  works). In a chain bending in one plane (legs, spine and neck pitch, tail yaw) the turns add up:
  `C(bone) = R(Δ(bone) − Δ(parent))`, `Δ` = the absolute change wanted for that bone.
- Body = the `Gait_Body` Motor6D (Part0 the server's root, Part1 the look's PrimaryPart at the feet); its `Transform`
  moves the whole model. A rotation about another point p: `CF(p) · R · CF(−p)`.
- Action timeline: `W` = the server's windup of the action (the event's seconds). `S` = strike segment, 0.14 s
  (`Gait.STRIKE_SECONDS`) unless a table says otherwise. Phases: **A** anticipation `[0, W − S]`, **S** strike
  `[W − S, W]` (contact or release exactly at `W`), **F** follow-through, **R** recovery. Tables give seconds for the
  normal variant; an Elite / Elite II basic blow (W ×1.2 / ×1.35) stretches A only; S, F, R stay.
- Curves: easeOut = `1 − (1 − x)²` (gathers), easeIn = `x³` (strikes, falls), smooth = smoothstep, "spring ω" = a
  critically damped spring with angular frequency ω rad/s.

### 1.2 What the game triggers (server facts the motion must fit)

| Fact | Value | Source |
|---|---|---|
| Basic melee blow | event `aw` (st `melee`, `w`, attacker `s`, target `t`), damage `w` later: 0.55 s normal, 0.66 Elite, 0.7425 Elite II and boss | `Data/Combat.basicWind`, `Logic/BasicBlow`, `Entities/Monster` windUp |
| Basic ranged blow | `aw` with st `arrow` (physical) or `bolt` (magic): draw 0.5 / 0.6 / 0.675 s, the projectile leaves at the end | same, `CombatService` projectile |
| Elite II throw at a fleeing target | `aw` st `throw`: draw 0.6 × 1.35 = 0.81 s | `MonsterAbilities.KITS.elite2.throw` |
| Attack interval | 2.0 s / kind speed: wolf 1.74, lynx 1.67, bear 2.35, boar 2.0, mammoth 2.5, vulture 1.6, spider 1.67, dragon 2.0; after an ability the next blow may come 0.5 × interval later | `Combat.monsterAttackInterval`, `Monster.stepCast` |
| Elite II own ability (charged, telegraph `tele`) | leap 1.2, charge 1.0, slam 1.4, poisonPool 1.3, wail 1.2, fireBreath 1.3, frostBreath 1.3, frostNova 1.4, emberNova 1.4 s | `Data/MonsterAbilities` |
| Kit blows | Elite: heavyBlow 1.8 s (cone 10 studs / 90° in front). Elite II: crush 2.2 s (lethal circle under the target, up to 45 studs away), pounce 1.4 s (target 12-45 studs away, **the monster is teleported into the circle at W**), throw | `KITS`, `Monster.stepCast` (PivotTo when `leap`) |
| Only these move the monster in an ability | `pounce`, `warlordLeap` (`leap = true`, teleported at W). S162m: the canine `leap` and the boar `charge` now run there at the end of the windup (`dash`, §10) | `Data/MonsterAbilities` |
| Hit flinch | `MonsterHit` at most once per 0.1 s; fades over 0.25 s; during a charged gather ×0.3 | `Config.MonsterLook.hitEvery`, `Gait.HIT_SECONDS` |
| Death | attribute `Dead`; pose 0.8 s, corpse fades (t²) until 1.6 s, then removed | `MonsterLook.deathSeconds`, `Config.CorpseSeconds` |
| Spawn | a boss helper (`Summoned`) climbs out over 0.8 s; S162m: every spawn stamps `SpawnedAt` (server time, §10) | `AnimationController` riseStart |
| Speeds | S162m: wander and patrol 0.4 ×, going home 0.7 ×, chase ×1 `moveSpeed` (9-14 studs/s; default 13, wolves and cats 14), attribute `Gait` (§10); slows scale it | `Logic/MonsterMove`, `Entities/Monster` |
| Facing | `face()` snaps the root to the target on the 5 Hz AI tick; `MoveTo` turns the Humanoid while walking | `Entities/Monster` |
| Melee stop distance | reach = range 7 + half the root depth: wolf 8.5, bear 9.6, dragon 9.6, spider 7.75 studs (normal); S162m: it walks on to 0.6 × reach (wolf 5.1) before it stands (§10) | `Monster.stepChase` |
| Replicated state | `AggroUserId` (target, nil = none), `Returning`, `Dead`, `Effects` (EffectStack: stun, freeze, slow...), `Flying` (Vaelgrath only), `Summoned`, `Phase`, `Variant`, `LookScale`, `GroupSize`; S162m: `Gait`, `SpawnedAt`, `Dash*`, the root's `Muzzle` (§10) | `Entities/Monster`, `StatusEffectService` |
| How many animate | the nearest 60 (desktop) / 25 (touch) monsters with a full look; the rest stand still | `Config.MonsterLook.maxAnimated` |

No flee state exists (the hare is only passive: it never starts a fight). Bosses add their own attacks and roars
(`Data/BossMotions`), which layer over the family template of their body.

### 1.3 The hit frame (must)

1. Contact (jaw shut, paw down, body at full lunge) or release (the projectile leaves the mouth, the wing, the hand)
   exactly `W` after the event reaches the client, ±0.03 s (docs/ANIMACJE.md §5 rule 2). That is the server's damage
   moment (melee: the `task.delay` in windUp; ranged: the projectile spawns; ability: the telegraph flashes).
2. A basic blow without `aw` (old path, `strikeNow`) peaks `Gait.STRIKE_NOW_LEAD` (0.03 s) after `atk`.
3. A charged gather (`tele`) reads as a silhouette within 0.3 s (`Gait.charge`: `1 − (1 − p)²`) and trembles as `p²`,
   in step with the telegraph's fill.
4. A teleporting ability (pounce, warlordLeap) ends its visual arc in the circle at `W`; the existing hand-off (the root
   jumps more than 4 studs → the arc ends) must not pop.
5. Nothing random inside S. Variants pick their pose before S starts.
6. A flinch never restarts or delays A. Any action may start during another's F or R, from the current pose.
7. AnimLab `keys` (`Logic/MotionKeys`) reports the new templates' `hit` = `W`; extend `MotionKeys` for them.
8. Projectiles start at the rig: the release point is a bone (jaw, beak, wing tip, hand), not `centre + (0, 1, 0)`
   (`CombatFxController.monsterShot`): expose a "muzzle" bone per family.

### 1.4 What is wrong today (read from the code)

1. **Feet slide** (F2, F4): `BoneRoles.angle` swings the leg's top bone with a sine of fixed 0.5 rad (29°); the cycle
   advances by `Gait.STRIDE` 4.5 × `LookScale`, which ignores the model's own leg length and its `visual` factor
   (1.3-2.2), and a sine is not a planted foot (a planted foot needs a linear sweep in stance).
2. **One gait at every speed**: diagonal trot phases always; `move = speed / 3` is full from 3 studs/s, so nothing
   changes between a stroll and a sprint. On top, the server wanders at full chase speed (§9 R1).
3. **Stiff limbs**: only the top leg bone and the next one move; paws never flex or plant; the spine is one bone ±2°;
   no neck chain; the tail is a time sine without follow-through; the head nods but never looks at its target.
4. **No jaw, ears, toes**: `BoneRoles` has no such roles; a bite is carried by the body motor (`dash` 0.4 studs) and the
   whole model, feet included, slides forward and back.
5. **Blows hit the air**: a melee monster stops at its reach edge (§1.2: ~8.5 studs); the gap between snout and
   target is ~5 studs and the 0.4-stud lunge never closes it (§1.7, §9 R2).
6. **Snap turns**: `face()` sets the root's rotation at 5 Hz; the look follows instantly (yaw pops).
7. **Hits**: the flinch jumps to full in one frame and decays linearly; the same for every blow.
8. **Deaths sink**: `Gait_Body` rolls 1.5 rad about the pivot at the feet centre, so half the body ends in the ground;
   smoothstep timing (no gravity); the legs go back to rest (`angle × alive`) instead of going limp; a flyer's `fall`
   drops with smoothstep (floats down) instead of accelerating.
9. **Flyers**: one wing bone, a symmetric sine; no fast downstroke / slow folded upstroke, no lift bob, no glide, no
   bank; legs dangle stiff.
10. **Rigid models**: a 0.05-stud breathing bob, a step bob and leans; nothing says "eight legs" or "slithering".
11. **AnimLab cannot show it**: `AnimLabController` never calls `BoneGait`, so `/animlab mob wolf walk` shows a gliding
    statue (approval blocker until fixed, §1.11).
12. **F1 anticipation cut away**: `BoneClips.play` starts an attack clip late when its hit comes later than the
    server's lead (bandit `attack2` hit 0.867 s vs the 0.55 s draw → starts 0.317 s in; fireGolem and werewolf
    `attack2` hit 1.0 s → start 0.45 s in): the wind-up the owner asked for is skipped (§2).

### 1.5 Layers and blends

Evaluate in this order every frame:

1. **Base**: idle ⇄ locomotion by a speed weight `wL = smooth((v − 0.3) / 1.2)` (0 at 0.3 studs/s, 1 at 1.5); the gait
   clock keeps running under idle.
2. **Action** (blow, ability, alert, roar): owns the bones its table lists; everything else keeps the base.
3. **Additive**: breathing, look-at, tremble, hit flinch, turn lean or bank, tail / ear / trunk springs.
4. **Body motor** (`Gait_Body`): bob, lean, lunge, arcs, hit push, turn smoothing, death.
5. **Feet IK** last (F2, F4): feet in stance stay where they touched the ground.
6. **Death** overrides everything.

| From → to | Blend |
|---|---|
| idle ⇄ locomotion | by speed weight (no timer) |
| gait ⇄ gait | 0.25 s crossfade of the gait parameters at the same phase |
| base → action | 0.08 s (basic blow), 0.12 s (charged) |
| action → base | the recovery itself (0.35 s smooth); locomotion resumes with the leg that is farthest behind |
| action → action | 0.06 s from the current pose |
| hit flinch | additive envelope: 0.05 s in (easeOut), 0.03 s hold, 0.25 s out with 10 % overshoot |
| any → death | 0.1 s, then the death curve |
| look-at weight | in 0.15 s, out 0.3 s |
| turn smoothing | spring on the body yaw: F2 ω 10, F3 ω 8, F4 ω 6, F5 ω 14 rad/s; at most 70° behind the root |

Turn smoothing: when the root's yaw jumps by `Δ`, add `−Δ` to the body motor's yaw offset and let the spring take it to
0; the look turns in ~0.25 s instead of popping. The offset is settled before any strike (W ≥ 0.5 s). With feet IK, a
twist over 20° re-plants the feet in the order front-left, hind-right, front-right, hind-left, 0.12 s apart.

### 1.6 Building blocks (write once, test in Lune)

Pure math in `shared/Logic` (no Roblox API, Lune specs), bone writing in `client/Anim`. Names are suggestions; the Studio
session owns the layout.

- **Gait clock**: phase advanced by distance, not time: `phase += v · dt / stride`, `stride = k(v / L) · L`; gait picked
  by `v / L` with hysteresis; returns for each leg `(stance?, p)` with `p = (phase − offset) mod 1`.
- **Foot planner**: at touchdown store the foot's world point; in swing a path from lift-off to the reach point
  `hip + stride · duty / 2` ahead, height peak at 35-40 % of the swing; lift a foot early when its stance would
  overstretch the leg (turns, lag spikes, teleports).
- **Two-bone IK** in the leg's plane (Appendix A); the bend side is the side the rest knee lies on (front elbows point
  back, hind knees forward, hocks back).
- **Spring** (critically damped) and **delay line** (sample a signal k × 40 ms late) for tails, ears, trunks, wing tips,
  turn lag and the flinch envelope.
- **Action curve**: `(t, W, S, F, R)` → phase name and local progress; easeOut gather, easeIn strike, overshoot.
- **Look-at**: yaw and pitch to the target's root + 2 studs, clamped (neck ±45° yaw, head ±30°, pitch ±25°), spread over
  the neck chain (weights base → head 0.15, 0.2, 0.25, 0.4), spring 0.15 s; off during S and death.
- **Seeded noise**: smooth 1-D value noise from the model's seed for drifts and tremble (no `math.random` per frame).
- **Death roll pivot**: roll about the ground line on the fall side (Appendix A) so the body lies on the ground.

### 1.7 Melee reach

Monsters stop at the edge of their reach (wolf 8.5 studs from the target's centre), so the jaws close ~5 studs short.
Two fixes, both recommended:
- server (owner decision, §9 R2): walk on to 0.6 × reach before stopping; the hit rule stays (reach × 1.5 + 3 at the
  blow). The gap then is 1-2 studs.
- animation: the target id is in `aw` (`t`) and in `AggroUserId`. `gap = flatDistance(root, targetRoot) − Rs − 1.0`;
  lunge `D = clamp(gap, 0, Dmax)` along the facing, aimed at the target until S starts, then locked. `Dmax`: wolf,
  boar 4 studs, lynx 3.5, bear, dragon, vulture, spider 3, toad, serpent 2.5 (× scale). `D ≤ 0.5 L`: feet stay planted,
  the body and neck stretch. `D > 0.5 L`: a hop-lunge (front feet leave at `W − S − 0.06`, land at `W`, one hind drag
  step), and R walks back with a 2-step reversed trot so the feet do not slide.

### 1.8 Randomness

- Seed per model (`MonsterState.seed`): idle clock offset, cadence ±4 %, tail amplitude ±15 %, fidget timers (ranges per
  family), head saccade timing, death side (existing `deathSide`) and death variant, attack variant (bite toss side
  alternates; 25 % feint before a bite).
- A group (`GroupSize` > 1) must not move in sync: offsets from the seed are enough; never share one clock.
- Nothing random in S (§1.3).

### 1.9 Rig audit (first thing per representative)

Run in the Studio command bar (or MCP `execute_luau`) on the template:

```lua
-- Prints every bone of a monster template with its parent and rest position in the model frame (feet y = 0, front -Z),
-- then its parts. Change `id`.
local id = "wolf"
local m = game.ReplicatedStorage.Assets.Monsters[id]
local pivot = m:GetPivot()
local _, size = m:GetBoundingBox()
print(id, "bounding box", size)
for _, d in m:GetDescendants() do
	if d:IsA("Bone") then
		local p = pivot:PointToObjectSpace(d.WorldPosition)
		print(string.format("%-28s parent=%-24s %6.2f %6.2f %6.2f", d.Name, d.Parent.Name, p.X, p.Y, p.Z))
	end
end
for _, d in m:GetDescendants() do
	if d:IsA("BasePart") then
		print("part", d.ClassName, d.Name, d.Size, d.Transparency)
	end
end
```

Write down per model: the bone → role map (pelvis, spine 1..n, chest, neck 1..n, head, jaw?, ears?, tail 1..n, each leg
3 or 4 bones, each wing 2-4 bones, toes?), `L`, hind hip height, `B`, `Rs`, `h`, whether the wings rest spread or folded.
For F5: the number of visible parts (one MeshPart → squash allowed, §6.1), the bounding-box centre height `c`, top
height, width. Keep the map in code (one table per model), not in this file.

### 1.10 Cost and level of detail

- Tier A, the nearest 12 (desktop) / 6 (touch): the full template (IK, springs, look-at).
- Tier B, the rest of `maxAnimated`: no IK (the FK sweep of §3.2), springs at 30 Hz, no look-at.
- Beyond: as today (still).
- Write a `Bone.Transform` only when it changed by more than 0.1°; at most one ground ray per footfall, none per frame.
- Measure with `/animlab stress` (after `mob` support) and `Stats.HeartbeatTimeMs`; budget about 0.02 ms per tier-A
  monster per frame on desktop.

### 1.11 Approval (per template)

1. AnimLab first: `mob <id> <slot>` must pose the template through a pure sampler `(slot, t, options) → pose` (like
   `Gait.stateMotion`), so `freeze` and `keys` work. Slots: `idle`, `walk`, `run`, `attack1`, `attack2`, `cast`, `hit`,
   `death`, `spawn`. For gaits, `walk` = 0.4 × the kind's `moveSpeed`, `run` = `moveSpeed`; an optional speed argument
   (`mob wolf run 6`) needs `Logic/AnimLab.parse`.
2. Shots from `side`, `threequarter`, `game`: loops at 4 phases, actions frozen at A 50 %, `W − S`, `W`, `W + 0.15`.
3. The owner checks docs/ANIMACJE.md §5 plus: feet do not slide in stance, nothing sinks into the ground (deaths!), the
   silhouette reads from the game camera, a pack of four does not move in sync.
4. After the owner's yes: the family's rollout table; one AnimLab sheet per kind.

## 2. F1 Humanoid (bandit): notes for the kinds on Mixamo rigs

Studio builds the bandit template now. What §1 means for it, and what the other `rig = "bones"` kinds add on top.

- **Keep the clip's anticipation** (§1.4 item 12): never start an attack clip in the middle. Warp time piecewise: the
  clip's wind-up `[0, hc − Sc]` (hc = clip hit, Sc = the clip's own strike part, ~0.15 s) is compressed or stretched
  into `[0, W − S]`; the strike part plays at rate 1 so the swing keeps its speed; the rest at rate 1. Compression at
  most 2.5×; beyond it, trim the clip's still lead-in frames instead.
- Shared layers from §1: turn smoothing, look-at (head and spine, off during S), the directional flinch as an additive
  over the clip, reach (§1.7), the muzzle point (staff tip / hand) for shots, death without sinking.

| Subtype | Kinds | Posture over the clips | Locomotion | Blows | Flinch | Death |
|---|---|---|---|---|---|---|
| Brute | `werewolf`, `swampTroll`, `yeti`, `ghoul` | spine +12° forward hunch, head +10° to keep the eyes level, arms hang 10° forward | clip rate from stride (no slide); body motor bob 0.04 h, footfall dip 0.03 h | the full wind-up (warp); F +0.1 s heavier; werewolf `leap` and Elite II pounce with a real arc (§3.5); `slam` lands at W with a ground impact | ×0.7 | knees, then forward |
| Golem | `fireGolem`, `magmaGolem`, `crystalGuardian` (+ Azgor) | wide stance, shoulders up 5°, head sunk | slower cadence: rate ≤ 0.8 of a humanoid's at the same speed (longer strides); each footfall: body dip 0.05 h, pitch 2°, dust | S 0.18 s; F holds the impact pose 0.25 s; impact VFX at W; `emberNova` gather trembles and glows | ×0.4 | knees, forward collapse, debris, fade |
| Ghost on bones | `forestWraith` | arms forward 10°, slight hunch | no leg cycle: the idle clip on the legs while moving, body float bob ±0.12 h at 0.5 Hz, lean 10° into the move, drift lag 0.2 s | cast clip warped; ranged release at the hands | ×0.8 + transparency flicker | rise 1.5 studs and fade by 0.8 s |

## 3. F2 Quadruped: wolf

### 3.1 Rig and sizes

Roles to map in the audit (§1.9): pelvis (root), spine 1..n, chest, neck 1..n, head, jaw (if any), ears (if any), tail
1..n, four legs of upper (scapula / hip), lower (humerus / femur), foot (radius / tibia), paw (if any). `BoneRoles` today
takes only the top and the next leg bone; the template needs the whole chain.

Wolf at `LookScale` 1: drawn `h` ≈ 4.4 studs (3.39 × visual 1.3), `B` ≈ 3.8, estimated `L` ≈ 2.0-2.2 and `Rs` ≈ 1.9
(measure). `moveSpeed` 14 → v / L ≈ 6.5: a gallop. Going home at 17.5 studs/s ≈ 8 L/s. Elites are 1.25× / 1.5× bigger, so
the same speed gives a slower cadence by itself (stride scales with L).

### 3.2 Locomotion

| Gait | v / L (up; down) | Footfall (touchdown phase, LH = 0) | Duty | Stride k (× L) | Body (motor) | Spine | Neck and head | Tail |
|---|---|---|---|---|---|---|---|---|
| Walk | < 1.7; 1.5 | lateral sequence: LH 0, LF 0.25, RH 0.5, RF 0.75 | 0.65 | 1.1 → 1.3 | bob 0.015 L twice a cycle (high when a foreleg is mid-stance), roll ±1.5° | yaw ±3° at 1× (bends toward the foreleg in stance) | neck pitch counters the bob (±2.5°), head height varies ≤ 0.01 L; look-at on | yaw ±6° at 1×, 0.15 cycle lag per bone |
| Trot | 1.7-3.8; 1.5 / 3.4 | diagonal pairs: LH 0 + RF 0.02, RH 0.5 + LF 0.52 | 0.45 | 1.6 → 2.0 | bob 0.035 L twice a cycle, lowest at mid-stance; roll ±2° | flat, yaw ±1.5° | head steady (neck counter-pitch ±3°) | raised +10°, sway ±4° |
| Gallop (rotary) | > 3.8; 3.4 | LH 0, RH 0.10, RF 0.42, LF 0.52 (lead side from the seed, swapped in a turn toward the other side) | hind 0.30, fore 0.28 | 3.0 at 3.8 → 3.6 at ≥ 7 | height: lowest in fore stance (~0.6), highest +0.07 L in the gathered flight (~0.9); pitch +5° in hind stance (~0.15), −5° in fore stance (~0.55) | sagittal flex: extended (back hollow, −8° spread over the spine) at ~0.40, flexed (arched, +12°) at ~0.90 | head world pitch within ±4° (the neck counter-rotates); ears back 25° | straight back, +10°, follows the spine flex 0.1 cycle late |

- Cadence: `f = v / (k · L)`. Wolf, L = 2.1: 3 studs/s walk ≈ 1.2 Hz; 6 studs/s trot ≈ 1.7 Hz; 14 studs/s gallop
  ≈ 2.0 Hz; 17.5 studs/s ≈ 2.3 Hz.
- Swing path: foot peak height walk 0.10 L, trot 0.16 L, gallop fore 0.28 L, hind 0.22 L, at 35 % of the swing; the
  fore paw folds back 70° in swing (gallop 100°: tucked up), the hind paw 30°; it opens 0.08 s before touchdown and
  lands flat.
- Full version: feet IK (§1.6) with planted feet. Body bob lives on the body motor; the IK targets are taken back
  through the motor's transform so planted feet stay put.
- FK fallback (tier B, or before IK exists): upper-leg pitch in stance `θ = A · (1 − 2p / duty)` (a **linear** sweep
  from +A to −A), in swing `θ = −A + 2A · smooth(s)` with `s = (p − duty) / (1 − duty)`;
  `A = asin(clamp(duty · k / 2, 0.15, 0.6))` (walk ≈ 23°, trot ≈ 24°, gallop ≈ 30°); lower bone: stance 0-8° (most at
  mid-stance), swing a fold peaking at 45° (front, joint back) / 35° (hind) at s = 0.4.
- Start (v rises past 0.3): body pitch −4° for 0.15 s (falls into the run), the first lift is the hind leg farthest
  back. Stop (v under 0.3): finish the swings (≤ 0.25 s), plant, then idle; body pitch +3° → 0 over 0.3 s.
- Turning while running: lean into the turn (roll = clamp(0.25 s × yaw rate, ±10°)), the spine yaws toward the inside
  (up to 8° spread); turning in place: turn smoothing + re-plant steps (§1.5).

### 3.3 Idle, alert, going home

| State | Motion |
|---|---|
| Idle base | weight even, neck and head at rest, tail −5° |
| Breathing | chest / spine pitch ±1° at 0.35 Hz; after 4+ s of running: panting, jaw 12°, ±2.5° at 2.2 Hz, fading over 5 s |
| Weight shift | body x ±0.03 L at 0.12 Hz with roll ±1° |
| Looking around | every 2.5-6 s: a new yaw ±35°, pitch ±10°, reached in 0.35 s (smooth), held; 50 % of the time toward a player within 20 studs |
| Ears (if bones) | each ear twitches 0.15 s every 3-8 s |
| Tail | yaw ±8° at 0.25 Hz, chain lag 0.12 s per bone |
| Fidgets (one every 6-12 s, never with a target) | sniff the ground (neck −30°, head −15° in 0.5 s, three ±3° sniffs at 5 Hz, back in 0.6 s); head shake (yaw ±15° at 6 Hz for 0.4 s, ears flop); re-plant a fore paw (0.3 s step) |
| Alert (`AggroUserId` nil → id), additive 0.4 s, also while the chase starts | 0-0.12 s: head snaps to the target (look-at weight 1), ears forward, body y −0.05 L, tail up +15° and stiff; 0.12-0.4 s: snarl, jaw 8°, then release |
| Going home (`Returning` = true) | the same gaits, calm: head −8°, tail −10°, ears neutral, look-at off, no panting; on arrival a sniff fidget at once |

### 3.4 Basic blow: bite (W = 0.55; Elite 0.66, Elite II 0.74)

| Phase | t (s) | Motion |
|---|---|---|
| Blend | 0-0.08 | from the base pose |
| A (easeOut) | 0-0.41 | body z +0.12 L (back), y −0.04 L, pitch +4°; front feet planted (the shift braces them), hind legs flex 8°; neck pitch +12°, head +6°, yaw on the target (look-at); jaw opens to 30° by 0.35; ears back 25°; tail −10° and stiff |
| S (easeIn) | 0.41-0.55 | lunge `D` (§1.7, at least 0.2 L), pitch −6°; neck −20°, head −10°; jaw 30° → 0° in the last 0.06 s |
| Contact | **0.55** | jaw shut, head at the target, body at full lunge |
| F | 0.55-0.72 | head toss: yaw ±12° (alternates per bite), pitch +6° (tug); body overshoot −0.03 L |
| R (smooth) | 0.72-1.07 | back to the base; with `D > 0.5 L` a 2-step reversed trot carries the body back |

Variant: 25 % a feint at 0.22-0.30 s (jaw 30 → 12 → 30°, head −6°) before the real strike.

### 3.5 Elite II own ability: leap (W = 1.2, circle r 7 under the target; S162m: the server runs the wolf the last 0.35 s, `Dash*` §10)

| Phase | t (s) | Motion |
|---|---|---|
| A1 aim | 0-0.3 | crouch: body y −0.15 L, z +0.2 L, pitch −3°; hind legs fold (hips drop, feet planted), front feet spread 5°; neck −12°, head +10° (eyes level on the target); ears flat; tail straight back |
| A2 hold | 0.3-0.85 | tremble ∝ p² (body pitch / roll noise up to 1.5° at 18 Hz); hind feet tread (re-plant 0.05 L at 0.5 and 0.7 s); rear rises 0.03 L |
| Launch | 0.85 | hind legs extend, body pitch +12° |
| Flight | 0.85-1.2 | the body follows `Gait.leapArc` from 0 to `Dleap = clamp(distance to the circle centre − Rs, 0, 5 studs × scale)`, height 0.4 L + 0.1 Dleap; fore legs reach (upper +40°, lower straight), hind legs trail (−35°), spine extended −8°, jaw 35° |
| Contact | **1.2** | forefeet land, jaw snaps shut, pitch −10°, y −0.06 L (the legs absorb) |
| F | 1.2-1.45 | head shake: yaw ±10° at 8 Hz, 2 cycles; hind feet land 0.08 s after the fore |
| R | 1.45-1.95 | back to the server position with a reversed trot (2-3 steps) |

### 3.6 Elite and Elite II kit

| Blow (W) | A | S and contact at W | F + R |
|---|---|---|---|
| Heavy Blow, Elite (1.8, cone 10 / 90° in front) "maul" | 0-1.0: body z +0.2 L, pitch +10°; right fore lifts (upper +35°, lower folded 60°); head cocked right (yaw +20°), neck +10°, jaw 35°; 1.0-1.66: tremble ∝ p², snarl pulse (jaw 35 ↔ 28° at 4 Hz) | 1.66-1.8: head sweeps across the cone (yaw +20° → −25°), lunge ≤ 2 studs, the raised paw slams down at 1.8, jaw snaps at 1.8 | 1.8-2.1: head on to −30°, shakes twice; R to 2.45 |
| Crush, Elite II (2.2, lethal circle under the target) "rear and slam" | 0-0.6: crouch, then up on the hind legs (pivot at the hind feet): pitch +55°, y +0.35 L; front legs folded high (upper +60°, lower −70°); tail −25° (counterweight); neck −30° to the body (eyes on the target); jaw 30°. 0.6-2.06: hold, hind feet tread every 0.4 s, tremble ∝ p² up to 2° | 2.06-2.2: pitch +55° → −8°, both forefeet slam at 2.2 (IK targets 0.45 L ahead of the shoulders), y −0.08 L | 2.2-2.5: snarl low (neck −15°, jaw 25°), dust; R to 2.9. The circle may be far: a ground-crack VFX from the paws to it reads well (VFX session) |
| Pounce, Elite II (1.4; teleported into the circle at W) | 0-1.0: the leap crouch (A1 + A2 of §3.5), deeper (y −0.2 L), turned toward the circle | 1.0-1.4: flight on the leap arc of `AnimationController` (today bosses only: enable it for `leap = true` abilities, the `cf` of `tele` is the circle), height `clamp(0.25 × distance, 2, 6)` studs × scale, body pitch follows the arc tangent (+20° up, −25° down); lands at 1.4 as the root teleports | 1.4-1.7: skid 0.3 L (the one allowed foot slide, with dust), head snap; R to 2.05 |
| Throw, Elite II (`aw` st `throw`, 0.81) | 0-0.45: head to the ground (neck −35°, head −20°), jaw 30° (scoop); 0.45-0.55: jaw closes; 0.55-0.67: neck draws back up +20°, body pitch +6° | 0.67-0.81: neck whips up and forward (+35° → −10°), head flick +20°, jaw opens at 0.81 = release (the projectile starts at the jaw) | head follows forward, R to 1.3 |

### 3.7 Hit, stun, freeze

Flinch at its peak (envelope §1.5), feet planted:

| Blow from | Pose |
|---|---|
| front | body z +0.10 L, pitch +6°; head pitch +8°, ears flat, jaw 10°; tail tucks −15° |
| side | roll away 7°, x 0.08 L away; spine yaws away 6° (a C-curve), head turns 12° toward the attacker |
| behind | body z −0.06 L, pitch −4°, hind legs flex 6°, tail clamps −20° |
| during a charged gather | ×0.3, no head turn |

Stun and freeze come from the `Effects` attribute (`EffectStack.decode`). Stun: head −15°, a slow circling sway (yaw
±8°, roll ±4° at 0.8 Hz), feet splay 0.05 L, ears down, tail springs ×0.3. Freeze: every clock of this model stops
(the pose holds), a 0.5° shiver at 25 Hz. Both blend 0.15 s in and out.

### 3.8 Death and spawn

| t (s) | Motion |
|---|---|
| 0-0.12 | hard jolt away from the attacker (flinch ×1.5) |
| 0.12-0.40 | legs buckle, hind first: hips drop 0.35 L (easeIn), fore legs fold from 0.25; body pitch −5°; neck −15° |
| 0.40-0.70 | roll onto the side (`deathSide`, away from the attacker when known): 85° about the ground line at x = side × half the body width (Appendix A), easeIn; legs limp (upper +15°, lower −10°, slightly splayed), paws relaxed; head and neck fall to the ground (neck −20°); jaw 15°; tail flat along the spine |
| 0.70-0.80 | settle: bounce y +0.03 L → 0; one hind twitch at 0.75 (upper ±8°) |
| 0.8-1.6 | hold; corpse fade (existing) |

No part more than 0.05 studs below the ground at any frame (check from 3 cameras).
Spawn: `Summoned` (0.8 s): climbs out (body y −3 studs → 0 as today) with the forelegs clawing (upper alternating
+40° / −10° at 4 Hz), head +15°, then a shake-off (roll ±6° at 5 Hz for 0.3 s). Regular respawn: nothing until a
server attribute exists (§9 R3); then 0.5 s: rise from a crouch (y −0.3 L → 0), shake-off, fade-in 0.2 s.

### 3.9 Rollout to the other quadrupeds

| Kind (model) | Size, speed, interval, Elite II ability | Changes from the wolf |
|---|---|---|
| `iceWolf` (wolf model) | 1.1, 14, 1.74 s, leap | none; breath mist while panting |
| `lynx`, `snowLeopard` (lynx model) | 0.8 / 0.9, 14, 1.67 / 1.6 s, leap | cat: walk body y −0.05 L; gallop = half-bound (LH 0, RH 0.04, LF 0.45, RF 0.55), spine flex ±18°; short tail (springs ×0.3); basic blow = a right fore swat landing at W (upper +50° → −10°) with the bite 0.1 s later as F; leap: a rear wiggle (hip yaw ±5° at 3 Hz) in the A2 hold, arc +0.2 L higher |
| `wasteHyena` | 0.95, 14, 1.67 s, leap | head carried −10°, sloped back; gallop with spine flex ×0.5 (a lope); bite F = head shake ±15° × 3 at 7 Hz |
| `brownBear`, `blackBear` (bear model) | 1.5, 13, 2.35 / 2.22 s, slam | plantigrade: feet flat, duty +0.1 in every gait, walk k 1.0; rolling walk: shoulder roll ±4°, head sway yaw ±5° per step; run = heavy gallop (spine flex ±6°, bob 0.05 L, pitch ±4°); blows below |
| `boar` | 1.15, 13, 2.0 s, charge | short legs, head −10°; trot and gallop; blows below |
| `iceMammoth` | 1.9, 13, 2.5 s, slam | never gallops: walk → amble above 1.5 L/s (same lateral sequence, duty 0.5, k 1.4); body bob 0.03 L, roll ±2.5°; trunk (if bones) a pendulum spring lagging the head; ears flap at 0.2 Hz; blows below |
| `rabbit` | 0.5, 11, passive, no Elites | §8 |

Bear, boar and mammoth blows (W as §1.2, contact at W, F + R ≤ 0.8 s):

| Kind, blow | A | S, contact | F + R |
|---|---|---|---|
| Bear, basic "swipe" (0.55) | weight back and left (x −0.05 L, z +0.08 L, roll −3°); right fore up (upper +55°, lower folded 70°, paw rolled out 15°); head yaw +15°, jaw 25° | the paw sweeps down and across (upper +55° → −5°, body yaw −8°), plants 0.3 L ahead at W; lunge ≤ 3 studs; head −10° | body follows left, jaw closes; R 0.35 |
| Bear, Elite II "slam" (1.4, circle r 11 around it) | 0-0.6: up on the hind legs (pivot at the hind feet): pitch +70°, y +0.4 L; forelegs high (upper +80°, lower −30°, paws open); neck +20°, roar jaw 40°. 0.6-1.26: hold, sway roll ±3° at 0.8 Hz, tremble ∝ p² | 1.26-1.4: falls forward (+70° → −6°), both forepaws slam at W (0.5 L ahead), y −0.06 L, dust ring r 11 | head low, roar; R to 2.1 |
| Bear kit | crush = the slam with A over 2.06 s (rear by 0.8); heavyBlow = a two-paw swipe (both forelegs, `alt` timing: right at W − 0.1, left at W); pounce = a low flat body-slam arc (height 1.5 studs) | | |
| Boar, basic "gore" (0.55) | head dips −20°, body z +0.08 L, front legs brace | head hooks up +30° with a yaw twist 15° at W; lunge ≤ 4 studs | head shake; R |
| Boar, Elite II "charge" (1.0, line 20 × 6; S162m: the boar runs the line the last 0.4 s, `Dash*` §10) | 0.2-0.7: front-right hoof scrapes twice (upper −25° / +10° at 3 Hz); head −25°, rear up 0.03 L, tremble | 0.86-1.0: dash forward (≥ 3, ≤ 5 studs) with the gallop running at 2× rate so the feet keep up; head hooks at W | skid stop; trot back over 0.5 s |
| Mammoth, basic "tusk" (0.55) | head yaw +25°, trunk curled up, weight back | head sweeps to −30° (tusks across) at W, lunge ≤ 2 studs | trunk swings on; R |
| Mammoth, Elite II "stomp" (1.4; also crush) | front rises ≤ 25° (pivot hind feet; elephants do not rear high), trunk up (trumpet), ears out | both front feet stomp at W, y −0.05 L, dust ring | trunk down; R |

## 4. F3 Flyer: ashVulture

### 4.1 Rig and sizes

Roles: wings (humerus, forearm, hand, primaries if any), legs (thigh, tarsus, toes), neck 1..n, head, beak (if any),
tail fan. `BoneRoles` takes only the top wing bone; the template needs the chain. The model floats (hover built into its
pivot, `Hover` attribute; hip height 2.88). Vulture at `LookScale` 0.8: body about 2.6 studs, wingspan to measure.
Ranged physical (`aw` st `arrow`, range 20, interval 1.6 s), Elite II own `wail`. Moves at 13 studs/s.

### 4.2 Wingbeat cycle

Phase `φ` in [0, 1): downstroke 0 → 0.45, upstroke 0.45 → 1. Frequency at scale 1, divided by √scale for bigger birds.

| Mode | Hz | Humerus elevation (up +) | Humerus sweep (forward +) | Forearm fold | Hand | Body |
|---|---|---|---|---|---|---|
| Hover (idle, shooting) | 1.7 | +55° → −35° (fastest mid-stroke), back up on the upstroke | +10° down, −15° up (a figure 8) | 0° on the downstroke, 45° at φ 0.70 | follows the humerus 0.06 cycle late (whip), twisted 20° on the upstroke | y +0.12 studs × scale at φ 0.40, −0.10 at 0.90; pitch ±3° (nose up at 0.40); tail counter-pitch ±5° |
| Forward flight | 2.0 | +45° → −30° | +5° / −10° | 0° / 35° | same | pitch −8° × (v / 13), bob ±0.08 |
| Hard flapping (after a hit, climbing, take-off) | 2.6 | +65° → −45° | +15° / −20° | 0° / 55° | same | y +0.2 at the end of each downstroke |
| Glide (straight flight over 1.5 s, 40 % chance every 3 s, 1-2 s, never in a fight) | none | held +8° (dihedral) | −5° | 5° | 0° | roll wobble ±2° at 0.7 Hz, pitch −5° |

- Enter a glide at the end of a downstroke (blend 0.2 s); leave it with a downstroke from the top (blend 0.15 s).
- Bank into turns: roll toward the inside = clamp(0.35 s × yaw rate, ±35°), spring 0.2 s; the outer wing beats 10°
  wider while turning in place.
- Braking (speed drops faster than 6 studs/s²): a flare, pitch +15°, wings swept forward +25° and up +40°, 0.3 s.
- Legs: tucked in flight (thigh −60°, tarsus folded 70°, toes curled 50°), hanging in a hover (thigh −20°, tarsus 20°,
  toes 20°).
- Neck and head: the head keeps its world height and pitch (the neck counters the body's bob and pitch); bird
  saccades: the head jumps to a new look in 0.08 s and holds 0.4-1.2 s (yaw ±40°); look-at the target when aggroed.

### 4.3 States

| State | Motion |
|---|---|
| Idle | hover cycle; slow figure-8 drift (x ±0.15, z ±0.1 studs at 0.2 Hz), yaw drift ±6°, head saccades |
| Alert | head snaps to the target, one hard flap, a short screech pose (neck +15°, beak 25°) for 0.3 s |
| Moving | forward flight with glides, banks and the stop flare (§4.2) |
| Going home | forward flight, no glide, head straight |

Basic shot "feather volley" (W = 0.5; Elite 0.6, Elite II 0.675; also the Elite II throw, W = 0.81):

| Phase | t (s) | Motion |
|---|---|---|
| Blend | 0-0.08 | the beat stops where it is and blends into the pose |
| A | 0-0.36 | flare: body pitch +20°, y +0.3 studs; wings high and back (humerus +70°, sweep −25°, forearm straight); neck back +15°; tail fanned |
| S | 0.36-0.5 | one violent downstroke (humerus +70° → −40°), body pitch → +5°, recoil z +0.25 studs |
| Release | **0.5** | the projectile leaves the chest / wing tips (muzzle bone) |
| F | 0.5-0.65 | wings low, head −10° (follows the shot) |
| R | 0.65-0.85 | the beat resumes at the upstroke (φ 0.45), no pop |

| Blow (W) | A | S, contact or release at W | F + R |
|---|---|---|---|
| Wail, Elite II own (1.2, cone 15 / 90°) | 0-0.3: rise +0.5 studs, pitch +15°, wings spread to full span and held (humerus +20°, forearm and hand straight), neck back +20°; beak opens to 30° by 0.9. 0.3-1.06: hold, small beats (±10° at 3 Hz) to stay up, tremble ∝ p² (body 1-2°, wing tips ±4° at 12 Hz) | 1.06-1.2: neck thrusts −30°, head −10°, beak 40°, wings snap forward (sweep +25°) and down 20°; recoil 0.3 studs at W | 1.2-1.5: the scream held (beak open, head shake ±5° at 8 Hz); R to 1.85 into the beat |
| Heavy Blow, Elite (1.8) "talon rake" | 0-1.2: rise +0.8 studs with hard flaps, legs swing forward (thigh +70°, toes open); 1.2-1.66: hover there, tremble | 1.66-1.8: swoop forward 1.5 studs and down 0.8, legs rake down (thigh +70° → −20°), mid-downstroke at W | pull up; R 0.5 s back to the hover point |
| Crush, Elite II (2.2) "stoop" | 0-1.6: climb +3 studs with hard flaps, turning toward the target; 1.6-1.9: wings fold (humerus −10°, forearm 80°), pitch −50° | 1.9-2.2: dive along an arc toward the target, at most 6 studs out and down to 0.3 studs above the ground; talons forward, wings flare open (humerus +60°, sweep +20°) at W | pull up; R 0.5 s back to the hover point |
| Pounce, Elite II (1.4; teleported at W) | 0-1.0: hover low (y −0.4), wings cocked high | 1.0-1.4: the leap arc (§3.6 pounce) with hard flaps at 3 Hz, talons forward at W | hover settles; R |

### 4.4 Hit, stun, death

| State | Motion |
|---|---|
| Hit | pushed away 0.35 studs and down 0.25, roll away 12°, wings flare up +30° for 0.06 s, then two hard beats at 3.5 Hz; back on the cycle in 0.4 s; a feather puff |
| Stun | irregular flutter (2-4 Hz, amplitude 60 %), body sinks 0.6 studs and wobbles (roll ±8° at 0.9 Hz) |
| Freeze | the pose holds (frozen in the air is fine) |
| Death | 0-0.1: jolt. 0.1-0.5: the wings stop, one folds up (humerus +60°, then folded), the other hangs; nose down −30°; it **falls with gravity**: `y = −H · ((t − 0.1) / 0.4)²` (H = hover height × scale), rolling 60° to the seed side. 0.5: impact, bounce +0.12 studs for 0.08 s. 0.5-0.8: lies on its side (roll 100°), one wing spread on the ground, the other folded over, neck limp (head on the ground), toes curled 60°. Feather burst at the impact (no gore) |
| Spawn (`Summoned`) | up from the ground (y −1 → hover) with hard flaps |

### 4.5 Rollout

| Kind | Changes |
|---|---|
| `peakHarpy` | upright torso (pitch +55° from the vulture's), wing-arms; legs with talons dangle and grasp; the shot (lightning, `arrow`) is a forward fling of both wing-arms (sweep +30°) released from the wing tips; wail: wings wide, head thrown back, then forward; death: tumbles backwards |
| `wyvern`, `vaelgrath` in the air | the hover / flight cycle at 1.1-1.3 Hz, legs tucked, tail as a rudder (yaw ±15° in turns); see §5.8 |
| `carrionCrow`, `bloodBat` | rigid: §6.4 |

## 5. F4 Dragon: youngFrostDragon

### 5.1 Rig and sizes

The F2 roles plus wing chains (humerus, forearm, hand / fingers, membrane bones if any), a long neck chain, jaw and a
long tail. At `LookScale` 1.6: `h` ≈ 8 studs, `B` ≈ 6.7, estimated `L` ≈ 3.0. Melee (interval 2.0 s), Elite II own
`frostBreath`, 13 studs/s → about 4 L/s.

**Folded wings first.** If the Tripo rest pose has the wings spread, the dragon needs a folded base pose for the
ground: about humerus elevation −20° and sweep back −60°, forearm fold 110-130° (the hand comes back along the body),
hand fold 80-100°; tune on the model until nothing clips from the three AnimLab cameras. Folding or unfolding takes
0.5 s (smooth, the forearm leads the hand by 0.1 s).

### 5.2 Locomotion

| Gait | v / L (up; down) | Footfall | Duty | k | Spine and tail | Neck and wings |
|---|---|---|---|---|---|---|
| Walk | < 1.8; 1.6 | lateral sequence (as the wolf) | 0.7 | 1.0 → 1.2 | reptilian S-wave: spine yaw ±6° running from the shoulders to the tail tip, 0.15 cycle lag per bone, tail tip ±12°; shoulder roll ±3°; heavy bob 0.03 L | the neck counter-sways so the head stays steady; wings folded, a slight bob with the shoulders |
| Trot | 1.8-3.0; 1.6 / 2.8 | diagonal pairs | 0.5 | 1.5 → 1.8 | wave ±3°, tail raised +5° | head steady |
| Bound | > 3.0; 2.8 | LH 0, RH 0.05, LF 0.45, RF 0.50 | 0.35 | 2.6 → 3.0 | sagittal flex ±10° (extended at the hind push-off, flexed in the flight); tail straight back, +10°, as a counterweight | neck lowered forward −10°; wings half open (humerus +15°, forearm fold 60°) and pumping once per stride: downstroke during the hind push-off (φ 0-0.25), ±15° |

Turning: heavy, turn smoothing ω 6, feet re-plant (§1.5); the tail swings out of the turn by 0.5 × the body's yaw lag.

### 5.3 Idle and alert

| State | Motion |
|---|---|
| Breathing | chest / spine pitch ±1.5° at 0.25 Hz; frost mist from the nostrils on each exhale (VFX) |
| Neck | slow S-sway: yaw ±8° along the chain at 0.15 Hz; reptilian looks: a new target every 2-4 s, moved in 0.6 s |
| Tail | slow wave ±6°; every 3-6 s a tip flick (tip yaw ±20°, 0.3 s) |
| Wings | every 8-15 s resettle: half open (40 %) and fold again, 1.2 s |
| Alert | neck up +20°, jaw 30°, wings half open for 0.6 s (a short roar; sound from the family) |

### 5.4 Basic blow: bite (W = 0.55)

| Phase | t (s) | Motion |
|---|---|---|
| A | 0-0.41 | the neck coils into an S (neck 1 +15°, neck 2 −10°, neck 3 +15°; the head pulls back 0.25 L), jaw opens 35°, front legs brace, wings twitch 5° open |
| S | 0.41-0.55 | the neck uncoils (every neck bone to −8°), head forward 0.4 L, lunge ≤ 3 studs; jaw 35° → 0° in the last 0.06 s |
| Contact | **0.55** | jaw shut at the target |
| F | 0.55-0.75 | head yanks back 10° and turns ±10° |
| R | 0.75-1.1 | base |

### 5.5 Elite II own ability: frost breath (W = 1.3, cone 17 / 60°)

| Phase | t (s) | Motion |
|---|---|---|
| A1 | 0-0.5 | the head rears: neck 1 +25°, neck 2 +15°, head +20°; chest swells (spine pitch +6°); wings mantle up and forward (humerus +35°, forearm fold 70°); jaw 10°; frost glow in the throat starts (VFX) |
| A2 | 0.5-1.16 | hold, tremble ∝ p², the glow grows; front feet dig in |
| S | 1.16-1.3 | the neck drops forward and down so the maw points along the cone, 10° below horizontal (neck 1 −15°, neck 2 −10°, head −20° to the body); body pushes forward 0.15 L |
| Release | **1.3** | jaw 45°, the breath starts at the jaw bone |
| F (breath held) | 1.3-1.8 | jaw stays open; the head sweeps the cone, yaw −15° → +15°; body recoils 0.1 L (thrust) |
| R | 1.8-2.3 | jaw closes, neck back, wings fold (0.5 s) |

### 5.6 Kit blows

| Blow (W) | A | S, contact at W | F + R |
|---|---|---|---|
| Heavy Blow, Elite (1.8, cone in front) "claw rake" | rear 20° (pivot at the hind feet), right fore high (upper +60°, claws open), neck back, jaw 30° | the claw rakes down and across (body yaw −15°, upper +60° → −10°), plants at W | R 0.5 |
| Crush, Elite II (2.2) "rear and stomp" | 0-0.8: up on the hind legs, pitch +50°, wings fully open (humerus +40°, forearm and hand straight), neck high, roar jaw 40°. 0.8-2.06: two slow balance flaps at 1 Hz, tremble ∝ p² | 2.06-2.2: both forefeet slam and the wings beat down (humerus −20°) at W; dust and frost ring | head low roar; R 0.6 (wings fold) |
| Pounce, Elite II (1.4; teleported) | 0-1.0: crouch, wings half open and cocked | 1.0-1.4: one huge downstroke at 1.05 (launch), glide on the leap arc, lands at W with a wing flare and the forefeet | wings fold over 0.5 s |
| Throw, Elite II (0.81) "frost spit" | neck back +20°, jaw 25°, throat glow | neck thrust, release at the jaw at W | R |

### 5.7 Hit, stun, death

| State | Motion |
|---|---|
| Hit | push 0.08 L, lean 5°; neck recoils and the head turns 12° toward the attacker; wings twitch open 10° and fold again; tail lash (tip yaw 20° away) |
| Stun, freeze | as the wolf (§3.7); wings droop 10° when stunned |
| Death | 0-0.12: jolt. 0.12-0.4: hind legs buckle, then the fore. 0.4-0.7: the wings half open and go limp (spread on the ground: humerus −10°, forearm fold 40°), roll 80° about the ground line on the seed side (Appendix A); the neck falls in an S onto the ground (each neck bone −10°), jaw slack 20°. 0.7-0.8: settle, a last tail-tip flick at 0.75; a frost mist puff |

### 5.8 Rollout

| Kind | Changes |
|---|---|
| `wyvern` | the wings are its forelegs: on the ground it walks on the hind legs and the wing wrists (the hand bones are the front feet; lateral sequence; wings folded along the arm); the run is wing-assisted bounding (a half beat on each bound). Ranged fire (`aw` st `arrow`, 0.5): "spit shot", neck back +20°, jaw 25°, throat glow, release at the jaw at W with a neck thrust. Elite II `fireBreath`: §5.5 with fire. Stays a ground monster (its hitbox and hip height are on the ground; §9 Q5) |
| `vaelgrath` (boss) | the dragon template for idle, ground locomotion, hit and death; `Flying` (true from its boss script): the flyer cycle at 1.1 Hz (§4.2), legs tucked, neck forward, tail rudder; take-off (false → true): 0.6 s crouch and two huge flaps; landing (true → false): flare (pitch +25°, wings forward), legs out, impact squash 0.05 L. Its attacks keep their `Data/BossMotions` gestures on top |

## 6. F5 Rigid models: caveSpider

### 6.1 What a rigid model can do

No bones, so no limb bends. The whole look moves on `Gait_Body` (rotation and offset), around any pivot
(`CF(p) · R · CF(−p)`). On top:
- **Transparency**: `LocalTransparencyModifier` per part (fades, flicker, dissolve).
- **Squash and stretch**: `MeshPart.Size` can be written at runtime and scales the mesh non-uniformly about its centre.
  Use it only if the look is **one** visible MeshPart (audit §1.9; several welded parts would drift apart), only during
  short events (blows, landings, hits, deaths), only for the nearest 8 rigid monsters, volume-preserving
  (`sy = s`, `sx = sz = 1 / √s`, s in [0.85, 1.15]), and move the motor by `(s − 1) · hMesh / 2` in y so the feet stay on
  the ground. Never `Model:ScaleTo` per frame (it rebuilds every part). Check the cost with `/animlab stress`; if it
  shows, drop squash, it is polish.
- If the audit finds separate parts (legs, wings, a jaw), they can be turned into Motor6Ds at build time and swung like
  generator joints: a big win for that model.

Rigid vocabulary (combine per kind):

| Tool | How |
|---|---|
| Step bob | y = A · \|sin(2π n φ)\| with n bumps per gait cycle (gait clock by distance, §1.6) |
| Weight sway | roll ± a few degrees at 1× the cycle |
| Wiggle | yaw oscillation at 1× the cycle, about the centre (lizards: head and tail swing opposite) or about a point near the head (snakes: the head stays, the tail sweeps) |
| Surge | z offset: lunges, recoils, the burst-and-stop of insects |
| Rear and dip | pitch about the hind contact (front up) or the front contact (rear up) |
| Hop arc | `Gait.leapArc` offsets: hops, leaps, pounces |
| Shiver | value noise at 15-25 Hz, 0.5-2°: tension, fear, stun |
| Turn lag and bank | the spring of §1.5 plus roll into the turn |
| Flip, topple | roll / pitch 90-180° about a ground edge or the body centre (Appendix A) |
| Fade, sink, rise | transparency, y offset (ghost deaths, spawns) |

### 6.2 Cave spider: sizes and locomotion

At `LookScale` 1: `h` ≈ 3.4 studs (visual 1.45), body ≈ 2.2 studs; melee (interval 1.67 s), Elite II own `poisonPool`,
13 studs/s.

| State | Motion |
|---|---|
| Skitter (moving) | stride = 0.9 × body length (≈ 2 studs → ≈ 6.5 Hz at 13 studs/s); step bob 0.04 h with 2 bumps per cycle (the two leg tetrads); roll ±2.5° at 1× the cycle (the tetrad swap), yaw ±1.5° a quarter cycle later; pitch −5° (nose down) at speed; a burst modulation of the bob (×0.7-1.0 at 0.8 Hz) so it feels like spurts |
| Start | 0.1 s squat (y −0.05 h), then the skitter |
| Stop | overshoot 0.1 studs forward and back in 0.15 s (inertia), roll wobble ±2° fading |
| Turning | turn spring ω 14 (spiders turn fast), bank 4° into the turn |
| Idle | low crouch (y −0.02 h); breathing bob ±0.01 h at 0.5 Hz; a twitch every 2-6 s (yaw jerk ±5° in 0.12 s, held); a re-settle dip (y −0.03 h, 0.2 s); now and then "tasting the air" (pitch +6° held 0.6 s) |
| Alert | rear about the hind contact (z +0.4 × body length): pitch +18° in 0.15 s, held 0.25 s with a shiver (±1° at 20 Hz), dropped in 0.1 s with a thump (y −0.03 h, squash s 0.92 if allowed) |
| Going home | skitter with the burst modulation off, no alert |

### 6.3 Cave spider: blows, hit, death

| Blow (W) | A | S, contact or release at W | F + R |
|---|---|---|---|
| Bite (0.55; Elite 0.66, Elite II 0.74) | 0-0.41: rear about the hind pivot, pitch +14°, body z +0.2 studs, y +0.05 h; shiver 0.5° → 1.5° at 22 Hz | 0.41-0.55: the front slams forward and down (pitch → −10° about the hind pivot), surge `D` (§1.7, at least 0.6 studs), a hop y +0.1 h at 0.48 coming down at W; squash s 0.9 at W (back over 0.12 s) | 0.55-0.7: stays forward, yaw shake ±4° (worrying); 0.7-0.95: recoils back to z 0 with a small back hop (y +0.05 h): spiders retreat after a bite |
| Poison pool, Elite II own (1.3, circle r 8 under the target) | 0-0.4: rear high (pitch +22° about the hind pivot, y +0.1 h). 0.4-1.16: hold; venom pump: pitch ±3° at 3 Hz (stretch s 1.06 on the pump peaks if allowed), shiver ∝ p² | 1.16-1.3: snaps forward (pitch → −8°), recoil z +0.25 studs at W = the spit leaves the front top (muzzle point) toward the circle | 1.3-1.5 held low; R to 1.85 |
| Heavy Blow, Elite (1.8, cone in front) | rear to +25° by 1.2 with a slow weave (yaw ±8° at 1.2 Hz) and a shiver | 1.66-1.8: crashes forward (pitch −12°), surge −0.8 studs, yaw sweep 30° across (right to left) at W | R 0.5 |
| Crush, Elite II (2.2) | rear to +30°, three venom pumps, large shiver ∝ p² | slams the front down at W (dust ring); a venom glob arcs to the circle (VFX) | R 0.5 |
| Pounce, Elite II (1.4; teleported) | 0-1.0: cocked crouch (y −0.08 h, pitch −6°: rear up, front down), a hind wiggle | 1.0-1.4: leap on the arc (height `clamp(0.3 × distance, 2, 7)` studs), body pitch along the tangent (+25° up, −30° down); lands at W: squash s 0.85 (or y dip −0.06 h), skid 0.3 studs | a bounce and a shiver; R |
| Throw, Elite II (0.81) | a short rear (+15°) with one pump | the spit at W | R |

| State | Motion |
|---|---|
| Hit | pushed 0.2 studs away and tilted 10° away about the far-side contact (so it tilts as if on legs), y −0.03 h; envelope §1.5 |
| Stun | wobble roll ±6° at 1.1 Hz, pitch ±3°, y −0.04 h, a random twitch every 0.5-1 s |
| Freeze | holds, shiver 0.5° |
| Death (variant 1, 60 %) "flip" | 0-0.1: jolt up (y +0.08 h) and back. 0.1-0.55: flips onto its back: roll 180° (seed side) about the body centre `(0, c, 0)` (audit), with an arc (y +0.3 h at 0.33 s), landing upside down: y shift `h_top − 2c` so the back rests on the ground. 0.55-0.8: bounce (+0.04 h → 0), two death twitches (roll ±4° at 0.62 and 0.72) |
| Death (variant 2, 40 %) "curl" | y −0.12 h and pitch −4° (legs fold under), squash s 0.8 if allowed, a slow roll 25° to the side, one twitch |
| Spawn (`Summoned`) | out of the ground (y −h → 0 over 0.6 s) with a shiver and a final hop |

### 6.4 Rollout to the other rigid models

| Kind (size, speed, blow, Elite II own) | Recipe |
|---|---|
| `basilisk` (0.8, 13, melee, poisonPool), `salamander` (1.1, 13, melee, fireBreath) | lizard waddle: wiggle yaw ±10° about the centre at 1× the cycle (stride 0.8 B), x sway ±0.08 studs against the yaw, roll ±3°, small bob at 2×; idle push-ups (y +0.05 h twice at 3 Hz every 5-10 s) and head-up pauses; bite = a yaw wind (+12°) then a fast yaw snap (−20°) with surge; breath / spit = front rises 15° about the hind contact, held with a shiver, forward −6° with a recoil at W, the stream from the snout (muzzle point); death = flip onto the back (as the spider) |
| `bogSerpent` (1.1, 13, melee, poisonPool), `frostWyrm` if rigid (1.1, 13, melee, frostBreath) | slither: wiggle yaw ±12° about a point 0.35 B behind the head (the head stays, the tail sweeps), stride 0.8 B, x offset ±0.15 studs against the yaw, roll ±4°; idle cobra sway (yaw ±10° at 0.4 Hz, pitch bob ±2°); strike: coil back (z +0.4, front up +10°, squash s_z 0.9) then lunge (z −`D`, stretch s_z 1.12 at W) and back; spit / breath: front up +15°, held, forward at W; death: sinks 0.2 studs, slow roll 90°, fade |
| `carrionCrow` (0.6, 13, ranged arrow, wail), `bloodBat` (0.7, 13, melee, wail) | no wings to flap: flight is sold by the body: crow vibrato bob ±0.06 studs and pitch ±4° at 4 Hz; bat erratic flutter: bob ±0.1 at 6 Hz plus lateral jitter ±0.08 studs at 3 Hz (noise); bank into turns ±25°; figure-8 drift in a hover. Blows: dive = rise +0.6 studs in A, swoop forward and down along an arc (≤ 3 studs) to contact or release at W, pull back up in R; wail = rear pitch +25° with a shiver, thrust −15° and recoil at W. Death: gravity fall (§4.4 formula) with a yaw spin of one turn, a bounce and a flip. Strongly recommended: wings as separate parts or a Tripo avian rig (§9 Q4) |
| `swampToad` (0.7, 11, melee, poisonPool) | hops instead of steps: hop rate ≤ 3 Hz, hop length = v / rate, height 0.35 × hop length (≤ 0.8 studs × scale); each hop: crouch 0.06 s (y −0.08 h, squash s 0.85), launch (stretch s 1.1), land squash; idle: breathing bob, an occasional settle; basic "squash": a squeeze down then a forward lunge with stretch at W; spit: inflate (s_x, s_z 1.08 if allowed) with a shiver, recoil at W; death: belly-up flip and a slow sink |
| `rotEnt` (1.5, 9, melee, slam) | heavy tree: a big slow sway, roll ±5° at 1× the cycle about the base, yaw ±4°, pitch 3° forward, small bob at 2×; creak and falling leaves on each step; "branch" blow: lean back 12° about the roots, whip forward −18° at W; slam: rise 0.3 studs and lean back 10° in A, crash down (y −0.15, pitch −6°) at W with a root and dust ring; death: topples 85° about the base edge (seed side; easeIn, gravity), bounce 4°, sinks 0.3 studs and fades with splinters. A treant rig would help most (§9 Q4) |
| `specter` if rigid (1.0, 13, ranged bolt, wail) | float: bob ±0.15 studs at 0.45 Hz, roll / pitch sway ±3° at 0.3 Hz, lean −12° into the move with a drift lag 0.25 s; trailing wisps by a Trail / particles; phase flicker: transparency 0.15-0.35 at 0.5 Hz; shot: rear +10°, rise 0.3, shiver, lunge 0.6 studs with a transparency dip at release (W); wail: rise 0.8 and grow (s 1.08 if allowed), thrust at W; death: rise 1.5 studs, yaw 90°, transparency to 1 by 0.8 s, wisp burst |
| `iceElemental` if rigid (1.2, 13, ranged bolt, frostNova) | float as the specter without the flicker; separate crystal parts (if any) orbit slowly; nova: compress (s 0.9) and shiver in A, burst to s 1.1 at W with a flash; death: shatter (fade by 0.4 s with ice shards) |
| `desertScorpion` if rigid (1.3, 13, melee, poisonPool) | spider skitter with 1.5 bumps per cycle and a heavier bob; pincer blow = a front rise and a forward surge at W; sting = pitch nose-down 10° in A (the tail goes up), a jab forward at W |

### 6.5 As built (2026-10-26)

`Logic/RigidMotion` + `Data/RigidStyles` (recipes) + `Data/RigidRigs` (bone chains) + `client/Anim/RigidRig`, picked by
`motion` in `Data/MonsterAssets` like the other families. The rig dump (`tools/anim/rigs`, fcde9b38) has no bones in any
rigid kind except `frostWyrm`; every look is one visible MeshPart, so all may squash. Deviations from §6.1-6.4:

- **Units**: a recipe's x is in body widths `W`, y in mesh heights `hMesh` (a flyer's hover `lift` below it), z in body
  lengths `B` of the drawn box (the spider's `B` is the leg span, 6.7 studs drawn: stride 0.3 B is the spec's ≈ 2 studs).
  The box is measured on the clone at runtime (the visible parts in the PrimaryPart's frame).
- **Driver**: the `Gait_Body` motor when the template has `Hover`, else the look's `LookWeld` (`C0 · T`); AnimLab's
  anchored preview directly. **Transparency** writes `Transparency`: `LocalTransparencyModifier` stays MonsterView's (the
  hidden look, the corpse fade).
- **Squash**: three volume-kept controls (`sq` vertical, `sl` along the body, `gr` grow), each axis clamped to
  [0.85, 1.15], the bottom kept on the ground; only the 8 rigid looks nearest to the camera (re-picked every 0.25 s),
  Size written only when it changes by > 0.3 %. A look that may not squash sinks by 35 % of a squash instead.
- **Pivots**: `rear` about the hind contact, `dip` about the front contact, `tip` about the ground edge under a flank
  (rocks, deaths), `bow` / `lean` about the ground centre, `wig` about `wigPivot` (a snake's head stays); the contacts lie
  at the style's `footprint` share of the box. Deaths and flips never put the box under the ground (`ground`) and come
  to rest on it (`settle`).
- **Gaits by the server's intent**: a style with several gaits takes them from `Gait` (cat: walk / trot / gallop;
  lizard: waddle / sprint), not from speed over body length (a big snow leopard would trot at its walk speed).
- **Hops** (toad, hare): the body pitches about its feet (nose down about the fore feet as it lands, up about the hind
  feet as they push) and stays put on the ground, catching up in the air: no sliding (Lune spec).
- **Flights**: the pounce and the cat's leap fly on the server's `Dash*` arc (offset from the root, the body pitched
  along the tangent within +25° / −30°), held 0.5 s on the landing point until the teleport arrives; with no flight
  announced the body stays where it is (AnimLab, without a server, flies its own arc to the actor).
- **Appear**: `spawn` (fade in out of a crouch, rise, shake off) when the look is built within 0.6 s of `SpawnedAt`,
  `summon` (climbs out of the ground; a flyer drops in) for `Summoned`; a look built late still plays it.
- **Handover**: an action cut short by another (or by the death) blends its pose over 0.12 s; fidgets are added over
  the idle.
- **Muzzle**: while an action plays, the root's `Muzzle` moves with the body (client side), so shots leave the drawn
  beak or jaws.
- **frostWyrm** (23 Tripo bones): the serpent recipe drives its chains: a travelling wave down the tail (`Tail_0..8`) and
  the coil (`bone_1..5`, half), amplitude growing to the end (5° a bone in place, 16° moving, phase by distance), the
  neck (`bone_6`, `Head_0..4`) takes the cobra sway and the strike's pull back / lunge, the head (`Head_5`) keeps level;
  the whole body wiggles at a quarter. Without the bones it falls back to the rigid slither.
- **Cats** (`lynx`, `snowLeopard` on the lynx model): rigid `cat` recipe: a 4-beat walk (4 dips a cycle, pitch rocking
  front / back twice, roll), trot, gallop (one suspension, pitch ±7°, surge), crouched stalk while fighting at a walk,
  hiss at the first aggro, swat-and-bite (weight back, rear-up 14°, a forward surge with the front coming down at W, a
  head toss), the leap on the `Dash*` arc (crouch, rear wiggle, stretch, landing squash at W), death on its side.
- **Deaths per kind** (two each, by the seed; the side away from the last blow from a side): spider flip 60 % / curl
  40 %; scorpion flip / curl 50 / 50; lizards flip 70 % / side 30 %; serpents sink onto the side and fade 60 % / writhe
  (thrash, flop, the tail stills) 40 %; crow falls on its side 60 % / back 40 % (bat the other way round); toad flip
  70 % / curl 30 %; hare on its side 60 % / a last leap and roll 40 %; cats on the side 65 % / slump (legs give way)
  35 %; rot ent topples sideways 85° about its base edge 60 % / on its face 40 %, and fades.
- AnimLab: `/animlab mob <id> <state>`, states `Data/RigidStyles.labStates`: idle, alert, walk, trot, run, turn, home,
  attack1, attack2, cast, heavy, crush, pounce, throw, hit, hitBack, hitLeft, hitRight, stun, freeze, death, spawn,
  summon, fight, then every action of the style by name (e.g. `deathCurl`, `sting`, `sitUp`).
- Not done: sounds and leaves on the ent's steps, the dust and venom VFX of §6.3 (the poses are timed for them).

## 7. Ghosts, golems, brutes: which template covers them

| Kind | Rig | Template |
|---|---|---|
| `forestWraith` | bones (Mixamo, clips) | F1, ghost subtype (§2) |
| `specter` | static (bones not confirmed) | F5 float recipe (§6.4); if it has bones, F1 ghost subtype with procedural clips |
| `fireGolem`, `magmaGolem`, `crystalGuardian`, Azgor | bones (Mixamo, clips) | F1, golem subtype (§2) |
| `iceElemental` | static (bones not confirmed) | F5 float recipe |
| `rotEnt` | static, no bones (Studio) | F5 heavy tree recipe |
| `werewolf`, `swampTroll`, `yeti`, `ghoul` | bones (Mixamo, clips) | F1, brute subtype (§2) |

## 8. Small critters: hare, toad

- `rabbit` (passive, no Elites, 11 studs/s, `LookScale` 0.5, `h` ≈ 1.9 studs): if the audit finds a quadruped skeleton,
  use the F2 code with a **bound** gait set only (2026-10-26: the dump found no bones: F5 `hare` recipe, §6.5): hind pair together then fore pair (LH 0, RH 0.02, LF 0.45, RF 0.50),
  duty 0.25, hop rate ≤ 4 Hz, hop length = v / rate, a body arc of 0.3 × hop length (≤ 0.8 studs × scale). States:
  idle (nose twitch bursts: head pitch ±2° at 8 Hz for 0.3 s; ears swivel; sit up now and then: pitch +35° about the
  hind feet, 1.5 s), bound, bite (the wolf's bite at 60 % amplitude), hit, death (side roll). No kit, no ability, no
  IK needed (feet barely touch). Without bones: the F5 toad hop recipe.
- `swampToad`: F5 (§6.4); the hop is the whole locomotion.
- Light means: no look-at springs, no fidgets beyond one, tier B always.

## 9. Requests outside animation code, blockers, open questions

Owner decisions (recommended default first):

- **R1 / Q1 wander speed** (done S162m, §10): monsters wander at full chase speed (13-14 studs/s), so a walk or trot is
  never seen and a resting pack sprints back and forth. Recommended: wandering at 0.4 × `moveSpeed` (a new
  `Combat.wanderSpeedMul`), full speed from the first aggro on.
- **R2 / Q2 melee approach** (done S162m, §10): monsters stop at the edge of their reach (~8.5 studs), so blows hit
  the air. Recommended: walk on to 0.6 × reach before stopping; the hit check stays as it is (reach × 1.5 + 3).
- **R3 / Q3 respawn animation** (done S162m, §10): a regular respawn sends nothing the client can tell from a model
  streaming in. Recommended: an attribute `SpawnedAt` (server time) and a 0.5 s appear (§3.8).
- **Q4 rigs for the rigid models**: no limb can bend on F5. Recommended: Tripo re-rigs (octopod for `caveSpider`, avian
  for `carrionCrow` and `bloodBat`, serpent for `bogSerpent` and `frostWyrm`, biped for `rotEnt`), or at least wings and
  legs exported as separate parts (Blender) so they swing as rigid joints. Spider and crow first (seen most).
- **Q5 wyvern in the air**: its hitbox and hip height are on the ground; a permanent visual hover would float it over
  its own target ring. Recommended: ground monster with wing-assisted hops (§5.8).
- **Q6 canine leap landing** (owner 2026-10-25: the server moves it; done S162m, §10): the wolf's own `leap` does not
  move it (only `pounce` does). Recommended: keep the server; the visual leap and walk-back of §3.5. Alternative:
  `leap = true` on the ability (the wolf really lands, a fight change).

Blockers and checks for the Studio session:

1. AnimLab does not drive `BoneGait` (§1.4 item 11): add template support before any approval round.
2. Bone audit (§1.9) not done from here: the model files are only in the place (`assets/Monsters` in the repo holds
   none). Unknown until then: jaw, ear and toe bones on the Tripo quadrupeds (without a jaw bone, bites and breath use
   head pitch only), whether the dragon's wings rest spread (needs the folded base pose, §5.1), the bone counts of necks
   and tails, and whether `desertScorpion`, `iceElemental`, `specter`, `frostWyrm`, `rabbit` have bones.
3. F5 squash depends on a single MeshPart look; otherwise CFrame-only motion.
4. Visual reach needs R2 to look like contact; without it, the lunges of §1.7 close at most ~4 of the ~5 studs.
5. Pounce arcs need the leap arc of `AnimationController` enabled for non-boss `leap = true` abilities (S162m: the
   server publishes every non-boss flight as `Dash*`, §10).
6. The release point of shots needs a muzzle bone handed to `CombatFxController` (§1.3 item 8) (S162m: the root's
   `Muzzle` attachment, §10; move it to the bone on the client).

## 10. Server data for animations (S162m)

Done on the server for §9 R1, R2, R3, Q6 and §1.3 rule 8 (owner 2026-10-25: "decide yourself, best quality"). Everything
sits on the monster's model in `workspace.Monsters` and replicates; times are server time (`Workspace:GetServerTimeNow()`
on the client too). Rules in `Logic/MonsterMove` (Lune spec `tests/monstermove.spec.luau`).

| Data | What the client gets |
|---|---|
| attribute `Gait` | `"walk"` idle (wandering, a champion's patrol, spreading back to its spot): `Combat.wanderSpeedMul` 0.4 × `moveSpeed`; `"trot"` going home (`Returning`): `returnSpeedMultiplier` 0.7 ×; `"run"` fighting (chase, cast): × 1. Wolf 5.6 / 9.8 / 14 studs/s, the usual kind 5.2 / 9.1 / 13, golems 3.6 / 6.3 / 9. There is no "idle" value: standing vs moving comes from the root's speed (a wanderer at its point stands with `Gait` "walk"). Slows scale the speed, not `Gait`; `Humanoid.WalkSpeed` (replicated) is the exact speed asked for |
| melee approach | a melee monster walks on to `max(0.6 × reach, half its root depth + 1.5)` from the target's centre (wolf 5.1 instead of 8.5) and then stands facing it; it may start a blow (`aw`) anywhere within its reach, so a draw can start while it still closes in (at most ~0.25 s of walking). The hit rule is unchanged. Ranged monsters stand at their reach |
| attribute `SpawnedAt` | server time of the spawn: every spawn (a respawn, a sleeping group woken by a player 250 studs away, world events, bosses and their helpers). Play the appear (§3.8) when the look is built within ~0.6 s of it; `Summoned` keeps its own climb |
| attributes `Dash*` | a flight of an ability with `dash` (`Data/MonsterAbilities`), set with its telegraph (`tele`), `DashAt` last: `DashId` (ability id), `DashMode` (`"move"`: the root runs the path from `DashAt`; `"jump"`: the root stays and is teleported at `DashAt + DashTime` = W), `DashFrom`, `DashTo` (Vector3, root positions), `DashAt` (when the flight starts), `DashTime` (s), `DashArc` (studs of the apex over the straight line). `DashAt = nil` = cancelled (stun, root). Draw: `k = MonsterMove.flightProgress(now, DashAt, DashTime)` (nil outside the flight), the body at `Gait.leapArc(k, DashFrom, DashTo, DashArc)` as an offset from wherever the root is now: the same rule for both modes. The attributes stay after the landing (k = nil); none are set when the monster already stands at its landing or may not land (a ledge over 6 studs, a safe zone, past the hard leash) |
| which flights | `leap` (Elite II wolves, cats, hyena): move, 0.35 s (flight 0.85-1.2), apex 0.35 × travel within 1.2-4 studs × LookScale, a short hop (usually 1-4 studs) to the melee approach distance in front of its circle; `charge` (Elite II boar): move, 0.4 s (0.6-1.0), apex 0, up to 20 studs along its line to stand in front of where the target stood (~37 studs/s; the feet need the gallop at ~3× rate); `pounce`: jump, 0.4 s (1.0-1.4), apex 0.25 × distance within 2-6 × LookScale; `warlordLeap` (Invasion commander): jump, 0.5 s, 3-8. Bosses keep their own leap (`Data/BossMotions` arc) without `Dash*` |
| attachment `HumanoidRootPart.Muzzle` | where shots leave the drawn body (`Data/MonsterRelease`: shares of the drawn height per body plan, per kind where needed: biped hand, quadruped jaw, flyer beak, dragon jaw, crawler front, serpent head, spirit front). The server starts regular shots and the Elite II throw at it; `CombatFxController` starts its fallback projectiles there. The animation may set its `WorldCFrame` to the jaw / beak / hand bone each frame (client side only; the server's start is from its own copy) |
| event `hz` field `rl` | a regular shot's release point (Vector3, the Muzzle at the shot); `Vfx/HazardFx` draws the bolt dropping from it to its flight height (`Hazards.BOLT_HEIGHT`) over its first 8 studs |

Gameplay notes (`tools/balance_reasons`, S162m): damage, areas, windups and intervals are unchanged; a monster going
home is easier to catch and teleports only after 20 s (was 12); an Elite II boar stands at its target after a charge
(its next blow up to ~1 s sooner); shots start 0.6-2.9 studs closer to the target.

## Appendix A: formulas

Gait clock (per frame):

```
v      = smoothed flat speed of the root (studs/s, 0.1 s smoothing)
gait   = pick(v / L) with hysteresis (tables above)
k      = lerp(gait.kMin, gait.kMax, clamp((v / L - gait.from) / (gait.to - gait.from), 0, 1))
phase  = (phase + v * dt / (k * L)) % 1
leg p  = (phase - gait.offset[leg]) % 1;  stance = p < gait.duty
```

Two-bone leg IK in the leg's plane (model space, pitch only):

```
hip  = the upper bone's pivot after the spine and body pose
T    = the foot target (planted world point taken into the model frame, or the swing path)
l1   = |knee_rest - hip_rest|,  l2 = |ankle_rest - knee_rest|
d    = clamp(|T - hip|, 0.05, 0.999 * (l1 + l2))
aT   = pitch of (T - hip) measured from straight down
aK   = acos((l1^2 + d^2 - l2^2) / (2 * l1 * d))
upper pitch = aT ± aK         -- the sign keeps the knee on its rest side
lower pitch = upper pitch ∓ (pi - acos((l1^2 + l2^2 - d^2) / (2 * l1 * l2)))
Δ(upper) = upper pitch - rest upper pitch;  Δ(lower) = lower pitch - rest lower pitch
C(upper) = Rx(Δ(upper) - Δ(parent));  C(lower) = Rx(Δ(lower) - Δ(upper))
paw: in stance keep its rest world pitch (flat); in swing add the curl of the tables
```

Critically damped spring (per frame): `a = ω² (target − x) − 2 ω v;  v += a dt;  x += v dt` (dt ≤ 1/30; substep
above).

Death roll onto the side, rolling toward side `s` (−1 left, +1 right) by θ (easeIn over its span):

```
p = (s * halfWidth, 0, 0)                       -- the ground line under that flank
body = CF(p) * CFrame.Angles(0, 0, -s * θ) * CF(-p)
```

`halfWidth` = half the body width at the ribs (audit), so at θ ≈ 85-90° the flank rests on the ground instead of
sinking. A flip onto the back (F5) turns 180° about the body centre `(0, c, 0)` and then shifts by `h_top − 2c` in y.
