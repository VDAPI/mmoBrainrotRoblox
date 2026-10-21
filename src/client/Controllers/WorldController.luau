--!strict
-- The world on the client (S08):
--   * environment: on entering a map, Lighting / Atmosphere / colour grading (and music, once maps have
--     tracks) tween to the map's settings from Data/Maps; on maps with `dayNight` (S21: the city) the clock
--     runs from the shared server time (Logic/DayCycle, offset from the Workspace attribute "DayOffset" set by
--     /daytime) and the lighting blends between the day and night presets once a second,
--   * look (W01, Data/MapLooks): a fixed hour per map (no day and night outside the city), the sun's colour, bloom,
--     sun rays, depth of field, contrast, clouds and the sky, scaled by the graphics level (Config.Graphics),
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
local MapLooks = require(ReplicatedStorage.Shared.Data.MapLooks)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Portals = require(ReplicatedStorage.Shared.Data.Portals)
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
local bloom: BloomEffect
local sunRays: SunRaysEffect
local farBlur: DepthOfFieldEffect
local music: Sound
local appliedMap = ""

-- Environment ------------------------------------------------------------------------------------

-- Time of day on maps with day and night (S21): clock 0..24 and how dark it is (0 day .. 1 night).
function WorldController.TimeOfDay(): (number, number)
	-- W01: a map with a fixed hour (Data/MapLooks) shows it all the time
	local fixed = MapLooks.of(appliedMap).clock
	if fixed then
		return fixed, DayCycle.nightness(fixed)
	end
	local offset = workspace:GetAttribute("DayOffset")
	local now = workspace:GetServerTimeNow() + (if type(offset) == "number" then offset else 0)
	local clock = DayCycle.clock(now, Config.DayLength, Config.DayNightShare)
	return clock, DayCycle.nightness(clock)
end

-- Whether the map the player is on runs the day and night cycle.
function WorldController.HasDayNight(): boolean
	local map = Maps.get(appliedMap)
	return map ~= nil and map.dayNight == true and map.nightLighting ~= nil and MapLooks.of(map.id).clock == nil
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
	local look = MapLooks.of(map.id)
	-- W01: a fixed hour replaces the cycle (the day preset, lit at that hour)
	local night = if map.dayNight and look.clock == nil then map.nightLighting else nil
	local clock, t = look.clock or day.clockTime, 0
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
		-- W12: on the cycle the sun's colour follows the hour (MapLooks.sunAt), else the map's fixed colour
		ColorShift_Top = Color3.fromHex(if night then MapLooks.sunAt(clock) else look.sunColor)
			:Lerp(Color3.new(1, 1, 1), t),
	}, {
		Density = lerp(day.atmosphere.density, n.atmosphere.density, t),
		Haze = lerp(day.atmosphere.haze, n.atmosphere.haze, t),
		Glare = lerp(day.atmosphere.glare, n.atmosphere.glare, t),
		Color = mix(day.atmosphere.color, n.atmosphere.color, t),
		Decay = mix(day.atmosphere.decay, n.atmosphere.decay, t),
	}, {
		TintColor = mix(day.tint, n.tint, t),
		Saturation = lerp(day.saturation, n.saturation, t),
		Contrast = look.contrast,
		Brightness = look.brightness,
	}
end

-- W01: the graphics level of the options (settings.quality; Config.Graphics).
local function graphicsLevel(): typeof(Config.Graphics.levels.high)
	local quality = State.Get({ "account", "settings", "quality" })
	local levels = Config.Graphics.levels :: { [string]: typeof(Config.Graphics.levels.high) }
	return levels[if type(quality) == "string" then quality else Config.Graphics.default] or levels.high
end

-- W01: the map's sky from ReplicatedStorage.Assets.Sky (the default sky when the key or the asset is missing). The
-- place's own Sky is the default; it leaves Lighting while a map sky shows (two skies in Lighting pick one at random).
-- 2026-10-20: a painted sky of the look (MapLooks.paintedSky: all six image ids uploaded) wins over the asset key; on
-- the city's cycle the night one swaps in by the hour.
local defaultSky: Sky? = nil

local function paintedSkyInstance(sky: MapLooks.PaintedSky): Sky
	local out = Instance.new("Sky")
	out.SkyboxBk = `rbxassetid://{sky.ids.bk}`
	out.SkyboxDn = `rbxassetid://{sky.ids.dn}`
	out.SkyboxFt = `rbxassetid://{sky.ids.ft}`
	out.SkyboxLf = `rbxassetid://{sky.ids.lf}`
	out.SkyboxRt = `rbxassetid://{sky.ids.rt}`
	out.SkyboxUp = `rbxassetid://{sky.ids.up}`
	-- the stars are painted into the night sky; the engine's sun and moon stay (the glow is painted behind them)
	out.StarCount = 0
	if sky.turn ~= 0 then
		pcall(function()
			(out :: any).SkyboxOrientation = Vector3.new(0, sky.turn, 0)
		end)
	end
	return out
end

local function applySky(look: MapLooks.Look, clock: number?)
	local paintedKey, painted = MapLooks.paintedSky(look, clock)
	local key = if painted then `painted:{paintedKey}` else look.sky
	local current = Lighting:FindFirstChild("VaelthornSky")
	if current and current:GetAttribute("Key") == key then
		return
	end
	if current then
		current:Destroy()
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Sky")
	local source = if key and folder and not painted then folder:FindFirstChild(key) else nil
	local sky: Sky? = nil
	if painted then
		sky = paintedSkyInstance(painted)
	elseif source and source:IsA("Sky") then
		sky = source:Clone()
	end
	if sky then
		if defaultSky then
			defaultSky.Parent = nil
		end
		sky.Name = "VaelthornSky"
		sky:SetAttribute("Key", key)
		sky.Parent = Lighting
	elseif defaultSky then
		defaultSky.Parent = Lighting
	end
end

-- W02: the map's painted terrain materials (Data/MapLooks `materials`): a base material shows its MaterialVariant
-- while the map sets one and the variant exists in MaterialService (the place); every other overridden base goes back
-- to the plain material.
local function applyMaterials(look: MapLooks.Look)
	local service = game:GetService("MaterialService")
	local wanted: { [string]: string } = look.materials or {}
	for _, base in MapLooks.overriddenMaterials() do
		local name = wanted[base]
		local variant = if name then service:FindFirstChild(name, true) else nil
		pcall(function()
			service:SetBaseMaterialOverride((Enum.Material :: any)[base], if variant then name :: string else "")
		end)
	end
end

-- The map's terrain colours (Data/MapLooks `terrainColors` over TERRAIN_COLORS), e.g. the city's grass-green lawns.
local function applyTerrainColors(mapId: string)
	for name, color in MapLooks.terrainColorsOf(mapId) do
		pcall(function()
			Workspace.Terrain:SetMaterialColor((Enum.Material :: any)[name], Color3.fromHex(color))
		end)
	end
end

-- W01: bloom, sun rays, far blur and clouds of a map at the current graphics level, tweened over `seconds`.
local function applyPost(map: Maps.MapDef, seconds: number, clock: number?)
	local look = MapLooks.of(map.id)
	local level = graphicsLevel()
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine)
	TweenService:Create(bloom, info, {
		Intensity = look.bloom.intensity * level.bloom,
		Size = look.bloom.size,
		Threshold = look.bloom.threshold,
	}):Play()
	TweenService:Create(sunRays, info, { Intensity = if level.sunRays then look.sunRays else 0 }):Play()
	-- W29: low quality draws no sun shadows (the lamps never cast any)
	Lighting.GlobalShadows = level.shadows
	local blur = level.farBlur and look.farBlur > 0 and UserInputService.KeyboardEnabled
	farBlur.Enabled = blur
	if blur then
		TweenService:Create(farBlur, info, { FarIntensity = look.farBlur }):Play()
	end
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	local want = if level.clouds then look.clouds else nil
	if want then
		if not clouds then
			local created = Instance.new("Clouds")
			created.Cover = 0
			created.Parent = Workspace.Terrain
			clouds = created
		end
		local c = clouds :: Clouds
		c.Enabled = true
		TweenService:Create(c, info, { Cover = want.cover, Density = want.density, Color = Color3.fromHex(want.color) })
			:Play()
	elseif clouds then
		clouds.Enabled = false
	end
	local hour = clock
	if hour == nil and map.dayNight and look.clock == nil then
		hour = WorldController.TimeOfDay()
	end
	applySky(look, hour)
	applyMaterials(look)
	applyTerrainColors(map.id)
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

-- S129: Blood Moon sky: a second layer after the area mood (BloodMoonController), faded in and out over `fade` s by
-- `eventMix` (the Heartbeat loop steps it and re-applies the light, also on maps without a day cycle).
export type EventTint = {
	fogColor: Color3,
	fogMix: number,
	tint: Color3,
	tintMix: number,
	brightness: number, -- multiplier
	saturation: number, -- added
	haze: number, -- added
	fade: number, -- seconds
}
local eventTint: EventTint? = nil
local eventTarget = 0
local eventMix = 0

function WorldController.SetEventTint(tint: EventTint?)
	if tint then
		eventTint = tint
	end
	eventTarget = if tint then 1 else 0
	modulationDirty = true
end

local function modulate(lighting: { [string]: any }, air: { [string]: any }, grading: { [string]: any })
	local m = modulation
	if m then
		lighting.FogEnd *= m.fogScale
		lighting.FogColor = (lighting.FogColor :: Color3):Lerp(m.fogColor, m.fogMix)
		lighting.Brightness *= m.brightness
		air.Haze = math.clamp(air.Haze + m.haze, 0, 10)
		air.Density = math.clamp(air.Density + m.density, 0, 1)
		grading.TintColor = (grading.TintColor :: Color3):Lerp(m.tint, m.tintMix)
		grading.Saturation = math.clamp(grading.Saturation + m.saturation, -1, 1)
	end
	local e = eventTint
	local k = eventMix
	if e and k > 0 then
		lighting.FogColor = (lighting.FogColor :: Color3):Lerp(e.fogColor, e.fogMix * k)
		lighting.Brightness *= 1 + (e.brightness - 1) * k
		air.Haze = math.clamp(air.Haze + e.haze * k, 0, 10)
		air.Color = (air.Color :: Color3):Lerp(e.fogColor, e.fogMix * k)
		grading.TintColor = (grading.TintColor :: Color3):Lerp(e.tint, e.tintMix * k)
		grading.Saturation = math.clamp(grading.Saturation + e.saturation * k, -1, 1)
	end
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
	applyPost(map, Config.Graphics.fade)
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

-- S102: for CutsceneController: the lighting of another map (and an hour of its day) while a cutscene shows it;
-- nil goes back to the map the player is on. The day / night loop leaves the lighting alone while it shows.
local previewing = false

function WorldController.PreviewEnvironment(mapId: string?, clock: number?)
	if mapId == nil and not previewing then
		return
	end
	local map = Maps.get(mapId or appliedMap)
	if not map then
		return
	end
	previewing = mapId ~= nil
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Sine)
	local lightingProps, atmosphereProps, gradeProps = environment(map)
	if map.id == appliedMap then
		modulate(lightingProps, atmosphereProps, gradeProps)
	end
	if previewing and clock then
		lightingProps.ClockTime = clock
	end
	TweenService:Create(Lighting, info, lightingProps):Play()
	TweenService:Create(atmosphere, info, atmosphereProps):Play()
	TweenService:Create(grade, info, gradeProps):Play()
	applyPost(map, 0.8, if previewing then clock else nil)
	tweenUntil = if previewing then math.huge else os.clock() + 0.9
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
	loadingFrame.BackgroundColor3 = Theme.Iron.Sunken
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
	loadingTitle = label(-40, Theme.TextSize.Hero - 10, Theme.Fonts.Display, Theme.Brass.Bright)
	loadingSub = label(14, Theme.TextSize.Large, Theme.Fonts.BodyBold, Theme.Iron.Text)
	loadingTip = label(120, Theme.TextSize.Body, Theme.Fonts.Body, Theme.Iron.TextMuted)
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
		then Theme.ZoneText.Red
		elseif map.zone == "yellow" then Theme.ZoneText.Yellow
		else Theme.ZoneText.Green
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

-- S102: for CutsceneController: whether the loading screen is up.
function WorldController.IsLoading(): boolean
	local gui: ScreenGui? = loadingGui
	return gui ~= nil and gui.Enabled
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

local decoratePortal: (instance: Instance) -> ()

-- Owner report 2026-10-18 (published game, no "Travel [E]"): the "Portal" tag can replicate before the arch's parts
-- or attributes, so a portal without them yet is retried once its first part or attribute arrives.
local function retryPortal(model: Model)
	if model:GetAttribute("VaelthornPortalWait") then
		return
	end
	model:SetAttribute("VaelthornPortalWait", true)
	local connections: { RBXScriptConnection } = {}
	local function again()
		for _, connection in connections do
			connection:Disconnect()
		end
		model:SetAttribute("VaelthornPortalWait", nil)
		task.defer(decoratePortal, model)
	end
	table.insert(
		connections,
		model.DescendantAdded:Connect(function(child: Instance)
			if child:IsA("BasePart") then
				again()
			end
		end)
	)
	table.insert(
		connections,
		model.AttributeChanged:Connect(function(name: string)
			if name == "PortalId" or name == "TargetMap" then
				again()
			end
		end)
	)
end

decoratePortal = function(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	local portalId = model:GetAttribute("PortalId")
	local targetId = model:GetAttribute("TargetMap")
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if type(portalId) ~= "string" or type(targetId) ~= "string" or not anchor then
		if model.Parent then
			retryPortal(model)
		end
		return
	end
	if anchor:FindFirstChild("VaelthornPortal") then
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
	title.FontFace = Theme.Fonts.Display
	title.TextSize = Theme.TextSize.Large + 2
	title.TextColor3 = Theme.Brass.Bright
	title.TextStrokeTransparency = 0.3
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromOffset(0, 32)
	sub.Size = UDim2.new(1, 0, 0, 24)
	sub.BackgroundTransparency = 1
	sub.FontFace = Theme.Fonts.BodyBold
	sub.TextSize = Theme.TextSize.Small
	sub.TextStrokeTransparency = 0.3
	sub.TextColor3 = if target.zone == "red"
		then Theme.ZoneText.Red
		elseif target.zone == "yellow" then Theme.ZoneText.Yellow
		else Theme.ZoneText.Green
	sub.Parent = gui
	local prompt = Instance.new("ProximityPrompt")
	Keybinds.bindPrompt(prompt, "interact")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Portals.PROMPT_RANGE -- W28: the server checks from the same field
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
	-- Portal prompts first (owner report 2026-10-17: no "Travel [E]"): an error later in Start (lighting, post
	-- effects, sky, materials) must never leave the portals without their prompt.
	for _, instance in CollectionService:GetTagged("Portal") do
		task.spawn(decoratePortal, instance)
	end
	CollectionService:GetInstanceAddedSignal("Portal"):Connect(function(instance)
		task.defer(decoratePortal, instance)
	end)
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "VaelthornGrade"
	grade.Parent = Lighting
	-- W01: post effects of the map look (Data/MapLooks), off until a map is applied. The place's own bloom, sun rays
	-- and depth of field (left in Lighting from before W01) go off: one owner for every post effect.
	for _, child in Lighting:GetChildren() do
		if child:IsA("BloomEffect") or child:IsA("SunRaysEffect") or child:IsA("DepthOfFieldEffect") then
			child.Enabled = false
		end
	end
	defaultSky = Lighting:FindFirstChildOfClass("Sky")
	bloom = Instance.new("BloomEffect")
	bloom.Name = "VaelthornBloom"
	bloom.Intensity = 0
	bloom.Parent = Lighting
	sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "VaelthornSunRays"
	sunRays.Intensity = 0
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting
	farBlur = Instance.new("DepthOfFieldEffect")
	farBlur.Name = "VaelthornFarBlur"
	farBlur.Enabled = false
	farBlur.FocusDistance = 60
	farBlur.InFocusRadius = 120
	farBlur.NearIntensity = 0
	farBlur.FarIntensity = 0
	farBlur.Parent = Lighting
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
		local ok: boolean, err: any = pcall(applyEnvironment, initial)
		if not ok then
			warn("[WorldController] applyEnvironment failed:", err)
		end
	end
	-- W01: a new graphics level re-applies the post effects of the current map
	scope:Observer(State.Value({ "account", "settings", "quality" })):onChange(function()
		local map = Maps.get(appliedMap)
		if map then
			applyPost(map, 0.5)
		end
	end)

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
		-- S129: the Blood Moon sky fades in / out
		if eventMix ~= eventTarget then
			local fade = if eventTint then math.max(0.1, eventTint.fade) else 1
			eventMix = if eventTarget > eventMix
				then math.min(eventTarget, eventMix + dt / fade)
				else math.max(eventTarget, eventMix - dt / fade)
			modulationDirty = true
		end
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
		if not mood and (not map.dayNight or MapLooks.of(map.id).clock ~= nil) then
			return
		end
		if mood then
			sinceMod = 0
			modulationDirty = false
		end
		local lightingProps, atmosphereProps, gradeProps = environment(map)
		modulate(lightingProps, atmosphereProps, gradeProps)
		if cycle and map.dayNight then
			-- the painted night sky swaps in by the hour (no-op while the key stays)
			applySky(MapLooks.of(map.id), lightingProps.ClockTime)
		end
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
end

return WorldController
