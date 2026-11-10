--!strict
-- Breakpoint cards of a skill (S59, ROZWOJ 2.7, 4): for ranks 5 and 10 "Rank 5 breakthrough · from lv. 26", card A
-- and, when the breakpoint has it, card B. The working option has a gold frame; cards of a rank not reached yet are
-- greyed (the level is in the line above them). Without B only card A, no button. Data from
-- UI/SkillInfo.breakpointCards.
-- Owner 2026-10-21 (too many detailed descriptions): the rule of changes in one short line, the whole rule behind an "i".
-- Owner 2026-11-10 (UI plan: "nothing folds", one home per thing): the cards live in the folded "Przełomy" section of
-- the details (Section skillBreakpoints, Details), so no label of their own here. A card is one row: the letter, its
-- text (one short line, at most 48 characters: TextCaps "breakpoint"), and on the right either "Wybierz" or its state.
-- The rule line comes once under all cards, not under each rank. The phone chooses on the cards too (44-px buttons;
-- its sheet lost the pinned A / B row, GearLayout.skillSheet). `summary` is the section's folded line: the version
-- that works at each reached rank ("Ranga 5: A · Ranga 10: B"), the level of the first one before that, and
-- "Przełom do wyboru" as a badge (`waiting`) while a reached breakpoint with B has no choice (the tile's "!" rule).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Parent.Components.InfoTip)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local SkillInfo = require(script.Parent.Parent.Parent.SkillInfo)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

-- `rows`: the instances of the section (empty: the skill has no breakpoints); `summary` and `waiting` as above.
export type Built = { rows: { Instance }, summary: string?, waiting: boolean }

local Breakpoints = {}

local LETTER = 24
local RIGHT = 96 -- the state or the "Wybierz" button
local PAD = 6

function Breakpoints.new(
	s: Scope,
	use: Fusion.Use,
	ctx: Context.Ctx,
	actions: Actions.Actions,
	skill: SkillData.SkillDef,
	rank: number,
	touch: boolean
): Built
	local rows: { Instance } = {}
	local function add(item: Instance)
		(item :: any).LayoutOrder = #rows + 1
		table.insert(rows, item)
	end
	local character = use(ctx.character)
	local choices = if character and character.path then character.path.bp else nil
	local cards = SkillInfo.breakpointCards(use, skill, rank, choices)
	if #cards == 0 then
		return { rows = rows, summary = nil, waiting = false }
	end
	local refused = use(ctx.bpError)
	local buttonH = if touch then Theme.Size.MinTouch else 32
	local function label(text: string, color: Color3, font: Font?): Instance
		return s:New("TextLabel")({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = text,
			TextWrapped = true,
			FontFace = font or Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	local waiting = false
	local anyB = false
	local parts: { string } = {}
	for _, card in cards do
		local hasB = #card.options > 1
		anyB = anyB or hasB
		if card.reached then
			if hasB and card.chosen == nil then
				waiting = true
			end
			table.insert(parts, Text.get(use, "bp.summary", { rank = card.at, option = string.upper(card.working) }))
		end
		add(
			label(
				Text.get(use, "bp.title", { rank = card.at, level = card.level }),
				if card.reached then Theme.Paper.Text else Theme.Paper.TextMuted,
				Theme.Fonts.BodyBold
			)
		)
		for _, option in card.options do
			local working = card.working == option.option
			local canChoose = card.reached and hasB and card.chosen ~= option.option
			-- the state on the right where no button stands there (the level of a rank not reached is in its line)
			local state = if not card.reached or canChoose
				then ""
				elseif card.chosen == option.option then Text.get(use, "bp.chosen")
				elseif card.chosen == nil and option.option == "a" then Text.get(use, "bp.default")
				else ""
			local right = canChoose or state ~= ""
			local at: number, choice: SkillData.BreakpointOption = card.at, option.option
			add(s:New("Frame")({
				Name = `Bp{card.at}{option.option}`,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = if card.reached then Theme.Paper.Raised else Theme.Paper.Sunken,
				[Children] = {
					s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					s:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = if working then Theme.Stroke.Normal else Theme.Stroke.Thin,
						Color = if working and card.reached then Theme.Brass.Frame else Theme.Paper.Border,
					}),
					s:New("UIPadding")({
						PaddingTop = UDim.new(0, PAD),
						PaddingBottom = UDim.new(0, PAD),
						PaddingLeft = UDim.new(0, PAD),
						PaddingRight = UDim.new(0, PAD),
					}),
					s:New("TextLabel")({
						Name = "Letter",
						Size = UDim2.fromOffset(LETTER, LETTER),
						BackgroundColor3 = if working then Theme.Paper.Accent else Theme.Paper.Surface,
						Text = string.upper(option.option),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = if working then Theme.Paper.AccentText else Theme.Paper.Text,
						[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					}),
					-- one short line; it wraps rather than hiding words while a text is still over its 48
					s:New("TextLabel")({
						Name = "Text",
						Position = UDim2.fromOffset(LETTER + 8, 2),
						Size = UDim2.new(1, -(LETTER + 8 + (if right then RIGHT + PAD else 0)), 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Text = option.text,
						TextWrapped = true,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = if card.reached then Theme.Paper.Text else Theme.Paper.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					if state ~= ""
						then s:New("TextLabel")({
							Name = "State",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, 0, 0, 2),
							Size = UDim2.fromOffset(RIGHT, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							Text = state,
							TextWrapped = true,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if card.chosen == option.option
								then Theme.Paper.Success
								else Theme.Paper.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Right,
						}) :: any
						else nil,
					if canChoose
						then Button(s, {
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.fromOffset(RIGHT, buttonH),
							Variant = "secondary",
							TextSize = Theme.TextSize.Small,
							Text = Text.get(use, "bp.choose"),
							OnClick = function()
								actions.chooseBp(skill.id, at, choice)
							end,
						}) :: any
						else nil,
					-- keeps the row as tall as the letter and the button
					s:New("Frame")({
						Name = "MinHeight",
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(1, if canChoose then buttonH else LETTER),
					}),
				},
			}))
		end
		if hasB and refused and refused.key == Skills.choiceKey(skill.id, card.at) then
			add(label(Text.get(use, refused.err), Theme.Paper.Danger))
		end
	end
	-- the rule of changes once, under every card (only breakpoints with B are chosen)
	if anyB then
		local rule: any = label(Text.get(use, "bp.rule.short"), Theme.Paper.TextMuted)
		rule.Size = UDim2.new(1, -32, 0, 0)
		add(s:New("Frame")({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			[Children] = {
				rule,
				InfoTip.new(s, {
					Text = Text.get(use, "bp.rule"),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
				}),
			},
		}))
	end

	local summary = if waiting
		then Text.get(use, "bp.waiting")
		elseif #parts > 0 then table.concat(parts, " · ")
		else Text.get(use, "skills.unlockAt", { level = cards[1].level })
	return { rows = rows, summary = summary, waiting = waiting }
end

return Breakpoints
