--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, nothing folds"; UI plan package B): the one door of
-- every message on the client. Toasts, banners (announcements, the achievement, the zone and the area), the boss's
-- alerts, the invitations (Components/Prompt), the cards (better item, fight result, boss reward, legendary loot) and
-- the NPC's barks go into one queue (Logic/NoticeQueue) and stand where Logic/TopBand puts them: the band under the
-- target (owner question 2), a PC card in the empty bottom right corner (question 1), a phone's M zone one message at a
-- time. Only this module draws into the Toasts layer's message host (Toast.mount builds it).
--   combat: 6 s after the character's HP drops or the player attacks (TargetController, read through the check that
--   NotificationController hands over): the quiet messages wait (Logic/NoticeQueue.HOLD);
--   a window open: a message stands over it where it fits, else under its title bar (owner 2026-10-31, question UI 8);
--   the achievement's banner waits for the window to close (docs/UI-ZASADY.md §6);
--   "Szczegóły" of a card opens its full view in the same layer, closed by a tap beside it or after a while.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Components.Button)
local Device = require(script.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudCover = require(script.Parent.HudCover)
local HudZones = require(ReplicatedStorage.Shared.Logic.HudZones)
local NoticeQueue = require(ReplicatedStorage.Shared.Logic.NoticeQueue)
local PhoneLayout = require(script.Parent.PhoneLayout)
local Scale = require(script.Parent.Scale)
local State = require(script.Parent.State)
local Text = require(script.Parent.Text)
local TextCaps = require(ReplicatedStorage.Shared.Logic.TextCaps)
local Theme = require(script.Parent.Theme)
local TopBand = require(ReplicatedStorage.Shared.Logic.TopBand)
local TopBandState = require(script.Parent.TopBandState)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>
type Rect = TopBand.Rect

-- What a message's look gets: its count (×N), whether it stands in a phone's M zone, a way to take it out (an answer,
-- ✕) and to ask for a new layout (its height changed).
export type Live = {
	id: number,
	count: Fusion.Value<number>,
	phone: boolean,
	close: () -> (),
	relayout: () -> (),
}

export type Spec = {
	class: NoticeQueue.Class,
	text: string?, -- what it says (two pushes of the same text within 10 s merge, ×N)
	key: string?, -- the localization key (an error's identity, a world boss's banner)
	tone: string?, -- toast: info | success | warning | error; banner: legendary | mythic | worldboss | achievement ...
	seconds: number?,
	deadline: number?,
	crossServer: boolean?,
	windowWaits: boolean?,
	wait: number?,
	hold: (number | boolean)?,
	w: number?, -- its width in virtual pixels, else its kind's
	h: number?, -- its height, else its kind's
	inset: number?, -- a toast: the text's line is this much narrower than the toast (its drawn "i")
	height: ((phone: boolean) -> number)?, -- its height by device (a prompt that opens 'Więcej ▸')
	build: (scope: Scope, live: Live) -> Instance, -- its look, filling the place Notify gives it
	shown: (() -> ())?, -- once, when it first comes on the screen (the achievement's sound)
	gone: (() -> ())?, -- once, when it leaves (shown or not)
}

export type Handle = { id: number, close: () -> (), alive: () -> boolean }

local Notify = {}

-- Combat lasts this long after the last hit taken or blow struck.
Notify.COMBAT_SECONDS = 6
-- The combat signal is inferred (the client has no combat flag). If it holds too much, set this false: then only the
-- other servers' banners and the better-item card wait in combat (UI plan package B).
Notify.HOLD_ALL = true

local TICK = 0.1
local FADE = 0.18
local MOVE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TOAST_PAD = 10
local LINE = 5 -- a text line is its size plus this

local scope = Fusion.scoped(Fusion)
local queue = NoticeQueue.new("pc", os.clock())
local specs: { [number]: Spec } = {}

type View = {
	scope: Scope,
	frame: Instance,
	place: Fusion.Value<UDim2>,
	size: Fusion.Value<UDim2>,
	alpha: Fusion.Value<number>,
	count: Fusion.Value<number>,
	closing: boolean,
}
local views: { [number]: View } = {}
local host: Frame? = nil
local detailsHost: Frame? = nil
local held: { [string]: number } = {}
local combatUntil = -math.huge
local attackCheck: (() -> boolean)? = nil
local wanted = false

-- Combat signal: the character's HP drops (a hit taken).
local hp = State.Value({ "character", "hp" })
local lastHp: number? = nil
scope:Observer(hp):onChange(function()
	local value = Fusion.peek(hp)
	if type(value) == "number" then
		if lastHp and value < lastHp then
			combatUntil = os.clock() + Notify.COMBAT_SECONDS
		end
		lastHp = value
	else
		lastHp = nil
	end
end)

-- NotificationController hands over TargetController.IsAttacking (read only; a UI module cannot require it: the
-- target controller requires the toasts).
function Notify.SetAttackCheck(check: () -> boolean)
	attackCheck = check
end

function Notify.InCombat(): boolean
	return os.clock() < combatUntil
end

local function device(): NoticeQueue.Device
	if Fusion.peek(PhoneLayout.Compact) then
		return "phone"
	end
	return if Fusion.peek(Device.Touch) then "tablet" else "pc"
end

-- The text's lines at `size` in `width` (Logic/TextCaps' model), 1..3.
local function lines(text: string, size: number, width: number): number
	return math.clamp(TextCaps.lines(text, size, width), 1, 3)
end

-- A toast's or a phone line's height for `text` (the views use the same sizes).
function Notify.textHeight(text: string, width: number, phone: boolean): number
	local size = if phone then Theme.TextSize.Small else Theme.TextSize.Body
	local inner = width - 2 * (if phone then Theme.Padding.Small else Theme.Padding.Large)
	return 2 * TOAST_PAD + lines(text, size, inner) * (size + LINE)
end

local function sizeOf(e: NoticeQueue.Entry, phone: boolean, zoneWidth: number): (number, number)
	local spec = specs[e.id]
	local w = spec and spec.w
	local h = spec and (if spec.height then spec.height(phone) else spec.h)
	local inset = spec and spec.inset or 0
	if phone then
		w = zoneWidth
		if h == nil then
			h = if e.kind == "toast"
					or e.kind == "bark"
					or e.kind == "banner"
				then Notify.textHeight(e.text or "", zoneWidth - inset, true)
				else Theme.Size.HudLine
		end
		return w :: number, h :: number
	end
	if e.kind == "alert" then
		return w or TopBand.ALERT_W, h or HudZones.MESSAGE.alert
	elseif e.kind == "banner" then
		local big = e.tone == "mythic" or e.tone == "worldboss"
		local b = if big then TopBand.BANNER_BIG else TopBand.BANNER
		return w or b.w, h or b.h
	elseif e.kind == "prompt" then
		return w or TopBand.PROMPT.w, h or TopBand.PROMPT.h
	elseif e.kind == "card" then
		return w or HudZones.CARD_W, h or HudZones.CARDS.fight
	elseif e.kind == "bark" then
		return w or HudZones.BARK.w, h or HudZones.BARK.h
	end
	local width = w or TopBand.TOAST_WIDTH
	return width, h or Notify.textHeight(e.text or "", width - inset, false)
end

local function cardKind(e: NoticeQueue.Entry): HudZones.CardKind
	if e.class == "betterItem" then
		return "betterItem"
	elseif e.class == "bossReward" then
		return "bossReward"
	elseif e.class == "legendary" then
		return "legend"
	end
	return "fight"
end

local function toLayer(r: { left: number, top: number, right: number, bottom: number }, at: Vector2, k: number): Rect
	return {
		left = (r.left - at.X) / k,
		top = (r.top - at.Y) / k,
		right = (r.right - at.X) / k,
		bottom = (r.bottom - at.Y) / k,
	}
end

-- Where each shown entry stands now (by id), and how many of each place got room.
local function layout(shown: { NoticeQueue.Entry }): ({ [number]: Rect }, { [string]: number })
	local out: { [number]: Rect } = {}
	local room: { [string]: number } = {}
	local root = host
	if not root then
		return out, room
	end
	local k = Fusion.peek(Scale.Value)
	local size: Vector2 = Fusion.peek(Scale.VirtualSize)
	local bar = if k > 0 then Fusion.peek(Scale.TopBar) / k else 0
	local dev: NoticeQueue.Device = queue.device
	local phone = queue.device == "phone"
	local at = root.AbsolutePosition
	local windows: { TopBand.Window } = {}
	for _, r in Fusion.peek(HudCover.Rects) do
		local v = toLayer(r, at, k)
		table.insert(windows, {
			left = v.left,
			top = v.top,
			right = v.right,
			bottom = v.bottom,
			header = if phone then Theme.Size.WindowHeaderCompact else Theme.Size.WindowHeader,
		})
	end
	local keep = Fusion.peek(TopBandState.Keep)
	local boss = State.Get({ "boss" })
	local arena = State.Get({ "arenaLive" })
	local hud: HudZones.State = {
		bossBar = type(boss) == "table",
		arena = if type(arena) == "table" and type(arena.match) == "table" then "match" else nil,
	}
	local ctx: TopBand.Context = {
		w = size.X,
		h = size.Y,
		bar = bar,
		device = dev,
		hud = hud,
		windows = windows,
		keep = if keep then toLayer(keep, at, k) else nil,
		items = {},
		held = held,
	}
	local zone = TopBand.zone(ctx)
	local zoneWidth = zone.right - zone.left
	-- the band top down: the alert, the banner, the toasts (a tablet's barks too, older first), the prompt and a
	-- tablet's card; a phone: its line, then its card or prompt
	local ORDER: { [string]: number } = if phone
		then { alert = 1, banner = 1, toast = 1, bark = 1, prompt = 2, card = 2 }
		else { alert = 1, banner = 2, toast = 3, bark = 3, prompt = 4, card = 5 }
	local band: { NoticeQueue.Entry } = {}
	local cardEntry: NoticeQueue.Entry? = nil
	local barkEntry: NoticeQueue.Entry? = nil
	for _, e in shown do
		if dev == "pc" and e.kind == "card" then
			cardEntry = e
		elseif dev == "pc" and e.kind == "bark" then
			barkEntry = e
		else
			table.insert(band, e)
		end
	end
	table.sort(band, function(a, b)
		local oa, ob = ORDER[a.kind], ORDER[b.kind]
		if oa ~= ob then
			return oa < ob
		end
		return a.order < b.order
	end)
	ctx.card = if cardEntry then cardKind(cardEntry) else nil
	ctx.bark = barkEntry ~= nil
	-- where the band is too short for all of them, the lowest of them waits (a prompt never waits for a toast)
	local placed: TopBand.Placed
	while true do
		local items: { TopBand.Item } = {}
		for _, e in band do
			local w, h = sizeOf(e, phone, zoneWidth)
			table.insert(items, { id = tostring(e.id), w = w, h = h })
		end
		ctx.items = items
		placed = TopBand.slots(ctx)
		local missing = false
		for _, e in band do
			if placed.rects[tostring(e.id)] == nil then
				missing = true
			end
		end
		if not missing or #band <= 1 then
			break
		end
		local worst = 1
		for i = 2, #band do
			if NoticeQueue.before(band[worst], band[i]) then
				worst = i
			end
		end
		table.remove(band, worst)
	end
	for _, e in band do
		local r = placed.rects[tostring(e.id)]
		if r then
			out[e.id] = r
			local place = NoticeQueue.place(dev, e.kind)
			room[place] = (room[place] or 0) + 1
		end
	end
	if cardEntry then
		local r = placed.card
		if r then
			out[cardEntry.id] = r
			room.card = 1
		end
	end
	if barkEntry then
		local r = placed.bark
		if r then
			out[barkEntry.id] = r
			room.bark = 1
		end
	end
	return out, room
end

local function finish(id: number)
	local spec = specs[id]
	specs[id] = nil
	if spec and spec.gone then
		task.spawn(spec.gone)
	end
end

local function hideView(id: number)
	local view = views[id]
	if not view or view.closing then
		return
	end
	view.closing = true
	views[id] = nil
	view.alpha:set(1)
	task.delay(FADE + 0.05, function()
		Fusion.doCleanup(view.scope)
	end)
end

local function udims(r: Rect): (UDim2, UDim2)
	return UDim2.fromOffset(r.left, r.top), UDim2.fromOffset(r.right - r.left, r.bottom - r.top)
end

local function showView(e: NoticeQueue.Entry, r: Rect)
	local spec = specs[e.id]
	local root = host
	if not spec or not root then
		return
	end
	local inner = scope:innerScope()
	local position, size = udims(r)
	local place = inner:Value(position)
	local sizeValue = inner:Value(size)
	local alpha = inner:Value(1)
	local count = inner:Value(e.count)
	local live: Live = {
		id = e.id,
		count = count,
		phone = queue.device == "phone",
		close = function()
			Notify.close(e.id)
		end,
		relayout = function()
			wanted = true
		end,
	}
	local frame = inner:New("CanvasGroup")({
		Name = `Notice{e.id}`,
		Parent = root,
		BackgroundTransparency = 1,
		Position = inner:Tween(place, MOVE),
		Size = sizeValue,
		GroupTransparency = inner:Tween(alpha, TweenInfo.new(FADE)),
		ZIndex = if e.kind == "alert" then 3 else 2,
		[Children] = spec.build(inner, live),
	})
	views[e.id] = {
		scope = inner,
		frame = frame,
		place = place,
		size = sizeValue,
		alpha = alpha,
		count = count,
		closing = false,
	}
	task.defer(function()
		alpha:set(0)
	end)
	local first = spec.shown
	if first then
		spec.shown = nil
		task.spawn(first)
	end
end

local function context(now: number, room: { [string]: number }?): NoticeQueue.Context
	return {
		combat = now < combatUntil,
		window = Fusion.peek(HudCover.Open),
		room = room,
	}
end

local function tick()
	local now = os.clock()
	if attackCheck then
		local ok, attacking = pcall(attackCheck :: () -> boolean)
		if ok and attacking then
			combatUntil = now + Notify.COMBAT_SECONDS
		end
	end
	local dev: NoticeQueue.Device = device()
	if NoticeQueue.setDevice(queue, dev) then
		for id in views do
			hideView(id)
		end
		table.clear(held)
	end
	local shown, gone = NoticeQueue.update(queue, now, context(now))
	local rects, room = layout(shown)
	-- what has no room on the screen waits (it keeps its time): one more pass with the room the layout found
	if #shown > 0 then
		local missing = false
		for _, e in shown do
			if rects[e.id] == nil then
				missing = true
			end
		end
		if missing then
			local cap = table.clone(NoticeQueue.CAPACITY[dev])
			for place in cap do
				cap[place] = room[place] or 0
			end
			local again, more = NoticeQueue.update(queue, now, context(now, cap))
			shown = again
			for _, e in more do
				table.insert(gone, e)
			end
			rects = layout(shown)
		end
	end
	local keepIds: { [number]: boolean } = {}
	table.clear(held)
	for _, e in shown do
		local r = rects[e.id]
		if r then
			keepIds[e.id] = true
			held[tostring(e.id)] = r.top
			local view = views[e.id]
			if view then
				local position, size = udims(r)
				if Fusion.peek(view.place) ~= position then
					view.place:set(position)
				end
				if Fusion.peek(view.size) ~= size then
					view.size:set(size)
				end
				if Fusion.peek(view.count) ~= e.count then
					view.count:set(e.count)
				end
			else
				showView(e, r)
			end
		end
	end
	for id in views do
		if not keepIds[id] then
			hideView(id)
		end
	end
	for _, e in gone do
		finish(e.id)
	end
end

local function schedule()
	wanted = true
end

-- A banner's tone from its key (Logic/NoticeQueue.bannerTone), for Components/Announcement, which soft-requires this.
Notify.bannerTone = NoticeQueue.bannerTone

-- Puts a message in the queue. Returns its handle, or nil when it dropped (the same error within 10 s).
function Notify.push(spec: Spec): Handle?
	local hold = spec.hold
	if hold == nil and not Notify.HOLD_ALL and (spec.class == "toast" or spec.class == "bark") then
		hold = false
	end
	local entry = NoticeQueue.push(queue, os.clock(), {
		class = spec.class,
		text = spec.text,
		key = spec.key,
		tone = spec.tone,
		seconds = spec.seconds,
		deadline = spec.deadline,
		crossServer = spec.crossServer,
		windowWaits = spec.windowWaits,
		wait = spec.wait,
		hold = hold,
	})
	if not entry then
		return nil
	end
	local id = entry.id
	if specs[id] == nil then
		specs[id] = spec
	end
	schedule()
	return {
		id = id,
		close = function()
			Notify.close(id)
		end,
		alive = function(): boolean
			return NoticeQueue.find(queue, id) ~= nil
		end,
	}
end

-- Takes a message out now (an answered prompt, an alert whose cast ended, ✕).
function Notify.close(id: number)
	if NoticeQueue.remove(queue, id) then
		hideView(id)
		finish(id)
		schedule()
	end
end

-- The alert line (at most 28 characters): a boss's blow until its cast ends (Vfx/BossCastBar), the fight's countdown,
-- phases and victory (DungeonController). `color`: the blow's colour (danger), else brass.
function Notify.alert(text: string, seconds: number?, color: Color3?): Handle?
	return Notify.push({
		class = "alert",
		text = text,
		seconds = seconds,
		build = function(s: Scope, _live: Live): Instance
			local tint = color or Theme.Brass.Bright
			local parts: { Instance } = {
				s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				s:New("TextLabel")({
					Size = UDim2.new(1, -16, 1, 0),
					Position = UDim2.fromOffset(8, 0),
					BackgroundTransparency = 1,
					Text = text,
					RichText = true,
					TextScaled = true,
					FontFace = Theme.Fonts.Display,
					TextColor3 = if color then tint:Lerp(Theme.Plain, 0.35) else tint,
					TextStrokeColor3 = Theme.Shade,
					TextStrokeTransparency = 0.2,
					[Children] = s:New("UITextSizeConstraint")({ MaxTextSize = Theme.TextSize.Title }),
				}),
			}
			if color then
				-- a blow to dodge: on a dark plate with its telegraph's colour round it (Vfx/BossCastBar)
				table.insert(
					parts,
					s:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Stroke.Thick,
						Color = color,
					})
				)
			end
			return s:New("Frame")({
				Name = "Alert",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Iron.Sunken,
				BackgroundTransparency = if color then 0.25 else 1,
				[Children] = parts,
			})
		end,
	})
end

-- A card's texts and buttons (Notify.card).
export type Card = {
	class: NoticeQueue.Class, -- bossReward | legendary | fightResult | betterItem
	title: string, -- one line (at most 40)
	line: string?, -- one more (at most 40), PC only
	accent: Color3?,
	seconds: number?,
	details: (() -> ())?, -- 'Szczegóły': the full view (Notify.details)
	action: { text: string, run: () -> () }?, -- a second button (the better item's "Załóż")
	build: ((s: Scope, live: Live) -> Instance)?, -- its own look on PC (the better item's card with its icon)
	gone: (() -> ())?,
}

local PHONE_BUTTON = 96 -- a card's button on a phone's line

local function cardButton(
	s: Scope,
	order: number,
	text: string,
	primary: boolean,
	phone: boolean,
	run: () -> ()
): Instance
	return Button(s, {
		Surface = "iron",
		LayoutOrder = order,
		Text = text,
		Variant = if primary then "primary" else "secondary",
		Size = UDim2.fromOffset(if phone then PHONE_BUTTON elseif primary then 120 else 104, Theme.Size.MinTouch),
		TextSize = if phone then Theme.TextSize.Caption else Theme.TextSize.Small,
		OnClick = run,
	})
end

-- The card summary: on PC the title, a line, 'Szczegóły' and ✕ in HudZones.cardSlot (a tablet: under the toasts); on a
-- phone one line in M. A card that waits too long drops (it stays in the fight log or the loot log).
function Notify.card(card: Card): Handle?
	local function look(s: Scope, live: Live): Instance
		local accent = card.accent or Theme.Brass.Bright
		local buttons: { Instance } = {}
		if card.details then
			local open = card.details :: () -> ()
			table.insert(
				buttons,
				cardButton(s, 1, Text.now("fight.details"), card.action == nil, live.phone, function()
					live.close()
					open()
				end)
			)
		end
		if card.action then
			local action = card.action :: { text: string, run: () -> () }
			table.insert(
				buttons,
				cardButton(s, 2, action.text, true, live.phone, function()
					live.close()
					action.run()
				end)
			)
		end
		local close = Button(s, {
			Name = "Close",
			Surface = "iron", -- on the card's iron
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(Theme.Size.MinTouch, Theme.Size.MinTouch),
			Variant = "ghost",
			Text = "✕",
			OnClick = live.close,
		})
		if live.phone then
			-- one line of M: the title over its line, the buttons and ✕ at the right
			local buttonsWidth = #buttons * PHONE_BUTTON + math.max(0, #buttons - 1) * 4
			local textWidth = -(Theme.Padding.Small * 2 + buttonsWidth + Theme.Size.MinTouch)
			return s:New("Frame")({
				Name = "Card",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Iron.Surface,
				BackgroundTransparency = Theme.HudAlpha,
				Active = true,
				[Children] = {
					s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					s:New("UIStroke")({ Color = accent, Thickness = Theme.Stroke.Normal }),
					s:New("TextLabel")({
						Name = "Title",
						Position = UDim2.fromOffset(Theme.Padding.Small, 2),
						Size = UDim2.new(1, textWidth, if card.line then 0.5 else 1, -2),
						BackgroundTransparency = 1,
						Text = card.title,
						RichText = true,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = accent,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					s:New("TextLabel")({
						Name = "Line",
						Position = UDim2.new(0, Theme.Padding.Small, 0.5, 0),
						Size = UDim2.new(1, textWidth, 0.5, -2),
						BackgroundTransparency = 1,
						Visible = card.line ~= nil,
						Text = card.line or "",
						RichText = true,
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Caption,
						TextColor3 = Theme.Iron.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					s:New("Frame")({
						Name = "Buttons",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -Theme.Size.MinTouch, 0.5, 0),
						Size = UDim2.new(0, buttonsWidth, 1, 0),
						BackgroundTransparency = 1,
						[Children] = {
							s:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 4),
							}),
							buttons :: any,
						},
					}),
					close,
				},
			})
		end
		if card.build then
			return card.build(s, live)
		end
		return s:New("Frame")({
			Name = "Card",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Iron.Surface,
			BackgroundTransparency = Theme.HudAlpha,
			Active = true,
			[Children] = {
				s:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
				s:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = accent,
					Thickness = Theme.Stroke.Normal,
				}),
				s:New("UIPadding")({
					PaddingTop = UDim.new(0, Theme.Padding.Small),
					PaddingBottom = UDim.new(0, Theme.Padding.Small),
					PaddingLeft = UDim.new(0, Theme.Padding.Medium),
					PaddingRight = UDim.new(0, Theme.Padding.Small),
				}),
				s:New("TextLabel")({
					Name = "Title",
					Size = UDim2.new(1, -Theme.Size.MinTouch, 0, 28),
					BackgroundTransparency = 1,
					Text = card.title,
					RichText = true,
					FontFace = Theme.Fonts.Display,
					TextSize = Theme.TextSize.Body,
					TextColor3 = accent,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				s:New("TextLabel")({
					Name = "Line",
					Position = UDim2.fromOffset(0, 32),
					Size = UDim2.new(1, 0, 1, -(32 + Theme.Size.MinTouch + 6)),
					BackgroundTransparency = 1,
					Text = card.line or "",
					RichText = true,
					TextWrapped = true,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Iron.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				s:New("Frame")({
					Name = "Buttons",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
					BackgroundTransparency = 1,
					[Children] = {
						s:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Right,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, Theme.Padding.Small),
						}),
						buttons :: any,
					},
				}),
				close,
			},
		})
	end
	local kind: HudZones.CardKind = if card.class == "betterItem"
		then "betterItem"
		elseif card.class == "bossReward" then "bossReward"
		elseif card.class == "legendary" then "legend"
		else "fight"
	return Notify.push({
		class = card.class,
		seconds = card.seconds,
		w = HudZones.CARD_W,
		height = function(phone: boolean): number
			return if phone then Theme.Size.HudLine else HudZones.CARDS[kind]
		end,
		build = look,
		gone = card.gone,
	})
end

local detailsScope: Scope? = nil

-- Closes the open full view of a card, if any.
function Notify.closeDetails()
	local s = detailsScope
	detailsScope = nil
	if s then
		Fusion.doCleanup(s)
	end
end

-- The full view of a card ('Szczegóły'): `build(scope, close, sheet)` over a dimmed screen in the Toasts layer, closed
-- by a tap beside it or after `seconds` (default 60). One at a time. On a phone (`sheet`) it is a full-screen sheet
-- that scrolls: the view fills its width (Size 1, 0 with an automatic height) from its top.
function Notify.details(build: (s: Scope, close: () -> (), sheet: boolean) -> Instance, seconds: number?)
	Notify.closeDetails()
	local parent = detailsHost
	if not parent then
		return
	end
	local inner = scope:innerScope()
	detailsScope = inner
	local function close()
		if detailsScope == inner then
			Notify.closeDetails()
		end
	end
	local sheet = queue.device == "phone"
	local content = build(inner, close, sheet)
	inner:New("TextButton")({
		Name = "Details",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.Shade,
		BackgroundTransparency = if sheet then 0.2 else 0.4,
		[OnEvent("Activated")] = close,
		[Children] = if sheet
			then inner:New("ScrollingFrame")({
				Name = "Sheet",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -2 * Theme.Padding.Small, 1, -2 * Theme.Padding.Small),
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 6,
				Active = true,
				[Children] = content,
			})
			else content,
	})
	task.delay(seconds or 60, close)
end

local layer: Instance? = nil

-- A flash of the whole screen over everything (a legendary or mythic drop, Controllers/LootController): `color` at
-- `transparency`, fading out over `seconds`.
function Notify.flash(color: Color3, transparency: number, seconds: number)
	local parent = layer
	if not parent then
		return
	end
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = transparency
	flash.ZIndex = 100
	flash.Parent = parent
	TweenService:Create(flash, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	task.delay(seconds + 0.1, function()
		flash:Destroy()
	end)
end

-- Builds the message host in the Toasts layer (Components/Toast.mount calls it once, from UIController).
function Notify.mount(s: Scope, parent: Instance)
	layer = parent
	detailsHost = s:New("Frame")({
		Name = "NoticeDetails",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}) :: Frame
	host = s:New("Frame")({
		Name = "Notices",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}) :: Frame
	local clock = 0
	table.insert(
		s,
		RunService.Heartbeat:Connect(function(dt: number)
			clock += dt
			if clock >= TICK or wanted then
				clock = 0
				wanted = false
				tick()
			end
		end)
	)
	for _, state in { Scale.VirtualSize, Scale.TopBar, HudCover.Rects, TopBandState.Keep } :: { any } do
		s:Observer(state):onChange(schedule)
	end
end

return Notify
