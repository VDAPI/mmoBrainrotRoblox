--!strict
-- Studio review 2026-10-21: a monster's regular blow is drawn back visibly before it lands (Logic/BasicBlow,
-- Data/Combat.basicWind), the server's hit and the clients' swing share the draw, and every real model with bone clips
-- lands its clip's blow at it (AnimLab `mob <kind> attack1` reported peak 0 / hit 0 / end 0.38 for every model: the
-- strike-now fallback with no draw).

local fs = require("@lune/fs")

local BasicBlow = require("../src/shared/Logic/BasicBlow")
local Combat = require("../src/shared/Data/Combat")
local Gait = require("../src/shared/Logic/Gait")
local MonsterClips = require("../src/shared/Data/MonsterClips")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local Monsters = require("../src/shared/Data/Monsters")
local MotionKeys = require("../src/shared/Logic/MotionKeys")
local T = require("./Test")

local VARIANTS = { "normal", "elite", "elite2", "boss" }

local function kinds(): { string }
	local out = {}
	for id in Monsters.byId do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

T.describe("A monster's regular blow (studio review 2026-10-21)", function()
	T.it("is drawn back visibly: well past the strike, longer for Elites, never a spell's windup", function()
		for _, attack in { "melee", "ranged" } do
			local normal = BasicBlow.wind(attack, "normal")
			for _, variant in VARIANTS do
				local w = BasicBlow.wind(attack, variant)
				-- the draw itself (the windup before the strike) lasts a third of a second at least
				T.expect({ attack, variant, w - Gait.STRIKE_SECONDS >= 0.35 }).toEqual({ attack, variant, true })
				-- AnimationController: a windup over 1 s is a cast
				T.expect({ attack, variant, w <= 1 }).toEqual({ attack, variant, true })
				if variant ~= "normal" then
					T.expect({ attack, variant, w > normal }).toEqual({ attack, variant, true })
				end
			end
			T.expect(normal >= 0.45 and normal <= 0.6).toBe(true)
		end
		T.expect(BasicBlow.throwWind("elite2") > Combat.basicWind.throw).toBe(true)
	end)

	T.it("leaves time between blows: every kind's interval outlasts its longest draw", function()
		for _, id in kinds() do
			local kind = Monsters.get(id) :: any
			local interval = Combat.monsterAttackInterval / math.max(0.1, kind.speed)
			local w = BasicBlow.wind(kind.attack, "boss")
			T.expect({ id, interval > w + Gait.RECOVER_SECONDS }).toEqual({ id, true })
		end
	end)

	T.it("lands every bone clip's blow at the draw, each model with its own clip", function()
		local seen, shapes = 0, {}
		for _, id in kinds() do
			local kind = Monsters.get(id) :: any
			local look = MonsterLooks.get(id, kind.region)
			local asset = look and look.asset
			if asset and asset.rig == "bones" and MonsterClips.get(asset.model) then
				local keys, w, slot = MotionKeys.basicBlow(id)
				local k = assert(keys, id)
				local peak = MotionKeys.at(k, "peak") :: number
				local hit = MotionKeys.at(k, "hit") :: number
				local finish = MotionKeys.at(k, "end") :: number
				-- a draw before the blow (not the strike-now pose: peak 0, hit 0)
				T.expect({ id, peak > 0.25 }).toEqual({ id, true })
				-- the clip's blow where the server's lands
				T.expect({ id, slot, math.abs(hit - w) < 0.02 }).toEqual({ id, slot, true })
				T.expect({ id, finish > hit }).toEqual({ id, true })
				-- the slot has its blow marked
				local s = MonsterClips.slotsFor(asset.model)[slot]
				T.expect({ id, slot, s ~= nil and s.hit ~= nil }).toEqual({ id, slot, true })
				shapes[string.format("%.2f", finish)] = true
				seen += 1
			end
		end
		T.expect(seen >= 20).toBe(true)
		local distinct = 0
		for _ in shapes do
			distinct += 1
		end
		T.expect(distinct > 3).toBe(true)
	end)

	T.it("fits a bone clip like client/Anim/BoneClips: late start or slower play, the blow at the lead", function()
		local slow = { from = 0, to = 30, rate = 1, hit = 0.4 } -- blow before the lead: plays slower
		local late = { from = 0, to = 30, rate = 1, hit = 1.5 } -- blow after the lead: starts late
		for _, slot in { slow, late } do
			local keys = MotionKeys.boneClip(slot :: any, 0.6)
			T.expect(MotionKeys.at(keys, "hit") :: number).toBeNear(0.6, 1e-9)
		end
		local t0, fit = MotionKeys.boneFit(late :: any, 0.6)
		T.expect(t0).toBeNear(0.9, 1e-9)
		T.expect(fit).toBe(1)
		local t1, fit1 = MotionKeys.boneFit(slow :: any, 0.6)
		T.expect(t1).toBe(0)
		T.expect(fit1).toBeNear(0.4 / 0.6, 1e-9)
		-- the client's mixer runs the same rule
		local src = fs.readFile("src/client/Anim/BoneClips.luau")
		T.expect(string.find(src, "self.fit = math.max(0.4, hit / reach)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(src, "self.time = hit - reach", 1, true) ~= nil).toBe(true)
	end)

	T.it("is one rule on the server, the clients and AnimLab", function()
		local monster = fs.readFile("src/server/Entities/Monster.luau")
		T.expect(string.find(monster, "BasicBlow.wind(self.def.attack, self.variant)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(monster, "BasicBlow.shot(self.def.attack, self.stats.damageKind)", 1, true) ~= nil)
			.toBe(true)
		T.expect(string.find(monster, "BasicBlow.throwWind(self.variant)", 1, true) ~= nil).toBe(true)
		local fx = fs.readFile("src/client/Controllers/CombatFxController.luau")
		T.expect(string.find(fx, "BasicBlow.slot(shot)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(fx, 'BasicBlow.slot("melee")', 1, true) ~= nil).toBe(true)
		local lab = fs.readFile("src/client/Controllers/AnimLabController.luau")
		T.expect(string.find(lab, "MotionKeys.basicBlow(id)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(lab, "BoneClips.step(bone.mixer, 0)", 1, true) ~= nil).toBe(true)
		-- the slot a draw plays: a bolt is a spell, every other draw the second attack (AnimationController's rule)
		T.expect(BasicBlow.slot("bolt")).toBe("cast")
		T.expect(BasicBlow.slot("arrow")).toBe("attack2")
		T.expect(BasicBlow.slot("melee")).toBe("attack2")
	end)
end)

T.describe("AnimLab: looks on the floor, cameras on the look (studio review 2026-10-21)", function()
	T.it("stands a real model on its feet and frames the look with its cast bar", function()
		local lab = fs.readFile("src/client/Controllers/AnimLabController.luau")
		-- a real model's pivot is its feet (MonsterView: groundOffset), a generated look's its root
		T.expect(
			string.find(lab, "local lift = if info.real then 0 else info.hipHeight + info.rootHalf", 1, true) ~= nil
		)
			.toBe(true)
		local view = fs.readFile("src/client/Controllers/MonsterViewController.luau")
		T.expect(string.find(view, "real:PivotTo(cframe * groundOffset(", 1, true) ~= nil).toBe(true)
		T.expect(string.find(lab, "frameLook(model)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(lab, "LAB.castBarAbove", 1, true) ~= nil).toBe(true)
		T.expect(string.find(lab, '"SubjectFloor"', 1, true) ~= nil).toBe(true)
	end)
end)

return nil
