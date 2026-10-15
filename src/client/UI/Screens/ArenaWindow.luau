--!strict
-- The arena window (S126, DESIGN-17 §6): "Your arena" (tier sign, rating, tier, the way to the next tier, bracket,
-- season and its end, the season's numbers, the last season), "Queue" (the rules of each enabled mode, the scope "this
-- server", who waits in the own bracket, join / leave with the time in the queue or the reason it is closed, the fight
-- on the sand with "Watch") and "Recent matches" (character.arena.history). On a PC the first two stand side by side,
-- on a phone everything is one scrolling column. It reads `character.arena`, `arenaLive` and the window's status
-- (ArenaController.Status); the reason a button is off is Logic/ArenaRules.canQueue on the same state as the server.
-- S130 may add a "Tournament" part here or turn this file into a folder ArenaWindow/ (the window id stays "arena").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local ServerModeView = require(script.Parent.Parent.ServerModeView)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use

export type Props = {
	Status: Fusion.UsedAs<any>,
	Join: (mode: string) -> (),
	Leave: () -> (),
	Spectate: () -> (),
	ErrorText: (key: string) -> string,
}

-- Tier colours and sign (client only; Data/Arena holds the numbers).
local TIER_COLORS: { [string]: Color3 } = {
	bronze = Color3.fromHex("#A8703A"),
	silver = Color3.fromHex("#B8BCC4"),
	gold = Color3.fromHex("#D4A537"),
	diamond = Color3.fromHex("#5EC8E6"),
	master = Color3.fromHex("#B04AE0"),
}
local TIER_SIGN = "◆"
local ROW = 30

local function tierColor(id: string): Color3
	return TIER_COLORS[id] or Theme.Colors.Text
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
		TextColor3 = color or Theme.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function card(s: Scope, order: number, titleKey: string, size: Fusion.UsedAs<UDim2>, body: any): Instance
	return s:New("Frame")({
		LayoutOrder = order,
		Size = size,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.PanelRaised,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			s:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 1 }),
			s:New("UIPadding")({
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			label(s, 0, Text.T(s, titleKey), Theme.TextSize.Body, Theme.Colors.Gold, Theme.Fonts.Heading),
			body,
		},
	})
end

local function ArenaWindow(scope: Scope, props: Props): Fusion.Child
	local state = State.Value({ "character", "arena" })
	local level = State.Value({ "character", "level" })
	local live = State.Value({ "arenaLive" })
	local zone = State.Value({ "zone" })
	local death = State.Value({ "death" })
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
		local rating = tonumber(a.rating) or Arena.ELO.start
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
				Theme.Colors.Parchment,
				Theme.Fonts.Heading
			)
		)
		table.insert(
			items,
			label(
				s,
				2,
				`{Text.get(use, `arena.tier.{tier}`)} · {Text.get(use, "arena.stats.rating")}`,
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
				BackgroundColor3 = Theme.Colors.Panel,
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
				Theme.Colors.TextMuted
			)
		)
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
		local d, h = Time.split(ArenaRules.seasonEndsAt(season) - use(clock))
		table.insert(items, label(s, 6, Text.get(use, "arena.season", { name = seasonName(use, season) })))
		table.insert(
			items,
			label(
				s,
				7,
				Text.get(use, "arena.season.ends", { time = Text.get(use, "arena.time.dh", { d = d, h = h }) }),
				nil,
				Theme.Colors.TextMuted
			)
		)
		-- the numbers of this season (a state from the month before shows zeros until the server rolls it)
		local current = a.season == season or a.season == ""
		local wins = if current then a.wins else 0
		local losses = if current then a.losses else 0
		local played = if current then a.played else 0
		local peak = if current then a.peak else rating
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
					Theme.Colors.TextMuted
				)
			)
		end
		return items
	end)

	-- Queue ------------------------------------------------------------------------------------------------------------
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

	local queueBody = scope:Computed(function(use, s: Scope): any
		local items: { any } = {}
		local l = use(liveValue)
		local status = use(props.Status :: any)
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		for _, mode in ArenaRules.enabledModes() do
			table.insert(
				items,
				label(
					s,
					nextOrder(),
					Text.get(use, `arena.rules.{mode.id}`, {
						wins = mode.winsNeeded,
						time = Time.format(mode.roundTime),
						potions = mode.potions,
						elixir = Text.get(use, "item.potion_full.name"),
					}),
					nil,
					Theme.Colors.Parchment
				)
			)
		end
		-- S127: the scope of the queue: all servers (MemoryStore), or this server only (Studio, the link down) with why
		local bracket = ArenaRules.bracketOf(use(myLevel))
		local q = l.queue
		local scopeId = if type(q) == "table" and type(q.scope) == "string"
			then q.scope
			elseif type(status) == "table" and type(status.scope) == "string" then status.scope
			else "local"
		local global = scopeId == "global"
		table.insert(
			items,
			label(
				s,
				nextOrder(),
				Text.get(use, if global then "arena.scope.global" else "arena.scope.local"),
				nil,
				Theme.Colors.Gold
			)
		)
		if not global then
			table.insert(
				items,
				label(s, nextOrder(), Text.get(use, "arena.net.scope.localHint"), nil, Theme.Colors.TextMuted)
			)
		end
		local waiting: number? = nil
		if type(q) == "table" and type(q.waiting) == "number" then
			waiting = q.waiting
		elseif not global and bracket and type(status) == "table" and type(status.waiting) == "table" then
			waiting = tonumber(status.waiting[bracket])
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
				label(s, nextOrder(), Text.get(use, "arena.net.waitingLocal"), nil, Theme.Colors.TextMuted)
			)
		end
		for _, mode in ArenaRules.enabledModes() do
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
						Theme.Colors.Success,
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
			else
				local reason = reasonFor(use, mode.id)
				table.insert(
					items,
					Button(s, {
						LayoutOrder = nextOrder(),
						Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
						Variant = "primary",
						Disabled = reason ~= nil,
						Text = Text.get(use, "arena.join", { mode = mode.id }),
						OnClick = function()
							props.Join(mode.id)
						end,
					})
				)
				if reason then
					use(now) -- the penalty countdown ticks
					table.insert(items, label(s, nextOrder(), props.ErrorText(reason), nil, Theme.Colors.Warning))
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
					Theme.Colors.Parchment,
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
				label(s, nextOrder(), Text.get(use, "arena.pending", { n = pending }), nil, Theme.Colors.TextMuted)
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
			return { label(s, 1, Text.get(use, "arena.history.empty"), nil, Theme.Colors.TextMuted) }
		end
		local items: { any } = {
			s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
		}
		local t = use(clock)
		for i, entry in list do
			local glyph, color = "=", Theme.Colors.TextMuted
			if entry.score >= 1 then
				glyph, color = "✓", Theme.Colors.Success
			elseif entry.score <= 0 then
				glyph, color = "✗", Theme.Colors.Danger
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
					BackgroundColor3 = Theme.Colors.Panel,
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
							TextColor3 = Theme.Colors.Text,
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
							TextColor3 = Theme.Colors.Parchment,
						}),
						s:New("TextLabel")({
							LayoutOrder = 4,
							Size = UDim2.new(0, deltaWidth, 1, 0),
							BackgroundTransparency = 1,
							Text = delta,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if not entry.rated
								then Theme.Colors.TextMuted
								elseif entry.delta >= 0 then Theme.Colors.Success
								else Theme.Colors.Danger,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							LayoutOrder = 5,
							Size = UDim2.new(0, agoWidth, 1, 0),
							BackgroundTransparency = 1,
							Text = agoText(use, t - entry.t),
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Colors.TextMuted,
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
					Theme.Colors.TextMuted
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

	return scope:New("ScrollingFrame")({
		Name = "Arena",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Border,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
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
					card(scope, 1, "arena.section.mine", cardSize, mine :: any),
					card(scope, 2, "arena.section.queue", cardSize, queueBody :: any),
				},
			}),
			card(scope, 2, "arena.history", UDim2.fromScale(1, 0), historyBody :: any),
		},
	})
end

return ArenaWindow
