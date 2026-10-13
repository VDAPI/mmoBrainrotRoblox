--!strict
-- Mounts (S96, docs/DESIGN-15.md §2). A mount is owned per character (character.mounts.owned[id] = { lvl });
-- its look is a procedural Anatomy rig (plan "horse") unless Mounts.assets names a real model in
-- ReplicatedStorage.Assets.Mounts (assets/Mounts/<model>.rbxm). Speed comes from Config.Mount and the mount
-- level only: mounts never give combat stats. S97: boss mounts (a flat personal roll of the winners, BOSS_DROPS),
-- the premium mount (Data/Products.mounts, off until the owner decides), the upgrade curve UPGRADE (the
-- stablemaster, gold and monster parts) and skins (Data/Cosmetics kind "mountskin", Logic/Mounts.lookWith).

local Mounts = {}

export type Source = "quest" | "boss" | "premium" | "event"

-- Same shape as Logic/Anatomy.Look (kept here so Data does not require Logic, like Data/MonsterLooks.Look).
export type Look = {
	plan: string, -- "horse"
	build: { [string]: number }?, -- horse: mane (0/1), tail (0/1), feathering (0/1: fringes above the hooves)
	-- cloth: caparison and plume (default detail), trim: metal plates, horns and crystals (default accent); S97
	colors: { base: string, accent: string, detail: string?, eye: string?, cloth: string?, trim: string? },
	materials: { base: string?, accent: string?, detail: string? }?,
	-- accessories (Logic/Anatomy/Accessories): saddle, bridle, saddlebags; S97: peytral, chamfron, spikes,
	-- warPaint, caparison, caparisonTorn, plume, wreath, emberCracks, frostHorns, frostCrystals
	parts: { string }?,
	glow: string?, -- S97: colour of the glowing pieces (emberCracks)
	glowEyes: boolean?, -- S97: boss mounts
}

export type MountDef = {
	id: string, -- "mount_<name>"
	nameKey: string, -- mount.<id>.name
	startLevel: number, -- 1..Config.Mount.maxLevel: the mount level a fresh copy starts at
	source: Source,
	look: Look, -- plan "horse"; scale in `scale`
	scale: number?, -- rig scale (default 1)
	boss: string?, -- S97: source = "boss": the boss id
	product: string?, -- S97: source = "premium": Data/Products id (off until the owner decides)
	wiki: boolean?, -- false: left out of the wiki (S97 publishes)
}

-- Real model hook (docs/ASSETS.md "Wierzchowce"): mount id -> a Model in ReplicatedStorage.Assets.Mounts,
-- facing -Z, its pivot on the ground between the hooves. `saddle` = where the rider sits (studs from the
-- pivot), `rig` like MonsterLooks.AssetLook ("animator": clips in `anims`, "gait": Gait_* Motor6Ds,
-- "static"), `walkSpeed` = the speed the walk clip was made for. No entry or no model: the procedural look.
export type MountAsset = {
	model: string,
	saddle: { number },
	rig: "animator" | "gait" | "static",
	walkSpeed: number?,
	anims: { [string]: string }?,
}

export type Rules = { noBiomes: { string }, noZones: { string } }

-- Rider pose (Logic/RiderPose), degrees like Data/SkillMotions (KNEEL: hip + = thigh forward, knee + = bent).
-- The third hip angle spreads the thighs outwards around the horse: + on the right hip and - on the left one, the
-- same signs as KNEEL (rHip z 6). bob = upper body lift per step (studs, two per walk cycle while moving),
-- seatLift = height of the rider's HumanoidRootPart centre above the saddle socket (studs), stride = extra stride
-- length of the mount's walk cycle (Gait.advance scale x stride: 25-42 studs/s would spin the legs too fast).
export type Rider = {
	rHip: { number },
	lHip: { number },
	rKnee: { number },
	lKnee: { number },
	bob: number,
	seatLift: number,
	stride: number,
}

local function mount(def: MountDef): MountDef
	return table.freeze(def)
end

local LIST: { MountDef } = {
	-- The stablemaster's bay horse (side quest arc "stable", S96): brown coat, black mane and tail, leather saddle.
	mount({
		id = "mount_horse",
		nameKey = "mount.mount_horse.name",
		startLevel = 1,
		source = "quest",
		look = {
			plan = "horse",
			build = { mane = 1, tail = 1, feathering = 0 },
			colors = { base = "#6B4A2B", accent = "#2A1D14", detail = "#3A2A1A", eye = "#1C1410" },
			materials = { base = "Fabric", accent = "Fabric", detail = "Leather" },
			parts = { "saddle", "bridle", "saddlebags" },
		},
	}),
	-- S97 boss mounts: the horse plan with the boss's colours and gear (no saddlebags: room for the extras within
	-- Anatomy.BUDGET.mount together with a skin). Grimrok: a heavy bay war horse in rough spiked iron with red paint.
	mount({
		id = "mount_grimrok",
		nameKey = "mount.mount_grimrok.name",
		startLevel = 3,
		source = "boss",
		boss = "grimrok",
		scale = 1.05,
		look = {
			plan = "horse",
			build = { mane = 1, tail = 1, feathering = 0 },
			colors = { base = "#7A4A26", accent = "#24180F", detail = "#3A2A1A", eye = "#1C1410", trim = "#5C5A58" },
			materials = { base = "Fabric", accent = "Fabric", detail = "Leather" },
			parts = { "saddle", "bridle", "peytral", "chamfron", "spikes", "warPaint" },
		},
	}),
	-- Morvane: a pale ash horse, a tattered black caparison, mane and tail in a faint green-blue light, glowing eyes.
	mount({
		id = "mount_morvane",
		nameKey = "mount.mount_morvane.name",
		startLevel = 4,
		source = "boss",
		boss = "morvane",
		look = {
			plan = "horse",
			build = { mane = 1, tail = 1, feathering = 0 },
			colors = {
				base = "#9C9A96",
				accent = "#7FD6C8",
				detail = "#2A262E",
				eye = "#B8F5E4",
				cloth = "#24222A",
			},
			materials = { base = "Fabric", accent = "Neon", detail = "Leather" },
			parts = { "saddle", "bridle", "caparisonTorn" },
			glowEyes = true,
		},
	}),
	-- Azgor: a black horse with ember cracks in the hide, a flame mane and tail, scorched barding.
	mount({
		id = "mount_azgor",
		nameKey = "mount.mount_azgor.name",
		startLevel = 5,
		source = "boss",
		boss = "azgor",
		look = {
			plan = "horse",
			build = { mane = 1, tail = 1, feathering = 0 },
			colors = { base = "#2A2422", accent = "#FF7A1C", detail = "#3E3634", eye = "#FFB347", trim = "#4A3E3A" },
			materials = { base = "Fabric", accent = "Neon", detail = "Leather" },
			parts = { "saddle", "bridle", "peytral", "chamfron", "emberCracks" },
			glow = "#FF8A2A",
			glowEyes = true,
		},
	}),
	-- Vaelgrath: a white-blue horse with two ice horns, frost crystals on the shoulders and a frost mane.
	mount({
		id = "mount_vaelgrath",
		nameKey = "mount.mount_vaelgrath.name",
		startLevel = 6,
		source = "boss",
		boss = "vaelgrath",
		scale = 1.05,
		look = {
			plan = "horse",
			build = { mane = 1, tail = 1, feathering = 0 },
			colors = { base = "#DCE8F0", accent = "#9FD8F5", detail = "#4A6A8A", eye = "#9FE8FF", trim = "#CFEFFF" },
			materials = { base = "Fabric", accent = "Ice", detail = "Leather" },
			parts = { "saddle", "bridle", "frostHorns", "frostCrystals" },
			glowEyes = true,
		},
	}),
	-- S97 premium (Data/Products.mounts, enabled = false until the owner decides): a snow-white charger in royal
	-- barding. startLevel 4 = a middle boss mount, below the best one (6): buying never gives the best start.
	mount({
		id = "mount_royal",
		nameKey = "mount.mount_royal.name",
		startLevel = 4,
		source = "premium",
		product = "mount_royal",
		wiki = false,
		look = {
			plan = "horse",
			build = { mane = 1, tail = 1, feathering = 0 },
			colors = {
				base = "#E8E4DA",
				accent = "#D8CFB8",
				detail = "#3A2A1A",
				eye = "#1C1410",
				cloth = "#1F2A5A",
				trim = "#D4AF37",
			},
			materials = { base = "Fabric", accent = "Fabric", detail = "Leather" },
			parts = { "saddle", "bridle", "caparison", "chamfron", "plume" },
		},
	}),
}

-- Where riding is not allowed: map biomes (Data/Maps) and zone names (ZoneService nameKey).
Mounts.RULES = table.freeze({
	noBiomes = table.freeze({ "cave", "crypt", "dungeon" }),
	noZones = table.freeze({ "zone.arena" }),
}) :: Rules

Mounts.RIDER = table.freeze({
	rHip = table.freeze({ 70, 0, 22 }),
	lHip = table.freeze({ 70, 0, -22 }),
	rKnee = table.freeze({ 75 }),
	lKnee = table.freeze({ 75 }),
	bob = 0.12,
	seatLift = 0.75,
	stride = 1.6,
}) :: Rider

-- Real models (docs/ASSETS.md "Wierzchowce"), e.g.
--   mount_horse = { model = "BayHorse", saddle = { 0, 4.4, 0.4 }, rig = "animator", walkSpeed = 26,
--       anims = { idle = "rbxassetid://...", walk = "rbxassetid://...", run = "rbxassetid://..." } },
Mounts.assets = table.freeze({}) :: { [string]: MountAsset }

-- Upgrade to mount level n (DESIGN-15 §2, S97): character level needed, gold and monster parts. The same for every
-- mount (a boss mount starts higher, so it skips the first steps). Gold priced against the level income of the S84
-- model at `level` (tests/Balance.luau levelIncome: 0.4 of it for steps 2-4, 0.55 for 5-7, 0.7 for 8-10, rounded up
-- to 500); parts of the monsters of that level band (LootTables.PARTS); see docs/BALANS.md "Wierzchowce (S97)".
export type Material = { id: string, n: number }
export type UpgradeStep = { level: number, gold: number, materials: { Material } }

local function step(level: number, gold: number, materials: { Material }): UpgradeStep
	for _, m in materials do
		table.freeze(m)
	end
	return table.freeze({ level = level, gold = gold, materials = table.freeze(materials) })
end

Mounts.UPGRADE = table.freeze({
	[2] = step(20, 1500, { { id = "goblin_ear", n = 15 }, { id = "thick_hide", n = 10 } }),
	[3] = step(25, 2000, { { id = "werewolf_claw", n = 12 } }),
	[4] = step(30, 2500, { { id = "werewolf_claw", n = 20 }, { id = "ectoplasm", n = 10 } }),
	[5] = step(40, 6000, { { id = "ectoplasm", n = 20 } }),
	[6] = step(50, 8500, { { id = "salamander_scale", n = 15 } }),
	[7] = step(60, 12500, { { id = "salamander_scale", n = 15 }, { id = "magma_shard", n = 15 } }),
	[8] = step(70, 22000, { { id = "magma_shard", n = 20 }, { id = "yeti_fur", n = 10 } }),
	[9] = step(80, 25500, { { id = "yeti_fur", n = 25 } }),
	[10] = step(90, 32000, { { id = "yeti_fur", n = 20 }, { id = "frost_scale", n = 15 } }),
}) :: { [number]: UpgradeStep }

-- Personal boss drops (DESIGN-15 §2, S97): every winner of a kill rolls once for the boss's mount and once for its
-- mount skin. Flat chances: no kills-today ladder (that is the item pity of LootTables.bosses), no luck, no party
-- split. A roll is skipped when the character already owns the mount / the account already owns the skin.
export type BossDrop = { mount: string?, mountChance: number?, skin: string?, skinChance: number? }

local function drop(def: BossDrop): BossDrop
	return table.freeze(def)
end

Mounts.BOSS_DROPS = table.freeze({
	grimrok = drop({ mount = "mount_grimrok", mountChance = 0.02 }),
	morvane = drop({ mount = "mount_morvane", mountChance = 0.015, skin = "mountskin_shade", skinChance = 0.03 }),
	azgor = drop({ mount = "mount_azgor", mountChance = 0.012, skin = "mountskin_cinder", skinChance = 0.03 }),
	vaelgrath = drop({ mount = "mount_vaelgrath", mountChance = 0.01 }),
}) :: { [string]: BossDrop }

local BY_ID: { [string]: MountDef } = {}
for _, def in LIST do
	assert(BY_ID[def.id] == nil, `Mounts: duplicate id {def.id}`)
	BY_ID[def.id] = def
end

Mounts.list = table.freeze(LIST)
Mounts.byId = table.freeze(BY_ID)

function Mounts.get(id: string): MountDef?
	return BY_ID[id]
end

return table.freeze(Mounts)
