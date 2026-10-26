--!strict
-- AnimLab (S110, docs/ANIMACJE.md): the parser of /animlab and the stage layout. Pure (Lune): the server checks a call
-- with it before it sends "animlab" to the admin's client, the client (AnimLabController, AnimLabCall) runs the same
-- parse. Every refusal is a key "animlab.error.<why>" (PL and EN).

local AttackMotions = require("../Data/AttackMotions")
local BipedStyles = require("../Data/BipedStyles")
local FlyerStyles = require("../Data/FlyerStyles")
local QuadStyles = require("../Data/QuadStyles")
local BossMotions = require("../Data/BossMotions")
local Bosses = require("../Data/Bosses")
local Classes = require("../Data/Classes")
local Config = require("../Config")
local Items = require("../Data/Items")
local LookAnim = require("./LookAnim")
local MonsterLooks = require("../Data/MonsterLooks")
local Monsters = require("../Data/Monsters")
local Npcs = require("../Data/Npcs")
local PathData = require("../Data/Paths")
local Sfx = require("../Data/Sfx")
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
	| "vfx"
	| "hit"
	| "flinch"
	| "clip"
	| "loop"
	| "freeze"
	| "step"
	| "play"
	| "keys"
	| "cam"
	| "stress"
	| "state"
	| "floor"
-- `ref` (S113): the weapon type or skill id a `clip` is fitted to.
export type Command = { action: Action, id: string?, slot: string?, t: number?, n: number?, ref: string? }

AnimLab.ACTIONS = {
	"on",
	"off",
	"attack",
	"skill",
	"mob",
	"boss",
	"npc",
	"sfx",
	"vfx",
	"hit",
	"flinch",
	"clip",
	"loop",
	"freeze",
	"step",
	"play",
	"keys",
	"cam",
	"stress",
	"state",
	"floor", -- S117
} :: { Action }
AnimLab.CAMERAS = { "front", "side", "threequarter", "top", "game" }
AnimLab.NPC_SLOTS = { "idle", "talk", "wave", "work" }
-- Motions a freeze / loop / keys can replay (the others are tools).
AnimLab.MOTIONS = { "attack", "skill", "mob", "boss", "npc", "vfx", "hit", "flinch", "clip" } :: { Action }
-- S117: the floors of `floor <name>` (telegraphs on light grass, snow and a dark cave; Config.AnimLab.floors).
AnimLab.FLOORS = { "grass", "snow", "cave" }
-- S117: what `boss <id>` plays besides an attack: the phase roar and the long death (S159a: `rage` the roar into the
-- last phase; a pattern id its gesture).
AnimLab.BOSS_EXTRAS = { "roar", "rage", "death" }
-- S113: the sides a `flinch <side> [crit]` comes from.
AnimLab.FLINCH_SIDES = { "front", "back", "left", "right" }
-- S112: pieces `vfx <piece> [color]` plays (Vfx/Library: the six new ones first, then the old ones and the three
-- lasting areas of breakpoints); `vfx all` plays them in this order.
AnimLab.VFX_PIECES = {
	"impactFlash",
	"sparks",
	"groundDecal",
	"smokePuff",
	"magicCircle",
	"ringWave",
	"burst",
	"shockwave",
	"cracks",
	"slash",
	"projectile",
	"lightning",
	"pillar",
	"rune",
	"sparkle",
	"aura",
	"glow",
	"weaponTrail",
	"falcon",
	"beam",
	"dust",
	"meteor",
	"lingering:burn",
	"lingering:frost",
	"lingering:poison",
	"shieldArc", -- S114
	"wings", -- S114
	"snare", -- S115
	"stormCloud", -- S115
}
-- `vfx` sub-commands that are not a piece.
AnimLab.VFX_TOOLS = { "all", "tex", "stats" }
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
	"animlab.error.sfxId",
	"animlab.error.vfx",
	"animlab.error.vfxColor",
	"animlab.error.time",
	"animlab.error.step",
	"animlab.error.cam",
	"animlab.error.stress",
	"animlab.error.hit",
	"animlab.error.flinch",
	"animlab.error.clip",
	"animlab.error.floor",
}

local function make(action: Action, id: string?, slot: string?, t: number?, n: number?, ref: string?): Command
	return { action = action, id = id, slot = slot, t = t, n = n, ref = ref }
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
	local a: string?, b: string?, c: string?, d: string? = args[2], args[3], args[4], args[5]
	if a == "" then
		a = nil
	end
	if b == "" then
		b = nil
	end
	if c == "" then
		c = nil
	end
	if d == "" then
		d = nil
	end
	-- only `clip` takes more than two arguments (S113)
	if action ~= "clip" and (c ~= nil or d ~= nil or args[6] ~= nil) then
		return nil, "animlab.error.args"
	end
	if NO_ARGS[action] then
		if a ~= nil then
			return nil, "animlab.error.args"
		end
		return make(action :: Action), nil
	end
	local limits = Config.AnimLab
	if action == "attack" then
		-- S113: attack <type> [step|combo]
		if not a or (a ~= "unarmed" and AttackMotions.byWeapon[a] == nil) then
			return nil, "animlab.error.weapon"
		end
		if b == "combo" then
			return make("attack", a, "combo"), nil
		end
		local step = if b then number(b) else nil
		if b and (not step or step ~= math.floor(step) or step < 1 or step > AnimLab.stepsOf(a)) then
			return nil, "animlab.error.weapon"
		end
		return make("attack", a, nil, nil, step), nil
	elseif action == "hit" then
		-- S113: hit <material> [crit]
		if not a or not table.find(Sfx.MATERIALS, a) or (b ~= nil and b ~= "crit") then
			return nil, "animlab.error.hit"
		end
		return make("hit", a, b), nil
	elseif action == "flinch" then
		-- S113: flinch <front|back|left|right> [crit]
		if not a or not table.find(AnimLab.FLINCH_SIDES, a) or (b ~= nil and b ~= "crit") then
			return nil, "animlab.error.flinch"
		end
		return make("flinch", a, b), nil
	elseif action == "clip" then
		-- S113: clip <assetId> [attack <type> [step] | skill <skillId>]
		if not a or not string.match(a, "^%d+$") or #a > 20 or args[6] ~= nil then
			return nil, "animlab.error.clip"
		end
		if b == nil then
			if c ~= nil or d ~= nil then
				return nil, "animlab.error.clip"
			end
			return make("clip", a), nil
		elseif b == "attack" then
			if not c or (c ~= "unarmed" and AttackMotions.byWeapon[c] == nil) then
				return nil, "animlab.error.clip"
			end
			local step = if d then number(d) else nil
			if d and (not step or step ~= math.floor(step) or step < 1 or step > 3) then
				return nil, "animlab.error.clip"
			end
			return make("clip", a, "attack", nil, step, c), nil
		elseif b == "skill" then
			local skill = c and Skills.get(c)
			if not c or not skill or skill.type == "passive" or d ~= nil then
				return nil, "animlab.error.clip"
			end
			return make("clip", a, "skill", nil, nil, c), nil
		end
		return nil, "animlab.error.clip"
	elseif action == "skill" then
		-- S115: skill <id> [weapon type] (the actor's weapon: a crossbow, a staff …; default the path's or the class's)
		local skill = a and Skills.get(a)
		if not a or not skill or skill.type == "passive" or c ~= nil then
			return nil, "animlab.error.skill"
		end
		if b ~= nil and AttackMotions.byWeapon[b] == nil then
			return nil, "animlab.error.skill"
		end
		return make("skill", a, b), nil
	elseif action == "mob" then
		if not a or not hasLook(a) then
			return nil, "animlab.error.mob"
		end
		local slot = b or "attack1"
		-- template animation: a biped with a style (MonsterLooks asset `motion`) shows its states and actions too
		local look = MonsterLooks.get(a)
		local motion = if look and look.asset then look.asset.motion else nil
		local states = if motion and BipedStyles.get(motion)
			then BipedStyles.LAB_STATES
			elseif motion and QuadStyles.get(motion) then QuadStyles.LAB_STATES
			elseif motion and FlyerStyles.get(motion) then FlyerStyles.LAB_STATES
			else nil
		if not table.find(LookAnim.SLOTS, slot) and not (states and table.find(states, slot)) then
			return nil, "animlab.error.slot"
		end
		return make("mob", a, slot), nil
	elseif action == "boss" then
		local boss = a and Bosses.get(a)
		if not a or not boss or not b or MonsterLooks.get(a) == nil then
			return nil, "animlab.error.boss"
		end
		if table.find(AnimLab.BOSS_EXTRAS, b) then
			return make("boss", a, b), nil
		end
		for _, attack in boss.attacks do
			if attack.id == b then
				return make("boss", a, b), nil
			end
		end
		local gesture = BossMotions.gesture(a, b)
		if gesture and gesture.style then
			return make("boss", a, b), nil
		end
		return nil, "animlab.error.boss"
	elseif action == "npc" then
		local slot = b or "idle"
		if not a or not Npcs.get(a) or not table.find(AnimLab.NPC_SLOTS, slot) then
			return nil, "animlab.error.npc"
		end
		return make("npc", a, slot), nil
	elseif action == "sfx" then
		-- S111: sfx <key> [n] | sfx list [prefix] | sfx all [prefix] | sfx try <assetId>; the key itself is checked by
		-- the client (Data/Sfx): an unknown key answers animlab.sfx.unknown
		if not a then
			return nil, "animlab.error.sfx"
		end
		if a == "try" then
			if not b or not string.match(b, "^%d+$") or #b > 20 then
				return nil, "animlab.error.sfxId"
			end
			return make("sfx", "try", b), nil
		elseif a == "list" or a == "all" then
			return make("sfx", a, b), nil
		end
		local n = if b then number(b) else nil
		if b and (not n or n ~= math.floor(n) or n < 1) then
			return nil, "animlab.error.sfx"
		end
		return make("sfx", a, nil, nil, n), nil
	elseif action == "vfx" then
		-- S112: vfx <piece> [color] | vfx all [stress] | vfx tex [on|off] | vfx stats
		if not a then
			return nil, "animlab.error.vfx"
		end
		if a == "all" then
			if b ~= nil and b ~= "stress" then
				return nil, "animlab.error.vfx"
			end
			return make("vfx", "all", b), nil
		elseif a == "tex" then
			if b ~= nil and b ~= "on" and b ~= "off" then
				return nil, "animlab.error.vfx"
			end
			return make("vfx", "tex", b), nil
		elseif a == "stats" then
			if b ~= nil then
				return nil, "animlab.error.args"
			end
			return make("vfx", "stats"), nil
		end
		if not table.find(AnimLab.VFX_PIECES, a) then
			return nil, "animlab.error.vfx"
		end
		if b and not AnimLab.vfxColor(b) then
			return nil, "animlab.error.vfxColor"
		end
		return make("vfx", a, b), nil
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
	elseif action == "floor" then
		-- S117: floor <grass|snow|cave>
		if not a or not table.find(AnimLab.FLOORS, a) or b ~= nil then
			return nil, "animlab.error.floor"
		end
		return make("floor", a), nil
	elseif action == "stress" then
		local n = number(a)
		if not n or n ~= math.floor(n) or n < 1 or n > limits.stressMax or b ~= nil then
			return nil, "animlab.error.stress"
		end
		return make("stress", nil, nil, nil, n), nil
	end
	return nil, "animlab.error.action"
end

-- S112: the colour of `vfx <piece> [color]`: "#RRGGBB" or "class:<Class>" (Data/Classes) as a hex text, nil when
-- neither.
function AnimLab.vfxColor(text: string): string?
	if string.match(text, "^#%x%x%x%x%x%x$") then
		return string.upper(text)
	end
	local class = string.match(text, "^class:(%a+)$")
	local def = class and Classes.get(class)
	return if def then def.color else nil
end

-- S112: true for a `vfx` command that plays a piece (a motion AnimLab can freeze), false for its tools.
function AnimLab.isVfxPiece(command: Command): boolean
	return command.action == "vfx" and command.id ~= nil and table.find(AnimLab.VFX_PIECES, command.id) ~= nil
end

-- S113: combo steps of a weapon type's motion (nil / "unarmed" = fists).
function AnimLab.stepsOf(weaponType: string?): number
	local motion = if weaponType then AttackMotions.byWeapon[weaponType] or "unarmed" else "unarmed"
	return #AttackMotions.motions[motion].steps
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
