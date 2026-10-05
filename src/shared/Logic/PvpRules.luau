--!strict
-- Who may attack whom (DESIGN §3.3). Pure; the zone is the one the TARGET stands in.
--   green  : never
--   yellow : only when both players have PvP enabled
--   red    : always (the toggle is ignored)
-- Party members are always protected; guild members unless the guild disabled the protection.

export type Zone = "green" | "yellow" | "red"

export type Combatant = { pvpEnabled: boolean }

export type Context = {
	zone: Zone,
	sameParty: boolean?,
	sameGuild: boolean?,
	guildProtection: boolean?, -- defaults to true
}

local PvpRules = {}

-- Returns (allowed, reasonKey?). Reason keys are localization keys "pvp.deny.<reason>".
function PvpRules.canAttack(attacker: Combatant, target: Combatant, context: Context): (boolean, string?)
	if context.sameParty then
		return false, "pvp.deny.party"
	end
	if context.sameGuild and context.guildProtection ~= false then
		return false, "pvp.deny.guild"
	end
	if context.zone == "green" then
		return false, "pvp.deny.safeZone"
	end
	if context.zone == "red" then
		return true, nil
	end
	if not attacker.pvpEnabled then
		return false, "pvp.deny.selfDisabled"
	end
	if not target.pvpEnabled then
		return false, "pvp.deny.targetDisabled"
	end
	return true, nil
end

-- True when the player's own PvP toggle matters in this zone (only yellow zones).
function PvpRules.toggleMatters(zone: Zone): boolean
	return zone == "yellow"
end

-- Whether the toggle may switch now. Turning PvP off is blocked for `combatLock` seconds after PvP combat.
function PvpRules.canToggle(
	zone: Zone,
	wantEnabled: boolean,
	now: number,
	lastPvpCombat: number?,
	combatLock: number
): (boolean, string?)
	if zone ~= "yellow" then
		return false, "pvp.error.zone"
	end
	if not wantEnabled and lastPvpCombat and now - lastPvpCombat < combatLock then
		return false, "pvp.error.inCombat"
	end
	return true, nil
end

export type Indicator = "off" | "on" | "forced" | "switching" | "locked"

-- PvP dot next to a name (DESIGN §3.3, after the S17 tests): forced in red zones, switching while a toggle
-- counts down, locked (grey, padlock) when the toggle cannot change (green zone or the post-combat lock),
-- otherwise on/off. For other players only `enabled` and `zone` are known (pass nil for the rest).
function PvpRules.indicator(
	enabled: boolean,
	zone: Zone?,
	pendingTarget: boolean?,
	lockedUntil: number?,
	now: number
): Indicator
	if zone == "red" then
		return "forced"
	elseif pendingTarget ~= nil then
		return "switching"
	elseif zone == "green" or (lockedUntil ~= nil and lockedUntil > now) then
		return "locked"
	end
	return if enabled then "on" else "off"
end

return PvpRules
