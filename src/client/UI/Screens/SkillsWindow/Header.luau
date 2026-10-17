--!strict
-- Header row of the skills window (S59, ROZWOJ 4): the build set switch of S58 ("Set 1 / Set 2", "Copy").
-- S139 (DESIGN-18 §12): on a pool tab the free skill points of the shown pool (green while a rank can be bought), the
-- reservation ("Confirm (+3)") and "Cancel" (PC; the phone pins them to the bottom of the screen); on
-- the directions tab the free talent points (green while a node can be bought), the leading direction ("Leading
-- direction: <name>" or "none (12 points in one direction)", Logic/PathView.leading) and the set's capstone
-- (Logic/Paths.capstoneOf; the phone shows these two under the directions switch, PathTab). PC 44 px with 32 px
-- buttons, phone 52 px with 44 px.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local BuildSetSwitch = require(script.Parent.Parent.Parent.Components.BuildSetSwitch)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
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

function Header.new(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions, touch: boolean): Instance
	local buttonHeight = if touch then Theme.Size.MinTouch else 32
	local function label(s: Scope, order: number, text: string, color: Color3, max: number): Instance
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
			[Children] = s:New("UISizeConstraint")({ MaxSize = Vector2.new(max, 22) }),
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
					if canBuy or view.free > 0 then Theme.Paper.Success else Theme.Paper.TextMuted,
					260
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
				if attention and attention.points then Theme.Paper.Success else Theme.Paper.TextMuted,
				220
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
						else Text.get(use, "skills.tree.leadingNone", { n = leading.need }),
					Theme.Paper.Heading,
					280
				)
			)
			local capstone = Paths.capstoneOf(c)
			local capstoneDef = if capstone then PathData.get(capstone) else nil
			table.insert(
				out,
				label(
					s,
					4,
					if capstoneDef
						then Text.get(use, "skills.tree.capstone", { name = Text.get(use, capstoneDef.nameKey) })
						else Text.get(use, "skills.tree.capstoneNone"),
					Theme.Paper.Text,
					200
				)
			)
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
				LayoutOrder = 1,
			}),
			items :: any,
		},
	})
end

return Header
