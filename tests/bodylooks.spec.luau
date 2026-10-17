--!strict
-- W09: the game's body (Data/BodyLooks) and the hair colour on Roblox hairstyles (Logic/HairTint).

local BodyLooks = require("../src/shared/Data/BodyLooks")
local ClassLooks = require("../src/shared/Data/ClassLooks")
local HairTint = require("../src/shared/Logic/HairTint")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Body (W09)", function()
	it("has every body part and the face accessories", function()
		for _, field in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
			local id = BodyLooks.parts[field]
			expect(`{field} {type(id) == "number" and id > 0}`).toBe(`{field} true`)
		end
		expect(BodyLooks.eyebrows > 0 and BodyLooks.eyelashes > 0).toBe(true)
	end)

	it("keeps the old figure's height within 10% (hitboxes, camera)", function()
		local height = BodyLooks.bodyHeight * BodyLooks.scales.height
		local ratio = height / BodyLooks.STANDARD_HEIGHT
		expect(ratio >= 0.9 and ratio <= 1.1).toBe(true)
	end)

	it("has a hairstyle or a deliberate bare head for every creator style", function()
		for _, hair in ClassLooks.HAIRS do
			local def = BodyLooks.hairs[hair.style]
			local ok = def ~= nil and def.id > 0 or hair.style == "shaved"
			expect(`{hair.style} {ok}`).toBe(`{hair.style} true`)
		end
	end)
end)

describe("Hair tint (W09)", function()
	it("tints a light texture, lifted toward white", function()
		local mode, tint = HairTint.plan("#000000", true)
		expect(mode).toBe("texture")
		expect(math.abs(tint[1] - HairTint.LIFT) < 1e-9).toBe(true)
	end)

	it("keeps a black texture for dark colours, the plain colour for light ones", function()
		local dark, keep = HairTint.plan("#1E1A18", false)
		expect(dark).toBe("texture")
		expect(keep[1]).toBe(1)
		local light, plain = HairTint.plan("#E8E4DA", false)
		expect(light).toBe("flat")
		expect(math.abs(plain[1] - 0xE8 / 255) < 1e-9).toBe(true)
	end)

	it("every creator hair colour gets a plan", function()
		for _, hair in ClassLooks.HAIRS do
			local def = BodyLooks.hairs[hair.style]
			if def then
				local mode = HairTint.plan(hair.color, def.light)
				expect(mode == "texture" or mode == "flat").toBe(true)
			end
		end
	end)
end)
