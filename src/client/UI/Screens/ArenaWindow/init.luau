--!strict
-- The arena window (S126, DESIGN-17 §6): "Your arena" (tier sign, rating, tier, the way to the next tier, bracket,
-- season and its end, the season's numbers, the last season), "Queue" (the rules of each enabled mode, the scope "this
-- server", who waits in the own bracket, join / leave with the time in the queue or the reason it is closed, the fight
-- on the sand with "Watch") and "Recent matches" (character.arena.history). On a PC the first two stand side by side,
-- on a phone everything is one scrolling column. It reads `character.arena`, `arenaLive` and the window's status
-- (ArenaController.Status); the reason a button is off is Logic/ArenaRules.canQueue on the same state as the server.
-- S130: a folder now (ArenaWindow/init); the "Tournament" tab is ArenaWindow/Tourney with its bracket
-- (ArenaWindow/TourneyBracket); the window id stays "arena".
-- S128: the Arena Tokens on top (balance, the week, the daily bonus left), three tabs ("Arena", "Arena shop", "Season
-- rewards"; the Arena Master's "arenashop" opens the shop tab) and a 1 vs 1 / 3 vs 3 switch in the arena tab (the
-- rating, tier and numbers of that mode; 3v3: solo or the party team of three, the reason a button is off from
-- Logic/ArenaRules.canQueue3 on the replicated party). The shop rows come from Data/Arena.SHOP with the server's own
-- check (Logic/ArenaRules.canBuyShop); buying asks first (UI/Components/Modal, ArenaController.Buy).
-- 2026-10-21 (owner: too many descriptions): "Your arena" shows the rating, the tier and the season's end, the rest
-- (bracket, season, the numbers, the last season) is folded (Components/Details); the queue shows the mode's rules in
-- one short line, the full rules sit behind the "i" of the mode switch, the queue's hints (this server only, nobody
-- waiting, solo or team) behind the "i" of the queue's title; the season tab's rule behind the "i" of the own tier.
-- An "i" is never built inside a part rebuilt every second (its popover would close): those parts only get lines.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local CurrencyIcon = require(script.Parent.Parent.Components.CurrencyIcon)
local Details = require(script.Parent.Parent.Components.Details)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoLine = require(script.Parent.Parent.Components.InfoLine)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local ServerModeView = require(script.Parent.Parent.ServerModeView)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local TourneyTab = require(script.Tourney)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use

export type Props = {
	Status: Fusion.UsedAs<any>,
	Join: (mode: string) -> (),
	Leave: () -> (),
	Spectate: () -> (),
	ErrorText: (key: string) -> string,
	-- S128
	Tab: Fusion.Value<string>, -- "main" | "shop" | "season" | "tourney" (S130)
	Mode: Fusion.Value<string>, -- "1v1" | "3v3" (the arena tab)
	AtMaster: Fusion.UsedAs<boolean>, -- opened at the Arena Master (the shop's buttons)
	Buy: (entry: Arena.ArenaShopEntry, name: string) -> (),
	-- S130: the tournament tab
	Tourney: TourneyTab.Props?,
}

-- Tier colours and sign (client only; Data/Arena holds the numbers).
-- S136: the identity colours (Data/UiPalette.league) made readable on parchment
local TIER_COLORS: { [string]: Color3 } = {}
for id, hex in UiPalette.league :: { [string]: string } do
	TIER_COLORS[id] = Theme.readable(hex, "paper")
end
local TIER_SIGN = "◆"
local ROW = 30

local function tierColor(id: string): Color3
	return TIER_COLORS[id] or Theme.Paper.Text
end

local function tierMin(id: string): number
	for _, tier in Arena.TIERS do
		if tier.id == id then
			return tier.min
		end
	end
	return 0
end

-- "listopad 2026" of a season key.
local function seasonName(use: Use, season: string): string
	local year, month = Time.monthLabel(season)
	if not year or not month then
		return "—"
	end
	return Text.get(use, "arena.season.name", { month = Text.get(use, `arena.month.{month}`), year = year })
end

-- The arguments of a mode's rules (arena.rules.<mode> and its short line).
local function rulesArgs(use: Use, mode: Arena.Mode): { [string]: any }
	return {
		wins = mode.winsNeeded,
		time = Time.format(mode.roundTime),
		potions = mode.potions,
		elixir = Text.get(use, "item.potion_full.name"),
	}
end

local function agoText(use: Use, seconds: number): string
	local s = math.max(0, seconds)
	if s < 3600 then
		return Text.get(use, "arena.history.agoMin", { n = math.max(1, math.floor(s / 60)) })
	elseif s < 86400 then
		return Text.get(use, "arena.history.agoH", { n = math.floor(s / 3600) })
	end
	return Text.get(use, "arena.history.agoD", { n = math.floor(s / 86400) })
end

local function label(
	s: Scope,
	order: number,
	text: Fusion.UsedAs<string>,
	size: number?,
	color: Fusion.UsedAs<Color3>?,
	font: Font?
): Instance
	return s:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		RichText = true,
		TextWrapped = true,
		FontFace = font or Theme.Fonts.Body,
		TextSize = size or Theme.TextSize.Small,
		TextColor3 = color or Theme.Paper.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- A titled card; with `info` an "i" after the title holds the card's hints (`info` "" hides it).
local function card(
	s: Scope,
	order: number,
	titleKey: string,
	size: Fusion.UsedAs<UDim2>,
	body: any,
	info: Fusion.UsedAs<string>?
): Instance
	local title = if info
		then InfoLine.new(s, {
			LayoutOrder = 0,
			Text = Text.T(s, titleKey),
			Info = info,
			InfoVisible = s:Computed(function(use): boolean
				return use(info) ~= ""
			end),
			Font = Theme.Fonts.Display,
			TextSize = Theme.TextSize.Body,
			Color = Theme.Paper.Heading,
		})
		else label(s, 0, Text.T(s, titleKey), Theme.TextSize.Body, Theme.Paper.Heading, Theme.Fonts.Display)
	return s:New("Frame")({
		LayoutOrder = order,
		Size = size,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Paper.Raised,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			s:New("UIStroke")({ Color = Theme.Paper.Rule, Thickness = 1 }),
			s:New("UIPadding")({
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			title,
			body,
		},
	})
end

-- S128: the shown name of an arena shop entry (items through Logic/ItemName, cosmetics their name key).
local function shopName(use: Use, entry: Arena.ArenaShopEntry): string
	if entry.kind == "item" then
		local name = ItemText.get(use, entry.id)
		local n = entry.n or 1
		return if n > 1 then Text.get(use, "arena.shop.stack", { name = name, n = n }) else name
	end
	local def = Cosmetics.get(entry.id)
	return if def then Text.get(use, def.nameKey) else entry.id
end

-- S128: the name of a season title of a tier with its season ("Gladiator Złota 11.2026").
local function seasonTitle(use: Use, titleId: string, season: string?): string
	local def = TitleData.get(titleId)
	if not def then
		return titleId
	end
	if season then
		local month, year = ArenaRules.seasonLabel(season)
		return Text.get(
			use,
			def.nameKey,
			{ season = Text.get(use, "arena.season.short", { month = month, year = year }) }
		)
	end
	return Text.get(use, `{def.nameKey}.plain`)
end

local function ArenaWindow(scope: Scope, props: Props): Fusion.Child
	local state = State.Value({ "character", "arena" })
	local level = State.Value({ "character", "level" })
	local live = State.Value({ "arenaLive" })
	local zone = State.Value({ "zone" })
	local death = State.Value({ "death" })
	local party = State.Value({ "party" }) -- S128: the 3v3 team button
	local owned = State.Value({ "account", "cosmetics", "owned" }) -- S128: owned arena cosmetics
	local touch = Device.Touch
	local now = scope:Value(Workspace:GetServerTimeNow())
	local clock = scope:Value(Clock.now())
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(1)
			if alive then
				now:set(Workspace:GetServerTimeNow())
				clock:set(Clock.now())
			end
		end
	end)

	local arena = scope:Computed(function(use): any
		local value = use(state)
		return if type(value) == "table" then value else ArenaRules.emptyState()
	end)
	local liveValue = scope:Computed(function(use): any
		local value = use(live)
		return if type(value) == "table" then value else {}
	end)
	local myLevel = scope:Computed(function(use): number
		local value = use(level)
		return if type(value) == "number" then value else 1
	end)

	local cardSize = scope:Computed(function(use): UDim2
		return if use(touch) then UDim2.fromScale(1, 0) else UDim2.new(0.5, -6, 0, 0)
	end)

	-- Your arena -----------------------------------------------------------------------------------------------------
	local mine = scope:Computed(function(use, s: Scope): any
		local a = use(arena)
		-- S128: the numbers of the chosen mode (Data/Arena Mode fields)
		local m = Arena.MODES[use(props.Mode)] or Arena.MODES["1v1"]
		local rating = tonumber(a[m.ratingField]) or Arena.ELO.start
		local tier = ArenaRules.tierOf(rating)
		local color = tierColor(tier)
		local items: { any } = {}
		table.insert(
			items,
			label(
				s,
				1,
				`<font color="#{color:ToHex()}">{TIER_SIGN}</font> {rating}`,
				Theme.TextSize.Title,
				Theme.Paper.Text,
				Theme.Fonts.Display
			)
		)
		table.insert(
			items,
			label(
				s,
				2,
				`{Text.get(use, `arena.tier.{tier}`)} · {Text.get(
					use,
					if m.id == "3v3" then "arena.stats.rating3" else "arena.stats.rating"
				)}`,
				Theme.TextSize.Body,
				color,
				Theme.Fonts.BodyBold
			)
		)
		local nextTier, missing = ArenaRules.tierProgress(rating)
		local share = 1
		if nextTier then
			local from = tierMin(tier)
			local to = tierMin(nextTier)
			share = if to > from then math.clamp((rating - from) / (to - from), 0, 1) else 1
		end
		table.insert(
			items,
			s:New("Frame")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 10),
				BackgroundColor3 = Theme.Paper.Surface,
				[Children] = {
					s:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					s:New("Frame")({
						Size = UDim2.fromScale(share, 1),
						BackgroundColor3 = color,
						[Children] = { s:New("UICorner")({ CornerRadius = Theme.Corner.Round }) },
					}),
				},
			})
		)
		table.insert(
			items,
			label(
				s,
				4,
				if nextTier
					then Text.get(
						use,
						"arena.tier.next",
						{ n = missing, tier = Text.get(use, `arena.tier.{nextTier}`) }
					)
					else Text.get(use, "arena.tier.top"),
				nil,
				Theme.Paper.TextMuted
			)
		)
		local season = ArenaRules.seasonOf(use(clock))
		local d, h = Time.split(ArenaRules.seasonEndsAt(season) - use(clock))
		table.insert(
			items,
			label(
				s,
				7,
				Text.get(use, "arena.season.ends", { time = Text.get(use, "arena.time.dh", { d = d, h = h }) }),
				nil,
				Theme.Paper.TextMuted
			)
		)
		return items
	end)
	-- 2026-10-21: the bracket, the season, this season's numbers and the last season, folded under "More"
	local function mineDetails(use: Use, s: Scope): { any }
		local a = use(arena)
		local m = Arena.MODES[use(props.Mode)] or Arena.MODES["1v1"]
		local rating = tonumber(a[m.ratingField]) or Arena.ELO.start
		local items: { any } = {}
		local bracket = Arena.bracket(ArenaRules.bracketOf(use(myLevel)) or "")
		table.insert(
			items,
			label(
				s,
				5,
				if bracket
					then Text.get(use, "arena.bracket", { min = bracket.min, max = bracket.max })
					else Text.get(use, "arena.bracket.none", { level = Arena.MIN_LEVEL })
			)
		)
		local season = ArenaRules.seasonOf(use(clock))
		table.insert(items, label(s, 6, Text.get(use, "arena.season", { name = seasonName(use, season) })))
		-- the numbers of this season (a state from the month before shows zeros until the server rolls it)
		local current = a.season == season or a.season == ""
		local wins = if current then tonumber(a[m.winsField]) or 0 else 0
		local losses = if current then tonumber(a[m.lossesField]) or 0 else 0
		local played = if current then tonumber(a[m.playedField]) or 0 else 0
		local peak = if current then tonumber(a[m.peakField]) or rating else rating
		table.insert(
			items,
			label(
				s,
				8,
				`{Text.get(use, "arena.stats.wins")}: <b>{wins}</b>   {Text.get(use, "arena.stats.losses")}: <b>{losses}</b>   {Text.get(
					use,
					"arena.stats.played"
				)}: <b>{played}</b>   {Text.get(use, "arena.stats.peak")}: <b>{peak}</b>`
			)
		)
		local last = a.last
		if type(last) == "table" then
			table.insert(
				items,
				label(
					s,
					9,
					Text.get(use, "arena.lastSeason", {
						name = seasonName(use, last.season),
						tier = Text.get(use, `arena.tier.{ArenaRules.tierOf(last.peak)}`),
						peak = last.peak,
					}),
					nil,
					Theme.Paper.TextMuted
				)
			)
		end
		return items
	end
	local mineMore = Details.new(scope, {
		Key = "arena/mine",
		LayoutOrder = 50,
		Build = function(ds: Scope): any
			return ds:Computed(function(use, s: Scope): any
				return mineDetails(use, s)
			end)
		end,
	})

	-- Queue ------------------------------------------------------------------------------------------------------------
	-- S128: the 3v3 button: solo without a party, the team for the leader of a party of three in one bracket.
	local function team3(use: Use): (string, string?)
		local p = use(party)
		if type(p) ~= "table" or type(p.members) ~= "table" or #p.members == 0 then
			return "arena.queue3.solo", nil
		end
		local bracket: string? = nil
		local same = true
		for _, m in p.members do
			local b = ArenaRules.bracketOf(tonumber(m.level) or 0)
			if bracket == nil then
				bracket = b
			elseif b ~= bracket then
				same = false
			end
		end
		local _, err = ArenaRules.canQueue3({
			inParty = true,
			partySize = #p.members,
			isLeader = p.leader == Players.LocalPlayer.UserId,
			sameBracket = same and bracket ~= nil,
			anyBusy = false, -- the server checks every member
		})
		return "arena.queue3.team", err
	end

	-- Why the join button is off (nil = it is on); the same rule as the server, from the replicated state.
	local function reasonFor(use: Use, mode: string): string?
		if not ServerModeView.isWorld() then
			return "arena.net.error.notHere" -- S127: no queue on an arena server
		end
		local l = use(liveValue)
		local z = use(zone)
		local mapId = if type(z) == "table" then z.map else nil
		local map = if mapId then Maps.get(mapId) else nil
		return ArenaRules.canQueue({
			level = use(myLevel),
			dead = use(death) ~= nil,
			inDungeon = map ~= nil and map.biome == "dungeon",
			inDuel = false, -- the client does not know; the server refuses with arena.error.duel
			inMatch = l.match ~= nil,
			queued = false,
			offered = l.offer ~= nil,
			penaltyUntil = tonumber(l.penaltyUntil),
			now = use(now),
			mode = mode,
		})
	end

	-- S127: the scope of the queue (all servers, or this server only) from the queue entry or the window's status
	local function queueScope(use: Use): string
		local q = use(liveValue).queue
		local status = use(props.Status :: any)
		return if type(q) == "table" and type(q.scope) == "string"
			then q.scope
			elseif type(status) == "table" and type(status.scope) == "string" then status.scope
			else "local"
	end

	-- 2026-10-21: the hints of the queue behind the "i" of its title (built once, so the popover stays open while the
	-- queue ticks): this server only, nobody else waiting, solo or team in 3 vs 3.
	local queueInfo = scope:Computed(function(use): string
		local parts: { string } = {}
		if queueScope(use) ~= "global" then
			table.insert(parts, Text.get(use, "arena.net.scope.localHint"))
		end
		local q = use(liveValue).queue
		if type(q) == "table" and q.waitingLocal == true then
			table.insert(parts, Text.get(use, "arena.net.waitingLocal"))
		end
		if use(props.Mode) == "3v3" then
			table.insert(parts, Text.get(use, "arena.queue3.soloHint"))
		end
		return table.concat(parts, "\n\n")
	end)

	local queueBody = scope:Computed(function(use, s: Scope): any
		local items: { any } = {}
		local l = use(liveValue)
		local status = use(props.Status :: any)
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		local chosen = use(props.Mode)
		for _, mode in ArenaRules.enabledModes() do
			if mode.id ~= chosen then
				continue -- S128: the rules of the chosen mode (2026-10-21: one line, the full rules in the switch's "i")
			end
			table.insert(
				items,
				label(
					s,
					nextOrder(),
					Text.get(use, `arena.rules.{mode.id}.short`, rulesArgs(use, mode)),
					nil,
					Theme.Paper.Text
				)
			)
		end
		-- S127: the scope of the queue: all servers (MemoryStore), or this server only (Studio, the link down) with why
		local bracket = ArenaRules.bracketOf(use(myLevel))
		local q = l.queue
		local global = queueScope(use) == "global"
		table.insert(
			items,
			label(
				s,
				nextOrder(),
				Text.get(use, if global then "arena.scope.global" else "arena.scope.local"),
				nil,
				Theme.Paper.Heading
			)
		)
		local waiting: number? = nil
		local waitingField = if chosen == "3v3" then "waiting3" else "waiting" -- S128
		if type(q) == "table" and q.mode == chosen and type(q.waiting) == "number" then
			waiting = q.waiting
		elseif not global and bracket and type(status) == "table" and type(status[waitingField]) == "table" then
			waiting = tonumber(status[waitingField][bracket])
		end
		if bracket and waiting then
			table.insert(items, label(s, nextOrder(), Text.get(use, "arena.waiting", { n = waiting })))
		elseif type(q) == "table" and type(q.window) == "number" then
			-- the global queue does not know who waits elsewhere: the rating window it searches now
			table.insert(items, label(s, nextOrder(), Text.get(use, "arena.net.window", { n = q.window })))
		end
		if type(q) == "table" and q.waitingLocal == true then
			table.insert(
				items,
				label(s, nextOrder(), Text.get(use, "arena.net.waitingLocal.short"), nil, Theme.Paper.TextMuted)
			)
		end
		for _, mode in ArenaRules.enabledModes() do
			if mode.id ~= chosen then
				continue
			end
			local inThis = type(q) == "table" and q.mode == mode.id
			if inThis then
				table.insert(
					items,
					label(
						s,
						nextOrder(),
						Text.get(
							use,
							"arena.inQueue",
							{ mode = mode.id, time = Time.format(use(now) - (tonumber(q.since) or use(now))) }
						),
						Theme.TextSize.Body,
						Theme.Paper.Success,
						Theme.Fonts.BodyBold
					)
				)
				table.insert(
					items,
					Button(s, {
						LayoutOrder = nextOrder(),
						Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
						Variant = "secondary",
						Text = Text.get(use, "arena.leave"),
						OnClick = props.Leave,
					})
				)
				-- S128: the members of a party team in the queue
				if type(q.members) == "table" and #q.members > 0 then
					local rows = {}
					for _, m in q.members do
						if type(m) == "table" then
							table.insert(
								rows,
								Text.get(use, "arena.queue3.member", {
									name = tostring(m.name),
									class = Text.get(use, `class.{m.class}.name`),
									level = tonumber(m.level) or 0,
								})
							)
						end
					end
					table.insert(
						items,
						label(
							s,
							nextOrder(),
							Text.get(use, "arena.queue3.members", { names = table.concat(rows, ", ") }),
							nil,
							Theme.Paper.Text
						)
					)
				end
			else
				local reason = reasonFor(use, mode.id)
				local joinText = Text.get(use, "arena.join", { mode = mode.id })
				if mode.id == "3v3" then
					local key, err = team3(use)
					joinText = Text.get(use, key)
					reason = reason or err
				end
				table.insert(
					items,
					Button(s, {
						LayoutOrder = nextOrder(),
						Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
						Variant = "primary",
						Disabled = reason ~= nil,
						Text = joinText,
						OnClick = function()
							props.Join(mode.id)
						end,
					})
				)
				if reason then
					use(now) -- the penalty countdown ticks
					table.insert(items, label(s, nextOrder(), props.ErrorText(reason), nil, Theme.Paper.Warning))
				end
			end
		end
		-- the fight on the sand now (a ranked match or a duel) and the spectators' seats
		local busy = if type(status) == "table" then status.busy else nil
		if type(busy) == "table" and type(busy.names) == "table" then
			table.insert(
				items,
				label(
					s,
					nextOrder(),
					Text.get(use, "arena.now", { a = busy.names[1] or "?", b = busy.names[2] or "?" }),
					nil,
					Theme.Paper.Text,
					Theme.Fonts.BodyBold
				)
			)
			table.insert(
				items,
				Button(s, {
					LayoutOrder = nextOrder(),
					Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
					Variant = "secondary",
					Disabled = l.match ~= nil or reasonFor(use, Arena.MODE_ORDER[1]) == "arena.error.dungeon",
					Text = Text.get(use, "arena.spectate"),
					OnClick = props.Spectate,
				})
			)
		end
		local pending = if type(status) == "table" then tonumber(status.pending) else nil
		if pending and pending > 0 then
			table.insert(
				items,
				label(s, nextOrder(), Text.get(use, "arena.pending", { n = pending }), nil, Theme.Paper.TextMuted)
			)
		end
		return items
	end)

	-- Recent matches ------------------------------------------------------------------------------------------------
	local historyBody = scope:Computed(function(use, s: Scope): any
		local a = use(arena)
		local list = if type(a.history) == "table" then a.history else {}
		local isTouch = use(touch)
		if #list == 0 then
			return { label(s, 1, Text.get(use, "arena.history.empty"), nil, Theme.Paper.TextMuted) }
		end
		local items: { any } = {
			s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
		}
		local t = use(clock)
		for i, entry in list do
			local glyph, color = "=", Theme.Paper.TextMuted
			if entry.score >= 1 then
				glyph, color = "✓", Theme.Paper.Success
			elseif entry.score <= 0 then
				glyph, color = "✗", Theme.Paper.Danger
			end
			local className = Text.get(use, `class.{entry.oppClass}.name`)
			local delta = if not entry.rated
				then Text.get(use, "arena.history.unrated")
				elseif entry.delta > 0 then `+{entry.delta}`
				else tostring(entry.delta)
			local deltaWidth = if isTouch then 80 else 110
			local agoWidth = if isTouch then 80 else 120
			table.insert(
				items,
				s:New("Frame")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, ROW),
					BackgroundColor3 = Theme.Paper.Surface,
					BackgroundTransparency = if i % 2 == 0 then 0 else 1,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIPadding")({ PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
						s:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						s:New("TextLabel")({
							LayoutOrder = 1,
							Size = UDim2.new(0, 26, 1, 0),
							BackgroundTransparency = 1,
							Text = glyph,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = color,
						}),
						s:New("TextLabel")({
							LayoutOrder = 2,
							Size = UDim2.new(1, -(26 + 44 + deltaWidth + agoWidth + 12), 1, 0),
							BackgroundTransparency = 1,
							Text = `{entry.opp} ({className})`,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							LayoutOrder = 3,
							Size = UDim2.new(0, 44, 1, 0),
							BackgroundTransparency = 1,
							Text = entry.rounds,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.Text,
						}),
						s:New("TextLabel")({
							LayoutOrder = 4,
							Size = UDim2.new(0, deltaWidth, 1, 0),
							BackgroundTransparency = 1,
							Text = delta,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if not entry.rated
								then Theme.Paper.TextMuted
								elseif entry.delta >= 0 then Theme.Paper.Success
								else Theme.Paper.Danger,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							LayoutOrder = 5,
							Size = UDim2.new(0, agoWidth, 1, 0),
							BackgroundTransparency = 1,
							Text = agoText(use, t - entry.t),
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Right,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
					},
				})
			)
		end
		local unrated = false
		for _, entry in list do
			if not entry.rated then
				unrated = true
			end
		end
		if unrated then
			table.insert(
				items,
				label(
					s,
					#list + 1,
					`{Text.get(use, "arena.history.unrated")}: {Text.get(
						use,
						"arena.history.unratedHint",
						{ n = Arena.LIMITS.sameOpponentDaily }
					)}`,
					nil,
					Theme.Paper.TextMuted
				)
			)
		end
		return {
			s:New("Frame")({
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = items,
			}),
		}
	end)

	-- S128: the Arena Tokens --------------------------------------------------------------------------------------------
	local tokensBar = scope:Computed(function(use, s: Scope): any
		local a = use(arena)
		local t = use(clock)
		local week = ArenaRules.weekTokens(a, t)
		local dailyLeft = math.max(0, Arena.TOKENS.firstMatches - ArenaRules.dailyCount(a, Time.dayNumber(t)))
		local items: { any } = {
			s:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
			}),
			CurrencyIcon(s, { Currency = "token", Size = UDim2.fromOffset(24, 24), LayoutOrder = 1 }),
			s:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, 28),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = `{tonumber(a.tokens) or 0}`,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Paper.Heading,
			}),
			s:New("TextLabel")({
				LayoutOrder = 3,
				Size = UDim2.fromOffset(0, 28),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = `{Text.get(use, "currency.token")} · {Text.get(
					use,
					"arena.tokens.week",
					{ n = week, cap = Arena.tokensWeekCap }
				)}{if dailyLeft > 0
					then " · " .. Text.get(use, "arena.tokens.bonusLeft", { n = dailyLeft })
					else ""}`,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextWrapped = true,
			}),
		}
		return items
	end)

	-- S128: the arena shop -----------------------------------------------------------------------------------------------
	local shopBody = scope:Computed(function(use, s: Scope): any
		local a = use(arena)
		local ownedMap = use(owned)
		local ownedSet: { [string]: boolean } = if type(ownedMap) == "table" then ownedMap else {}
		local char = { level = use(myLevel), arena = a }
		local atMaster = use(props.AtMaster)
		local isTouch = use(touch)
		local items: { any } = {}
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		if not atMaster then
			table.insert(items, label(s, nextOrder(), Text.get(use, "arena.shop.atMaster"), nil, Theme.Paper.Warning))
		end
		for _, group in { "cosmetic", "blessing", "travel" } do
			table.insert(
				items,
				label(
					s,
					nextOrder(),
					Text.get(use, `arena.shop.group.{group}`),
					Theme.TextSize.Body,
					Theme.Paper.Heading,
					Theme.Fonts.Display
				)
			)
			for _, entry in Arena.SHOP do
				if entry.group ~= group then
					continue
				end
				local name = shopName(use, entry)
				local isOwned = entry.kind == "cosmetic" and ownedSet[entry.id] == true
				local ok, err = ArenaRules.canBuyShop(entry, char, ownedSet)
				local icon: any
				if entry.kind == "item" then
					icon = ItemIcon(s, { Def = Items.get(entry.id), Size = UDim2.fromOffset(48, 48), LayoutOrder = 1 })
				else
					local def = Cosmetics.get(entry.id)
					icon = ArtIcon(s, {
						Key = UiArt.cosmetic(entry.id),
						Glyph = if def then def.icon else "?",
						GlyphColor = if def then Theme.readable(def.color, "paper", 3) else Theme.Paper.Text,
						Size = UDim2.fromOffset(48, 48),
						LayoutOrder = 1,
					})
				end
				local priceText = Text.get(use, "arena.shop.price", { price = entry.price })
				local action: any
				if isOwned then
					action = label(s, 4, Text.get(use, "arena.shop.owned"), nil, Theme.Paper.Success)
				else
					action = Button(s, {
						LayoutOrder = 4,
						Size = UDim2.fromOffset(if isTouch then 96 else 120, Theme.Size.MinTouch),
						Variant = "primary",
						Disabled = not ok or not atMaster,
						Text = Text.get(use, "arena.shop.buy"),
						OnClick = function()
							props.Buy(entry, name)
						end,
					})
				end
				local hint = if isOwned then nil elseif not ok and err then props.ErrorText(err) else nil
				table.insert(
					items,
					s:New("Frame")({
						LayoutOrder = nextOrder(),
						Size = UDim2.new(1, 0, 0, 64),
						BackgroundColor3 = Theme.Paper.Surface,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							s:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
							s:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 8),
							}),
							icon,
							s:New("Frame")({
								LayoutOrder = 2,
								Size = UDim2.new(1, -(48 + (if isTouch then 96 else 120) + 110 + 32), 1, 0),
								BackgroundTransparency = 1,
								[Children] = {
									s:New("UIListLayout")({
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Center,
									}),
									label(s, 1, name, Theme.TextSize.Small, Theme.Paper.Text, Theme.Fonts.BodyBold),
									if hint
										then label(s, 2, hint, Theme.TextSize.Small, Theme.Paper.TextMuted)
										else nil :: any,
								} :: any,
							}),
							s:New("TextLabel")({
								LayoutOrder = 3,
								Size = UDim2.fromOffset(110, 40),
								BackgroundTransparency = 1,
								Text = `⚔ {priceText}`,
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Small,
								TextColor3 = Theme.readable(UiPalette.currency.token, "paper"),
								TextXAlignment = Enum.TextXAlignment.Right,
							}),
							action,
						},
					})
				)
			end
		end
		return items
	end)

	-- S128: the season rewards ------------------------------------------------------------------------------------------
	-- The tier the season counts now (the best peak of 1 vs 1 or 3 vs 3; a state from the month before counts the start).
	local function seasonTierOf(a: any, t: number): string
		local current = a.season == ArenaRules.seasonOf(t) or a.season == ""
		local peak = if current then tonumber(a.peak) or Arena.ELO.start else Arena.ELO.start
		local peak3 = if current then tonumber(a.peak3) or Arena.ELO.start else Arena.ELO.start
		return ArenaRules.seasonTier(peak, peak3)
	end
	-- 2026-10-21: the own tier as one short line (built once: its "i" holds where the tier comes from and when the
	-- reward arrives, and stays open while the tab ticks).
	local seasonTierNow = scope:Computed(function(use): string
		return seasonTierOf(use(arena), use(clock))
	end)
	local yourTier = InfoLine.new(scope, {
		LayoutOrder = 0,
		Text = scope:Computed(function(use): string
			return Text.get(
				use,
				"arena.season.yourTier.short",
				{ tier = Text.get(use, `arena.tier.{use(seasonTierNow)}`) }
			)
		end),
		Info = scope:Computed(function(use): string
			local tier = Text.get(use, `arena.tier.{use(seasonTierNow)}`)
			return `{Text.get(use, "arena.season.yourTier", { tier = tier })}\n\n{Text.get(use, "arena.season.howTo")}`
		end),
		Font = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Body,
		Color = scope:Computed(function(use): Color3
			return tierColor(use(seasonTierNow))
		end),
	})
	local seasonBody = scope:Computed(function(use, s: Scope): any
		local a = use(arena)
		local t = use(clock)
		local season = ArenaRules.seasonOf(t)
		local current = a.season == season or a.season == ""
		local played = if current then (tonumber(a.played) or 0) + (tonumber(a.played3) or 0) else 0
		local myTier = seasonTierOf(a, t)
		local items: { any } = {}
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		table.insert(
			items,
			label(
				s,
				nextOrder(),
				Text.get(use, "arena.season.minPlayed", { n = played, min = Arena.seasonMinPlayed }),
				nil,
				if played >= Arena.seasonMinPlayed then Theme.Paper.Success else Theme.Paper.Warning
			)
		)
		local d, h = Time.split(ArenaRules.seasonEndsAt(season) - t)
		table.insert(
			items,
			label(
				s,
				nextOrder(),
				Text.get(use, "arena.season.ends", { time = Text.get(use, "arena.time.dh", { d = d, h = h }) }),
				nil,
				Theme.Paper.TextMuted
			)
		)
		for i, tier in Arena.TIERS do
			local reward = Arena.SEASON_REWARDS[tier.id]
			local nextTier = Arena.TIERS[i + 1]
			local range = if nextTier
				then Text.get(use, "arena.season.range", { min = tier.min, max = nextTier.min - 1 })
				else Text.get(use, "arena.season.rangeTop", { min = tier.min })
			local parts: { string } = {}
			if reward then
				table.insert(parts, seasonTitle(use, reward.title, nil))
				for _, id in (reward.cosmetics or {}) :: { string } do
					local def = Cosmetics.get(id)
					table.insert(parts, if def then Text.get(use, def.nameKey) else id)
				end
				if reward.shards and reward.shards > 0 then
					table.insert(parts, Text.get(use, "arena.season.shards", { n = reward.shards }))
				end
			end
			local mineRow = tier.id == myTier
			table.insert(
				items,
				s:New("Frame")({
					LayoutOrder = nextOrder(),
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = if mineRow then Theme.Paper.Hover else Theme.Paper.Surface,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIStroke")({
							Color = tierColor(tier.id),
							Thickness = if mineRow then 2 else 0,
							Transparency = if mineRow then 0 else 1,
						}),
						s:New("UIPadding")({
							PaddingTop = UDim.new(0, 6),
							PaddingBottom = UDim.new(0, 6),
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
						}),
						s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
						label(
							s,
							1,
							`<font color="#{tierColor(tier.id):ToHex()}">{TIER_SIGN}</font> {Text.get(
								use,
								`arena.tier.{tier.id}`
							)} · {range}`,
							Theme.TextSize.Body,
							Theme.Paper.Text,
							Theme.Fonts.BodyBold
						),
						label(s, 2, table.concat(parts, " · "), nil, Theme.Paper.Text),
					},
				})
			)
		end
		local last = a.last
		if type(last) == "table" and last.rewarded == true then
			local month, year = ArenaRules.seasonLabel(last.season)
			local lastTier = ArenaRules.seasonTier(tonumber(last.peak) or 0, tonumber(last.peak3) or 0)
			table.insert(
				items,
				label(
					s,
					nextOrder(),
					Text.get(use, "arena.season.last", {
						season = Text.get(use, "arena.season.short", { month = month, year = year }),
						tier = Text.get(use, `arena.tier.{lastTier}`),
					}),
					Theme.TextSize.Body,
					Theme.Paper.Heading,
					Theme.Fonts.BodyBold
				)
			)
		end
		return items
	end)

	local function page(id: string, order: number, children: any): Instance
		return scope:New("Frame")({
			Name = id,
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return use(props.Tab) == id
			end),
			[Children] = children,
		})
	end

	local modeSwitch = scope:Computed(function(use, s: Scope): any
		local items: { any } = {
			s:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
			}),
		}
		local chosen = use(props.Mode)
		for i, mode in ArenaRules.enabledModes() do
			table.insert(
				items,
				Button(s, {
					LayoutOrder = i,
					Size = UDim2.fromOffset(140, Theme.Size.MinTouch),
					Variant = if chosen == mode.id then "primary" else "secondary",
					Text = Text.get(use, `arena.mode.{mode.id}`),
					OnClick = function()
						props.Mode:set(mode.id)
					end,
				})
			)
			-- 2026-10-21: the full rules of the chosen mode behind the "i" next to the switch
			if chosen == mode.id then
				table.insert(
					items,
					InfoTip.new(s, {
						LayoutOrder = 100,
						Title = Text.get(use, `arena.mode.{mode.id}`),
						Text = Text.get(use, `arena.rules.{mode.id}`, rulesArgs(use, mode)),
					})
				)
			end
		end
		return items
	end)

	local mainPage = page("main", 3, {
		scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }),
		scope:New("Frame")({
			Name = "Modes",
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
			BackgroundTransparency = 1,
			[Children] = modeSwitch :: any,
		}),
		scope:New("Frame")({
			Name = "Top",
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 12),
					FillDirection = scope:Computed(function(use): Enum.FillDirection
						return if use(touch) then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
					end),
				}),
				card(scope, 1, "arena.section.mine", cardSize, { mine :: any, mineMore }),
				card(scope, 2, "arena.section.queue", cardSize, queueBody :: any, queueInfo),
			},
		}),
		card(scope, 2, "arena.history", UDim2.fromScale(1, 0), historyBody :: any),
	})

	return scope:New("ScrollingFrame")({
		Name = "Arena",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Rule,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
			scope:New("Frame")({
				Name = "Tokens",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 28),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = tokensBar :: any,
			}),
			Tabs(scope, {
				Tabs = {
					{ id = "main", label = Text.T(scope, "arena.tab.main") },
					{ id = "shop", label = Text.T(scope, "arena.shop.title") },
					{ id = "season", label = Text.T(scope, "arena.season.rewards") },
					{ id = "tourney", label = Text.T(scope, "tourney.tab") }, -- S130
				},
				Selected = props.Tab,
				Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
				LayoutOrder = 2,
				Scroll = true,
			}),
			mainPage,
			page("shop", 4, {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				shopBody :: any,
			}),
			page("season", 5, {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
				yourTier,
				seasonBody :: any,
			}),
			-- S130: the Champion's Tournament
			page(
				"tourney",
				6,
				{
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
					(if props.Tourney then TourneyTab(scope, props.Tourney) else nil) :: any,
				} :: any
			),
		},
	})
end

return ArenaWindow
