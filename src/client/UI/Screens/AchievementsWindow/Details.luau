--!strict
-- Details of the selected achievement (S151b): the name, the description with its goal, where it counts (account or
-- this character), the progress or the date it was earned, the reward, the whole series (goals, points, rewards,
-- dates) and the next step; the actions "Track" / "Stop tracking" (not for earned or secret ones), "Set title" for an
-- earned title reward (SetTitle, S16) and "Open wardrobe" for an earned cosmetic. PC: the panel on the right; phone:
-- the same lines in a sheet over the window (Details.sheet, the S59 pattern), every button >= 44.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementView = require(ReplicatedStorage.Shared.Logic.AchievementView)
local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SectionLabel = require(script.Parent.Parent.Parent.Components.SectionLabel)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>
type Row = AchievementView.Row

export type ActionSpec = { text: string, run: () -> (), secondary: boolean? }

local Details = {}

Details.WIDTH = 270
local GAP = 6
local TOP = 44

local function dateOf(at: number?): string
	return if type(at) == "number" then os.date("%d.%m.%Y", at) :: string else ""
end

-- The detail row of the selection (nil without one).
function Details.selection(use: Fusion.Use, ctx: Context.Ctx): Row?
	local id = use(ctx.selected)
	if not id then
		return nil
	end
	return AchievementView.detail(use(ctx.st), id)
end

-- The lines of the details (instances in layout order).
function Details.lines(s: Scope, use: Fusion.Use, ctx: Context.Ctx): { Instance }
	local out: { Instance } = {}
	local function text(value: string, font: Font, size: number, color: Color3)
		table.insert(
			out,
			s:New("TextLabel")({
				LayoutOrder = #out + 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextWrapped = true,
				Text = value,
				FontFace = font,
				TextSize = size,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		)
	end
	local function section(key: string)
		table.insert(out, SectionLabel(s, { LayoutOrder = #out + 1, Text = Text.get(use, key) }))
	end
	local row = Details.selection(use, ctx)
	if not row then
		text(Text.get(use, "ach.select"), Theme.Fonts.Body, Theme.TextSize.Body, Theme.Paper.TextMuted)
		return out
	end
	text(Text.get(use, row.nameKey), Theme.Fonts.Display, Theme.TextSize.Large, Theme.Paper.Heading)
	local desc = Context.desc(use, row)
	if desc ~= "" then
		text(desc, Theme.Fonts.Body, Theme.TextSize.Body, Theme.Paper.Text)
	end
	text(
		`{Text.get(use, `ach.details.scope.{row.scope}`)} · {Text.get(use, "ach.points", { n = row.points })}`,
		Theme.Fonts.BodyMedium,
		Theme.TextSize.Small,
		Theme.Paper.TextMuted
	)

	section("ach.details.progress")
	if row.done then
		text(
			Text.get(use, "ach.details.doneAt", { date = dateOf(row.doneAt) }),
			Theme.Fonts.BodyBold,
			Theme.TextSize.Body,
			Theme.Paper.Success
		)
	elseif not row.hidden then
		table.insert(
			out,
			Bar(s, {
				LayoutOrder = #out + 1,
				Size = UDim2.new(1, 0, 0, 12),
				Value = row.pct,
				Max = 1,
				Color = Theme.Brass.Frame,
				Surface = "paper",
			})
		)
		text(Context.progressText(row), Theme.Fonts.BodyBold, Theme.TextSize.Small, Theme.Paper.Label)
	else
		text(Text.get(use, "ach.details.secret"), Theme.Fonts.Body, Theme.TextSize.Small, Theme.Paper.TextMuted)
	end

	if not row.hidden then
		section("ach.details.reward")
		if #row.reward == 0 then
			text(Text.get(use, "ach.details.noReward"), Theme.Fonts.Body, Theme.TextSize.Small, Theme.Paper.TextMuted)
		end
		for _, line in row.reward do
			text(
				`{Context.REWARD_GLYPH[line.kind] or "·"} {Context.rewardText(use, line)}`,
				Theme.Fonts.BodyMedium,
				Theme.TextSize.Body,
				Theme.Paper.Text
			)
		end
	end

	if #row.steps > 1 then
		section("ach.details.series")
		for i, step in row.steps do
			local parts: { string } = {
				Context.ROMAN[i] or tostring(i),
				Text.get(use, "ach.details.goal", { goal = step.goal }),
				Text.get(use, "ach.points", { n = step.points }),
			}
			for _, line in step.reward do
				table.insert(parts, Context.rewardText(use, line))
			end
			if step.done then
				table.insert(parts, `✔ {dateOf(step.doneAt)}`)
			end
			text(
				table.concat(parts, " · "),
				if step.id == row.id then Theme.Fonts.BodyBold else Theme.Fonts.Body,
				Theme.TextSize.Small,
				if step.done then Theme.Paper.Success else Theme.Paper.Text
			)
		end
		if row.next and not row.done then
			text(
				Text.get(use, "ach.details.next", { name = Text.get(use, `ach.{row.next}.name`) }),
				Theme.Fonts.BodyMedium,
				Theme.TextSize.Small,
				Theme.Paper.TextMuted
			)
		end
	end
	return out
end

-- The buttons of the selection.
function Details.actions(use: Fusion.Use, ctx: Context.Ctx): { ActionSpec }
	local out: { ActionSpec } = {}
	local row = Details.selection(use, ctx)
	if not row then
		return out
	end
	local id = row.id
	if not row.done and not row.hidden then
		local tracked = row.tracked
		table.insert(out, {
			text = Text.get(use, if tracked then "ach.untrack" else "ach.track"),
			secondary = tracked,
			run = function()
				ctx.props.Track(id, not tracked)
			end,
		})
	end
	if row.done then
		for _, line in row.reward do
			local rewardId = line.id
			if line.kind == "title" and rewardId then
				table.insert(out, {
					text = Text.get(use, "ach.setTitle"),
					run = function()
						ctx.props.SetTitle(rewardId)
					end,
				})
			elseif line.kind == "cosmetic" and rewardId then
				table.insert(out, {
					text = Text.get(use, "ach.openWardrobe"),
					secondary = true,
					run = function()
						ctx.props.OpenWardrobe(rewardId)
					end,
				})
			end
		end
	end
	return out
end

local function buttons(s: Scope, specs: { ActionSpec }, height: number): { Instance }
	local out: { Instance } = {}
	for i, spec in specs do
		table.insert(
			out,
			Button(s, {
				LayoutOrder = i,
				Size = UDim2.new(1 / math.max(1, #specs), -GAP, 0, height),
				Variant = if spec.secondary then "secondary" else "primary",
				TextSize = Theme.TextSize.Small,
				Text = spec.text,
				OnClick = spec.run,
			})
		)
	end
	return out
end

local function scroller(scope: Scope, position: UDim2, size: Fusion.UsedAs<UDim2>, lines: any): Instance
	return scope:New("ScrollingFrame")({
		Name = "Lines",
		Position = position,
		Size = size,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Label,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
			lines,
		},
	})
end

local function buttonRow(scope: Scope, ctx: Context.Ctx, height: number): Instance
	local list = scope:Computed(function(use, s: Scope): { Instance }
		return buttons(s, Details.actions(use, ctx), height)
	end)
	return scope:New("Frame")({
		Name = "Actions",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, GAP, 0, height),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, GAP),
			}),
			list :: any,
		},
	})
end

-- PC: the panel at the right edge.
function Details.panel(scope: Scope, ctx: Context.Ctx): Instance
	local lines = scope:Computed(function(use, s: Scope): { Instance }
		return Details.lines(s, use, ctx)
	end)
	local height = Theme.Size.ButtonHeightSmall
	return scope:New("Frame")({
		Name = "Details",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, Details.WIDTH, 1, 0),
		BackgroundColor3 = Theme.Paper.Raised,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Paper.Border,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Padding.Medium),
				PaddingBottom = UDim.new(0, Theme.Padding.Medium),
				PaddingLeft = UDim.new(0, Theme.Padding.Medium),
				PaddingRight = UDim.new(0, Theme.Padding.Medium),
			}),
			scroller(scope, UDim2.new(), UDim2.new(1, 0, 1, -(height + GAP)), lines),
			buttonRow(scope, ctx, height),
		},
	})
end

-- Phone: the sheet over the window (Back, the lines, the actions pinned to the bottom).
function Details.sheet(scope: Scope, ctx: Context.Ctx): Instance
	local lines = scope:Computed(function(use, s: Scope): { Instance }
		if not use(ctx.sheet) then
			return {}
		end
		return Details.lines(s, use, ctx)
	end)
	local height = Theme.Size.MinTouch
	return scope:New("TextButton")({
		Name = "Sheet",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Paper.Surface,
		Text = "",
		ZIndex = 10,
		Visible = scope:Computed(function(use): boolean
			return use(ctx.sheet) and use(ctx.selected) ~= nil
		end),
		[OnEvent("Activated")] = function() end,
		[Children] = {
			Button(scope, {
				Size = UDim2.fromOffset(height + 72, height),
				Variant = "ghost",
				TextSize = Theme.TextSize.Small,
				Text = scope:Computed(function(use): string
					return `← {Text.get(use, "ach.back")}`
				end),
				OnClick = function()
					ctx.sheet:set(false)
				end,
			}),
			scroller(scope, UDim2.fromOffset(0, TOP + GAP), UDim2.new(1, 0, 1, -(TOP + GAP + height + GAP)), lines),
			buttonRow(scope, ctx, height),
		},
	})
end

return Details
