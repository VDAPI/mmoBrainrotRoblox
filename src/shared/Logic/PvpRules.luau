--!strict
-- Who may attack whom (DESIGN §3.3). Pure; the zone is the one the TARGET stands in.
--   green  : never
--   yellow : only when both players have PvP enabled
--   red    : always (the toggle is ignored)
-- Party members are always protected; guild members unless the guild disabled the protection.
-- Review 2026-11-10: `hostile` is the same rule from what the client sees (TargetController.IsEnemy), so a tapped skill
-- never takes a party or guild member for an enemy.

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

-- What the client sees of another player (review 2026-11-10: the client's enemy test, TargetController.IsEnemy, said
-- "PvP on or a red zone" and so counted party and guild members as enemies). Read from the model's attributes
-- (PvpZone, PvpEnabled, GuildTag, DuelId) and our own state (party, guild, arenaLive) and model (PvpEnabled, DuelId).
export type Seen = {
	zone: string?, -- their PvpZone attribute (nil: not known yet, green as on the server)
	pvpEnabled: boolean, -- their PvpEnabled attribute (the toggle, or standing on an arena sand)
	myPvp: boolean, -- our own PvpEnabled attribute
	sameParty: boolean?,
	sameGuild: boolean?,
	guildProtection: boolean?, -- our guild's setting (defaults to true)
	myDuel: string?, -- our DuelId attribute (DuelService: both duelists carry the same one while their duel runs)
	duel: string?, -- their DuelId attribute
	mySide: number?, -- our side in an arena match we fight in (nil: none)
	side: number?, -- their side in that match (nil or 0: not a fighter of it)
}

-- Whether we may attack the player we see, as PvpService.CanAttack decides it: its fight rules first, as far as the
-- client sees them (an arena match we fight in: only the other side; a duel: the two duelists, whatever party or
-- guild, and nobody else may touch them), then canAttack with the same context (the target's zone, both PvP flags,
-- party, guild and our guild's protection). Review 2026-11-10: standing on an arena sand lifts no protection, only our
-- own duel does (the duel rule says nothing about anyone else, so the server protects a party member on an idle sand).
function PvpRules.hostile(seen: Seen): boolean
	if seen.mySide ~= nil then
		return seen.side ~= nil and seen.side ~= 0 and seen.side ~= seen.mySide
	end
	if seen.myDuel ~= nil or seen.duel ~= nil then
		-- the duel rule: the pair fights (blows land once the countdown ends), "deny" when only one of us duels
		return seen.myDuel == seen.duel
	end
	local zone: Zone = if seen.zone == "yellow" then "yellow" elseif seen.zone == "red" then "red" else "green"
	local allowed = PvpRules.canAttack({ pvpEnabled = seen.myPvp }, { pvpEnabled = seen.pvpEnabled }, {
		zone = zone,
		sameParty = seen.sameParty == true,
		sameGuild = seen.sameGuild == true,
		guildProtection = seen.guildProtection,
	})
	return allowed
end

-- Review 2026-11-10: a player we fight beside, whom a click on their body selects over an enemy drawn next to them
-- (TargetController): a fighter of our side in an arena match we fight in (the server's help group), else a party
-- member or a guild member under the guild's protection. The caller asks `hostile` first (a party member we duel is an
-- enemy).
function PvpRules.teammate(seen: Seen): boolean
	if seen.mySide ~= nil then
		return seen.side == seen.mySide
	end
	return seen.sameParty == true or (seen.sameGuild == true and seen.guildProtection ~= false)
end

-- True when the player's own PvP toggle matters in this zone (only yellow zones).
function PvpRules.toggleMatters(zone: Zone): boolean
	return zone == "yellow"
end

-- UI plan phase 1 (owner 2026-10-31, too much on one screen): the HUD's PvP toggle shows only where PvP is in play: a
-- yellow zone (the toggle matters), PvP on (a red zone forces it; in a green zone it is off whatever the switch says)
-- or a switch counting down (`pendingTarget`). The dot on the portrait always tells the state.
function PvpRules.toggleShown(zone: Zone?, pendingTarget: boolean?): boolean
	return zone == "yellow" or zone == "red" or pendingTarget ~= nil
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

-- S61 (ROZWOJ 7.6): a player is in PvP combat within `window` seconds of the last player hit (dealt or taken).
function PvpRules.inPvpCombat(now: number, lastPvpCombat: number?, window: number): boolean
	return lastPvpCombat ~= nil and now - lastPvpCombat <= window
end

return PvpRules
