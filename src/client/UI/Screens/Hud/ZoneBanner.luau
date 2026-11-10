--!strict
-- Banner shown when the player enters another map or PvP zone (DESIGN §3.3): area name + zone line in
-- the zone colour ("Safe zone" / "PvP by consent" / "PvP zone"). S22: on region maps the map name (the area
-- banner names the place). S149b: entering the fighters' circle of a living world boss shows the barrow's name and
-- "no PvP while the boss lives" (Logic/WorldBoss.zoneNote: the zone itself stays yellow).
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): the banner is one
-- of UI/Notify's banners (the banner's place in the band under the target, a phone's M zone), 3.5 s; a newer zone's
-- banner takes the older one's place at once. The HUD still mounts this (an empty folder): it watches the zone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AreaState = require(script.Parent.Parent.Parent.AreaState)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Notify = require(script.Parent.Parent.Parent.Notify)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBoss = require(ReplicatedStorage.Shared.Logic.WorldBoss)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local HOLD_SECONDS = 3.5
local SIZE = Vector2.new(560, 64) -- on PC; a phone: the M zone's width, HudLine high

-- S136: the zone colours as text on iron (Data/UiPalette.zoneText)
local ZONE_COLORS: { [string]: Color3 } = {
	green = Theme.ZoneText.Green,
	yellow = Theme.ZoneText.Yellow,
	red = Theme.ZoneText.Red,
}

-- The banner's look: the place's name over the zone's line, in the zone's colour.
local function look(name: string, line: string, color: Color3): (Scope, Notify.Live) -> Instance
	return function(s: Scope, live: Notify.Live): Instance
		return s:New("Frame")({
			Name = "ZoneBanner",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Iron.Sunken,
			BackgroundTransparency = Theme.HudAlpha,
			[Children] = {
				s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				s:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = color,
					Thickness = Theme.Stroke.Normal,
				}),
				s:New("TextLabel")({
					Name = "AreaName",
					Size = UDim2.fromScale(1, 0.6),
					BackgroundTransparency = 1,
					Text = name,
					FontFace = Theme.Fonts.Display,
					TextSize = if live.phone then Theme.TextSize.Body else Theme.TextSize.Large + 2,
					TextColor3 = Theme.Iron.Text,
					TextStrokeColor3 = Theme.Shade,
					TextStrokeTransparency = 0.3,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				s:New("TextLabel")({
					Name = "ZoneType",
					Position = UDim2.fromScale(0, 0.58),
					Size = UDim2.fromScale(1, 0.38),
					BackgroundTransparency = 1,
					Text = line,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = if live.phone then Theme.TextSize.Caption else Theme.TextSize.Small,
					TextColor3 = color,
					TextStrokeColor3 = Theme.Shade,
					TextStrokeTransparency = 0.4,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
			},
		})
	end
end

local function ZoneBanner(scope: Scope): Instance
	local zoneValue = State.Value({ "zone" })
	local lastKey = ""
	local lastNote: string? = nil
	local handle: Notify.Handle? = nil
	table.insert(scope, function()
		if handle then
			handle.close()
		end
	end)

	-- `note`: S149b, the world boss circle's note (a key), else the zone's banner
	local function show(zone: Types.ZoneState, note: string?)
		local map = Maps.get(zone.map)
		local name = if note
			then Text.now(WorldBoss.spot().nameKey)
			else Text.now(AreaState.zoneNameKey(zone, if map then map.nameKey else nil))
		local line = if note then Text.now(note) else Text.now(`zone.{zone.pvp}`)
		local color = if note then Theme.ZoneText.Green else ZONE_COLORS[zone.pvp] or Theme.Brass.Bright
		if handle then
			handle.close()
		end
		handle = Notify.push({
			class = "banner",
			tone = "zone",
			text = `{name}|{line}`,
			seconds = HOLD_SECONDS,
			w = SIZE.X,
			height = function(phone: boolean): number
				return if phone then Theme.Size.HudLine else SIZE.Y
			end,
			build = look(name, line, color),
		})
	end

	scope:Observer(zoneValue):onBind(function()
		local zone = Fusion.peek(zoneValue) :: Types.ZoneState?
		if not zone then
			lastKey = ""
			return
		end
		local map = Maps.get(zone.map)
		local key = `{zone.map}|{zone.pvp}|{AreaState.zoneNameKey(zone, if map then map.nameKey else nil)}`
		if key == lastKey then
			return
		end
		lastKey = key
		show(zone, nil)
	end)

	local noteClock = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			noteClock += dt
			if noteClock < 0.5 then
				return
			end
			noteClock = 0
			local zone = Fusion.peek(zoneValue) :: Types.ZoneState?
			local map = if zone then Maps.get(zone.map) else nil
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local key: string? = nil
			if zone and map and root then
				key = WorldBoss.zoneNote(
					State.Get({ "worldBoss" }),
					zone.map,
					root.Position.X - map.offset.x,
					root.Position.Z - map.offset.z
				)
			end
			if key == lastNote then
				return
			end
			lastNote = key
			if not key or not zone then
				return
			end
			show(zone, key)
		end)
	)

	return scope:New("Folder")({ Name = "ZoneBanner" })
end

return ZoneBanner
