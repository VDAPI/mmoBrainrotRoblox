--!strict
-- Low health warning (S134f): when the red vignette and the heartbeat are on, how strong they are and how often
-- the heartbeat plays. Pure; the HUD (Hud/LowHpVignette) reads hp / maxHp from the state mirror and calls this.

local LowHp = {}

export type Cfg = {
	onPct: number, -- turns on below this % of max HP
	offPct: number, -- turns off above this % (hysteresis, so heal-over-time ticks do not make it blink)
	fullPct: number, -- intensity 1 at or below this %
	beatSlow: number, -- heartbeat interval at intensity 0 (s)
	beatFast: number, -- heartbeat interval at intensity 1 (s)
	maxAlpha: number,
}

-- (on, intensity 0..1). Dead (hp <= 0) or no max HP: off.
function LowHp.state(hp: number?, maxHp: number?, wasOn: boolean, cfg: Cfg): (boolean, number)
	if type(hp) ~= "number" or type(maxHp) ~= "number" or maxHp <= 0 or hp <= 0 then
		return false, 0
	end
	local pct = hp * 100 / maxHp
	local on = if wasOn then pct <= cfg.offPct else pct < cfg.onPct
	if not on then
		return false, 0
	end
	local span = cfg.onPct - cfg.fullPct
	local intensity = if span > 0 then (cfg.onPct - pct) / span else 1
	return true, math.clamp(intensity, 0, 1)
end

-- Seconds between heartbeats: beatSlow at intensity 0 down to beatFast at 1.
function LowHp.beatInterval(intensity: number, cfg: Cfg): number
	local t = math.clamp(intensity, 0, 1)
	return cfg.beatSlow + (cfg.beatFast - cfg.beatSlow) * t
end

return LowHp
