--!strict
-- City NPCs (DESIGN §3.2). Positions are relative to the map offset. City NPCs take their position and facing
-- from the city plan (Town.npcSpot, S21: one source of truth with the buildings); the numbers below are only
-- used when the plan has no spot for the NPC.
-- `services` are the buttons of the dialog window; their windows live on the client (NpcController).

local Areas = require("./Areas")
local Town = require("./Town")

export type Service =
	"shop" -- buy / sell / buyback (shop id below)
	| "heal" -- free full restore in the city
	| "deposit"
	| "blacksmith"
	| "backpacks"
	| "alchemy" -- S07
	| "guild" -- S12
	| "auction" -- S13
	| "mail" -- S13
	| "quests" -- S11: daily contracts board
	| "story" -- S11: main story quests
	| "talk" -- S27: only conversation (side quests, gossip)
	| "vendors" -- S95: the dealer's "Where can I buy gear?" (leads to the player's class vendor, client only)
	| "mounts" -- S97: the stablemaster's mounts window (upgrades only near him)
	| "arena" -- S126: the ranked arena window (ArenaController)
	| "arenashop" -- S128: Arena Tokens shop (opens the arena window on its shop tab)
	| "look" -- S132: change face, skin and hair (the look window; paid changes only here, Logic/CharacterLook)
	| "huntshop" -- S134k: the Huntmaster's shop for Hunter's Marks (Data/HuntShop)
	| "wanderer" -- S159w: the wandering merchant's goods (Data/WanderingMerchant, WanderingMerchantController)

export type NpcDef = {
	id: string,
	map: string,
	nameKey: string,
	greetingKey: string,
	services: { Service },
	shop: string?, -- Data/Shops id for the "shop" service
	position: { x: number, z: number },
	facing: number, -- yaw in degrees
	colors: { body: string, accent: string },
	icon: string, -- glyph shown above the head
	decoration: boolean?, -- guards: no dialog
	-- "board" (S21): no figure, only an invisible anchor over a model that the world already has (the quest
	-- board of the city plan); default: a humanoid figure.
	body: "board"?,
	-- S27: random lines in the dialog instead of the greeting (npc.<id>.line1..N); the innkeeper adds gossip.
	lines: number?,
	gossip: boolean?,
	wiki: boolean?, -- S102: false = left out of the wiki until published (the series S102-S108 published in S109)
	ghost: boolean?, -- S103: a pale, half-transparent figure with a cold light (NpcService)
	-- S104: id of a main quest; the NPC is shown to a character once that quest is active or done (Logic/NpcVisibility)
	showFrom: string?,
}

local LIST: { NpcDef } = {}

local function npc(def: NpcDef)
	local spot = if def.map == "city" then Town.npcSpot(def.id) else nil
	if spot then
		def.position = { x = spot.x, z = spot.z }
		def.facing = spot.facing
	end
	table.insert(LIST, def)
end

npc({
	id = "healer",
	map = "city",
	nameKey = "npc.healer.name",
	greetingKey = "npc.healer.greeting",
	services = { "shop", "heal" },
	shop = "healer",
	position = { x = -142, z = 50 },
	facing = 0,
	colors = { body = "#EADDBE", accent = "#C2352E" },
	icon = "⚕",
})
npc({
	id = "blacksmith",
	map = "city",
	nameKey = "npc.blacksmith.name",
	greetingKey = "npc.blacksmith.greeting",
	services = { "blacksmith", "shop" },
	shop = "blacksmith",
	position = { x = -100, z = -26 },
	facing = 180,
	colors = { body = "#5A4636", accent = "#8E8E93" },
	icon = "⚒",
})
-- Class vendors (S95, DESIGN-15 §1): gear of one class each, at a place of that class (the castle keep, the temple,
-- the hunters' lodge, the mages' tower); the dealer in the armoury only buys and sells back.
local function classVendor(id: string, colors: { body: string, accent: string }, icon: string, x: number, z: number)
	npc({
		id = id,
		map = "city",
		nameKey = `npc.{id}.name`,
		greetingKey = `npc.{id}.greeting`,
		services = { "shop" },
		shop = id,
		position = { x = x, z = z },
		facing = 0,
		colors = colors,
		icon = icon,
	})
end
classVendor("vendor_warrior", { body = "#5A2E2E", accent = "#C9CED6" }, "⚔", -210, -205)
classVendor("vendor_cleric", { body = "#E8E2D0", accent = "#C8A040" }, "✚", -110, -130)
classVendor("vendor_hunter", { body = "#3E5A34", accent = "#8A6A44" }, "➶", 262, 21)
classVendor("vendor_mage", { body = "#2E3A6B", accent = "#8E7CC3" }, "✦", -246, -168)
npc({
	id = "fence",
	map = "city",
	nameKey = "npc.fence.name",
	greetingKey = "npc.fence.greeting",
	services = { "shop", "vendors" },
	shop = "fence",
	position = { x = -126, z = 33 },
	facing = 0,
	colors = { body = "#4A3A2E", accent = "#B89A6A" },
	icon = "⚖",
})
npc({
	id = "alchemist",
	map = "city",
	nameKey = "npc.alchemist.name",
	greetingKey = "npc.alchemist.greeting",
	services = { "alchemy" },
	position = { x = -190, z = -28 },
	facing = 180,
	colors = { body = "#3E5A3A", accent = "#7ACB3A" },
	icon = "⚗",
})
npc({
	id = "merchant",
	map = "city",
	nameKey = "npc.merchant.name",
	greetingKey = "npc.merchant.greeting",
	services = { "shop" },
	shop = "merchant",
	position = { x = 92, z = -48 },
	facing = 180,
	colors = { body = "#6B4A2B", accent = "#E8C25A" },
	icon = "⚖",
})
npc({
	id = "backpacker",
	map = "city",
	nameKey = "npc.backpacker.name",
	greetingKey = "npc.backpacker.greeting",
	services = { "backpacks" },
	position = { x = 130, z = -48 },
	facing = 180,
	colors = { body = "#8A6B4A", accent = "#4FA35A" },
	icon = "▣",
})
npc({
	id = "banker",
	map = "city",
	nameKey = "npc.banker.name",
	greetingKey = "npc.banker.greeting",
	services = { "deposit" },
	position = { x = 240, z = -36 },
	facing = 180,
	colors = { body = "#2F3540", accent = "#C9A45C" },
	icon = "⛃",
})
npc({
	id = "teacher",
	map = "city",
	nameKey = "npc.teacher.name",
	greetingKey = "npc.teacher.greeting",
	services = { "shop" },
	shop = "teacher",
	position = { x = -118, z = 50 },
	facing = 0,
	colors = { body = "#4A3B6B", accent = "#B455FF" },
	icon = "📜",
})
npc({
	id = "guildmaster",
	map = "city",
	nameKey = "npc.guildmaster.name",
	greetingKey = "npc.guildmaster.greeting",
	services = { "guild" },
	position = { x = -225, z = 42 },
	facing = 0,
	colors = { body = "#6B2F2A", accent = "#C9A45C" },
	icon = "⚑",
})
npc({
	id = "auctioneer",
	map = "city",
	nameKey = "npc.auctioneer.name",
	greetingKey = "npc.auctioneer.greeting",
	services = { "auction", "mail" },
	position = { x = 185, z = -32 },
	facing = 180,
	colors = { body = "#2A3A5A", accent = "#4A8FE7" },
	icon = "⚱",
})
npc({
	id = "questboard",
	map = "city",
	nameKey = "npc.questboard.name",
	greetingKey = "npc.questboard.greeting",
	services = { "quests" },
	position = { x = 28, z = -36 },
	facing = 160,
	colors = { body = "#6B4A2B", accent = "#EADDBE" },
	icon = "✎",
	body = "board", -- S21: the notice board on the market (Town plan, TownGen Props)
})
-- Main story (S11): the captain of the guard on the plaza and a scout at the entrance of every region.
npc({
	id = "captain",
	map = "city",
	nameKey = "npc.captain.name",
	greetingKey = "npc.captain.greeting",
	services = { "story" },
	position = { x = -22, z = 46 },
	facing = 270,
	colors = { body = "#7A1F2B", accent = "#C9A45C" },
	icon = "⚑",
})
for _, region in { "meadows", "duskwood", "ashen", "frostpeak" } do
	npc({
		id = `scout_{region}`,
		map = region,
		nameKey = `npc.scout_{region}.name`,
		greetingKey = `npc.scout_{region}.greeting`,
		services = { "story" },
		position = { x = -690, z = -36 },
		facing = 0,
		colors = { body = "#4F6B2E", accent = "#C9A45C" },
		icon = "⚑",
	})
end
for i, position in { { x = 272, z = -16 }, { x = 272, z = 16 } } do
	npc({
		id = `guard{i}`,
		map = "city",
		nameKey = "npc.guard.name",
		greetingKey = "npc.guard.name",
		services = {},
		position = position,
		facing = 90,
		colors = { body = "#8E96A3", accent = "#C2352E" },
		icon = "⛨",
		decoration = true,
	})
end

-- Side quest givers in the city (S27): by their buildings, spots in Data/Town/npcExtra (hand-placed next to the
-- generated plan).
local function townsfolk(id: string, colors: { body: string, accent: string }, icon: string, extra: any)
	local e: any = extra or {}
	npc({
		id = id,
		map = "city",
		nameKey = `npc.{id}.name`,
		greetingKey = `npc.{id}.greeting`,
		services = e.services or { "talk" },
		shop = e.shop,
		position = { x = 0, z = 0 }, -- from Town.npcSpot
		facing = 0,
		colors = colors,
		icon = icon,
		lines = e.lines or 3,
		gossip = e.gossip,
	})
end

townsfolk("granary_keeper", { body = "#8A7A52", accent = "#5A4A2E" }, "⚖")
townsfolk("brother_anzelm", { body = "#5A4A3A", accent = "#2E2620" }, "✝")
townsfolk("fishwife", { body = "#3E6B5A", accent = "#C9B98A" }, "🐟")
townsfolk("innkeeper", { body = "#7A3E2A", accent = "#E8D8B0" }, "🍺", { gossip = true })
townsfolk("miller_widow", { body = "#4A4A52", accent = "#1E1E22" }, "⚙")
townsfolk("stablemaster", { body = "#6B4A2B", accent = "#3A2A1A" }, "🐎", { services = { "talk", "mounts" } })
townsfolk("sergeant", { body = "#8E96A3", accent = "#7A1F2B" }, "⚔")
-- S132 (DESIGN-17 §9a): the barber by the cloth stall on the market square: the paid look change (gold)
townsfolk("barber", { body = "#4A3A5A", accent = "#C9B98A" }, "✂", { services = { "talk", "look" } })

-- S126: the Arena Master by the north gate of Ristalle (Data/Town/npcExtra), the ranked arena window.
npc({
	id = "arenamaster",
	map = "city",
	nameKey = "npc.arenamaster.name",
	greetingKey = "npc.arenamaster.greeting",
	services = { "arena", "arenashop" },
	position = { x = 0, z = 0 }, -- from Town.npcSpot
	facing = 0,
	colors = { body = "#6B2A24", accent = "#C8A040" }, -- the crimson and gold of the lord's box of Ristalle
	icon = "🏆",
	lines = 3,
})

-- S134k (DESIGN-15 §3.3): the Huntmaster by the contract board (Data/Town/npcExtra): takes and hands in the hunting
-- contracts like the board ("quests" opens the journal's hunting tab) and keeps the shop for Hunter's Marks.
townsfolk(
	"huntmaster",
	{ body = "#4F5A2E", accent = "#A8743A" },
	"➶",
	{ services = { "talk", "quests", "huntshop" } }
)

-- S102: an NPC of a region map standing on a prepared spot of Areas.byMap[map].npcSpots (S27 on the Meadows, S103-S108
-- elsewhere); `extra.services` / `shop` / `wiki` as for townsfolk; S103: `extra.ghost`; S104: `extra.showFrom`.
local function regionfolk(
	map: string,
	id: string,
	spot: string,
	colors: { body: string, accent: string },
	icon: string,
	extra: any?
)
	local data = Areas.byMap[map]
	local spots: { [string]: Areas.NpcSpot } = if data then data.npcSpots or {} else {}
	local place = assert(spots[spot], `{map} npc spot {spot}`)
	local e: any = extra or {}
	npc({
		id = id,
		map = map,
		nameKey = `npc.{id}.name`,
		greetingKey = `npc.{id}.greeting`,
		services = e.services or { "talk" },
		shop = e.shop,
		position = { x = place.x, z = place.z },
		facing = place.facing,
		colors = colors,
		icon = icon,
		lines = 3,
		wiki = e.wiki,
		ghost = e.ghost,
		showFrom = e.showFrom,
	})
end

-- Side quest NPCs on the Whispering Meadows (S27), on the places S26 prepared (Areas/meadows npcSpots).
local function meadowsfolk(id: string, spot: string, colors: { body: string, accent: string }, icon: string, extra: any)
	regionfolk("meadows", id, spot, colors, icon, extra)
end

meadowsfolk("farmer_bartosz", "farmer", { body = "#7A6A3A", accent = "#C9A45C" }, "🌾")
meadowsfolk(
	"fisher_wit",
	"fisher",
	{ body = "#4A5A4A", accent = "#8A7A5A" },
	"🎣",
	{ services = { "talk", "shop" }, shop = "fisher" }
)
meadowsfolk("woodcutter_gerwazy", "woodcutter", { body = "#6B2F2A", accent = "#3A2A1A" }, "🪓")
meadowsfolk("merchant_lucjan", "merchant", { body = "#2A3A5A", accent = "#C9A45C" }, "⚖")
meadowsfolk(
	"miner_dobromir",
	"miner",
	{ body = "#5A5650", accent = "#C9A45C" },
	"⛏",
	{ services = { "talk", "shop" }, shop = "miner" }
)
meadowsfolk("hunter_borys", "hunter", { body = "#4F5A2E", accent = "#6B4A2B" }, "🏹")

-- Story NPCs of Duskwood (S103, docs/FABULA.md §2.3), on the places of Areas/duskwood npcSpots.
regionfolk("duskwood", "forester_radomir", "radomir", { body = "#4A5236", accent = "#6B4A2B" }, "🌲")
regionfolk("duskwood", "ghost_oswin", "oswin", { body = "#B8D4D0", accent = "#6E8C9A" }, "⚜", { ghost = true })
regionfolk("duskwood", "defector_jorund", "jorund", { body = "#4A4A52", accent = "#7A4AA0" }, "🕯")
regionfolk("duskwood", "witch_ragna", "ragna", { body = "#3E4A36", accent = "#8A7A5A" }, "🌿")

-- S106: Duskwood side arc NPCs (Data/Quests/Side arcs K-R), on the places of Areas/duskwood npcSpots.
regionfolk("duskwood", "huntress_wanda", "huntress", { body = "#3A4A5A", accent = "#7FB8FF" }, "🏮")
regionfolk("duskwood", "beekeeper_maciej", "beekeeper", { body = "#6B5A2E", accent = "#D8A43A" }, "🐝")
regionfolk("duskwood", "gravedigger_bogumil", "gravedigger", { body = "#3A3A3E", accent = "#8A7A5E" }, "⚰")
regionfolk("duskwood", "herbalist_dobrawa", "herbalist", { body = "#4A5A3A", accent = "#B8C08A" }, "🌿")
regionfolk("duskwood", "warden_zbyszko", "warden", { body = "#5A5650", accent = "#7A1F2B" }, "🛡")
regionfolk("duskwood", "ferryman_oldrzych", "ferryman", { body = "#3E4A3A", accent = "#8A7A58" }, "🛶")
regionfolk("duskwood", "exorcist_kalina", "exorcist", { body = "#E8E2D0", accent = "#5A4A3A" }, "🕯")
regionfolk("duskwood", "mason_wojslaw", "mason", { body = "#6E6A64", accent = "#6E2F2A" }, "⚒")

-- Story NPCs of the Ashen Wastes (S104, docs/FABULA.md §2.4), on the places of Areas/ashen npcSpots. Brokk reaches
-- Kesra's camp with deadOasis, Ghasha the Hot Spring once freed in warcampCages (NpcDef.showFrom); Kaspar always stands
-- before his temple.
regionfolk(
	"ashen",
	"runesmith_brokk",
	"runesmith",
	{ body = "#4A3A2E", accent = "#6FB8FF" },
	"✦",
	{ services = { "story" }, showFrom = "deadOasis" }
)
regionfolk(
	"ashen",
	"shaman_ghasha",
	"shaman",
	{ body = "#4A5A3A", accent = "#A3282A" },
	"☽",
	{ showFrom = "warcampCages" }
)
regionfolk("ashen", "hermit_kaspar", "hermit", { body = "#4A4236", accent = "#C9A45C" }, "✝")

-- S107: Ashen side arc NPCs (Data/Quests/Side arcs S-Z), on the places of Areas/ashen npcSpots.
regionfolk("ashen", "waterkeeper_orren", "waterkeeper", { body = "#5A6B7A", accent = "#C9B98A" }, "💧")
regionfolk("ashen", "prospector_dragan", "prospector", { body = "#6B5A48", accent = "#C9A45C" }, "⚒")
regionfolk("ashen", "wyvernhunter_wieslawa", "wyvernhunter", { body = "#6B3A2A", accent = "#B8C0C8" }, "🏹")
regionfolk("ashen", "tombwarden_ezra", "tombwarden", { body = "#B8A47A", accent = "#3A6B6B" }, "⚱")
regionfolk("ashen", "wagoner_bogna", "wagoner", { body = "#7A5A3A", accent = "#3A2A1A" }, "🐂")

-- Story NPCs of the Frost Peaks (S105, docs/FABULA.md §2.5), on the places of Areas/frostpeak npcSpots. Both always
-- stand there (no showFrom): Sigrun in the abandoned trappers' camp, the ghost of Brother Halgrim before the Ice Watch's
-- keep, also after the oath (one NPC for everyone; his lines hold before and after it). S108 gives Sigrun side arcs.
regionfolk("frostpeak", "trapper_sigrun", "trapper", { body = "#6B5A44", accent = "#C9C2B0" }, "🐾")
regionfolk("frostpeak", "ghost_halgrim", "halgrim", { body = "#BFD3E0", accent = "#2F3A4A" }, "⛨", { ghost = true })

-- S108: Frost Peaks side arc NPCs (Data/Quests/Side arcs fp_*), on the places of Areas/frostpeak npcSpots with a small
-- camp behind each (Logic/FrostpeakGen/SideCamps).
regionfolk("frostpeak", "cairn_ingrid", "cairn", { body = "#5A4A5E", accent = "#C9A45C" }, "🎗")
regionfolk("frostpeak", "hornblower_eskil", "horn", { body = "#4A5A6B", accent = "#B8862E" }, "📯")
regionfolk("frostpeak", "skald_ragnvald", "skald", { body = "#6B3A2A", accent = "#D8C8A0" }, "📜")
regionfolk("frostpeak", "icefisher_torvi", "icefisher", { body = "#3E5A6B", accent = "#9FC8D8" }, "🎣")
regionfolk("frostpeak", "bonecarver_gunnar", "bonecarver", { body = "#5A5046", accent = "#E8DCC0" }, "🦴")
regionfolk("frostpeak", "squire_asmund", "squire", { body = "#5E6670", accent = "#7A1F2B" }, "🛡")
regionfolk("frostpeak", "scholar_vigdis", "scholar", { body = "#2E3A5A", accent = "#C9A45C" }, "📖")

local byId: { [string]: NpcDef } = {}
for _, def in LIST do
	byId[def.id] = def
end

-- S159w (owner 2026-10-20): the wandering merchant Radoslav (Data/WanderingMerchant). He has no fixed place, so he is
-- not in `list` (the map pins, the wiki, the guide and the NPC placement read `list`); `get` finds him and
-- WanderingMerchantService places his figure (NpcService.PlaceAt) where the visit is. `map` / `position` below are only
-- the fallback of code that reads them.
local WANDERER: NpcDef = {
	id = "wanderer",
	map = "city",
	nameKey = "npc.wanderer.name",
	greetingKey = "npc.wanderer.greeting",
	services = { "talk", "wanderer" },
	position = { x = 8, z = -48 },
	facing = 180,
	colors = { body = "#7A3E5A", accent = "#D8A43A" }, -- a plum coat and a saffron hat, the colours of his canvas
	icon = "⚖",
	lines = 3,
	wiki = false,
}
byId[WANDERER.id] = WANDERER

return table.freeze({
	list = LIST,
	byId = byId,
	get = function(id: string): NpcDef?
		return byId[id]
	end,
	-- Max distance (studs) between a player and an NPC for any service (+ lag tolerance on the server).
	INTERACT_RANGE = 12,
	-- S102: NPCs of later sessions on region spots (exported for tests/story.spec)
	regionfolk = regionfolk,
	WANDERER = WANDERER, -- S159w (wandering merchant)
})
