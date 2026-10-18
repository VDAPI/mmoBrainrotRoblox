--!strict
-- Banner shown when the player enters another map or PvP zone (DESIGN §3.3): area name + zone line in
-- the zone colour ("Safe zone" / "PvP by consent" / "PvP zone"). S22: on region maps the map name (the area
-- banner names the place). S149b: entering the fighters' circle of a living world boss shows the barrow's name and
-- "no PvP while the boss lives" (Logic/WorldBoss.zoneNote: the zone itself stays yellow).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AreaState = require(script.Parent.Parent.Parent.AreaState)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBoss = require(ReplicatedStorage.Shared.Logic.WorldBoss)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local HOLD_SECONDS = 3.5

-- S136: the zone colours as text on iron (Data/UiPalette.zoneText)
local ZONE_COLORS: { [string]: Color3 } = {
	green = Theme.ZoneText.Green,
	yellow = Theme.ZoneText.Yellow,
	red = Theme.ZoneText.Red,
}

local function ZoneBanner(scope: Scope): Instance
	local zoneValue = State.Value({ "zone" })
	local shown = scope:Value(nil :: Types.ZoneState?)
	local transparency = scope:Value(1)
	local animated = scope:Tween(transparency, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	local lastKey = ""
	local token = 0
	-- S149b: the world boss circle's note (a key) while its banner shows, else nil (the zone banner)
	local note = scope:Value(nil :: string?)
	local lastNote: string? = nil

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
		token += 1
		local current = token
		note:set(nil)
		shown:set(zone)
		transparency:set(0)
		task.delay(HOLD_SECONDS, function()
			if current == token then
				transparency:set(1)
			end
		end)
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
			token += 1
			local current = token
			shown:set(zone)
			note:set(key)
			transparency:set(0)
			task.delay(HOLD_SECONDS, function()
				if current == token then
					transparency:set(1)
				end
			end)
		end)
	)

	local color = scope:Computed(function(use): Color3
		if use(note) then
			return Theme.ZoneText.Green
		end
		local zone = use(shown)
		return if zone then ZONE_COLORS[zone.pvp] or Theme.Brass.Bright else Theme.Brass.Bright
	end)

	return scope:New("Frame")({
		Name = "ZoneBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(640, 110),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return use(animated) < 0.99
		end),
		[Children] = {
			scope:New("TextLabel")({
				Name = "AreaName",
				Size = UDim2.new(1, 0, 0, 64),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local zone = use(shown)
					if not zone then
						return ""
					end
					if use(note) then
						return Text.get(use, WorldBoss.spot().nameKey)
					end
					local map = Maps.get(zone.map)
					return Text.get(use, AreaState.zoneNameKey(zone, if map then map.nameKey else nil))
				end),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Hero,
				TextColor3 = Theme.Iron.Text,
				TextStrokeColor3 = Theme.Shade,
				TextStrokeTransparency = scope:Computed(function(use): number
					return 0.3 + use(animated) * 0.7
				end),
				TextTransparency = animated,
			}),
			scope:New("Frame")({
				Name = "Rule",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 68),
				Size = UDim2.fromOffset(320, 2),
				BackgroundColor3 = color,
				BackgroundTransparency = animated,
				BorderSizePixel = 0,
			}),
			scope:New("TextLabel")({
				Name = "ZoneType",
				Position = UDim2.fromOffset(0, 74),
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local zone = use(shown)
					local key = use(note)
					if key then
						return Text.get(use, key)
					end
					return if zone then Text.get(use, `zone.{zone.pvp}`) else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Large,
				TextColor3 = color,
				TextStrokeColor3 = Theme.Shade,
				TextStrokeTransparency = scope:Computed(function(use): number
					return 0.4 + use(animated) * 0.6
				end),
				TextTransparency = animated,
			}),
		},
	})
end

return ZoneBanner
