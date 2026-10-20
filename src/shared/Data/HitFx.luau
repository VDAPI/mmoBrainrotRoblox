--!strict
-- Hit sparks of basic attacks by the target's material (S113, DESIGN-16 §5): texture key (Data/VfxTextures), colour,
-- count (before Config.Vfx limits and low quality), speed and life; `flash` adds Library.impactFlash, `puff` a small
-- smokePuff. The material comes from the same resolver as the hit sounds (S111, Logic/SfxRules.material: the look's
-- hitSound, the family's, flesh); players count as `player` ("armor"). Looks only.
export type Spark = {
	key: string,
	color: string, -- "#RRGGBB"
	count: number,
	speed: { number }, -- { min, max } studs/s
	life: { number }, -- { min, max } seconds
	gravity: number, -- studs/s² down
	flash: boolean?,
	puff: boolean?,
}

local byMaterial: { [string]: Spark } = {
	armor = {
		key = "spark",
		color = "#FFE3A0",
		count = 10,
		speed = { 12, 24 },
		life = { 0.15, 0.35 },
		gravity = 45,
		flash = true,
	},
	stone = {
		key = "spark",
		color = "#E2D8C6",
		count = 6,
		speed = { 8, 16 },
		life = { 0.2, 0.4 },
		gravity = 50,
		puff = true,
	},
	wood = { key = "spark", color = "#A07850", count = 7, speed = { 6, 14 }, life = { 0.25, 0.5 }, gravity = 40 },
	bone = { key = "iceShard", color = "#EDE6D6", count = 6, speed = { 6, 12 }, life = { 0.25, 0.45 }, gravity = 45 },
	flesh = { key = "darkSpark", color = "#3A3230", count = 6, speed = { 5, 11 }, life = { 0.25, 0.45 }, gravity = 55 },
	slime = { key = "poisonBubble", color = "#7ACB3A", count = 4, speed = { 3, 7 }, life = { 0.4, 0.6 }, gravity = 20 },
}

return table.freeze({
	byMaterial = table.freeze(byMaterial),
	default = "flesh",
	player = "armor",
	-- A critical hit: a gold impactFlash this much bigger than a material's flash, and more sparks.
	-- walka-wk: and both bodies freeze `hitstop` seconds (scaled by the "Hit feel" option)
	crit = table.freeze({ flashScale = 1.6, countMul = 1.5, hitstop = 0.05 }),
	flashSize = 2, -- studs of the material's white impactFlash
	puffSize = 0.6, -- size of the material's smokePuff
	smashTint = "#B8A888", -- the smoke of a smash (mace, hammer) at the target
	surface = 0.6, -- the sparks start this share of the root's half width in front of the target's centre
})
