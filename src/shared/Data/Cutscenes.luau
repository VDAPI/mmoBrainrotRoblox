--!strict
-- Story cutscenes (S102, FABULA §2.1): "chapter" = chapter card, "scene" = a short shot with 2–4 lines. Once per
-- character (quests.scenes), skippable, replayable; queued by QuestService, played by CutsceneController when idle.
-- Texts: cutscene.<id>.title / .l1..lN. People who are not NPCs (Ilvar) appear only as figures.
-- Rules (triggers, queue order, camera path, line times, validation): Logic/Cutscenes; timing: Config.Cutscene.

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
export type Figure = { look: string, x: number, z: number, facing: number, fade: ("frost" | "none")? }
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
local WHO: { [string]: string } = { ilvar = "cutscene.who.ilvar" }

-- Looks of the figures (colours of the robe, the hood and the trim).
local FIGURES: { [string]: { robe: string, hood: string, trim: string } } = {
	ilvar = { robe = "#7E8288", hood = "#5E6268", trim = "#C8DDF0" },
}

local function line(who: string?, key: string): Line
	return { who = who, key = key }
end

local function figure(look: string, x: number, z: number, facing: number, fade: ("frost" | "none")?): Figure
	return { look = look, x = x, z = z, facing = facing, fade = fade }
end

-- The seven scenes of chapter I "The Frost Sign" (order = playing order when several are queued).
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
