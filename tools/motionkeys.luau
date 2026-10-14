--!strict
-- Control frames of motions (S110, Logic/MotionKeys, docs/ANIMACJE.md §3) as a Markdown table:
--   lune run tools/motionkeys.luau [attack|skill|boss|ability|all] [id]
-- attack <weapon type>, skill <skill id>, boss <boss id> (every attack), ability <id>; without an id every one of the
-- kind; `all` (the default) prints every weapon type, every active skill, every boss attack and every Elite II ability.

local process = require("@lune/process")

local AttackMotions = require("../src/shared/Data/AttackMotions")
local Bosses = require("../src/shared/Data/Bosses")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MotionKeys = require("../src/shared/Logic/MotionKeys")
local Skills = require("../src/shared/Data/Skills")

local kind = process.args[1] or "all"
local only = process.args[2]

local function fmt(t: number?): string
	if t == nil then
		return "—"
	end
	local text = string.format("%.3f", t)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

local rows: { string } = {}

local function row(name: string, what: string, keys: MotionKeys.Keys?)
	if not keys then
		return
	end
	local hitOrRelease = MotionKeys.at(keys, "hit") or MotionKeys.at(keys, "release")
	local label = if MotionKeys.at(keys, "hit") then "hit" elseif MotionKeys.at(keys, "release") then "release" else ""
	table.insert(
		rows,
		`| \`{name}\` | {what} | {fmt(MotionKeys.at(keys, "start"))} | {fmt(MotionKeys.at(keys, "peak"))} | {fmt(
			hitOrRelease
		)}{if label ~= "" then ` ({label})` else ""} | {fmt(MotionKeys.at(keys, "strikePeak"))} | {fmt(
			MotionKeys.at(keys, "follow")
		)} | {fmt(MotionKeys.at(keys, "end"))} |`
	)
end

local function sorted(map: { [string]: any }): { string }
	local list: { string } = {}
	for key in map do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

local function attacks()
	local list = sorted(AttackMotions.byWeapon)
	table.insert(list, "unarmed")
	for _, weaponType in list do
		if not only or only == weaponType then
			row(weaponType, `atak ({AttackMotions.byWeapon[weaponType] or "unarmed"})`, MotionKeys.attack(weaponType))
		end
	end
end

local function skills()
	for _, class in { "Warrior", "Hunter", "Mage", "Cleric" } do
		for _, def in Skills.byClass[class] do
			if def.type ~= "passive" and (not only or only == def.id) then
				row(def.id, `umiejętność ({class})`, MotionKeys.skill(def.id))
			end
		end
	end
end

local function bosses()
	for _, boss in Bosses.list do
		if not only or only == boss.id then
			for _, attack in boss.attacks do
				row(`{boss.id}.{attack.id}`, `boss (windup {fmt(attack.windup)})`, MotionKeys.boss(boss.id, attack.id))
			end
		end
	end
end

local function abilities()
	for _, id in sorted(MonsterAbilities.byId) do
		if not only or only == id then
			row(id, `Elita II (windup {fmt(MonsterAbilities.byId[id].windup)})`, MotionKeys.ability(id))
		end
	end
end

if kind == "attack" then
	attacks()
elseif kind == "skill" then
	skills()
elseif kind == "boss" then
	bosses()
elseif kind == "ability" then
	abilities()
elseif kind == "all" then
	attacks()
	skills()
	bosses()
	abilities()
	row("monster (atk)", "zwykły atak potwora", MotionKeys.monster(nil, true))
else
	print("usage: lune run tools/motionkeys.luau [attack|skill|boss|ability|all] [id]")
	process.exit(1)
end

print("| Ruch | Rodzaj | start | peak | hit / release | strikePeak | follow | end |")
print("|---|---|---|---|---|---|---|---|")
for _, line in rows do
	print(line)
end
