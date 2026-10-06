--!strict
-- Looks of every monster kind and boss (S24, docs/MODELE.md): body plan, proportions, colours, materials,
-- accessories, weapons, glow and particles for the procedural generator (Logic/Anatomy), and an optional real
-- model (`asset`, docs/ASSETS.md) that replaces it. Data only. `inherit` copies another entry and overrides
-- the fields given here; an inheriting entry without its own colours takes the parent's colours tinted with
-- its region (REGIONS).

export type AssetLook = {
	model: string, -- Model name in ReplicatedStorage.Assets.Monsters
	rig: "animator" | "gait" | "static",
	rootSize: { number }, -- hitbox at LookScale 1 (x, y, z)
	hipHeight: number,
	height: number, -- top of the model above the ground, for name plates
	scale: number?, -- extra ScaleTo factor
	walkSpeed: number?, -- speed the walk clip was authored for
	tint: boolean?, -- apply the region tint
	anims: { [string]: string }?, -- idle, walk, run, attack1, attack2, cast, hit, death, spawn -> "rbxassetid://..."
}

export type Phase = { tint: string, amount: number, glow: string? }

export type Look = {
	inherit: string?,
	plan: string,
	build: { [string]: number }?,
	colors: { base: string, accent: string, detail: string?, eye: string? },
	materials: { base: string?, accent: string?, detail: string? }?,
	parts: { string }?,
	weapon: string?,
	offhand: string?,
	weaponScale: number?,
	glow: string?,
	glowEyes: boolean?,
	fx: string?,
	elite: { string }?,
	elite2: { string }?,
	phases: { [number]: Phase }?,
	asset: AssetLook?,
}

export type Region = { tint: string, amount: number, glow: string?, fx: string? }

-- Region looks: inheriting entries take the parent's colours with this tint; region glow / fx are defaults.
local REGIONS: { [string]: Region } = {
	meadows = { tint = "#C9B98A", amount = 0, glow = "#FFD86E", fx = nil },
	duskwood = { tint = "#5A4A7A", amount = 0.18, glow = "#9FE0C9", fx = "mist" },
	ashen = { tint = "#3A2A22", amount = 0.15, glow = "#FF7A1A", fx = "embers" },
	frostpeak = { tint = "#B8D8F0", amount = 0.22, glow = "#9FE0FF", fx = "frost" },
}

local REGION_BY_NUMBER = { "meadows", "duskwood", "ashen", "frostpeak" }

local ANIMAL_ELITE = { "spikesBack" }
local ANIMAL_ELITE2 = { "eliteHorns" }
local FIGHTER_ELITE = { "pauldrons" }
local FIGHTER_ELITE2 = { "runes" }

-- Partial looks (inherit) may leave plan / colours out: the table is cast where needed.
local LOOKS: { [string]: any } = {
	-- Region 1: Whispering Meadows ---------------------------------------------------------------------
	rabbit = {
		plan = "hare",
		colors = { base = "#8B6B4A", accent = "#E8A0A0", detail = "#5A4636" },
	},
	wolf = {
		plan = "canine",
		build = { snout = 1.2, ears = 1, tail = 1, mane = 1 },
		colors = { base = "#6E6E72", accent = "#C9C9C9", detail = "#38383E" },
		elite = ANIMAL_ELITE,
		elite2 = ANIMAL_ELITE2,
	},
	boar = {
		plan = "boar",
		colors = { base = "#5A3D2B", accent = "#C98A8A", detail = "#2E2018" },
		elite = { "eliteHorns" },
		elite2 = { "runes" },
	},
	lynx = {
		plan = "canine",
		build = { snout = 0.75, ears = 1.15, tail = 0, mane = 0 },
		colors = { base = "#B08A5A", accent = "#E8D9B8", detail = "#3A2E24" },
		parts = { "earTufts", "spots" },
		elite = ANIMAL_ELITE,
		elite2 = ANIMAL_ELITE2,
	},
	swampToad = {
		plan = "toad",
		colors = { base = "#5E7A3A", accent = "#C9C25A", detail = "#3A4A24" },
		materials = { base = "SmoothPlastic" },
		elite = { "spikesBack", "eliteHorns" },
		elite2 = { "runes" },
	},
	carrionCrow = {
		plan = "bird",
		colors = { base = "#2A2830", accent = "#4A4652", detail = "#3A3A40", eye = "#C2352E" },
		materials = { base = "Fabric" },
	},
	bandit = {
		plan = "humanoid",
		colors = { base = "#5B4636", accent = "#3E5B33", detail = "#C9A27E" },
		materials = { base = "Leather", accent = "Leather", detail = "Leather" },
		parts = { "hood", "scarf", "pouches" },
		weapon = "saber1h",
		elite = FIGHTER_ELITE,
		elite2 = FIGHTER_ELITE2,
	},
	goblinScout = {
		plan = "humanoid",
		build = { height = 0.7, bulk = 0.85, head = 1.45, ears = 1.3, nose = 0.8 },
		colors = { base = "#6B4A2B", accent = "#8A6B4A", detail = "#6E9A3A" },
		materials = { base = "Leather", accent = "Fabric" },
		parts = { "pouches" },
		weapon = "dagger",
		elite = FIGHTER_ELITE,
		elite2 = FIGHTER_ELITE2,
	},
	caveSpider = {
		plan = "spider",
		colors = { base = "#2B2630", accent = "#7A2E3A", detail = "#4A3A44" },
		glow = "#C2352E",
		elite = { "spikesBack" },
		elite2 = { "runes" },
	},
	goblinShaman = {
		plan = "humanoid",
		build = { height = 0.72, bulk = 0.85, head = 1.45, ears = 1.2, nose = 0.6 },
		colors = { base = "#4F3A2A", accent = "#C9B26B", detail = "#5E8C3A" },
		materials = { base = "Leather", accent = "Fabric" },
		parts = { "skullMask", "feathers", "amulets" },
		weapon = "skullStaff",
		glow = "#7ACB3A",
		elite2 = { "orbitSkulls" },
	},
	koboldMiner = {
		plan = "humanoid",
		build = { height = 0.75, bulk = 0.9, hunch = 0.6, muzzle = 0.9, tail = 1 },
		colors = { base = "#8A5A3A", accent = "#C9A45C", detail = "#A86B4A" },
		materials = { base = "Leather", accent = "Fabric" },
		parts = { "lanternHelmet", "sack" },
		weapon = "pickaxe",
		elite = FIGHTER_ELITE,
		elite2 = FIGHTER_ELITE2,
	},
	brownBear = {
		plan = "bear",
		colors = { base = "#5A3A24", accent = "#8A6B4A", detail = "#2A1E16" },
		elite = ANIMAL_ELITE,
		elite2 = ANIMAL_ELITE2,
	},

	-- Region 2: Duskwood -----------------------------------------------------------------------------------
	werewolf = {
		plan = "beast",
		build = { wolf = 1, bulk = 1.05, arms = 1.15, height = 1.1 },
		colors = { base = "#4A3B30", accent = "#8E7E6A", detail = "#2E241E" },
		parts = { "mane" },
		glow = "#FFD23A",
		glowEyes = true,
		elite = ANIMAL_ELITE,
		elite2 = ANIMAL_ELITE2,
	},
	forestWraith = {
		plan = "ghost",
		build = { fade = 0.25 },
		colors = { base = "#3A4A3A", accent = "#7ACB3A", detail = "#2A2E2A" },
		parts = { "cloakTatters" },
		glow = "#7ACB3A",
		glowEyes = true,
		fx = "mist",
		elite2 = { "chains" },
	},
	rotEnt = {
		plan = "treant",
		colors = { base = "#4B3A26", accent = "#5F7D3A", detail = "#2E2418" },
		materials = { base = "Wood", accent = "Grass", detail = "Wood" },
		parts = { "mushrooms" },
		glow = "#C9E86B",
		fx = "spores",
		elite = { "moss" },
		elite2 = { "runes" },
	},
	darkCultist = {
		plan = "humanoid",
		build = { robe = 1, bulk = 0.95 },
		colors = { base = "#2A1F33", accent = "#3A2A4A", detail = "#C9A27E" },
		materials = { base = "Fabric", accent = "Fabric" },
		parts = { "hood", "runes" },
		weapon = "staff",
		glow = "#B455FF",
		elite2 = { "orbitSkulls" },
	},
	swampTroll = {
		plan = "beast",
		build = { bulk = 1.25, arms = 1.35, nose = 1.0, head = 0.8, height = 1.15 },
		colors = { base = "#4D5E3A", accent = "#2E3A24", detail = "#6E7A4A" },
		materials = { base = "SmoothPlastic" },
		parts = { "moss" },
		weapon = "club",
		weaponScale = 1.3,
		elite = { "eliteHorns" },
		elite2 = { "runes" },
	},
	skeletonGuard = {
		plan = "humanoid",
		build = { bones = 1 },
		colors = { base = "#D8D2C2", accent = "#5A5A60", detail = "#8A8478" },
		materials = { base = "SmoothPlastic", accent = "SmoothPlastic", detail = "CorrodedMetal" },
		parts = { "rustyHelmet" },
		weapon = "sword1h",
		offhand = "rustyShield",
		glow = "#9FE0FF",
		glowEyes = true,
		elite2 = { "chains" },
	},
	specter = {
		plan = "ghost",
		build = { fade = 0.45 },
		colors = { base = "#6E8FA8", accent = "#C9E3F2", detail = "#3A4A5A" },
		parts = { "chains" },
		glow = "#CFF0FF",
		glowEyes = true,
		fx = "mist",
		elite2 = { "runes" },
	},
	necromancer = {
		plan = "humanoid",
		build = { robe = 1, bulk = 0.9 },
		colors = { base = "#1F1F24", accent = "#2E3A2E", detail = "#B8B0A0" },
		materials = { base = "Fabric", accent = "Fabric" },
		parts = { "hood", "collar", "orbitSkulls" },
		weapon = "skullStaff",
		glow = "#5FA06B",
		elite2 = { "runes" },
	},
	blackBear = {
		inherit = "brownBear",
		colors = { base = "#262220", accent = "#5A4636", detail = "#1E1E24" },
		parts = { "vMark" },
	},
	ghoul = {
		plan = "beast",
		build = { gaunt = 1, bulk = 0.85, arms = 1.2, head = 0.85 },
		colors = { base = "#6E7A5A", accent = "#3A3028", detail = "#8A9478" },
		materials = { base = "SmoothPlastic" },
		parts = { "tusks" },
		glow = "#C9E86B",
		glowEyes = true,
		elite2 = { "chains" },
	},
	bogSerpent = {
		plan = "serpent",
		build = { segments = 10 },
		colors = { base = "#3A5A3A", accent = "#A8B85A", detail = "#2A3A24" },
		materials = { base = "SmoothPlastic" },
	},
	marshWitch = {
		plan = "humanoid",
		build = { hunch = 0.5, nose = 1.2, robe = 1, bulk = 0.9 },
		colors = { base = "#3A2E44", accent = "#2A3A2A", detail = "#8A9A6A" },
		materials = { base = "Fabric", accent = "Fabric" },
		parts = { "witchHat", "herbs" },
		weapon = "broom",
		glow = "#7ACB3A",
		elite2 = { "orbitSkulls" },
	},
	bloodBat = {
		plan = "bat",
		colors = { base = "#4A1E24", accent = "#7A2E34", detail = "#2A1418" },
		glow = "#FF3A3A",
	},

	-- Region 3: Ashen Wastes -------------------------------------------------------------------------------
	salamander = {
		plan = "lizard",
		colors = { base = "#B5462B", accent = "#F0A030", detail = "#6B2A1A" },
		materials = { base = "SmoothPlastic" },
		parts = { "flameSpikes" },
		glow = "#FF9A3A",
		fx = "embers",
	},
	ashOrc = {
		plan = "humanoid",
		build = { bulk = 1.35, height = 1.12 },
		colors = { base = "#4A4440", accent = "#8A3A2A", detail = "#6E7A5A" },
		materials = { base = "Leather", accent = "Metal", detail = "Leather" },
		parts = { "pauldrons", "tusks", "warPaint" },
		weapon = "axe2h",
		elite = { "hornedHelmet" },
		elite2 = { "runes" },
	},
	fireGolem = {
		plan = "golem",
		build = { cracks = 1 },
		colors = { base = "#3A2A22", accent = "#FF7A1A", detail = "#2B1F1A" },
		materials = { base = "Basalt", accent = "Basalt", detail = "Basalt" },
		glow = "#FF7A1A",
		glowEyes = true,
		fx = "embers",
		elite = { "flameSpikes" },
		elite2 = { "flameCrown" },
	},
	desertScorpion = {
		plan = "scorpion",
		colors = { base = "#C29A5B", accent = "#6B2A1A", detail = "#8A6B3A" },
		materials = { base = "SmoothPlastic", accent = "SmoothPlastic", detail = "SmoothPlastic" },
	},
	wyvern = {
		plan = "dragon",
		build = { legs = 2, wings = 1, neck = 0.8, slim = 0.2 },
		colors = { base = "#6B2E25", accent = "#C97B3A", detail = "#3A1E18" },
		materials = { base = "SmoothPlastic", accent = "Fabric", detail = "SmoothPlastic" },
		parts = { "crest" },
		fx = "embers",
	},
	renegadeDwarf = {
		plan = "humanoid",
		build = { height = 0.75, bulk = 1.35, head = 1.15 },
		colors = { base = "#6A4A32", accent = "#9A9AA2", detail = "#C9A27E" },
		materials = { base = "Leather", accent = "Metal", detail = "SmoothPlastic" },
		parts = { "hornedHelmet", "braids" },
		weapon = "hammer2h",
		weaponScale = 0.85,
		elite = FIGHTER_ELITE,
		elite2 = FIGHTER_ELITE2,
	},
	magmaGolem = {
		inherit = "fireGolem",
		build = { cracks = 1, height = 1.15 },
		colors = { base = "#2B1F1A", accent = "#FF5A1A", detail = "#1E1E24" },
		materials = { base = "CrackedLava", accent = "Basalt", detail = "Basalt" },
		glow = "#FF5A1A",
	},
	flameSmith = {
		plan = "humanoid",
		build = { bulk = 1.3, height = 1.05 },
		colors = { base = "#4A3A30", accent = "#6B4A2B", detail = "#A86B4A" },
		materials = { base = "Leather", accent = "Fabric" },
		parts = { "apron", "flameHands" },
		weapon = "smithHammer",
		glow = "#FF9A3A",
		glowEyes = true,
		fx = "embers",
	},
	wasteHyena = {
		plan = "canine",
		build = { frontHigh = 1, tail = 0, mane = 1, snout = 1.0, ears = 0.9 },
		colors = { base = "#A8865A", accent = "#E0C89A", detail = "#5A4636" },
		parts = { "spots" },
		elite = ANIMAL_ELITE,
		elite2 = ANIMAL_ELITE2,
	},
	ashVulture = {
		plan = "bird",
		build = { neck = 1 },
		colors = { base = "#4A3A3A", accent = "#C9A08A", detail = "#8A7A6A" },
	},
	fireImp = {
		plan = "humanoid",
		build = { height = 0.65, bulk = 0.85, head = 1.3, tail = 1 },
		colors = { base = "#C2352E", accent = "#FF9F1C", detail = "#8A1E1A" },
		materials = { base = "SmoothPlastic", accent = "SmoothPlastic", detail = "SmoothPlastic" },
		parts = { "horns", "wings", "flameHead" },
		glow = "#FF9F1C",
		glowEyes = true,
		fx = "embers",
	},
	basilisk = {
		plan = "lizard",
		build = { heavy = 1 },
		colors = { base = "#5A6B3A", accent = "#C9B26B", detail = "#3A4A24" },
		materials = { base = "SmoothPlastic" },
		parts = { "crest", "spikesBack" },
		glow = "#E8E25A",
		glowEyes = true,
	},
	desertMummy = {
		plan = "humanoid",
		build = { bulk = 0.85, height = 1.05 },
		colors = { base = "#D8C9A0", accent = "#C9A45C", detail = "#8A7A5A" },
		materials = { base = "Fabric", accent = "Fabric", detail = "Fabric" },
		parts = { "bandages", "crown" },
		glow = "#6BE0FF",
		glowEyes = true,
	},

	-- Region 4: Frostpeak ----------------------------------------------------------------------------------
	iceWolf = {
		inherit = "wolf",
		colors = { base = "#C8DDEB", accent = "#7FA7C9", detail = "#5A7A9A" },
		parts = { "iceSpikes" },
		fx = "frost",
	},
	yeti = {
		plan = "beast",
		build = { bulk = 1.3, arms = 1.25, height = 1.2, head = 0.95 },
		colors = { base = "#E4EAF0", accent = "#6F9AC8", detail = "#7FA0C0" },
		materials = { base = "Fabric", accent = "Fabric", detail = "SmoothPlastic" },
		elite = { "iceSpikes" },
		elite2 = { "iceArmor" },
	},
	frostGiant = {
		plan = "humanoid",
		build = { height = 1.6, bulk = 1.5 },
		colors = { base = "#7FA7C9", accent = "#3A5A7A", detail = "#B8D0E0" },
		materials = { base = "Leather", accent = "Fabric", detail = "SmoothPlastic" },
		parts = { "frostBeard", "iceArmor" },
		weapon = "iceClub",
		weaponScale = 1.4,
		glow = "#9FE0FF",
		elite = { "hornedHelmet" },
		elite2 = { "runes" },
	},
	iceElemental = {
		plan = "elemental",
		colors = { base = "#9FE0FF", accent = "#E4F6FF", detail = "#5A9AC9" },
		materials = { base = "Ice", accent = "Glass", detail = "Ice" },
		glow = "#CFF6FF",
		glowEyes = true,
		fx = "frost",
	},
	dragonspawn = {
		plan = "humanoid",
		build = { muzzle = 1, tail = 1, bulk = 1.1 },
		colors = { base = "#3A4A6B", accent = "#C9A45C", detail = "#5A6B8A" },
		materials = { base = "SmoothPlastic", accent = "Metal", detail = "SmoothPlastic" },
		parts = { "horns", "wings" },
		weapon = "spear2h",
		elite = { "pauldrons" },
		elite2 = { "runes" },
	},
	crystalGuardian = {
		plan = "golem",
		build = { crystal = 1 },
		colors = { base = "#7FD4E8", accent = "#E8FBFF", detail = "#4A9AB8" },
		materials = { base = "Glass", accent = "Ice", detail = "Glass" },
		parts = { "crystals", "runes" },
		glow = "#9FF0FF",
		glowEyes = true,
	},
	youngFrostDragon = {
		plan = "dragon",
		build = { legs = 4, wings = 1, slim = 0.3 },
		colors = { base = "#A8D8F0", accent = "#3A6A9A", detail = "#E4F6FF" },
		materials = { base = "SmoothPlastic", accent = "Fabric", detail = "Ice" },
		parts = { "iceSpikes" },
		fx = "frost",
	},
	snowLeopard = {
		inherit = "lynx",
		build = { snout = 0.8, ears = 1.0, tail = 2, mane = 0 },
		colors = { base = "#E8E4DA", accent = "#5A5A66", detail = "#9A968A" },
		parts = { "spots" },
	},
	peakHarpy = {
		plan = "bird",
		build = { harpy = 1 },
		colors = { base = "#8A9AB0", accent = "#E8E25A", detail = "#C9B8A0" },
		glow = "#E8E25A",
	},
	iceMammoth = {
		plan = "mammoth",
		colors = { base = "#7A6A5A", accent = "#E4F0F7", detail = "#4A3A2E" },
		materials = { base = "Fabric" },
		elite = { "iceSpikes" },
		elite2 = { "runes" },
	},
	frozenKnight = {
		plan = "humanoid",
		build = { bulk = 1.15, height = 1.1 },
		colors = { base = "#9FB6C9", accent = "#2F3A4A", detail = "#B8D0E0" },
		materials = { base = "Metal", accent = "Fabric", detail = "Metal" },
		parts = { "visor", "cape", "iceArmor" },
		weapon = "frostSword",
		glow = "#6BC9FF",
		glowEyes = true,
	},
	frostWyrm = {
		plan = "serpent",
		build = { segments = 11, legs = 1, wings = 1, thick = 1.2 },
		colors = { base = "#7FD4FF", accent = "#E4F0F7", detail = "#3A6A9A" },
		materials = { base = "SmoothPlastic", accent = "Fabric" },
		parts = { "iceSpikes" },
		fx = "frost",
	},

	-- Bosses -------------------------------------------------------------------------------------------------
	grimrok = {
		plan = "humanoid",
		build = { height = 0.9, bulk = 1.5, head = 1.35, ears = 1.2, nose = 0.7 },
		colors = { base = "#5A3D2B", accent = "#8A3A2A", detail = "#4F7A34" },
		materials = { base = "Leather", accent = "Leather", detail = "SmoothPlastic" },
		parts = { "hornedHelmet", "skullPauldrons", "banner", "warPaint", "pouches" },
		weapon = "cleaver",
		offhand = "skullShield",
		weaponScale = 1.15,
		glow = "#FFB25A",
		phases = { [3] = { tint = "#D64A3E", amount = 0.35, glow = "#FF3A3A" } },
	},
	morvane = {
		plan = "humanoid",
		build = { height = 1.15, robe = 1, bulk = 0.95 },
		colors = { base = "#2A1F33", accent = "#3A2A4A", detail = "#B8B0C8" },
		materials = { base = "Fabric", accent = "Fabric", detail = "SmoothPlastic" },
		parts = { "spikeCrown", "collar", "orbitSkulls", "cape" },
		weapon = "scythe",
		glow = "#9FE0C9",
		glowEyes = true,
		fx = "mist",
		phases = {
			[2] = { tint = "#9FE0C9", amount = 0.1, glow = "#B8FFE0" },
			[3] = { tint = "#9FE0C9", amount = 0.22, glow = "#E8FFF4" },
		},
	},
	azgor = {
		plan = "golem",
		build = { cracks = 1, height = 1.1 },
		colors = { base = "#3A2A22", accent = "#FF7A1A", detail = "#2B1F1A" },
		materials = { base = "Basalt", accent = "Basalt", detail = "Basalt" },
		parts = { "horns", "flameCrown", "flameSpikes" },
		weapon = "flameSword",
		weaponScale = 1.2,
		glow = "#FF7A1A",
		glowEyes = true,
		fx = "embers",
		phases = {
			[2] = { tint = "#FF9A3A", amount = 0.1, glow = "#FFB25A" },
			[3] = { tint = "#FFE8C0", amount = 0.15, glow = "#FFF2D0" },
		},
	},
	vaelgrath = {
		plan = "dragon",
		build = { legs = 4, wings = 1, neck = 1.4, span = 1.5 },
		colors = { base = "#A8D8F0", accent = "#3A6A9A", detail = "#E4F6FF" },
		materials = { base = "SmoothPlastic", accent = "Fabric", detail = "Ice" },
		parts = { "iceSpikes", "horns" },
		glow = "#9FE0FF",
		glowEyes = true,
		fx = "frost",
		phases = {
			[2] = { tint = "#E4F6FF", amount = 0.1 },
			[3] = { tint = "#6BC9FF", amount = 0.2, glow = "#FFFFFF" },
		},
	},
}

local MonsterLooks = {}

MonsterLooks.REGIONS = REGIONS
MonsterLooks.REGION_BY_NUMBER = REGION_BY_NUMBER
MonsterLooks.raw = LOOKS

local function mixHex(a: string, b: string, t: number): string
	local function ch(hex: string, i: number): number
		return tonumber(string.sub(hex, i, i + 1), 16) or 0
	end
	local out = "#"
	for i = 2, 6, 2 do
		local v = ch(a, i) + (ch(b, i) - ch(a, i)) * t
		out ..= string.format("%02X", math.clamp(math.floor(v + 0.5), 0, 255))
	end
	return out
end

-- Resolved look of `id` (inherit applied). `region` (1–4 or a region id) tints inherited colours.
function MonsterLooks.get(id: string, region: (number | string)?): Look?
	local entry = LOOKS[id]
	if not entry then
		return nil
	end
	local chain = { entry }
	local seen: { [string]: boolean } = { [id] = true }
	local current = entry
	while current.inherit do
		local parentId = current.inherit
		if seen[parentId] or not LOOKS[parentId] then
			break
		end
		seen[parentId] = true
		current = LOOKS[parentId]
		table.insert(chain, current)
	end
	local out: { [string]: any } = {}
	for i = #chain, 1, -1 do
		for key, value in chain[i] do
			if key ~= "inherit" then
				out[key] = value
			end
		end
	end
	if entry.inherit and not entry.colors and out.colors then
		local regionId = if type(region) == "number" then REGION_BY_NUMBER[region] else region
		local r = regionId and REGIONS[regionId :: string]
		if r and r.amount > 0 then
			out.colors = {
				base = mixHex(out.colors.base, r.tint, r.amount),
				accent = mixHex(out.colors.accent, r.tint, r.amount),
				detail = if out.colors.detail then mixHex(out.colors.detail, r.tint, r.amount) else nil,
				eye = out.colors.eye,
			}
		end
	end
	return out :: any
end

function MonsterLooks.has(id: string): boolean
	return LOOKS[id] ~= nil
end

return MonsterLooks
