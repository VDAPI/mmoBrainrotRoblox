--!strict
-- W30 (owner: "animacje wszystkiego ... particle a nie okrągłe kółko"): the Hunter and Mage skill pieces of
-- client/Vfx/LmHunterMage (prefix `lm`), described here so the tests can check them without Roblox:
--   layer  the layer of the three (tests/SkillLooks.PIECE_LAYER): core (the flash), body (the shape), trail (what stays)
--   cost   what the piece holds at once at its peak (tests/SkillLooks.PIECE_COST: emitter / beam / light / decal
--          holders); most lm pieces are plain pooled parts (neon, glass, force field) and cost nothing
--   phase  where SkillVfx lists it: "impact" (impact, trigger, strike, allies: VfxController.piece), "cast" (castFx: at
--          the cast's start, while the spell gathers), "release" (releaseFx: when the shot leaves the hand / the tip),
--          "flight" (flight: the projectile's own flight instead of Vfx/Library.projectile)
--   immediate  (impact) plays with the event even when the entry's blow lands `d` later (SkillVfx.landsAfter): the
--          rift the meteor falls out of
-- Looks only: nothing here changes damage, timing or rules.

export type Layer = "core" | "body" | "trail"
export type Phase = "impact" | "cast" | "release" | "flight"
export type Cost = { emitters: number, beams: number, lights: number, decals: number }
export type Spec = { layer: Layer, cost: Cost, phase: Phase, immediate: boolean? }

local function c(emitters: number, beams: number, lights: number, decals: number): Cost
	return { emitters = emitters, beams = beams, lights = lights, decals = decals }
end

local function spec(layer: Layer, phase: Phase, cost: Cost, immediate: boolean?): Spec
	return { layer = layer, phase = phase, cost = cost, immediate = immediate }
end

local FREE = c(0, 0, 0, 0)

local LmVfxPieces: { [string]: Spec } = {
	-- cast and release (Hunter and Mage)
	lmCharge = spec("body", "cast", c(0, 0, 1, 0)), -- motes spiralling into the hand / tip, a core swelling, a light
	lmMuzzle = spec("core", "release", c(1, 0, 0, 0)), -- a shock disc where the shot leaves, a forward spray of streaks
	lmSkyVolley = spec("body", "release", FREE), -- arrows shot up into the sky before a rain falls
	lmSpiral = spec("body", "release", FREE), -- two motes winding round the shot's path (Heartseeker)
	lmMissiles = spec("body", "flight", FREE), -- arcane missiles curving to the target, arriving together
	-- Hunter impacts
	lmSplinters = spec("trail", "impact", FREE), -- wood splinters and a chip of the head thrown back from the hit
	lmStuckArrow = spec("trail", "impact", FREE), -- the arrow stays in the target (or the ground), quivering
	lmShockRings = spec("body", "impact", FREE), -- a tunnel of shock rings along a piercing shot
	lmRainShadow = spec("body", "impact", FREE), -- the shadow of the falling arrows darkening the circle
	lmGust = spec("body", "impact", FREE), -- streaks of wind tearing through a cone
	lmTrapArm = spec("body", "impact", FREE), -- beads closing on the trap, three blinks: armed
	lmSpringJaws = spec("body", "impact", FREE), -- steel teeth snapping shut where a trap springs
	lmVenomSplash = spec("trail", "impact", FREE), -- venom drops flung out, puddles where they land
	lmReticle = spec("body", "impact", FREE), -- a reticle closing on the prey, a mark over its head
	lmPinRing = spec("body", "impact", FREE), -- stakes driven round the target's feet, a binding ring
	lmAfterimage = spec("body", "impact", FREE), -- ghosts of the body left where the dash started
	lmWindRibbons = spec("body", "impact", FREE), -- ribbons of wind winding up round the caster
	lmNet = spec("body", "impact", FREE), -- a net spreading as it drops over the circle
	-- Mage impacts
	lmRift = spec("body", "impact", c(1, 0, 0, 0)), -- a tear in the air at both ends of a blink
	lmExplosion = spec("core", "impact", c(0, 0, 1, 0)), -- the core of a blast: a white-hot core, a fire shell, a heat shell, a ground ring
	lmDebris = spec("trail", "impact", FREE), -- rock chunks (some molten) thrown out, bouncing once
	lmEmbers = spec("trail", "impact", c(1, 0, 0, 0)), -- embers drifting up for a second
	lmForkBolt = spec("body", "impact", c(0, 0, 1, 0)), -- a jagged bolt with forks (sky, link or line)
	lmArcCrawl = spec("trail", "impact", FREE), -- small arcs crawling over the struck body
	lmFlameJet = spec("body", "impact", c(1, 0, 0, 0)), -- tongues of flame roaring through a cone
	lmBubble = spec("body", "impact", FREE), -- a shimmering shield sphere popping on, then off
	lmSkyRift = spec("body", "impact", FREE, true), -- the burning rift the meteor falls out of
	lmVortex = spec("body", "impact", FREE), -- motes in a rising helix round the caster
	lmRuneRings = spec("body", "impact", FREE), -- two counter-turning rings of runes round a channel
	lmHelix = spec("body", "impact", FREE), -- two motes winding along a beam to its target every tick
	lmHail = spec("body", "impact", FREE), -- ice chunks falling into the circle, shattering
	lmOrbPulse = spec("body", "impact", c(0, 0, 1, 0)), -- a big pulsing orb over the circle every wave
	lmIceSpikes = spec("body", "impact", c(1, 0, 0, 0)), -- crystals bursting from the ground (ring, cluster, encase)
}

return table.freeze(LmVfxPieces)
