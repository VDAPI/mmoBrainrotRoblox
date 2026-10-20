--!strict
-- Summary bar of the achievements window (S151b): points "{points} / {max}" and done "{done} / {total}" of the shown
-- range with a bar, the range switch (All / Account / This character) and the filter (All / In progress / Earned).
-- PC: the numbers on the left, the two switches stacked on the right; phone: the numbers, then the two switches full
-- width (buttons >= 44).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementView = require(ReplicatedStorage.Shared.Logic.AchievementView)
local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Summary = {}

local GAP = 6
local SWITCH_WIDTH = 330

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

Summary.HEIGHT = Theme.Size.ButtonHeightSmall * 2 + GAP
Summary.HEIGHT_TOUCH = 64 + (Theme.Size.MinTouch + GAP) * 2

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

function Summary.new(scope: Scope, ctx: Context.Ctx, touch: boolean): Instance
	local summary = scope:Computed(function(use): AchievementView.Summary
		return AchievementView.summary(use(ctx.st), use(ctx.range))
	end)
	local switchHeight = if touch then Theme.Size.MinTouch else Theme.Size.ButtonHeightSmall
	local numbersWidth = if touch then UDim2.new(1, 0, 0, 64) else UDim2.new(1, -(SWITCH_WIDTH + 12), 1, 0)
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
	return scope:New("Frame")({
		Name = "Summary",
		Size = UDim2.new(1, 0, 0, if touch then Summary.HEIGHT_TOUCH else Summary.HEIGHT),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("Frame")({
				Name = "Numbers",
				Size = numbersWidth,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
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
					Bar(scope, {
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 10),
						Value = scope:Computed(function(use): number
							return use(summary).points
						end),
						Max = scope:Computed(function(use): number
							return use(summary).pointsMax
						end),
						Color = Theme.Brass.Frame,
						Surface = "paper",
					}),
				},
			}),
			switch(scope, ctx.range, AchievementView.SCOPES :: any, RANGE_KEYS, switchHeight, {
				Name = "Range",
				AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(1, 0),
				Position = if touch then UDim2.fromOffset(0, 64 + GAP) else UDim2.fromScale(1, 0),
				Size = if touch
					then UDim2.new(1, GAP, 0, switchHeight)
					else UDim2.fromOffset(SWITCH_WIDTH, switchHeight),
			}),
			switch(scope, ctx.filter, AchievementView.FILTERS :: any, FILTER_KEYS, switchHeight, {
				Name = "Filter",
				AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(1, 0),
				Position = if touch
					then UDim2.fromOffset(0, 64 + GAP * 2 + switchHeight)
					else UDim2.new(1, 0, 0, switchHeight + GAP),
				Size = if touch
					then UDim2.new(1, GAP, 0, switchHeight)
					else UDim2.fromOffset(SWITCH_WIDTH, switchHeight),
			}),
		},
	})
end

return Summary
