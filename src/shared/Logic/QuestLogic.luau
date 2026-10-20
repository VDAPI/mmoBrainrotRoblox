--!strict
-- Quest progress rules (DESIGN §20). Pure functions (Lune tests): which events advance which objectives,
-- completion, the next main quest, the daily contracts of a day and (S98) the weekly contracts and boss contract of a
-- week.

local Bosses = require("../Data/Bosses")
local BossScaling = require("./BossScaling")
local Monsters = require("../Data/Monsters")
local Quests = require("../Data/Quests")
local Rng = require("./Rng")
local Shops = require("../Data/Shops")
local SkillData = require("../Data/Skills")

local QuestLogic = {}

type Objective = Quests.Objective

-- S95 (DESIGN-15 §1): `npc` of a talk / deliver objective that means "the vendor of the player's class".
QuestLogic.CLASS_VENDOR = "classVendor"

-- The NPC an objective's `npc` points at for a character of `classId`: the class vendor for CLASS_VENDOR (nil
-- without a class), else `npc` itself.
function QuestLogic.npcFor(npc: string?, classId: string?): string?
	if npc == QuestLogic.CLASS_VENDOR then
		return Shops.vendorOf(classId)
	end
	return npc
end

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
		-- S159: the daily and weekly hunts count monsters in the character's level range
		if objective.lvMin and (tonumber(data.level) or 0) < objective.lvMin then
			return 0
		end
		local variant: string = data.variant or "normal"
		local wanted: string? = objective.variant
		local isElite = variant == "elite" or variant == "elite2"
		if (wanted == "elite" and not isElite) or (wanted == "normal" and isElite) then
			return 0
		end
		-- S98: "elite2" = Elite II only
		if wanted == "elite2" and variant ~= "elite2" then
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
		local target = QuestLogic.npcFor(objective.npc, data.classId)
		return if kind == "talk" and target ~= nil and data.npc == target then 1 else 0
	elseif t == "deliver" then
		-- S27: `npc` nil = the quest's turn-in NPC (the caller passes it as data.turnIn).
		local target = QuestLogic.npcFor(objective.npc, data.classId) or data.turnIn
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
	elseif t == "handin" then
		-- S159: QuestEvents "quest" (story, side quest, hunting contracts: `n` handed in at once)
		return if kind == "quest" then math.max(1, math.floor(tonumber(data.n) or 1)) else 0
	elseif t == "dismantle" then
		-- S159: BlacksmithService fires the items taken apart at once
		return if kind == "dismantle" then math.max(1, math.floor(tonumber(data.n) or 1)) else 0
	elseif t == "escort" then
		-- S101b: only CompanionService fires it, when the leading companion arrives with the player
		return if kind == "escort" and objective.npc ~= nil and data.npc == objective.npc then 1 else 0
	elseif t == kind then
		-- fish, loot, stats, learn, potion, duel, event (S98; WorldEventService fires it from S101)
		return 1
	end
	return 0
end

-- S27: whether a `use` objective involves this anchor.
-- S56: the "learn" objective counts a skill put on the bar. The first skill on slots 1..10 other than the
-- starting one (nil for an empty bar or not a table).
function QuestLogic.learnedOnBar(hotbar: any, startingId: string?): string?
	if type(hotbar) ~= "table" then
		return nil
	end
	for slot = 1, SkillData.HOTBAR_SLOTS do
		local id = hotbar[tostring(slot)]
		if type(id) == "string" and id ~= startingId then
			return id
		end
	end
	return nil
end

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

-- S98: the generator of a period's draws (the daily rules of S11: character bytes, 8 warm-up draws).
local function seeded(seed: number, characterId: string): Rng.Rng
	for i = 1, #characterId do
		seed = (seed * 31 + string.byte(characterId, i)) % 2147483647
	end
	local rng = Rng.new(seed)
	-- Warm the generator up: the first outputs of close seeds are close.
	for _ = 1, 8 do
		rng:next()
	end
	return rng
end

-- S159: one template of `pool` drawn by weight (Daily.templates `weight`, default 1) and removed from it. Equal weights
-- draw with rng:int like S98, so the weekly lists of a seed stay what they were.
local function draw(pool: { Quests.DailyTemplate }, rng: Rng.Rng): Quests.DailyTemplate
	local total, even = 0, true
	for _, template in pool do
		local w = template.weight or 1
		total += w
		even = even and w == 1
	end
	local index = #pool
	if even then
		index = rng:int(1, #pool)
	else
		local roll = rng:next() * total
		for i, template in pool do
			roll -= template.weight or 1
			if roll < 0 then
				index = i
				break
			end
		end
	end
	return table.remove(pool, index) :: Quests.DailyTemplate
end

local function entryOf(template: Quests.DailyTemplate, level: number): DailyEntry
	return { template = template.id, objective = template.objective(level), progress = 0, claimed = false }
end

-- The templates open at `level` (`hidden` never), without the ids in `except`.
local function openTemplates(
	templates: { Quests.DailyTemplate },
	level: number,
	except: { [string]: boolean }?
): { Quests.DailyTemplate }
	local pool = {}
	for _, template in templates do
		if level >= template.minLevel and template.hidden ~= true and not (except and except[template.id]) then
			table.insert(pool, template)
		end
	end
	return pool
end

-- S98: `perPeriod` templates of `templates` for a seed, drawn without repetition from the templates open at `level`.
-- S159: `slots` first (one template of each group, in order, when the group has one open; never a PvP one), then
-- the rest from every group left.
local function pickTemplates(
	templates: { Quests.DailyTemplate },
	perPeriod: number,
	seed: number,
	characterId: string,
	level: number,
	slots: { string }?
): { DailyEntry }
	local rng = seeded(seed, characterId)
	local pool = openTemplates(templates, level)
	local list: { DailyEntry } = {}
	local groups: { string } = slots or {}
	for _, slot in groups do
		if #list >= perPeriod then
			break
		end
		local group, indexOf = {}, {}
		for i, template in pool do
			if template.slot == slot and template.pvp ~= true then
				table.insert(group, template)
				indexOf[template] = i
			end
		end
		if #group > 0 then
			local template = draw(group, rng)
			table.remove(pool, indexOf[template])
			table.insert(list, entryOf(template, level))
		end
	end
	while #list < perPeriod and #pool > 0 do
		table.insert(list, entryOf(draw(pool, rng), level))
	end
	return list
end

-- The day's contracts for a character (deterministic for the same user, character and day).
function QuestLogic.dailyFor(userId: number, characterId: string, day: number, level: number): { DailyEntry }
	local seed = (userId * 7919 + day * 104729) % 2147483647
	return pickTemplates(Quests.Daily.templates, Quests.Daily.PER_DAY, seed, characterId, level, Quests.Daily.SLOTS)
end

-- S159: the contract that replaces daily contract `index` on a reroll: another template open at `level` that is not
-- on the list (the same group first, any group else); `n` = the reroll of the day (another draw each). Nil when the
-- index is out of the list or nothing else is open.
function QuestLogic.rerollDaily(
	list: { DailyEntry },
	index: number,
	userId: number,
	characterId: string,
	day: number,
	level: number,
	n: number
): DailyEntry?
	local old = list[index]
	if not old then
		return nil
	end
	local taken: { [string]: boolean } = {}
	for _, entry in list do
		taken[entry.template] = true
	end
	local pool = openTemplates(Quests.Daily.templates, level, taken)
	if #pool == 0 then
		return nil
	end
	local before = Quests.Daily.get(old.template)
	local same = {}
	for _, template in pool do
		if before and template.slot == before.slot then
			table.insert(same, template)
		end
	end
	local seed = (userId * 7919 + day * 104729 + (index * 31 + n) * 1299709) % 2147483647
	local rng = seeded(seed, characterId)
	return entryOf(draw(if #same > 0 then same else pool, rng), level)
end

-- S98: the week's contracts for a character (deterministic for the same user, character and week; another sequence
-- than the daily ones of the same day).
function QuestLogic.weeklyFor(userId: number, characterId: string, week: number, level: number): { DailyEntry }
	local seed = (userId * 7919 + week * 15485863) % 2147483647
	return pickTemplates(Quests.Weekly.templates, Quests.Weekly.PER_WEEK, seed, characterId, level)
end

-- S98: the boss of the week's boss contract: the highest boss whose quest level the character has (S134c:
-- BossScaling.questLevel = boss level - 5, the old entry level; the dungeon opens 10 below); nil below the first.
function QuestLogic.bossContractFor(level: number): string?
	local best, bestLevel = nil, -math.huge
	for _, def in Bosses.list do
		if BossScaling.questLevel(def.level) <= level and def.level > bestLevel then
			best, bestLevel = def.id, def.level
		end
	end
	return best
end

export type WeeklyState = {
	week: number,
	list: { any },
	rerolls: number,
	boss: { boss: string, progress: number, claimed: boolean }?,
}

-- S98: weekly contracts and the boss contract to collect (done, not claimed) and open (not done).
function QuestLogic.weeklyOpen(weekly: WeeklyState?): (number, number)
	if type(weekly) ~= "table" then
		return 0, 0
	end
	local ready, open = 0, 0
	local list: { any } = weekly.list or {}
	for _, entry in list do
		if not entry.claimed then
			if (entry.progress or 0) >= entry.objective.n then
				ready += 1
			else
				open += 1
			end
		end
	end
	local boss = weekly.boss
	if boss and not boss.claimed then
		if boss.progress >= Quests.Weekly.bossContract.n then
			ready += 1
		else
			open += 1
		end
	end
	return ready, open
end

return QuestLogic
