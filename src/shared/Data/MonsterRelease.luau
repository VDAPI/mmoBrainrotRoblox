--!strict
-- S162m (owner 2026-10-25, docs/ANIM-WZORCE §1.3 rule 8): where a monster's shot leaves its body (the mouth, the beak,
-- the casting hand), so an arrow, a bolt or the Elite II's throw no longer starts in the middle of the model. Shares of
-- the drawn height `h` (the look's height x LookScale x the model's `visual`, Data/MonsterAssets): `up` from the feet,
-- `fwd` ahead of the root's centre, `side` to the right. Entities/RigBuilder puts an Attachment "Muzzle" on the root
-- there; CombatService starts the shot's projectile at it (`fwd` and `side` move the server's start, `up` is only
-- drawn: the bolt drops to its flight height, Vfx/HazardFx). A kind takes its body plan's point, a table entry may
-- move it. Data only.

export type Release = { up: number, fwd: number, side: number }
type Entry = string | { plan: string, up: number?, fwd: number?, side: number? }

-- Body plans (the families of docs/ANIM-WZORCE §0 and the shapes of the rigid models).
local PLANS: { [string]: Release } = {
	biped = { up = 0.62, fwd = 0.2, side = 0.14 }, -- the casting / throwing hand at chest height, a little ahead
	quadruped = { up = 0.6, fwd = 0.42, side = 0 }, -- the jaw at the front of the head
	flyer = { up = 0.68, fwd = 0.32, side = 0 }, -- the beak (a hovering body: h counts from the ground)
	dragon = { up = 0.7, fwd = 0.48, side = 0 }, -- the jaw at the end of a long neck
	crawler = { up = 0.42, fwd = 0.42, side = 0 }, -- the front top of a low body (fangs, a toad's mouth, a pincer)
	serpent = { up = 0.62, fwd = 0.32, side = 0 }, -- the raised head
	float = { up = 0.6, fwd = 0.2, side = 0 }, -- the front of a floating spirit
}

-- Every kind and boss look (Data/Monsters, Data/Bosses); tests/monstermove.spec checks the list is complete.
local KINDS: { [string]: Entry } = {
	-- F1 humanoids, brutes, golems, ghosts on Mixamo rigs; bosses
	bandit = "biped",
	goblinScout = "biped",
	goblinShaman = "biped",
	koboldMiner = "biped",
	werewolf = "biped",
	forestWraith = "biped",
	darkCultist = "biped",
	swampTroll = "biped",
	skeletonGuard = "biped",
	necromancer = "biped",
	ghoul = "biped",
	marshWitch = "biped",
	ashOrc = "biped",
	fireGolem = "biped",
	renegadeDwarf = "biped",
	magmaGolem = "biped",
	flameSmith = "biped",
	fireImp = "biped",
	desertMummy = "biped",
	yeti = "biped",
	frostGiant = "biped",
	dragonspawn = "biped",
	crystalGuardian = "biped",
	frozenKnight = "biped",
	rotEnt = { plan = "biped", up = 0.66, side = 0.2 }, -- a branch arm
	grimrok = "biped",
	morvane = "biped",
	azgor = "biped",
	hrimvald = "biped",
	-- F2 quadrupeds
	rabbit = "quadruped",
	wolf = "quadruped",
	iceWolf = "quadruped",
	lynx = "quadruped",
	snowLeopard = "quadruped",
	wasteHyena = { plan = "quadruped", up = 0.5 }, -- the head is carried low
	boar = { plan = "quadruped", up = 0.45, fwd = 0.45 }, -- the snout and tusks low in front
	brownBear = "quadruped",
	blackBear = "quadruped",
	iceMammoth = { plan = "quadruped", up = 0.55, fwd = 0.4 }, -- the trunk's root
	-- F3 flyers (the crow and the bat are rigid flyers)
	ashVulture = "flyer",
	carrionCrow = "flyer",
	bloodBat = "flyer",
	peakHarpy = { plan = "flyer", up = 0.62, fwd = 0.22, side = 0.14 }, -- the wing hand of an upright body
	-- F4 dragons
	youngFrostDragon = "dragon",
	wyvern = "dragon",
	vaelgrath = "dragon",
	-- F5 rigid models
	caveSpider = "crawler",
	basilisk = "crawler",
	salamander = "crawler",
	swampToad = { plan = "crawler", up = 0.5, fwd = 0.38 },
	desertScorpion = "crawler",
	bogSerpent = "serpent",
	frostWyrm = "serpent",
	specter = "float",
	iceElemental = "float",
}

local function resolve(id: string): Release
	local entry = KINDS[id] or "biped"
	if type(entry) == "string" then
		return PLANS[entry] or PLANS.biped
	end
	local base = PLANS[entry.plan] or PLANS.biped
	return {
		up = entry.up or base.up,
		fwd = entry.fwd or base.fwd,
		side = entry.side or base.side,
	}
end

return table.freeze({
	PLANS = PLANS,
	KINDS = KINDS,
	-- The release shares of a kind or boss look (an unknown id: the biped hand).
	of = resolve,
	-- The body plan of a kind or boss look (nil = not listed).
	planOf = function(id: string): string?
		local entry = KINDS[id]
		if entry == nil then
			return nil
		end
		return if type(entry) == "string" then entry else entry.plan
	end,
})
