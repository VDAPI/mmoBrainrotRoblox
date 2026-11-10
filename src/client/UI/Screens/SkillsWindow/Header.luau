--!strict
-- Header row of the skills window (S59, ROZWOJ 4): the build set switch of S58 ("Set 1 / Set 2", "Copy").
-- S139 (DESIGN-18 §12): on a pool tab the free skill points of the shown pool (green while a rank can be bought), the
-- reservation ("Confirm (+3)") and "Cancel" (PC; the phone pins them to the bottom of the screen); on
-- the directions tab the free talent points (green while a node can be bought), the leading direction ("Leading
-- direction: <name>" or "none (12 points in one direction)", Logic/PathView.leading) and the set's capstone
-- (Logic/Paths.capstoneOf; the phone shows these two under the directions switch, PathTab). PC 44 px with 32 px
-- buttons, phone 52 px with 44 px.
-- Owner 2026-11-10 (UI plan, "niektóre rzeczy zasłaniają inne"): the directions tab needed about 1046 px of 876, so
-- the capstone ran past the window's edge and the points lost their number. Now the labels share what the set switch
-- leaves (each shrinks, UIFlexItem, instead of a fixed maximum), the texts are short ("Punkty kierunków: 3",
-- "Prowadzi: <name>" or "Prowadzi: brak" with the rule behind its "i"), the capstone shows only once there is one,
-- and the set switch is narrower here (80-px buttons).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local BuildSetSwitch = require(script.Parent.Parent.Parent.Components.BuildSetSwitch)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Parent.Components.InfoTip)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillPools = require(ReplicatedStorage.Shared.Logic.SkillPools)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Header = {}

Header.HEIGHT = 44
Header.HEIGHT_TOUCH = 52

local CONFIRM_W = 150
local CANCEL_W = 100
local SET_W = 80 -- the set switch's buttons here ("Zestaw 1", "Kopiuj"), 96 elsewhere

function Header.new(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions, touch: boolean): Instance
	local buttonHeight = if touch then Theme.Size.MinTouch else 32
	-- a label as wide as its text, shrinking (and cut at its end) only when the row runs out of room
	local function label(s: Scope, order: number, text: string, color: Color3): Instance
		return s:New("TextLabel")({
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			[Children] = s:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink }),
		})
	end
	local items = scope:Computed(function(use, s: Scope): { Instance }
		local c: any = use(ctx.character)
		if not c then
			return {}
		end
		local out: { Instance } = {}
		if use(ctx.onPools) then
			local view = use(ctx.poolView)
			local pool = use(ctx.pool)
			local def = if pool then SkillPools.def(c.class, pool) else nil
			if not view or not def then
				return out
			end
			local attention = use(ctx.attention)
			local canBuy = attention ~= nil and attention.skills and view.active
			table.insert(
				out,
				label(
					s,
					2,
					Text.get(use, "skills.header.points", { pool = Text.get(use, def.nameKey), n = view.free }),
					if canBuy or view.free > 0 then Theme.Paper.Success else Theme.Paper.TextMuted
				)
			)
			-- the reservation and its buttons (PC; the phone pins them to the bottom)
			if view.reserved > 0 and not touch then
				table.insert(
					out,
					Button(s, {
						LayoutOrder = 4,
						Size = UDim2.fromOffset(CONFIRM_W, buttonHeight),
						Variant = "primary",
						TextSize = Theme.TextSize.Small,
						Text = Text.get(use, "skills.points.confirmN", { n = view.reserved }),
						OnClick = actions.confirmRanks,
					})
				)
				table.insert(
					out,
					Button(s, {
						LayoutOrder = 5,
						Size = UDim2.fromOffset(CANCEL_W, buttonHeight),
						Variant = "ghost",
						TextSize = Theme.TextSize.Small,
						Text = Text.get(use, "common.cancel"),
						OnClick = actions.cancelRanks,
					})
				)
			end
			return out
		end
		-- the directions tab
		local attention = use(ctx.attention)
		local free = use(ctx.free)
		table.insert(
			out,
			label(
				s,
				2,
				Text.get(use, "paths.points", { n = free }),
				if attention and attention.points then Theme.Paper.Success else Theme.Paper.TextMuted
			)
		)
		if not touch then
			local leading = PathView.leading(c)
			local leadingDef = if leading.pathId then PathData.get(leading.pathId) else nil
			table.insert(
				out,
				label(
					s,
					3,
					if leadingDef
						then Text.get(use, "skills.tree.leading", { name = Text.get(use, leadingDef.nameKey) })
						else Text.get(use, "skills.tree.leadingNone"),
					Theme.Paper.Heading
				)
			)
			if not leadingDef then
				-- what makes a direction lead, behind the "i" (it was "(12 pkt w jednym kierunku)" in the line)
				table.insert(
					out,
					InfoTip.new(s, {
						LayoutOrder = 4,
						Text = Text.get(use, "skills.tree.leadingHint", { n = Paths.MAIN_MIN_POINTS }),
					})
				)
			end
			local capstone = Paths.capstoneOf(c)
			local capstoneDef = if capstone then PathData.get(capstone) else nil
			if capstoneDef then
				table.insert(
					out,
					label(
						s,
						5,
						Text.get(use, "skills.tree.capstone", { name = Text.get(use, capstoneDef.nameKey) }),
						Theme.Paper.Text
					)
				)
			end
		end
		return out
	end)
	return scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, if touch then Header.HEIGHT_TOUCH else Header.HEIGHT),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 14),
			}),
			BuildSetSwitch(scope, {
				ShowModal = ctx.props.ShowModal,
				Height = if touch then Theme.Size.MinTouch else 32,
				ButtonWidth = SET_W,
				LayoutOrder = 1,
			}),
			items :: any,
		},
	})
end

return Header
