--!strict
-- Breakpoint cards of a skill (S59, ROZWOJ 2.7, 4): for ranks 5 and 10 "Rank 5 breakthrough · from lv. 26", card A
-- and, when the breakpoint has it, card B (letter, text, state: chosen / works without a choice / "Choose"). The
-- working option has a gold frame; cards of a rank not reached yet are greyed with the level. With option B the
-- rule of changes and the server's last refusal for that rank follow. Without B only card A, no button. The phone
-- sheet shows the cards without buttons (its pinned A / B row chooses). Data from UI/SkillInfo.breakpointCards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local SkillInfo = require(script.Parent.Parent.Parent.SkillInfo)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Breakpoints = {}

local RIGHT = 96

function Breakpoints.new(
	s: Scope,
	use: Fusion.Use,
	ctx: Context.Ctx,
	actions: Actions.Actions,
	skill: SkillData.SkillDef,
	rank: number,
	withButtons: boolean
): { Instance }
	local out: { Instance } = {}
	local character = use(ctx.character)
	local choices = if character and character.path then character.path.bp else nil
	local cards = SkillInfo.breakpointCards(use, skill, rank, choices)
	if #cards == 0 then
		return out
	end
	local refused = use(ctx.bpError)
	local function label(text: string, color: Color3, font: Font?, size: number?): Instance
		return s:New("TextLabel")({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = text,
			TextWrapped = true,
			FontFace = font or Theme.Fonts.Body,
			TextSize = size or Theme.TextSize.Small,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	table.insert(out, label(Text.get(use, "skills.breakpoints"), Theme.Colors.Gold, Theme.Fonts.BodyBold))
	for _, card in cards do
		table.insert(
			out,
			label(
				Text.get(use, "bp.title", { rank = card.at, level = card.level }),
				if card.reached then Theme.Colors.Parchment else Theme.Colors.TextMuted,
				Theme.Fonts.BodyBold,
				14
			)
		)
		local hasB = #card.options > 1
		for _, option in card.options do
			local working = card.working == option.option
			local state = if not card.reached
				then Text.get(use, "skills.unlockAt", { level = card.level })
				elseif card.chosen == option.option then Text.get(use, "bp.chosen")
				elseif card.chosen == nil and option.option == "a" then Text.get(use, "bp.default")
				else ""
			local canChoose = withButtons and card.reached and hasB and card.chosen ~= option.option
			local at: number, choice: SkillData.BreakpointOption = card.at, option.option
			table.insert(
				out,
				s:New("Frame")({
					Name = `Bp{card.at}{option.option}`,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Theme.Colors.Panel,
					BackgroundTransparency = if card.reached then 0.2 else 0.6,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIStroke")({
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Thickness = if working then 2 else 1,
							Color = if working and card.reached then Theme.Colors.Gold else Theme.Colors.Border,
						}),
						s:New("UIPadding")({
							PaddingTop = UDim.new(0, 6),
							PaddingBottom = UDim.new(0, 6),
							PaddingLeft = UDim.new(0, 6),
							PaddingRight = UDim.new(0, 6),
						}),
						s:New("TextLabel")({
							Name = "Letter",
							Size = UDim2.fromOffset(24, 24),
							BackgroundColor3 = if working then Theme.Colors.GoldDim else Theme.Colors.PanelRaised,
							Text = string.upper(option.option),
							FontFace = Theme.Fonts.BodyBold,
							TextSize = 15,
							TextColor3 = Theme.Colors.Parchment,
							[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
						}),
						s:New("TextLabel")({
							Name = "Text",
							Position = UDim2.fromOffset(32, 2),
							Size = UDim2.new(1, -(32 + RIGHT + 6), 0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							Text = option.text,
							TextWrapped = true,
							FontFace = Theme.Fonts.Body,
							TextSize = 14,
							TextColor3 = if card.reached then Theme.Colors.Text else Theme.Colors.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						s:New("TextLabel")({
							Name = "State",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.fromOffset(RIGHT, 18),
							BackgroundTransparency = 1,
							Text = state,
							TextWrapped = true,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = 13,
							TextColor3 = if card.chosen == option.option
								then Theme.Colors.Success
								else Theme.Colors.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Right,
						}),
						if canChoose
							then Button(s, {
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.new(1, 0, 0, 20),
								Size = UDim2.fromOffset(RIGHT, 28),
								Variant = "secondary",
								TextSize = 14,
								Text = Text.get(use, "bp.choose"),
								OnClick = function()
									actions.chooseBp(skill.id, at, choice)
								end,
							}) :: any
							else nil,
						-- keeps the card tall enough for the state and the button
						s:New("Frame")({
							Name = "MinHeight",
							BackgroundTransparency = 1,
							Size = UDim2.fromOffset(1, if canChoose then 48 else 24),
						}),
					},
				})
			)
		end
		if hasB then
			table.insert(out, label(Text.get(use, "bp.rule"), Theme.Colors.TextMuted, nil, 14))
			if refused and refused.key == Skills.choiceKey(skill.id, card.at) then
				table.insert(out, label(Text.get(use, refused.err), Theme.Colors.DangerHover, nil, 14))
			end
		end
	end
	return out
end

return Breakpoints
