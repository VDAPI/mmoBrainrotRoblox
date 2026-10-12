local P = {}
local function mk(o)
	local base = {
		hs = { 180, 330 }, rad = { 130, 240 }, jud = { 320, 580 }, zeal = 8,
		ink = { faith = 10, hand = 35, relic = 8, ember = 3, brandDmg = { 80, 140 }, brandDot = { 120, 220 }, brandCd = 12,
			hammerDmg = { 260, 420 }, hammerCd = 24, judgeCdMul = 0.8, truth = 20 },
		inkPlan = { int = 3, vit = 2 },
	}
	for k, v in o or {} do
		if k == "ink" then
			for k2, v2 in v do base.ink[k2] = v2 end
		else
			base[k] = v
		end
	end
	return base
end
P.c = mk()
P.d = mk({ zeal = 10, ink = { faith = 12, hand = 40, hammerDmg = { 240, 380 }, truth = 15 } })
P.e = mk({ hs = { 190, 340 }, zeal = 10, ink = { faith = 12, hand = 40, relic = 10, brandDmg = { 90, 150 }, hammerDmg = { 240, 380 }, truth = 15 } })
P.f = mk({ hs = { 190, 340 }, zeal = 10, ink = { faith = 12, hand = 40, relic = 10, brandDmg = { 100, 170 }, brandDot = { 140, 240 }, brandCd = 10, hammerDmg = { 220, 360 }, truth = 15 } })
P.g = mk({ hs = { 190, 340 }, zeal = 10, ink = { faith = 12, hand = 40, relic = 10, brandDmg = { 100, 170 }, brandDot = { 140, 240 }, brandCd = 10, hammerDmg = { 200, 340 }, hammerCd = 30, truth = 15 } })
P.h = mk({ hs = { 190, 340 }, zeal = 10, ink = { faith = 12, hand = 40, relic = 10, ember = 4, brandDmg = { 110, 180 }, brandDot = { 150, 260 }, brandCd = 10, hammerDmg = { 200, 340 }, hammerCd = 30, truth = 15 } })
return P
