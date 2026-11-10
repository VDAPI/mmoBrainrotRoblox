--!strict
-- Small banner at the top when entering a monster area (S20, DESIGN §3.6): "Bandits' Road · 9–14" in the
-- level difference colour, 2.5 s. S33: the hunting ground profile's icon after it and its name below.
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"; owner question 4,
-- default): it says the same as the minimap's caption, so it stays short: the name and the levels only (the profile
-- stays on the minimap and the map card), 3 s, as one of UI/Notify's banners in the band under the target (a phone's
-- M zone); a newer area's banner takes the older one's place at once. The HUD still mounts this (an empty folder).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaState = require(script.Parent.Parent.Parent.AreaState)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local Notify = require(script.Parent.Parent.Parent.Notify)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local HOLD_SECONDS = 3
local SIZE = Vector2.new(520, 44) -- on PC; a phone: the M zone's width, 40 high

-- The banner's look: one line in the level difference colour.
local function look(line: string, color: Color3): (Scope, Notify.Live) -> Instance
	return function(s: Scope, live: Notify.Live): Instance
		return s:New("Frame")({
			Name = "AreaBanner",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Iron.Sunken,
			BackgroundTransparency = Theme.HudAlpha,
			[Children] = {
				s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				s:New("TextLabel")({
					Name = "Label",
					Position = UDim2.fromOffset(Theme.Padding.Small, 0),
					Size = UDim2.new(1, -2 * Theme.Padding.Small, 1, 0),
					BackgroundTransparency = 1,
					Text = line,
					FontFace = Theme.Fonts.Display,
					TextSize = if live.phone then Theme.TextSize.Body else Theme.TextSize.Large,
					TextColor3 = color,
					TextStrokeColor3 = Theme.Shade,
					TextStrokeTransparency = 0.3,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
			},
		})
	end
end

local function AreaBanner(scope: Scope): Instance
	local handle: Notify.Handle? = nil
	table.insert(scope, function()
		if handle then
			handle.close()
		end
	end)
	scope:Observer(AreaState.Banner):onChange(function()
		local banner = Fusion.peek(AreaState.Banner)
		if not banner then
			return
		end
		local area = banner.area
		-- package A: area.label takes the level band as one {range} (the minimap's one-line caption)
		local line = Text.now("area.label", { name = Text.now(area.nameKey), range = `{area.lv[1]}–{area.lv[2]}` })
		local band = LevelBand.of(math.floor((area.lv[1] + area.lv[2]) / 2), State.Get({ "character", "level" }) or 1)
		local color = Theme.readable((LevelBand.COLORS :: any)[band], "iron")
		if handle then
			handle.close()
		end
		handle = Notify.push({
			class = "banner",
			tone = "area",
			text = line,
			seconds = HOLD_SECONDS,
			w = SIZE.X,
			height = function(phone: boolean): number
				return if phone then 40 else SIZE.Y
			end,
			build = look(line, color),
		})
	end)
	return scope:New("Folder")({ Name = "AreaBanner" })
end

return AreaBanner
