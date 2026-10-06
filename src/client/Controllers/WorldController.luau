--!strict
-- The world on the client (S08):
--   * environment: on entering a map, Lighting / Atmosphere / colour grading (and music, once maps have
--     tracks) tween to the map's settings from Data/Maps; on maps with `dayNight` (S21: the city) the clock
--     runs from the shared server time (Logic/DayCycle, offset from the Workspace attribute "DayOffset" set by
--     /daytime) and the lighting blends between the day and night presets once a second,
--   * loading screen on MapTransition (map name, levels, zone, a random tip), faded in and out,
--   * portals (tag "Portal"): nameplate with the target map and levels, "Travel [E]" prompt; entering a red
--     zone or a map above your level asks for confirmation first.
-- Also registers the world map window (M).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

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
local WorldMapWindow = require(script.Parent.Parent.UI.Screens.WorldMapWindow)

local WorldController = {
	Name = "WorldController",
	Deps = { "WindowManager", "SettingsController" },
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
	prompt.Triggered:Connect(function()
		onPortal(portalId :: string, target.id)
	end)
end

function WorldController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	WindowManager.Register({
		id = "map",
		titleKey = "window.map.title",
		size = Vector2.new(1180, 740), -- S20: up to ~85% of the screen (full screen on phones)
		hotkey = Enum.KeyCode.M,
		build = WorldMapWindow,
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

local function onAdminClient(action: any)
	if action == "mapcache" then
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

	Net.On("MapTransition", function(mapId: string?)
		showLoading(mapId)
	end)

	-- Day and night (S21): once a second on maps with the cycle.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		accumulator = 0
		local map = Maps.get(appliedMap)
		if not map or not map.dayNight or os.clock() < tweenUntil then
			return
		end
		local lightingProps, atmosphereProps, gradeProps = environment(map)
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
