--!strict
-- Small banner at the top when entering a monster area (S20, DESIGN §3.6): "Bandits' Road · 9–14" in the
-- level difference colour, 2.5 s.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaState = require(script.Parent.Parent.Parent.AreaState)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local HOLD_SECONDS = 2.5

local function AreaBanner(scope: Scope): Instance
	local transparency = scope:Value(1)
	local animated = scope:Tween(transparency, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	local level = State.Value({ "character", "level" })
	scope:Observer(AreaState.Banner):onChange(function()
		local banner = Fusion.peek(AreaState.Banner)
		if not banner then
			return
		end
		local mine = banner.token
		transparency:set(0)
		task.delay(HOLD_SECONDS, function()
			local now = Fusion.peek(AreaState.Banner)
			if now and now.token == mine then
				transparency:set(1)
			end
		end)
	end)
	local color = scope:Computed(function(use): Color3
		local banner = use(AreaState.Banner)
		if not banner then
			return Theme.Colors.Parchment
		end
		local lv = banner.area.lv
		local band = LevelBand.of(math.floor((lv[1] + lv[2]) / 2), use(level) or 1)
		return Color3.fromHex((LevelBand.COLORS :: any)[band])
	end)
	return scope:New("TextLabel")({
		Name = "AreaBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(520, 34),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return use(animated) < 0.99
		end),
		Text = scope:Computed(function(use): string
			local banner = use(AreaState.Banner)
			if not banner then
				return ""
			end
			return Text.get(use, "area.label", {
				name = Text.get(use, banner.area.nameKey),
				min = banner.area.lv[1],
				max = banner.area.lv[2],
			})
		end),
		FontFace = Theme.Fonts.Heading,
		TextSize = 28,
		TextColor3 = color,
		TextStrokeColor3 = Theme.Colors.Background,
		TextStrokeTransparency = scope:Computed(function(use): number
			return 0.3 + use(animated) * 0.7
		end),
		TextTransparency = animated,
		[Children] = {},
	})
end

return AreaBanner
