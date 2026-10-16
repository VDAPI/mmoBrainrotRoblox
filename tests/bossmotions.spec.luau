--!strict
-- S117: Data/BossMotions (every attack of every boss has its own pose, an effect from the list, a shake in 0..1, a roar
-- and a death) and the styles it names.

local BossMotions = require("../src/shared/Data/BossMotions")
local Bosses = require("../src/shared/Data/Bosses")
local Config = require("../src/shared/Config")
local MonsterMotions = require("../src/shared/Data/MonsterMotions")
local Sfx = require("../src/shared/Data/Sfx")
local T = require("./Test")

T.describe("BossMotions (S117)", function()
	T.it("10. every boss and every attack has a motion, no dead entries", function()
		for _, boss in Bosses.list do
			local def = BossMotions.get(boss.id)
			T.expect({ boss.id, def ~= nil }).toEqual({ boss.id, true })
			if not def then
				continue
			end
			local ids: { [string]: boolean } = {}
			for _, attack in boss.attacks do
				ids[attack.id] = true
				local motion = def.attacks[attack.id]
				T.expect({ boss.id, attack.id, motion ~= nil }).toEqual({ boss.id, attack.id, true })
				if motion then
					T.expect({ attack.id, MonsterMotions.STYLES[motion.style] ~= nil }).toEqual({ attack.id, true })
					local impact = motion.impact or "none"
					T.expect({ attack.id, table.find(BossMotions.IMPACTS, impact) ~= nil }).toEqual({ attack.id, true })
					local shake = motion.shake or 0
					T.expect({ attack.id, shake >= 0 and shake <= 1 }).toEqual({ attack.id, true })
					if motion.sound then
						T.expect({ attack.id, Sfx.get(motion.sound) ~= nil }).toEqual({ attack.id, true })
					end
					if attack.leap then
						T.expect({ attack.id, (motion.arc or 0) > 0 }).toEqual({ attack.id, true })
					end
				end
			end
			for id in def.attacks do
				T.expect({ boss.id, id, ids[id] == true }).toEqual({ boss.id, id, true })
			end
			T.expect({ boss.id, MonsterMotions.STYLES[def.roar.style] ~= nil }).toEqual({ boss.id, true })
			T.expect({ boss.id, def.roar.shake >= 0 and def.roar.shake <= 1 }).toEqual({ boss.id, true })
			T.expect({ boss.id, def.roar.seconds > 0.65 }).toEqual({ boss.id, true })
			T.expect({ boss.id, MonsterMotions.DEATH[def.death.style] ~= nil }).toEqual({ boss.id, true })
			T.expect({ boss.id, string.match(def.death.light, "^#%x%x%x%x%x%x$") ~= nil }).toEqual({ boss.id, true })
			T.expect({ boss.id, (def.death.seconds or Config.MonsterLook.bossDeathSeconds) > 0 })
				.toEqual({ boss.id, true })
		end
		for id in BossMotions.byBoss do
			T.expect({ id, Bosses.get(id) ~= nil }).toEqual({ id, true })
		end
	end)

	T.it("11. two attacks of one boss never share a style", function()
		for id, def in BossMotions.byBoss do
			local seen: { [string]: string } = {}
			for attackId, motion in def.attacks do
				T.expect({ id, attackId, seen[motion.style] }).toEqual({ id, attackId, nil })
				seen[motion.style] = attackId
			end
		end
	end)
end)

-- S134 (bosses 2.0): time to react (a phone too) and complete mechanic data.
T.describe("Boss big blows and mechanics (S134)", function()
	T.it("an avoid blow winds up >= 1.8 s, a mechanic >= 3 s (a channel >= 4 s, its windup), data complete", function()
		for _, boss in Bosses.list do
			for _, attack in boss.attacks do
				local tag = `{boss.id}.{attack.id}`
				if attack.avoid then
					T.expect({ tag, attack.windup >= 1.8, attack.mechanic }).toEqual({ tag, true, nil })
				end
				if attack.mechanic == "split" then
					local split = attack.split
					T.expect({ tag, attack.windup >= 3, split ~= nil }).toEqual({ tag, true, true })
					if split then
						T.expect({ tag, split.missAll > 0 and split.missAll < 1 }).toEqual({ tag, true })
					end
				elseif attack.mechanic == "mark" then
					local mark = attack.mark
					T.expect({ tag, mark ~= nil }).toEqual({ tag, true })
					if mark then
						T.expect({ tag, mark.seconds >= 3, mark.self > 0 and mark.self < 1 })
							.toEqual({ tag, true, true })
					end
				elseif attack.mechanic == "channel" then
					local channel = attack.channel
					T.expect({ tag, channel ~= nil }).toEqual({ tag, true })
					if channel then
						T.expect({ tag, channel.seconds >= 4, attack.windup == channel.seconds })
							.toEqual({ tag, true, true })
						T.expect({ tag, channel.breakPct > 0, channel.stagger > 0 }).toEqual({ tag, true, true })
					end
				else
					T.expect({ tag, attack.split == nil and attack.mark == nil and attack.channel == nil })
						.toEqual({ tag, true })
				end
			end
		end
	end)
end)

-- S134c: the same reaction times for the monster abilities with the bosses 2.0 fields (the Invasion commander's blows);
-- a monster has only the split mechanic.
T.describe("Monster big blows and mechanics (S134c)", function()
	T.it("an avoid blow winds up >= 1.8 s, a split >= 3 s with a complete missAll, no mark or channel", function()
		local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
		for id, ability in MonsterAbilities.byId do
			if ability.avoid then
				T.expect({ id, ability.windup >= 1.8, ability.mechanic }).toEqual({ id, true, nil })
			end
			if ability.mechanic == "split" then
				local split = ability.split
				T.expect({ id, ability.windup >= 3, split ~= nil }).toEqual({ id, true, true })
				if split then
					T.expect({ id, split.missAll > 0 and split.missAll < 1 }).toEqual({ id, true })
				end
			else
				T.expect({ id, ability.mechanic, ability.split }).toEqual({ id, nil, nil })
			end
			if ability.fromHp then
				T.expect({ id, ability.fromHp > 0 and ability.fromHp < 1 }).toEqual({ id, true })
			end
		end
	end)
end)

-- S134e: the kits of Elites / Elites II have a motion on every plan (KIT_STYLES or special.default), every KIT_STYLES
-- entry names a style and a plan; the reaction times: a lethal blow >= 2.0 s, Pounce >= 1.2 s, Heavy Blow >= 1.6 s.
T.describe("Monster kits (S134e)", function()
	T.it("every kit ability has a style on every plan; the windups of the kit", function()
		local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
		for variant, kit in MonsterAbilities.KITS do
			for _, id in kit.abilities do
				for plan in MonsterMotions.PLANS do
					local style = MonsterMotions.styleFor(plan, nil, id)
					T.expect({ variant, plan, id, style ~= nil and MonsterMotions.STYLES[style] ~= nil })
						.toEqual({ variant, plan, id, true })
				end
			end
		end
		for plan, styles in MonsterMotions.KIT_STYLES do
			T.expect({ plan, MonsterMotions.PLANS[plan] ~= nil }).toEqual({ plan, true })
			for id, style in styles do
				T.expect({ plan, id, MonsterAbilities.get(id) ~= nil, MonsterMotions.STYLES[style] ~= nil })
					.toEqual({ plan, id, true, true })
			end
		end
		T.expect((MonsterAbilities.get("crush") :: any).windup >= 2.0).toBe(true)
		T.expect((MonsterAbilities.get("pounce") :: any).windup >= 1.2).toBe(true)
		T.expect((MonsterAbilities.get("heavyBlow") :: any).windup >= 1.6).toBe(true)
	end)
end)

T.describe("BossTuning.extra (FIX 2026-10-15)", function()
	T.it("shield and kiting attacks borrow a motion of their own boss and have sane numbers", function()
		local BossTuning = require("../src/shared/Data/BossTuning")
		for bossId, extra in BossTuning.extra :: any do
			T.expect({ bossId, Bosses.get(bossId) ~= nil }).toEqual({ bossId, true })
			for kind, spec in extra do
				local tag = `{bossId}.{kind}`
				T.expect({ tag, BossMotions.attack(bossId, spec.look) ~= nil }).toEqual({ tag, true })
				T.expect({ tag, spec.windup >= 1 and spec.damage > 0 }).toEqual({ tag, true })
				T.expect({ tag, (spec.every or spec.cooldown or 0) >= 3 }).toEqual({ tag, true })
				T.expect({ tag, spec.shape == "line" or spec.shape == "circle" }).toEqual({ tag, true })
			end
		end
	end)
end)
