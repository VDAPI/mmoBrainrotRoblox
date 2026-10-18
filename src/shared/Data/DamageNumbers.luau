--!strict
-- Floating combat numbers (S29, DESIGN §23): sizes, lifetime, stacking and merging. Read by Logic/DamageText
-- (text, style, stacking) and CombatFxController (drawing). Colours live in the client (UI/Theme).

export type Style = {
	size: number, -- TextSize in pixels
	dim: number?, -- starting text transparency (others' hits are dimmer)
	pop: number?, -- starting scale of the pop (crits: 1.4 -> 1)
	rise: number?, -- studs the number rises over its lifetime (default DamageNumbers.rise)
	mergeable: boolean?, -- hits of this style may merge into a sum when they come too fast
}

local DamageNumbers = {
	-- Seconds a number stays on screen (the fade takes the second half).
	lifetime = 1.2,
	-- Studs a number rises over its lifetime.
	rise = 3,
	-- Studs above the previous number for each number of the same target still in the air.
	stackStep = 1.1,
	-- At most this many numbers fly above one target at once (the oldest one goes first).
	maxPerTarget = 6,
	-- More than this many numbers per second on one target: new hits add to the newest number of the same style.
	mergeRate = 8,
	-- Window (seconds) over which that rate is counted.
	rateWindow = 1,
	-- A number accepts merged hits only while younger than this (seconds).
	mergeAge = 0.6,
	-- BillboardGui.MaxDistance of the numbers (studs).
	maxDistance = 250,
	-- Seconds the pop of a critical number takes.
	popSeconds = 0.12,
	-- Pixels a critical number twitches sideways during the pop.
	twitch = 4,
	-- Skill numbers are this many pixels bigger than basic attacks (S28).
	skillBonus = 6,
	-- Billboards kept in the pool.
	poolSize = 48,
	-- W28: every number pops in from this scale (crits use their style's bigger pop).
	popAll = 1.22,
	-- W28: studs a number drifts sideways (random side) while it rises, so a stream of hits fans out.
	drift = 0.9,
	-- W28: scale a number shrinks to while it fades.
	shrink = 0.72,
	-- W28: outline thickness in pixels (crits get `strokeCrit`) and how dark the outline is (0 = the text colour,
	-- 1 = black).
	stroke = 2,
	strokeCrit = 3,
	strokeDark = 0.82,
	-- W28: crits and heals get a vertical sheen: the top of the glyphs this much lighter (toward white).
	sheen = 0.5,

	styles = {
		mine = { size = 28, mergeable = true },
		mineCrit = { size = 40, pop = 1.4 },
		other = { size = 20, dim = 0.35, mergeable = true },
		otherCrit = { size = 26, dim = 0.3, pop = 1.2 },
		received = { size = 26, mergeable = true },
		receivedCrit = { size = 34, pop = 1.4 },
		absorbed = { size = 20 },
		immune = { size = 20 },
		dodge = { size = 22 },
		blocked = { size = 22 }, -- S64
		heal = { size = 24, mergeable = true },
		hot = { size = 20, mergeable = true },
		dot = { size = 18, mergeable = true },
		none = { size = 0 },
	} :: { [string]: Style },

	-- Options of the "Damage numbers" setting (settings.dmgMode), in the menu's order.
	modes = { "all", "mine", "off" },
}

return DamageNumbers
