--!strict
-- The world on the client (S08):
--   * environment: on entering a map, Lighting / Atmosphere / colour grading (and music, once maps have
--     tracks) tween to the map's settings from Data/Maps; on maps with `dayNight` (S21: the city) the clock
--     runs from the shared server time (Logic/DayCycle, offset from the Workspace attribute "DayOffset" set by
--     /daytime) and the lighting blends between the day and night presets once a second,
--   * mood (S26): AmbienceController hands over the current area's light modulation (Data/Ambience), applied on
--     top of the map's light and the day and night blend, re-applied ~10 times a second while it changes,
--   * loading screen on MapTransition (map name, levels, zone, a random tip), faded in and out,
--   * GroundCheck: the server holds the character anchored after a spawn or teleport until this client has the
--     ground under the target streamed in (server Placement), answered with GroundReady,
--   * portals (tag "Portal"): nameplate with the target map and levels, "Travel [E]" prompt; entering a red
--     zone or a map above your level asks for confirmation first.
-- Also registers the world map window (M, UI/Screens/WorldMap; S25: interactive cards, guide and walk).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local AreaPicker = require(script.Parent.Parent.UI.Screens.AreaPicker)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local DayCycle = require(ReplicatedStorage.Shared.Logic.DayCycle)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local MapSketch = require(script.Parent.Parent.UI.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local WorldMapWindow = require(script.Parent.Parent.UI.Screens.WorldMap)

local WorldController = {
	Name = "WorldController",
	Deps = { "WindowManager", "SettingsController", "NavController", "MonsterViewController", "PartyController" },
}

local TIP_COUNT = 10
local FADE = 0.35

local scope = Fusion.scoped(Fusion)
local WindowManager: any

local atmosphere: Atmosphere
local grade: ColorCorrectionEffect
local music: Sound
local appliedMap = ""

-- Environment ------------------------------------------------------------------------------------

-- Time of day on maps with day and night (S21): clock 0..24 and how dark it is (0 day .. 1 night).
function WorldController.TimeOfDay(): (number, number)
	local offset = workspace:GetAttribute("DayOffset")
	local now = workspace:GetServerTimeNow() + (if type(offset) == "number" then offset else 0)
	local clock = DayCycle.clock(now, Config.DayLength, Config.DayNightShare)
	return clock, DayCycle.nightness(clock)
end

-- Whether the map the player is on runs the day and night cycle.
function WorldController.HasDayNight(): boolean
	local map = Maps.get(appliedMap)
	return map ~= nil and map.dayNight == true and map.nightLighting ~= nil
end

local function mix(a: string, b: string, t: number): Color3
	return Color3.fromHex(a):Lerp(Color3.fromHex(b), t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Lighting, Atmosphere and colour grading properties of a map right now (day/night blend when it has one).
local function environment(map: Maps.MapDef): ({ [string]: any }, { [string]: any }, { [string]: any })
	local day = map.lighting
	local night = if map.dayNight then map.nightLighting else nil
	local clock, t = day.clockTime, 0
	if night then
		clock, t = WorldController.TimeOfDay()
		if map.dayClock then
			-- S45: eternal dusk (Duskwood): the day's sun stays low
			clock = DayCycle.duskClock(clock, t, map.dayClock[1], map.dayClock[2])
		end
	end
	local n = night or day
	return {
		ClockTime = clock,
		Brightness = lerp(day.brightness, n.brightness, t),
		Ambient = mix(day.ambient, n.ambient, t),
		OutdoorAmbient = mix(day.outdoorAmbient, n.outdoorAmbient, t),
		FogColor = mix(day.fogColor, n.fogColor, t),
		FogEnd = lerp(day.fogEnd, n.fogEnd, t),
	}, {
		Density = lerp(day.atmosphere.density, n.atmosphere.density, t),
		Haze = lerp(day.atmosphere.haze, n.atmosphere.haze, t),
		Glare = lerp(day.atmosphere.glare, n.atmosphere.glare, t),
		Color = mix(day.atmosphere.color, n.atmosphere.color, t),
		Decay = mix(day.atmosphere.decay, n.atmosphere.decay, t),
	}, {
		TintColor = mix(day.tint, n.tint, t),
		Saturation = lerp(day.saturation, n.saturation, t),
	}
end

-- Light modulation of the current area (S26, AmbienceController): fog distance / colour, tint, saturation,
-- brightness, atmosphere haze and density. nil = none.
export type Modulation = {
	fogScale: number,
	fogColor: Color3,
	fogMix: number,
	tint: Color3,
	tintMix: number,
	saturation: number,
	brightness: number,
	haze: number,
	density: number,
}
local modulation: Modulation? = nil
local modulationDirty = false

function WorldController.SetModulation(mod: Modulation?)
	modulation = mod
	modulationDirty = true
end

local function modulate(lighting: { [string]: any }, air: { [string]: any }, grading: { [string]: any })
	local m = modulation
	if not m then
		return
	end
	lighting.FogEnd *= m.fogScale
	lighting.FogColor = (lighting.FogColor :: Color3):Lerp(m.fogColor, m.fogMix)
	lighting.Brightness *= m.brightness
	air.Haze = math.clamp(air.Haze + m.haze, 0, 10)
	air.Density = math.clamp(air.Density + m.density, 0, 1)
	grading.TintColor = (grading.TintColor :: Color3):Lerp(m.tint, m.tintMix)
	grading.Saturation = math.clamp(grading.Saturation + m.saturation, -1, 1)
end

-- The day/night loop leaves the lighting alone while the map-entry tween runs.
local tweenUntil = 0

local function applyEnvironment(mapId: string)
	local map = Maps.get(mapId)
	if not map or mapId == appliedMap then
		return
	end
	appliedMap = mapId
	local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine)
	local lightingProps, atmosphereProps, gradeProps = environment(map)
	modulate(lightingProps, atmosphereProps, gradeProps)
	TweenService:Create(Lighting, info, lightingProps):Play()
	TweenService:Create(atmosphere, info, atmosphereProps):Play()
	TweenService:Create(grade, info, gradeProps):Play()
	tweenUntil = os.clock() + 1.6
	-- Music crossfade (tracks arrive with S14; empty id = silence).
	local volume = 0.35
	TweenService:Create(music, TweenInfo.new(1), { Volume = 0 }):Play()
	task.delay(1, function()
		if appliedMap ~= mapId then
			return
		end
		music.SoundId = map.music
		if map.music ~= "" then
			music:Play()
			TweenService:Create(music, TweenInfo.new(1.5), { Volume = volume }):Play()
		else
			music:Stop()
		end
	end)
end

-- Loading screen ---------------------------------------------------------------------------------

local loadingGui: ScreenGui
local loadingFrame: CanvasGroup
local loadingTitle: TextLabel
local loadingSub: TextLabel
local loadingTip: TextLabel

local function buildLoading()
	loadingGui = Instance.new("ScreenGui")
	loadingGui.Name = "Vaelthorn_Loading"
	loadingGui.DisplayOrder = 100
	loadingGui.IgnoreGuiInset = true
	loadingGui.ResetOnSpawn = false
	loadingGui.Enabled = false
	loadingGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	loadingFrame = Instance.new("CanvasGroup")
	loadingFrame.Size = UDim2.fromScale(1, 1)
	loadingFrame.BackgroundColor3 = Theme.Colors.Background
	loadingFrame.GroupTransparency = 1
	loadingFrame.Parent = loadingGui
	local function label(y: number, size: number, font: Font, color: Color3): TextLabel
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.new(0.5, 0, 0.5, y)
		t.Size = UDim2.new(0.8, 0, 0, size + 10)
		t.BackgroundTransparency = 1
		t.TextSize = size
		t.FontFace = font
		t.TextColor3 = color
		t.TextWrapped = true
		t.Parent = loadingFrame
		return t
	end
	loadingTitle = label(-40, 54, Theme.Fonts.Heading, Theme.Colors.Gold)
	loadingSub = label(14, 24, Theme.Fonts.BodyBold, Theme.Colors.Parchment)
	loadingTip = label(120, 20, Theme.Fonts.Body, Theme.Colors.TextMuted)
end

local function showLoading(mapId: string?)
	if not mapId then
		TweenService:Create(loadingFrame, TweenInfo.new(FADE), { GroupTransparency = 1 }):Play()
		task.delay(FADE, function()
			if loadingFrame.GroupTransparency >= 0.99 then
				loadingGui.Enabled = false
			end
		end)
		return
	end
	local map = Maps.get(mapId)
	if not map then
		return
	end
	loadingTitle.Text = Text.now(map.nameKey)
	local zone = Text.now(`zone.{map.zone}`)
	loadingSub.Text = if map.id == "city" then zone else `{map.minLevel}–{map.maxLevel} · {zone}`
	loadingSub.TextColor3 = if map.zone == "red"
		then Theme.Colors.ZoneRed
		elseif map.zone == "yellow" then Theme.Colors.ZoneYellow
		else Theme.Colors.ZoneGreen
	loadingTip.Text = `{Text.now("loading.tip")}: {Text.now(`tip.{math.random(1, TIP_COUNT)}`)}`
	loadingGui.Enabled = true
	TweenService:Create(loadingFrame, TweenInfo.new(FADE), { GroupTransparency = 0 }):Play()
	-- Safety: never stay stuck behind the loading screen.
	task.delay(8, function()
		if loadingGui.Enabled and loadingFrame.GroupTransparency < 0.5 then
			showLoading(nil)
		end
	end)
end

-- Portals ----------------------------------------------------------------------------------------

-- "Where to?" (S22): the area picker shared by portals and the Map Stone.
local pickerMap = scope:Value(nil :: string?)
local pickerWarnings = scope:Value({} :: { string })
local pickerSelected = scope:Value(nil :: string?)
local pickerBusy = scope:Value(false)
local pickerGo: ((areaId: string) -> (boolean, string?))? = nil

local function pickerConfirm()
	local areaId = Fusion.peek(pickerSelected)
	local go = pickerGo
	if not areaId or not go or Fusion.peek(pickerBusy) then
		return
	end
	pickerBusy:set(true)
	task.spawn(function()
		local ok, err = go(areaId)
		pickerBusy:set(false)
		if ok then
			Sounds.play("click")
			WindowManager.Close("areapicker")
		else
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

-- Opens the area picker for a region map; `go(areaId)` does the travel and returns (ok, errorKey?).
function WorldController.OpenAreaPicker(mapId: string, warnings: { string }, go: (areaId: string) -> (boolean, string?))
	local first = AreaAdvice.default(mapId)
	pickerMap:set(mapId)
	pickerWarnings:set(warnings)
	pickerSelected:set(if first then first.id else nil)
	pickerGo = go
	WindowManager.Open("areapicker")
end

-- Whether travelling to `mapId` through this portal offers the area choice (not from cave exits).
function WorldController.HasAreaChoice(mapId: string, portalId: string?): boolean
	if portalId and string.sub(portalId, -5) == "_exit" then
		return false
	end
	return Areas.byMap[mapId] ~= nil
end

local function travel(portalId: string)
	task.spawn(function()
		local ok, err = Net.Invoke("UsePortal", portalId)
		if not ok then
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

local function onPortal(portalId: string, targetId: string)
	local target = Maps.get(targetId)
	if not target then
		return
	end
	if not MapSketch.isBuilt(targetId) then
		Toast.push(Text.now("portal.closed"), "info")
		return
	end
	local warnings = {}
	if target.zone == "red" then
		table.insert(warnings, Text.now("portal.warnRed"))
	end
	local level = State.Get({ "character", "level" }) or 1
	if level < target.minLevel then
		table.insert(warnings, Text.now("portal.warnLevel", { level = target.minLevel }))
	end
	-- S22: region maps open the area picker; the warnings become a line in it.
	if WorldController.HasAreaChoice(targetId, portalId) then
		WorldController.OpenAreaPicker(targetId, warnings, function(areaId: string): (boolean, string?)
			return Net.Invoke("UsePortal", portalId, areaId)
		end)
		return
	end
	if #warnings == 0 then
		travel(portalId)
		return
	end
	WindowManager.ShowModal({
		Title = Text.now(target.nameKey),
		Message = table.concat(warnings, "\n\n"),
		ConfirmText = Text.now("portal.go"),
		CancelText = Text.now("common.cancel"),
		Variant = if target.zone == "red" then "danger" else nil,
		OnConfirm = function(): (boolean, string?)
			travel(portalId)
			return true, nil
		end,
	})
end

local function decoratePortal(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	local portalId = model:GetAttribute("PortalId")
	local targetId = model:GetAttribute("TargetMap")
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if
		type(portalId) ~= "string"
		or type(targetId) ~= "string"
		or not anchor
		or anchor:FindFirstChild("VaelthornPortal")
	then
		return
	end
	local target = Maps.get(targetId)
	if not target then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VaelthornPortal"
	gui.Size = UDim2.fromOffset(280, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Parent = anchor
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 32)
	title.BackgroundTransparency = 1
	title.FontFace = Theme.Fonts.Heading
	title.TextSize = 26
	title.TextColor3 = Theme.Colors.GoldBright
	title.TextStrokeTransparency = 0.3
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromOffset(0, 32)
	sub.Size = UDim2.new(1, 0, 0, 24)
	sub.BackgroundTransparency = 1
	sub.FontFace = Theme.Fonts.BodyBold
	sub.TextSize = 18
	sub.TextStrokeTransparency = 0.3
	sub.TextColor3 = if target.zone == "red"
		then Theme.Colors.ZoneRed
		elseif target.zone == "yellow" then Theme.Colors.ZoneYellow
		else Theme.Colors.ZoneGreen
	sub.Parent = gui
	local prompt = Instance.new("ProximityPrompt")
	Keybinds.bindPrompt(prompt, "interact")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	local function refresh()
		title.Text = Text.now(target.nameKey)
		local built = MapSketch.isBuilt(target.id)
		if not built then
			sub.Text = Text.now("worldmap.soon")
		elseif target.id == "city" then
			sub.Text = Text.now(`zone.{target.zone}`)
		else
			sub.Text = `{target.minLevel}–{target.maxLevel} · {Text.now(`zone.{target.zone}`)}`
		end
		prompt.ActionText = Text.now("portal.travel")
		prompt.ObjectText = Text.now(target.nameKey)
	end
	refresh()
	scope:Observer(Text.Lang):onChange(refresh)
	if not MapSketch.isBuilt(target.id) then
		-- S45: a region built in the background: "Soon" turns into its levels when its sketch is published
		task.spawn(function()
			local sketches = ReplicatedStorage:WaitForChild("MapSketches", 30)
			if not sketches or not gui.Parent then
				return
			end
			local connection: RBXScriptConnection
			connection = sketches.ChildAdded:Connect(function(child: Instance)
				if child.Name == target.id then
					connection:Disconnect()
					if gui.Parent then
						refresh()
					end
				end
			end)
			gui.Destroying:Connect(function()
				connection:Disconnect()
			end)
		end)
	end
	prompt.Triggered:Connect(function()
		onPortal(portalId :: string, target.id)
	end)
end

function WorldController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	-- S25: the interactive map guides, walks, opens profiles and builds 3D previews of monsters.
	local Nav = registry.Get("NavController")
	local MonsterView = registry.Get("MonsterViewController")
	local Party = registry.Get("PartyController")
	WorldMapWindow.setServices({
		Guide = Nav.Guide,
		Walk = Nav.Walk,
		Resolve = Nav.Resolve,
		OpenProfile = function(userId: number)
			WindowManager.Close("map")
			Party.OpenProfile(userId)
		end,
		BuildLook = MonsterView.BuildPreview,
	})
	WindowManager.Register({
		id = "map",
		titleKey = "window.map.title",
		size = Vector2.new(1180, 740), -- S20: up to ~85% of the screen (full screen on phones)
		hotkey = Enum.KeyCode.M,
		build = WorldMapWindow,
	})
	WindowManager.Register({
		id = "areapicker",
		titleKey = "window.areapicker.title",
		size = Vector2.new(560, 560),
		build = function(s)
			return AreaPicker(s, {
				MapId = pickerMap,
				Warnings = pickerWarnings,
				Selected = pickerSelected,
				Busy = pickerBusy,
				OnGo = pickerConfirm,
			})
		end,
	})
end

-- Client-side admin helpers (S20): drop the map cache, report decoration chunks and frame time.
-- Client town detail numbers (S21): buildings with detail, detail and fine parts, last build step, generation.
local function townStats()
	local ok, town = pcall(function()
		return require(script.Parent.TownDetailController) :: any
	end)
	if not ok or not town then
		return
	end
	local builds, detail, fine, lastMs, prepareMs = town.Stats()
	local clock = WorldController.TimeOfDay()
	Toast.push(
		Text.now("admin.perf.town", {
			builds = builds,
			detail = detail,
			fine = fine,
			ms = string.format("%.1f", lastMs),
			gen = math.floor(prepareMs),
			clock = string.format("%02d:%02d", math.floor(clock), math.floor((clock % 1) * 60)),
		}),
		"info",
		8
	)
end

-- /anim (S22): repeats a weapon's attack on our character every second until "off".
local animToken = 0
local function animLoop(kind: string)
	animToken += 1
	local token = animToken
	if kind == "off" then
		return
	end
	local weaponType = if kind == "unarmed" or kind == "none" then nil else kind
	task.spawn(function()
		local ok, combat = pcall(function()
			return require(script.Parent.CombatFxController) :: any
		end)
		while ok and token == animToken do
			combat.PreviewAttack(weaponType)
			task.wait(1)
		end
	end)
end

local function onAdminClient(action: any, arg: any)
	if action == "portalpick" and type(arg) == "string" then
		WorldController.OpenAreaPicker(arg, {}, function(areaId: string): (boolean, string?)
			return Net.Invoke("AdminRun", "arrive", { arg, areaId })
		end)
	elseif action == "anim" and type(arg) == "string" then
		animLoop(arg)
	elseif action == "mapcache" then
		(WorldMapWindow :: any).clearCache()
	elseif action == "town" then
		townStats()
	elseif action == "perf" then
		townStats()
		local ok, decor = pcall(function()
			return require(script.Parent.DecorController) :: any
		end)
		if ok and decor then
			local chunks, parts, frame = decor.Stats()
			Toast.push(
				Text.now("admin.perf.client", {
					chunks = chunks,
					parts = parts,
					ms = string.format("%.1f", frame * 1000),
				}),
				"info",
				6
			)
		end
	end
end

function WorldController.Start()
	Net.On("AdminClient", onAdminClient)
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "VaelthornGrade"
	grade.Parent = Lighting
	music = Instance.new("Sound")
	music.Name = "VaelthornMusic"
	music.Looped = true
	music.Volume = 0
	-- The options window's music volume scales this group (SettingsController).
	music.SoundGroup = SoundService:FindFirstChild("VaelthornMusicGroup") :: SoundGroup?
	music.Parent = SoundService
	buildLoading()

	scope:Observer(State.Value({ "character", "location", "map" })):onChange(function()
		local mapId = State.Get({ "character", "location", "map" })
		if type(mapId) == "string" then
			applyEnvironment(mapId)
		end
	end)
	local initial = State.Get({ "character", "location", "map" })
	if type(initial) == "string" then
		applyEnvironment(initial)
	end

	-- Safe placement: tell the server once the ground under the spawn / teleport target has streamed in (a ray
	-- from just above the target hits terrain, water or map geometry), so it can release the anchored character.
	Net.On("GroundCheck", function(token: number, target: Vector3)
		task.spawn(function()
			local deadline = os.clock() + 15
			while os.clock() < deadline do
				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and (root.Position - target).Magnitude < 12 then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { character :: Model }
					local hit = Workspace:Raycast(target + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
					if hit then
						Net.Send("GroundReady", token)
						return
					end
				end
				task.wait(0.1)
			end
		end)
	end)

	Net.On("MapTransition", function(mapId: string?)
		showLoading(mapId)
	end)
	-- Enter confirms the area picker (S22).
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if
			not processed
			and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter)
			and Fusion.peek(WindowManager.IsOpen("areapicker"))
		then
			pickerConfirm()
		end
	end)

	-- Day and night (S21): once a second on maps with the cycle; S26: up to 10 times a second while the area mood
	-- changes.
	local accumulator = 0
	local sinceMod = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		sinceMod += dt
		local cycle = accumulator >= 1
		local mood = modulationDirty and sinceMod >= 0.1
		if not cycle and not mood then
			return
		end
		local map = Maps.get(appliedMap)
		if not map or os.clock() < tweenUntil then
			return
		end
		if cycle then
			accumulator = 0
		end
		if not mood and not map.dayNight then
			return
		end
		if mood then
			sinceMod = 0
			modulationDirty = false
		end
		local lightingProps, atmosphereProps, gradeProps = environment(map)
		modulate(lightingProps, atmosphereProps, gradeProps)
		for key, value in lightingProps do
			(Lighting :: any)[key] = value
		end
		for key, value in atmosphereProps do
			(atmosphere :: any)[key] = value
		end
		for key, value in gradeProps do
			(grade :: any)[key] = value
		end
	end)

	for _, instance in CollectionService:GetTagged("Portal") do
		task.spawn(decoratePortal, instance)
	end
	CollectionService:GetInstanceAddedSignal("Portal"):Connect(function(instance)
		task.defer(decoratePortal, instance)
	end)
end

return WorldController
