--!strict
-- Rankings window (S124, DESIGN-17 §5): the tabs of Data/Leaderboards.tabs (a column on the left on PC, a strip on a
-- phone), a class filter, the top of the chosen board (Logic/Leaderboard.boardFor) in a scrolling table, the player's
-- own line and when the board was read. Data comes from LeaderboardGet (the server keeps a 5-minute cache), asked when
-- the board changes and every Config.Leaderboard.clientPoll s while the window is open; no "refresh" button (it would
-- change nothing). "This server only" when the shared stores are unavailable (DESIGN-17 §0.8). Tabs and boards of later
-- sessions (S125+) show up from the data alone.
-- S125: the "This week" tab (a bracket switch instead of the class filter, the countdown to the new week, the rewards,
-- the own EXP and the winners of the week before) and the "Guilds" tab (tag and name, members, the sum of levels, the
-- own guild). Narrow state branches only (expWeek, level), never the whole character.
-- S126: the "Arena" tab (filter "arenaBracket": the arena brackets of Data/Arena, this season's board of each; the
-- rating and the level in the columns; the own rank and rating; the end of the season in the footer).
-- 2026-10-21 (owner: too many descriptions): the week's rewards are one short line; the full rewards (This week) and
-- the rule of the Hall of Fame sit behind an "i" next to the board's title (Components/InfoLine, built once).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Device = require(script.Parent.Parent.Device)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoLine = require(script.Parent.Parent.Components.InfoLine)
local Leaderboard = require(ReplicatedStorage.Shared.Logic.Leaderboard)
local Leaderboards = require(ReplicatedStorage.Shared.Data.Leaderboards)
local Net = require(ReplicatedStorage.Shared.Net)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local Section = require(script.Parent.Parent.Components.Section)
local SideTabs = require(script.Parent.Parent.Components.SideTabs)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)
local WorldLayout = require(ReplicatedStorage.Shared.Logic.WorldLayout)

local Children = Fusion.Children
local peek = Fusion.peek

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use

-- The touch tab strip and the filter strip are Tabs with Scroll: their buttons are the strip - 6 (scroll bar 4 + 2) =
-- MinTouch tall (WorldLayout.rankings: strip and filter 50). INFO: a footer line (the week's countdown, the player's
-- line, the update time).
local INFO = 22
local ALL = "all" -- the filter value of the board without a class

-- S136: `medal` draws the cell as an iron plaque with a bright digit (places 1-3: gold is not readable as text on
-- parchment).
type Cell = { text: string, width: number?, color: Color3?, bold: boolean?, rich: boolean?, medal: Color3? }

local function sortedTabs(): { Leaderboards.TabDef }
	local list = table.clone(Leaderboards.tabs)
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

local function tabById(id: string): Leaderboards.TabDef?
	for _, tab in Leaderboards.tabs do
		if tab.id == id then
			return tab
		end
	end
	return nil
end

-- Filter values of a tab: "all" when it has a board without a class, then the classes with a board; S125 the bracket
-- indexes of the weekly board ("1".."4").
local function filterValues(tab: Leaderboards.TabDef): { string }
	local out = {}
	if tab.filter == "bracket" then
		for i in Leaderboards.WEEK_BRACKETS do
			table.insert(out, tostring(i))
		end
		return out
	end
	if tab.filter == "arenaBracket" then
		-- S126: the arena bracket ids ("20_39" ...)
		for _, b in Arena.BRACKETS do
			table.insert(out, b.id)
		end
		return out
	end
	if tab.filter ~= "class" then
		return out
	end
	if Leaderboard.boardFor(tab, nil) then
		table.insert(out, ALL)
	end
	for _, class in Classes.order do
		if Leaderboard.boardFor(tab, class) then
			table.insert(out, class)
		end
	end
	return out
end

local function boardOf(tab: Leaderboards.TabDef, filter: string, now: number): string?
	if tab.filter == "bracket" or tab.filter == "arenaBracket" then
		-- S125: this week's board of the bracket (the server clock with the /time offset, like the server)
		return Leaderboard.boardFor(tab, filter, now)
	end
	local id = Leaderboard.boardFor(tab, if filter == ALL then nil else filter)
	if not id then
		return nil
	end
	local def = Leaderboards.get(id)
	if def and def.parts then
		-- S125+: boards with parts (week, season) are read for the current period
		return Leaderboard.instanceId(def, Leaderboard.partsAt(def, Workspace:GetServerTimeNow()))
	end
	return id
end

local function escape(text: string): string
	return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

-- S136: the medal colour of places 1-3 (Data/UiPalette.medal, contrast-tested on iron), nil below.
local function medalColor(rank: number): Color3?
	if rank == 1 then
		return Theme.Medal.Gold
	elseif rank == 2 then
		return Theme.Medal.Silver
	elseif rank == 3 then
		return Theme.Medal.Bronze
	end
	return nil
end

local function line(scope: Scope, cells: { Cell }, height: number, order: number, background: Color3?): Instance
	local fixed = 0
	for _, cell in cells do
		fixed += cell.width or 0
	end
	local children: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	}
	if background then
		table.insert(children, scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }))
	end
	for i, cell in cells do
		if cell.medal then
			table.insert(
				children,
				scope:New("Frame")({
					LayoutOrder = i,
					Size = UDim2.new(0, cell.width or 44, 1, 0),
					BackgroundTransparency = 1,
					[Children] = scope:New("TextLabel")({
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(36, 26),
						BackgroundColor3 = Theme.Iron.Raised,
						Text = cell.text,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = cell.medal,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							scope:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = cell.medal,
								Thickness = Theme.Stroke.Thin,
							}),
						},
					}),
				})
			)
			continue
		end
		table.insert(
			children,
			scope:New("TextLabel")({
				LayoutOrder = i,
				Size = if cell.width then UDim2.new(0, cell.width, 1, 0) else UDim2.new(1, -(fixed + 16), 1, 0),
				BackgroundTransparency = 1,
				Text = cell.text,
				RichText = cell.rich == true,
				FontFace = if cell.bold then Theme.Fonts.BodyBold else Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = cell.color or Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		)
	end
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = background or Theme.Paper.Surface,
		BackgroundTransparency = if background then 0 else 1,
		[Children] = children,
	})
end

local function headerCells(use: Use, format: string, touch: boolean): { Cell }
	local muted = Theme.Paper.TextMuted
	if format == "guild" then
		-- S125: place, guild, members, score
		return {
			{ text = Text.get(use, "leaderboard.col.rank"), width = if touch then 44 else 56, color = muted },
			{ text = Text.get(use, "leaderboard.col.guild"), color = muted },
			-- S159g: the guild level (not part of the score)
			{ text = Text.get(use, "leaderboard.col.guildLevel"), width = if touch then 56 else 90, color = muted },
			{ text = Text.get(use, "leaderboard.col.members"), width = if touch then 90 else 120, color = muted },
			{ text = Text.get(use, "leaderboard.col.score"), width = if touch then 80 else 120, color = muted },
		}
	elseif format == "int" or format == "rating" or format == "time" then
		-- S125: place, name, (class, guild on PC), level, EXP; S126: the arena rating in the last column; S156 time
		local cells: { Cell } = {
			{ text = Text.get(use, "leaderboard.col.rank"), width = if touch then 44 else 56, color = muted },
			{ text = Text.get(use, "leaderboard.col.name"), color = muted },
		}
		if not touch then
			table.insert(cells, { text = Text.get(use, "leaderboard.col.class"), width = 150, color = muted })
			table.insert(cells, { text = Text.get(use, "leaderboard.col.guild"), width = 110, color = muted })
		end
		table.insert(
			cells,
			{ text = Text.get(use, "leaderboard.col.level"), width = if touch then 56 else 80, color = muted }
		)
		table.insert(cells, {
			text = Text.get(
				use,
				if format == "rating"
					then "leaderboard.col.rating"
					elseif format == "time" then "leaderboard.col.time"
					else "leaderboard.col.exp"
			),
			width = if touch then 100 else 130,
			color = muted,
		})
		return cells
	end
	local cells: { Cell } = {
		{ text = Text.get(use, "leaderboard.col.rank"), width = if touch then 44 else 56, color = muted },
		{ text = Text.get(use, "leaderboard.col.name"), color = muted },
		{ text = Text.get(use, "leaderboard.col.class"), width = if touch then 110 else 150, color = muted },
	}
	if format == "date" then
		table.insert(cells, { text = Text.get(use, "leaderboard.col.reached"), width = 150, color = muted })
		return cells
	end
	if not touch then
		table.insert(cells, { text = Text.get(use, "leaderboard.col.guild"), width = 110, color = muted })
	end
	table.insert(
		cells,
		{ text = Text.get(use, "leaderboard.col.level"), width = if touch then 110 else 130, color = muted }
	)
	return cells
end

-- S156: minutes in the world as "12 h 05 min" (under an hour "37 min").
local function playtime(use: Use, minutes: number): string
	local m = math.max(0, math.floor(minutes))
	if m < 60 then
		return Text.get(use, "leaderboard.time.m", { m = m })
	end
	return Text.get(use, "leaderboard.time.hm", { h = Format.number(m // 60), m = string.format("%02d", m % 60) })
end

local function rowCells(use: Use, row: Leaderboard.Row, format: string, touch: boolean): { Cell }
	local top = row.r <= 3
	local medal = medalColor(row.r)
	local color = Theme.Paper.Text
	local name = if row.n == "" then Text.get(use, "leaderboard.unknown") else row.n
	local nameText = escape(name)
	if format == "guild" then
		-- S125: "[TAG] Name", members, the decoded sum of levels
		local tag = if row.g then `<font color="{Theme.hex(Theme.Paper.TextMuted)}">[{escape(row.g)}]</font> ` else ""
		return {
			{ text = tostring(row.r), width = if touch then 44 else 56, color = color, bold = top, medal = medal },
			{ text = tag .. nameText, color = color, bold = top, rich = true },
			{ text = if row.v then tostring(row.v) else "", width = if touch then 56 else 90 },
			{ text = if row.m then Format.number(row.m) else "", width = if touch then 90 else 120 },
			{ text = Format.number(row.s), width = if touch then 80 else 120, bold = top },
		}
	elseif format == "int" or format == "rating" or format == "time" then
		-- S125: weekly EXP; S126: the arena rating; S156: minutes in the world
		if touch and row.g then
			nameText ..= ` <font size="{Theme.TextSize.Small}" color="{Theme.hex(Theme.Paper.TextMuted)}">[{escape(
				row.g
			)}]</font>`
		end
		local cells: { Cell } = {
			{ text = tostring(row.r), width = if touch then 44 else 56, color = color, bold = top, medal = medal },
			{ text = nameText, color = color, bold = top, rich = true },
		}
		if not touch then
			local class = if row.c and string.sub(row.c, 1, 1) == "@" then Text.get(use, string.sub(row.c, 2)) else ""
			table.insert(cells, { text = class, width = 150 })
			table.insert(
				cells,
				{ text = if row.g then `[{row.g}]` else "", width = 110, color = Theme.Paper.TextMuted }
			)
		end
		table.insert(cells, { text = if row.l then tostring(row.l) else "", width = if touch then 56 else 80 })
		local score = if format == "time" then playtime(use, row.s) else Format.number(row.s)
		table.insert(cells, { text = score, width = if touch then 100 else 130, bold = top })
		return cells
	end
	if touch and row.g then
		nameText ..= ` <font size="{Theme.TextSize.Small}" color="{Theme.hex(Theme.Paper.TextMuted)}">[{escape(row.g)}]</font>`
	end
	local class = if row.c and string.sub(row.c, 1, 1) == "@" then Text.get(use, string.sub(row.c, 2)) else ""
	local cells: { Cell } = {
		{ text = tostring(row.r), width = if touch then 44 else 56, color = color, bold = top, medal = medal },
		{ text = nameText, color = color, bold = top, rich = true },
		{ text = class, width = if touch then 110 else 150 },
	}
	if format == "date" then
		local parts = Leaderboard.dateParts(row.at or row.s)
		table.insert(cells, { text = Text.get(use, "leaderboard.date", parts), width = 150 })
		return cells
	end
	if not touch then
		table.insert(cells, { text = if row.g then `[{row.g}]` else "", width = 110, color = Theme.Paper.TextMuted })
	end
	local level = if row.p
		then Text.get(use, "leaderboard.levelPct", { level = row.l or 1, pct = row.p })
		else tostring(row.l or row.s)
	table.insert(cells, { text = level, width = if touch then 110 else 130, bold = top })
	return cells
end

-- S156: the score of a row as one short text (the podium cards).
local function scoreText(use: Use, row: Leaderboard.Row, format: string): string
	if format == "time" then
		return playtime(use, row.s)
	elseif format == "level" then
		return Text.get(use, "leaderboard.podium.level", { level = row.l or row.s })
	elseif format == "rating" then
		return Text.get(use, "leaderboard.podium.rating", { rating = Format.number(row.s) })
	elseif format == "int" then
		return Text.get(use, "leaderboard.podium.exp", { exp = Format.number(row.s) })
	end
	return Format.number(row.s)
end

-- S156 (owner 2026-10-20: "make the rankings nicer"): the first three as a podium above the table, the winner in the
-- middle and highest, each card on iron with its medal colour.
-- Owner 2026-11-10 ("bardzo dużo napisów, niektóre rzeczy zasłaniają inne"; UI plan E, L10): the chrome heights come from
-- Logic/WorldLayout.rankings. The podium is a Section in the rows (rankPodium: open on PC, folded on a phone). A phone
-- steps through the filter with one button beside the tabs, and its footer keeps only the player's line: the countdown
-- and the update time go behind the title's (i). So a phone shows at least two rows under the folded podium.
-- Review 2026-11-10: the window is 720 tall (RankingsController), so PC shows five rows under the open podium; the
-- weekly rewards line is one line of WorldLayout's height, and a phone leaves it out.
local PODIUM = { 2, 1, 3 }
local PODIUM_HEIGHT = { 0.82, 1, 0.7 }
local function podium(
	scope: Scope,
	use: Use,
	rows: { Leaderboard.Row },
	format: string,
	touch: boolean,
	room: number
): Instance
	local cards: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	}
	for slot, rank in PODIUM do
		local row = rows[rank]
		if not row then
			continue
		end
		local medal = medalColor(rank) or Theme.Iron.Text
		local name = if row.n == "" then Text.get(use, "leaderboard.unknown") else row.n
		if format == "guild" and row.g then
			name = `[{row.g}] {name}`
		end
		local class = if row.c and string.sub(row.c, 1, 1) == "@" then Text.get(use, string.sub(row.c, 2)) else ""
		table.insert(
			cards,
			scope:New("Frame")({
				LayoutOrder = slot,
				Size = UDim2.new(0.3, 0, PODIUM_HEIGHT[slot], -4),
				BackgroundColor3 = if row.mine then Theme.Iron.Selected else Theme.Iron.Raised,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = medal,
						Thickness = if rank == 1 then Theme.Stroke.Thick else Theme.Stroke.Normal,
					}),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
					}),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					scope:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, if rank == 1 then 34 else 28),
						BackgroundTransparency = 1,
						Text = tostring(rank),
						FontFace = Theme.Fonts.Display,
						TextSize = if rank == 1 then Theme.TextSize.Title else Theme.TextSize.Large,
						TextColor3 = medal,
					}),
					scope:New("TextLabel")({
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundTransparency = 1,
						Text = name,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = if touch then Theme.TextSize.Small else Theme.TextSize.Body,
						TextColor3 = Theme.Iron.Text,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					scope:New("TextLabel")({
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						Text = if class ~= "" and not touch
							then `{class}  ·  {scoreText(use, row, format)}`
							else scoreText(use, row, format),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Caption,
						TextColor3 = Theme.Iron.TextMuted,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
				},
			})
		)
	end
	return scope:New("Frame")({
		Name = "Podium",
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, room),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIPadding")({ PaddingBottom = UDim.new(0, 8) }),
			scope:New("Frame")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[Children] = cards,
			}),
		},
	})
end

local function freeCells(use: Use, rank: number, touch: boolean): { Cell }
	local muted = Theme.Paper.TextMuted
	return {
		{ text = tostring(rank), width = if touch then 44 else 56, color = muted },
		{ text = Text.get(use, "leaderboard.hof.free"), color = muted },
		{ text = "", width = if touch then 110 else 150 },
		{ text = "", width = 150 },
	}
end

-- The label of a filter value. Owner 2026-11-10 (tabs at most 12 characters): a level bracket is its bare range,
-- "40–59"; S126: an arena bracket its levels.
local function filterLabel(use: Use, tab: Leaderboards.TabDef, value: string): string
	if tab.filter == "bracket" then
		return Leaderboard.bracketLabel(tonumber(value) or 1)
	elseif tab.filter == "arenaBracket" then
		local b = Arena.bracket(value)
		return if b then `{b.min}–{b.max}` else "?"
	elseif value == ALL then
		return Text.get(use, "leaderboard.filter.all")
	end
	return Text.get(use, `class.{value}.name`)
end

-- The player's line under the table.
local function meText(use: Use, snap: Leaderboard.Snapshot): string
	local me = snap.me
	if not me then
		return ""
	end
	if me.hidden then
		return Text.get(use, "leaderboard.meHidden")
	end
	if snap.format == "date" then
		if me.r then
			return Text.get(use, "leaderboard.hof.mine", { n = me.r })
		end
		return Text.get(use, "leaderboard.hof.left", { n = me.left or 0 })
	end
	if snap.format == "guild" then
		-- S125
		if me.none then
			return Text.get(use, "leaderboard.guild.none")
		end
		if me.r then
			return Text.get(use, "leaderboard.guild.yours", { rank = me.r, score = Format.number(me.s or 0) })
		end
		return Text.get(use, "leaderboard.guild.outside", { score = Format.number(me.s or 0) })
	end
	if snap.format == "rating" then
		-- S126: the own arena rank and rating, or the arena's minimum level
		if me.below then
			return Text.get(use, "arena.bracket.none", { level = me.below })
		end
		if me.r then
			return Text.get(use, "leaderboard.arena.you", { rank = me.r, rating = me.s or 0 })
		end
		return Text.get(use, "leaderboard.arena.outside", { rating = me.s or 0 })
	end
	if snap.format == "time" then
		-- S156: the own place and time in the world
		if me.below then
			return Text.get(use, "leaderboard.meBelow", { level = me.below })
		end
		local time = playtime(use, me.s or 0)
		return if me.r
			then Text.get(use, "leaderboard.time.you", { rank = me.r, time = time })
			else Text.get(use, "leaderboard.time.outside", { time = time })
	end
	if snap.format == "int" then
		-- S125: the week's EXP, and the own bracket when another one is shown
		local exp = Format.number(me.s or 0)
		local text = if me.r
			then Text.get(use, "leaderboard.week.you", { rank = me.r, exp = exp })
			else Text.get(use, "leaderboard.week.outside", { exp = exp })
		local _, parts = Leaderboard.resolve(snap.id)
		local shown = tonumber(parts and parts[2])
		if me.b and shown and me.b ~= shown then
			text ..= "  ·  " .. Text.get(
				use,
				"leaderboard.week.otherBracket",
				{ bracket = Leaderboard.bracketLabel(me.b) }
			)
		end
		return text
	end
	if me.below then
		return Text.get(use, "leaderboard.meBelow", { level = me.below })
	end
	if me.r then
		return Text.get(use, "leaderboard.me", { rank = me.r })
	end
	if me.l then
		return Text.get(use, "leaderboard.meOutside", { level = me.l, pct = me.p or 100 })
	end
	return ""
end

local function RankingsWindow(scope: Scope, _props: {}?): Fusion.Child
	local touch = Device.Touch
	local compact = PhoneLayout.Compact
	local tabs = sortedTabs()
	local myClass = State.Value({ "character", "class" })
	local myLevel = State.Value({ "character", "level" })
	local selected = scope:Value(if tabs[1] then tabs[1].id else "")
	local filter = scope:Value(ALL)
	local snapshots = scope:Value({} :: { [string]: Leaderboard.Snapshot })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local asked: { [string]: number } = {}
	local alive = true
	table.insert(scope, function()
		alive = false
	end)

	-- The default filter of a tab: "all" when the tab has it, else the active character's class (Hall of Fame).
	local function resetFilter(tabId: string)
		local tab = tabById(tabId)
		if not tab then
			return
		end
		local values = filterValues(tab)
		if tab.filter == "bracket" then
			-- S125: the bracket of the active character
			local level = peek(myLevel)
			filter:set(tostring(Leaderboard.bracketOf(if type(level) == "number" then level else 1)))
		elseif tab.filter == "arenaBracket" then
			-- S126: the arena bracket of the active character (the lowest one below the arena level)
			local level = peek(myLevel)
			filter:set(ArenaRules.bracketOf(if type(level) == "number" then level else 1) or values[1])
		elseif table.find(values, ALL) then
			filter:set(ALL)
		else
			local class = peek(myClass)
			filter:set(if type(class) == "string" and table.find(values, class) then class else values[1] or ALL)
		end
	end
	resetFilter(peek(selected))

	-- S125: `clock` follows the server clock with the /time offset (the week board changes at Monday 00:00 UTC)
	local clock = scope:Value(Clock.now())
	local current = scope:Computed(function(use): string?
		local tab = tabById(use(selected))
		return if tab then boardOf(tab, use(filter), use(clock)) else nil
	end)

	local function load(id: string?, force: boolean?)
		if not id then
			return
		end
		local last = asked[id]
		if not force and last and os.clock() - last < Config.Leaderboard.clientPoll then
			return
		end
		asked[id] = os.clock()
		task.spawn(function()
			local ok, data = Net.Invoke("LeaderboardGet", id)
			if not alive then
				return
			end
			if ok and type(data) == "table" then
				local copy = table.clone(peek(snapshots))
				copy[id] = data :: any
				snapshots:set(copy)
				if data.loading then
					-- the server's first read is still running: ask again soon
					asked[id] = os.clock() - Config.Leaderboard.clientPoll + 5
				end
			else
				-- refused (rate limit) or failed: the next poll tick or selecting the board again asks at once
				asked[id] = nil
				Sounds.play("error")
				Toast.push(Text.now(if type(data) == "string" then data else "error.internal"), "error")
			end
		end)
	end

	scope:Observer(selected):onChange(function()
		resetFilter(peek(selected))
	end)
	scope:Observer(current):onBind(function()
		load(peek(current))
	end)
	task.spawn(function()
		local elapsed = 0
		while alive do
			task.wait(5)
			if not alive then
				break
			end
			now:set(Workspace:GetServerTimeNow())
			clock:set(Clock.now())
			elapsed += 5
			local id = peek(current)
			if elapsed >= Config.Leaderboard.clientPoll then
				elapsed = 0
				load(id, true)
			elseif id then
				-- no snapshot yet (a failed call) or the server's first read still running: `asked` gates the retry
				local snap = peek(snapshots)[id]
				if snap == nil or snap.loading then
					load(id)
				end
			end
		end
	end)

	local snapshot = scope:Computed(function(use): Leaderboard.Snapshot?
		local id = use(current)
		return if id then use(snapshots)[id] else nil
	end)

	local tabList = {}
	for _, tab in tabs do
		table.insert(tabList, { id = tab.id, label = Text.T(scope, tab.nameKey) })
	end

	-- S125: the countdown to the new week, or how the guild score is counted; empty for the other boards
	local infoText = scope:Computed(function(use): string
		local id = use(current)
		local def = if id then Leaderboard.resolve(id) else nil
		if def and def.id == "exp_week" then
			local d, h, m = Time.split(Leaderboard.weekEndsIn(use(clock)))
			return Text.get(use, "leaderboard.week.resetIn", { d = d, h = h, m = m })
		elseif def and def.format == "guild" then
			return Text.get(use, "leaderboard.guild.hint", { n = Config.Leaderboard.guildTop })
		elseif def and def.format == "rating" then
			-- S126: the end of the arena season
			local season = ArenaRules.seasonOf(use(clock))
			local d, h = Time.split(ArenaRules.seasonEndsAt(season) - use(clock))
			return Text.get(use, "arena.season.ends", { time = Text.get(use, "arena.time.dh", { d = d, h = h }) })
		end
		return ""
	end)
	-- 2026-10-21: what the board's "i" explains: the week's rewards, or the rule of the Hall of Fame; "" = no "i"
	local titleInfo = scope:Computed(function(use): string
		local id = use(current)
		local def = if id then Leaderboard.resolve(id) else nil
		if def and def.id == "exp_week" then
			local rewards = Leaderboards.WEEK_REWARDS
			return Text.get(use, "leaderboard.week.rewards", {
				title = Text.get(use, "title." .. rewards.title),
				days = rewards.titleDays,
				first = rewards.shards[1],
				second = rewards.shards[2],
				third = rewards.shards[3],
			})
		elseif def and def.format == "date" then
			return Text.get(use, "leaderboard.hof.hint", { n = Leaderboards.HOF_SIZE, level = Config.MaxLevel })
		end
		return ""
	end)
	local hasFilter = scope:Computed(function(use): boolean
		local tab = tabById(use(selected))
		return tab ~= nil and #filterValues(tab) > 1
	end)
	-- Logic/WorldLayout: the chrome of this device (the rows fill the rest), and the weekly board's rewards line
	local layout = scope:Computed(function(use): WorldLayout.Rankings
		local device: WorldLayout.Device = WorldLayout.device(use(touch) == true, use(compact))
		local id = use(current)
		local def = if id then Leaderboard.resolve(id) else nil
		local week = def ~= nil and def.id == "exp_week"
		return WorldLayout.rankings(WorldLayout.CHROME, device, use(hasFilter), use(infoText) ~= "", week)
	end)
	-- When the board was read, and the warning of a board of this server only (rich text).
	local updated = scope:Computed(function(use): string
		local snap = use(snapshot)
		if not snap or snap.loading then
			return ""
		end
		local age = use(now) - snap.at
		local text = if age < 60
			then Text.get(use, "leaderboard.updatedNow")
			else Text.get(use, "leaderboard.updated", { time = Format.time(age) })
		if snap.mode == "local" then
			local warning = Theme.Paper.Warning:ToHex()
			return `{escape(text)}   <font color="#{warning}">⚠ {escape(Text.get(use, "leaderboard.local"))}</font>`
		end
		return escape(text)
	end)
	-- What the title's (i) explains: the board's rule; a phone adds the countdown and the update time (its footer keeps
	-- only the player's line).
	local info = scope:Computed(function(use): string
		local parts: { string } = {}
		local rule = use(titleInfo)
		if rule ~= "" then
			table.insert(parts, escape(rule))
		end
		if use(layout).footerLines < 2 then
			if use(infoText) ~= "" then
				table.insert(parts, escape(use(infoText)))
			end
			if use(updated) ~= "" then
				table.insert(parts, use(updated))
			end
		end
		return table.concat(parts, "\n\n")
	end)

	local contentPos = scope:Computed(function(use): UDim2
		local l = use(layout)
		return if use(touch) then UDim2.fromOffset(0, l.strip + 8) else UDim2.fromOffset(l.side + 12, 0)
	end)
	local contentSize = scope:Computed(function(use): UDim2
		local l = use(layout)
		return if use(touch) then UDim2.new(1, 0, 1, -(l.strip + 8)) else UDim2.new(1, -(l.side + 12), 1, 0)
	end)

	local filterStrip = scope:Computed(function(use, s: Scope): any
		local tab = tabById(use(selected))
		local values: { string } = if tab then filterValues(tab) else {}
		if #values <= 1 then
			return nil
		end
		local list = {}
		for _, value in values do
			local label = s:Computed(function(use2): string
				return if tab then filterLabel(use2, tab, value) else value
			end)
			list[#list + 1] = { id = value, label = label }
		end
		return Tabs(s, { Tabs = list, Selected = filter, Scroll = true, Size = UDim2.fromScale(1, 1) })
	end)
	-- A phone: one button beside the tabs steps through the filter (the shown value and "▸").
	local filterButton = scope:Computed(function(use, s: Scope): any
		local tab = tabById(use(selected))
		local width = use(layout).filterButton
		if not tab or width <= 0 then
			return nil
		end
		local values = filterValues(tab)
		return Button(s, {
			Name = "FilterButton",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(width, Theme.Size.MinTouch),
			Variant = "secondary",
			TextSize = Theme.TextSize.Small,
			Text = s:Computed(function(use2): string
				return `{filterLabel(use2, tab, use2(filter))} ▸`
			end),
			OnClick = function()
				local i = table.find(values, peek(filter)) or 0
				filter:set(values[i % #values + 1])
			end,
		})
	end)

	local table_ = scope:Computed(function(use, s: Scope): { any }
		local snap = use(snapshot)
		local isTouch = use(touch)
		local id = use(current)
		local def = if id then Leaderboard.resolve(id) else nil
		local format = if snap then snap.format elseif def then def.format else "level"
		local items: { any } = {
			s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
		}
		local l = use(layout)
		local rowHeight = l.list.row
		if l.rewards > 0 then
			-- S125: what the top three of each bracket get (numbers from Data/Leaderboards). Review 2026-11-10: one line
			-- of WorldLayout's height, on PC and a tablet only; a phone keeps its rows (the title's (i) has the rewards).
			local rewards = Leaderboards.WEEK_REWARDS
			table.insert(
				items,
				s:New("TextLabel")({
					LayoutOrder = -1,
					Size = UDim2.new(1, 0, 0, l.rewards),
					BackgroundTransparency = 1,
					Text = Text.get(use, "leaderboard.week.rewards.short", {
						title = Text.get(use, "title." .. rewards.title),
					}),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextYAlignment = Enum.TextYAlignment.Top,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					[Children] = {
						s:New("UIPadding")({
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
							PaddingBottom = UDim.new(0, 6),
						}),
					},
				})
			)
		end
		if not snap or (snap.loading and #snap.rows == 0) then
			table.insert(
				items,
				line(
					s,
					{ { text = Text.get(use, "leaderboard.loading"), color = Theme.Paper.TextMuted } },
					rowHeight,
					1
				)
			)
			return items
		end
		if format ~= "date" and #snap.rows > 0 then
			table.insert(
				items,
				Section.new(s, {
					Id = "rankPodium",
					Title = Text.T(s, "leaderboard.podium"),
					LayoutOrder = 0,
					Children = { podium(s, use, snap.rows, format, isTouch, l.podium) },
				})
			)
		end
		for i, row in snap.rows do
			local background = if row.mine then Theme.Paper.Hover elseif i % 2 == 0 then Theme.Paper.Raised else nil
			table.insert(items, line(s, rowCells(use, row, format, isTouch), rowHeight, i, background))
		end
		if format == "date" then
			local max = if def and def.max then def.max else Leaderboards.HOF_SIZE
			for rank = #snap.rows + 1, max do
				table.insert(items, line(s, freeCells(use, rank, isTouch), rowHeight, rank))
			end
		elseif #snap.rows == 0 then
			table.insert(
				items,
				line(s, { { text = Text.get(use, "leaderboard.empty"), color = Theme.Paper.TextMuted } }, rowHeight, 1)
			)
		end
		local last = snap.last
		if last and #last.rows > 0 then
			-- S125: the winners of the week before in this bracket
			local base = #snap.rows + 10
			table.insert(
				items,
				line(s, {
					{
						text = Text.get(use, "leaderboard.week.lastWinners"),
						color = Theme.Paper.Heading,
						bold = true,
					},
				}, rowHeight, base)
			)
			for i, row in last.rows do
				table.insert(
					items,
					line(s, rowCells(use, row, "int", isTouch), rowHeight, base + i, Theme.Paper.Raised)
				)
			end
		end
		return items
	end)

	local footerHeight = scope:Computed(function(use): number
		return use(layout).footer
	end)

	return {
		-- PC: the tab column on the left.
		scope:New("Frame")({
			Name = "SideTabsHolder",
			Size = scope:Computed(function(use): UDim2
				return UDim2.new(0, use(layout).side, 1, 0)
			end),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return not use(touch)
			end),
			[Children] = {
				SideTabs(scope, { Tabs = tabList, Selected = selected, Size = UDim2.fromScale(1, 1) }),
			},
		}),
		-- Phone: the tabs as a strip at the top (a phone's filter button at its right).
		scope:New("Frame")({
			Name = "TabStripHolder",
			Size = scope:Computed(function(use): UDim2
				local l = use(layout)
				return UDim2.new(1, if l.filterButton > 0 then -(l.filterButton + 8) else 0, 0, l.strip)
			end),
			BackgroundTransparency = 1,
			Visible = touch,
			[Children] = {
				Tabs(scope, { Tabs = tabList, Selected = selected, Scroll = true, Size = UDim2.fromScale(1, 1) }),
			},
		}),
		scope:New("Frame")({
			Name = "FilterButtonHolder",
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			Visible = touch,
			[Children] = filterButton :: any,
		}),
		scope:New("Frame")({
			Name = "Board",
			Position = contentPos,
			Size = contentSize,
			BackgroundTransparency = 1,
			[Children] = {
				InfoLine.new(scope, {
					Name = "Title",
					Size = scope:Computed(function(use): UDim2
						return UDim2.new(1, 0, 0, use(layout).title)
					end),
					Text = scope:Computed(function(use): string
						local id = use(current)
						local def = if id then Leaderboard.resolve(id) else nil
						return if def then Text.get(use, def.nameKey) else ""
					end),
					Info = info,
					InfoVisible = scope:Computed(function(use): boolean
						return use(info) ~= ""
					end),
					Font = Theme.Fonts.Display,
					TextSize = Theme.TextSize.Large,
					Color = Theme.Paper.Heading,
				}),
				scope:New("Frame")({
					Name = "Filter",
					Position = scope:Computed(function(use): UDim2
						return UDim2.fromOffset(0, use(layout).title + 4)
					end),
					Size = scope:Computed(function(use): UDim2
						return UDim2.new(1, 0, 0, use(layout).filter)
					end),
					Visible = scope:Computed(function(use): boolean
						return use(layout).filter > 0
					end),
					BackgroundTransparency = 1,
					[Children] = filterStrip :: any,
				}),
				scope:New("Frame")({
					Name = "Head",
					Position = scope:Computed(function(use): UDim2
						return UDim2.fromOffset(0, use(layout).headTop)
					end),
					Size = scope:Computed(function(use): UDim2
						return UDim2.new(1, -8, 0, use(layout).head)
					end),
					BackgroundTransparency = 1,
					[Children] = scope:Computed(function(use, s: Scope): any
						local snap = use(snapshot)
						local id = use(current)
						local def = if id then Leaderboard.resolve(id) else nil
						local format = if snap then snap.format elseif def then def.format else "level"
						return line(s, headerCells(use, format, use(touch)), use(layout).head, 1)
					end) :: any,
				}),
				scope:New("ScrollingFrame")({
					Name = "Rows",
					Position = scope:Computed(function(use): UDim2
						return UDim2.fromOffset(0, use(layout).list.top)
					end),
					Size = scope:Computed(function(use): UDim2
						local l = use(layout)
						return UDim2.new(1, 0, 1, -(l.list.top + l.footer + 2))
					end),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 6,
					ScrollBarImageColor3 = Theme.Paper.Rule,
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					[Children] = table_ :: any,
				}),
				scope:New("Frame")({
					Name = "Footer",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = scope:Computed(function(use): UDim2
						return UDim2.new(1, 0, 0, use(footerHeight))
					end),
					BackgroundTransparency = 1,
					[Children] = {
						scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
						scope:New("TextLabel")({
							LayoutOrder = 0,
							Size = UDim2.new(1, 0, 0, INFO),
							BackgroundTransparency = 1,
							Visible = scope:Computed(function(use): boolean
								return use(infoText) ~= "" and use(layout).footerLines >= 3
							end),
							Text = infoText,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.Heading,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						scope:New("TextLabel")({
							LayoutOrder = 1,
							Size = UDim2.new(1, 0, 0, INFO),
							BackgroundTransparency = 1,
							Text = scope:Computed(function(use): string
								local snap = use(snapshot)
								if not snap then
									return ""
								end
								return meText(use, snap)
							end),
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						scope:New("TextLabel")({
							LayoutOrder = 2,
							Size = UDim2.new(1, 0, 0, INFO),
							BackgroundTransparency = 1,
							Visible = scope:Computed(function(use): boolean
								return use(layout).footerLines >= 2
							end),
							RichText = true,
							Text = updated,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
					},
				}),
			},
		}),
	}
end

return RankingsWindow
