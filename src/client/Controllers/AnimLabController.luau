--!strict
-- AnimLab (S110, docs/ANIMACJE.md): the motion review stage of the admin, in Studio only. "/animlab" (server:
-- Admin/Combat, studioOnly) sends the parsed call here through "AdminClient"; the Studio MCP session calls the same
-- commands through the local BindableFunction Players.LocalPlayer.AnimLabCall (a line in, JSON out). The stage floats
-- Config.AnimLab.layout.height studs above the admin: a floor with a 1-stud grid, three walls, five camera parts
-- AnimLabCam_*, the actor (a copy of the admin's character in the class colour, with the weapon of the motion), the
-- target dummy and a row of mannequins with every weapon type. Motions: basic attacks (CombatFxController.PreviewAttack),
-- skills (VfxController.Preview), generated monsters and bosses (Gait.stateMotion, clips of real models through
-- LookAnim.clipTime), boss telegraphs (CombatFxController.PreviewTelegraph) and NPC copies. `freeze t` replays the last
-- motion and stops the pose (AnimationController.LabHold, exact) and every effect (Vfx/Clock, within a frame) at t.
-- Nothing here runs outside Studio or without the stage (the frame loop is connected only while the stage exists).
-- S111: `sfx` plays Data/Sfx keys and raw Creator Store ids (SfxController.Preview / Audition), also without the
-- stage; `state` carries the sound pool's numbers (SfxController.Stats).
-- S112: `vfx <piece> [color]` plays a Vfx/Library piece at the target as a motion (freeze, step, loop every
-- Config.AnimLab.vfxEvery; without the stage once in front of the camera), `vfx all [stress]` every piece in turn,
-- `vfx tex [on|off]` checks / switches the effect textures (Vfx/Textures), `vfx stats` the effect pool's holders and
-- limits (also in `state`).
-- S113: `attack <type> [step|combo]` plays one combo step or the whole combo (steps Config.AnimLab.comboGap apart),
-- `hit <material> [crit]` the sparks, sound and reaction of a basic hit on the target, `flinch <side> [crit]` the
-- target's reaction to a blow from that side, `clip <assetId> [attack <type> [step] | skill <id>]` loads a real clip on
-- the actor, prints its load state, "Hit" marker, the server's hit time, the fitted speed (Logic/ClipFit) and the line
-- to paste into the data, and plays it in a loop (freeze through TimePosition).
-- S117: generated monsters and bosses move like in the game (Data/MonsterMotions style of the plan / weapon / Elite II
-- ability, Data/BossMotions of each boss attack, Gait.charge for telegraphed attacks, deaths by plan); `mob <kind>
-- attack2|cast` of an Elite II kind plays its ability with its telegraph, `mob <kind> spawn` the climb of a summon,
-- `boss <id> roar|death` the phase roar (camera shake, aura flash) and the death pose, a boss leap its arc to the actor;
-- S159a: `boss <id> rage` the roar into the last phase, `boss <id> <pattern>` a dodgeable pattern's gesture (its own
-- warning, the channel held, the follow-through);
-- `floor <grass|snow|cave>` dresses the floor (telegraph readability, Config.AnimLab.floors).
-- Studio review 2026-10-21: a look stands on the floor by the game's rule (a real model's feet at its pivot,
-- MonsterView's groundOffset; a generated one's root at hip height), a look wider than the stage gets floor under it;
-- with a monster or boss on the stage every camera frames it with the actor and the cast bar over it (the walls fade
-- while a camera stands outside them); `mob <kind> attack1` is the kind's regular blow as the game plays it (the draw
-- of Logic/BasicBlow, MotionKeys.basicBlow), and a real model with bone clips plays its clip (client/Anim/BoneClips,
-- the blow fitted to the draw) instead of standing still.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimLab = require(ReplicatedStorage.Shared.Logic.AnimLab)
local AttackMotions = require(ReplicatedStorage.Shared.Data.AttackMotions)
local AttackPose = require(ReplicatedStorage.Shared.Logic.AttackPose)
local BasicBlow = require(ReplicatedStorage.Shared.Logic.BasicBlow)
local BipedRig = require(script.Parent.Parent.Anim.BipedRig)
local BipedStyles = require(ReplicatedStorage.Shared.Data.BipedStyles)
local QuadRig = require(script.Parent.Parent.Anim.QuadRig)
local QuadStyles = require(ReplicatedStorage.Shared.Data.QuadStyles)
local BoneClips = require(script.Parent.Parent.Anim.BoneClips)
local CharacterClips = require(script.Parent.Parent.Anim.CharacterClips)
local ClipFit = require(ReplicatedStorage.Shared.Logic.ClipFit)
local CombatData = require(ReplicatedStorage.Shared.Data.Combat)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Footing = require(ReplicatedStorage.Shared.Logic.Footing)
local Clock = require(script.Parent.Parent.Vfx.Clock)
local Library = require(script.Parent.Parent.Vfx.Library)
local Config = require(ReplicatedStorage.Shared.Config)
local Gait = require(ReplicatedStorage.Shared.Logic.Gait)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LookAnim = require(ReplicatedStorage.Shared.Logic.LookAnim)
local Anatomy = require(ReplicatedStorage.Shared.Logic.Anatomy)
local AnatomyPlans = require(ReplicatedStorage.Shared.Logic.Anatomy.Plans)
local BossMotions = require(ReplicatedStorage.Shared.Data.BossMotions)
local BossTuning = require(ReplicatedStorage.Shared.Data.BossTuning)
local HazardGesture = require(ReplicatedStorage.Shared.Logic.HazardGesture)
local HazardPatterns = require(ReplicatedStorage.Shared.Data.HazardPatterns)
local Hazards = require(ReplicatedStorage.Shared.Logic.Hazards)
local MonsterAbilities = require(ReplicatedStorage.Shared.Data.MonsterAbilities)
local MonsterLooks = require(ReplicatedStorage.Shared.Data.MonsterLooks)
local MonsterMotions = require(ReplicatedStorage.Shared.Data.MonsterMotions)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local MotionKeys = require(ReplicatedStorage.Shared.Logic.MotionKeys)
local MountLook = require(ReplicatedStorage.Shared.Util.MountLook)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Pool = require(script.Parent.Parent.Vfx.Pool)
local Sfx = require(ReplicatedStorage.Shared.Data.Sfx)
local SkillMotions = require(ReplicatedStorage.Shared.Data.SkillMotions)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Textures = require(script.Parent.Parent.Vfx.Textures)
local VfxTextures = require(ReplicatedStorage.Shared.Data.VfxTextures)
local WeaponBuild = require(ReplicatedStorage.Shared.Util.WeaponBuild)

local AnimLabController = {
	Name = "AnimLabController",
	Deps = {
		"AnimationController",
		"VfxController",
		"CombatFxController",
		"MonsterViewController",
		"NotificationController",
		"SfxController",
	},
}

type Command = AnimLab.Command
type Joint = { motor: Motor6D, joint: Gait.Joint, scale: number }
-- The model standing in the target's place (monster, boss or NPC copy) and how it moves.
type Subject = {
	model: Model,
	joints: { Joint },
	slot: string,
	windup: number,
	shift: number, -- seconds added to t (a basic monster attack starts late in its windup, like MonsterAttack)
	track: AnimationTrack?,
	looped: boolean,
	keys: MotionKeys.Keys,
	options: Gait.StateOptions?, -- S117: the game's style, gather, death, rise and roar of this motion
	leap: { offset: Vector3, height: number }?, -- S117: a boss leap's arc (model frame)
	-- studio review 2026-10-21: a real model's bone clip (client/Anim/BoneClips): the mixer, the track, its clip time
	-- at motion time 0 and the clip seconds per motion second
	bone: { mixer: BoneClips.Mixer, track: BoneClips.Track, t0: number, pace: number }?,
	-- template animation (2026-10-25): a biped with a style, posed by Logic/BipedMotion from the state's plan
	biped: BipedLab?,
}
-- A biped's AnimLab state: its rig and the input of each moment `t` of the shown motion.
type BipedLab = {
	rig: any, -- client/Anim/BipedRig or QuadRig
	length: number,
	input: (t: number) -> any,
	lastT: number?,
}
type Stressed = { model: Model, index: number, nextAt: number }

local LAB = Config.AnimLab
local LAYOUT = LAB.layout
local WEAPON_NAME = "VaelthornWeapon"
local CAMERA_NAMES: { [string]: string } = {
	front = "AnimLabCam_Front",
	side = "AnimLabCam_Side",
	threequarter = "AnimLabCam_ThreeQuarter",
	top = "AnimLabCam_Top",
	game = "AnimLabCam_Game",
}
local LIMB_PARTS = {
	"UpperTorso",
	"LowerTorso",
	"Torso",
	"RightUpperArm",
	"RightLowerArm",
	"LeftUpperArm",
	"LeftLowerArm",
	"Right Arm",
	"Left Arm",
}

local Animation: any
local Vfx: any
local Combat: any
local MonsterView: any
local Notifications: any
local SfxCtl: any
local player = Players.LocalPlayer

local stage: Folder? = nil
local centre = Vector3.zero -- C: the floor top under the actor
local actor: Model? = nil
local actorWeapon: string? = nil
local dummy: Model? = nil
local subject: Subject? = nil
-- studio review 2026-10-21: the box (world) the cameras frame round a subject (its look, the actor, its cast bar),
-- the floor under a look wider than the stage, the camera last set
local framed: { centre: Vector3, half: Vector3 }? = nil
local subjectFloor: BasePart? = nil
local cameraName: string? = nil
-- studio review 2026-10-21 (2): how the look in the target's place stands (the `mob` / `boss` result's `ground`)
local subjectGround: { [string]: number }? = nil
local row: { Model } = {}
local stressed: { Stressed } = {}
local last: Command? = nil
local lastKeys: MotionKeys.Keys? = nil
local startedAt = 0 -- Clock.now() when the last motion started
local playedAt = -math.huge
local heldT: number? = nil -- the motion time it is frozen at
local pendingT: number? = nil -- freeze when the motion reaches this time
local loopOn = false
local cameraOn = false
local frame: RBXScriptConnection? = nil
local playing = 0 -- token of the running replay (a newer command cancels an older wait)
local sfxRun = 0 -- S111: token of `sfx all` (any newer command stops it)
local vfxRun = 0 -- S112: token of `vfx all` (any newer command stops it)
local playVfx: (Command) -> () -- S112, below
-- S113: the combo being played (`attack <type> combo`): steps and the gap between their starts.
local combo: { count: number, gap: number }? = nil
-- S113: the real clip `clip` plays on the actor, driven by the motion time (TimePosition each frame).
local clipRun: { track: AnimationTrack, speed: number, length: number, marker: number? }? = nil

-- Helpers ----------------------------------------------------------------------------------------------------

local function notify(key: string, args: { [string]: any }?)
	Notifications.System(Text.now(key, args))
end

local function vec(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function round(n: number): number
	return math.floor(n * 1000 + 0.5) / 1000
end

local function describe(command: Command?): string
	if not command then
		return Text.now("animlab.none")
	end
	local parts = { command.action :: string }
	if command.id then
		table.insert(parts, command.id)
	end
	if command.slot then
		table.insert(parts, command.slot)
	end
	if command.ref then
		table.insert(parts, command.ref)
	end
	if command.n and (command.action == "attack" or command.action == "clip") then
		table.insert(parts, tostring(command.n))
	end
	return table.concat(parts, " ")
end

local function keysText(keys: MotionKeys.Keys): string
	local parts: { string } = {}
	for _, key in keys do
		table.insert(parts, `{key.name} {round(key.t)}`)
	end
	return table.concat(parts, ", ")
end

local function keysJson(keys: MotionKeys.Keys): { { name: string, t: number } }
	local out: { { name: string, t: number } } = {}
	for _, key in keys do
		table.insert(out, { name = key.name :: string, t = round(key.t) })
	end
	return out
end

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanQuery = solid == true -- the floor: Vfx Library.ground finds it
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Parent = stage
	return p
end

-- Studio review 2026-10-21 (2): sized in studs (two places of the row wide), so labels never grow over their
-- neighbours from afar; refreshLabels shows and staggers them by the camera.
local function label(model: Model, text: string)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "AnimLabLabel"
	gui.Size = UDim2.fromScale(LAYOUT.row.gap * 2 * LAB.labelWidth, LAB.labelHeight)
	gui.StudsOffsetWorldSpace = Vector3.new(0, LAB.labelAbove, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = root
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromHex("#FFE6A0")
	textLabel.TextStrokeTransparency = 0.3
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamMedium
	textLabel.Text = text
	textLabel.Parent = gui
	gui.Parent = model
end

local function classColor(class: string?): Color3
	local def = class and Classes.get(class)
	return if def then Color3.fromHex(def.color) else Color3.fromHex(LAB.dummyColor)
end

local function myClass(): string?
	local class = State.Get({ "character", "class" })
	return if type(class) == "string" then class else nil
end

-- A still copy of the admin's character (the pattern of SkillsWindow/Preview): no scripts, plates, sounds, mount or
-- held weapons; root anchored, no queries (effects raycast the floor), attribute VaelthornPreview.
local function mannequin(name: string, color: Color3?): Model?
	local character = player.Character
	if not character then
		return nil
	end
	local was = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = was
	if not copy then
		return nil
	end
	MountLook.strip(copy)
	for _, item in copy:GetDescendants() do
		if
			item:IsA("LuaSourceContainer")
			or item:IsA("BillboardGui")
			or item:IsA("ProximityPrompt")
			or item:IsA("Sound")
			or item:IsA("ForceField")
			or (color ~= nil and (item:IsA("Clothing") or item:IsA("ShirtGraphic") or item:IsA("BodyColors")))
		then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = item.Name == "HumanoidRootPart"
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	for _, held in { WEAPON_NAME, "VaelthornOffhand" } do
		local old = copy:FindFirstChild(held)
		if old then
			old:Destroy()
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.EvaluateStateMachine = false
	end
	if color then
		for _, partName in LIMB_PARTS do
			local limb = copy:FindFirstChild(partName)
			if limb and limb:IsA("BasePart") then
				limb.Color = color
			end
		end
	end
	copy.Name = name
	copy:SetAttribute("VaelthornPreview", true)
	copy:SetAttribute("EntityId", nil)
	return copy
end

-- Height of the character's root above its feet.
local function rootHeight(model: Model): number
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return (if root then root.Size.Y / 2 else 1) + (if humanoid then humanoid.HipHeight else 2)
end

-- Stands `model` with its feet on the floor at C + offset, facing -Z (or +Z when `back`).
local function stand(model: Model, offset: Vector3, back: boolean?)
	local at = centre + offset + Vector3.new(0, rootHeight(model), 0)
	local frame = CFrame.new(at)
	if back then
		frame *= CFrame.Angles(0, math.pi, 0)
	end
	model:PivotTo(frame)
	model.Parent = stage
end

local function giveWeapon(model: Model, weaponType: string?, accent: Color3)
	local old = model:FindFirstChild(WEAPON_NAME)
	if old then
		old:Destroy()
	end
	if not weaponType or weaponType == "unarmed" then
		return
	end
	-- the best real model of the type (nearest lower tier present), else its Part look
	local def = Items.get(`{weaponType}_{Items.generate.tierFor(Config.MaxLevel)}`)
	WeaponBuild.attach(model, weaponType, accent, WEAPON_NAME, def)
end

-- Stage ------------------------------------------------------------------------------------------------------

local function clearSubject()
	local s = subject
	if s then
		if s.track then
			s.track:Stop(0)
		end
		s.model:Destroy()
		subject = nil
	end
	framed = nil
	subjectGround = nil
	if subjectFloor then
		subjectFloor:Destroy()
		subjectFloor = nil
	end
	local d = dummy
	if d and stage then
		d.Parent = stage
	end
end

local function clearStress()
	for _, entry in stressed do
		entry.model:Destroy()
	end
	table.clear(stressed)
end

-- Studio review 2026-10-21 (2): the weapon row's labels piled up into one unreadable heap seen from an angle. From
-- the front and from above (and with the cameras off) every label shows, every other one higher, so two labels of
-- one height are two places apart; from the side, the three-quarter view and the game camera only the label of the
-- actor's weapon (the last `attack <type>`), or without one the label nearest to the camera.
local function refreshLabels()
	local camera = Workspace.CurrentCamera
	local all = not cameraOn or cameraName == "front" or cameraName == "top"
	local nearest: Model? = nil
	if not all and not actorWeapon and camera then
		local best = math.huge
		for _, m in row do
			local d = (m:GetPivot().Position - camera.CFrame.Position).Magnitude
			if d < best then
				best, nearest = d, m
			end
		end
	end
	for i, m in row do
		local gui = m:FindFirstChild("AnimLabLabel")
		if gui and gui:IsA("BillboardGui") then
			gui.Enabled = all or m:GetAttribute("AnimLabWeapon") == actorWeapon or m == nearest
			local up = if all and i % 2 == 0 then LAB.labelStagger else 0
			gui.StudsOffsetWorldSpace = Vector3.new(0, LAB.labelAbove + up, 0)
		end
	end
end

-- Studio review 2026-10-21: the three walls hidden (a camera outside them) or shown.
local function fadeWalls(hidden: boolean)
	local folder = stage
	if not folder then
		return
	end
	for _, item in folder:GetChildren() do
		if item:IsA("BasePart") and item.Name == "Backdrop" then
			item.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function setCamera(name: string?): (Vector3?, Vector3?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil, nil
	end
	if not name or name == "off" then
		if cameraOn then
			camera.CameraType = Enum.CameraType.Custom
			cameraOn = false
		end
		cameraName = nil
		fadeWalls(false)
		refreshLabels()
		return nil, nil
	end
	local spec = (LAYOUT.cameras :: any)[name]
	local pos, look = centre + vec(spec.pos), centre + vec(spec.look)
	local box = framed
	if box then
		-- studio review 2026-10-21: the look, the actor and the cast bar in view, from the preset's direction; the
		-- front and the three-quarter view look at the look's face (it faces +Z, the actor) instead of its back
		local dir = vec(spec.pos) - vec(spec.look)
		if name == "front" or name == "threequarter" then
			dir = Vector3.new(dir.X, dir.Y, math.abs(dir.Z))
		end
		local viewport = camera.ViewportSize
		local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
		local half = math.rad(camera.FieldOfView) / 2
		local fit = math.min(half, math.atan(math.tan(half) * aspect))
		local radius = box.half.Magnitude
		look = box.centre
		pos = look + dir.Unit * (radius / math.sin(fit) * LAB.frameMargin)
	end
	cameraName = name
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(pos, look)
	cameraOn = true
	-- the walls fade while the camera stands outside them (a big look needs a camera far back)
	local floor = LAYOUT.floor
	fadeWalls(math.abs(pos.X - centre.X) > floor.size[1] / 2 or pos.Z - centre.Z > floor.size[3] / 2)
	refreshLabels()
	return pos, look
end

-- studio review 2026-10-21: after a look comes or goes, the camera set last frames the stage again.
local function reframe()
	if cameraOn and cameraName then
		setCamera(cameraName)
	end
end

local step: (dt: number) -> ()

local function stopClip()
	local run = clipRun
	if run then
		run.track:Stop(0)
		run.track:Destroy()
		clipRun = nil
	end
end

-- S113: holds the actor and the target dummy at motion time `t` (nil plays on): the actor's attack at its own time in
-- a combo (the step that started last before t), the dummy's flinch at t.
local function labHold(t: number?)
	local a = actor
	if a then
		local own = t
		local c = combo
		if own and c then
			local index = math.clamp(math.floor(own / c.gap) + 1, 1, c.count)
			own = own - (index - 1) * c.gap
		end
		Animation.LabHold(a, own)
	end
	local d = dummy
	if d then
		Animation.LabHold(d, t)
	end
end

local function labClear()
	local a = actor
	if a then
		Animation.LabClear(a)
	end
	local d = dummy
	if d then
		Animation.LabClear(d)
	end
end

local function teardown()
	playing += 1
	loopOn = false
	stopClip()
	combo = nil
	pendingT = nil
	heldT = nil
	Clock.resume()
	labClear()
	clearSubject()
	clearStress()
	setCamera(nil)
	if frame then
		frame:Disconnect()
		frame = nil
	end
	if stage then
		stage:Destroy()
		stage = nil
	end
	actor, dummy, actorWeapon, last, lastKeys = nil, nil, nil, nil, nil
	table.clear(row)
end

local function build(): boolean
	teardown()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return false
	end
	centre = Vector3.new(root.Position.X, root.Position.Y + LAYOUT.height, root.Position.Z)
	local folder = Instance.new("Folder")
	folder.Name = "AnimLab"
	folder.Parent = Workspace
	stage = folder
	-- floor and grid
	local floor = LAYOUT.floor
	local w, d = floor.size[1], floor.size[3]
	part(
		"Floor",
		Vector3.new(w, floor.size[2], d),
		CFrame.new(centre - Vector3.new(0, floor.size[2] / 2, 0)),
		Color3.fromHex(floor.color),
		true
	)
	local line, major = Color3.fromHex(floor.line), Color3.fromHex(floor.major)
	local function gridLine(i: number, alongZ: boolean)
		local isMajor = i % floor.majorEvery == 0
		local width = LAB.lineWidth * (if isMajor then 2 else 1)
		local size = if alongZ then Vector3.new(width, 0.02, d) else Vector3.new(w, 0.02, width)
		local offset = if alongZ then Vector3.new(i, 0.01, 0) else Vector3.new(0, 0.01, i)
		part("Grid", size, CFrame.new(centre + offset), if isMajor then major else line)
	end
	for x = -w / 2, w / 2, floor.step do
		gridLine(x, true)
	end
	for z = -d / 2, d / 2, floor.step do
		gridLine(z, false)
	end
	-- three walls (back +Z, left, right)
	local wall = LAYOUT.backdrop
	local thick = LAB.wallThickness
	local wallColor = Color3.fromHex(wall.color)
	local up = wall.height / 2
	part(
		"Backdrop",
		Vector3.new(w, wall.height, thick),
		CFrame.new(centre + Vector3.new(0, up, d / 2 + thick / 2)),
		wallColor
	)
	part(
		"Backdrop",
		Vector3.new(thick, wall.height, d),
		CFrame.new(centre + Vector3.new(-w / 2 - thick / 2, up, 0)),
		wallColor
	)
	part(
		"Backdrop",
		Vector3.new(thick, wall.height, d),
		CFrame.new(centre + Vector3.new(w / 2 + thick / 2, up, 0)),
		wallColor
	)
	-- camera parts
	for name, spec in (LAYOUT.cameras :: any) :: { [string]: any } do
		local camera = part(
			CAMERA_NAMES[name] or name,
			Vector3.one * LAB.cameraPart,
			CFrame.lookAt(centre + vec(spec.pos), centre + vec(spec.look)),
			Color3.new(1, 1, 1)
		)
		camera.Transparency = 1
	end
	-- actor, target dummy, the row of weapons
	local color = classColor(myClass())
	local a = mannequin("AnimLabActor", color)
	if not a then
		teardown()
		return false
	end
	stand(a, vec(LAYOUT.actor))
	actor = a
	local t = mannequin("AnimLabTarget", Color3.fromHex(LAB.dummyColor))
	if t then
		stand(t, vec(LAYOUT.target), true)
		dummy = t
	end
	local types: { string } = {}
	for weaponType in AttackMotions.byWeapon do
		table.insert(types, weaponType)
	end
	table.sort(types)
	local from = vec(LAYOUT.row.from)
	for i, weaponType in types do
		local m = mannequin(`AnimLabRow_{weaponType}`, color)
		if m then
			stand(m, from + Vector3.new((i - 1) * LAYOUT.row.gap, 0, 0))
			giveWeapon(m, weaponType, color)
			m:SetAttribute("AnimLabWeapon", weaponType)
			label(m, weaponType)
			table.insert(row, m)
		end
	end
	frame = RunService.PreSimulation:Connect(function(dt: number)
		local ok, err = pcall(function()
			step(dt)
		end)
		if not ok then
			warn(`[AnimLab] {tostring(err)}`)
		end
	end)
	return true
end

-- Motions ----------------------------------------------------------------------------------------------------

local function collect(model: Model): { Joint }
	local joints: { Joint } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") and string.sub(item.Name, 1, 5) == "Gait_" then
			local role = item:GetAttribute("Role")
			if type(role) == "string" then
				table.insert(joints, {
					motor = item,
					joint = {
						role = role :: any,
						side = tonumber(item:GetAttribute("Side")) or 0,
						phase = tonumber(item:GetAttribute("Phase")) or 0,
						amp = tonumber(item:GetAttribute("Amp")) or 1,
						front = tonumber(item:GetAttribute("Front")) or 0,
					},
					scale = tonumber(item:GetAttribute("Scale")) or 1,
				})
			end
		end
	end
	return joints
end

-- A track of `anims[slot]` (or the LookAnim fallback) on the model's Animator, held at speed 0: the frame loop sets
-- its TimePosition from the motion time.
local function clipOf(model: Model, anims: { [string]: string }?, slot: string): (AnimationTrack?, boolean)
	if not anims then
		return nil, false
	end
	local available: { [string]: boolean } = {}
	for name in anims do
		available[name] = true
	end
	local state: LookAnim.State = { speed = 0 }
	if slot == "death" then
		state.dead = true
	elseif slot == "hit" then
		state.hit = true
	elseif slot == "attack1" or slot == "attack2" or slot == "cast" then
		state.attack = slot :: any
	elseif slot == "spawn" then
		state.spawning = true
	elseif slot == "walk" or slot == "run" then
		state.speed = if slot == "run" then Gait.RUN_SPEED else Gait.WALK_SPEED
		state.runAbove = Gait.RUN_SPEED
	end
	local pick = LookAnim.pick(state, available)
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not pick or not animator then
		return nil, false
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = anims[pick.slot]
	animation.Parent = model
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil, false
	end
	track.Looped = pick.looped
	track:Play(0)
	track:AdjustSpeed(0)
	return track, pick.looped
end

local function keysForSlot(slot: string, windup: number, strikeNow: boolean, track: AnimationTrack?): MotionKeys.Keys
	if track and track.Length > 0 then
		return MotionKeys.clip(track.Length)
	end
	if slot == "attack1" or slot == "attack2" or slot == "cast" then
		return MotionKeys.monster(windup, strikeNow)
	elseif slot == "hit" then
		return MotionKeys.clip(Gait.HIT_SECONDS)
	elseif slot == "death" then
		return MotionKeys.clip(Gait.DEATH_SECONDS)
	elseif slot == "spawn" then
		return MotionKeys.clip(Gait.SPAWN_SECONDS)
	end
	return MotionKeys.still()
end

-- S117: the hover of a plan (studs at scale 1).
local function hoverOf(plan: string): number
	return if AnatomyPlans.hovers(plan) then Anatomy.HOVER else 0
end

-- Studio review 2026-10-21 (2): the body of a look as Logic/Footing boxes, NpcService's rule for the NPCs' feet: every
-- visible part, but not the invisible root parts (a real model's HumanoidRootPart is centred at its feet, half of it
-- under the ground: the 0.5 x scale a bounding box reported as "buried"; a generated look's LookRoot hangs at hip
-- height) and not accessory handles.
local function bodyBoxes(model: Model): { Footing.Box }
	local out: { Footing.Box } = {}
	for _, item in model:GetDescendants() do
		if not item:IsA("BasePart") or item.Transparency >= 0.99 then
			continue
		end
		if item.Name == "HumanoidRootPart" or item.Name == "LookRoot" then
			continue
		end
		if item.Parent and item.Parent:IsA("Accessory") then
			continue
		end
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = item.CFrame:GetComponents()
		local p, size = item.Position, item.Size
		table.insert(out, {
			p = { p.X, p.Y, p.Z },
			r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			size = { size.X, size.Y, size.Z },
		})
	end
	return out
end

-- The world box round a look's body (bodyBoxes), or its bounding box when it has no visible part.
local function bodyBox(model: Model): (Vector3, Vector3)
	local extent = Footing.extent(bodyBoxes(model))
	if extent then
		local lo, hi = vec(extent.lo), vec(extent.hi)
		return (lo + hi) / 2, hi - lo
	end
	local box, size = model:GetBoundingBox()
	return box.Position, size
end

-- Studio review 2026-10-21: floor under a look that pokes out of the stage (the same dress as the stage's floor, a
-- hair lower so the two never flicker where they overlap) and the box the cameras frame: the look, the actor and the
-- cast bar over the look. (2): both from the look's body.
local function frameLook(model: Model)
	local at, size = bodyBox(model)
	local floor = LAYOUT.floor
	local main = (stage :: Folder):FindFirstChild("Floor") :: BasePart?
	local reach = Vector3.new(size.X, 0, size.Z) / 2 + Vector3.one * LAB.floorPast
	local rel = at - centre
	if main and (math.abs(rel.X) + reach.X > floor.size[1] / 2 or math.abs(rel.Z) + reach.Z > floor.size[3] / 2) then
		local under = main:Clone()
		under.Name = "SubjectFloor"
		under.Size = Vector3.new(reach.X * 2, main.Size.Y, reach.Z * 2)
		under.CFrame = CFrame.new(at.X, main.Position.Y - 0.02, at.Z)
		under.Parent = stage
		subjectFloor = under
	end
	local actorAt = centre + vec(LAYOUT.actor)
	local top = at.Y + size.Y / 2 + LAB.castBarAbove
	local lo =
		Vector3.new(math.min(at.X - size.X / 2, actorAt.X - 2), centre.Y, math.min(at.Z - size.Z / 2, actorAt.Z - 2))
	local hi = Vector3.new(
		math.max(at.X + size.X / 2, actorAt.X + 2),
		math.max(top, actorAt.Y + 7),
		math.max(at.Z + size.Z / 2, actorAt.Z + 2)
	)
	framed = { centre = (lo + hi) / 2, half = (hi - lo) / 2 }
end

-- Puts a monster / boss look in the target's place, facing the actor.
local function placeLook(id: string, look: MonsterLooks.Look, variant: string, scale: number): Model
	clearSubject()
	local model, info = MonsterView.BuildPreview(id, look, variant, scale, CFrame.new())
	local d = dummy
	if d then
		d.Parent = nil
	end
	local target = vec(LAYOUT.target)
	-- studio review 2026-10-21: on the floor by the game's rule (a real model's pivot is its feet, MonsterView
	-- groundOffset; a generated look's is its root, at hip height). (2): the front of the body (-Z of the look as
	-- built, at the origin) a stud before the dummy's place, not half the widest box back (that put Hrimvald at
	-- z -34, off the 32-deep floor); the look's root stays `rootInside` studs inside the stage floor.
	local lift = if info.real then 0 else info.hipHeight + info.rootHalf
	local built = Footing.extent(bodyBoxes(model))
	local front = if built then math.max(0, -built.lo[3]) else info.width / 2
	local floor = LAYOUT.floor
	local back = math.clamp(front - 1, 0, math.max(0, target.Z + floor.size[3] / 2 - LAB.rootInside))
	local at = centre + Vector3.new(target.X, lift, target.Z - back)
	model:PivotTo(CFrame.lookAt(at, Vector3.new(centre.X, at.Y, centre.Z)))
	-- (2) the lowest visible point on the floor (Logic/Footing, as NpcService stands the NPCs): a look standing by
	-- the game's rule moves by the clearance only; a hovering look keeps its height
	local hover = hoverOf(look.plan) > 0 or (tonumber(model:GetAttribute("Hover")) or 0) > 0
	local dy = if hover then 0 else Footing.liftFor(bodyBoxes(model), centre.Y)
	if math.abs(dy) > LAB.footTolerance then
		model:PivotTo(model:GetPivot() + Vector3.new(0, dy, 0))
	else
		dy = 0
	end
	model:SetAttribute("PreviewMonsterId", id) -- S111: SfxController.Mob (family, boss, hit material)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanQuery = false
		end
	end
	model.Parent = stage
	local root = model.PrimaryPart
	local placed = Footing.extent(bodyBoxes(model))
	subjectGround = {
		lift = round(dy), -- studs the look moved to stand on its lowest visible point
		lowest = if placed then round(placed.lo[2] - centre.Y) else 0, -- its lowest visible point over the floor
		-- the bottom of its invisible root part (a real model's HumanoidRootPart, centred at the feet)
		rootBottom = if root then round(root.Position.Y - root.Size.Y / 2 - centre.Y) else 0,
		z = round(at.Z - centre.Z), -- where its root stands (the stage floor reaches +-floor.size[3] / 2)
		hover = if hover then 1 else 0,
	}
	frameLook(model)
	return model
end

-- Studio review 2026-10-21: a real model with bone clips (rig "bones") plays a slot's clip as in the game
-- (client/Anim/BoneClips): an attack's blow fitted to land `lead` s after the start; the frame loop sets its time.
local BONE_LOOPED: { [string]: boolean } = { idle = true, walk = true, run = true }
local function boneOf(model: Model, look: MonsterLooks.Look, slot: string, lead: number?): any
	local asset = look.asset
	if not asset or asset.rig ~= "bones" then
		return nil
	end
	local mixer = BoneClips.new(model, asset.model)
	if not mixer then
		return nil
	end
	local tracks = mixer.tracks
	local track = tracks[slot]
	if not track and (slot == "attack1" or slot == "attack2" or slot == "cast") then
		track = tracks.attack2 or tracks.attack1
	end
	if not track then
		return nil
	end
	track.Looped = BONE_LOOPED[slot] == true
	track.lead = lead
	track:Play(0)
	track.weight = 1
	return { mixer = mixer, track = track, t0 = track.time, pace = track.slot.rate * track.fit }
end

-- S117: a telegraph on the stage like CombatService sends it: around the caster for "self" circles / rings, on the
-- actor for the other circles, from the caster towards the actor for cones and lines. Returns its area.
local function stageTelegraph(
	model: Model,
	shape: string,
	around: boolean,
	dims: { r: number?, ir: number?, an: number?, l: number?, w: number? },
	windup: number,
	element: string?,
	id: string,
	mechanic: string? -- S134: the boss mechanic (`m` of the event: golden split, purple mark, thick avoid rim)
): CFrame
	local at = model:GetPivot().Position
	local casterAt = Vector3.new(at.X, centre.Y, at.Z)
	local actorAt = centre + vec(LAYOUT.actor)
	local toActor = Vector3.new(actorAt.X - casterAt.X, 0, actorAt.Z - casterAt.Z)
	local dir = if toActor.Magnitude > 0.01 then toActor.Unit else Vector3.new(0, 0, 1)
	local isRound = shape == "circle" or shape == "ring"
	local origin = if isRound and not around then actorAt else casterAt
	local area = CFrame.lookAt(origin, origin + dir)
	Combat.PreviewTelegraph({
		k = "tele",
		sh = shape,
		cf = area,
		r = dims.r,
		ir = dims.ir,
		an = dims.an,
		l = dims.l,
		w = dims.w,
		t = windup,
		el = element,
		a = id,
		m = mechanic,
	}, model)
	return area
end

-- Template animation: the plan of a biped's or quadruped's AnimLab state (Data/BipedStyles / QuadStyles LAB_STATES;
-- LookAnim's slots map onto them): each moment's input to its motion, the motion's length and its keys.
local function bipedLab(model: Model, look: any, monster: any, state: string): (BipedLab?, MotionKeys.Keys?)
	local styleId = look.asset.motion :: string
	local rig: any = if BipedStyles.get(styleId)
		then BipedRig.new(model, styleId, 7.3)
		elseif QuadStyles.get(styleId) then QuadRig.new(model, styleId, 7.3, look.asset.model)
		else nil
	if not rig then
		return nil, nil
	end
	local style = rig.motion.style
	local at = model:GetPivot()
	local actorAt = centre + vec(LAYOUT.actor)
	local function toActor(): { number }
		local d = at:VectorToObjectSpace(actorAt + Vector3.new(0, 2.5, 0) - (at.Position + Vector3.new(0, 3, 0)))
		return { d.X, d.Y, d.Z }
	end
	local reachV = at:PointToObjectSpace(actorAt)
	local reach = { reachV.X, 0, reachV.Z }
	local melee = CombatData.basicWind.melee
	local function windupOf(name: string): number
		if monster and monster.ability and style.abilities[monster.ability] == name then
			local own = MonsterAbilities.get(monster.ability)
			if own then
				return own.windup
			end
		end
		for abilityId, action in style.abilities do
			local ability = MonsterAbilities.get(abilityId)
			if action == name and ability then
				return ability.windup
			end
		end
		if name == style.abilities.heavyBlow then
			local heavy = MonsterAbilities.get("heavyBlow")
			return if heavy then heavy.windup else 1.8
		elseif name == style.throw then
			return CombatData.basicWind.throw * CombatData.basicWindVariant.elite2
		elseif name == style.aggro then
			return 0.45
		elseif name == style.spawn or name == "sniff" or name == "shake" then
			return 0.5
		end
		return melee
	end
	-- LookAnim's slots onto the style
	local name = state
	if state == "attack1" then
		name = style.basic[1]
	elseif state == "attack2" then
		name = style.basic[2] or style.basic[1]
	elseif state == "cast" then
		name = (monster and monster.ability and style.abilities[monster.ability]) or style.abilities.heavyBlow
	elseif state == "death" then
		name = rig.mod.death(rig.motion)
	end
	local base: any = {
		now = 0,
		dt = 0,
		speed = 0,
		yawRate = 0,
		combat = true,
		action = nil,
		hitAt = nil,
		hitSide = nil,
		look = toActor(),
	}
	local length = 3
	local keys: MotionKeys.Keys
	local input: (t: number) -> any
	local hitSides: { [string]: string } = { hit = "front", hitBack = "back", hitLeft = "left", hitRight = "right" }
	if style.actions[name] and not hitSides[state] then
		local action = style.actions[name]
		local dying = string.sub(name, 1, 5) == "death"
		local hit = if dying then action.strike else windupOf(name)
		local run = { name = name, start = 0, hit = hit, reach = reach }
		length = rig.mod.length(action, hit) + 0.4
		keys = MotionKeys.clip(length, hit)
		input = function(t)
			local i = table.clone(base)
			i.now, i.action = t, run
			if dying then
				i.look = nil
			end
			return i
		end
	elseif hitSides[state] then
		length = 1.2
		keys = MotionKeys.clip(length, 0.2)
		input = function(t)
			local i = table.clone(base)
			i.now, i.hitAt, i.hitSide = t, 0.2, hitSides[state]
			return i
		end
	elseif state == "fight" then
		-- a short fight: the shout, three blows, a hit taken, the ability
		local ability = (monster and monster.ability and style.abilities[monster.ability])
			or style.abilities.cleave
			or style.basic[1]
		local plan: { { at: number, name: string, hit: number } } = {
			{ at = 0, name = style.aggro or style.basic[1], hit = 0.45 },
			{ at = 1.6, name = style.basic[1], hit = melee },
			{ at = 3.0, name = style.basic[2] or style.basic[1], hit = melee },
			{ at = 4.5, name = style.basic[4] or style.basic[1], hit = melee },
			{ at = 6.6, name = ability, hit = windupOf(ability) },
		}
		length = 9.5
		keys = MotionKeys.clip(length)
		input = function(t)
			local i = table.clone(base)
			i.now = t
			for _, step in plan do
				if t >= step.at then
					i.action =
						{ name = step.name, start = step.at, hit = step.hit, reach = reach, mirror = step.at == 3.0 }
				end
			end
			if t >= 5.9 then
				i.hitAt, i.hitSide = 5.9, "front"
			end
			return i
		end
	else
		-- locomotion and stances
		local moveSpeed = if monster and monster.moveSpeed then monster.moveSpeed else 13
		length = 3
		keys = MotionKeys.clip(length)
		input = function(t)
			local i = table.clone(base)
			i.now = t
			if state == "idle" then
				i.combat = false
				i.look = nil
			elseif state == "walk" then
				-- S162m: the server's gaits: wander 0.4x, going home 0.7x, the chase 1x moveSpeed
				i.combat, i.look, i.speed = false, nil, moveSpeed * 0.4
			elseif state == "trot" or state == "home" then
				i.combat, i.look, i.speed = false, nil, moveSpeed * 0.7
				i.returning = state == "home"
			elseif state == "run" then
				i.speed = moveSpeed
			elseif state == "turn" then
				i.yawRate = 2.4
			end
			return i
		end
	end
	return { rig = rig, length = length, input = input, lastT = nil }, keys
end

local function playMob(command: Command)
	local id = command.id :: string
	local slot = command.slot or "attack1"
	local monster = Monsters.get(id)
	local boss = Bosses.get(id)
	local look = if monster then MonsterLooks.get(id, monster.region) else MonsterLooks.get(id)
	if not look then
		return
	end
	local model = placeLook(
		id,
		look,
		if monster then "normal" else "boss",
		if monster then monster.size elseif boss then boss.look.size else 1
	)
	-- template animation: a biped with a style shows Logic/BipedMotion (its states and actions)
	local motionStyle = look.asset and look.asset.motion
	if motionStyle then
		local lab, labKeys = bipedLab(model, look, monster, slot)
		if lab and labKeys then
			subject = {
				model = model,
				joints = {},
				slot = slot,
				windup = 0,
				shift = 0,
				track = nil,
				looped = true,
				keys = labKeys,
				options = nil,
				leap = nil,
				bone = nil,
				biped = lab,
			}
			local ability = monster and monster.ability and MonsterAbilities.get(monster.ability)
			if ability and slot == "cast" then
				stageTelegraph(model, ability.shape, ability.origin == "self", {
					r = ability.radius,
					ir = ability.inner,
					an = ability.angle,
					l = ability.length,
					w = ability.width,
				}, ability.windup, ability.element, ability.id)
			end
			return
		end
	end
	-- S117: an Elite II kind's attack2 / cast is its ability (the windup and the telegraph of the game)
	local ability = if monster
			and monster.ability
			and (slot == "attack2" or slot == "cast")
		then MonsterAbilities.get(monster.ability)
		else nil
	-- studio review 2026-10-21: attack1 is the kind's regular blow as the game plays it since S159 (the "aw" draw of
	-- Logic/BasicBlow, then the blow; before, the strike-now pose with no draw: peak 0, hit 0 for every model)
	-- (2): a boss's regular blow too, drawn as the "boss" variant (Entities/Boss spawns its monster as one)
	local basicKeys, wind, basicSlot = nil, 0, slot
	if (monster or boss) and slot == "attack1" then
		basicKeys, wind, basicSlot = MotionKeys.basicBlow(id, if monster then "normal" else "boss")
	end
	local basic = basicKeys ~= nil
	local shot = if monster
		then BasicBlow.shot(monster.attack, monster.damageKind)
		elseif boss then BasicBlow.shot(boss.attack, boss.damageKind)
		else "melee"
	local windup = if ability
		then ability.windup
		elseif basic then wind
		elseif slot == "cast" then LAB.castWindup
		else Gait.DEFAULT_WINDUP
	local strikeNow = false
	local playSlot = if basic then basicSlot else slot -- the clip slot the game plays (BasicBlow.slot)
	local asset = look.asset
	local track, looped = nil, false
	if asset and asset.rig == "animator" then
		track, looped = clipOf(model, asset.anims :: any, playSlot)
	end
	local lead = if playSlot == "attack1" or playSlot == "attack2" or playSlot == "cast" then windup else nil
	local bone = boneOf(model, look, playSlot, lead)
	local plan = look.plan
	local bossDef = if boss then BossMotions.get(id) else nil
	local style = if basic and shot ~= "melee"
		then MonsterMotions.rangedFor(plan, look.weapon, shot)
		elseif basic then MonsterMotions.styleFor(plan, look.weapon)
		elseif ability then MonsterMotions.styleFor(plan, look.weapon, ability.id)
		else MonsterMotions.styleFor(plan, look.weapon, "default")
	local keys = keysForSlot(slot, windup, strikeNow, track)
	if bone then
		keys = MotionKeys.boneClip(bone.track.slot, lead)
	elseif basic and not track then
		keys = basicKeys :: MotionKeys.Keys
	elseif ability and not track then
		keys = MotionKeys.ability(ability.id) or keys
	elseif slot == "spawn" and not track then
		keys = MotionKeys.clip(Config.MonsterLook.summonRise)
	end
	subject = {
		model = model,
		joints = collect(model),
		slot = slot,
		windup = windup,
		shift = 0,
		track = track,
		looped = looped,
		keys = keys,
		bone = bone,
		options = {
			style = style,
			charged = ability ~= nil or (basic and shot ~= "melee"),
			deathStyle = if bossDef then bossDef.death.style else MonsterMotions.deathFor(plan),
			deathSide = 1,
			hover = hoverOf(plan),
			plan = plan,
			rise = true,
		},
		leap = nil,
	}
	if ability then
		stageTelegraph(
			model,
			ability.shape,
			ability.origin == "self",
			{ r = ability.radius, ir = ability.inner, an = ability.angle, l = ability.length, w = ability.width },
			ability.windup,
			ability.element,
			ability.id
		)
	end
end

local function playBoss(command: Command)
	local bossId, attackId = command.id :: string, command.slot :: string
	local boss = Bosses.get(bossId)
	local look = MonsterLooks.get(bossId)
	local def = BossMotions.get(bossId)
	if not boss or not look then
		return
	end
	local model = placeLook(bossId, look, "boss", boss.look.size)
	local plan = look.plan
	-- S117: the phase roar and the death of the boss (S159a: `rage` the roar into the last phase)
	if attackId == "roar" or attackId == "rage" or attackId == "death" then
		local roar = if def then def.roar.seconds else Config.MonsterLook.roarSeconds
		local dying = attackId == "death"
		local bone = boneOf(model, look, if dying then "death" else "idle", nil)
		subject = {
			model = model,
			joints = collect(model),
			slot = if attackId == "death" then "death" else "idle",
			windup = Gait.DEFAULT_WINDUP,
			shift = 0,
			track = nil,
			looped = false,
			bone = bone,
			keys = if bone and dying
				then MotionKeys.boneClip(bone.track.slot, nil)
				else MotionKeys.clip(if attackId == "death" then Gait.DEATH_SECONDS else roar),
			options = {
				deathStyle = if def then def.death.style else MonsterMotions.deathFor(plan),
				deathSide = 1,
				hover = hoverOf(plan),
				plan = plan,
				roar = if attackId ~= "death" then roar else nil,
				roarStyle = BossMotions.roarStyle(bossId, if attackId == "rage" then 3 else nil),
			},
			leap = nil,
		}
		if attackId ~= "death" then
			Animation.Roar(model)
		end
		return
	end
	-- S159a: a pattern's gesture over its warning (the attack it replaces: that attack's windup)
	local gesture = if def then def.patterns[attackId] else nil
	local pattern = HazardPatterns.get(attackId)
	if gesture and gesture.style and pattern then
		local warn = Hazards.MIN_WARN
		local first = pattern.emitters[1]
		if first and first.delay then
			warn = math.max(warn, first.delay)
		end
		local tuning = (BossTuning.patterns :: any)[bossId]
		for replacedId, id in (if tuning and tuning.replace then tuning.replace else {}) :: { [string]: string } do
			for _, a in boss.attacks do
				if id == attackId and a.id == replacedId then
					warn = a.windup
				end
			end
		end
		local timing = HazardGesture.timing(pattern, warn)
		subject = {
			model = model,
			joints = collect(model),
			slot = "cast",
			windup = timing.windup,
			shift = 0,
			track = nil,
			looped = false,
			keys = MotionKeys.monster(timing.windup),
			options = {
				style = gesture.style,
				charged = true,
				hold = timing.hold,
				plan = plan,
				hover = hoverOf(plan),
			},
			leap = nil,
		}
		return
	end
	local attack: Bosses.Attack? = nil
	for _, a in boss.attacks do
		if a.id == attackId then
			attack = a
		end
	end
	if not attack then
		return
	end
	local slot = if attack.windup > 1 then "cast" else "attack2"
	local asset = look.asset
	local track, looped = nil, false
	if asset and asset.rig == "animator" then
		track, looped = clipOf(model, asset.anims :: any, slot)
	end
	local motion = if def then def.attacks[attackId] else nil
	-- studio review 2026-10-21: a boss with bone clips plays the slot's clip, its blow at the attack's windup
	local bone = if track then nil else boneOf(model, look, slot, attack.windup)
	local played: Subject = {
		model = model,
		joints = collect(model),
		slot = slot,
		windup = attack.windup,
		shift = 0,
		track = track,
		looped = looped,
		bone = bone,
		keys = if bone
			then MotionKeys.boneClip(bone.track.slot, attack.windup)
			else MotionKeys.boss(bossId, attackId) or MotionKeys.monster(attack.windup),
		options = {
			style = if motion then motion.style else nil,
			charged = true,
			plan = plan,
			hover = hoverOf(plan),
		},
		leap = nil,
	}
	subject = played
	local area = stageTelegraph(
		model,
		attack.shape,
		attack.target == "self",
		{ r = attack.radius, ir = attack.inner, an = attack.angle, l = attack.length, w = attack.width },
		attack.windup,
		attack.element,
		attack.id,
		if attack.mechanic then attack.mechanic elseif attack.avoid then "avoid" else nil
	)
	-- S117: a leap flies its arc to the area (the stage has no server teleport: it stays there to the end)
	if attack.leap and motion and motion.arc then
		local offset = model:GetPivot():PointToObjectSpace(area.Position)
		played.leap = { offset = Vector3.new(offset.X, 0, offset.Z), height = motion.arc }
	end
end

local function playNpc(command: Command)
	local id, slot = command.id :: string, command.slot or "idle"
	local folder = Workspace:FindFirstChild("Npcs")
	local source: Model? = nil
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("NpcId") == id then
				source = child
			end
		end
	end
	if not source then
		notify("animlab.npc.missing", { npc = id })
		return
	end
	clearSubject()
	local was = source.Archivable
	source.Archivable = true
	local copy = source:Clone()
	source.Archivable = was
	for _, item in copy:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("BillboardGui") or item:IsA("ProximityPrompt") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = item.Name == "HumanoidRootPart"
			item.CanCollide = false
			item.CanQuery = false
		end
	end
	copy:SetAttribute("NpcId", nil)
	copy:SetAttribute("VaelthornPreview", true)
	local d = dummy
	if d then
		d.Parent = nil
	end
	stand(copy, vec(LAYOUT.target), true)
	-- clips of NPCs come with S116 (Data/Npcs `asset.anims`); until then the copy stands
	local def = Npcs.get(id) :: any
	local anims = def and def.asset and def.asset.anims
	local track, looped = clipOf(copy, anims, slot)
	if not track then
		notify("animlab.npc.noClip", { npc = id, slot = slot })
	end
	subject = {
		model = copy,
		joints = {},
		slot = slot,
		windup = 0,
		shift = 0,
		track = track,
		looped = looped,
		keys = if track and track.Length > 0 then MotionKeys.clip(track.Length) else MotionKeys.still(),
	}
end

-- Plays `command` from its start (the clock must be running).
local function play(command: Command)
	local a = actor
	if not a then
		return
	end
	labClear()
	heldT = nil
	pendingT = nil
	combo = nil
	local action = command.action
	if action ~= "clip" then
		stopClip()
	end
	if action == "attack" then
		clearSubject()
		reframe()
		local weaponType = command.id :: string
		if actorWeapon ~= weaponType then
			giveWeapon(a, weaponType, classColor(myClass()))
			actorWeapon = weaponType
		end
		local wt = if weaponType == "unarmed" then nil else weaponType
		Animation.ResetCombo(a)
		if command.slot == "combo" then
			-- S113: every step in turn, comboGap apart (inside the combo window)
			local count = AttackPose.stepCount(AttackPose.motionFor(wt), wt)
			local gap = LAB.comboGap
			combo = { count = count, gap = gap }
			local token = playing -- a newer command cancels the remaining steps
			for i = 1, count do
				Clock.after((i - 1) * gap, function()
					if token == playing and actor == a then
						Combat.PreviewAttack(wt, a, i, dummy)
					end
				end)
			end
			local keys = MotionKeys.attack(wt, nil, 1)
			local last = AttackPose.timing(AttackPose.motionFor(wt), nil, count)
			for _, key in keys do
				if key.name == "end" then
					key.t = (count - 1) * gap + last.total
				end
			end
			lastKeys = keys
		else
			Combat.PreviewAttack(wt, a, command.n or 1, dummy)
			lastKeys = MotionKeys.attack(wt, nil, command.n or 1)
		end
	elseif action == "hit" or action == "flinch" then
		-- S113: on the target (the dummy, or the monster standing in its place)
		local s = subject
		local target = if s then s.model else dummy
		local root = target and target:FindFirstChild("HumanoidRootPart")
		if target and root and root:IsA("BasePart") then
			local crit = command.slot == "crit"
			if action == "hit" then
				Combat.PreviewHit(
					target,
					centre + vec(LAYOUT.actor) + Vector3.new(0, 2.5, 0),
					command.id :: string,
					crit
				)
			else
				local frame = root.CFrame
				local side = command.id
				local offset = if side == "back"
					then -frame.LookVector
					elseif side == "left" then -frame.RightVector
					elseif side == "right" then frame.RightVector
					else frame.LookVector
				Animation.CharacterHit(target, root.Position + offset * 4, crit)
			end
		end
		lastKeys = MotionKeys.clip(LAB.hitShow)
	elseif action == "clip" then
		-- S113: the clip loaded by runClip, from its start (the frame loop drives its TimePosition)
		local run = clipRun
		lastKeys = if run then MotionKeys.clip(run.length, run.marker, run.speed) else MotionKeys.still()
	elseif action == "skill" then
		clearSubject()
		reframe()
		local id = command.id :: string
		local skill = Skills.get(id)
		local weaponType = command.slot or AnimLab.weaponForSkill(id) -- S115: `skill <id> [weapon type]`
		if actorWeapon ~= weaponType then
			giveWeapon(a, weaponType, classColor(if skill then skill.class else myClass()))
			actorWeapon = weaponType
		end
		Vfx.Preview(a, id)
		-- the same loopUntil the preview's motion plays with (beam, channel, castTime); S115: and the variant the
		-- actor plays (its weapon's family, the previewed rank's waves)
		lastKeys = MotionKeys.skill(id, Vfx.PreviewLoopUntil(id), {
			weapon = if weaponType then AttackMotions.byWeapon[weaponType] else nil,
			hits = Vfx.PreviewHits(id),
		})
	elseif action == "mob" then
		playMob(command)
		lastKeys = if subject then subject.keys else nil
		reframe()
	elseif action == "boss" then
		playBoss(command)
		lastKeys = if subject then subject.keys else nil
		reframe()
	elseif action == "npc" then
		playNpc(command)
		lastKeys = if subject then subject.keys else nil
		reframe()
	elseif action == "vfx" then
		playVfx(command)
		lastKeys = MotionKeys.still()
	end
	last = command
	startedAt = Clock.now()
	playedAt = startedAt
end

local function motionLength(): number
	local command = last
	if command and command.action == "vfx" then
		return LAB.vfxEvery - LAB.loopGap -- S112: a piece repeats every vfxEvery seconds
	end
	local keys = lastKeys
	return if keys then MotionKeys.at(keys, "end") or 0 else 0
end

-- The frame loop (only while the stage exists): freezes at the pending time, poses the subject, loops and stress.
step = function(_dt: number)
	local now = Clock.now()
	local t = heldT or (now - startedAt)
	local pending = pendingT
	if pending and not heldT and t >= pending then
		Clock.freeze()
		heldT = pending
		pendingT = nil
		t = pending
		labHold(pending)
	end
	local run = clipRun
	if run and run.length > 0 then
		run.track.TimePosition = LookAnim.clipTime(t * run.speed, run.length, true)
	end
	local s = subject
	if s then
		if s.track then
			s.track.TimePosition = LookAnim.clipTime(t, s.track.Length, s.looped)
		end
		local biped = s.biped
		if biped then
			-- template animation: the biped at motion time t (a jump back in time snaps its weights)
			local tt = math.max(0, t)
			local last = biped.lastT
			local input = biped.input(tt)
			input.dt = if last and tt >= last then tt - last else 0
			input.snap = last == nil or tt < last
			biped.lastT = tt
			local posed = biped.rig.mod.step(biped.rig.motion, input)
			if biped.rig.kind == "quad" then
				QuadRig.apply(biped.rig, posed)
			else
				BipedRig.apply(biped.rig, posed)
			end
		end
		local bone = s.bone
		if bone then
			-- studio review 2026-10-21: the bone clip at motion time t (BoneClips holds a clip's last frame)
			bone.track.time = bone.t0 + math.max(0, t) * bone.pace
			BoneClips.step(bone.mixer, 0)
		end
		if #s.joints > 0 then
			-- S117: the game's choices (style, gather, death, rise, roar) on top of the slot's windup
			local options: Gait.StateOptions = if s.options then table.clone(s.options) else {}
			options.windup = s.windup
			local motion = Gait.stateMotion(s.slot :: Gait.Slot, t + s.shift, options)
			-- S117: a boss leap flies the last leapArc s of its windup to the area and stays there
			local leap: Vector3? = nil
			local arc = s.leap
			if arc then
				local fly = math.min(Config.MonsterLook.leapArc, s.windup)
				local k = (t - (s.windup - fly)) / fly
				if k > 0 then
					local o = arc.offset
					local x, y, z = Gait.leapArc(math.min(1, k), { 0, 0, 0 }, { o.X, o.Y, o.Z }, arc.height)
					leap = Vector3.new(x, y, z)
				end
			end
			for _, j in s.joints do
				local p = Gait.pose(j.joint, motion)
				local k = j.scale
				local transform = CFrame.new(p.x * k, p.y * k, p.z * k) * CFrame.Angles(p.rx, p.ry, p.rz)
				if leap and j.joint.role == "body" then
					transform = CFrame.new(leap) * transform
				end
				j.motor.Transform = transform
			end
		end
	end
	local command = last
	if loopOn and command and not heldT and not pendingT and now - startedAt >= motionLength() + LAB.loopGap then
		play(command)
	end
	if not Clock.frozen() then
		local skills = AnimLab.activeSkills()
		for _, entry in stressed do
			if now >= entry.nextAt and #skills > 0 then
				Vfx.Preview(entry.model, skills[(entry.index - 1) % #skills + 1])
				entry.index += 1
				entry.nextAt = now + LAB.stressEvery
			end
		end
	end
end

-- Replays the last motion and waits (in the frame loop) to freeze it at `t`; effects of an earlier play may run out
-- first (at most Config.AnimLab.settle seconds).
local function freezeAt(t: number)
	local command = last
	if not command then
		return
	end
	playing += 1
	local token = playing
	Clock.resume()
	labHold(nil)
	labClear()
	heldT = nil
	pendingT = nil -- an earlier freeze / step must not stop the clock while this one waits
	local waitUntil = playedAt + LAB.settle
	while Clock.now() < waitUntil and Clock.pending() > 0 and token == playing do
		task.wait()
	end
	if token ~= playing then
		return
	end
	play(command)
	if t <= 0 then
		Clock.freeze()
		heldT = 0
		labHold(0)
	else
		pendingT = t
	end
end

local function resume()
	local held = heldT
	pendingT = nil
	if not held then
		return
	end
	heldT = nil
	Clock.resume()
	labHold(nil)
	-- the motion time goes on from where it was held
	startedAt = Clock.now() - held
end

local function stepBy(dt: number)
	local held = heldT
	if not held then
		freezeAt(math.max(0, dt))
		return
	end
	if dt < 0 then
		freezeAt(math.max(0, held + dt))
		return
	end
	resume()
	pendingT = held + dt
end

local function stress(n: number)
	clearStress()
	local color = classColor(myClass())
	for i = 1, n do
		local m = mannequin(`AnimLabStress_{i}`, color)
		if m then
			local angle = (i - 1) / n * math.pi * 2
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * LAB.stressRadius
			stand(m, offset)
			m:PivotTo(CFrame.lookAt(m:GetPivot().Position, Vector3.new(centre.X, m:GetPivot().Position.Y, centre.Z)))
			table.insert(stressed, { model = m, index = i, nextAt = Clock.now() + (i - 1) * LAB.stressEvery / n })
		end
	end
end

local function yesNo(value: any): string
	return Text.now(if value == true then "animlab.yes" else "animlab.no")
end

-- S112: where `vfx` plays: the target's spot on the stage, else 12 studs in front of the camera.
local function vfxAt(): Vector3?
	if stage then
		return centre + vec(LAYOUT.target)
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position + camera.CFrame.LookVector * 12 else nil
end

-- The blow comes from the actor (or the camera without the stage).
local function vfxFrom(): Vector3
	if stage then
		return centre + vec(LAYOUT.actor)
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

-- The colour of a `vfx` command (white by default) and the rune of its class ("class:Mage" -> runeMage).
local function vfxLook(text: string?): (Color3, string)
	local hex = if text then AnimLab.vfxColor(text) else nil
	local class = if text then string.match(text, "^class:(%a+)$") else nil
	return if hex then Color3.fromHex(hex) else Color3.new(1, 1, 1), VfxTextures.runeOf(class)
end

-- Plays one piece of AnimLab.VFX_PIECES at the floor point `at`, struck from `from`; false when it needs a model and
-- there is none (sparkle, aura, glow, weaponTrail, falcon without the stage). `model` is the target, `caster` the one
-- who glows, swings or keeps the falcon (default: `model`).
local function playPiece(
	name: string,
	at: Vector3,
	from: Vector3,
	color: Color3,
	rune: string,
	model: Model?,
	caster: Model?
): boolean
	local up = at + Vector3.new(0, 2.5, 0)
	local hand = from + Vector3.new(0, 2.5, 0)
	local away = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
	local dir = if away.Magnitude > 0.1 then away.Unit + Vector3.new(0, 0.6, 0) else Vector3.yAxis
	if name == "impactFlash" then
		Library.impactFlash(up, 3, color)
	elseif name == "sparks" then
		Library.sparks(up, color, { dir = dir })
	elseif name == "groundDecal" then
		Library.groundDecal(at, 4, "cracks", Library.crackTint(color), 1.4)
	elseif name == "smokePuff" then
		Library.smokePuff(at, 1.2, color)
	elseif name == "magicCircle" then
		Library.magicCircle(at, 5, color, 2, { key = rune })
	elseif name == "ringWave" then
		Library.ringWave(at, 8, color)
	elseif name == "burst" then
		Library.burst(up, 5, color)
	elseif name == "shockwave" then
		Library.shockwave(at, 8, color, 0.45)
	elseif name == "cracks" then
		Library.cracks(at, 5, color, 1.4)
	elseif name == "slash" then
		local look = if (up - hand).Magnitude > 0.1 then up else hand + Vector3.new(0, 0, -1)
		Library.slash(CFrame.lookAt(hand, look), 7, 70, -70, color, 55)
	elseif name == "projectile" then
		Library.projectile(hand, up, "orb", color, { size = 1.2, speed = 60 })
	elseif name == "lightning" then
		Library.lightning(up + Vector3.new(0, 20, 0), up, color, 0.4)
	elseif name == "pillar" then
		Library.pillar(at, 1.5, 14, color, 0.7)
	elseif name == "rune" then
		Library.rune(at, 5, color, 2, false, rune)
	elseif name == "sparkle" or name == "aura" then
		if not model then
			return false
		end
		if name == "sparkle" then
			Library.sparkle(model, color)
		else
			Library.aura(model, color, 2)
		end
	elseif name == "glow" or name == "weaponTrail" or name == "falcon" then
		local who = caster or model
		if not who then
			return false
		end
		if name == "glow" then
			Library.glow(who, "both", color, 1.5)
		elseif name == "weaponTrail" then
			-- the streak on the held weapon (a sword when it holds none) over a swing of the whole model and back
			if not who:FindFirstChild(WEAPON_NAME) then
				giveWeapon(who, "sword1h", color)
				if who == actor then
					actorWeapon = "sword1h"
				end
			end
			local root = who:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local frame = root.CFrame
				Library.weaponTrail(who, color, 0, 0.6)
				Clock.tween(
					root,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad),
					{ CFrame = frame * CFrame.Angles(0, -2.5, 0) }
				)
				Clock.after(0.3, function()
					Clock.tween(root, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { CFrame = frame })
				end)
			end
		else
			local falcon = Library.falcon(who, color, false)
			if falcon then
				falcon.keep(3)
				local target = if model ~= who then model else nil
				Clock.after(1, function()
					falcon.strike(target, false)
				end)
			end
		end
	elseif name == "beam" then
		Library.beam(hand, up, color, 0.35, 0.6)
	elseif name == "dust" then
		Library.dust(at, 1.2)
	elseif name == "meteor" then
		Library.meteor(at, 6, 0.6, color)
	elseif string.sub(name, 1, 10) == "lingering:" then
		Library.lingering(at, 4, string.sub(name, 11), color, 2)
	elseif name == "shieldArc" then
		local look = Vector3.new(at.X, from.Y, at.Z)
		Library.shieldArc(
			CFrame.lookAt(from, if (look - from).Magnitude > 0.1 then look else from - Vector3.zAxis),
			6,
			color
		)
	elseif name == "wings" then
		local who = model or caster
		if not who then
			return false
		end
		Library.wings(who, color, 1.5)
	elseif name == "snare" then
		Library.snare(at, color, 2)
	elseif name == "stormCloud" then
		Library.stormCloud(at, 6, color, 2)
		Clock.after(0.6, function()
			Library.lightning(at + Vector3.new(0, Config.Vfx.cloudHeight, 0), at, color, 0.5)
		end)
	end
	return true
end

-- The piece of a `vfx` motion at the target (play / freeze / loop replay it).
playVfx = function(command: Command)
	local at = vfxAt()
	if not at then
		return
	end
	local color, rune = vfxLook(command.slot)
	if not playPiece(command.id :: string, at, vfxFrom(), color, rune, dummy or actor, actor) then
		notify("animlab.vfx.noModel", { piece = command.id })
	end
end

-- Holders, lights and limits of the effect pool (`vfx stats`, `state`).
local function vfxStats(): { [string]: any }
	return {
		active = Pool.activeCount(),
		maxActive = Config.Vfx.maxActive,
		emitters = Pool.holderCount("emitter"),
		beams = Pool.holderCount("beam"),
		surfaces = Pool.holderCount("surface"),
		decals = Pool.holderCount("decal"),
		lights = Pool.lightCount(),
		limits = {
			emitters = Pool.limit("emitters"),
			beams = Pool.limit("beams"),
			decals = Pool.limit("decals"),
			lights = Pool.limit("lights"),
		},
		touch = Pool.isTouch(),
		textures = Textures.enabled,
	}
end

-- S112: vfx all [stress] | vfx tex [on|off] | vfx stats (also without the stage).
local function runVfxTool(command: Command): { [string]: any }
	local sub = command.id :: string
	if sub == "tex" then
		if command.slot then
			Textures.enabled = command.slot == "on"
			if Textures.enabled then
				Textures.clearFailed()
			end
			notify("animlab.vfx.texSet", { state = yesNo(Textures.enabled) })
			return { ok = true, enabled = Textures.enabled }
		end
		local result = Textures.check()
		local good, bad = 0, {}
		for key, value in result do
			if value == "ok" then
				good += 1
			elseif not string.find(key, "%.flipbook$") and value ~= "empty" then
				table.insert(bad, key)
			end
		end
		table.sort(bad)
		notify("animlab.vfx.tex", {
			ok = good,
			total = #VfxTextures.ORDER,
			bad = if #bad > 0 then table.concat(bad, ", ") else Text.now("animlab.none"),
		})
		print("[AnimLab] vfx tex", HttpService:JSONEncode(result))
		local out: { [string]: any } = { ok = true, result = result }
		return out
	elseif sub == "stats" then
		local stats = vfxStats()
		notify("animlab.vfx.stats", {
			active = `{stats.active}/{stats.maxActive}`,
			emitters = `{stats.emitters}/{stats.limits.emitters}`,
			beams = `{stats.beams + stats.surfaces}/{stats.limits.beams}`,
			decals = `{stats.decals}/{stats.limits.decals}`,
			lights = `{stats.lights}/{stats.limits.lights}`,
		})
		print("[AnimLab] vfx stats", HttpService:JSONEncode(stats))
		stats.ok = true
		return stats
	end
	-- all [stress]: every piece in turn at the target (and at every stress mannequin with `stress`)
	local token = vfxRun
	local stress = command.slot == "stress"
	task.spawn(function()
		for _, name in AnimLab.VFX_PIECES do
			if token ~= vfxRun then
				return
			end
			local at = vfxAt()
			if at then
				notify("animlab.vfx.piece", { piece = name })
				local color = classColor(myClass())
				playPiece(name, at, vfxFrom(), color, VfxTextures.runeOf(myClass()), dummy or actor, actor)
				if stress then
					for _, entry in stressed do
						local root = entry.model:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root then
							local spot = root.Position - Vector3.new(0, rootHeight(entry.model), 0)
							playPiece(name, spot + root.CFrame.LookVector * 3, spot, color, "magicCircle", entry.model)
						end
					end
				end
			end
			task.wait(LAB.vfxEvery)
		end
	end)
	notify("animlab.vfx.all", { n = #AnimLab.VFX_PIECES, every = LAB.vfxEvery })
	return { ok = true, pieces = AnimLab.VFX_PIECES, stress = stress }
end

local function stateOf(): { [string]: any }
	return {
		stage = stage ~= nil,
		motion = describe(last),
		t = if heldT then round(heldT :: number) elseif last then round(Clock.now() - startedAt) else 0,
		frozen = heldT ~= nil,
		pending = pendingT,
		vfxActive = Pool.activeCount(),
		vfxMax = Config.Vfx.maxActive,
		animated = Animation.AnimatedCount(),
		dummies = #row + #stressed + (if actor then 1 else 0) + (if dummy then 1 else 0),
		clockPending = Clock.pending(),
		sfx = SfxCtl.Stats(),
		vfx = vfxStats(),
	}
end

-- S111: where `sfx` plays: in front of the actor (C + (0, 3, -3)), without the stage in front of the camera.
local function sfxAt(): Vector3?
	if stage then
		return centre + Vector3.new(0, 3, -3)
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position + camera.CFrame.LookVector * 4 else nil
end

-- S111: sfx <key> [n] | sfx list [prefix] | sfx all [prefix] | sfx try <assetId> (works without the stage too).
local function runSfx(command: Command): { [string]: any }
	local sub = command.id :: string
	local prefix = command.slot
	if sub == "try" then
		local result = SfxCtl.Audition("rbxassetid://" .. (command.slot :: string), sfxAt())
		notify("animlab.sfx.try", { id = result.id, loaded = yesNo(result.loaded), length = result.length })
		print("[AnimLab] sfx", HttpService:JSONEncode(result))
		return result
	elseif sub == "list" then
		local keys = Sfx.keys(prefix)
		local empty: { string } = {}
		for _, key in keys do
			if not Sfx.playable(key) then
				table.insert(empty, key)
			end
		end
		local result = { ok = true, total = #keys, playable = #keys - #empty, empty = empty }
		notify("animlab.sfx.list", {
			prefix = prefix or "*",
			total = #keys,
			playable = #keys - #empty,
			empty = if #empty > 0 then table.concat(empty, ", ") else Text.now("animlab.none"),
		})
		print("[AnimLab] sfx", HttpService:JSONEncode(result))
		return result
	elseif sub == "all" then
		local list: { string } = {}
		for _, key in Sfx.keys(prefix) do
			if Sfx.playable(key) then
				table.insert(list, key)
			end
		end
		local token = sfxRun
		task.spawn(function()
			for _, key in list do
				if token ~= sfxRun then
					return
				end
				local result = SfxCtl.Preview(key, nil, sfxAt())
				print("[AnimLab] sfx", HttpService:JSONEncode(result))
				task.wait(Config.Sfx.allEvery)
			end
		end)
		notify("animlab.sfx.all", { n = #list, prefix = prefix or "*", every = Config.Sfx.allEvery })
		return { ok = true, keys = list }
	end
	if not Sfx.has(sub) then
		notify("animlab.sfx.unknown", { key = sub })
		return { ok = false, error = "unknown", key = sub }
	end
	if not Sfx.playable(sub) then
		notify("animlab.sfx.empty", { key = sub })
		return { ok = false, error = "empty", key = sub }
	end
	local result = SfxCtl.Preview(sub, command.n, sfxAt())
	notify("animlab.sfx.played", {
		key = sub,
		n = result.n,
		id = result.id,
		loaded = yesNo(result.loaded),
		length = result.length,
	})
	print("[AnimLab] sfx", HttpService:JSONEncode(result))
	return result
end

-- S113 `clip <assetId> [attack <type> [step] | skill <id>]`: loads the clip on the actor (yields up to
-- ClipFit.LOAD_SECONDS), reads its "Hit" marker (KeyframeSequenceProvider, Studio), fits the speed to the server's hit
-- of the attack step or the skill (Logic/ClipFit) and plays it in a loop; the answer has the line to paste.
local function runClip(command: Command): { [string]: any }
	local a = actor
	local humanoid = a and a:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not a or not animator then
		return { ok = false, error = "no animator" }
	end
	stopClip()
	local id = "rbxassetid://" .. (command.id :: string)
	CharacterClips.retry(id)
	local serverHit: number
	local what: string
	if command.slot == "skill" then
		serverHit = SkillMotions.hitDelay(command.ref :: string)
		what = `skill {command.ref}`
	else
		local weaponType = command.ref or actorWeapon or "sword1h"
		local wt = if weaponType == "unarmed" then nil else weaponType
		serverHit = AttackPose.timing(AttackPose.motionFor(wt), nil, command.n or 1).hitAt
		what = `attack {weaponType} {command.n or 1}`
		if command.ref and actorWeapon ~= weaponType then
			giveWeapon(a, wt, classColor(myClass()))
			actorWeapon = weaponType
		end
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, loaded = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok or not loaded then
		notify("animlab.clip.failed", { id = id })
		return { ok = false, error = "load", id = id }
	end
	local track = loaded :: AnimationTrack
	local deadline = os.clock() + ClipFit.LOAD_SECONDS
	while os.clock() < deadline and track.Length <= 0 do
		task.wait(0.1)
	end
	if track.Length <= 0 then
		track:Destroy()
		notify("animlab.clip.failed", { id = id })
		return { ok = false, error = "not loaded", id = id, loaded = false }
	end
	local clip: ClipFit.Clip = { id = id, hit = ClipFit.MARKER }
	local marker = CharacterClips.measureNow(clip)
	local speed, fits = ClipFit.speed(clip, serverHit, marker)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0)
	track:AdjustSpeed(0)
	clipRun = { track = track, speed = speed, length = track.Length, marker = marker }
	local line = if marker
		then `\{ id = "{id}", hit = "Hit", hitTime = {round(marker)} \}`
		else `\{ id = "{id}", hit = "Hit" \}`
	notify("animlab.clip.info", {
		id = id,
		length = round(track.Length),
		marker = if marker then round(marker) else Text.now("animlab.none"),
		what = what,
		hit = round(serverHit),
		speed = round(speed),
		fits = yesNo(fits),
	})
	notify("animlab.clip.line", { line = line })
	local result = {
		ok = true,
		id = id,
		loaded = true,
		length = round(track.Length),
		marker = if marker then round(marker) else nil,
		serverHit = round(serverHit),
		speed = round(speed),
		fits = fits,
		minSpeed = ClipFit.MIN_SPEED,
		maxSpeed = ClipFit.MAX_SPEED,
		line = line,
	}
	print("[AnimLab] clip", HttpService:JSONEncode(result))
	return result
end

-- Runs a command; returns the result for AnimLabCall (always with `ok`).
local function runCommand(command: Command): { [string]: any }
	local action = command.action
	sfxRun += 1
	vfxRun += 1
	if action == "sfx" then
		return runSfx(command)
	elseif action == "vfx" and not AnimLab.isVfxPiece(command) then
		return runVfxTool(command)
	elseif action == "vfx" and not stage then
		-- without the stage a piece plays once in front of the camera (no freeze, no loop)
		playVfx(command)
		return { ok = true, motion = describe(command), stage = false }
	end
	if action == "on" then
		if not build() then
			return { ok = false, error = "no character" }
		end
		-- effects of a model far from the camera play their simple versions: look at the stage at once
		setCamera("threequarter")
		notify("animlab.on", { height = LAYOUT.height, dummies = #row + 2 })
		return { ok = true, centre = { round(centre.X), round(centre.Y), round(centre.Z) } }
	elseif action == "off" then
		teardown()
		notify("animlab.off")
		return { ok = true }
	elseif action == "state" then
		local s = stateOf()
		notify("animlab.state", {
			stage = Text.now(if s.stage then "animlab.yes" else "animlab.no"),
			what = s.motion,
			t = s.t,
			frozen = Text.now(if s.frozen then "animlab.yes" else "animlab.no"),
			vfx = `{s.vfxActive}/{s.vfxMax}`,
			animated = s.animated,
			dummies = s.dummies,
		})
		print("[AnimLab] state", HttpService:JSONEncode(s))
		s.ok = true
		return s
	end
	if not stage then
		notify("animlab.noStage")
		return { ok = false, error = "no stage" }
	end
	local loadedClip: { [string]: any }? = nil
	if action == "clip" then
		playing += 1
		Clock.resume()
		local result = runClip(command)
		if result.ok ~= true then
			return result
		end
		loadedClip = result
	end
	if
		action == "attack"
		or action == "skill"
		or action == "mob"
		or action == "boss"
		or action == "npc"
		or action == "vfx"
		or action == "hit"
		or action == "flinch"
		or action == "clip"
	then
		if action ~= "clip" then
			playing += 1
			Clock.resume()
		end
		play(command)
		notify("animlab.playing", { what = describe(command) })
		local keys = lastKeys
		local result: { [string]: any } = loadedClip or { ok = true }
		result.motion = describe(command)
		result.keys = if keys then keysJson(keys) else nil
		if keys then
			-- E3: a motion prints its control frames
			notify("animlab.keys", { what = describe(command), keys = keysText(keys) })
			print("[AnimLab] keys", HttpService:JSONEncode(result))
		end
		return result
	elseif action == "cam" then
		local pos, look = setCamera(command.id)
		if not pos or not look then
			notify("animlab.camOff")
			return { ok = true }
		end
		local p = { round(pos.X), round(pos.Y), round(pos.Z) }
		local l = { round(look.X), round(look.Y), round(look.Z) }
		local text = `{p[1]}, {p[2]}, {p[3]}`
		notify("animlab.cam", { name = command.id, pos = text, look = `{l[1]}, {l[2]}, {l[3]}` })
		local result = { ok = true, camera_position = p, look_at_position = l }
		print("[AnimLab] cam", HttpService:JSONEncode(result))
		return result
	elseif action == "floor" then
		-- S117: the floor as grass, snow or a cave (telegraph readability)
		local spec = (LAB.floors :: any)[command.id :: string]
		for _, name in { "Floor", "SubjectFloor" } do
			local floorPart = (stage :: Folder):FindFirstChild(name)
			if spec and floorPart and floorPart:IsA("BasePart") then
				floorPart.Material = (Enum.Material :: any)[spec.material]
				floorPart.Color = Color3.fromHex(spec.color)
			end
		end
		notify("animlab.floor", { floor = command.id })
		return { ok = true, floor = command.id }
	elseif action == "stress" then
		stress(command.n :: number)
		notify("animlab.stress", { n = command.n, every = LAB.stressEvery })
		return { ok = true, n = #stressed }
	end
	if not last then
		notify("animlab.noMotion")
		return { ok = false, error = "no motion" }
	end
	if action == "loop" then
		loopOn = not loopOn
		notify(if loopOn then "animlab.loopOn" else "animlab.loopOff")
		return { ok = true, loop = loopOn }
	elseif action == "keys" then
		local keys = lastKeys or {}
		notify("animlab.keys", { what = describe(last), keys = keysText(keys) })
		local result = { ok = true, motion = describe(last), keys = keysJson(keys) }
		print("[AnimLab] keys", HttpService:JSONEncode(result))
		return result
	elseif action == "freeze" then
		task.spawn(freezeAt, command.t :: number)
	elseif action == "step" then
		task.spawn(stepBy, command.t :: number)
	elseif action == "play" then
		resume()
		notify("animlab.resumed")
		return { ok = true }
	end
	return { ok = true }
end

-- Studio review 2026-10-21 (2): every command, then the row's labels for the camera and the actor's weapon; a look
-- placed in the target's place reports how it stands (`ground`).
local function run(command: Command): { [string]: any }
	local result = runCommand(command)
	if stage then
		refreshLabels()
	end
	local ground = subjectGround
	if ground and (command.action == "mob" or command.action == "boss") and result.ok ~= false then
		result.ground = ground
		print("[AnimLab] ground", HttpService:JSONEncode(ground))
	end
	return result
end

-- Waits (AnimLabCall) until a freeze / step has stopped the motion.
local function waitFrozen(): boolean
	local deadline = os.clock() + LAB.freezeWait
	task.wait()
	while os.clock() < deadline do
		if heldT and not pendingT then
			return true
		end
		task.wait()
	end
	return false
end

local function call(line: string): string
	local command, err = AnimLab.parseLine(line)
	if not command then
		return HttpService:JSONEncode({ ok = false, error = err })
	end
	local result = run(command)
	if (command.action == "freeze" or command.action == "step") and result.ok ~= false then
		local frozen = waitFrozen()
		result = { ok = frozen, t = heldT, motion = describe(last), state = stateOf() }
		if frozen and heldT then
			notify("animlab.frozen", { what = describe(last), t = round(heldT :: number) })
		end
	end
	return HttpService:JSONEncode(result)
end

local function installCall()
	if player:FindFirstChild("AnimLabCall") then
		return
	end
	local fn = Instance.new("BindableFunction")
	fn.Name = "AnimLabCall"
	fn.OnInvoke = function(line: any): string
		local ok, result = pcall(call, tostring(line))
		if not ok then
			return HttpService:JSONEncode({ ok = false, error = tostring(result) })
		end
		return result
	end
	fn.Parent = player
end

function AnimLabController.Init(registry: any)
	Animation = registry.Get("AnimationController")
	Vfx = registry.Get("VfxController")
	Combat = registry.Get("CombatFxController")
	MonsterView = registry.Get("MonsterViewController")
	Notifications = registry.Get("NotificationController")
	SfxCtl = registry.Get("SfxController")
end

function AnimLabController.Start()
	if not RunService:IsStudio() then
		return
	end
	Net.On("AdminClient", function(action: any, args: any)
		if action ~= "animlab" or type(args) ~= "table" then
			return
		end
		local list: { string } = {}
		for _, value in args do
			if type(value) == "string" then
				table.insert(list, value)
			end
		end
		local command, err = AnimLab.parse(list)
		if not command then
			notify("admin.animlab.bad", { why = Text.now(err or "animlab.error.action") })
			return
		end
		local ok, result = pcall(run, command)
		if not ok then
			warn(`[AnimLab] {tostring(result)}`)
		elseif (command.action == "freeze" or command.action == "step") and result.ok ~= false then
			task.spawn(function()
				if waitFrozen() and heldT then
					notify("animlab.frozen", { what = describe(last), t = round(heldT :: number) })
				end
			end)
		end
	end)
	if player:GetAttribute("Admin") == true then
		installCall()
	end
	player:GetAttributeChangedSignal("Admin"):Connect(function()
		if player:GetAttribute("Admin") == true then
			installCall()
		end
	end)
	player.CharacterRemoving:Connect(function()
		if stage then
			teardown()
		end
	end)
end

return AnimLabController
