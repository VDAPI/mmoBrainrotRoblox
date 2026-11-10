--!strict
-- Small banner at the top when entering a monster area (S20, DESIGN §3.6): "Bandits' Road · 9–14" in the
-- level difference colour, 2.5 s. S33: the hunting ground profile's icon after it and its name below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaProfileText = require(script.Parent.Parent.Parent.AreaProfileText)
local AreaProfiles = require(ReplicatedStorage.Shared.Data.AreaProfiles)
local AreaState = require(script.Parent.Parent.Parent.AreaState)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local TopBandState = require(script.Parent.Parent.Parent.TopBandState)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local HOLD_SECONDS = 2.5

local function AreaBanner(scope: Scope): Instance
	local transparency = scope:Value(1)
	local animated = scope:Tween(transparency, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	-- UI plan phase 2: the toasts start under this banner while it shows (UI/TopBandState, Logic/TopBand); Studio check
	-- of phase 4: until its fade ends (a toast under it jumped up while it still faded)
	local function flag()
		TopBandState.set("area", Fusion.peek(transparency) < 1 or Fusion.peek(animated) < 1)
	end
	scope:Observer(transparency):onBind(flag)
	scope:Observer(animated):onChange(flag)
	table.insert(scope, function()
		TopBandState.set("area", false)
	end)
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
			return Theme.Iron.Text
		end
		local lv = banner.area.lv
		local band = LevelBand.of(math.floor((lv[1] + lv[2]) / 2), use(level) or 1)
		return Theme.readable((LevelBand.COLORS :: any)[band], "iron")
	end)
	return scope:New("TextLabel")({
		Name = "AreaBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(520, 34),
		BackgroundTransparency = 1,
		RichText = true,
		Visible = scope:Computed(function(use): boolean
			return use(animated) < 0.99
		end),
		Text = scope:Computed(function(use): string
			local banner = use(AreaState.Banner)
			if not banner then
				return ""
			end
			return AreaProfileText.escape(Text.get(use, "area.label", {
				name = Text.get(use, banner.area.nameKey),
				range = `{banner.area.lv[1]}–{banner.area.lv[2]}`, -- package A: the band as one "{range}"
			})) .. AreaProfileText.iconRich(banner.area.profile, " ", "iron")
		end),
		FontFace = Theme.Fonts.Display,
		TextSize = Theme.TextSize.Title,
		TextColor3 = color,
		TextStrokeColor3 = Theme.Shade,
		TextStrokeTransparency = scope:Computed(function(use): number
			return 0.3 + use(animated) * 0.7
		end),
		TextTransparency = animated,
		[Children] = {
			scope:New("TextLabel")({
				Name = "Profile",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local banner = use(AreaState.Banner)
					local profile = banner and AreaProfiles.get(banner.area.profile)
					return if profile then AreaProfileText.tag(use, profile) else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					local banner = use(AreaState.Banner)
					local profile = banner and AreaProfiles.get(banner.area.profile)
					return if profile then AreaProfileText.color(profile, "iron") else Theme.Iron.Text
				end),
				TextStrokeColor3 = Theme.Shade,
				TextStrokeTransparency = scope:Computed(function(use): number
					return 0.3 + use(animated) * 0.7
				end),
				TextTransparency = animated,
			}),
		},
	})
end

return AreaBanner
