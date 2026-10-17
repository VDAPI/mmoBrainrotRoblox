--!strict
-- Header row of the skills window (S59, ROZWOJ 4): the build set switch of S58 ("Set 1 / Set 2", "Copy"), free path
-- points (green while a node can be bought) and (S138) the leading direction ("Leading direction: <name>" or "none
-- (12 points in one direction)", Logic/PathView.leading). PC 44 px with 32 px buttons, phone 52 px with 44 px.
-- S137 (DESIGN-18 §12): the active weapon pool and its free skill points (green while a rank can be bought); the pool
-- tabs and the reservation buttons stand above the Base list (BaseList.poolBar) until the S139 window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildSetSwitch = require(script.Parent.Parent.Parent.Components.BuildSetSwitch)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local SkillPoints = require(ReplicatedStorage.Shared.Logic.SkillPoints)
local SkillPools = require(ReplicatedStorage.Shared.Logic.SkillPools)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Header = {}

Header.HEIGHT = 44
Header.HEIGHT_TOUCH = 52

function Header.new(scope: Scope, ctx: Context.Ctx, touch: boolean): Instance
	local function label(
		order: number,
		text: Fusion.UsedAs<string>,
		color: Fusion.UsedAs<Color3>,
		max: number
	): Instance
		return scope:New("TextLabel")({
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
			[Children] = scope:New("UISizeConstraint")({ MaxSize = Vector2.new(max, 22) }),
		})
	end
	return scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, if touch then Header.HEIGHT_TOUCH else Header.HEIGHT),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 16),
			}),
			BuildSetSwitch(scope, {
				ShowModal = ctx.props.ShowModal,
				Height = if touch then Theme.Size.MinTouch else 32,
				LayoutOrder = 1,
			}),
			label(
				2,
				scope:Computed(function(use): string
					return Text.get(use, "paths.points", { n = use(ctx.free) })
				end),
				scope:Computed(function(use): Color3
					local attention = use(ctx.attention)
					return if attention and attention.points then Theme.Paper.Success else Theme.Paper.TextMuted
				end),
				200
			),
			label(
				3,
				scope:Computed(function(use): string
					local c: any = use(ctx.character)
					if not c then
						return ""
					end
					local leading = PathView.leading(c)
					local def = if leading.pathId then PathData.get(leading.pathId) else nil
					return if def
						then Text.get(use, "skills.tree.leading", { name = Text.get(use, def.nameKey) })
						else Text.get(use, "skills.tree.leadingNone", { n = leading.need })
				end),
				Theme.Paper.Heading,
				280
			),
			label(
				4,
				scope:Computed(function(use): string
					local c: any = use(ctx.character)
					local pool = use(ctx.activePool)
					local def = if c and pool then SkillPools.def(c.class, pool) else nil
					if not c or not pool or not def then
						return ""
					end
					local free = math.max(0, SkillPoints.free(c, pool))
					return Text.get(use, "skills.points.header", { pool = Text.get(use, def.nameKey), n = free })
				end),
				scope:Computed(function(use): Color3
					local attention = use(ctx.attention)
					return if attention and attention.skills then Theme.Paper.Success else Theme.Paper.TextMuted
				end),
				260
			),
		},
	})
end

return Header
