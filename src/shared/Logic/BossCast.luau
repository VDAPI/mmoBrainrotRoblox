--!strict
-- S160 (owner 2026-10-21: "boss abilities are barely visible"): what the client shows of a boss's (or an Elite II's)
-- cast besides the ground: the cast bar over the caster with the ability's name (Vfx/BossCastBar), the warning banner
-- of a big attack, and the colours of the telegraph rim (bright on dark ground, the dark under-rim on light ground).
-- Pure (Lune).
--   nameKeys(bossId, attackId, patternId)  candidate Localization keys of the ability's name, best first (the client
--                                         takes the first that exists): the boss attack, the hazard pattern, the
--                                         Elite II ability
--   banner(info)                          the banner's key for a big attack (nil = no banner): a lethal blow, a big
--                                         blow to dodge, a big hazard pattern; the party mechanics (split, mark,
--                                         channel) have their own announcements (BossAnnounce)
--   allowBanner(last, now)                one banner per Config.BossCast.bannerGap s (several areas of one attack)
--   barSeconds(windup)                    how long the cast bar fills (at least MIN_BAR, the shortest fair warning)
--   vivid(hex)                            the rim's colour: saturated and bright, a deep red / blue lifted towards
--                                         white to Config.BossCast.minLuminance (white and greys keep their hue)
--   onGround(hex, ground?)                studio review 2026-10-21: the telegraph's colours on the ground under it
--                                         (Config.Telegraph.ground): the vivid rim where it stands out, else deep on
--                                         light ground (snow, ice, sand) and white-hot on a ground of its own hue
--                                         (lava) or one the dark under-rim hardly marks, with a wider dark under-rim

local Config = require("../Config")
local Contrast = require("./Contrast")

local BossCast = {}

BossCast.MIN_BAR = 0.6 -- seconds: the shortest cast bar (= Logic/Hazards.MIN_WARN, the shortest warning)

-- The colours of a telegraph on its ground (hex strings): the rim and its moving front, the faint area, the dark
-- under-rim and how much wider than Config.Telegraph.underRim it is; `kind` says which rule chose them.
export type Style = {
	kind: "plain" | "deep" | "hot",
	rim: string,
	front: string,
	area: string,
	under: string,
	underScale: number,
}

export type Info = {
	mechanic: string?, -- "avoid" | "split" | "mark" | "channel" | nil
	lethal: boolean?, -- S134e: a lethal blow (Elite II Crushing Blow)
	big: boolean?, -- a big hazard pattern (Data/HazardPatterns `big`)
	regular: boolean?, -- a monster's regular shot: never a banner
}

function BossCast.nameKeys(bossId: string?, attackId: string?, patternId: string?): { string }
	local keys: { string } = {}
	if bossId and attackId then
		table.insert(keys, `boss.{bossId}.attack.{attackId}`)
	end
	if patternId then
		table.insert(keys, `hazard.{patternId}.name`)
	end
	if attackId then
		-- a pattern cast without an attack of its own sends the pattern's id as the attack
		table.insert(keys, `hazard.{attackId}.name`)
		table.insert(keys, `ability.{attackId}.name`)
	end
	return keys
end

function BossCast.banner(info: Info): string?
	if info.regular then
		return nil
	end
	if info.lethal then
		return "boss.cast.lethal"
	end
	local m = info.mechanic
	if m == "split" or m == "mark" or m == "channel" then
		return nil
	end
	if m == "avoid" then
		return "boss.cast.avoid"
	end
	if info.big then
		return "boss.cast.dodge"
	end
	return nil
end

function BossCast.allowBanner(last: number?, now: number): boolean
	return last == nil or now - last >= Config.BossCast.bannerGap
end

function BossCast.barSeconds(windup: number?): number
	return math.max(BossCast.MIN_BAR, windup or BossCast.MIN_BAR)
end

-- RGB 0..255 -> HSV 0..1.
local function hsv(r: number, g: number, b: number): (number, number, number)
	r, g, b = r / 255, g / 255, b / 255
	local hi, lo = math.max(r, g, b), math.min(r, g, b)
	local d = hi - lo
	local h = 0
	if d > 0 then
		if hi == r then
			h = ((g - b) / d) % 6
		elseif hi == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	local s = if hi > 0 then d / hi else 0
	return h, s, hi
end

local function fromHsv(h: number, s: number, v: number): (number, number, number)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local k = i % 6
	local r, g, b
	if k == 0 then
		r, g, b = v, t, p
	elseif k == 1 then
		r, g, b = q, v, p
	elseif k == 2 then
		r, g, b = p, v, t
	elseif k == 3 then
		r, g, b = p, q, v
	elseif k == 4 then
		r, g, b = t, p, v
	else
		r, g, b = v, p, q
	end
	return r * 255, g * 255, b * 255
end

function BossCast.vivid(hex: string): string
	local r, g, b = Contrast.rgb(hex)
	local h, s, v = hsv(r, g, b)
	local cfg = Config.BossCast
	if s >= cfg.greyBelow then
		s = math.max(s, cfg.minSaturation)
	end
	v = math.max(v, cfg.minValue)
	local nr, ng, nb = fromHsv(h, s, v)
	local out = Contrast.hexOf(nr, ng, nb)
	-- a deep red or blue stays dark even at full brightness: lifted towards white until it glows on dark ground
	for step = 1, 20 do
		if Contrast.luminance(out) >= cfg.minLuminance then
			break
		end
		out = Contrast.mix(Contrast.hexOf(nr, ng, nb), "#FFFFFF", step / 20)
	end
	return out
end

-- Hue distance on the colour wheel (0..0.5 of a turn).
local function hueGap(a: number, b: number): number
	local d = math.abs(a - b) % 1
	return math.min(d, 1 - d)
end

-- `hex` mixed towards `towards` in 5 % steps (at most `most`) until it stands out `min` against `ground`.
local function pushed(hex: string, ground: string, towards: string, min: number, most: number): string
	local out = hex
	for step = 1, 20 do
		if Contrast.contrast(out, ground) >= min or step / 20 > most + 1e-9 then
			break
		end
		out = Contrast.mix(hex, towards, step / 20)
	end
	return out
end

function BossCast.onGround(hex: string, ground: string?): Style
	local cfg = Config.Telegraph
	local g = cfg.ground
	local rim = BossCast.vivid(hex)
	local plain: Style = {
		kind = "plain",
		rim = rim,
		front = Contrast.mix(rim, "#FFFFFF", 0.55),
		area = string.upper(hex),
		under = cfg.underColor,
		underScale = 1,
	}
	if not ground or Contrast.contrast(rim, ground) >= g.rimMin then
		return plain
	end
	if Contrast.luminance(ground) >= g.light then
		-- snow, ice, sand: the same hue, deep, so the rim itself stands out (not only the dark under-rim)
		local deep = pushed(rim, ground, "#000000", g.rimMin + 0.5, g.deepMax)
		return {
			kind = "deep",
			rim = deep,
			front = Contrast.mix(deep, "#000000", 0.3),
			area = deep,
			under = cfg.underColor,
			underScale = g.underLight,
		}
	end
	local rh, rs = hsv(Contrast.rgb(rim))
	local gh, gs = hsv(Contrast.rgb(ground))
	local sameHue = rs >= g.sameSat and gs >= g.sameSat and hueGap(rh, gh) <= g.sameHue
	if sameHue or Contrast.contrast(cfg.underColor, ground) < g.rimMin then
		-- lava under fire, grass under poison, and a mid-dark rock the dark under-rim hardly marks: a white-hot rim
		-- over a wider dark under-rim
		local hot = pushed(rim, ground, "#FFFFFF", g.rimMin, g.hotMax)
		return {
			kind = "hot",
			rim = hot,
			front = Contrast.mix(hot, "#FFFFFF", 0.6),
			area = string.upper(hex),
			under = cfg.underColor,
			underScale = g.underHot,
		}
	end
	return plain
end

return BossCast
