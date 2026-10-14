--!strict
-- Story cutscenes (S102, docs/FABULA.md §2.1; Data/Cutscenes, Logic/Cutscenes). The server queues a scene in
-- character.quests.scenes (false); this controller plays the first queued one once the player is idle (alive, no
-- loading screen, no boss reward card, no quest interaction held, no modal). Playing: comments muted
-- (BarkController.SetQuiet), windows closed, HUD and hotkeys off, movement off, a fade, the shot (the city plan's
-- camera, a point of a map, an NPC, a quest anchor or the player) with the camera moving along Logic/Cutscenes.frame,
-- the map's lighting (WorldController.PreviewEnvironment), client-only figures and light; the lines in the overlay
-- (UI/Screens/Cutscene). Skip: the button, Escape, pad B; next line: click, tap, Space, pad A. Damage taken, death or a
-- map change end it at once like a skip. When the shot cannot be set up (unknown NPC, no ground under the point after
-- streaming) the same texts show as a card over the dimmed view and the camera stays with the player. At the end the
-- server hears CutsceneDone(id) (skipped counts as watched); Play(id) replays a watched scene from the journal without
-- the server. S103: on a cave map (the Tomb of Morvane) the ground under the focus and the figures comes from
-- Logic/CaveTerrain (a ray from the sky would land on the rock over the cave); ghost figures (Data/Cutscenes).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Areas = require(Shared.Data.Areas)
local CaveTerrain = require(Shared.Logic.CaveTerrain)
local Config = require(Shared.Config)
local CutsceneData = require(Shared.Data.Cutscenes)
local CutsceneFigure = require(script.Parent.Parent.Vfx.CutsceneFigure)
local CutsceneScreen = require(script.Parent.Parent.UI.Screens.Cutscene)
local Cutscenes = require(Shared.Logic.Cutscenes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Npcs = require(Shared.Data.Npcs)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Town = require(Shared.Data.Town)

local log = Log.new("CutsceneController")

local CutsceneController = {
	Name = "CutsceneController",
	Deps = { "UIController", "WindowManager", "WorldController", "DungeonController" },
}

type Scene = CutsceneData.Scene
type Shot = CutsceneData.Shot
type Step = { title: string?, subtitle: string?, speaker: string?, line: string?, seconds: number }

local SKIP_ACTION = "VaelthornCutsceneSkip"
local NEXT_ACTION = "VaelthornCutsceneNext"
local STREAM_DISTANCE = 400
local SAFETY = 30 -- seconds over the planned length after which a scene ends anyway

local scope = Fusion.scoped(Fusion)
local UIController: any
local WindowManager: any
local WorldController: any
local DungeonController: any
local Registry: any

local title = scope:Value(nil :: string?)
local subtitle = scope:Value(nil :: string?)
local speaker = scope:Value(nil :: string?)
local lineText = scope:Value(nil :: string?)
local card = scope:Value(false)
local black = scope:Value(0)

-- The scene on screen (nil = none) and how to end it.
type Playing = { id: string, replay: boolean, token: number, finish: (reason: string) -> (), next: () -> () }
local playing: Playing? = nil
local token = 0
local replays: { string } = {}
-- reported (or being reported) to the server: not again until the server has it as seen (true) or dropped it (nil),
-- so /scene play and a new trigger after /scene reset play it again in the same session
local finishedHere: { [string]: boolean } = {}

local function lazy(name: string): any
	return Registry and Registry.Get(name)
end

local function controls(): any
	local ok, result = pcall(function()
		local module = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		return (require :: any)(module):GetControls()
	end)
	return if ok then result else nil
end

local function setControls(enabled: boolean)
	local c = controls()
	if c then
		pcall(function()
			if enabled then
				c:Enable()
			else
				c:Disable()
			end
		end)
	end
end

local function root(): BasePart?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function idle(): boolean
	if State.Get({ "session", "phase" }) ~= "playing" or State.Get({ "death" }) ~= nil then
		return false
	end
	if not root() then
		return false
	end
	if WorldController.IsLoading() or DungeonController.RewardVisible() then
		return false
	end
	if State.Get({ "questUse" }) ~= nil or WindowManager.HasModal() then
		return false
	end
	return true
end

-- Shot geometry ------------------------------------------------------------------------------------------------------

local function offsetOf(mapId: string?): Vector3?
	local map = Maps.get(mapId or "")
	return if map then Vector3.new(map.offset.x, map.offset.y, map.offset.z) else nil
end

local function rayParams(folder: Instance?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list: { Instance } = {}
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(list, character)
	end
	if folder then
		table.insert(list, folder)
	end
	params.FilterDescendantsInstances = list
	return params
end

local function ground(point: Vector3, folder: Instance?, mapId: string?): number?
	-- S103: a cave or a boss chamber knows its floor (the rock over it would stop a ray from the sky)
	local cave = if mapId then CaveTerrain.get(mapId) else nil
	local offset = offsetOf(mapId)
	if cave and offset then
		local floor = cave.floor(point.X - offset.X, point.Z - offset.Z)
		if floor then
			return offset.Y + floor
		end
	end
	local hit = Workspace:Raycast(point + Vector3.new(0, 400, 0), Vector3.new(0, -900, 0), rayParams(folder))
	return if hit then hit.Position.Y else nil
end

local function npcModel(npcId: string): Model?
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Npcs")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("NpcId") == npcId then
			return model
		end
	end
	return nil
end

local function anchorPart(anchorId: string): BasePart?
	for _, instance in game:GetService("CollectionService"):GetTagged("QuestAnchor") do
		if instance:IsA("BasePart") and instance:GetAttribute("AnchorId") == anchorId then
			return instance
		end
	end
	return nil
end

-- The rough point of a shot (before streaming) and its map; nil = no shot possible.
local function roughFocus(shot: Shot): (Vector3?, string?, number?)
	local c = Config.Cutscene
	if shot.kind == "self" then
		local r = root()
		if not r then
			return nil, nil, nil
		end
		local look = r.CFrame.LookVector
		local facing = math.deg(math.atan2(-look.X, -look.Z))
		return r.Position + Vector3.new(0, (shot.lift or c.lift) - 3, 0),
			State.Get({ "character", "location", "map" }),
			facing
	elseif shot.kind == "npc" then
		local def = Npcs.get(shot.npc or "")
		if not def then
			return nil, nil, nil
		end
		local model = npcModel(def.id)
		if model then
			return model:GetPivot().Position, def.map, def.facing
		end
		local offset = offsetOf(def.map)
		return if offset then offset + Vector3.new(def.position.x, 0, def.position.z) else nil, def.map, def.facing
	elseif shot.kind == "anchor" then
		local part = anchorPart(shot.anchor or "")
		local data, mapId = Areas.anchorById(shot.anchor or "")
		if part then
			return part.Position, mapId, nil
		end
		local offset = offsetOf(mapId)
		return if offset and data then offset + Vector3.new(data.x, 0, data.z) else nil, mapId, nil
	elseif shot.kind == "point" then
		local offset = offsetOf(shot.map)
		return if offset then offset + Vector3.new(shot.x or 0, 0, shot.z or 0) else nil, shot.map, nil
	end
	-- "city": the city plan's camera
	local offset = offsetOf(Config.StartingMap)
	return if offset
		then offset + Vector3.new(Town.city.selectCamera.look[1], 0, Town.city.selectCamera.look[3])
		else nil,
		Config.StartingMap,
		nil
end

-- Streams the area of a far point in (waits at most Config.Cutscene.streamWait behind the black screen).
local function stream(point: Vector3)
	local r = root()
	if r and (r.Position - point).Magnitude < STREAM_DISTANCE then
		return
	end
	local done = false
	task.spawn(function()
		pcall(function()
			Players.LocalPlayer:RequestStreamAroundAsync(point)
		end)
		done = true
	end)
	local untilTime = os.clock() + Config.Cutscene.streamWait
	while not done and os.clock() < untilTime do
		task.wait(0.1)
	end
end

-- The focus on the ground (+ lift) after streaming; nil = card mode.
local function settleFocus(shot: Shot, rough: Vector3, folder: Instance, mapId: string?): Vector3?
	local c = Config.Cutscene
	if shot.kind == "self" then
		return rough
	elseif shot.kind == "city" then
		return rough + Vector3.new(0, Town.city.selectCamera.look[2], 0)
	elseif shot.kind == "npc" and npcModel(shot.npc or "") then
		local y = ground(rough, folder, mapId)
		return if y then Vector3.new(rough.X, y + (shot.lift or c.lift), rough.Z) else rough
	end
	local y = ground(rough, folder, mapId)
	if not y then
		return nil
	end
	return Vector3.new(rough.X, y + (shot.lift or c.lift), rough.Z)
end

local function vec(t: { x: number, y: number, z: number }): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

-- Camera CFrame of a shot at t (0..1).
local function cameraAt(shot: Shot, focus: Vector3, facing: number?, t: number): CFrame
	if shot.kind == "city" then
		local offset = offsetOf(Config.StartingMap) or Vector3.zero
		local s = Town.city.selectCamera
		local eye = offset + Vector3.new(s.eye[1], s.eye[2], s.eye[3])
		local look = offset + Vector3.new(s.look[1], s.look[2], s.look[3])
		local k = math.clamp(t, 0, 1)
		local orbit = math.rad((shot.orbit or Cutscenes.ORBIT) * k)
		local rel = CFrame.Angles(0, orbit, 0) * (eye - look)
		local dir = rel.Unit
		eye = look + rel - dir * (shot.push or Cutscenes.PUSH) * k
		return CFrame.lookAt(eye, look)
	end
	local eye, look = Cutscenes.frame(shot, { x = focus.X, y = focus.Y, z = focus.Z }, facing, t)
	return CFrame.lookAt(vec(eye), vec(look))
end

-- Steps: the chapter title first ("chapter"), the lines, an end title ("scene" with a title).
local function stepsOf(scene: Scene): { Step }
	local c = Config.Cutscene
	local steps: { Step } = {}
	local function titleStep()
		if scene.title then
			table.insert(steps, {
				title = Text.now(scene.title),
				subtitle = if scene.subtitle then Text.now(scene.subtitle) else nil,
				seconds = c.titleSeconds,
			})
		end
	end
	if scene.kind == "chapter" then
		titleStep()
	end
	for _, item in scene.lines do
		local text = Text.now(item.key)
		local key = Cutscenes.speakerKey(item)
		table.insert(steps, {
			speaker = if key then Text.now(key) else nil,
			line = text,
			seconds = Cutscenes.lineSeconds(text),
		})
	end
	if scene.kind == "scene" then
		titleStep()
	end
	return steps
end

local function fade(to: number, seconds: number)
	local from = Fusion.peek(black)
	local start = os.clock()
	while true do
		local k = math.clamp((os.clock() - start) / math.max(seconds, 0.01), 0, 1)
		black:set(from + (to - from) * k)
		if k >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

-- Reports a played story scene (one retry after 2 s).
local function report(sceneId: string)
	finishedHere[sceneId] = true
	task.spawn(function()
		local ok = Net.Invoke("CutsceneDone", sceneId)
		if not ok then
			task.wait(2)
			ok = Net.Invoke("CutsceneDone", sceneId)
			if not ok then
				log:warn("CutsceneDone %s failed", sceneId)
			end
		end
	end)
end

-- Playing ------------------------------------------------------------------------------------------------------------

local function play(scene: Scene, replay: boolean)
	token += 1
	local myToken = token
	local c = Config.Cutscene
	local folder = Instance.new("Folder")
	folder.Name = "VaelthornCutscene"
	folder.Parent = Workspace
	local connections: { RBXScriptConnection } = {}
	local stopFade: (() -> ())? = nil
	local overlayScope = scope:innerScope()
	local hotkeys = WindowManager.HotkeysEnabled()
	local camera = Workspace.CurrentCamera
	local finished = false
	local skipToNext = false
	local characterId = State.Get({ "character", "id" })

	local function finish(reason: string)
		if finished then
			return
		end
		finished = true
		log:info("scene %s ended (%s)", scene.id, reason)
		task.spawn(function()
			if reason ~= "interrupted" then
				fade(1, c.fade * 0.5)
			end
			for _, connection in connections do
				connection:Disconnect()
			end
			if stopFade then
				stopFade()
			end
			folder:Destroy()
			pcall(function()
				ContextActionService:UnbindAction(SKIP_ACTION)
				ContextActionService:UnbindAction(NEXT_ACTION)
			end)
			WindowManager.SetEscapeOverride(nil)
			WorldController.PreviewEnvironment(nil)
			local screens = lazy("ScreenController")
			if screens and screens.RestoreCamera then
				screens.RestoreCamera()
			end
			setControls(true)
			UIController.SetHudHidden(false)
			WindowManager.SetHotkeysEnabled(hotkeys)
			local barks = lazy("BarkController")
			if barks then
				barks.SetQuiet("cutscene", false)
			end
			title:set(nil)
			subtitle:set(nil)
			speaker:set(nil)
			lineText:set(nil)
			card:set(false)
			fade(0, c.fade * 0.5)
			Fusion.doCleanup(overlayScope)
			-- a scene cut by a character switch stays queued for its own character
			if not replay and State.Get({ "character", "id" }) == characterId then
				report(scene.id)
			end
			if playing and playing.token == myToken then
				playing = nil
			end
		end)
	end

	playing = {
		id = scene.id,
		replay = replay,
		token = myToken,
		finish = finish,
		next = function()
			skipToNext = true
		end,
	}

	-- quiet world, no input, no HUD
	local barks = lazy("BarkController")
	if barks then
		barks.SetQuiet("cutscene", true)
	end
	WindowManager.CloseAll()
	WindowManager.SetHotkeysEnabled(false)
	setControls(false)
	CutsceneScreen(overlayScope, {
		Title = title,
		Subtitle = subtitle,
		Speaker = speaker,
		Line = lineText,
		Card = card,
		CardDim = c.cardDim,
		Black = black,
		OnSkip = function()
			finish("skipped")
		end,
		OnNext = function()
			skipToNext = true
		end,
	}).Parent =
		UIController.GetLayer("Modals")
	WindowManager.SetEscapeOverride(function()
		finish("skipped")
	end)
	ContextActionService:BindActionAtPriority(SKIP_ACTION, function(_, inputState): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin then
			finish("skipped")
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority(NEXT_ACTION, function(_, inputState): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin then
			skipToNext = true
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	-- damage, death or a new map end the scene at once
	local hp = State.Value({ "character", "hp" })
	local lastHp = Fusion.peek(hp)
	overlayScope:Observer(hp):onChange(function()
		local now = Fusion.peek(hp)
		if type(now) == "number" and type(lastHp) == "number" and now < lastHp then
			finish("interrupted")
		end
		lastHp = now
	end)
	local map = State.Get({ "character", "location", "map" })
	overlayScope:Observer(State.Value({ "character", "location", "map" })):onChange(function()
		if State.Get({ "character", "location", "map" }) ~= map then
			finish("interrupted")
		end
	end)
	overlayScope:Observer(State.Value({ "death" })):onChange(function()
		if State.Get({ "death" }) ~= nil then
			finish("interrupted")
		end
	end)
	Sounds.play("open")

	fade(1, c.fade)
	if finished then
		return
	end
	UIController.SetHudHidden(true)

	-- the shot
	local shot = scene.shot
	local rough, shotMap, facing = roughFocus(shot)
	local focus: Vector3? = nil
	if rough then
		stream(rough)
		if finished then
			return
		end
		focus = settleFocus(shot, rough, folder, shotMap)
	end
	local steps = stepsOf(scene)
	local total = 0
	for _, step in steps do
		total += step.seconds
	end
	if focus and camera then
		camera.CameraType = Enum.CameraType.Scriptable
		if shotMap and (shotMap ~= map or scene.clock) then
			WorldController.PreviewEnvironment(shotMap, scene.clock)
		end
		local offset = offsetOf(shotMap) or Vector3.zero
		local figures: { CutsceneData.Figure } = scene.figures or {}
		for _, figure in figures do
			local base = offset + Vector3.new(figure.x, 0, figure.z)
			local y = ground(base, folder, shotMap) or focus.Y
			local model = CutsceneFigure.build(
				figure.look,
				CFrame.new(base.X, y, base.Z) * CFrame.Angles(0, math.rad(figure.facing), 0),
				figure.ghost
			)
			model.Parent = folder
			local lastStep = steps[#steps]
			local fadeIn = math.max(0, total - (if lastStep then lastStep.seconds else 0) - 2)
			stopFade = CutsceneFigure.fade(model, figure.fade, fadeIn, 2)
		end
		if scene.light then
			local holder = Instance.new("Part")
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.CanTouch = false
			holder.Transparency = 1
			holder.Size = Vector3.new(0.2, 0.2, 0.2)
			holder.CFrame = CFrame.new(focus + Vector3.new(0, 0.5, 0))
			holder.Parent = folder
			local light = Instance.new("PointLight")
			light.Color = Color3.fromHex(scene.light.color)
			light.Range = scene.light.range
			light.Brightness = 2
			light.Shadows = true
			light.Parent = holder
		end
		local started = os.clock()
		local finalFocus = focus
		camera.CFrame = cameraAt(shot, finalFocus, facing, 0)
		table.insert(
			connections,
			RunService.RenderStepped:Connect(function()
				local t = (os.clock() - started) / math.max(total, 0.1)
				local cam = Workspace.CurrentCamera
				if cam then
					cam.CameraType = Enum.CameraType.Scriptable
					cam.CFrame = cameraAt(shot, finalFocus, facing, t)
				end
			end)
		)
	else
		-- card mode (DESIGN-15 §0.7): the texts over the dimmed view, the camera stays with the player
		card:set(true)
	end
	fade(0, c.fade)

	-- the lines
	local deadline = os.clock() + total + SAFETY
	for _, step in steps do
		if finished then
			return
		end
		title:set(step.title)
		subtitle:set(step.subtitle)
		speaker:set(step.speaker)
		lineText:set(step.line)
		skipToNext = false
		local stepEnd = os.clock() + step.seconds
		while not finished and not skipToNext and os.clock() < stepEnd and os.clock() < deadline do
			task.wait(0.05)
		end
	end
	finish("done")
end

local function sceneOf(id: string): Scene?
	return CutsceneData.get(id)
end

-- Replays a watched scene (the journal's "▶"); ignored while a story scene plays, queued after another replay.
function CutsceneController.Play(sceneId: string)
	if not sceneOf(sceneId) then
		return
	end
	local current = playing
	if current and not current.replay then
		return
	end
	table.insert(replays, sceneId)
end

-- Whether a cutscene is on screen.
function CutsceneController.IsPlaying(): boolean
	return playing ~= nil
end

local function poll()
	if playing or not idle() then
		return
	end
	local nextReplay = table.remove(replays, 1)
	if nextReplay then
		local scene = sceneOf(nextReplay)
		if scene then
			task.spawn(play, scene, true)
		end
		return
	end
	local scenes = State.Get({ "character", "quests", "scenes" })
	for id in finishedHere do
		if type(scenes) ~= "table" or scenes[id] ~= false then
			finishedHere[id] = nil
		end
	end
	for _, id in Cutscenes.pending(scenes) do
		if not finishedHere[id] then
			local scene = sceneOf(id)
			if scene then
				task.spawn(play, scene, false)
				return
			end
		end
	end
end

function CutsceneController.Init(registry)
	Registry = registry
	UIController = registry.Get("UIController")
	WindowManager = registry.Get("WindowManager")
	WorldController = registry.Get("WorldController")
	DungeonController = registry.Get("DungeonController")
end

function CutsceneController.Start()
	-- a new character (character select) starts with nothing reported
	scope:Observer(State.Value({ "character", "id" })):onChange(function()
		table.clear(finishedHere)
		table.clear(replays)
		local current = playing
		if current then
			current.finish("interrupted")
		end
	end)
	-- input that UserInputService sees outside the overlay: clicks and taps on the 3D view go to the next line
	UserInputService.InputBegan:Connect(function(input, processed)
		local current = playing
		if not current or processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			current.next()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Cutscene.idlePoll)
			local ok, err = pcall(function(): string?
				poll()
				return nil
			end)
			if not ok then
				log:warn("poll failed: %s", tostring(err))
			end
		end
	end)
end

return CutsceneController
