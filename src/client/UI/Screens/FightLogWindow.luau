--!strict
-- Fight log window (S134f, DESIGN §17): the last fights of this session (boss, Elite II, Invasion; newest first) on
-- the left, the full table of the picked one on the right: target and outcome, the header line (time, deaths, dodged
-- blows), the party's table (all columns) and the party's loot of a boss. Only the own party is ever shown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FightLoot = require(script.Parent.Parent.Components.FightLoot)
local FightTable = require(script.Parent.Parent.Components.FightTable)
local FightView = require(script.Parent.Parent.FightView)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Scale = require(script.Parent.Parent.Scale)
local Sounds = require(script.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Recent: Fusion.Value<{ FightView.Summary }>,
	Selected: Fusion.Value<number>,
}

local LIST_WIDTH = 190
local ROW = 52

local function FightLogWindow(scope: Scope, props: Props): Fusion.Child
	local compact = Fusion.peek(Scale.VirtualSize).X < 900

	local list = scope:Computed(function(use, s: Scope): { Instance }
		local recent = use(props.Recent)
		local out: { Instance } = {}
		for i, summary in recent do
			local picked = s:Computed(function(use2): boolean
				return use2(props.Selected) == i
			end)
			table.insert(
				out,
				s:New("TextButton")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, ROW),
					AutoButtonColor = false,
					BackgroundColor3 = s:Computed(function(use2): Color3
						return if use2(picked) then Theme.Colors.PanelHover else Theme.Colors.PanelRaised
					end),
					Text = s:Computed(function(use2): string
						local outcome = Text.get(use2, `fight.outcome.{summary.outcome}`)
						return `{FightView.title(use2, summary)}\n{outcome}`
					end),
					TextWrapped = true,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = s:Computed(function(use2): Color3
						return if use2(picked) then Theme.Colors.GoldBright else Theme.Colors.Parchment
					end),
					[OnEvent("Activated")] = function()
						Sounds.play("click")
						props.Selected:set(i)
					end,
					[Children] = { s:New("UICorner")({ CornerRadius = Theme.Corner.Small }) },
				})
			)
		end
		return out
	end)

	local detail = scope:Computed(function(use, s: Scope): { Instance }
		local recent = use(props.Recent)
		local summary = recent[use(props.Selected)] or recent[1]
		if not summary then
			return {
				s:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 60),
					BackgroundTransparency = 1,
					Text = Text.get(use, "fight.recent.none"),
					TextWrapped = true,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.TextMuted,
				}),
			}
		end
		local outcome = Text.get(use, "fight.outcome." .. summary.outcome)
		local items: { Instance } = {
			s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			s:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = Text.get(use, "fight.card.title", { name = FightView.title(use, summary) }),
				TextWrapped = true,
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.GoldBright,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			s:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = `{outcome} · {FightView.headerLine(use, summary.header)}`,
				TextWrapped = true,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = if summary.outcome == "win" then Theme.Colors.Success else Theme.Colors.Warning,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			FightTable(s, { Rows = summary.rows, Compact = compact, LayoutOrder = 3 }),
		}
		local drop = summary.drop
		if drop then
			local loot = FightLoot(s, { Drop = drop, LayoutOrder = 4 })
			if loot then
				table.insert(items, loot)
			end
		end
		return items
	end)

	return {
		scope:New("ScrollingFrame")({
			Name = "Recent",
			Size = UDim2.new(0, LIST_WIDTH, 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 6) }),
				scope:New("TextLabel")({
					LayoutOrder = 0,
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundTransparency = 1,
					Text = Text.T(scope, "fight.recent"),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				list :: any,
			},
		}),
		scope:New("ScrollingFrame")({
			Name = "Detail",
			Position = UDim2.fromOffset(LIST_WIDTH + 12, 0),
			Size = UDim2.new(1, -(LIST_WIDTH + 12), 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
				detail :: any,
			},
		}),
	}
end

return FightLogWindow
