--!strict
-- Story cutscenes (S102, FABULA §2.1): "chapter" = chapter card, "scene" = a short shot with 2–4 lines. Once per
-- character (quests.scenes), skippable, replayable; queued by QuestService, played by CutsceneController when idle.
-- Texts: cutscene.<id>.title / .l1..lN. People who are not NPCs (Ilvar) appear only as figures.
-- Rules (triggers, queue order, camera path, line times, validation): Logic/Cutscenes; timing: Config.Cutscene.
-- S103: the ten scenes of chapter II "The Forgotten House" (Duskwood); figures may be ghosts (`ghost`: a projection
-- or a spirit, half-transparent in a cold light) and wear a crown (FIGURES.queen); Brother Anzelm stands by the
-- captain as a figure (the city NPC stays in the temple). Shots on a cave map (the Tomb of Morvane) take the ground
-- from Logic/CaveTerrain, not a ray from the sky.

local Npcs = require("./Npcs")

export type Shot = {
	-- "city": Town.city.selectCamera; "point": map, x, z; "npc": an NPC (yaw = its facing); "anchor": a quest
	-- anchor (Areas.anchorById); "self": the player's character.
	kind: "city" | "point" | "npc" | "anchor" | "self",
	map: string?,
	x: number?,
	z: number?,
	npc: string?,
	anchor: string?,
	lift: number?, -- focus height over the ground (studs, default Config.Cutscene.lift)
	yaw: number?, -- direction from the focus to the eye, degrees; front of yaw 0 = (-sin 0, -cos 0) like the city plan
	dist: number?, -- eye distance from the focus (default Config.Cutscene.dist)
	height: number?, -- eye height over the focus (default Config.Cutscene.height)
	orbit: number?, -- degrees the eye turns around the focus over the whole shot (default 10)
	push: number?, -- studs the eye moves towards the focus over the whole shot (default 4)
}
export type Line = { who: string?, key: string } -- who: NPC id, "boss:<bossId>", a WHO key, or nil = narration
export type Figure = {
	look: string,
	x: number,
	z: number,
	facing: number,
	fade: ("frost" | "none")?,
	ghost: boolean?, -- S103: half-transparent with a cold light in the trim's colour (Ilvar's projection, a spirit)
}
export type Scene = {
	id: string,
	kind: "chapter" | "scene",
	quest: string, -- Data/Quests/Main id
	on: "accept" | "objective" | "complete" | "turnIn",
	index: number?, -- "objective": which objective (1-based)
	shot: Shot,
	title: string?, -- locale key of the big title ("chapter" kind, or an end card)
	subtitle: string?, -- locale key under the title (story.chapter.<n> for chapter cards)
	lines: { Line },
	figures: { Figure }?, -- client-only figures placed for the shot (map of the shot, map-relative x / z)
	light: { color: string, range: number }?, -- a warm light at the focus (candle, fire)
	clock: number?, -- show the shot's map at this time of day (0..24); nil = as it is now
}

-- Who speaks: locale keys of speakers that are not NPCs or bosses.
local WHO: { [string]: string } = {
	ilvar = "cutscene.who.ilvar",
	queen = "cutscene.who.queen", -- S103: the spirit of Queen Morvane after the fight (not the boss any more)
}

-- Looks of the figures (colours of the robe, the hood and the trim).
local FIGURES: { [string]: { robe: string, hood: string, trim: string, crown: string? } } = {
	ilvar = { robe = "#7E8288", hood = "#5E6268", trim = "#C8DDF0" },
	-- S103: Brother Anzelm by the captain (the city NPC's colours) and the young queen with a crown of thorns
	anzelm = { robe = "#5A4A3A", hood = "#2E2620", trim = "#C9A45C" },
	queen = { robe = "#9FE0C9", hood = "#6E9C8E", trim = "#E8FFF6", crown = "#3A4A44" },
}

local function line(who: string?, key: string): Line
	return { who = who, key = key }
end

local function figure(
	look: string,
	x: number,
	z: number,
	facing: number,
	fade: ("frost" | "none")?,
	ghost: boolean?
): Figure
	return { look = look, x = x, z = z, facing = facing, fade = fade, ghost = ghost }
end

-- S103: Brother Anzelm as a figure 3.5 studs to the captain's left (both facing the camera of an "npc" shot).
local function besideCaptain(): Figure
	local captain = assert(Npcs.get("captain"), "captain")
	local r = math.rad(captain.facing)
	-- the captain's left: his front (-sin, -cos) turned 90 degrees
	local lx, lz = -math.cos(r), math.sin(r)
	return figure("anzelm", captain.position.x + lx * 3.5, captain.position.z + lz * 3.5, captain.facing, "none")
end

-- The seven scenes of chapter I "The Frost Sign" and (S103) the ten of chapter II "The Forgotten House" (order =
-- playing order when several are queued).
local list: { Scene } = {
	{
		-- the chapter card over the city when the first quest is taken
		id = "ch1_open",
		kind = "chapter",
		quest = "arrival",
		on = "accept",
		shot = { kind = "city", push = 30, orbit = 6 },
		title = "cutscene.ch1_open.title",
		subtitle = "story.chapter.1",
		lines = { line("captain", "cutscene.ch1_open.l1"), line("captain", "cutscene.ch1_open.l2") },
	},
	{
		-- Mira on the road behind the Meadows gate (the eye on the gate's side, looking east)
		id = "portal_gate",
		kind = "scene",
		quest = "portal",
		on = "objective",
		index = 1,
		shot = { kind = "point", map = "meadows", x = -700, z = -30, yaw = 270, dist = 26, height = 7 },
		lines = { line("scout_meadows", "cutscene.portal_gate.l1"), line("scout_meadows", "cutscene.portal_gate.l2") },
	},
	{
		-- the frosted crest on the tower ruins (the anchor's frost effect is already shown)
		id = "frost_ruins",
		kind = "scene",
		quest = "frostRuins",
		on = "objective",
		index = 2,
		shot = { kind = "anchor", anchor = "tower_crest", dist = 16, height = 6, orbit = 20 },
		lines = { line(nil, "cutscene.frost_ruins.l1"), line(nil, "cutscene.frost_ruins.l2") },
	},
	{
		-- Aldric reads the bandits' orders
		id = "bandit_orders",
		kind = "scene",
		quest = "banditOrders",
		on = "turnIn",
		shot = { kind = "npc", npc = "captain", dist = 9, height = 3, lift = 4.5 },
		lines = {
			line("captain", "cutscene.bandit_orders.l1"),
			line("captain", "cutscene.bandit_orders.l2"),
			line("captain", "cutscene.bandit_orders.l3"),
		},
	},
	{
		-- Brother Anzelm by candlelight names Ilvar
		id = "frost_sign",
		kind = "scene",
		quest = "frostSign",
		on = "objective",
		index = 3,
		shot = { kind = "npc", npc = "brother_anzelm", dist = 8, height = 2.5, lift = 4.5 },
		lines = {
			line("brother_anzelm", "cutscene.frost_sign.l1"),
			line("brother_anzelm", "cutscene.frost_sign.l2"),
			line("brother_anzelm", "cutscene.frost_sign.l3"),
		},
		light = { color = "#FFB35A", range = 14 },
	},
	{
		-- Grimrok's last words over the player
		id = "grimrok_end",
		kind = "scene",
		quest = "grimrok",
		on = "objective",
		index = 1,
		shot = { kind = "self", dist = 18, height = 9, orbit = 40 },
		lines = {
			line("boss:grimrok", "cutscene.grimrok_end.l1"),
			line("boss:grimrok", "cutscene.grimrok_end.l2"),
			line(nil, "cutscene.grimrok_end.l3"),
		},
	},
	{
		-- a man in a grey cloak at the edge of Duskwood, gone in the frost (the end card of chapter I)
		id = "ch1_close",
		kind = "scene",
		quest = "warCouncil",
		on = "turnIn",
		shot = { kind = "point", map = "meadows", x = 704, z = -694, yaw = 220, dist = 30, height = 10, push = 8 },
		lines = { line(nil, "cutscene.ch1_close.l1"), line(nil, "cutscene.ch1_close.l2") },
		figures = { figure("ilvar", 712, -702, 225, "frost") },
		title = "story.chapter.1.end",
	},
	-- S103: chapter II "The Forgotten House" (Duskwood) -----------------------------------------------------------
	{
		-- the chapter card over the dusk gate with its blue lanterns, the eye on the road from the west
		id = "ch2_title",
		kind = "chapter",
		quest = "toDuskwood",
		on = "objective",
		index = 1,
		shot = {
			kind = "point",
			map = "duskwood",
			x = -646,
			z = 9,
			yaw = 90,
			dist = 32,
			height = 9,
			push = 10,
			orbit = 6,
		},
		title = "cutscene.ch2_title.title",
		subtitle = "story.chapter.2",
		lines = { line(nil, "cutscene.ch2_title.l1"), line(nil, "cutscene.ch2_title.l2") },
	},
	{
		-- the frost rune cracks on the menhir at night
		id = "moonstone",
		kind = "scene",
		quest = "moonstone",
		on = "objective",
		index = 2,
		shot = { kind = "anchor", anchor = "moonstone_rune", dist = 14, height = 4, lift = 5, orbit = 15 },
		clock = 0,
		lines = {
			line(nil, "cutscene.moonstone.l1"),
			line(nil, "cutscene.moonstone.l2"),
			line("forester_radomir", "cutscene.moonstone.l3"),
		},
	},
	{
		-- inside the chapel, the eye by the door, the stained glass behind the altar; the ghost's voice
		id = "houseOfVael",
		kind = "scene",
		quest = "houseOfVael",
		on = "objective",
		index = 2,
		shot = {
			kind = "point",
			map = "duskwood",
			x = 4,
			z = -593,
			yaw = 180,
			dist = 11,
			height = 0,
			lift = 6.5,
			orbit = 0,
			push = 3,
		},
		light = { color = "#B08A2A", range = 16 },
		lines = {
			line(nil, "cutscene.houseOfVael.l1"),
			line("ghost_oswin", "cutscene.houseOfVael.l2"),
			line("ghost_oswin", "cutscene.houseOfVael.l3"),
		},
	},
	{
		-- the cold blue in the Elder Tree's crack goes out, the gold comes back
		id = "elderHeart",
		kind = "scene",
		quest = "elderHeart",
		on = "objective",
		index = 1,
		shot = { kind = "anchor", anchor = "elder_tree", dist = 16, height = 5, lift = 6, orbit = 12 },
		lines = {
			line(nil, "cutscene.elderHeart.l1"),
			line(nil, "cutscene.elderHeart.l2"),
			line(nil, "cutscene.elderHeart.l3"),
		},
	},
	{
		-- Aldric and Brother Anzelm over the cult's seals; Anzelm names Ilvar the Voice
		id = "cult",
		kind = "scene",
		quest = "cult",
		on = "turnIn",
		shot = { kind = "npc", npc = "captain", dist = 11, height = 3, lift = 4.5, orbit = 8 },
		figures = { besideCaptain() },
		lines = {
			line("captain", "cutscene.cult.l1"),
			line("brother_anzelm", "cutscene.cult.l2"),
			line("brother_anzelm", "cutscene.cult.l3"),
		},
	},
	{
		-- Jorund whispers in the mist by the shrine's lantern
		id = "turncoat",
		kind = "scene",
		quest = "turncoat",
		on = "objective",
		index = 2,
		shot = { kind = "npc", npc = "defector_jorund", dist = 8, height = 2.5, lift = 4.5 },
		light = { color = "#7FB8FF", range = 12 },
		lines = {
			line("defector_jorund", "cutscene.turncoat.l1"),
			line("defector_jorund", "cutscene.turncoat.l2"),
			line("defector_jorund", "cutscene.turncoat.l3"),
		},
	},
	{
		-- the empty shroud in the Heart of the Barrow (a generated cave: the shot is over the player)
		id = "barrow",
		kind = "scene",
		quest = "barrow",
		on = "objective",
		index = 3,
		shot = { kind = "self", dist = 14, height = 12, orbit = 30 },
		lines = {
			line(nil, "cutscene.barrow.l1"),
			line(nil, "cutscene.barrow.l2"),
			line(nil, "cutscene.barrow.l3"),
		},
	},
	{
		-- Ilvar's projection in the frost before the Crypt Gate, the eye from the courtyard's west side
		id = "cryptGate",
		kind = "scene",
		quest = "cryptGate",
		on = "objective",
		index = 2,
		shot = {
			kind = "point",
			map = "duskwood",
			x = 742,
			z = -4,
			yaw = 90,
			dist = 26,
			height = 6,
			lift = 5,
			push = 6,
		},
		figures = { figure("ilvar", 738, -4, 90, "frost", true) },
		lines = {
			line(nil, "cutscene.cryptGate.l1"),
			line("ilvar", "cutscene.cryptGate.l2"),
			line("ilvar", "cutscene.cryptGate.l3"),
			line(nil, "cutscene.cryptGate.l4"),
		},
	},
	{
		-- the spirit of the young queen before her empty sarcophagus in the apse of the Tomb (Logic/CaveDress/Tomb:
		-- the sarcophagus on the dais at 0 / -128), the eye from the middle of the arena
		id = "morvane",
		kind = "scene",
		quest = "morvane",
		on = "objective",
		index = 1,
		shot = {
			kind = "point",
			map = "dungeon_duskwood",
			x = 0,
			z = -120,
			yaw = 180,
			dist = 60,
			height = 8,
			lift = 4,
			orbit = 0,
			push = 12,
		},
		figures = { figure("queen", 0, -116, 180, "frost", true) },
		light = { color = "#9FE0C9", range = 18 },
		lines = {
			line("queen", "cutscene.morvane.l1"),
			line("queen", "cutscene.morvane.l2"),
			line("queen", "cutscene.morvane.l3"),
			line("queen", "cutscene.morvane.l4"),
		},
	},
	{
		-- the end of chapter II: Anzelm lays the branch by the ring and it starts to glow
		id = "queensLegacy",
		kind = "scene",
		quest = "queensLegacy",
		on = "turnIn",
		shot = { kind = "npc", npc = "captain", dist = 11, height = 3, lift = 4.5, orbit = 8 },
		figures = { besideCaptain() },
		light = { color = "#E8C25A", range = 12 },
		lines = {
			line(nil, "cutscene.queensLegacy.l1"),
			line("brother_anzelm", "cutscene.queensLegacy.l2"),
			line("brother_anzelm", "cutscene.queensLegacy.l3"),
			line("captain", "cutscene.queensLegacy.l4"),
		},
		title = "story.chapter.2.end",
	},
}

local byId: { [string]: Scene } = {}
local byQuest: { [string]: { Scene } } = {}
for _, scene in list do
	assert(byId[scene.id] == nil, `Cutscenes: duplicate id {scene.id}`)
	byId[scene.id] = scene
	local scenes = byQuest[scene.quest]
	if not scenes then
		scenes = {}
		byQuest[scene.quest] = scenes
	end
	table.insert(scenes, scene)
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	byQuest = table.freeze(byQuest),
	get = function(id: string): Scene?
		return byId[id]
	end,
	WHO = table.freeze(WHO),
	FIGURES = table.freeze(FIGURES),
})
