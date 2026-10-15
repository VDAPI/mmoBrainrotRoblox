--!strict
-- Elixir of Wholeness rules (DESIGN-17 §3, S122), pure: the own cooldown and the uses per character and UTC day
-- (Config.FullElixir). State: character.fullElixir (saved, os.time seconds), so logging out skips neither the
-- cooldown nor the daily limit. WHERE it does not work is not here: Logic/UseBlocks (the server checks it first).

local Config = require("../Config")
local Time = require("./Time")

local FullElixir = {}

export type State = { day: number, used: number, readyAt: number }
export type Missing = { hp: number, mana: number, energy: number }

FullElixir.EMPTY = table.freeze({ day = 0, used = 0, readyAt = 0 })

local function stateOf(state: State?): State
	if type(state) ~= "table" then
		return FullElixir.EMPTY :: State
	end
	return state
end

-- Uses on the UTC day of `now` (0 when the saved day is another one).
function FullElixir.usedToday(state: State?, now: number): number
	local s = stateOf(state)
	if s.day ~= Time.dayNumber(now) then
		return 0
	end
	return math.max(0, s.used or 0)
end

function FullElixir.leftToday(state: State?, now: number): number
	return math.max(0, Config.FullElixir.dailyLimit - FullElixir.usedToday(state, now))
end

-- Seconds until the next elixir is allowed (0 = ready).
function FullElixir.readyIn(state: State?, now: number): number
	return math.max(0, (stateOf(state).readyAt or 0) - now)
end

-- Whether one more elixir may be drunk now: cooldown, then the daily limit, then "already full".
function FullElixir.check(state: State?, now: number, missing: Missing): (boolean, string?)
	if FullElixir.readyIn(state, now) > 0 then
		return false, "fullElixir.error.cooldown"
	end
	if FullElixir.leftToday(state, now) <= 0 then
		return false, "fullElixir.error.daily"
	end
	if missing.hp <= 0 and missing.mana <= 0 and missing.energy <= 0 then
		return false, "fullElixir.error.notNeeded"
	end
	return true, nil
end

-- The state after drinking one at `now` (a new table; the input is never changed).
function FullElixir.count(state: State?, now: number): State
	return {
		day = Time.dayNumber(now),
		used = FullElixir.usedToday(state, now) + 1,
		readyAt = now + Config.FullElixir.cooldown,
	}
end

return FullElixir
