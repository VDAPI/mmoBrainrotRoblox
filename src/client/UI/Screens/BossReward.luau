--!strict
-- Post-fight reward card (S30, DESIGN §16): shown to each winner after a boss kill, under the victory message.
-- EXP and gold, whether the winner's one item (in their own bag) is a Legendary / Mythic, today's runs of this
-- boss ("Dziś: 2/3") with the time to the UTC reset, and the chances for the next kill, which grow with every kill
-- that day (FIX 2026-10-09). "OK" closes it; it also closes by itself after a while.
-- S60: the party's Fortune (Legendary multiplier, an ennobled item, a second item) only when it counted, and the
-- "Fight summary" table: damage share, healing and shields of every member. On short screens the card sits in the
-- middle and the table scrolls after 4 rows. S61: an "Intercepted" column when anyone took over blows from allies.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossScaling = require(ReplicatedStorage.Shared.Logic.BossScaling)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GroupLuck = require(script.Parent.Parent.GroupLuck)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Scale = require(script.Parent.Parent.Scale)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

-- n = name, c = class, d = damage share 0..1, h = healing, s = shields (S61 adds the taken-damage column).
export type SummaryRow = { n: string, c: string?, d: number, h: number, s: number, i: number? }

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
}

export type Props = {
	Reward: Reward,
	Close: () -> (),
}

local function percent(value: number?): number
	return math.floor((tonumber(value) or 0) * 100 + 0.5)
end

local SUMMARY_ROW = 26
local SUMMARY_VISIBLE = 4 -- rows before the table scrolls on short screens
local COLUMNS = { 0.40, 0.20, 0.20, 0.20 }
local COLUMNS_INTERCEPT = { 0.32, 0.17, 0.17, 0.17, 0.17 } -- S61: with the "Intercepted" column

local function cell(
	scope: Scope,
	columns: { number },
	column: number,
	text: string,
	color: Color3,
	font: Font
): Instance
	local x = 0
	for i = 1, column - 1 do
		x += columns[i]
	end
	return scope:New("TextLabel")({
		Position = UDim2.fromScale(x, 0),
		Size = UDim2.fromScale(columns[column], 1),
		BackgroundTransparency = 1,
		Text = text,
		FontFace = font,
		TextSize = Theme.TextSize.Small,
		TextColor3 = color,
		TextXAlignment = if column == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

-- The fight summary: a header and one row per member (own row in GoldBright).
local function summaryTable(scope: Scope, rows: { SummaryRow }, compact: boolean): Instance
	local own = State.Get({ "character", "name" })
	local intercept = false
	for _, row in rows do
		if (row.i or 0) > 0 then
			intercept = true
		end
	end
	local columns = if intercept then COLUMNS_INTERCEPT else COLUMNS
	local muted, bold = Theme.Colors.TextMuted, Theme.Fonts.BodyBold
	local headerCells: { Instance } = {
		cell(scope, columns, 1, Text.now("dungeon.summary.member"), muted, bold),
		cell(scope, columns, 2, Text.now("dungeon.summary.damage"), muted, bold),
		cell(scope, columns, 3, Text.now("dungeon.summary.healing"), muted, bold),
		cell(scope, columns, 4, Text.now("dungeon.summary.shields"), muted, bold),
	}
	if intercept then
		table.insert(headerCells, cell(scope, columns, 5, Text.now("dungeon.summary.intercepted"), muted, bold))
	end
	local header = scope:New("Frame")({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, SUMMARY_ROW),
		BackgroundTransparency = 1,
		[Children] = headerCells :: any,
	})
	local lines: { Instance } = {}
	for i, row in rows do
		local class = if row.c then Classes.get(row.c) else nil
		local color = if row.n == own then Theme.Colors.GoldBright else Theme.Colors.Parchment
		local name = if class then `{class.icon} {row.n}` else row.n
		local font = Theme.Fonts.BodyMedium
		local cells: { Instance } = {
			cell(scope, columns, 1, name, color, font),
			cell(scope, columns, 2, `{math.floor(row.d * 100 + 0.5)}%`, color, font),
			cell(scope, columns, 3, Format.number(row.h), color, font),
			cell(scope, columns, 4, Format.number(row.s), color, font),
		}
		if intercept then
			table.insert(cells, cell(scope, columns, 5, Format.number(row.i or 0), color, font))
		end
		table.insert(
			lines,
			scope:New("Frame")({
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, SUMMARY_ROW),
				BackgroundTransparency = 1,
				[Children] = cells :: any,
			})
		)
	end
	local list = { scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }) :: Instance }
	for _, line in lines do
		table.insert(list, line)
	end
	local body: Instance
	if compact and #rows > SUMMARY_VISIBLE then
		body = scope:New("ScrollingFrame")({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, SUMMARY_ROW * SUMMARY_VISIBLE),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			[Children] = list :: any,
		})
	else
		body = scope:New("Frame")({
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = list :: any,
		})
	end
	return scope:New("Frame")({
		LayoutOrder = 10,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
			header,
			body,
		},
	})
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
				Theme.Colors.GoldBright,
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
				Rarities.get(Rarities.HEROIC).color,
				Theme.TextSize.Small,
				Theme.Fonts.BodyBold
			)
		)
	end
	if reward.extra then
		table.insert(
			extras,
			label(8, Text.T(scope, "luck.extra"), Theme.Colors.GoldBright, Theme.TextSize.Small, Theme.Fonts.BodyBold)
		)
	end
	local summary = reward.summary
	if summary and #summary > 0 then
		table.insert(
			extras,
			label(
				9,
				Text.T(scope, "dungeon.summary.title"),
				Theme.Colors.GoldBright,
				Theme.TextSize.Body,
				Theme.Fonts.Heading
			)
		)
		table.insert(extras, summaryTable(scope, summary, compact))
	end

	return scope:New("Frame")({
		Name = "BossReward",
		AnchorPoint = if compact then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 0),
		Position = if compact then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.38),
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
			extras :: any,
			Button(scope, {
				LayoutOrder = 11,
				Text = Text.T(scope, "reveal.ok"),
				Variant = "secondary",
				Size = UDim2.fromOffset(140, Theme.Size.ButtonHeight),
				OnClick = props.Close,
			}),
		},
	})
end

return BossReward
