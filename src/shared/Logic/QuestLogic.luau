--!strict
-- Quest progress rules (DESIGN §20). Pure functions (Lune tests): which events advance which objectives,
-- completion, the next main quest and the daily contracts of a day.

local Monsters = require("../Data/Monsters")
local Quests = require("../Data/Quests")
local Rng = require("./Rng")

local QuestLogic = {}

type Objective = Quests.Objective

-- How much an event advances an objective (0 when it does not match). `roll` (0..1) decides `collect`.
function QuestLogic.amount(objective: Objective, kind: string, data: { [string]: any }, roll: number): number
	local t = objective.type
	if t == "kill" or t == "collect" then
		if kind ~= "kill" then
			return 0
		end
		if objective.monster and objective.monster ~= data.monsterId then
			return 0
		end
		-- S27: only monsters of groups from that area (MonsterService tags them with AreaId).
		if objective.area and objective.area ~= data.areaId then
			return 0
		end
		if objective.region then
			local def = Monsters.get(data.monsterId or "")
			if not def or def.region ~= objective.region then
				return 0
			end
		end
		local variant: string = data.variant or "normal"
		local wanted: string? = objective.variant
		local isElite = variant == "elite" or variant == "elite2"
		if (wanted == "elite" and not isElite) or (wanted == "normal" and isElite) then
			return 0
		end
		if t == "collect" then
			return if roll < (objective.chance or 1) then 1 else 0
		end
		return 1
	elseif t == "gather" then
		if kind ~= "gather" then
			return 0
		end
		if objective.node and objective.node ~= data.kind then
			return 0
		end
		if objective.category and objective.category ~= data.category then
			return 0
		end
		return 1
	elseif t == "boss" then
		return if kind == "boss" and (objective.boss == nil or objective.boss == data.bossId) then 1 else 0
	elseif t == "upgrade" then
		return if kind == "upgrade" and (data.to or 0) >= (objective.up or 1) then 1 else 0
	elseif t == "equip" then
		return if kind == "equip" and (data.rarity or 1) >= (objective.rarity or 1) then 1 else 0
	elseif t == "talk" then
		return if kind == "talk" and data.npc == objective.npc then 1 else 0
	elseif t == "deliver" then
		-- S27: `npc` nil = the quest's turn-in NPC (the caller passes it as data.turnIn).
		local target = objective.npc or data.turnIn
		return if kind == "talk" and target ~= nil and data.npc == target then 1 else 0
	elseif t == "use" then
		-- S27: one anchor once; `data.used` lists the anchors this objective already counted.
		if kind ~= "use" or type(data.anchor) ~= "string" then
			return 0
		end
		if not QuestLogic.usesAnchor(objective, data.anchor) then
			return 0
		end
		local used: { string } = data.used or {}
		return if table.find(used, data.anchor) then 0 else 1
	elseif t == "reach" then
		if kind ~= "reach" or data.map ~= objective.map then
			return 0
		end
		if objective.x and objective.z then
			local dx, dz = (data.x or 0) - objective.x, (data.z or 0) - objective.z
			if math.sqrt(dx * dx + dz * dz) > (objective.radius or 20) then
				return 0
			end
		end
		return 1
	elseif t == "level" then
		return if kind == "level" and (data.level or 0) >= (objective.level or 1) then objective.n else 0
	elseif t == kind then
		-- fish, loot, stats, learn, potion, duel
		return 1
	end
	return 0
end

-- S27: whether a `use` objective involves this anchor.
function QuestLogic.usesAnchor(objective: Objective, anchor: string): boolean
	if objective.anchor == anchor then
		return true
	end
	local list: { string } = objective.anchors or {}
	return table.find(list, anchor) ~= nil
end

-- Applies an event to a progress list in place. Returns the indices that changed.
function QuestLogic.advance(
	progress: { number },
	objectives: { Objective },
	kind: string,
	data: { [string]: any },
	rng: Rng.Rng
): { number }
	local changed = {}
	for i, objective in objectives do
		local have = progress[i] or 0
		if have < objective.n then
			local add = QuestLogic.amount(objective, kind, data, rng:next())
			if add > 0 then
				progress[i] = math.min(objective.n, have + add)
				table.insert(changed, i)
			end
		end
	end
	return changed
end

function QuestLogic.isComplete(progress: { number }, objectives: { Objective }): boolean
	for i, objective in objectives do
		if (progress[i] or 0) < objective.n then
			return false
		end
	end
	return true
end

function QuestLogic.emptyProgress(objectives: { Objective }): { number }
	return table.create(#objectives, 0)
end

-- The next main quest after `done` completed ones, and whether the level allows it now.
function QuestLogic.nextMain(done: number, level: number): (Quests.MainQuest?, boolean)
	local quest = Quests.Main.list[done + 1]
	if not quest then
		return nil, false
	end
	return quest, level >= quest.level - Quests.Main.LEVEL_SLACK
end

export type DailyEntry = { template: string, objective: Objective, progress: number, claimed: boolean }

-- The day's contracts for a character (deterministic for the same user, character and day).
function QuestLogic.dailyFor(userId: number, characterId: string, day: number, level: number): { DailyEntry }
	local seed = (userId * 7919 + day * 104729) % 2147483647
	for i = 1, #characterId do
		seed = (seed * 31 + string.byte(characterId, i)) % 2147483647
	end
	local rng = Rng.new(seed)
	-- Warm the generator up: the first outputs of close seeds are close.
	for _ = 1, 8 do
		rng:next()
	end
	local pool = {}
	for _, template in Quests.Daily.templates do
		if level >= template.minLevel then
			table.insert(pool, template)
		end
	end
	local list: { DailyEntry } = {}
	for _ = 1, math.min(Quests.Daily.PER_DAY, #pool) do
		local template = table.remove(pool, rng:int(1, #pool))
		assert(template, "template")
		table.insert(
			list,
			{ template = template.id, objective = template.objective(level), progress = 0, claimed = false }
		)
	end
	return list
end

return QuestLogic
