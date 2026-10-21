--!strict
-- Blood Moon panel (S129, DESIGN-17 §7): seen by every player from 10 min before the start to the end, also in the
-- city. Before the start "In 9:41"; during it the time left, the own points and the place in the region's top 10 (or
-- in the city: the regions are a PvP zone, the city is safe) and "Results" (the bloodmoon window). It stands where the
-- world event panel stands (S101: PC the right column over the quest tracker; touch the left column under the
-- portrait, below the party frames in a party): world events never run during the Blood Moon. Owner 2026-10-21: the
-- column's order and places come from UI/HudSlots (Logic/HudStack), round the elements the player moved.
-- Reads UI/BloodMoonView (attributes, clock), `character.bloodMoon`, `bloodMoonBoard` and `zone.map` only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BloodMoon = require(ReplicatedStorage.Shared.Logic.BloodMoon)
local BloodMoonView = require(script.Parent.Parent.Parent.BloodMoonView)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudDrag = require(script.Parent.Parent.Parent.HudDrag)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	OpenResults: () -> (),
}

local BLOOD = Theme.Glyph.Blood
local WIDTH_PC = 280
local WIDTH_TOUCH = 240
local PAD = 8
local GAP = 3
local TITLE = 22
local LINE = 20
local INFO = 40 -- two lines: the points and the place, or the city hint
local BUTTON_PC = 34
local BUTTON_TOUCH = 44

local function BloodMoonPanel(scope: Scope, props: Props): Instance
	local phase = BloodMoonView.Phase
	local mine = State.Value({ "character", "bloodMoon" })
	local board = BloodMoonView.Board
	local zoneMap = State.Value({ "zone", "map" })
	local touch = Device.Touch

	local shown = scope:Computed(function(use): boolean
		local p = use(phase)
		return p == "soon" or p == "active"
	end)
	local active = scope:Computed(function(use): boolean
		return use(phase) == "active"
	end)
	local height = scope:Computed(function(use): number
		local button = if use(touch) then BUTTON_TOUCH else BUTTON_PC
		local h = PAD * 2 + TITLE + LINE + button + GAP * 2
		if use(active) then
			h += INFO + GAP
		end
		return h
	end)
	-- owner 2026-10-21: moved by its tab, scaled by its corner (UI/HudDrag); a moved panel leaves the column
	local handle = HudDrag.new(scope, "bloodMoon", function(use)
		return if use(touch) then WIDTH_TOUCH else WIDTH_PC
	end)
	-- owner 2026-10-21: the built-in place in the HUD column, round the moved elements (UI/HudSlots)
	local slot = HudSlots.join(
		scope,
		"bloodMoon",
		scope:Computed(function(use): HudSlots.Box
			local w, h = if use(touch) then WIDTH_TOUCH else WIDTH_PC, use(height)
			return {
				shown = use(shown),
				w = w,
				h = h,
				custom = HudSlots.moved(use(handle.corner), w, h, use(handle.scale)),
			}
		end)
	)

	local timeText = scope:Computed(function(use): string
		local t = use(BloodMoonView.Now)
		if use(phase) == "active" then
			local ends = use(BloodMoonView.EndsAt)
			return Text.get(use, "hud.bloodmoon.timeLeft", { time = Time.format((tonumber(ends) or t) - t) })
		end
		local starts = use(BloodMoonView.Next)
		return Text.get(use, "hud.bloodmoon.startsIn", { time = Time.format((tonumber(starts) or t) - t) })
	end)
	local infoText = scope:Computed(function(use): string
		if not use(active) then
			return ""
		end
		local map = use(zoneMap)
		local region = if type(map) == "string" then BloodMoon.regionOf(map) else nil
		if not region then
			return Text.get(use, "hud.bloodmoon.cityHint")
		end
		local state = use(mine)
		local id = use(BloodMoonView.Id)
		local points = if type(state) == "table" and state.id == id then tonumber(state.points) or 0 else 0
		local line = Text.get(use, "hud.bloodmoon.mine", { points = points })
		local b = use(board)
		local regionBoard = if type(b) == "table" and type(b.regions) == "table" then b.regions[region] else nil
		if type(regionBoard) == "table" and type(regionBoard.me) == "number" then
			local def = Maps.get(region)
			line ..= "\n" .. Text.get(use, "hud.bloodmoon.rank", {
				rank = regionBoard.me,
				region = if def then Text.get(use, def.nameKey) else region,
			})
		end
		return line
	end)

	local function label(order: number, h: number, text: any, color: any, size: number, font: Font, visible: any?)
		return scope:New("TextLabel")({
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, h),
			Text = text,
			TextColor3 = color,
			TextSize = size,
			FontFace = font,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = h > LINE,
			TextTruncate = if h > LINE then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
			Visible = visible,
		})
	end

	local body = scope:New("Frame")({
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = BLOOD, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, PAD),
				PaddingBottom = UDim.new(0, PAD),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
			label(
				1,
				TITLE,
				scope:Computed(function(use): string
					return `☾ {Text.get(use, "bloodmoon.name")}`
				end),
				Theme.Iron.Danger,
				Theme.TextSize.Small,
				Theme.Fonts.BodyBold
			),
			label(2, LINE, timeText, Theme.Iron.Text, Theme.TextSize.Small, Theme.Fonts.BodyMedium),
			label(3, INFO, infoText, Theme.Iron.Text, Theme.TextSize.Small, Theme.Fonts.Body, active),
			Button(scope, {
				Surface = "iron", -- S135: on a dark HUD / overlay surface
				Name = "Results",
				LayoutOrder = 4,
				Text = Text.T(scope, "hud.bloodmoon.results"),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, if use(touch) then BUTTON_TOUCH else BUTTON_PC)
				end),
				OnClick = props.OpenResults,
			}),
		},
	})
	return HudDrag.frame(scope, handle, {
		Name = "BloodMoonPanel",
		AnchorPoint = Vector2.zero,
		Position = HudSlots.position(scope, slot),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(if use(touch) then WIDTH_TOUCH else WIDTH_PC, use(height))
		end),
		Visible = shown,
		Content = body,
	})
end

return BloodMoonPanel
