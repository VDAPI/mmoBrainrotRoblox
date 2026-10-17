--!strict
-- Phone details sheet of the skills window (S59, ROZWOJ 4): over the whole window content after a tap on a row or a
-- card. Top bar (Back, name), the scrolling details (or the 3D preview on demand), a pinned A / B row for the
-- breakpoints with option B (A also without a choice, so the "!" goes out) and the action bar (Buy, Refund, To bar,
-- Preview / Details), every target at least 44 px. Missing actions are not shown; disabled ones have their reason in
-- the details.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Details = require(script.Parent.Details)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Preview = require(script.Parent.Preview)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local SkillInfo = require(script.Parent.Parent.Parent.SkillInfo)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local TOP = 44
local BOTTOM = 52
local PINNED = 44
local GAP = 4

local Sheet = {}

function Sheet.new(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions): Instance
	local touchTarget = Theme.Size.MinTouch
	local skillId = scope:Computed(function(use): string?
		return Details.previewSkill(use, ctx)
	end)
	local previewFrame, play = Preview.new(scope, ctx.props.Preview, skillId, nil, false)

	-- Breakpoint cards with option B of the selected skill (the pinned row).
	local pinned = scope:Computed(function(use): { SkillInfo.BpCard }
		local resolved = Details.resolve(use, ctx)
		local skill = resolved.skill
		local character = use(ctx.character)
		if not skill or not character then
			return {}
		end
		local rank = Paths.skillRank(character, skill.id)
		local choices = if character.path then character.path.bp else nil
		local out = {}
		for _, card in SkillInfo.breakpointCards(use, skill, rank, choices) do
			if #card.options > 1 then
				table.insert(out, card)
			end
		end
		return out
	end)
	local hasPinned = scope:Computed(function(use): boolean
		return #use(pinned) > 0
	end)

	local title = scope:Computed(function(use): string
		local resolved = Details.resolve(use, ctx)
		local key = if resolved.skill
			then resolved.skill.nameKey
			elseif resolved.node then resolved.node.nameKey
			elseif resolved.path then resolved.path.nameKey
			else nil
		return if key then Text.get(use, key) else ""
	end)

	local body = scope:Computed(function(use, s: Scope): { Instance }
		if not use(ctx.sheet) then
			return {}
		end
		return Details.lines(s, use, ctx, actions, true)
	end)

	local pinnedRow = scope:Computed(function(use, s: Scope): { Instance }
		local out: { Instance } = {}
		local resolved = Details.resolve(use, ctx)
		local skill = resolved.skill
		if not skill then
			return out
		end
		for _, card in use(pinned) do
			table.insert(
				out,
				s:New("TextLabel")({
					LayoutOrder = #out + 1,
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(36, touchTarget),
					Text = `{card.at}:`,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = if card.reached then Theme.Paper.Heading else Theme.Paper.TextMuted,
				})
			)
			for _, option in card.options do
				local at: number, choice: SkillData.BreakpointOption = card.at, option.option
				table.insert(
					out,
					Button(s, {
						LayoutOrder = #out + 1,
						Size = UDim2.fromOffset(56, touchTarget),
						TextSize = Theme.TextSize.Small,
						Variant = if card.working == choice then "primary" else "secondary",
						Text = string.upper(choice),
						Disabled = not card.reached,
						OnClick = function()
							if card.chosen ~= choice then
								actions.chooseBp(skill.id, at, choice)
							end
						end,
					})
				)
			end
		end
		return out
	end)

	local bar = scope:Computed(function(use, s: Scope): { Instance }
		local specs = Details.actions(use, ctx, actions)
		local out: { Instance } = {}
		local count = #specs + (if use(skillId) then 1 else 0)
		for i, spec in specs do
			table.insert(
				out,
				Button(s, {
					LayoutOrder = i,
					Size = UDim2.new(1 / math.max(1, count), -GAP, 0, touchTarget),
					TextSize = Theme.TextSize.Small,
					Variant = if spec.key == "paths.node.refund" then "secondary" else "primary",
					Text = Text.get(use, spec.key),
					Disabled = not spec.enabled,
					OnClick = spec.run,
				})
			)
		end
		if use(skillId) then
			table.insert(
				out,
				Button(s, {
					LayoutOrder = #specs + 1,
					Size = UDim2.new(1 / math.max(1, count), -GAP, 0, touchTarget),
					TextSize = Theme.TextSize.Small,
					Variant = "secondary",
					Text = Text.get(use, if use(ctx.previewOpen) then "skills.details" else "skills.preview"),
					OnClick = function()
						local open = not Fusion.peek(ctx.previewOpen)
						ctx.previewOpen:set(open)
						if open then
							play()
						end
					end,
				})
			)
		end
		return out
	end)

	local middleHeight = scope:Computed(function(use): number
		return TOP + GAP + BOTTOM + GAP + (if use(hasPinned) then PINNED + GAP else 0)
	end)

	return scope:New("TextButton")({
		Name = "Sheet",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Paper.Surface,
		Text = "",
		ZIndex = 10,
		Visible = ctx.sheet,
		[Children] = {
			-- top bar
			scope:New("Frame")({
				Name = "Top",
				Size = UDim2.new(1, 0, 0, TOP),
				BackgroundTransparency = 1,
				[Children] = {
					Button(scope, {
						Size = UDim2.fromOffset(touchTarget + 64, touchTarget),
						Variant = "ghost",
						TextSize = Theme.TextSize.Small,
						Text = scope:Computed(function(use): string
							return `← {Text.get(use, "skills.back")}`
						end),
						OnClick = function()
							ctx.sheet:set(false)
							ctx.previewOpen:set(false)
						end,
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(touchTarget + 76, 0),
						Size = UDim2.new(1, -(touchTarget + 76), 1, 0),
						BackgroundTransparency = 1,
						Text = title,
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Large,
						TextColor3 = Theme.Paper.Heading,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
				},
			}),
			-- details or the preview
			scope:New("ScrollingFrame")({
				Name = "Body",
				Position = UDim2.fromOffset(0, TOP + GAP),
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 1, -use(middleHeight))
				end),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Paper.Label,
				Visible = scope:Computed(function(use): boolean
					return not use(ctx.previewOpen)
				end),
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
					body :: any,
				},
			}),
			scope:New("Frame")({
				Name = "PreviewArea",
				Position = UDim2.fromOffset(0, TOP + GAP),
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 1, -use(middleHeight))
				end),
				BackgroundTransparency = 1,
				Visible = ctx.previewOpen,
				[Children] = previewFrame,
			}),
			-- pinned A / B row
			scope:New("Frame")({
				Name = "Pinned",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -(BOTTOM + GAP)),
				Size = UDim2.new(1, 0, 0, PINNED),
				BackgroundTransparency = 1,
				Visible = hasPinned,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					pinnedRow :: any,
				},
			}),
			-- action bar
			scope:New("Frame")({
				Name = "Actions",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, BOTTOM),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, GAP),
					}),
					bar :: any,
				},
			}),
		},
		[OnEvent("Activated")] = function() end,
	})
end

return Sheet
