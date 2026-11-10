--!strict
-- After-fight card (S134f, DESIGN §17): after an Elite II or an Invasion, bottom right above the skill bar, for
-- Config.FightLog.cardSeconds: the target and the outcome, the header line (time, deaths, dodged blows), the first
-- three rows of the party's table plus the own row, "Details" (the fight log window) and a close button. Off with the
-- setting `fightCard` (the window and the boss reward card stay). Mounted by FightLogController. S149b: after a world
-- boss also the player's place in the contribution ("Place 3 of 14 · share 9.5 %", no stranger named).
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"; owner question 1):
-- the card is one of UI/Notify's cards (FightCard.push): the target and the outcome in the PC corner's card slot (a
-- tablet: under the toasts, a phone: one line of its M zone) with 'Szczegóły'; the full table (every row, the header
-- line, the place) opens from there over a dimmed screen (a phone's full-screen sheet), closed by a tap beside it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local FightTable = require(script.Parent.Parent.Components.FightTable)
local FightView = require(script.Parent.Parent.FightView)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Notify = require(script.Parent.Parent.Notify)
local Scale = require(script.Parent.Parent.Scale)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Summary: FightView.Summary,
	OpenDetails: () -> (), -- the fight log window
	Close: () -> (),
	Sheet: boolean?, -- a phone's full-screen sheet: the view fills its width from the top
}

local WIDTH = 600
local VISIBLE = 8 -- rows before the table scrolls

local FightCard = {}

-- The full view ('Szczegóły' of the card).
function FightCard.full(scope: Scope, props: Props): Instance
	local summary = props.Summary
	local sheet = props.Sheet == true
	local compact = sheet or Fusion.peek(Scale.VirtualSize).X < 900
	local outcomeColor = if summary.outcome == "win" then Theme.Iron.Success else Theme.Iron.Danger

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
		AnchorPoint = if sheet then Vector2.zero else Vector2.new(0.5, 0.5),
		Position = if sheet then UDim2.new() else UDim2.fromScale(0.5, 0.5),
		Size = if sheet then UDim2.fromScale(1, 0) else UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Iron.Surface,
		Active = true, -- a tap inside never reaches the dimmed backdrop
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thick,
				Color = Theme.Iron.Rule,
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
				Theme.Brass.Bright,
				Theme.Fonts.Display,
				Theme.TextSize.Large
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
				Theme.Iron.Text,
				Theme.Fonts.BodyMedium,
				Theme.TextSize.Small
			),
			-- S149b: the place in the world boss's contribution
			(if summary.place
				then label(
					4,
					scope:Computed(function(use): string
						return FightView.placeLine(use, summary.place :: FightView.Place)
					end),
					Theme.Brass.Bright,
					Theme.Fonts.BodyBold,
					Theme.TextSize.Small
				)
				else nil) :: any,
			FightTable(scope, {
				Rows = summary.rows,
				Compact = compact,
				MaxVisible = VISIBLE,
				LayoutOrder = 5,
				Surface = "iron",
			}),
			scope:New("Frame")({
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					Button(scope, {
						Surface = "iron",
						LayoutOrder = 1,
						Text = Text.T(scope, "window.fightlog.title"),
						Variant = "secondary",
						Size = UDim2.fromOffset(170, Theme.Size.MinTouch),
						TextSize = Theme.TextSize.Small,
						OnClick = function()
							props.Close()
							props.OpenDetails()
						end,
					}),
					Button(scope, {
						Surface = "iron",
						LayoutOrder = 2,
						Text = Text.T(scope, "fight.card.close"),
						Variant = "primary",
						Size = UDim2.fromOffset(120, Theme.Size.MinTouch),
						TextSize = Theme.TextSize.Small,
						OnClick = props.Close,
					}),
				},
			}),
		},
	})
end

-- Puts the card into UI/Notify's queue for `seconds`: the target and the outcome, 'Szczegóły' (the full view) and ✕.
-- `openLog`: the fight log window.
function FightCard.push(summary: FightView.Summary, openLog: () -> (), seconds: number): Notify.Handle?
	return Notify.card({
		class = "fightResult",
		title = Text.now("fight.card.title", { name = FightView.title(Fusion.peek, summary) }),
		line = Text.now(`fight.outcome.{summary.outcome}`),
		accent = if summary.outcome == "win" then Theme.Iron.Success else Theme.Iron.Danger,
		seconds = seconds,
		details = function()
			Notify.details(function(s: Scope, close: () -> (), sheet: boolean): Instance
				return FightCard.full(s, { Summary = summary, OpenDetails = openLog, Close = close, Sheet = sheet })
			end)
		end,
	})
end

return FightCard
