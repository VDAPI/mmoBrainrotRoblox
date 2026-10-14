--!strict
-- Story cutscene rules (S102, FABULA §2.1). Pure (Lune tests). Which scenes a quest event triggers (QuestService
-- queues them in character.quests.scenes: false = queued, true = watched or skipped), which queued ones to play and in
-- what order (CutsceneController), how long a line stays, who speaks and where the camera is at a moment of the shot.

local Areas = require("../Data/Areas")
local Bosses = require("../Data/Bosses")
local Config = require("../Config")
local Data = require("../Data/Cutscenes")
local Locale = require("../Util/Locale")
local Maps = require("../Data/Maps")
local Npcs = require("../Data/Npcs")
local Quests = require("../Data/Quests")

type Scene = Data.Scene
type Shot = Data.Shot
type Line = Data.Line

export type Vec = { x: number, y: number, z: number }

local Cutscenes = {}

Cutscenes.MAX_LINES = 4 -- "scene": 2-4 lines (FABULA §2.1)
Cutscenes.ORBIT = 10 -- default degrees the eye turns over a shot
Cutscenes.PUSH = 4 -- default studs the eye moves in over a shot
-- S105: the figure fades and the story props the client knows (Vfx/CutsceneFigure, Util/StoryProps)
Cutscenes.FADES = table.freeze({ frost = true, freeze = true, none = true })
Cutscenes.PROPS = table.freeze({ thorn = true, lantern = true })

-- Ids of the scenes a quest event triggers, in list order (`index` matters only for "objective").
function Cutscenes.triggered(questId: string, on: string, index: number?): { string }
	local out: { string } = {}
	local scenes: { Scene } = Data.byQuest[questId] or {}
	for _, scene in scenes do
		if scene.on == on and (on ~= "objective" or scene.index == index) then
			table.insert(out, scene.id)
		end
	end
	return out
end

-- Queued scene ids (value false) in list order; unknown ids are skipped (a scene removed from the data never blocks
-- the queue).
function Cutscenes.pending(scenes: any): { string }
	local out: { string } = {}
	if type(scenes) ~= "table" then
		return out
	end
	for _, scene in Data.list do
		if scenes[scene.id] == false then
			table.insert(out, scene.id)
		end
	end
	return out
end

-- Whether a scene id exists in the data (admin /scene play).
function Cutscenes.isKnown(sceneId: string): boolean
	return Data.byId[sceneId] ~= nil
end

-- Scene ids of a quest in list order (the journal's replay).
function Cutscenes.ofQuest(questId: string): { string }
	local out: { string } = {}
	local scenes: { Scene } = Data.byQuest[questId] or {}
	for _, scene in scenes do
		table.insert(out, scene.id)
	end
	return out
end

-- Seconds a line stays: its UTF-8 characters at Config.Cutscene.lineCharsPerSecond, within lineMin..lineMax.
function Cutscenes.lineSeconds(text: string): number
	local c = Config.Cutscene
	local length = utf8.len(text) or #text
	return math.clamp(length / c.lineCharsPerSecond, c.lineMin, c.lineMax)
end

-- Locale key of a line's speaker name: nil for narration, a boss's name for "boss:<id>", a WHO key, else the NPC's
-- name (nil for an unknown one: Cutscenes.validate reports it).
function Cutscenes.speakerKey(line: Line): string?
	local who = line.who
	if who == nil then
		return nil
	end
	local bossId = string.match(who, "^boss:(.+)$")
	if bossId then
		local boss = Bosses.get(bossId)
		return if boss then boss.nameKey else nil
	end
	if Data.WHO[who] then
		return Data.WHO[who]
	end
	local npc = Npcs.get(who)
	return if npc then npc.nameKey else nil
end

-- Direction of a yaw in degrees (the city plan's convention: yaw 0 looks to -Z).
local function direction(yaw: number): (number, number)
	local r = math.rad(yaw)
	return -math.sin(r), -math.cos(r)
end

-- The eye and the point it looks at at moment `t` (0..1) of a shot around `focus`: the eye starts `dist` studs from
-- the focus towards `yaw` (default: `facing` for "npc" / "self", else 0) and `height` over it, turns `orbit` degrees
-- and moves `push` studs in over the whole shot. Plain tables (Lune tests); "city" shots do not use it.
function Cutscenes.frame(shot: Shot, focus: Vec, facing: number?, t: number): (Vec, Vec)
	local c = Config.Cutscene
	local k = math.clamp(t, 0, 1)
	local base = shot.yaw or (if shot.kind == "npc" or shot.kind == "self" then facing or 0 else 0)
	local yaw = base + (shot.orbit or Cutscenes.ORBIT) * k
	local dist = (shot.dist or c.dist) - (shot.push or Cutscenes.PUSH) * k
	local dx, dz = direction(yaw)
	local eye = { x = focus.x + dx * dist, y = focus.y + (shot.height or c.height), z = focus.z + dz * dist }
	return eye, { x = focus.x, y = focus.y, z = focus.z }
end

-- Problems of the cutscene data (for the test); empty = fine.
function Cutscenes.validate(): { string }
	local problems: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, scene in Data.list do
		local function bad(text: string)
			table.insert(problems, `{scene.id}: {text}`)
		end
		if seen[scene.id] then
			bad("id twice")
		end
		seen[scene.id] = true
		local quest = Quests.Main.get(scene.quest)
		if not quest then
			bad(`unknown quest {scene.quest}`)
		end
		if scene.on == "objective" then
			local index = scene.index
			if type(index) ~= "number" then
				bad("objective without an index")
			elseif quest and (index < 1 or index > #quest.objectives or index ~= math.floor(index)) then
				bad(`objective {index} out of the quest's objectives`)
			end
		end
		local shot = scene.shot
		if shot.kind == "npc" and not Npcs.get(shot.npc or "") then
			bad(`unknown NPC {tostring(shot.npc)}`)
		end
		if shot.kind == "anchor" and not Areas.anchorById(shot.anchor or "") then
			bad(`unknown anchor {tostring(shot.anchor)}`)
		end
		if shot.kind == "point" then
			if not Maps.get(shot.map or "") then
				bad(`unknown map {tostring(shot.map)}`)
			end
			if type(shot.x) ~= "number" or type(shot.z) ~= "number" then
				bad("point without x / z")
			end
		end
		if #scene.lines == 0 then
			bad("no lines")
		end
		if scene.kind == "scene" and #scene.lines > Cutscenes.MAX_LINES then
			bad(`{#scene.lines} lines (at most {Cutscenes.MAX_LINES})`)
		end
		if scene.kind == "chapter" and scene.title == nil then
			bad("chapter without a title")
		end
		local function needText(key: string?)
			if key and not (Locale.has(key, "pl") and Locale.has(key, "en")) then
				bad(`no text {key}`)
			end
		end
		needText(scene.title)
		needText(scene.subtitle)
		for _, item in scene.lines do
			if item.who ~= nil and Cutscenes.speakerKey(item) == nil then
				bad(`speaker {item.who} has no name`)
			end
			if not (Locale.has(item.key, "pl") and Locale.has(item.key, "en")) then
				bad(`no text {item.key}`)
			end
		end
		local figures: { Data.Figure } = scene.figures or {}
		for _, figure in figures do
			if not Data.FIGURES[figure.look] then
				bad(`unknown figure look {figure.look}`)
			end
			if figure.fade ~= nil and not Cutscenes.FADES[figure.fade] then
				bad(`unknown fade {tostring(figure.fade)}`)
			end
		end
		-- S105: story props (Util/StoryProps on the client)
		local props: { Data.Prop } = scene.props or {}
		for _, item in props do
			if not Cutscenes.PROPS[item.kind] then
				bad(`unknown prop {tostring(item.kind)}`)
			end
			if type(item.x) ~= "number" or type(item.z) ~= "number" then
				bad("prop without x / z")
			end
		end
	end
	return problems
end

return Cutscenes
