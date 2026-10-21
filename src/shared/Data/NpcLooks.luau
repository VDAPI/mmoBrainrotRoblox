--!strict
-- W31 (owner 2026-10-21, Studio: "about 60 NPCs stand as bare default avatars with a flat cap"): what an NPC without
-- the owner's model (ReplicatedStorage.Assets.Npcs.<id>) wears. The player's body and procedural garments
-- (Logic/CharacterLook, Util/AvatarBuild) by role, in the NPC's own colours (Data/Npcs `colors`: `body` = the main
-- cloth, `accent` = the trim; the second colour is a darker main). Faces, hair and beards are fixed here or picked
-- from the NPC's id (Logic/NpcLook: the same on every server). tests/npclook.spec keeps every NPC with a figure here,
-- the women beardless and every look within MAX_PIECES. Looks only.

local ClassLooks = require("./ClassLooks")

type Garment = ClassLooks.Garment

export type Role = {
	garments: { Garment },
	body: { [string]: string }?, -- R15 part -> colour role (default Data/ClassLooks.BODY_ROLES)
	build: string?, -- Data/ClassLooks BUILDS id (default build_medium)
}

export type Npc = {
	role: string,
	female: boolean?,
	old: boolean?, -- grey or white hair
	north: boolean?, -- fair or red hair (Frostpeak)
	add: { Garment }?, -- garments over the role's
	-- fixed look fields (Data/ClassLooks ids: face, skin, hair, hairColor, beard, build), the rest is picked
	look: { [string]: string }?,
}

local NpcLooks = {}

-- Procedural parts one NPC may wear (garments, hairstyle; Config.CharacterLook.maxPieces is the player's 28): some
-- 70 NPCs stand in the world at once, every one Persistent.
NpcLooks.MAX_PIECES = 18

-- Colours every role shares: worn leather and plain steel.
NpcLooks.LEATHER = "#5A4030"
NpcLooks.METAL = "#9AA3AD"
-- The second colour of an outfit: the main one this much darker.
NpcLooks.SECOND = 0.62

local function g(name: string, role: string?): Garment
	return { g = name, catalog = 0, role = role }
end

-- A long robe or a dress: the legs in the robe's colour down to the shoes.
local ROBE: { [string]: string } = {
	LowerTorso = "main",
	LeftUpperLeg = "main",
	RightUpperLeg = "main",
	LeftLowerLeg = "main",
	RightLowerLeg = "main",
}

NpcLooks.roles = table.freeze({
	-- city watch: mail under the city's tabard, a crested helmet
	guard = {
		garments = {
			g("chain_mail", "metal"),
			g("tabard", "trim"),
			g("helm_crest", "metal"),
			g("gauntlets", "metal"),
			g("belt", "leather"),
			g("boots", "leather"),
		},
		build = "build_strong",
	},
	-- a soldier or a warden off the wall: mail and tabard, bare head
	soldier = {
		garments = {
			g("chain_mail", "metal"),
			g("tabard", "trim"),
			g("bracers", "leather"),
			g("belt", "leather"),
			g("boots", "leather"),
		},
		build = "build_strong",
	},
	-- officers and champions: plate and a cape
	knight = {
		garments = {
			g("breastplate", "metal"),
			g("plate_pauldrons", "metal"),
			g("gauntlets", "metal"),
			g("cape", "trim"),
			g("belt", "leather"),
			g("boots", "leather"),
		},
		build = "build_strong",
	},
	-- traders: a fur collar and a sash in the trim colour
	merchant = {
		garments = { g("fur_collar", "second"), g("sash", "trim"), g("belt", "leather"), g("boots", "leather") },
	},
	-- the rich of the city: a cape, a fur collar and a chain
	noble = {
		garments = {
			g("cape", "second"),
			g("fur_collar", "trim"),
			g("amulet", "trim"),
			g("belt", "leather"),
			g("boots", "leather"),
		},
	},
	-- clergy: a long robe, the stole and the holy symbol
	priest = {
		garments = { g("robe_skirt", "main"), g("stole", "trim"), g("holy_symbol", "trim"), g("sash", "second") },
		body = ROBE,
	},
	-- monks, nuns and hermits: the hooded habit with a rope belt
	monk = {
		garments = { g("robe_skirt", "main"), g("hood", "main"), g("sash", "leather"), g("holy_symbol", "trim") },
		body = ROBE,
	},
	-- mages: robe, high collar, a mantle and the book on the belt
	mage = {
		garments = {
			g("robe_skirt", "main"),
			g("high_collar", "second"),
			g("shoulder_mantle", "trim"),
			g("belt_book", "leather"),
			g("sash", "trim"),
		},
		body = ROBE,
		build = "build_slim",
	},
	-- scholars and alchemists: robe, collar, spectacles and the book
	scholar = {
		garments = {
			g("robe_skirt", "main"),
			g("high_collar", "second"),
			g("spectacles", "metal"),
			g("belt_book", "leather"),
			g("sash", "trim"),
		},
		body = ROBE,
		build = "build_slim",
	},
	-- smiths and stoneworkers: the leather apron-vest and bracers
	smith = {
		garments = {
			g("leather_vest", "leather"),
			g("bracers", "leather"),
			g("belt", "leather"),
			g("boots", "leather"),
		},
		build = "build_strong",
	},
	-- hunters: leather, a quiver on the back
	hunter = {
		garments = {
			g("leather_vest", "leather"),
			g("quiver_back", "leather"),
			g("bracers", "leather"),
			g("belt", "leather"),
			g("boots", "leather"),
		},
	},
	-- scouts: the hood in the main colour over leather
	scout = {
		garments = {
			g("hood", "main"),
			g("leather_vest", "leather"),
			g("bracers", "leather"),
			g("belt", "leather"),
			g("boots", "leather"),
		},
	},
	-- farmers, fishers, carters, miners: a shirt, the leather vest and boots
	worker = {
		garments = { g("leather_vest", "leather"), g("belt", "leather"), g("boots", "leather") },
	},
	-- townswomen and villagers: a long dress with a sash
	dress = {
		garments = { g("robe_skirt", "main"), g("sash", "trim"), g("belt", "leather") },
		body = ROBE,
	},
	-- witches: a hooded robe, the amulet and a fur mantle
	witch = {
		garments = { g("hood", "main"), g("robe_skirt", "main"), g("amulet", "trim"), g("fur_mantle", "second") },
		body = ROBE,
	},
	-- shamans and herbalists: a robe with a wreath or a mantle
	shaman = {
		garments = { g("robe_skirt", "main"), g("fur_mantle", "second"), g("amulet", "trim"), g("wreath", "trim") },
		body = ROBE,
	},
	-- the north: furs over the shoulders
	north = {
		garments = { g("fur_mantle", "second"), g("bracers", "leather"), g("belt", "leather"), g("boots", "leather") },
		build = "build_strong",
	},
} :: { [string]: Role })

local function npc(
	role: string,
	extra: {
		female: boolean?,
		old: boolean?,
		north: boolean?,
		add: { Garment }?,
		look: { [string]: string }?,
	}?
): Npc
	if not extra then
		return { role = role }
	end
	return {
		role = role,
		female = extra.female,
		old = extra.old,
		north = extra.north,
		add = extra.add,
		look = extra.look,
	}
end

local F = { female = true }

-- Every NPC with a figure (Data/Npcs, the wandering merchant too).
NpcLooks.npcs = table.freeze({
	-- the city
	healer = npc("dress", { female = true, add = { g("belt_book", "leather"), g("amulet", "trim") } }),
	blacksmith = npc(
		"smith",
		{ add = { g("gauntlets", "metal") }, look = { beard = "beard_full", hair = "hair_shaved" } }
	),
	vendor_warrior = npc("knight", { look = { beard = "beard_short" } }),
	vendor_cleric = npc("priest", F),
	vendor_hunter = npc("hunter", { add = { g("cape", "second") } }),
	vendor_mage = npc("mage", F),
	fence = npc("merchant"),
	alchemist = npc("scholar", F),
	merchant = npc("merchant", { look = { build = "build_strong" } }),
	backpacker = npc("dress", { female = true, add = { g("belt_book", "leather") } }),
	banker = npc("noble", { add = { g("spectacles", "metal") } }),
	teacher = npc("mage", { old = true, look = { beard = "beard_long" } }),
	guildmaster = npc("noble", { look = { build = "build_strong", beard = "beard_short" } }),
	auctioneer = npc("noble", F),
	captain = npc("knight", { look = { beard = "beard_moustache" } }),
	guard1 = npc("guard"),
	guard2 = npc("guard"),
	granary_keeper = npc("merchant"),
	brother_anzelm = npc("monk"),
	fishwife = npc("dress", F),
	innkeeper = npc("worker", { add = { g("sash", "trim") }, look = { build = "build_strong", beard = "beard_full" } }),
	miller_widow = npc("dress", F),
	stablemaster = npc("worker", { add = { g("bracers", "leather") } }),
	sergeant = npc("soldier", { look = { beard = "beard_moustache" } }),
	barber = npc("merchant", { look = { beard = "beard_moustache", hair = "hair_slicked" } }),
	arenamaster = npc("knight", { look = { beard = "beard_short" } }),
	huntmaster = npc("hunter", { add = { g("cape", "second") } }),
	portalmaster = npc("mage", { add = { g("glow_seams", "trim") }, look = { beard = "beard_goatee" } }),
	wanderer = npc("merchant", { add = { g("cape", "main") }, look = { beard = "beard_short" } }),
	-- regions: the scouts
	scout_meadows = npc("scout", F),
	scout_duskwood = npc("scout"),
	scout_ashen = npc("scout", F),
	scout_frostpeak = npc("scout", { north = true }),
	-- the Meadows
	farmer_bartosz = npc("worker", { add = { g("wreath", "trim") } }),
	fisher_wit = npc("worker"),
	woodcutter_gerwazy = npc("worker", { add = { g("bracers", "leather") }, look = { build = "build_strong" } }),
	merchant_lucjan = npc("merchant"),
	miner_dobromir = npc("worker", { add = { g("bracers", "leather") }, look = { build = "build_strong" } }),
	hunter_borys = npc("hunter"),
	-- Duskwood
	forester_radomir = npc("hunter", { add = { g("cape", "second") } }),
	ghost_oswin = npc("noble", { old = true }),
	defector_jorund = npc("witch"),
	witch_ragna = npc("witch", F),
	huntress_wanda = npc("hunter", F),
	beekeeper_maciej = npc("worker", { add = { g("hood", "trim") } }),
	gravedigger_bogumil = npc("worker", { add = { g("hood", "main") } }),
	herbalist_dobrawa = npc("shaman", { female = true, add = { g("belt_book", "leather") } }),
	warden_zbyszko = npc("soldier", { add = { g("cape", "trim") } }),
	ferryman_oldrzych = npc("worker", { old = true, add = { g("hood", "main") } }),
	exorcist_kalina = npc("monk", F),
	mason_wojslaw = npc("smith"),
	-- the Ashen Wastes
	runesmith_brokk = npc("smith", { add = { g("glow_seams", "trim") }, look = { beard = "beard_long" } }),
	shaman_ghasha = npc("shaman", F),
	hermit_kaspar = npc("monk", { old = true }),
	waterkeeper_orren = npc("worker"),
	prospector_dragan = npc("worker", { add = { g("bracers", "leather") } }),
	wyvernhunter_wieslawa = npc("hunter", F),
	tombwarden_ezra = npc("soldier", { add = { g("hood", "second") } }),
	wagoner_bogna = npc("worker", F),
	-- Frostpeak
	trapper_sigrun = npc("hunter", { female = true, north = true, add = { g("fur_collar", "second") } }),
	ghost_halgrim = npc("monk", { north = true }),
	cairn_ingrid = npc("dress", { female = true, old = true, add = { g("fur_mantle", "second") } }),
	hornblower_eskil = npc("north", { north = true }),
	skald_ragnvald = npc("north", { north = true, add = { g("cape", "trim") }, look = { beard = "beard_long" } }),
	icefisher_torvi = npc("north", { north = true }),
	bonecarver_gunnar = npc("north", { north = true, look = { beard = "beard_full" } }),
	squire_asmund = npc("soldier", { north = true }),
	scholar_vigdis = npc("scholar", { female = true, north = true }),
} :: { [string]: Npc })

-- What the id picks from (Data/ClassLooks ids): faces, hairstyles, hair colours and beards.
NpcLooks.FACES = { "face_calm", "face_stern", "face_young", "face_weary", "face_scarred", "face_bearded", "face_sharp" }
NpcLooks.FACES_FEMALE = { "face_calm", "face_young", "face_freckled", "face_sharp", "face_weary" }
NpcLooks.HAIRS =
	{ "hair_short", "hair_fringe", "hair_curly", "hair_swept", "hair_slicked", "hair_charmer", "hair_shaved" }
NpcLooks.HAIRS_FEMALE = { "hair_long", "hair_straight", "hair_ponytail", "hair_braid", "hair_bangs" }
NpcLooks.HAIR_COLORS =
	{ "hc_black", "hc_dark", "hc_brown", "hc_chestnut", "hc_auburn", "hc_darkblond", "hc_blond", "hc_copper" }
NpcLooks.HAIR_COLORS_NORTH = { "hc_blond", "hc_paleblond", "hc_darkblond", "hc_red", "hc_copper" }
NpcLooks.HAIR_COLORS_OLD = { "hc_grey", "hc_white" }
NpcLooks.BEARDS = { "beard_moustache", "beard_goatee", "beard_short", "beard_full" }
-- Share of the men the id gives a beard to (the older ones all have one).
NpcLooks.BEARDED = 0.55

return table.freeze(NpcLooks)
