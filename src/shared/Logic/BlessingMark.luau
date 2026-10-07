--!strict
-- Blessing mark (S29, DESIGN §11): what the ✶ next to a character's name shows. The server mirrors the active
-- blessing to the character model as attributes `Blessing` (blessing id, line + tier, e.g. "warrior_3") and
-- `BlessingUntil` (Util/Clock time of expiry); nameplates and the HUD read them through these pure helpers.

local Blessings = require("../Data/Blessings")
local Format = require("../Util/Format")

local BlessingMark = {}

local BLINK_PERIOD = 0.8 -- seconds per on/off cycle during the last minute

export type Mark = {
	def: Blessings.BlessingDef,
	left: number, -- seconds left (> 0)
	lastMinute: boolean,
}

-- Attribute values for a saved blessing ({ id, expiresAt }); nil/nil when none is active at `now`.
function BlessingMark.attributes(saved: { id: string, expiresAt: number }?, now: number): (string?, number?)
	if saved == nil or saved.expiresAt <= now or Blessings.get(saved.id) == nil then
		return nil, nil
	end
	return saved.id, saved.expiresAt
end

-- The mark to draw for raw attribute values (anything may come from the model), or nil.
function BlessingMark.read(id: any, untilTime: any, now: number): Mark?
	if type(id) ~= "string" or type(untilTime) ~= "number" then
		return nil
	end
	local def = Blessings.get(id)
	local left = untilTime - now
	if def == nil or left <= 0 then
		return nil
	end
	return { def = def, left = left, lastMinute = left <= Blessings.LAST_MINUTE }
end

-- "mm:ss" countdown, rounded up so it shows 00:00 only at expiry.
function BlessingMark.countdown(left: number): string
	return Format.time(math.ceil(math.max(0, left)))
end

-- Blink phase for the last minute: true = visible.
function BlessingMark.blinkOn(now: number): boolean
	return (now % BLINK_PERIOD) < BLINK_PERIOD * 0.6
end

return BlessingMark
