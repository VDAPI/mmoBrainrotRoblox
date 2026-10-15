--!strict
-- The "Tournament" tab of the arena window (S130, DESIGN-17 §8). Without a bracket on this server: the date (Saturday,
-- UTC and the player's own time), the phase with its next moment and a countdown, the player's bracket (or the level
-- needed), "Sign up" / "Withdraw" (only in the signup phase; otherwise off with the phase's hint), the count of the
-- signed in the bracket out of the cap with the threshold of a full list, "this server only" in the local mode, the
-- rewards from Data/Arena.TOURNEY, the character's tournaments and the Champions of Vaelthorn (TourneyInfo.hall). With
-- a bracket here (`tourney.live`): the player's state, the bracket (ArenaWindow/TourneyBracket) and the way out. PC: two
-- columns; a phone: one column in the window's scrolling frame, buttons 44 px.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local Tourney = require(ReplicatedStorage.Shared.Logic.Tourney)
local TourneyBracket = require(script.Parent.TourneyBracket)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use

export type Props = {
	Info: Fusion.UsedAs<any>, -- the last TourneyInfo answer
	Sign: (sign: boolean) -> (),
	Leave: () -> (),
	ErrorText: (key: string) -> string,
}

local RULES = Arena.TOURNEY

local function clockOf(t: number, utc: boolean): string
	local d = os.date(if utc then "!*t" else "*t", math.floor(t))
	return string.format("%02d:%02d", d.hour, d.min)
end

-- "18:50 UTC (20:50)": the UTC time and the player's own.
local function both(t: number): string
	return `{clockOf(t, true)} UTC ({clockOf(t, false)})`
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

local function placeText(use: Use, place: number): string
	local key, args = Tourney.placeKey(place)
	return Text.get(use, key, args)
end

-- "DD.MM.YYYY" of a tournament id ("YYYYMMDD"); the id itself when it is not a date.
local function dateOf(use: Use, id: string): string
	local y, m, d = string.match(id, "^(%d%d%d%d)(%d%d)(%d%d)$")
	if not y then
		return id
	end
	return Text.get(use, "leaderboard.date", { d = d, m = m, y = y })
end

local function TourneyTab(scope: Scope, props: Props): Instance
	local tourney = State.Value({ "tourney" })
	local level = State.Value({ "character", "level" })
	local mine = State.Value({ "character", "tourney" })
	local slot = State.Value({ "session", "slot" })
	local touch = Device.Touch
	local now = scope:Value(Clock.now())
	local acc = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc >= 1 then
				acc = 0
				now:set(Clock.now())
			end
		end)
	)
	local cardSize = scope:Computed(function(use): UDim2
		return if use(touch) then UDim2.fromScale(1, 0) else UDim2.new(0.5, -6, 0, 0)
	end)
	local myKey = scope:Computed(function(use): string?
		local s = use(slot)
		return if s ~= nil then `{Players.LocalPlayer.UserId}_{s}` else nil
	end)
	local live = scope:Computed(function(use): any
		local t = use(tourney)
		return if type(t) == "table" and type(t.live) == "table" then t.live else nil
	end)
	local hasLive = scope:Computed(function(use): boolean
		return use(live) ~= nil
	end)

	-- Signups ---------------------------------------------------------------------------------------------------------
	-- Three parts, so the per-second countdown never rebuilds the button (a click across a rebuild is lost): the head
	-- (date, phase, countdown, bracket) on `now`, the Sign up / Withdraw button built once, the tail (count, list) without
	-- the clock.
	local headBody = scope:Computed(function(use, s: Scope): any
		local t = use(tourney)
		local lvl = tonumber(use(level)) or 0
		local items: { any } =
			{ s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) }
		local order = 0
		local function add(child: Instance)
			order += 1
			(child :: any).LayoutOrder = order
			table.insert(items, child)
		end
		local clock = use(now)
		local phase: Tourney.Phase, startAt = Tourney.phaseAt(clock)
		if type(t) == "table" and type(t.phase) == "string" and tonumber(t.startAt) then
			phase, startAt = t.phase :: Tourney.Phase, tonumber(t.startAt) :: number
		end
		local times = Tourney.times(startAt)
		add(label(s, 0, Text.get(use, "tourney.desc"), nil, Theme.Colors.Parchment))
		add(
			label(
				s,
				0,
				Text.get(use, "tourney.when", { utc = clockOf(startAt, true), ["local"] = clockOf(startAt, false) }),
				Theme.TextSize.Body,
				Theme.Colors.GoldBright,
				Theme.Fonts.BodyBold
			)
		)
		local at = if phase == "idle"
			then times.open
			elseif phase == "signup" then times.close
			elseif phase == "closed" then times.organize
			else nil
		add(label(s, 0, Text.get(use, `tourney.phase.{phase}`, { time = if at then both(at) else "" })))
		if type(t) ~= "table" or not t.test then
			add(
				label(
					s,
					0,
					Text.get(use, "tourney.nextIn", { time = Time.format(Tourney.phaseEnds(phase, startAt) - clock) }),
					nil,
					Theme.Colors.TextMuted
				)
			)
		end
		if type(t) == "table" and t.server ~= nil and t.server ~= "world" then
			add(label(s, 0, Text.get(use, "tourney.worldOnly"), nil, Theme.Colors.Warning))
			return items
		end
		local bracket = Tourney.bracketOf(lvl)
		if not bracket then
			add(
				label(
					s,
					0,
					Text.get(use, "tourney.error.level", { level = Arena.MIN_LEVEL }),
					nil,
					Theme.Colors.Warning
				)
			)
			return items
		end
		local signed = if type(t) == "table" and type(t.signed) == "table" then t.signed else nil
		add(
			label(
				s,
				0,
				Text.get(
					use,
					"tourney.bracket",
					{ range = Tourney.rangeOf(if signed then signed.bracket else bracket) }
				)
			)
		)
		return items
	end)
	-- a world server and a bracket for the level: the button and the tail show
	local signable = scope:Computed(function(use): boolean
		local t = use(tourney)
		if type(t) == "table" and t.server ~= nil and t.server ~= "world" then
			return false
		end
		return Tourney.bracketOf(tonumber(use(level)) or 0) ~= nil
	end)
	local signedNow = scope:Computed(function(use): any
		local t = use(tourney)
		return if type(t) == "table" and type(t.signed) == "table" then t.signed else nil
	end)
	local signOpen = scope:Computed(function(use): boolean
		local t = use(tourney)
		if type(t) == "table" and type(t.phase) == "string" and tonumber(t.startAt) then
			return t.phase == "signup"
		end
		local phase = Tourney.phaseAt(use(now))
		return phase == "signup"
	end)
	local signButton = Button(scope, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
		Visible = signable,
		Variant = scope:Computed(function(use): any
			return if use(signedNow) then "secondary" else "primary"
		end),
		Disabled = scope:Computed(function(use): boolean
			return not use(signOpen)
		end),
		Text = scope:Computed(function(use): string
			return Text.get(use, if use(signedNow) then "tourney.unsign" else "tourney.signup")
		end),
		OnClick = function()
			props.Sign(Fusion.peek(signedNow) == nil)
		end,
	})
	local tailBody = scope:Computed(function(use, s: Scope): any
		local info = use(props.Info)
		local items: { any } =
			{ s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) }
		if not use(signable) then
			return items
		end
		local order = 0
		local function add(child: Instance)
			order += 1
			(child :: any).LayoutOrder = order
			table.insert(items, child)
		end
		local signed = use(signedNow)
		local range =
			Tourney.rangeOf(if signed then signed.bracket else Tourney.bracketOf(tonumber(use(level)) or 0) :: string)
		if signed then
			add(
				label(
					s,
					0,
					Text.get(use, "tourney.signed", { range = range }),
					nil,
					Theme.Colors.Success,
					Theme.Fonts.BodyBold
				)
			)
		end
		if type(info) == "table" then
			if type(info.count) == "number" then
				add(label(s, 0, Text.get(use, "tourney.count", { range = range, n = info.count, cap = RULES.cap })))
				if info.count > RULES.cap and type(info.overflowRating) == "number" then
					add(
						label(
							s,
							0,
							Text.get(use, "tourney.overflow", { rating = info.rating or 0, min = info.overflowRating }),
							nil,
							Theme.Colors.Warning
						)
					)
				end
			end
			if info.mode == "local" then
				add(label(s, 0, Text.get(use, "tourney.local"), nil, Theme.Colors.Warning))
			end
		end
		return items
	end)
	local function part(order: number, body: any): Instance
		return scope:New("Frame")({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = body,
		})
	end
	local signupBody: { any } = {
		scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		part(1, headBody :: any),
		signButton,
		part(3, tailBody :: any),
	}

	-- Rewards and the character's tournaments ---------------------------------------------------------------------------
	local rewardsBody = scope:Computed(function(use, s: Scope): any
		local items: { any } =
			{ s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) }
		local function cosmeticName(id: string?): string
			local def = if id then Cosmetics.get(id) else nil
			return if def then Text.get(use, def.nameKey) else ""
		end
		local function swatch(order: number, id: string?, text: string): Instance
			local def = if id then Cosmetics.get(id) else nil
			return s:New("Frame")({
				LayoutOrder = order,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					s:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.fromOffset(28, 28),
						BackgroundColor3 = if def then Color3.fromHex(def.color) else Theme.Colors.Panel,
						Text = if def then def.icon else "◆",
						TextSize = 18,
						TextColor3 = Theme.Colors.Text,
						FontFace = Theme.Fonts.Body,
						[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					}),
					s:New("TextLabel")({
						LayoutOrder = 2,
						Size = UDim2.new(1, -36, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Text = text,
						TextWrapped = true,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			})
		end
		for i, r in RULES.rewards do
			local cosmetic = if r.cosmetics then r.cosmetics[1] else nil
			local title = if r.title then TitleData.get(r.title) else nil
			local text: string
			if r.place == 1 then
				text = Text.get(use, "tourney.rewards.champion", {
					title = if title then Text.get(use, title.nameKey) else "",
					days = r.titleDays or 0,
					aura = cosmeticName(cosmetic),
					shards = r.shards or 0,
				})
			elseif r.place == 2 then
				text = Text.get(
					use,
					"tourney.rewards.finalist",
					{ frame = cosmeticName(cosmetic), shards = r.shards or 0 }
				)
			else
				text = Text.get(use, "tourney.rewards.semi", { shards = r.shards or 0 })
			end
			table.insert(items, swatch(i, cosmetic, text))
		end
		table.insert(items, label(s, 10, Text.get(use, "tourney.rewards.all", { tokens = RULES.participantTokens })))
		local st = use(mine)
		local played = if type(st) == "table" then tonumber(st.played) or 0 else 0
		local won = if type(st) == "table" then tonumber(st.won) or 0 else 0
		local best = if type(st) == "table" then tonumber(st.best) or 0 else 0
		table.insert(
			items,
			label(
				s,
				11,
				Text.get(use, "tourney.stats", {
					played = played,
					won = won,
					best = if best > 0 then placeText(use, best) else "—",
				}),
				nil,
				Theme.Colors.Parchment,
				Theme.Fonts.BodyMedium
			)
		)
		return items
	end)

	-- The Champions of Vaelthorn ---------------------------------------------------------------------------------------
	local hallBody = scope:Computed(function(use, s: Scope): any
		local info = use(props.Info)
		local hall = if type(info) == "table" and type(info.hall) == "table" then info.hall else {}
		local isTouch = use(touch)
		local items: { any } = {
			s:New("UIListLayout")({
				FillDirection = if isTouch then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
		}
		for i, b in Arena.BRACKETS do
			local list = hall[b.id]
			local rows: { any } = {
				s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
				label(s, 0, `{b.min}–{b.max}`, Theme.TextSize.Small, Theme.Colors.GoldBright, Theme.Fonts.BodyBold),
			}
			if type(list) ~= "table" or #list == 0 then
				table.insert(rows, label(s, 1, Text.get(use, "tourney.hall.empty"), 14, Theme.Colors.TextMuted))
			else
				for n, row in list do
					local className = Text.get(use, `class.{row.class}.name`)
					table.insert(
						rows,
						label(
							s,
							n,
							`{dateOf(use, row.id)} · {row.name} ({className})`,
							14,
							if n == 1 then Theme.Colors.GoldBright else Theme.Colors.Text,
							if n == 1 then Theme.Fonts.BodyBold else Theme.Fonts.Body
						)
					)
				end
			end
			table.insert(
				items,
				s:New("Frame")({
					LayoutOrder = i,
					Size = if isTouch then UDim2.fromScale(1, 0) else UDim2.new(0.25, -6, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = rows,
				})
			)
		end
		return items
	end)

	-- A bracket on this server ------------------------------------------------------------------------------------------
	local liveBody = scope:Computed(function(use, s: Scope): any
		local l = use(live)
		use(now) -- the return countdown
		local items: { any } =
			{ s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) }
		if not l then
			return items
		end
		local me = if type(l.me) == "table" then l.me else {}
		local status: string
		if me.state == "fighting" then
			status = Text.get(use, "tourney.called", { field = me.field or 1 })
		elseif me.state == "waiting" then
			status = Text.get(use, "tourney.waiting")
		elseif me.state == "out" then
			status = Text.get(use, "tourney.out", { place = placeText(use, me.place or 0) })
		elseif me.state == "champion" then
			status = Text.get(use, "tourney.youChampion")
		else
			status = Text.get(use, "tourney.spectating")
		end
		table.insert(
			items,
			label(
				s,
				1,
				`{Text.get(use, "tourney.title")} · {l.range}`,
				Theme.TextSize.Body,
				Theme.Colors.GoldBright,
				Theme.Fonts.Heading
			)
		)
		table.insert(items, label(s, 2, status, Theme.TextSize.Body, Theme.Colors.Text, Theme.Fonts.BodyBold))
		if tonumber(l.endsAt) then
			table.insert(
				items,
				label(
					s,
					3,
					Text.get(
						use,
						"tourney.ending",
						{ s = math.max(0, math.ceil(l.endsAt - workspace:GetServerTimeNow())) }
					),
					nil,
					Theme.Colors.Warning
				)
			)
		end
		return items
	end)

	return scope:New("Frame")({
		Name = "Tourney",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }),
			-- no bracket here: the signups, the rewards, the champions
			scope:New("Frame")({
				Name = "Top",
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(hasLive)
				end),
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 12),
						FillDirection = scope:Computed(function(use): Enum.FillDirection
							return if use(touch) then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
						end),
					}),
					card(
						scope,
						1,
						"tourney.title",
						cardSize,
						scope:New("Frame")({
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							LayoutOrder = 1,
							[Children] = signupBody :: any,
						})
					),
					card(
						scope,
						2,
						"tourney.rewards.title",
						cardSize,
						scope:New("Frame")({
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							LayoutOrder = 1,
							[Children] = rewardsBody :: any,
						})
					),
				},
			}),
			scope:New("Frame")({
				Name = "Hall",
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(hasLive)
				end),
				[Children] = card(
					scope,
					1,
					"tourney.hall",
					UDim2.fromScale(1, 0),
					scope:New("Frame")({
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						LayoutOrder = 1,
						[Children] = hallBody :: any,
					})
				),
			}),
			-- a bracket here
			scope:New("Frame")({
				Name = "Live",
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = hasLive,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
					scope:New("Frame")({
						LayoutOrder = 1,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						[Children] = liveBody :: any,
					}),
					TourneyBracket(scope, {
						Live = live,
						MyKey = myKey,
						LayoutOrder = 2,
						Height = scope:Computed(function(use): number
							return if use(touch) then 300 else 400
						end),
					}),
					Button(scope, {
						LayoutOrder = 3,
						Size = UDim2.fromOffset(260, Theme.Size.MinTouch),
						Variant = "danger",
						Text = Text.T(scope, "tourney.leave"),
						OnClick = props.Leave,
					}),
				},
			}),
		},
	})
end

return TourneyTab
