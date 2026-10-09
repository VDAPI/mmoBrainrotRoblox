--!strict
-- Post-fight reward card (S30, DESIGN §16): shown to each winner after a boss kill, under the victory message.
-- EXP and gold, whether the winner's one item (in their own bag) is a Legendary / Mythic, today's runs of this
-- boss ("Dziś: 2/3") with the time to the UTC reset, and the chances for the next kill, which grow with every kill
-- that day (FIX 2026-10-09). "OK" closes it; it also closes by itself after a while.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossScaling = require(ReplicatedStorage.Shared.Logic.BossScaling)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Reward = {
	boss: string?,
	exp: number?,
	gold: number?,
	gotLeg: boolean?,
	gotMyth: boolean?,
	leg: number?, -- chance for the next kill, 0..1
	myth: number?,
	runs: number?,
	dailyRuns: number?,
}

export type Props = {
	Reward: Reward,
	Close: () -> (),
}

local function percent(value: number?): number
	return math.floor((tonumber(value) or 0) * 100 + 0.5)
end

local function BossReward(scope: Scope, props: Props): Instance
	local reward = props.Reward
	local boss = if reward.boss then Bosses.get(reward.boss) else nil
	local legendary = Rarities.get(Rarities.LEGENDARY)
	local mythic = Rarities.get(Rarities.MYTHIC)
	local accent = if reward.gotMyth then mythic.color elseif reward.gotLeg then legendary.color else Theme.Colors.Gold

	local function label(order: number, text: Fusion.UsedAs<string>, color: Color3, size: number, font: Font): Instance
		return scope:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			RichText = true,
			TextWrapped = true,
			FontFace = font,
			TextSize = size,
			TextColor3 = color,
			TextStrokeTransparency = 0.6,
		})
	end

	local resultKey = if reward.gotMyth
		then "dungeon.reward.mythic"
		elseif reward.gotLeg then "dungeon.reward.legendary"
		else "dungeon.reward.none"
	local resultColor = if reward.gotMyth
		then mythic.color
		elseif reward.gotLeg then legendary.color
		else Theme.Colors.TextMuted

	return scope:New("Frame")({
		Name = "BossReward",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(540, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.08,
		Active = true,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = if reward.gotMyth then 4 else Theme.Stroke.Thick,
				Color = accent,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Padding.Medium),
				PaddingBottom = UDim.new(0, Theme.Padding.Medium),
				PaddingLeft = UDim.new(0, Theme.Padding.Large),
				PaddingRight = UDim.new(0, Theme.Padding.Large),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
			}),
			label(
				1,
				Text.T(scope, "dungeon.reward.title", { boss = if boss then Text.T(scope, boss.nameKey) else "" }),
				Theme.Colors.GoldBright,
				Theme.TextSize.Large + 2,
				Theme.Fonts.Heading
			),
			label(
				2,
				Text.T(
					scope,
					"combat.reward",
					{ exp = Format.number(reward.exp or 0), gold = Format.number(reward.gold or 0) }
				),
				Theme.Colors.Parchment,
				Theme.TextSize.Body,
				Theme.Fonts.BodyBold
			),
			label(3, Text.T(scope, resultKey), resultColor, Theme.TextSize.Body, Theme.Fonts.BodyBold),
			label(
				4,
				Text.T(scope, "worldmap.card.runsToday", {
					n = reward.runs or 0,
					limit = reward.dailyRuns or 0,
					time = Time.format(BossScaling.untilReset(Clock.now())),
				}),
				if (reward.runs or 0) >= (reward.dailyRuns or 1) then Theme.Colors.Warning else Theme.Colors.Success,
				Theme.TextSize.Small,
				Theme.Fonts.BodyMedium
			),
			label(
				5,
				Text.T(scope, "dungeon.reward.next", { leg = percent(reward.leg), myth = percent(reward.myth) }),
				legendary.color,
				Theme.TextSize.Small,
				Theme.Fonts.BodyBold
			),
			Button(scope, {
				LayoutOrder = 10,
				Text = Text.T(scope, "reveal.ok"),
				Variant = "secondary",
				Size = UDim2.fromOffset(140, Theme.Size.ButtonHeight),
				OnClick = props.Close,
			}),
		},
	})
end

return BossReward
