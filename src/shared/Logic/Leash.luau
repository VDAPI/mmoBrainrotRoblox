--!strict
-- Monster leash and out-of-combat regeneration (S22, DESIGN §15.1). Pure decisions; Entities/Monster applies
-- them. Numbers come from Data/Combat (passed in as `cfg`).

local Leash = {}

export type Config = {
	leashRange: number,
	leashMax: number,
	leashGrace: number,
	stuckTime: number,
	idleRegenDelay: number,
	idleRegenPct: number,
}

export type Situation = {
	distHome: number, -- flat distance from the group centre
	sinceHit: number, -- seconds since a player last hit the monster (or its group)
	hasTarget: boolean, -- a valid target remains (alive, present, not hidden, not in a safe zone)
	stuckFor: number, -- seconds without moving or attacking while chasing
}

export type Reason = "target" | "hard" | "soft" | "stuck"

-- Whether a chasing monster gives up and goes home, and why.
--   * no valid target: home;
--   * past leashMax: always home (no dragging monsters across the map);
--   * past leashRange: home only once nobody has hit it for leashGrace seconds (it fights while beaten);
--   * stuck (no movement and no attack) for stuckTime seconds: home.
function Leash.shouldReturn(s: Situation, cfg: Config): (boolean, Reason?)
	if not s.hasTarget then
		return true, "target"
	end
	if s.distHome > cfg.leashMax then
		return true, "hard"
	end
	if s.distHome > cfg.leashRange and s.sinceHit >= cfg.leashGrace then
		return true, "soft"
	end
	if s.stuckFor >= cfg.stuckTime then
		return true, "stuck"
	end
	return false, nil
end

-- Whether a monster going home turns back to fight a player who hit it: only within leashMax.
function Leash.canReengage(distHome: number, cfg: Config): boolean
	return distHome <= cfg.leashMax
end

-- HP after `dt` seconds out of combat: nothing during the first idleRegenDelay seconds after the last hit, then
-- idleRegenPct % of max HP per second, up to max HP.
function Leash.regen(hp: number, maxHp: number, sinceHit: number, dt: number, cfg: Config): number
	if hp >= maxHp or sinceHit < cfg.idleRegenDelay or dt <= 0 then
		return math.min(hp, maxHp)
	end
	return math.min(maxHp, hp + maxHp * cfg.idleRegenPct / 100 * dt)
end

return Leash
