--!strict
-- S113: real animation clips over the procedural poses (Logic/ClipFit): ids, defaults, the speed that puts the "Hit"
-- marker on the server's hit, the clip of a combo step and the clip data.

local AttackMotions = require("../src/shared/Data/AttackMotions")
local ClipFit = require("../src/shared/Logic/ClipFit")
local SkillMotions = require("../src/shared/Data/SkillMotions")
local WeaponLooks = require("../src/shared/Data/WeaponLooks")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function checkClip(label: string, ref: ClipFit.ClipRef)
	local clip = ClipFit.normalize(ref)
	expect({ label, clip.id, ClipFit.validId(clip.id) }).toEqual({ label, clip.id, true })
	expect({ label, clip.hit ~= nil and clip.hit ~= "" }).toEqual({ label, true })
	if clip.speed then
		expect({ label, clip.speed >= ClipFit.MIN_SPEED and clip.speed <= ClipFit.MAX_SPEED }).toEqual({ label, true })
	end
	if clip.hitTime then
		expect({ label, clip.hitTime > 0 }).toEqual({ label, true })
	end
end

describe("ClipFit (S113)", function()
	it("validId", function()
		expect(ClipFit.validId("rbxassetid://123")).toBe(true)
		for _, bad in { "", "rbxassetid://", "rbxassetid://12a", "http://example.com/1", "123", "rbxtemp://5" } do
			expect({ bad, ClipFit.validId(bad) }).toEqual({ bad, false })
		end
	end)

	it("normalize", function()
		expect(ClipFit.normalize("rbxassetid://5")).toEqual({ id = "rbxassetid://5", hit = "Hit" })
		expect(ClipFit.normalize({ id = "rbxassetid://5" })).toEqual({ id = "rbxassetid://5", hit = "Hit" })
		expect(ClipFit.normalize({ id = "rbxassetid://5", hit = "Strike", speed = 1.2, hitTime = 0.3 })).toEqual({
			id = "rbxassetid://5",
			hit = "Strike",
			speed = 1.2,
			hitTime = 0.3,
		})
	end)

	it("speed", function()
		local function check(clip: ClipFit.Clip, serverHit: number, marker: number?, speed: number, fits: boolean)
			local s, ok = ClipFit.speed(clip, serverHit, marker)
			expect(s).toBeNear(speed, 1e-9)
			expect(ok).toBe(fits)
		end
		check({ id = "rbxassetid://1", hitTime = 0.36 }, 0.18, nil, 2.0, true)
		check({ id = "rbxassetid://1", hitTime = 0.9 }, 0.18, nil, 2.5, false)
		check({ id = "rbxassetid://1" }, 0.18, nil, 1, true)
		check({ id = "rbxassetid://1", speed = 1.3 }, 0.18, nil, 1.3, true)
		-- exactly at a limit still fits; just past it within the tolerance too
		check({ id = "rbxassetid://1", hitTime = 0.45 }, 0.18, nil, 2.5, true)
		check({ id = "rbxassetid://1", hitTime = 0.05 }, 0.1, nil, 0.5, true)
		check({ id = "rbxassetid://1", hitTime = 0.02 }, 0.1, nil, 0.5, false)
		-- a measured marker wins over the data's hitTime
		check({ id = "rbxassetid://1", hitTime = 0.9 }, 0.2, 0.3, 1.5, true)
		-- no server hit (a skill without hit / release): the data's speed
		check({ id = "rbxassetid://1", hitTime = 0.3, speed = 1.1 }, 0, nil, 1.1, true)
	end)

	it("clip data: ids, at most three per list, markers, speeds, known weapon types", function()
		for name, motion in AttackMotions.motions do
			local clips = motion.clips or {}
			expect({ name, #clips <= ClipFit.MAX_CLIPS }).toEqual({ name, true })
			for i, ref in clips do
				checkClip(`{name}[{i}]`, ref)
			end
		end
		for weaponType, clips in AttackMotions.clipsByWeapon do
			local def = WeaponLooks.list[weaponType]
			expect({ weaponType, def ~= nil and not AttackMotions.offhand[weaponType] }).toEqual({ weaponType, true })
			expect({ weaponType, #clips >= 1 and #clips <= ClipFit.MAX_CLIPS }).toEqual({ weaponType, true })
			for i, ref in clips do
				checkClip(`{weaponType}[{i}]`, ref)
			end
		end
		for id, motion in SkillMotions.motions do
			if motion.clip then
				checkClip(id, motion.clip)
			end
		end
	end)

	it("attackClip: the weapon type's clips before the motion's, step i -> clips[i], nil without clips", function()
		local source: ClipFit.Source = {
			motions = {
				slash1h = { clips = { "rbxassetid://11", { id = "rbxassetid://12", hitTime = 0.2 } } },
				smash = {},
				unarmed = {},
			},
			clipsByWeapon = { axe1h = { "rbxassetid://21" } },
			byWeapon = { sword1h = "slash1h", axe1h = "slash1h", mace1h = "smash" },
		}
		expect(ClipFit.attackClip("sword1h", 1, source)).toEqual({ id = "rbxassetid://11", hit = "Hit" })
		expect(ClipFit.attackClip("sword1h", 2, source)).toEqual({ id = "rbxassetid://12", hit = "Hit", hitTime = 0.2 })
		expect(ClipFit.attackClip("sword1h", 3, source)).toBeNil()
		expect(ClipFit.attackClip("axe1h", 1, source)).toEqual({ id = "rbxassetid://21", hit = "Hit" })
		expect(ClipFit.attackClip("axe1h", 2, source)).toBeNil()
		expect(ClipFit.attackClip("mace1h", 1, source)).toBeNil()
		expect(ClipFit.attackClip(nil, 1, source)).toBeNil()
		expect(#(ClipFit.attackClips("sword1h", source) :: { ClipFit.ClipRef })).toBe(2)
		-- the game data has no clips yet: every weapon plays its poses
		for weaponType in AttackMotions.byWeapon do
			if ClipFit.attackClips(weaponType) == nil then
				expect(ClipFit.attackClip(weaponType, 1)).toBeNil()
			end
		end
	end)
end)
