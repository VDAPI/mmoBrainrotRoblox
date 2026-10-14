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

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimLab = require(ReplicatedStorage.Shared.Logic.AnimLab)
local AttackMotions = require(ReplicatedStorage.Shared.Data.AttackMotions)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Clock = require(script.Parent.Parent.Vfx.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Gait = require(ReplicatedStorage.Shared.Logic.Gait)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LookAnim = require(ReplicatedStorage.Shared.Logic.LookAnim)
local MonsterLooks = require(ReplicatedStorage.Shared.Data.MonsterLooks)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local MotionKeys = require(ReplicatedStorage.Shared.Logic.MotionKeys)
local MountLook = require(ReplicatedStorage.Shared.Util.MountLook)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Pool = require(script.Parent.Parent.Vfx.Pool)
local Skills = require(ReplicatedStorage.Shared.Data.Skills)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local WeaponBuild = require(ReplicatedStorage.Shared.Util.WeaponBuild)

local AnimLabController = {
	Name = "AnimLabController",
	Deps = {
		"AnimationController",
		"VfxController",
		"CombatFxController",
		"MonsterViewController",
		"NotificationController",
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
local player = Players.LocalPlayer

local stage: Folder? = nil
local centre = Vector3.zero -- C: the floor top under the actor
local actor: Model? = nil
local actorWeapon: string? = nil
local dummy: Model? = nil
local subject: Subject? = nil
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

local function label(model: Model, text: string)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "AnimLabLabel"
	gui.Size = UDim2.fromOffset(120, 24)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
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
		return nil, nil
	end
	local spec = (LAYOUT.cameras :: any)[name]
	local pos, look = centre + vec(spec.pos), centre + vec(spec.look)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(pos, look)
	cameraOn = true
	return pos, look
end

local step: (dt: number) -> ()

local function teardown()
	playing += 1
	loopOn = false
	pendingT = nil
	heldT = nil
	Clock.resume()
	local a = actor
	if a then
		Animation.LabClear(a)
	end
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

-- Puts a monster / boss look in the target's place, facing the actor.
local function placeLook(id: string, look: MonsterLooks.Look, variant: string, scale: number): Model
	clearSubject()
	local model, info = MonsterView.BuildPreview(id, look, variant, scale, CFrame.new())
	local d = dummy
	if d then
		d.Parent = nil
	end
	local target = vec(LAYOUT.target)
	-- the front of a big look stays where the dummy stood
	local at = centre
		+ Vector3.new(target.X, info.hipHeight + info.rootHalf, target.Z - math.max(0, info.width / 2 - 1))
	model:PivotTo(CFrame.lookAt(at, Vector3.new(centre.X, at.Y, centre.Z)))
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanQuery = false
		end
	end
	model.Parent = stage
	return model
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
	local windup = if slot == "cast" then LAB.castWindup else Gait.DEFAULT_WINDUP
	-- a basic monster attack (attack1) comes with its damage: the windup is mostly skipped (MonsterAttack strikeNow)
	local strikeNow = slot == "attack1"
	local asset = look.asset
	local track, looped = nil, false
	if asset and asset.rig == "animator" then
		track, looped = clipOf(model, asset.anims :: any, slot)
	end
	subject = {
		model = model,
		joints = collect(model),
		slot = slot,
		windup = windup,
		shift = if strikeNow then math.max(0, windup - 0.06) else 0,
		track = track,
		looped = looped,
		keys = keysForSlot(slot, windup, strikeNow, track),
	}
end

local function playBoss(command: Command)
	local bossId, attackId = command.id :: string, command.slot :: string
	local boss = Bosses.get(bossId)
	local look = MonsterLooks.get(bossId)
	if not boss or not look then
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
	local model = placeLook(bossId, look, "boss", boss.look.size)
	local slot = if attack.windup > 1 then "cast" else "attack2"
	local asset = look.asset
	local track, looped = nil, false
	if asset and asset.rig == "animator" then
		track, looped = clipOf(model, asset.anims :: any, slot)
	end
	subject = {
		model = model,
		joints = collect(model),
		slot = slot,
		windup = attack.windup,
		shift = 0,
		track = track,
		looped = looped,
		keys = MotionKeys.boss(bossId, attackId) or MotionKeys.monster(attack.windup),
	}
	-- the telegraph like CombatService sends it: around the boss for "self" circles / rings, on the actor for the
	-- other circles, from the boss towards the actor for cones and lines
	local bossAt = Vector3.new(model:GetPivot().Position.X, centre.Y, model:GetPivot().Position.Z)
	local actorAt = centre + vec(LAYOUT.actor)
	local toActor = Vector3.new(actorAt.X - bossAt.X, 0, actorAt.Z - bossAt.Z)
	local dir = if toActor.Magnitude > 0.01 then toActor.Unit else Vector3.new(0, 0, 1)
	local isRound = attack.shape == "circle" or attack.shape == "ring"
	local origin = if isRound and attack.target ~= "self" then actorAt else bossAt
	Combat.PreviewTelegraph({
		k = "tele",
		sh = attack.shape,
		cf = CFrame.lookAt(origin, origin + dir),
		r = attack.radius,
		ir = attack.inner,
		an = attack.angle,
		l = attack.length,
		w = attack.width,
		t = attack.windup,
		el = attack.element,
	})
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
	Animation.LabClear(a)
	heldT = nil
	pendingT = nil
	local action = command.action
	if action == "attack" then
		clearSubject()
		local weaponType = command.id :: string
		if actorWeapon ~= weaponType then
			giveWeapon(a, weaponType, classColor(myClass()))
			actorWeapon = weaponType
		end
		Combat.PreviewAttack(if weaponType == "unarmed" then nil else weaponType, a)
		lastKeys = MotionKeys.attack(weaponType)
	elseif action == "skill" then
		clearSubject()
		local id = command.id :: string
		local skill = Skills.get(id)
		local weaponType = AnimLab.weaponForSkill(id)
		if actorWeapon ~= weaponType then
			giveWeapon(a, weaponType, classColor(if skill then skill.class else myClass()))
			actorWeapon = weaponType
		end
		Vfx.Preview(a, id)
		-- the same loopUntil the preview's motion plays with (beam, channel, castTime)
		lastKeys = MotionKeys.skill(id, Vfx.PreviewLoopUntil(id))
	elseif action == "mob" then
		playMob(command)
		lastKeys = if subject then subject.keys else nil
	elseif action == "boss" then
		playBoss(command)
		lastKeys = if subject then subject.keys else nil
	elseif action == "npc" then
		playNpc(command)
		lastKeys = if subject then subject.keys else nil
	end
	last = command
	startedAt = Clock.now()
	playedAt = startedAt
end

local function motionLength(): number
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
		local a = actor
		if a then
			Animation.LabHold(a, pending)
		end
	end
	local s = subject
	if s then
		if s.track then
			s.track.TimePosition = LookAnim.clipTime(t, s.track.Length, s.looped)
		end
		if #s.joints > 0 then
			local motion = Gait.stateMotion(s.slot :: Gait.Slot, t + s.shift, { windup = s.windup })
			for _, j in s.joints do
				local p = Gait.pose(j.joint, motion)
				local k = j.scale
				j.motor.Transform = CFrame.new(p.x * k, p.y * k, p.z * k) * CFrame.Angles(p.rx, p.ry, p.rz)
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
	local a = actor
	if a then
		Animation.LabHold(a, nil)
		Animation.LabClear(a)
	end
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
		if a then
			Animation.LabHold(a, 0)
		end
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
	local a = actor
	if a then
		Animation.LabHold(a, nil)
	end
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
	}
end

-- Runs a command; returns the result for AnimLabCall (always with `ok`).
local function run(command: Command): { [string]: any }
	local action = command.action
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
	if action == "attack" or action == "skill" or action == "mob" or action == "boss" or action == "npc" then
		playing += 1
		Clock.resume()
		play(command)
		notify("animlab.playing", { what = describe(command) })
		local keys = lastKeys
		local result = { ok = true, motion = describe(command), keys = if keys then keysJson(keys) else nil }
		if keys then
			-- E3: a motion prints its control frames
			notify("animlab.keys", { what = describe(command), keys = keysText(keys) })
			print("[AnimLab] keys", HttpService:JSONEncode(result))
		end
		return result
	elseif action == "sfx" then
		notify("animlab.notYet", { session = "S111" })
		return { ok = false, error = "notYet" }
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
