--!strict
-- AnimLab (S110, docs/ANIMACJE.md): the parser of /animlab and the stage layout. Pure (Lune): the server checks a call
-- with it before it sends "animlab" to the admin's client, the client (AnimLabController, AnimLabCall) runs the same
-- parse. Every refusal is a key "animlab.error.<why>" (PL and EN).

local AttackMotions = require("../Data/AttackMotions")
local Bosses = require("../Data/Bosses")
local Config = require("../Config")
local Items = require("../Data/Items")
local LookAnim = require("./LookAnim")
local MonsterLooks = require("../Data/MonsterLooks")
local Monsters = require("../Data/Monsters")
local Npcs = require("../Data/Npcs")
local PathData = require("../Data/Paths")
local Skills = require("../Data/Skills")

local AnimLab = {}

export type Action =
	"on"
	| "off"
	| "attack"
	| "skill"
	| "mob"
	| "boss"
	| "npc"
	| "sfx"
	| "loop"
	| "freeze"
	| "step"
	| "play"
	| "keys"
	| "cam"
	| "stress"
	| "state"
export type Command = { action: Action, id: string?, slot: string?, t: number?, n: number? }

AnimLab.ACTIONS = {
	"on",
	"off",
	"attack",
	"skill",
	"mob",
	"boss",
	"npc",
	"sfx",
	"loop",
	"freeze",
	"step",
	"play",
	"keys",
	"cam",
	"stress",
	"state",
} :: { Action }
AnimLab.CAMERAS = { "front", "side", "threequarter", "top", "game" }
AnimLab.NPC_SLOTS = { "idle", "talk", "wave", "work" }
-- Motions a freeze / loop / keys can replay (the others are tools).
AnimLab.MOTIONS = { "attack", "skill", "mob", "boss", "npc" } :: { Action }
AnimLab.LAYOUT = Config.AnimLab.layout
-- Every refusal key (tests check PL and EN).
AnimLab.ERRORS = {
	"animlab.error.action",
	"animlab.error.args",
	"animlab.error.weapon",
	"animlab.error.skill",
	"animlab.error.mob",
	"animlab.error.slot",
	"animlab.error.boss",
	"animlab.error.npc",
	"animlab.error.sfx",
	"animlab.error.time",
	"animlab.error.step",
	"animlab.error.cam",
	"animlab.error.stress",
}

local function make(action: Action, id: string?, slot: string?, t: number?, n: number?): Command
	return { action = action, id = id, slot = slot, t = t, n = n }
end

local NO_ARGS: { [string]: boolean } = { on = true, off = true, loop = true, play = true, keys = true, state = true }

-- A decimal number written with a dot ("0.21", "-.5", "2"); commas, exponents and hex are refused.
local function number(text: string?): number?
	if type(text) ~= "string" or not string.match(text, "^%-?%d*%.?%d+$") then
		return nil
	end
	local n = tonumber(text)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return n
end

local function hasLook(id: string): boolean
	local monster = Monsters.get(id)
	if monster then
		return MonsterLooks.get(id, monster.region) ~= nil
	end
	return Bosses.get(id) ~= nil and MonsterLooks.get(id) ~= nil
end

-- Validates a /animlab call against the game data (weapon types, active skills, monster / boss looks, boss attacks,
-- NPCs, camera names). Returns the command or an error key (animlab.error.<why>).
function AnimLab.parse(args: { string }): (Command?, string?)
	local first = args[1]
	local action = if first == nil or first == "" then "on" else string.lower(first)
	if not table.find(AnimLab.ACTIONS, action :: Action) then
		return nil, "animlab.error.action"
	end
	local a: string?, b: string? = args[2], args[3]
	if a == "" then
		a = nil
	end
	if b == "" then
		b = nil
	end
	if NO_ARGS[action] then
		if a ~= nil then
			return nil, "animlab.error.args"
		end
		return make(action :: Action), nil
	end
	local limits = Config.AnimLab
	if action == "attack" then
		if not a or (a ~= "unarmed" and AttackMotions.byWeapon[a] == nil) or b ~= nil then
			return nil, "animlab.error.weapon"
		end
		return make("attack", a), nil
	elseif action == "skill" then
		local skill = a and Skills.get(a)
		if not a or not skill or skill.type == "passive" or b ~= nil then
			return nil, "animlab.error.skill"
		end
		return make("skill", a), nil
	elseif action == "mob" then
		if not a or not hasLook(a) then
			return nil, "animlab.error.mob"
		end
		local slot = b or "attack1"
		if not table.find(LookAnim.SLOTS, slot) then
			return nil, "animlab.error.slot"
		end
		return make("mob", a, slot), nil
	elseif action == "boss" then
		local boss = a and Bosses.get(a)
		if not a or not boss or not b or MonsterLooks.get(a) == nil then
			return nil, "animlab.error.boss"
		end
		for _, attack in boss.attacks do
			if attack.id == b then
				return make("boss", a, b), nil
			end
		end
		return nil, "animlab.error.boss"
	elseif action == "npc" then
		local slot = b or "idle"
		if not a or not Npcs.get(a) or not table.find(AnimLab.NPC_SLOTS, slot) then
			return nil, "animlab.error.npc"
		end
		return make("npc", a, slot), nil
	elseif action == "sfx" then
		if not a or b ~= nil then
			return nil, "animlab.error.sfx"
		end
		return make("sfx", a), nil
	elseif action == "freeze" then
		local t = number(a)
		if not t or t < 0 or t > limits.freezeMax or b ~= nil then
			return nil, "animlab.error.time"
		end
		return make("freeze", nil, nil, t), nil
	elseif action == "step" then
		local dt = number(a)
		if not dt or dt == 0 or math.abs(dt) > limits.stepMax or b ~= nil then
			return nil, "animlab.error.step"
		end
		return make("step", nil, nil, dt), nil
	elseif action == "cam" then
		if not a or (a ~= "off" and not table.find(AnimLab.CAMERAS, a)) or b ~= nil then
			return nil, "animlab.error.cam"
		end
		return make("cam", a), nil
	elseif action == "stress" then
		local n = number(a)
		if not n or n ~= math.floor(n) or n < 1 or n > limits.stressMax or b ~= nil then
			return nil, "animlab.error.stress"
		end
		return make("stress", nil, nil, nil, n), nil
	end
	return nil, "animlab.error.action"
end

-- Splits a typed line ("freeze 0.21") into arguments and parses it.
function AnimLab.parseLine(line: string): (Command?, string?)
	local args: { string } = {}
	for word in string.gmatch(line, "%S+") do
		table.insert(args, word)
	end
	return AnimLab.parse(args)
end

-- The weapon type a skill is shown with: the main weapon of its path, else the class's starting weapon (DevPreset).
function AnimLab.weaponForSkill(skillId: string): string?
	local skill = Skills.get(skillId)
	if not skill then
		return nil
	end
	local path = skill.path and PathData.get(skill.path)
	local main = path and path.weapon.main
	if main and main[1] then
		return main[1]
	end
	local starting = Items.startingGear[skill.class]
	local def = starting and Items.get(starting[1])
	return if def then def.type else nil
end

-- Active skills in a fixed order (by class, then as listed): the playlist of /animlab stress.
function AnimLab.activeSkills(): { string }
	local out: { string } = {}
	for _, class in { "Warrior", "Hunter", "Mage", "Cleric" } do
		local list = Skills.byClass[class]
		if list then
			for _, def in list do
				if def.type ~= "passive" then
					table.insert(out, def.id)
				end
			end
		end
	end
	return out
end

return AnimLab
