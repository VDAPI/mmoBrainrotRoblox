--!strict
-- After-fight card (S134f, DESIGN §17): after an Elite II or an Invasion, bottom right above the skill bar, for
-- Config.FightLog.cardSeconds: the target and the outcome, the header line (time, deaths, dodged blows), the first
-- three rows of the party's table plus the own row, "Details" (the fight log window) and a close button. Off with the
-- setting `fightCard` (the window and the boss reward card stay). Mounted by FightLogController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local FightTable = require(script.Parent.Parent.Components.FightTable)
local FightView = require(script.Parent.Parent.FightView)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Scale = require(script.Parent.Parent.Scale)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Summary: FightView.Summary,
	OpenDetails: () -> (),
	Close: () -> (),
}

local SHOWN = 3 -- rows before the own row

-- The first SHOWN rows, plus the own row when it is further down.
local function shortRows(rows: { FightView.Row }): { FightView.Row }
	local own = State.Get({ "character", "name" })
	local out = {}
	local hasOwn = false
	for i, row in rows do
		if i <= SHOWN then
			table.insert(out, row)
			hasOwn = hasOwn or row.n == own
		end
	end
	if not hasOwn then
		for _, row in rows do
			if row.n == own then
				table.insert(out, row)
				break
			end
		end
	end
	return out
end

local function FightCard(scope: Scope, props: Props): Instance
	local summary = props.Summary
	local compact = Fusion.peek(Scale.VirtualSize).X < 900
	local outcomeColor = if summary.outcome == "win" then Theme.Colors.Success else Theme.Colors.Danger

	local function label(order: number, text: Fusion.UsedAs<string>, color: Color3, font: Font, size: number): Instance
		return scope:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			TextWrapped = true,
			FontFace = font,
			TextSize = size,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	return scope:New("Frame")({
		Name = "FightCard",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -Theme.Padding.Large, 1, -190),
		Size = UDim2.fromOffset(if compact then 340 else 440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.08,
		Active = true,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thick,
				Color = Theme.Colors.GoldDim,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Padding.Medium),
				PaddingBottom = UDim.new(0, Theme.Padding.Medium),
				PaddingLeft = UDim.new(0, Theme.Padding.Medium),
				PaddingRight = UDim.new(0, Theme.Padding.Medium),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
			label(
				1,
				scope:Computed(function(use): string
					return Text.get(use, "fight.card.title", { name = FightView.title(use, summary) })
				end),
				Theme.Colors.GoldBright,
				Theme.Fonts.Heading,
				Theme.TextSize.Body
			),
			label(
				2,
				Text.T(scope, `fight.outcome.{summary.outcome}`),
				outcomeColor,
				Theme.Fonts.BodyBold,
				Theme.TextSize.Small
			),
			label(
				3,
				scope:Computed(function(use): string
					return FightView.headerLine(use, summary.header)
				end),
				Theme.Colors.Parchment,
				Theme.Fonts.BodyMedium,
				Theme.TextSize.Small
			),
			FightTable(scope, { Rows = shortRows(summary.rows), Compact = true, LayoutOrder = 4, RowHeight = 22 }),
			scope:New("Frame")({
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					Button(scope, {
						LayoutOrder = 1,
						Text = Text.T(scope, "fight.details"),
						Variant = "primary",
						Size = UDim2.fromOffset(140, 44),
						TextSize = Theme.TextSize.Small,
						OnClick = props.OpenDetails,
					}),
					Button(scope, {
						LayoutOrder = 2,
						Text = Text.T(scope, "fight.card.close"),
						Variant = "secondary",
						Size = UDim2.fromOffset(110, 44),
						TextSize = Theme.TextSize.Small,
						OnClick = props.Close,
					}),
				},
			}),
		},
	})
end

return FightCard
