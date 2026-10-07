--!strict
-- Quest rewards row (S31, DESIGN §20, §23): EXP and gold as an icon with the number, every item as a small
-- ItemSlot with its tooltip (slot ids "view:quest:<id>:<n>", so a tap shows the tooltip on touch), and the
-- "item to choose" note of side quest arcs. Used by the quest dialog, the contract board, the journal and the
-- quest section of the world map's NPC cards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyIcon = require(script.Parent.CurrencyIcon)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.ItemSlot)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Id: string, -- quest id (or another unique key, e.g. "daily1")
	Reward: Quests.Reward,
	SlotSize: number?, -- default 40
	ShowTitle: boolean?, -- "Rewards:" in front
	LayoutOrder: number?,
	Position: UDim2?,
	Width: UDim?, -- default the full width; the height follows the content (wraps)
}

-- Icon and a number (EXP, gold; S35: CurrencyIcon when `iconColor` is nil) or a short note, as tall as the slots
-- so the row lines up.
local function chip(
	scope: Scope,
	order: number,
	icon: string,
	iconColor: Color3?,
	text: Fusion.UsedAs<string>,
	height: number
)
	return scope:New("Frame")({
		Name = "Chip",
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			if iconColor
				then scope:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.fromOffset(20, 20),
					BackgroundTransparency = 1,
					Text = icon,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 18,
					TextColor3 = iconColor,
				})
				else CurrencyIcon(scope, {
					Currency = icon :: CurrencyIcon.Currency,
					Size = UDim2.fromOffset(20, 20),
					LayoutOrder = 1,
				}),
			scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, 20),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = text,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 16,
				TextColor3 = Theme.Colors.Parchment,
			}),
		},
	})
end

local function QuestRewards(scope: Scope, props: Props): Instance
	local size = props.SlotSize or 40
	local reward = props.Reward
	local children: { Instance } = {}
	local order = 0
	local function add(instance: Instance)
		order += 1
		(instance :: any).LayoutOrder = order
		table.insert(children, instance)
	end
	if props.ShowTitle then
		add(scope:New("TextLabel")({
			Size = UDim2.fromOffset(0, size),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				return `{Text.get(use, "quest.rewards")}:`
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = 16,
			TextColor3 = Theme.Colors.GoldBright,
		}))
	end
	if reward.exp > 0 then
		add(chip(
			scope,
			0,
			"exp",
			nil,
			scope:Computed(function(use): string
				return Text.get(use, "quest.reward.exp", { exp = Format.number(reward.exp) })
			end),
			size
		))
	end
	if reward.gold > 0 then
		add(chip(scope, 0, "gold", nil, Format.number(reward.gold), size))
	end
	for n, entry in (reward.items or {}) :: { { id: string, n: number } } do
		if Items.get(entry.id) then
			add(ItemSlot(scope, {
				SlotId = `view:quest:{props.Id}:{n}`,
				Item = ItemRoll.makeStack(entry.id, entry.n, `quest:{props.Id}:{n}`),
				Size = size,
				TooltipCtx = { hints = false, merchantOpen = false },
			}))
		end
	end
	if reward.choice then
		add(chip(
			scope,
			0,
			"?",
			Theme.Colors.GoldBright,
			scope:Computed(function(use): string
				return Text.get(
					use,
					if reward.choice == "final" then "quest.reward.choiceRare" else "quest.reward.choice"
				)
			end),
			size
		))
	end
	local width = props.Width or UDim.new(1, 0)
	return scope:New("Frame")({
		Name = "Rewards",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = UDim2.new(width.Scale, width.Offset, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Wraps = true,
				Padding = UDim.new(0, 10),
			}),
			children :: any,
		},
	})
end

return QuestRewards
