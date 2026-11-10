--!strict
-- Summary bar of the achievements window (S151b): points "{points} / {max}" and done "{done} / {total}" of the shown
-- range with a bar, the range switch (All / Account / Character) and the filter (All / Unearned / Earned).
-- PC: the numbers on the left, the two switches stacked on the right. Touch (owner 2026-11-10: a phone kept one row of
-- the list; UI plan E, Logic/WorldLayout.achievements): the points and the earned count on one line over a thin bar,
-- the two switches side by side in one row under it (buttons >= 44).
-- Review 2026-11-10 (en "This character" wrapped in a phone's button): PC's switches are WorldLayout.ACH_SWITCH wide and
-- every label fits its button in one line (tests/worldlayout.spec).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementView = require(ReplicatedStorage.Shared.Logic.AchievementView)
local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local WorldLayout = require(ReplicatedStorage.Shared.Logic.WorldLayout)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Summary = {}

local GAP = 6
local SWITCH_WIDTH = WorldLayout.ACH_SWITCH

-- The switch labels (id -> text key).
local RANGE_KEYS: { [string]: string } = {
	all = "ach.scope.all",
	account = "ach.scope.account",
	character = "ach.scope.character",
}
local FILTER_KEYS: { [string]: string } = {
	all = "ach.filter.all",
	open = "ach.filter.open",
	done = "ach.filter.done",
}

-- One row of switch buttons over `value` (`keys`: id -> text key).
local function switch(
	scope: Scope,
	value: Fusion.Value<string>,
	ids: { string },
	keys: { [string]: string },
	height: number,
	layout: { [any]: any }
): Instance
	local buttons: { Instance } = {}
	for i, id in ids do
		table.insert(
			buttons,
			Button(scope, {
				LayoutOrder = i,
				Size = UDim2.new(1 / #ids, -GAP, 0, height),
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, keys[id]),
				Variant = scope:Computed(function(use): any
					return if use(value) == id then "primary" else "secondary"
				end),
				OnClick = function()
					value:set(id)
				end,
			})
		)
	end
	local spec: { [any]: any } = {
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, GAP),
			}),
			buttons :: any,
		},
	}
	for k, v in layout do
		spec[k] = v
	end
	return scope:New("Frame")(spec)
end

function Summary.new(scope: Scope, ctx: Context.Ctx, touch: boolean, layout: WorldLayout.Achievements): Instance
	local summary = scope:Computed(function(use): AchievementView.Summary
		return AchievementView.summary(use(ctx.st), use(ctx.range))
	end)
	local switchHeight = layout.switches
	local numbersWidth = if touch then UDim2.new(1, 0, 0, layout.numbers) else UDim2.new(1, -(SWITCH_WIDTH + 12), 1, 0)
	local switchTop = layout.numbers + 4
	local function label(order: number, font: Font, size: number, color: Color3, text: Fusion.UsedAs<string>)
		return scope:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, size + 6),
			BackgroundTransparency = 1,
			Text = text,
			FontFace = font,
			TextSize = size,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	local bar = Bar(scope, {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, if touch then 4 else 10),
		Value = scope:Computed(function(use): number
			return use(summary).points
		end),
		Max = scope:Computed(function(use): number
			return use(summary).pointsMax
		end),
		Color = Theme.Brass.Frame,
		Surface = "paper",
	})
	-- touch: one line, "Punkty: 120 / 400 · Zdobyte: 12 / 80"
	local numbers: { any } = if touch
		then {
			label(
				1,
				Theme.Fonts.BodyBold,
				Theme.TextSize.Body,
				Theme.Paper.Heading,
				scope:Computed(function(use): string
					local s = use(summary)
					local points = Text.get(use, "ach.summary.points", { points = s.points, max = s.pointsMax })
					return `{points}  ·  {Text.get(use, "ach.summary.done", { done = s.done, total = s.total })}`
				end)
			),
			bar,
		}
		else {
			label(
				1,
				Theme.Fonts.Display,
				Theme.TextSize.Large,
				Theme.Paper.Heading,
				scope:Computed(function(use): string
					local s = use(summary)
					return Text.get(use, "ach.summary.points", { points = s.points, max = s.pointsMax })
				end)
			),
			label(
				2,
				Theme.Fonts.BodyMedium,
				Theme.TextSize.Small,
				Theme.Paper.TextMuted,
				scope:Computed(function(use): string
					local s = use(summary)
					return Text.get(use, "ach.summary.done", { done = s.done, total = s.total })
				end)
			),
			bar,
		}
	return scope:New("Frame")({
		Name = "Summary",
		Size = UDim2.new(1, 0, 0, layout.summary),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("Frame")({
				Name = "Numbers",
				Size = numbersWidth,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, if touch then 0 else 2),
					}),
					numbers :: any,
				},
			}),
			switch(scope, ctx.range, AchievementView.SCOPES :: any, RANGE_KEYS, switchHeight, {
				Name = "Range",
				AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(1, 0),
				Position = if touch then UDim2.fromOffset(0, switchTop) else UDim2.fromScale(1, 0),
				Size = if touch
					then UDim2.new(0.5, 0, 0, switchHeight)
					else UDim2.fromOffset(SWITCH_WIDTH, switchHeight),
			}),
			switch(scope, ctx.filter, AchievementView.FILTERS :: any, FILTER_KEYS, switchHeight, {
				Name = "Filter",
				AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(1, 0),
				Position = if touch then UDim2.new(0.5, GAP, 0, switchTop) else UDim2.new(1, 0, 0, switchHeight + GAP),
				Size = if touch
					then UDim2.new(0.5, 0, 0, switchHeight)
					else UDim2.fromOffset(SWITCH_WIDTH, switchHeight),
			}),
		},
	})
end

return Summary
