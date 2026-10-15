--!strict
-- Wall-clock events (DESIGN-17 §7-§8): every server computes the same occurrences from the UTC clock
-- (Util/Clock.now, Logic/Schedule), with no cross-server messages. S129: the Blood Moon; S130 adds the
-- Champion's Tournament to `list`.
-- Balance ledger: tools/balance_reasons.luau (BALANCE_MODULES, session S129); `sky` is the look of the event.

export type Slot = { weekday: number, hour: number, minute: number } -- ISO weekday: 1 = Monday ... 7 = Sunday, UTC
export type EventDef = {
	key: string, -- "bloodmoon"; also the prefix of ids and Locale keys
	nameKey: string, -- "bloodmoon.name"
	descKey: string,
	slots: { Slot }, -- at most one slot per UTC day (the occurrence id is the date, Logic/Schedule.idOf)
	duration: number, -- seconds
	warn: { number }, -- announcements, seconds before the start (descending)
	blocksWorldEvents: boolean, -- S101 world events must not overlap it (Logic/Schedule.blocking)
	quietBefore: number, -- seconds before the start in which no world event may run (with blocksWorldEvents)
	enabled: boolean,
}

export type Sky = {
	fogColor: string,
	fogMix: number,
	tint: string,
	tintMix: number,
	brightness: number, -- multiplier
	saturation: number, -- added
	haze: number, -- added to the atmosphere haze
	fade: number, -- seconds of the transition
}

local function slot(weekday: number, hour: number, minute: number): Slot
	return table.freeze({ weekday = weekday, hour = hour, minute = minute })
end

local BLOODMOON: EventDef = table.freeze({
	key = "bloodmoon",
	nameKey = "bloodmoon.name",
	descKey = "bloodmoon.desc",
	slots = table.freeze({
		slot(2, 19, 0), -- Tuesday 19:00 UTC (DESIGN-17 §7)
		slot(4, 19, 0), -- Thursday 19:00 UTC
	}),
	duration = 1800, -- 30 min
	warn = table.freeze({ 600, 60 }), -- 10 min and 1 min before; the start has its own announcement
	blocksWorldEvents = true,
	quietBefore = 600,
	enabled = true,
})

-- S130 (DESIGN-17 §8): Champion's Tournament. The slot time is the bracket start; signups and invites are offsets in
-- Data/Arena.TOURNEY.window. No general warnings (TourneyService announces the signups itself) and no block of S101
-- world events (the fighters are on tournament servers). `duration` is an upper bound of a bracket of 32 on four
-- fields (usually 45-90 min; a tournament server stops itself at Config.Tourney.maxMinutes).
local TOURNEY: EventDef = table.freeze({
	key = "tourney",
	nameKey = "tourney.title",
	descKey = "tourney.desc",
	slots = table.freeze({
		slot(6, 19, 0), -- Saturday 19:00 UTC (DESIGN-17 §8)
	}),
	duration = 3 * 3600,
	warn = table.freeze({}),
	blocksWorldEvents = false,
	quietBefore = 0,
	enabled = true,
})

local LIST: { EventDef } = table.freeze({ BLOODMOON, TOURNEY })

local byKey: { [string]: EventDef } = {}
for _, def in LIST do
	byKey[def.key] = def
end

return table.freeze({
	list = LIST,
	byKey = table.freeze(byKey),
	get = function(key: string): EventDef?
		return byKey[key]
	end,
	-- Blood Moon rules (DESIGN-17 §7). Balance ledger: tools/balance_reasons.luau, session S129.
	bloodMoon = table.freeze({
		regions = table.freeze({ "meadows", "duskwood", "ashen", "frostpeak" }), -- open regions forced red
		points = table.freeze({ player = 10, elite = 1, elite2 = 5 }),
		levelGap = 8, -- a victim this many levels (or more) below the killer gives 0 points
		sameVictimMax = 2, -- one victim counts at most this many times per event
		eliteChance = 0.15, -- a normal group respawning in an open region comes back as one Elite (S129)
		reward = table.freeze({
			minPoints = 5, -- participation
			tokens = 20, -- Arena Tokens (S128), outside the weekly cap
			blessingRarity = 2, -- Rarities.UNIQUE; the line is random (Blessings.lines)
			titleTop = 100,
			titleId = "bloodmoon",
			titleDays = 7,
			frameTop = 10,
			frameId = "frame_bloodmoon",
			shardsTop = 1,
			shards = 100,
		}),
		-- the red sky over the open regions (client, WorldController.SetEventTint); a look, not balance
		sky = table.freeze({
			fogColor = "#4A0B10",
			fogMix = 0.6,
			tint = "#FF5A4E",
			tintMix = 0.35,
			brightness = 0.75,
			saturation = -0.1,
			haze = 1.2,
			fade = 3,
		} :: Sky),
	}),
})
