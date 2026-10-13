--!strict
-- Mounts (S96, docs/DESIGN-15.md §2). A mount is owned per character (character.mounts.owned[id] = { lvl });
-- its look is a procedural Anatomy rig (plan "horse") unless Mounts.assets names a real model in
-- ReplicatedStorage.Assets.Mounts (assets/Mounts/<model>.rbxm). Speed comes from Config.Mount and the mount
-- level only: mounts never give combat stats. S97 adds boss / premium / event mounts, the upgrade curve and
-- skins; it only appends entries and fields here.

local Mounts = {}

export type Source = "quest" | "boss" | "premium" | "event"

-- Same shape as Logic/Anatomy.Look (kept here so Data does not require Logic, like Data/MonsterLooks.Look).
export type Look = {
	plan: string, -- "horse"
	build: { [string]: number }?, -- horse: mane (0/1), tail (0/1), feathering (0/1: fringes above the hooves)
	colors: { base: string, accent: string, detail: string?, eye: string? },
	materials: { base: string?, accent: string?, detail: string? }?,
	parts: { string }?, -- accessories (Logic/Anatomy/Accessories): saddle, bridle, saddlebags
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
		wiki = false,
		look = {
			plan = "horse",
			build = { mane = 1, tail = 1, feathering = 0 },
			colors = { base = "#6B4A2B", accent = "#2A1D14", detail = "#3A2A1A", eye = "#1C1410" },
			materials = { base = "Fabric", accent = "Fabric", detail = "Leather" },
			parts = { "saddle", "bridle", "saddlebags" },
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
