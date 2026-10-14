--!strict
-- What the `n` of a skill's impact event means (S114, A3). Pure: VfxController asks it before it plays the pieces.
--   circleSelf                      n = the wave (Offense.circleSelf; 1 plays the full set, later waves the entry's
--                                   everyWave pieces)
--   circleTarget with waves = true  n = the wave (Cataclysm: one event per wave)
--   circleTarget without waves      n = the number of waves of the one event sent at the start (Arrow Rain, Hammer of
--                                   Heaven): the full set plays once and a piece with waves of its own reads `count`
--   anything else                   n = the target of the cast (heal 5A / 10B chain, renew / shield second target, a
--                                   trap's snare): every target plays the full set
-- (A beam tick and a projectile shot have their own branches in VfxController and never ask.)

local SkillFxWave = {}

export type Wave = {
	wave: number, -- 1 = the full set; > 1 = a later wave of the same cast
	count: number?, -- the waves one event stands for (circleTarget without per-wave events)
	target: number, -- 1 = the first target of the cast, 2.. = the next ones (chain, second target)
}

local function positive(n: number?): number?
	if type(n) ~= "number" or n ~= n or n < 1 then
		return nil
	end
	return math.floor(n)
end

function SkillFxWave.of(kind: string, perWave: boolean?, n: number?): Wave
	local value = positive(n)
	if kind == "circleSelf" or (kind == "circleTarget" and perWave == true) then
		return { wave = value or 1, count = nil, target = 1 }
	elseif kind == "circleTarget" then
		return { wave = 1, count = value, target = 1 }
	end
	return { wave = 1, count = nil, target = value or 1 }
end

return SkillFxWave
