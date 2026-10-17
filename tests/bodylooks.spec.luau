--!strict
-- W09: the game's body (Data/BodyLooks) and the hair colour on Roblox hairstyles (Logic/HairTint); W10: the creator's
-- looks (old saves, random looks, the resolved face).

local BodyLooks = require("../src/shared/Data/BodyLooks")
local CharacterLook = require("../src/shared/Logic/CharacterLook")
local ClassLooks = require("../src/shared/Data/ClassLooks")
local HairTint = require("../src/shared/Logic/HairTint")
local Rng = require("../src/shared/Logic/Rng")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Body (W09)", function()
	it("has every body part", function()
		for _, field in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
			local id = BodyLooks.parts[field]
			expect(`{field} {type(id) == "number" and id > 0}`).toBe(`{field} true`)
		end
	end)

	it("keeps the old figure's height within 10% (hitboxes, camera)", function()
		local height = BodyLooks.bodyHeight * BodyLooks.scales.height
		local ratio = height / BodyLooks.STANDARD_HEIGHT
		expect(ratio >= 0.9 and ratio <= 1.1).toBe(true)
	end)

	it("has a Roblox hairstyle for every creator hairstyle but the bare head", function()
		for _, hair in ClassLooks.HAIRS do
			local def = BodyLooks.hairs[hair.id]
			local ok = (def ~= nil and def.id > 0) ~= (hair.id == "hair_shaved")
			expect(`{hair.id} {ok}`).toBe(`{hair.id} true`)
		end
	end)
end)

describe("Creator looks (W10)", function()
	it("turns every S132 save into a valid look that keeps its meaning", function()
		for legacy, pair in ClassLooks.LEGACY_HAIRS do
			for _, face in ClassLooks.FACES do
				local look = CharacterLook.normalize({ face = face.id, skin = "skin_3", hair = legacy }) :: any
				expect(CharacterLook.isValid(look)).toBe(true)
				expect(`{legacy} {look.hair} {look.hairColor}`).toBe(`{legacy} {pair[1]} {pair[2]}`)
				expect(look.beard).toBe(face.legacyBeard or "beard_none")
				expect(look.paint).toBe(face.legacyPaint or "paint_none")
			end
		end
		-- a W10 save keeps its own beard even on the old bearded face
		local own = CharacterLook.normalize({
			face = "face_bearded",
			skin = "skin_1",
			hair = "hair_long",
			beard = "beard_none",
		})
		expect((own :: any).beard).toBe("beard_none")
	end)

	it("random looks are always valid, with natural skin tones", function()
		local rng = Rng.new(7)
		for _ = 1, 500 do
			local look = CharacterLook.random(function()
				return rng:next()
			end)
			expect(CharacterLook.isValid(look)).toBe(true)
			local i = table.find(
				(function()
					local ids = {}
					for _, s in ClassLooks.SKINS do
						table.insert(ids, s.id)
					end
					return ids
				end)(),
				look.skin
			)
			expect(i ~= nil and i <= CharacterLook.NATURAL_SKINS).toBe(true)
		end
		-- the extremes of the roll stay in range
		expect(CharacterLook.isValid(CharacterLook.random(function()
			return 0
		end))).toBe(true)
		expect(CharacterLook.isValid(CharacterLook.random(function()
			return 0.999999
		end))).toBe(true)
	end)

	it("resolves the face, the brows, the build and the paint", function()
		local look = CharacterLook.normalize({
			face = "face_young",
			skin = "skin_ash",
			hair = "hair_braid",
			hairColor = "hc_white",
			brows = "brows_3",
			beard = "beard_goatee",
			build = "build_strong",
			paint = "paint_rune",
			paintColor = "pc_woad",
		})
		local spec = CharacterLook.resolve({ classId = "Mage", look = look, robloxAvatar = false })
		local face = spec.face :: CharacterLook.FaceSpec
		expect(face.head).toBe(BodyLooks.heads.face_young.head)
		expect(face.browsId).toBe(BodyLooks.brows.brows_3)
		expect(face.beard).toBe("beard_goatee")
		expect(face.paintColor).toBe(ClassLooks.paintColorById.pc_woad.color)
		expect(spec.build.width).toBe(BodyLooks.builds.build_strong.width)
		local other =
			CharacterLook.resolve({ classId = "Mage", look = CharacterLook.normalize(nil), robloxAvatar = false })
		expect(spec.catalogKey ~= other.catalogKey).toBe(true)
		local avatar = CharacterLook.resolve({ classId = "Mage", look = look, robloxAvatar = true })
		expect(avatar.build.width).toBe(1)
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
			local def = BodyLooks.hairs[hair.id]
			for _, c in ClassLooks.HAIR_COLORS do
				local mode = HairTint.plan(c.color, if def then def.light else false)
				expect(mode == "texture" or mode == "flat").toBe(true)
			end
		end
	end)
end)
