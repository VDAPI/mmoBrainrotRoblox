--!strict
-- "Party loot" under an after-fight table (S134f): the player's own items from the bag (rarity colour, name through
-- ItemText), the other members' items from Legendary up ("Olek: <item>") and the count of the rest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FightView = require(script.Parent.Parent.FightView)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.ItemText)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Drop: FightView.DropView,
	LayoutOrder: number?,
}

local function FightLoot(scope: Scope, props: Props): Instance?
	local drop = props.Drop
	if #drop.mine == 0 and #drop.party == 0 and drop.more <= 0 then
		return nil
	end
	local function line(order: number, text: Fusion.UsedAs<string>, color: Color3, font: Font): Instance
		return scope:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			TextWrapped = true,
			FontFace = font,
			TextSize = Theme.TextSize.Small,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	local lines: { Instance } = {
		scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
		line(0, Text.T(scope, "fight.drop.title"), Theme.Colors.GoldBright, Theme.Fonts.Heading),
	}
	local order = 1
	if #drop.mine > 0 then
		table.insert(lines, line(order, Text.T(scope, "fight.drop.mine"), Theme.Colors.TextMuted, Theme.Fonts.BodyBold))
		for _, item in drop.mine do
			order += 1
			table.insert(
				lines,
				line(
					order,
					scope:Computed(function(use): string
						local name = ItemText.get(use, item.id, item.up)
						return if item.n and item.n > 1 then `{name} x{item.n}` else name
					end),
					ItemText.rarityColor(item.r),
					Theme.Fonts.BodyMedium
				)
			)
		end
	end
	if #drop.party > 0 then
		order += 1
		table.insert(
			lines,
			line(order, Text.T(scope, "fight.drop.party"), Theme.Colors.TextMuted, Theme.Fonts.BodyBold)
		)
		for _, item in drop.party do
			order += 1
			table.insert(
				lines,
				line(
					order,
					scope:Computed(function(use): string
						return `{item.n}: {ItemText.get(use, item.id, item.up)}`
					end),
					ItemText.rarityColor(item.r),
					Theme.Fonts.BodyMedium
				)
			)
		end
	end
	if drop.more > 0 then
		order += 1
		table.insert(
			lines,
			line(order, Text.T(scope, "fight.drop.more", { n = drop.more }), Theme.Colors.TextMuted, Theme.Fonts.Body)
		)
	end
	return scope:New("Frame")({
		Name = "FightLoot",
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = lines :: any,
	})
end

return FightLoot
