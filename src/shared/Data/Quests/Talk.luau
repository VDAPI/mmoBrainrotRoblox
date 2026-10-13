--!strict
-- S101b (DESIGN-15 §3.5): typed constructors of the dialogue fields of quests (Data/Quests/Types: choices, barks,
-- companion, the escort objective). luau-lsp does not narrow table literals to the members of a union in data, so
-- Main.luau and Side.luau (and S102-S108) build them here. Rules: Logic/Dialogue, Logic/Barks, Logic/Companion.

local Types = require("./Types")

type ChoiceEffect = Types.ChoiceEffect
type DialogueChoice = Types.DialogueChoice
type ChoicePage = Types.ChoicePage
type CompanionDef = Types.CompanionDef
type Objective = Types.Objective

export type Lines = { join: number?, wait: number?, arrive: number?, back: number? }

local Talk = {}

-- An extra point for the tracker and the world map (`place` = locale key of its name).
function Talk.hint(map: string, x: number, z: number, place: string): ChoiceEffect
	return { kind = "hint", map = map, x = x, z = z, place = place }
end

-- The tracker leads to objective `index` first.
function Talk.focus(index: number): ChoiceEffect
	return { kind = "focus", index = index }
end

-- A small consumable (Config.Dialogue.gifts), once per character.
function Talk.gift(id: string, n: number): ChoiceEffect
	return { kind = "item", id = id, n = n }
end

-- One answer of the player (texts quest.<id>.say.<choiceId> and .reply); `effect` nil = flavour only.
function Talk.answer(id: string, effect: ChoiceEffect?): DialogueChoice
	return { id = id, effect = effect }
end

-- Answers under offer page `page` (p1..pN).
function Talk.onPage(page: number, options: { DialogueChoice }): ChoicePage
	return { page = page, options = options }
end

-- Answers on the single offer page of a story quest without pages (quest.<id>.text).
function Talk.onText(options: { DialogueChoice }): ChoicePage
	return { page = "text", options = options }
end

-- Answers on the hand-in page (quest.<id>.done); only `item` effects make sense there.
function Talk.onDone(options: { DialogueChoice }): ChoicePage
	return { page = "done", options = options }
end

-- A companion who walks with the player while an objective of `during` is the current one.
function Talk.follow(
	npc: string,
	map: string,
	during: { number },
	lines: Lines?,
	from: { x: number, z: number }?
): CompanionDef
	return { npc = npc, mode = "follow", during = during, map = map, lines = lines, from = from }
end

-- A companion who leads the player along the route of the quest's `escort` objective (one of `during`).
function Talk.lead(
	npc: string,
	map: string,
	during: { number },
	lines: Lines?,
	from: { x: number, z: number }?
): CompanionDef
	return { npc = npc, mode = "lead", during = during, map = map, lines = lines, from = from }
end

-- The escort objective: walk with the leading companion `npc` to x/z on `map` (`via` waypoints on the way).
function Talk.escort(
	npc: string,
	map: string,
	x: number,
	z: number,
	radius: number,
	place: string,
	via: { { x: number, z: number } }?
): Objective
	return { type = "escort", n = 1, npc = npc, map = map, x = x, z = z, radius = radius, place = place, via = via }
end

return table.freeze(Talk)
