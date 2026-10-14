--!strict
-- S111: sound effect data (Data/Sfx), the choice of keys and the mix rules (Logic/SfxRules), the AnimLab `sfx` parser.

local fs = require("@lune/fs")

local AnimLab = require("../src/shared/Logic/AnimLab")
local AttackMotions = require("../src/shared/Data/AttackMotions")
local Bosses = require("../src/shared/Data/Bosses")
local Config = require("../src/shared/Config")
local Families = require("../src/shared/Data/Families")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local Sfx = require("../src/shared/Data/Sfx")
local SfxRules = require("../src/shared/Logic/SfxRules")
local SkillData = require("../src/shared/Data/Skills")
local SkillVfx = require("../src/shared/Data/SkillVfx")
local Test = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function sortedKeys(): { string }
	return Sfx.keys()
end

-- Every SkillType of Data/Skills/Types (read from the type itself, so a new kind cannot miss a default).
local function skillTypes(): { string }
	local text = fs.readFile("src/shared/Data/Skills/Types.luau")
	local from = string.find(text, "export type SkillType =", 1, true)
	local to = string.find(text, "export type TargetMode", 1, true)
	assert(from and to, "SkillType not found")
	local out = {}
	for name in string.gmatch(string.sub(text, from :: number, to :: number), '"(%w+)"') do
		table.insert(out, name)
	end
	return out
end

local function def(extra: { [string]: any }?): Sfx.Def
	local base: { [string]: any } = {
		ids = { "rbxassetid://1", "rbxassetid://2", "rbxassetid://3" },
		volume = 0.5,
		pitch = { 0.9, 1.1 },
		roll = 60,
		hint = "x",
	}
	for k, v in extra or {} do
		base[k] = v
	end
	return base :: any
end

describe("Sfx data (S111)", function()
	it("every entry has the right shape", function()
		for _, key in sortedKeys() do
			local d = Sfx.defs[key]
			expect({ key, string.match(key, "^[%w_.]+$") ~= nil }).toEqual({ key, true })
			expect({ key, type(d.ids) }).toEqual({ key, "table" })
			for _, id in d.ids do
				expect({ key, id, string.match(id, "^rbxassetid://%d+$") ~= nil }).toEqual({ key, id, true })
			end
			expect({ key, d.volume > 0 and d.volume <= 1 }).toEqual({ key, true })
			expect({ key, #d.pitch }).toEqual({ key, 2 })
			expect({ key, d.pitch[1] >= 0.85 and d.pitch[1] <= d.pitch[2] and d.pitch[2] <= 1.15 }).toEqual({
				key,
				true,
			})
			if not d.ui then
				expect({ key, d.roll >= 10 and d.roll <= 400 }).toEqual({ key, true })
			end
			expect({ key, d.cooldown == nil or (d.cooldown :: number) >= 0 }).toEqual({ key, true })
			expect({ key, type(d.hint) == "string" and #d.hint > 0 }).toEqual({ key, true })
		end
	end)

	it("has every key of the contract (DESIGN-16 §3, S111 A2)", function()
		local need: { string } = {
			"swing.light",
			"swing.heavy",
			"swing.blunt",
			"swing.thrust",
			"bow.draw",
			"bow.release",
			"crossbow.release",
			"wand.cast",
			"hit.crit",
			"block",
			"miss",
			"telegraph.warn",
		}
		for _, material in Sfx.MATERIALS do
			table.insert(need, "hit." .. material)
		end
		for _, kind in { "strike", "cast", "blast", "heal", "buff", "dash", "trap", "call" } do
			table.insert(need, "skill.default." .. kind)
		end
		for _, family in Families.ids do
			for _, suffix in { "attack", "hurt", "death", "aggro" } do
				table.insert(need, `mob.{family}.{suffix}`)
			end
		end
		for _, boss in Bosses.list do
			for _, suffix in { "roar", "attack", "death", "phase" } do
				table.insert(need, `boss.{boss.id}.{suffix}`)
			end
		end
		local ui = { "loot", "loot.rare", "loot.legendary", "levelup", "quest", "coin", "click", "error" }
		for _, name in ui do
			table.insert(need, "ui." .. name)
		end
		for _, id in Sfx.SKILL_SAMPLE do
			table.insert(need, "skill." .. id)
		end
		for _, key in need do
			expect({ key, Sfx.has(key) }).toEqual({ key, true })
		end
		expect(#Sfx.SKILL_SAMPLE).toBe(16)
		for _, id in Sfx.SKILL_SAMPLE do
			local skill = SkillData.get(id)
			expect({ id, skill ~= nil and skill.type ~= "passive" }).toEqual({ id, true })
		end
		-- interface keys are 2D, nothing else is
		for _, key in sortedKeys() do
			local isUi = string.sub(key, 1, 3) == "ui."
			expect({ key, Sfx.defs[key].ui == true }).toEqual({ key, isUi })
		end
		-- cooldowns of the contract
		for _, family in Families.ids do
			expect(Sfx.defs[`mob.{family}.hurt`].cooldown).toBe(0.35)
			expect(Sfx.defs[`mob.{family}.aggro`].cooldown).toBe(4)
		end
		for _, boss in Bosses.list do
			expect(Sfx.defs[`boss.{boss.id}.roar`].cooldown).toBe(3)
		end
	end)

	it("SkillVfx names only skill keys of Data/Sfx", function()
		for id, entry in SkillVfx do
			if entry.sound ~= "" then
				expect({ id, Sfx.has(entry.sound), string.sub(entry.sound, 1, 6) }).toEqual({ id, true, "skill." })
			end
		end
	end)

	it("has / playable / keys", function()
		expect(Sfx.has("nope")).toBe(false)
		expect(Sfx.playable("nope")).toBe(false)
		for _, key in Sfx.keys("ui.") do
			expect(string.sub(key, 1, 3)).toBe("ui.")
		end
		for _, key in sortedKeys() do
			expect({ key, Sfx.playable(key) }).toEqual({ key, #Sfx.defs[key].ids > 0 })
		end
	end)
end)

describe("SfxRules keys (S111)", function()
	it("every active skill has a default key; passives none", function()
		for _, skill in SkillData.byId do
			local vfx = SkillVfx[skill.id]
			local sound = if vfx then vfx.sound else nil
			local none = SfxRules.skillKey(skill, sound, function()
				return false
			end)
			local real = SfxRules.skillKey(skill, sound, Sfx.has)
			if skill.type == "passive" then
				expect({ skill.id, none, real }).toEqual({ skill.id, nil, nil })
			else
				expect({ skill.id, none ~= nil and string.sub(none :: string, 1, 14) == "skill.default." }).toEqual({
					skill.id,
					true,
				})
				expect({ skill.id, Sfx.has(none :: string) }).toEqual({ skill.id, true })
				expect({ skill.id, real ~= nil and Sfx.has(real :: string) }).toEqual({ skill.id, true })
			end
		end
	end)

	it("every skill kind has a default", function()
		local kinds = skillTypes()
		expect(#kinds > 20).toBe(true)
		for _, kind in kinds do
			if kind ~= "passive" then
				local key = SfxRules.KIND_DEFAULT[kind]
				expect({ kind, key ~= nil and Sfx.has(key) }).toEqual({ kind, true })
			end
		end
	end)

	it("picks the own key, then SkillVfx.sound, by playability", function()
		local skill = { id = "fireball", type = "circleTarget", delivery = "ranged" }
		local only = function(set: { [string]: boolean })
			return function(key: string): boolean
				return set[key] == true
			end
		end
		expect(SfxRules.skillKey(skill, "", only({}))).toBe("skill.default.blast")
		expect(SfxRules.skillKey(skill, "", only({ ["skill.fireball"] = true }))).toBe("skill.fireball")
		expect(SfxRules.skillKey(skill, "skill.meteor", only({ ["skill.meteor"] = true, ["skill.fireball"] = true }))).toBe(
			"skill.meteor"
		)
		expect(SfxRules.skillKey({ id = "x", type = "target", delivery = "melee" }, nil, only({}))).toBe(
			"skill.default.strike"
		)
		expect(SfxRules.skillKey({ id = "x", type = "target", delivery = "ranged" }, nil, only({}))).toBe(
			"skill.default.cast"
		)
		expect(SfxRules.skillKey({ id = "x", type = "charge", delivery = "melee" }, nil, only({}))).toBe(
			"skill.default.strike"
		)
		expect(SfxRules.skillKey({ id = "x", type = "charge" }, nil, only({}))).toBe("skill.default.dash")
		expect(SfxRules.skillKey({ id = "x", type = "passive" }, nil, only({}))).toBe(nil)
	end)

	it("every attack motion has keys: ranged a release, melee a swing", function()
		for name, motion in AttackMotions.motions do
			local keys = SfxRules.attackKeys(name)
			local any = false
			for _, key in { keys.start, keys.swing, keys.release } do
				if key then
					any = true
					expect({ name, key, Sfx.has(key) }).toEqual({ name, key, true })
				end
			end
			expect({ name, any }).toEqual({ name, true })
			if motion.ranged then
				expect({ name, keys.release ~= nil }).toEqual({ name, true })
			else
				expect({ name, keys.swing ~= nil }).toEqual({ name, true })
			end
		end
		expect(SfxRules.attackKeys("bow").start).toBe("bow.draw")
		expect(SfxRules.attackKeys("slash1h", 3).swing).toBe("swing.thrust") -- S113: a step overrides the motion
		expect(SfxRules.attackKeys("slash1h", 1).swing).toBe("swing.light")
		expect(SfxRules.attackKeys("nope").swing).toBe("swing.light")
	end)

	it("hit material from the look, then the family, then flesh", function()
		for _, family in Families.ids do
			local material = Sfx.FAMILY_MATERIAL[family]
			expect({ family, material ~= nil and table.find(Sfx.MATERIALS, material) ~= nil }).toEqual({ family, true })
			expect(SfxRules.material(family, nil)).toBe(material)
		end
		local looks = 0
		for id, raw in MonsterLooks.raw do
			if raw.hitSound ~= nil then
				looks += 1
				expect({ id, table.find(Sfx.MATERIALS, raw.hitSound) ~= nil }).toEqual({ id, true })
			end
			local look = MonsterLooks.get(id)
			if look and look.hitSound then
				expect({ id, table.find(Sfx.MATERIALS, look.hitSound) ~= nil }).toEqual({ id, true })
			end
		end
		expect(looks >= 2).toBe(true)
		expect((MonsterLooks.get("rotEnt") :: any).hitSound).toBe("wood")
		expect((MonsterLooks.get("swampToad") :: any).hitSound).toBe("slime")
		expect(SfxRules.material(nil, nil)).toBe("flesh")
		expect(SfxRules.material("undead", nil)).toBe("bone")
		expect(SfxRules.material("undead", "wood")).toBe("wood")
		expect(SfxRules.material("undead", "nope")).toBe("bone")
		expect(SfxRules.hitKey("bone", function()
			return true
		end)).toBe("hit.bone")
		expect(SfxRules.hitKey("armor", function()
			return false
		end)).toBe("hit.flesh")
	end)
end)

describe("SfxRules mix (S111)", function()
	it("pickVoice: free first, else the lowest priority, then the oldest; never above the new one", function()
		local voices: { SfxRules.Voice } = {
			{ busy = true, priority = 3, startedAt = 1 },
			{ busy = false, priority = 0, startedAt = 0 },
			{ busy = true, priority = 1, startedAt = 2 },
		}
		expect(SfxRules.pickVoice(voices, 1)).toBe(2)
		voices[2].busy = true
		voices[2].priority = 1
		voices[2].startedAt = 5
		-- all busy: the lowest priority (1), the oldest of them (index 3, started at 2)
		expect(SfxRules.pickVoice(voices, 3)).toBe(3)
		expect(SfxRules.pickVoice(voices, 1)).toBe(3)
		local own: { SfxRules.Voice } = {
			{ busy = true, priority = 3, startedAt = 1 },
			{ busy = true, priority = 3, startedAt = 0.5 },
		}
		expect(SfxRules.pickVoice(own, 1)).toBe(nil)
		expect(SfxRules.pickVoice(own, 2)).toBe(nil)
		expect(SfxRules.pickVoice(own, 3)).toBe(2)
		expect(#own).toBe(2)
		expect(SfxRules.pickVoice({}, 3)).toBe(nil)
	end)

	it("allowed: the repeat window per key and the cooldown per key and source", function()
		local window = Config.Sfx.repeatWindow
		expect(window).toBe(0.05)
		local byKey: { [string]: number } = { ["hit.flesh"] = 10 }
		local bySource: { [string]: number } = {}
		local plain = def()
		expect(SfxRules.allowed(byKey, bySource, "hit.flesh", nil, 10.04, plain, window)).toBe(false)
		expect(SfxRules.allowed(byKey, bySource, "hit.flesh", nil, 10.06, plain, window)).toBe(true)
		expect(SfxRules.allowed(byKey, bySource, "hit.bone", nil, 10.01, plain, window)).toBe(true)
		local hurt = def({ cooldown = 0.35 })
		local key = "mob.animal.hurt"
		byKey[key] = 20
		bySource[SfxRules.sourceKey(key, "m1")] = 20
		expect(SfxRules.allowed(byKey, bySource, key, "m1", 20.2, hurt, window)).toBe(false)
		expect(SfxRules.allowed(byKey, bySource, key, "m2", 20.2, hurt, window)).toBe(true)
		expect(SfxRules.allowed(byKey, bySource, key, "m1", 20.36, hurt, window)).toBe(true)
		expect(SfxRules.allowed(byKey, bySource, key, nil, 20.2, hurt, window)).toBe(true)
	end)

	it("pitch, variant and volume", function()
		local d = def()
		expect(SfxRules.pitch(d, 0)).toBe(0.9)
		expect(SfxRules.pitch(d, 0.9999999) < 1.1 + 1e-9).toBe(true)
		expect(SfxRules.pitch(d, 0.5)).toBeNear(1, 1e-9)
		for _, u in { 0, 0.2, 0.34, 0.5, 0.67, 0.99, 0.9999999 } do
			local v = SfxRules.variant(d, u) :: number
			expect({ u, v >= 1 and v <= 3 }).toEqual({ u, true })
		end
		expect(SfxRules.variant(d, 0)).toBe(1)
		expect(SfxRules.variant(d, 0.9999999)).toBe(3)
		expect(SfxRules.variant(def({ ids = {} }), 0.5)).toBe(nil)
		local cfg = Config.Sfx
		local own = SfxRules.volume(d, "own", false, cfg)
		local party = SfxRules.volume(d, "party", false, cfg)
		local other = SfxRules.volume(d, "other", false, cfg)
		expect(own > party and party > other).toBe(true)
		expect(SfxRules.volume(d, "own", true, cfg)).toBe(own)
		expect(SfxRules.volume(d, "party", true, cfg)).toBe(party)
		expect(SfxRules.volume(d, "other", true, cfg) < other).toBe(true)
		expect(SfxRules.higher("other", "own")).toBe("own")
		expect(SfxRules.higher("party", "other")).toBe("party")
	end)

	it("Config.Sfx limits (DESIGN-16 §3)", function()
		local cfg = Config.Sfx
		expect(cfg.maxVoices.desktop).toBe(16)
		expect(cfg.maxVoices.touch).toBe(10)
		expect(cfg.maxDistance).toBe(Config.EffectRadius)
		expect(cfg.uiVoices >= 1).toBe(true)
	end)
end)

describe("AnimLab sfx (S111)", function()
	it("parses sfx calls", function()
		local cases: { { any } } = {
			{ { "sfx", "hit.flesh" }, "hit.flesh", nil, nil },
			{ { "sfx", "hit.flesh", "2" }, "hit.flesh", nil, 2 },
			{ { "sfx", "list" }, "list", nil, nil },
			{ { "sfx", "list", "mob." }, "list", "mob.", nil },
			{ { "sfx", "all", "ui." }, "all", "ui.", nil },
			{ { "sfx", "all" }, "all", nil, nil },
			{ { "sfx", "try", "123" }, "try", "123", nil },
		}
		for _, case in cases do
			local command, err = AnimLab.parse(case[1])
			expect({ case[1], err }).toEqual({ case[1], nil })
			local c = command :: AnimLab.Command
			expect({ case[1], c.action, c.id, c.slot, c.n }).toEqual({ case[1], "sfx", case[2], case[3], case[4] })
		end
	end)

	it("refuses bad sfx calls", function()
		local bad: { { any } } = {
			{ { "sfx" }, "animlab.error.sfx" },
			{ { "sfx", "try" }, "animlab.error.sfxId" },
			{ { "sfx", "try", "abc" }, "animlab.error.sfxId" },
			{ { "sfx", "try", "12.5" }, "animlab.error.sfxId" },
			{ { "sfx", "hit.flesh", "0" }, "animlab.error.sfx" },
			{ { "sfx", "hit.flesh", "1.5" }, "animlab.error.sfx" },
			{ { "sfx", "hit.flesh", "x" }, "animlab.error.sfx" },
		}
		for _, case in bad do
			local command, err = AnimLab.parse(case[1])
			expect({ case[1], command, err }).toEqual({ case[1], nil, case[2] })
		end
	end)

	it("the sfx texts exist in PL and EN", function()
		for _, key in
			{
				"animlab.error.sfxId",
				"animlab.sfx.played",
				"animlab.sfx.unknown",
				"animlab.sfx.empty",
				"animlab.sfx.list",
				"animlab.sfx.all",
				"animlab.sfx.try",
			}
		do
			expect({ key, en[key] ~= nil, pl[key] ~= nil }).toEqual({ key, true, true })
		end
	end)
end)
