--!strict
-- Categories and the list of the achievements window (S151b). Categories: PC a column of ListRows with the category
-- icon (ArtIcon, UiArt.achCategory) and "done / total"; phone a scrolling Tabs strip. The list: one ListRow per
-- achievement (a series folded to its current step, Logic/AchievementView.rows): the name with the series steps and
-- the reward glyphs, the description with its goal, the range and the points, a thin progress bar and the tracking
-- star. The rows are rebuilt only when the list's shape changes (order, done steps, tracking); a row's bar and numbers
-- follow its own entry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchData = require(ReplicatedStorage.Shared.Data.Achievements)
local AchievementView = require(ReplicatedStorage.Shared.Logic.AchievementView)
local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ListRow = require(script.Parent.Parent.Parent.Components.ListRow)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Tabs = require(script.Parent.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>
type Row = AchievementView.Row

local List = {}

List.CATEGORY_WIDTH = 190
local ICON = 26
local ROW_HEIGHT = 66
local STAR = Theme.Size.MinTouch
local COUNT = 86 -- the "value / goal" column left of the star

-- PC: the category column.
function List.categories(scope: Scope, ctx: Context.Ctx): Instance
	local summary = scope:Computed(function(use): AchievementView.Summary
		return AchievementView.summary(use(ctx.st), use(ctx.range))
	end)
	local rows: { Instance } = {}
	for i, cat in AchData.CATEGORIES do
		table.insert(
			rows,
			ListRow(scope, {
				Name = cat,
				LayoutOrder = i,
				Index = i,
				Inset = ICON + 8,
				Text = Text.T(scope, `ach.cat.{cat}`),
				Value = scope:Computed(function(use): string?
					local c = use(summary).byCat[cat]
					return if c then `{c.done}/{c.total}` else nil
				end),
				Dense = true,
				Selected = scope:Computed(function(use): boolean
					return use(ctx.cat) == cat
				end),
				OnClick = function()
					ctx.cat:set(cat)
				end,
				[Children] = ArtIcon(scope, {
					Key = UiArt.achCategory(cat),
					Glyph = Context.CAT_GLYPH[cat] or "✪",
					GlyphColor = Theme.Paper.Label,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 10, 0.5, 0),
					Size = UDim2.fromOffset(ICON, ICON),
					Label = { FontFace = Theme.Fonts.BodyBold, TextSize = Theme.TextSize.Body },
				}),
			})
		)
	end
	return scope:New("ScrollingFrame")({
		Name = "Categories",
		Size = UDim2.new(0, List.CATEGORY_WIDTH, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Paper.Label,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
			rows :: any,
		},
	})
end

-- Phone: the categories as a scrolling tab strip ("Combat 3/20").
function List.categoryTabs(scope: Scope, ctx: Context.Ctx): Instance
	local summary = scope:Computed(function(use): AchievementView.Summary
		return AchievementView.summary(use(ctx.st), use(ctx.range))
	end)
	local tabs: { Tabs.Tab } = {}
	for _, cat in AchData.CATEGORIES do
		table.insert(tabs, {
			id = cat,
			label = scope:Computed(function(use): string
				local c = use(summary).byCat[cat]
				local name = `{Context.CAT_GLYPH[cat] or ""} {Text.get(use, `ach.cat.{cat}`)}`
				return if c then `{name} {c.done}/{c.total}` else name
			end),
		})
	end
	return Tabs(scope, {
		Tabs = tabs,
		Selected = ctx.cat,
		Scroll = true,
		Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch + 6),
	})
end

-- The tracking star of a row (not for done or hidden ones).
local function star(s: Scope, ctx: Context.Ctx, row: Row): Instance
	return s:New("TextButton")({
		Name = "Star",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(STAR, STAR),
		BackgroundTransparency = 1,
		Text = if row.tracked then "★" else "☆",
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Large,
		TextColor3 = if row.tracked then Theme.Brass.Frame else Theme.Paper.TextMuted,
		Visible = not row.done and not row.hidden,
		ZIndex = 3,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			ctx.props.Track(row.id, not row.tracked)
		end,
	})
end

-- The shape of the list: what forces a rebuild (order, the shown step, done, tracking, the done steps of a series).
local function shapeOf(rows: { Row }): string
	local parts: { string } = {}
	for _, row in rows do
		local doneSteps = 0
		for _, step in row.steps do
			if step.done then
				doneSteps += 1
			end
		end
		table.insert(
			parts,
			`{row.id}:{if row.done then 1 else 0}:{if row.tracked then 1 else 0}:{doneSteps}:{#row.reward}`
		)
	end
	return table.concat(parts, ",")
end

-- The list of the current category, filter and range.
function List.rows(scope: Scope, ctx: Context.Ctx, touch: boolean): Instance
	local rows = scope:Computed(function(use): { Row }
		return AchievementView.rows(use(ctx.st), use(ctx.cat), use(ctx.filter), use(ctx.range))
	end)
	local byId = scope:Computed(function(use): { [string]: Row }
		local out: { [string]: Row } = {}
		for _, row in use(rows) do
			out[row.id] = row
		end
		return out
	end)
	local shape = scope:Computed(function(use): string
		return shapeOf(use(rows))
	end)
	local items = scope:Computed(function(use, s: Scope): { Instance }
		use(shape)
		local out: { Instance } = {}
		local current = Fusion.peek(rows)
		if #current == 0 then
			table.insert(
				out,
				s:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 60),
					BackgroundTransparency = 1,
					Text = Text.get(use, "ach.empty"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.TextMuted,
				})
			)
			return out
		end
		for i, row in current do
			local id = row.id
			local live = s:Computed(function(use2): Row
				return use2(byId)[id] or row
			end)
			local stepsText = Context.stepsText(row)
			local glyphs = Context.rewardGlyphs(row)
			local name = Text.get(use, row.nameKey)
			local main = name
			if stepsText ~= "" then
				main ..= `  {stepsText}`
			end
			if glyphs ~= "" then
				main ..= `  {glyphs}`
			end
			local badge = Text.get(use, `ach.badge.{row.scope}`)
			local desc = Context.desc(use, row)
			local subParts: { string } = {}
			if desc ~= "" then
				table.insert(subParts, desc)
			end
			table.insert(subParts, badge)
			table.insert(subParts, Text.get(use, "ach.points", { n = row.points }))
			table.insert(
				out,
				ListRow(s, {
					Name = id,
					LayoutOrder = i,
					Index = i,
					Height = ROW_HEIGHT,
					RightInset = STAR + 8 + COUNT,
					Text = main,
					Sub = table.concat(subParts, " · "),
					Muted = row.hidden,
					Selected = s:Computed(function(use2): boolean
						local sel = use2(ctx.selected)
						if sel == nil then
							return false
						end
						if sel == id then
							return true
						end
						for _, step in row.steps do
							if step.id == sel then
								return true
							end
						end
						return false
					end),
					OnClick = function()
						ctx.selected:set(id)
						if touch then
							ctx.sheet:set(true)
						end
					end,
					[Children] = {
						Bar(s, {
							Name = "Progress",
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.new(0, Theme.Padding.Small + 4, 1, -5),
							Size = UDim2.new(1, -(Theme.Padding.Small * 2 + 4 + STAR + 8), 0, 5),
							Value = s:Computed(function(use2): number
								return use2(live).pct
							end),
							Max = 1,
							Color = if row.done then Theme.Paper.Success else Theme.Brass.Frame,
							Surface = "paper",
						}),
						s:New("TextLabel")({
							Name = "Count",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -(STAR + 8), 0, 4),
							Size = UDim2.fromOffset(COUNT, 20),
							BackgroundTransparency = 1,
							Text = s:Computed(function(use2): string
								local r = use2(live)
								return if r.done then "✔" else Context.progressText(r)
							end),
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Caption,
							TextColor3 = if row.done then Theme.Paper.Success else Theme.Paper.Label,
							TextXAlignment = Enum.TextXAlignment.Right,
							ZIndex = 2,
						}),
						star(s, ctx, row),
					},
				})
			)
		end
		return out
	end)
	return scope:New("ScrollingFrame")({
		Name = "List",
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Label,
		Size = UDim2.fromScale(1, 1),
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
			items :: any,
		},
	})
end

return List
