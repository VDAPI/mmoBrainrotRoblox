--!strict
-- City NPCs (DESIGN §3.2). Positions are relative to the map offset. City NPCs take their position and facing
-- from the city plan (Town.npcSpot, S21: one source of truth with the buildings); the numbers below are only
-- used when the plan has no spot for the NPC.
-- `services` are the buttons of the dialog window; their windows live on the client (NpcController).

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
-- Weaponsmith (S18, DESIGN §8a): stall between the forge and the alchemist.
npc({
	id = "weaponsmith",
	map = "city",
	nameKey = "npc.weaponsmith.name",
	greetingKey = "npc.weaponsmith.greeting",
	services = { "shop" },
	shop = "weaponsmith",
	position = { x = -150, z = -48 },
	facing = 180,
	colors = { body = "#4A3A2E", accent = "#C9CED6" },
	icon = "⚔",
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

local byId: { [string]: NpcDef } = {}
for _, def in LIST do
	byId[def.id] = def
end

return table.freeze({
	list = LIST,
	byId = byId,
	get = function(id: string): NpcDef?
		return byId[id]
	end,
	-- Max distance (studs) between a player and an NPC for any service (+ lag tolerance on the server).
	INTERACT_RANGE = 12,
})
