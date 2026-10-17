--!strict
-- After-fight table (S134f; S60 "Fight summary" grown): one row per party member, the own row in GoldBright.
-- PC: Damage (number and %), Healing, Shields, Taken, Intercepted (only when anyone took over blows), Deaths, Dodged
-- (dodged / aimed). Phone (`Compact`): Damage %, Healing, Taken, Deaths. Rows of the S60 shape (no numbers) show
-- the share only. `MaxVisible` rows before the body scrolls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local FightView = require(script.Parent.Parent.FightView)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Row = FightView.Row

export type Props = {
	Rows: { Row },
	Compact: boolean?,
	MaxVisible: number?,
	LayoutOrder: number?,
	RowHeight: number?,
	Surface: Theme.SurfaceName?, -- S136: "paper" (default; reward card, fight log) or "iron" (the HUD card)
}

type Column = { key: string, width: number, value: (row: Row) -> string }

local function pct(row: Row): string
	return `{math.floor(row.d * 100 + 0.5)}%`
end

local function count(value: number?): string
	return Format.number(math.floor(value or 0))
end

local COL_DAMAGE: Column = {
	key = "fight.col.damage",
	width = 0.18,
	value = function(row)
		return if row.a then `{Format.short(row.a)} ({pct(row)})` else pct(row)
	end,
}
local COL_SHARE: Column = { key = "fight.col.damage", width = 0.18, value = pct }
local COL_HEAL: Column = {
	key = "fight.col.healing",
	width = 0.12,
	value = function(row)
		return count(row.h)
	end,
}
local COL_SHIELD: Column = {
	key = "fight.col.shields",
	width = 0.11,
	value = function(row)
		return count(row.s)
	end,
}
local COL_TAKEN: Column = {
	key = "fight.col.taken",
	width = 0.12,
	value = function(row)
		return if row.t then count(row.t) else "-"
	end,
}
local COL_INTERCEPT: Column = {
	key = "fight.col.intercepted",
	width = 0.11,
	value = function(row)
		return count(row.i)
	end,
}
local COL_DEATHS: Column = {
	key = "fight.col.deaths",
	width = 0.08,
	value = function(row)
		return if row.x then count(row.x) else "-"
	end,
}
local COL_DODGED: Column = {
	key = "fight.col.dodged",
	width = 0.08,
	value = function(row)
		if row.w and row.w > 0 then
			return `{count(row.v)}/{count(row.w)}`
		end
		return if row.v then count(row.v) else "-"
	end,
}

local function columnsFor(rows: { Row }, compact: boolean): { Column }
	if compact then
		return { COL_SHARE, COL_HEAL, COL_TAKEN, COL_DEATHS }
	end
	local intercept = false
	for _, row in rows do
		if (row.i or 0) > 0 then
			intercept = true
		end
	end
	local list = { COL_DAMAGE, COL_HEAL, COL_SHIELD, COL_TAKEN }
	if intercept then
		table.insert(list, COL_INTERCEPT)
	end
	table.insert(list, COL_DEATHS)
	table.insert(list, COL_DODGED)
	return list
end

local function FightTable(scope: Scope, props: Props): Instance
	local rows = props.Rows
	local compact = props.Compact == true
	local height = props.RowHeight or 26
	local columns = columnsFor(rows, compact)
	local used = 0
	for _, column in columns do
		used += column.width
	end
	local nameWidth = math.max(0.2, 1 - used)
	local scale = (1 - nameWidth) / used
	local own = State.Get({ "character", "name" })

	local function cell(x: number, width: number, text: Fusion.UsedAs<string>, color: Color3, font: Font, left: boolean)
		return scope:New("TextLabel")({
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromScale(width, 1),
			BackgroundTransparency = 1,
			Text = text,
			FontFace = font,
			TextSize = Theme.TextSize.Small,
			TextColor3 = color,
			TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end

	local function line(
		order: number,
		first: Fusion.UsedAs<string>,
		values: { Fusion.UsedAs<string> },
		color: Color3,
		font: Font
	)
		local cells = { cell(0, nameWidth, first, color, font, true) }
		local x = nameWidth
		for i, column in columns do
			local width = column.width * scale
			table.insert(cells, cell(x, width, values[i], color, font, false))
			x += width
		end
		return scope:New("Frame")({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			[Children] = cells :: any,
		})
	end

	local headers = {}
	for _, column in columns do
		table.insert(headers, Text.T(scope, column.key))
	end
	local roles = Theme.surface(props.Surface)
	local ownColor = if props.Surface == "iron" then Theme.Brass.Bright else roles.Heading
	local header = line(0, Text.T(scope, "dungeon.summary.member"), headers, roles.TextMuted, Theme.Fonts.BodyBold)

	local list: { Instance } = { scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }) }
	for i, row in rows do
		local class = if row.c then Classes.get(row.c) else nil
		local color = if row.n == own then ownColor else roles.Text
		local values = {}
		for _, column in columns do
			table.insert(values, column.value(row))
		end
		table.insert(
			list,
			line(i, if class then `{class.icon} {row.n}` else row.n, values, color, Theme.Fonts.BodyMedium)
		)
	end

	local maxVisible = props.MaxVisible
	local body: Instance
	if maxVisible and #rows > maxVisible then
		body = scope:New("ScrollingFrame")({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, height * maxVisible),
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
		Name = "FightTable",
		LayoutOrder = props.LayoutOrder,
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

return FightTable
