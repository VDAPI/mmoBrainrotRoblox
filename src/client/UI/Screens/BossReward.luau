--!strict
-- Post-fight reward card (S30, DESIGN §16): shown to each winner after a boss kill, under the victory message.
-- EXP and gold, whether the winner's one item (in their own bag) is a Legendary / Mythic, today's runs of this
-- boss ("Dziś: 2/3") with the time to the UTC reset, and the chances for the next kill, which grow with every kill
-- that day (FIX 2026-10-09). "OK" closes it; it also closes by itself after a while.
-- S60: the party's Fortune (Legendary multiplier, an ennobled item, a second item) only when it counted, and the
-- "Fight summary" table: damage share, healing and shields of every member. On short screens the card sits in the
-- middle and the table scrolls after 4 rows. S61: an "Intercepted" column when anyone took over blows from allies.
-- S97: a new mount / mount skin from the personal boss roll (lines above the fight summary).
-- S134f: the fight meter (Components/FightTable: numbers and %, taken, deaths, dodges; phones see fewer columns), the
-- header line (fight time, deaths, dodged blows), "Party loot" (Components/FightLoot) and "Details" (the fight log).
-- S149b: the world boss form (`world`): EXP, gold and the own items (FightLoot) or the reason without a reward (level,
-- share, claimed), the next world boss in the player's own time instead of today's runs and the next kill's chances;
-- the fight table stays on the small after-fight card (FightCard, with the place in the contribution).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local BossScaling = require(ReplicatedStorage.Shared.Logic.BossScaling)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local ClockText = require(script.Parent.Parent.ClockText)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local FightLoot = require(script.Parent.Parent.Components.FightLoot)
local FightTable = require(script.Parent.Parent.Components.FightTable)
local FightView = require(script.Parent.Parent.FightView)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MountData = require(ReplicatedStorage.Shared.Data.Mounts)
local GroupLuck = require(script.Parent.Parent.GroupLuck)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Scale = require(script.Parent.Parent.Scale)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local WorldBoss = require(ReplicatedStorage.Shared.Logic.WorldBoss)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.UiArtState)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

-- S134f: the rows of the fight meter (UI/FightView.Row: S60 n, c, d, h, s, i plus a, t, x, v, w).
export type SummaryRow = FightView.Row

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
	luckMul: number?, -- S60: the party's Legendary multiplier (shown above 1)
	luckFrom: string?,
	upgraded: boolean?, -- Fortune ennobled the item (Unique -> Heroic)
	extra: boolean?, -- Fortune's second item
	summary: { SummaryRow }?,
	fight: FightView.Header?, -- S134f: fight time, deaths, dodged / aimed blows of the party
	drop: FightView.DropView?, -- S134f: own items and the party's from Legendary up
	mount: string?, -- S97: a new mount from the personal roll (Data/Mounts id)
	mountSkin: string?, -- S97: a new mount skin (Data/Cosmetics id)
	world: boolean?, -- S149b: the world boss form
	reason: string?, -- S149b: no reward ("level" | "share" | "claimed")
	minLevel: number?, -- S149b: the reward level (the "level" reason's text)
}

export type Props = {
	Reward: Reward,
	Close: () -> (),
	OpenDetails: (() -> ())?, -- S134f: the fight log window ("Details")
}

local function percent(value: number?): number
	return math.floor((tonumber(value) or 0) * 100 + 0.5)
end

local SUMMARY_VISIBLE = 4 -- rows before the table scrolls on short screens

local function BossReward(scope: Scope, props: Props): Instance
	local reward = props.Reward
	local boss = if reward.boss then Bosses.get(reward.boss) else nil
	local legendary = Rarities.get(Rarities.LEGENDARY)
	local mythic = Rarities.get(Rarities.MYTHIC)
	local portrait = if boss then UiArt.boss(boss.id) else nil
	UiArtState.ensureKey(portrait)
	local accent = if reward.gotMyth
		then mythic.paperColor
		elseif reward.gotLeg then legendary.paperColor
		else Theme.Brass.Frame

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
		})
	end

	local resultKey = if reward.gotMyth
		then "dungeon.reward.mythic"
		elseif reward.gotLeg then "dungeon.reward.legendary"
		else "dungeon.reward.none"
	local resultColor = if reward.gotMyth
		then mythic.textColor
		elseif reward.gotLeg then legendary.textColor
		else Theme.Paper.TextMuted

	local compact = Fusion.peek(Scale.VirtualSize).Y < 600
	local luckMul = tonumber(reward.luckMul) or 1
	local extras: { Instance } = {}
	if luckMul > 1 then
		table.insert(
			extras,
			label(
				6,
				scope:Computed(function(use): string
					return GroupLuck.line(use, {
						legendaryMul = luckMul,
						upgrade = 0,
						extra = 0,
						from = reward.luckFrom,
					}) or ""
				end),
				Theme.Paper.Heading,
				Theme.TextSize.Small,
				Theme.Fonts.BodyBold
			)
		)
	end
	if reward.upgraded then
		table.insert(
			extras,
			label(
				7,
				Text.T(scope, "luck.upgraded"),
				Rarities.get(Rarities.HEROIC).textColor,
				Theme.TextSize.Small,
				Theme.Fonts.BodyBold
			)
		)
	end
	if reward.extra then
		table.insert(
			extras,
			label(8, Text.T(scope, "luck.extra"), Theme.Paper.Heading, Theme.TextSize.Small, Theme.Fonts.BodyBold)
		)
	end
	local mountDef = if reward.mount then MountData.get(reward.mount) else nil
	if mountDef then
		table.insert(
			extras,
			label(
				8,
				Text.T(scope, "boss.mountGot", { mount = Text.T(scope, mountDef.nameKey) }),
				Theme.Paper.Heading,
				Theme.TextSize.Body,
				Theme.Fonts.BodyBold
			)
		)
	end
	local skinDef = if reward.mountSkin then Cosmetics.get(reward.mountSkin) else nil
	if skinDef then
		table.insert(
			extras,
			label(
				8,
				Text.T(scope, "boss.skinGot", { skin = Text.T(scope, skinDef.nameKey) }),
				Theme.Paper.Heading,
				Theme.TextSize.Small,
				Theme.Fonts.BodyBold
			)
		)
	end
	local summary = reward.summary
	if summary and #summary > 0 then
		table.insert(
			extras,
			label(
				9,
				Text.T(scope, "dungeon.summary.title"),
				Theme.Paper.Heading,
				Theme.TextSize.Body,
				Theme.Fonts.Display
			)
		)
		-- S134f: "Fight time 3:42 · Deaths: Ala, Olek · Dodged blows 14 / 17" above the table
		local header = reward.fight
		if header then
			table.insert(
				extras,
				label(
					9,
					scope:Computed(function(use): string
						return FightView.headerLine(use, header)
					end),
					Theme.Paper.Raised,
					Theme.TextSize.Small,
					Theme.Fonts.BodyMedium
				)
			)
		end
		table.insert(
			extras,
			FightTable(scope, {
				Rows = summary,
				Compact = compact,
				MaxVisible = if compact then SUMMARY_VISIBLE else nil,
				LayoutOrder = 10,
			})
		)
	end
	-- S134f: the party's loot under the table
	local drop = reward.drop
	if drop then
		local loot = FightLoot(scope, { Drop = drop, LayoutOrder = 10 })
		if loot then
			table.insert(extras, loot)
		end
	end
	-- S134f: OK and "Details" (the fight log window) side by side
	local buttons: { Instance } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Button(scope, {
			LayoutOrder = 1,
			Text = Text.T(scope, "reveal.ok"),
			Variant = "secondary",
			Size = UDim2.fromOffset(140, Theme.Size.ButtonHeight),
			OnClick = props.Close,
		}),
	}
	local openDetails = props.OpenDetails
	if openDetails and summary and #summary > 0 then
		table.insert(
			buttons,
			Button(scope, {
				LayoutOrder = 2,
				Text = Text.T(scope, "fight.details"),
				Variant = "secondary",
				Size = UDim2.fromOffset(160, Theme.Size.ButtonHeight),
				OnClick = function()
					openDetails()
					props.Close()
				end,
			})
		)
	end

	local dungeonLines: { Instance } = {}
	if not reward.world then
		dungeonLines = {
			label(
				2,
				Text.T(
					scope,
					"combat.reward",
					{ exp = Format.number(reward.exp or 0), gold = Format.number(reward.gold or 0) }
				),
				Theme.Paper.Text,
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
				if (reward.runs or 0) >= (reward.dailyRuns or 1) then Theme.Paper.Warning else Theme.Paper.Success,
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
		}
	end
	-- S149b: the world boss: the reward or the reason, then the next occurrence
	local worldLines: { Instance } = {}
	if reward.world then
		if reward.reason then
			table.insert(
				worldLines,
				label(
					2,
					Text.T(scope, "worldboss.rewardCard.none"),
					Theme.Paper.Danger,
					Theme.TextSize.Body,
					Theme.Fonts.BodyBold
				)
			)
			table.insert(
				worldLines,
				label(
					3,
					Text.T(scope, `worldboss.noReward.{reward.reason}`, { level = reward.minLevel or 0 }),
					Theme.Paper.Text,
					Theme.TextSize.Small,
					Theme.Fonts.BodyMedium
				)
			)
		else
			table.insert(
				worldLines,
				label(
					2,
					Text.T(
						scope,
						"combat.reward",
						{ exp = Format.number(reward.exp or 0), gold = Format.number(reward.gold or 0) }
					),
					Theme.Paper.Text,
					Theme.TextSize.Body,
					Theme.Fonts.BodyBold
				)
			)
			if reward.gotLeg or reward.gotMyth then
				table.insert(
					worldLines,
					label(3, Text.T(scope, resultKey), resultColor, Theme.TextSize.Body, Theme.Fonts.BodyBold)
				)
			end
		end
		table.insert(
			worldLines,
			label(
				4,
				Text.T(scope, "worldboss.rewardCard.next", {
					time = ClockText.hhmm(WorldBoss.next(Clock.now()).startsAt),
				}),
				Theme.Paper.TextMuted,
				Theme.TextSize.Small,
				Theme.Fonts.BodyMedium
			)
		)
	end

	return scope:New("Frame")({
		Name = "BossReward",
		AnchorPoint = if compact then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 0),
		Position = if compact then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(if compact then 540 else 660, 0), -- S134f: wider for the meter columns
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Paper.Surface,
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
			-- S119: the boss portrait above the title once loaded (an invisible item takes no room in the list).
			ArtIcon.Image(scope, {
				Name = "Portrait",
				Key = portrait,
				Size = UDim2.fromOffset(96, 96),
				Corner = Theme.Corner.Medium,
			}),
			label(
				1,
				Text.T(scope, "dungeon.reward.title", { boss = if boss then Text.T(scope, boss.nameKey) else "" }),
				Theme.Paper.Heading,
				Theme.TextSize.Large + 2,
				Theme.Fonts.Display
			),
			(if reward.world then worldLines else dungeonLines) :: any,
			extras :: any,
			scope:New("Frame")({
				Name = "Buttons",
				LayoutOrder = 11,
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
				BackgroundTransparency = 1,
				[Children] = buttons :: any,
			}),
		},
	})
end

return BossReward
