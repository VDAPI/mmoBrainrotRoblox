--!strict
-- Banner shown when the player enters another map or PvP zone (DESIGN §3.3): area name + zone line in
-- the zone colour ("Safe zone" / "PvP by consent" / "PvP zone").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local HOLD_SECONDS = 3.5

local ZONE_COLORS: { [string]: Color3 } = {
	green = Theme.Colors.ZoneGreen,
	yellow = Theme.Colors.ZoneYellow,
	red = Theme.Colors.ZoneRed,
}

local function ZoneBanner(scope: Scope): Instance
	local zoneValue = State.Value({ "zone" })
	local shown = scope:Value(nil :: Types.ZoneState?)
	local transparency = scope:Value(1)
	local animated = scope:Tween(transparency, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	local lastKey = ""
	local token = 0

	scope:Observer(zoneValue):onBind(function()
		local zone = Fusion.peek(zoneValue) :: Types.ZoneState?
		if not zone then
			lastKey = ""
			return
		end
		local key = `{zone.map}|{zone.pvp}|{zone.nameKey}`
		if key == lastKey then
			return
		end
		lastKey = key
		token += 1
		local current = token
		shown:set(zone)
		transparency:set(0)
		task.delay(HOLD_SECONDS, function()
			if current == token then
				transparency:set(1)
			end
		end)
	end)

	local color = scope:Computed(function(use): Color3
		local zone = use(shown)
		return if zone then ZONE_COLORS[zone.pvp] or Theme.Colors.Gold else Theme.Colors.Gold
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
					return if zone then Text.get(use, zone.nameKey) else ""
				end),
				FontFace = Theme.Fonts.Heading,
				TextSize = 56,
				TextColor3 = Theme.Colors.Parchment,
				TextStrokeColor3 = Theme.Colors.Background,
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
					return if zone then Text.get(use, `zone.{zone.pvp}`) else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Large,
				TextColor3 = color,
				TextStrokeColor3 = Theme.Colors.Background,
				TextStrokeTransparency = scope:Computed(function(use): number
					return 0.4 + use(animated) * 0.6
				end),
				TextTransparency = animated,
			}),
		},
	})
end

return ZoneBanner
