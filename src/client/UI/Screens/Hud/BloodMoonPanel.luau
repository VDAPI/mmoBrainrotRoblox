--!strict
-- Blood Moon panel (S129, DESIGN-17 §7): seen by every player from 10 min before the start to the end, also in the
-- city. Before the start "In 9:41"; during it the time left, the own points and the place in the region's top 10 (or
-- in the city: the regions are a PvP zone, the city is safe) and "Results" (the bloodmoon window). It stands where the
-- world event panel stands (S101: PC the right column over the quest tracker, which moves down by `Offset`; touch the
-- left column under the portrait, below the party frames in a party): world events never run during the Blood Moon.
-- Reads UI/BloodMoonView (attributes, clock), `character.bloodMoon`, `bloodMoonBoard` and `zone.map` only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BloodMoon = require(ReplicatedStorage.Shared.Logic.BloodMoon)
local BloodMoonView = require(script.Parent.Parent.Parent.BloodMoonView)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	OpenResults: () -> (),
	-- Set to the pixels the quest tracker moves down (0 while hidden or on touch).
	Offset: Fusion.Value<number>?,
}

local BLOOD = Color3.fromHex("#C0262D")
local WIDTH_PC = 280
local WIDTH_TOUCH = 240
local PAD = 8
local GAP = 3
local TITLE = 20
local LINE = 18
local INFO = 34 -- two lines: the points and the place, or the city hint
local BUTTON_PC = 30
local BUTTON_TOUCH = 44
-- the same anchors as Hud/WorldEventPanel
local TOUCH_TOP = Theme.Padding.Large + 136 + 6 + 44
local PARTY_TOP = Theme.Padding.Large + 136 + 70
local PARTY_ROW = 58 + 6
local PC_TOP = 400

local function BloodMoonPanel(scope: Scope, props: Props): Instance
	local phase = BloodMoonView.Phase
	local mine = State.Value({ "character", "bloodMoon" })
	local board = BloodMoonView.Board
	local zoneMap = State.Value({ "zone", "map" })
	local party = State.Value({ "party" })
	local touch = Device.Touch

	local shown = scope:Computed(function(use): boolean
		local p = use(phase)
		return p == "soon" or p == "active"
	end)
	local active = scope:Computed(function(use): boolean
		return use(phase) == "active"
	end)
	local touchTop = scope:Computed(function(use): number
		local p = use(party)
		local others = 0
		if type(p) == "table" and type(p.members) == "table" then
			for _, member in p.members do
				if member.id ~= Players.LocalPlayer.UserId then
					others += 1
				end
			end
		end
		return if others > 0 then PARTY_TOP + others * PARTY_ROW else TOUCH_TOP
	end)
	local height = scope:Computed(function(use): number
		local button = if use(touch) then BUTTON_TOUCH else BUTTON_PC
		local h = PAD * 2 + TITLE + LINE + button + GAP * 2
		if use(active) then
			h += INFO + GAP
		end
		return h
	end)
	if props.Offset then
		local offset = props.Offset
		local pushed = scope:Computed(function(use): number
			if not use(shown) or use(touch) then
				return 0
			end
			return use(height) + 8
		end)
		scope:Observer(pushed):onBind(function()
			offset:set(Fusion.peek(pushed))
		end)
	end

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

	return scope:New("Frame")({
		Name = "BloodMoonPanel",
		AnchorPoint = scope:Computed(function(use): Vector2
			return if use(touch) then Vector2.new(0, 0) else Vector2.new(1, 0)
		end),
		Position = scope:Computed(function(use): UDim2
			if use(touch) then
				return UDim2.fromOffset(Theme.Padding.Large, use(touchTop))
			end
			return UDim2.new(1, -Theme.Padding.Large, 0, PC_TOP)
		end),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(if use(touch) then WIDTH_TOUCH else WIDTH_PC, use(height))
		end),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.25,
		Visible = shown,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = BLOOD, Thickness = 1.5 }),
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
				BLOOD,
				16,
				Theme.Fonts.BodyBold
			),
			label(2, LINE, timeText, Theme.Colors.Parchment, 14, Theme.Fonts.BodyMedium),
			label(3, INFO, infoText, Theme.Colors.Text, 13, Theme.Fonts.Body, active),
			Button(scope, {
				Name = "Results",
				LayoutOrder = 4,
				Text = Text.T(scope, "hud.bloodmoon.results"),
				Variant = "secondary",
				TextSize = 14,
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, if use(touch) then BUTTON_TOUCH else BUTTON_PC)
				end),
				OnClick = props.OpenResults,
			}),
		},
	})
end

return BloodMoonPanel
