--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, nothing folds"; UI plan package B): one queue for every
-- message of the client, so two of them never fight for one place and a burst of them never buries the screen. Pure:
-- the caller passes the time (UI/Notify the client's os.clock, specs a fake one) and reads back what shows.
--   kinds: alert (a boss's blow, until the cast ends), prompt (an invitation, the ready check), card (a summary in the
--   corner), banner (an announcement, the achievement, the zone and area banners), toast, bark (an NPC's comment);
--   priority (the plan's yield ladder): alert > ready check > party invite > arena offer > other invites > boss
--   reward > legendary > fight result > better item > banner > toast > bark;
--   places: on PC (and a tablet) 1 alert, 1 banner, 2 toasts, 1 card, 1 prompt and the bark's own slot; on a phone one
--   line (alert, banner, toast or bark) plus one card or prompt. A higher entry takes a full place from a lower one,
--   which waits and later shows for the time it still had (a world boss's 15 s are 15 s on the screen in total);
--   the same text within MERGE seconds is one entry with a count (×N); the same error at most once per ERROR_GAP;
--   in combat the info and success toasts wait up to 10 s, the other servers' banners, the barks and the better-item
--   card up to 30 s, then they drop (the loot stays in the loot log); errors and alerts never wait.
-- Review 2026-11-10: an alert has its deadline (UI/Notify.alert: its seconds), so a countdown's "3" pushed back by "2"
-- never comes back after "Walcz!"; a blow to dodge (tone "danger") goes first among the alerts; a prompt whose silence
-- costs something (`penalty`: the arena's match offer, 5 min out of the queue) takes the prompt's place from the other
-- prompts, which wait with their own deadlines and come back.
-- Final UI review 2026-11-10: while the death screen shows (`paused`, UI/HudCover.Dead) what waits keeps its time: its
-- wait and its combat hold count again once the screen closes, so a long death (5 s + 0.3 s a level, and up to 60 s of
-- choosing) never drops the killer's name of a PvP death unseen; deadlines (alerts, prompts) still run.

local NoticeQueue = {}

export type Kind = "alert" | "prompt" | "card" | "banner" | "toast" | "bark"
export type Class =
	"alert"
	| "readyCheck"
	| "partyInvite"
	| "arenaOffer"
	| "invite"
	| "bossReward"
	| "legendary"
	| "fightResult"
	| "betterItem"
	| "banner"
	| "toast"
	| "bark"
export type Device = "pc" | "tablet" | "phone"

-- What a caller asks to show.
export type Spec = {
	class: Class,
	text: string?, -- what it says: two pushes of the same text merge (cards and prompts may leave it out)
	key: string?, -- its localization key: an error's identity (else its text)
	tone: string?, -- toast: info | success | warning | error; banner: legendary | mythic | worldboss | achievement ...
	seconds: number?, -- time on the screen; nil: the class's (a prompt: until answered or its deadline)
	deadline: number?, -- seconds from now when it goes, shown or not (an invitation's time to answer)
	crossServer: boolean?, -- a banner from another server: waits in combat
	windowWaits: boolean?, -- waits while a window is open (the achievement's banner, UI-ZASADY §6)
	wait: number?, -- the longest wait for a place, else the class's (math.huge: never drops)
	hold: (number | boolean)?, -- the combat wait: false none, a number its own, nil the class's (HOLD)
	penalty: boolean?, -- a prompt whose silence costs something: first among the prompts
	data: any?, -- the caller's own payload (the view to build)
}

export type Entry = {
	id: number,
	class: Class,
	kind: Kind,
	rank: number,
	-- first among its class: an error toast, an alert, a mythic or world boss banner, the zone and area banners
	urgent: boolean,
	newest: boolean, -- the newest of its rank shows first (alerts and errors never wait)
	text: string?,
	key: string?,
	tone: string?,
	data: any?,
	count: number, -- ×N
	added: number,
	last: number, -- the last merged push
	seconds: number?, -- its whole time on the screen
	left: number?, -- the time on the screen it still has; nil: until removed or its deadline
	ends: number?, -- the deadline, shown or not
	hold: number?, -- in combat it waits this long since `added`, then drops; nil: never held
	wait: number, -- the longest wait for a place since `added`
	crossServer: boolean,
	windowWaits: boolean,
	penalty: boolean,
	shown: boolean,
	order: number,
}

export type Queue = {
	device: Device,
	now: number,
	seq: number,
	entries: { Entry },
	errors: { [string]: number }, -- error identity -> when it last came on
	paused: boolean, -- the last update's `paused`: what waits does not age
}

-- The state the queue looks at: combat (UI/Notify's signal), an open window, the places the screen has room for now
-- (Logic/TopBand.slots), by place name (`NoticeQueue.place`; a missing name keeps the device's capacity), and the
-- death screen (`paused`: from this update on, what waits does not age until an update without it).
export type Context = {
	combat: boolean?,
	window: boolean?,
	room: { [string]: number }?,
	paused: boolean?,
}

NoticeQueue.ORDER = table.freeze({
	"alert",
	"readyCheck",
	"partyInvite",
	"arenaOffer",
	"invite",
	"bossReward",
	"legendary",
	"fightResult",
	"betterItem",
	"banner",
	"toast",
	"bark",
} :: { Class })

local RANK: { [string]: number } = {}
for i, class in NoticeQueue.ORDER do
	RANK[class] = i
end

local KIND: { [string]: Kind } = {
	alert = "alert" :: Kind,
	readyCheck = "prompt" :: Kind,
	partyInvite = "prompt" :: Kind,
	arenaOffer = "prompt" :: Kind,
	invite = "prompt" :: Kind,
	bossReward = "card" :: Kind,
	legendary = "card" :: Kind,
	fightResult = "card" :: Kind,
	betterItem = "card" :: Kind,
	banner = "banner" :: Kind,
	toast = "toast" :: Kind,
	bark = "bark" :: Kind,
}

-- The places of each device and how many entries each holds. A tablet has no bark slot (its column stands there,
-- Logic/HudZones.barkSlot): its barks take a toast's place. A phone's M zone shows one line, plus a card or a prompt.
NoticeQueue.CAPACITY = table.freeze({
	pc = table.freeze({ alert = 1, banner = 1, toast = 2, card = 1, prompt = 1, bark = 1 }),
	tablet = table.freeze({ alert = 1, banner = 1, toast = 2, card = 1, prompt = 1 }),
	phone = table.freeze({ line = 1, pane = 1 }),
} :: { [string]: { [string]: number } })

local PLACE: { [string]: { [string]: string } } = {
	pc = { alert = "alert", banner = "banner", toast = "toast", card = "card", prompt = "prompt", bark = "bark" },
	tablet = { alert = "alert", banner = "banner", toast = "toast", card = "card", prompt = "prompt", bark = "toast" },
	phone = { alert = "line", banner = "line", toast = "line", bark = "line", card = "pane", prompt = "pane" },
}

-- Seconds on the screen (UI-ZASADY §6). The banners' own: a mythic drop 8, a world boss 15 (owner, in red), the
-- achievement 5 (as before), the zone banner 3.5 (as before), the area banner 3 (owner question 4).
NoticeQueue.SECONDS = table.freeze({
	toast = 3.5,
	error = 4.5,
	banner = 5,
	mythic = 8,
	worldboss = 15,
	achievement = 5,
	zone = 3.5,
	area = 3,
	alert = 3,
	bark = 4,
	card = 8,
})

NoticeQueue.MERGE = 10
NoticeQueue.ERROR_GAP = 10

-- Combat waits (seconds since the push), then the entry drops.
NoticeQueue.HOLD = table.freeze({ toast = 10, crossServer = 30, bark = 30, betterItem = 30 })

-- The longest wait for a place (seconds since the push) before an entry drops: a backlog never outlives its news.
-- Alerts and prompts have none (a prompt has its deadline, an alert takes its place at once).
NoticeQueue.WAIT = table.freeze({ toast = 20, banner = 60, bark = 10, card = 30 } :: { [string]: number })

-- Where a kind stands on a device.
function NoticeQueue.place(device: Device, kind: Kind): string
	return PLACE[device][kind]
end

function NoticeQueue.kindOf(class: Class): Kind
	return KIND[class]
end

function NoticeQueue.new(device: Device, now: number?): Queue
	return { device = device, now = now or 0, seq = 0, entries = {}, errors = {}, paused = false }
end

-- A banner's tone from its key: a world boss's (red, 15 s), a mythic drop's or the Blood Moon's (red), else gold.
function NoticeQueue.bannerTone(key: string): string
	if string.sub(key, 1, 10) == "worldboss." then
		return "worldboss"
	end
	if string.find(key, "announceMythic", 1, true) or string.sub(key, 1, 10) == "bloodmoon." then
		return "mythic"
	end
	return "legendary"
end

local function effectiveRank(e: Entry): number
	-- a blow to dodge before the countdown's or a phase's line (each place sorts on its own: these only order alerts)
	if e.kind == "alert" and e.tone == "danger" then
		return RANK.alert - 0.5
	end
	-- an error toast never waits behind a banner on a phone's one line: only an alert goes first
	if e.kind == "toast" and e.tone == "error" then
		return RANK.alert + 0.5
	end
	-- the arena's offer before the ready check and the invitations (its silence costs 5 min out of the queue; theirs
	-- costs nothing, and they keep their deadlines while they wait)
	if e.kind == "prompt" and e.penalty then
		return RANK.alert + 0.75
	end
	return e.rank
end

-- Whether `a` comes before `b`: the priority, then the urgent first, then the newest alert or error, else the older.
function NoticeQueue.before(a: Entry, b: Entry): boolean
	local ra, rb = effectiveRank(a), effectiveRank(b)
	if ra ~= rb then
		return ra < rb
	end
	if a.urgent ~= b.urgent then
		return a.urgent
	end
	if a.newest and b.newest then
		return a.order > b.order
	end
	return a.order < b.order
end

-- The banners that go first among the banners: a mythic drop's and a world boss's (red), and the zone and area banners
-- (where the player stands now, never late; the achievement and an announcement shown then wait and come back for the
-- time they had left, so the achievement waits for the zone and area banners as before).
local URGENT_TONES: { [string]: boolean } = { mythic = true, worldboss = true, zone = true, area = true }

local function secondsOf(spec: Spec, kind: Kind): number?
	if spec.seconds then
		return spec.seconds
	end
	local s = NoticeQueue.SECONDS
	if kind == "toast" then
		return if spec.tone == "error" then s.error else s.toast
	elseif kind == "banner" then
		local tone = spec.tone or "legendary"
		local own = (s :: any)[tone]
		return if type(own) == "number" then own else s.banner
	elseif kind == "alert" then
		return s.alert
	elseif kind == "bark" then
		return s.bark
	elseif kind == "card" then
		return s.card
	end
	return nil -- a prompt: until answered or its deadline
end

local function holdOf(spec: Spec, kind: Kind): number?
	local h = NoticeQueue.HOLD
	if kind == "toast" then
		local tone = spec.tone or "info"
		return if tone == "info" or tone == "success" then h.toast else nil
	elseif kind == "banner" then
		return if spec.crossServer then h.crossServer else nil
	elseif kind == "bark" then
		return h.bark
	elseif spec.class == "betterItem" then
		return h.betterItem
	end
	return nil
end

local function identity(spec: Spec): string?
	return spec.key or spec.text
end

-- The shown entries spend the time from the queue's clock to `now`; while paused, the waiting ones do not age (their
-- wait and combat hold count from `added`, which moves on with the clock).
local function advance(q: Queue, now: number)
	local dt = math.max(0, now - q.now)
	q.now = math.max(q.now, now)
	if dt > 0 then
		for _, e in q.entries do
			if e.shown and e.left then
				e.left = (e.left :: number) - dt
			elseif not e.shown and q.paused then
				e.added += dt
			end
		end
	end
end

-- Adds an entry (or merges it into the same text within MERGE seconds). Returns the entry, or nil when it dropped:
-- the same error came on less than ERROR_GAP ago.
function NoticeQueue.push(q: Queue, now: number, spec: Spec): Entry?
	local found: Kind? = KIND[spec.class]
	assert(found ~= nil, `NoticeQueue: unknown class {spec.class}`)
	local kind: Kind = found
	advance(q, now)
	local isError = kind == "toast" and spec.tone == "error"
	local errorId = if isError then identity(spec) else nil
	if spec.text ~= nil then
		for _, e in q.entries do
			if
				e.class == spec.class
				and e.text == spec.text
				and e.tone == spec.tone
				and now - e.last <= NoticeQueue.MERGE
			then
				e.count += 1
				e.last = now
				-- a merged entry shows its whole time again, except an error: it showed, and shows once per ERROR_GAP
				if e.shown and e.seconds and not isError then
					e.left = e.seconds
				end
				-- and its deadline counts from the last push (an alert said again)
				if spec.deadline and e.ends then
					e.ends = math.max(e.ends :: number, now + spec.deadline)
				end
				return e
			end
		end
	end
	if errorId then
		local at = q.errors[errorId]
		if at and now - at < NoticeQueue.ERROR_GAP then
			return nil
		end
		q.errors[errorId] = now
	end
	q.seq += 1
	local seconds = secondsOf(spec, kind)
	local tone = spec.tone
	local entry: Entry = {
		id = q.seq,
		class = spec.class,
		kind = kind,
		rank = RANK[spec.class],
		urgent = isError or kind == "alert" or URGENT_TONES[tone or ""] == true,
		newest = isError or kind == "alert",
		text = spec.text,
		key = spec.key,
		tone = tone,
		data = spec.data,
		count = 1,
		added = now,
		last = now,
		seconds = seconds,
		left = seconds,
		ends = if spec.deadline then now + spec.deadline else nil,
		hold = if spec.hold == false then nil elseif type(spec.hold) == "number" then spec.hold else holdOf(spec, kind),
		wait = spec.wait or NoticeQueue.WAIT[kind] or math.huge,
		crossServer = spec.crossServer == true,
		windowWaits = spec.windowWaits == true,
		penalty = spec.penalty == true,
		shown = false,
		order = q.seq,
	}
	table.insert(q.entries, entry)
	return entry
end

function NoticeQueue.find(q: Queue, id: number): Entry?
	for _, e in q.entries do
		if e.id == id then
			return e
		end
	end
	return nil
end

-- Takes an entry out (an alert whose cast ended, an answered prompt). Returns whether it was there.
function NoticeQueue.remove(q: Queue, id: number): boolean
	for i, e in q.entries do
		if e.id == id then
			table.remove(q.entries, i)
			return true
		end
	end
	return false
end

-- A new device (a resized window): the entries keep their order and time, the places are the new device's. Returns
-- whether the device changed.
function NoticeQueue.setDevice(q: Queue, device: Device): boolean
	if q.device == device then
		return false
	end
	q.device = device
	return true
end

local function waits(e: Entry, ctx: Context): boolean
	if e.shown then
		return false -- what shows keeps showing: combat or a window never takes a message off the screen
	end
	if ctx.combat and e.hold ~= nil then
		return true
	end
	return ctx.window == true and e.windowWaits
end

-- Moves the clock to `now`: the shown entries spend their time, the expired and the dropped ones go, and each place
-- takes its best entries. Returns the shown entries in priority order and those that went this step.
function NoticeQueue.update(q: Queue, now: number, ctx: Context?): ({ Entry }, { Entry })
	local context: Context = ctx or {}
	advance(q, now)
	q.paused = context.paused == true
	local gone: { Entry } = {}
	local kept: { Entry } = {}
	for _, e in q.entries do
		local over = (e.shown and e.left ~= nil and (e.left :: number) <= 0)
			or (e.ends ~= nil and now >= (e.ends :: number))
			or (not e.shown and context.combat == true and e.hold ~= nil and now - e.added >= (e.hold :: number))
			or (not e.shown and now - e.added >= e.wait)
		if over then
			e.shown = false
			table.insert(gone, e)
		else
			table.insert(kept, e)
		end
	end
	q.entries = kept
	-- each place: its best eligible entries show, the rest wait (a shown one put back keeps the time it has left)
	local capacity = NoticeQueue.CAPACITY[q.device]
	local byPlace: { [string]: { Entry } } = {}
	for _, e in kept do
		local place = PLACE[q.device][e.kind]
		if place == nil or waits(e, context) then
			e.shown = false
		else
			local list = byPlace[place]
			if list == nil then
				list = {}
				byPlace[place] = list
			end
			table.insert(list, e)
		end
	end
	local shown: { Entry } = {}
	for place, list in byPlace do
		table.sort(list, NoticeQueue.before)
		local room = capacity[place] or 0
		local limit = context.room and context.room[place]
		if limit ~= nil then
			room = math.min(room, limit)
		end
		for i, e in list do
			e.shown = i <= room
			if e.shown then
				table.insert(shown, e)
			end
		end
	end
	table.sort(shown, NoticeQueue.before)
	return shown, gone
end

-- The entries that show now, in priority order (as the last update left them).
function NoticeQueue.visible(q: Queue): { Entry }
	local out = {}
	for _, e in q.entries do
		if e.shown then
			table.insert(out, e)
		end
	end
	table.sort(out, NoticeQueue.before)
	return out
end

return NoticeQueue
