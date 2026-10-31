--!strict
-- W09: the game's body (Data/BodyLooks) and the hair colour on Roblox hairstyles (Logic/HairTint); W10: the creator's
-- looks (old saves, random looks, the resolved face); hair fixes 2026-10-31: the new hairstyles, old ids and the colour
-- ranges of toned hairs.

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

	-- hair fixes 2026-10-31 (tester: "all hairstyles except 7, 9 and 12 are poorly made")
	it("maps every Roblox hairstyle to a creator hairstyle, each Roblox hair once", function()
		local seen: { [number]: string } = {}
		for hairId, def in BodyLooks.hairs do
			expect(`{hairId} {ClassLooks.hairById[hairId] ~= nil}`).toBe(`{hairId} true`)
			expect(`{hairId} {seen[def.id] or "-"}`).toBe(`{hairId} -`)
			seen[def.id] = hairId
			-- a texture that is not light has its colour, a light one is tinted as it is
			local toned = def.tone ~= nil and string.match(def.tone, "^#%x%x%x%x%x%x$") ~= nil
			expect(`{hairId} {toned}`).toBe(`{hairId} {not def.light}`)
		end
		local count = 0
		for _ in BodyLooks.hairs do
			count += 1
		end
		expect(count).toBe(#ClassLooks.HAIRS - 1)
	end)
end)

describe("Creator looks (W10)", function()
	it("turns every S132 save into a valid look that keeps its meaning", function()
		for legacy, pair in ClassLooks.LEGACY_HAIRS do
			-- an old id is no hairstyle of today; the hairstyle it points at is, and offers the colour it gives
			expect(`{legacy} {ClassLooks.hairById[legacy] == nil} {ClassLooks.hairById[pair[1]] ~= nil}`).toBe(
				`{legacy} true true`
			)
			local color = pair[2] or ClassLooks.DEFAULT_LOOK.hairColor :: string
			expect(`{legacy} {table.find(CharacterLook.hairColors(pair[1]), color) ~= nil}`).toBe(`{legacy} true`)
			for _, face in ClassLooks.FACES do
				local look = CharacterLook.normalize({ face = face.id, skin = "skin_3", hair = legacy }) :: any
				expect(CharacterLook.isValid(look)).toBe(true)
				expect(`{legacy} {look.hair} {look.hairColor}`).toBe(`{legacy} {pair[1]} {color}`)
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

	it("hair fixes 2026-10-31: a removed or renamed hairstyle keeps the save's own colour", function()
		for old, now in { hair_curly = "hair_fringe", hair_bangs = "hair_bob" } do
			for _, c in ClassLooks.HAIR_COLORS do
				local look =
					CharacterLook.normalize({ face = "face_calm", skin = "skin_2", hair = old, hairColor = c.id })
				expect(`{old} {c.id} {look.hair} {look.hairColor}`).toBe(`{old} {c.id} {now} {c.id}`)
			end
		end
	end)

	it(
		"hair fixes 2026-10-31: a hairstyle with its own colours offers the near ones, a save gets the nearest",
		function()
			-- light textures take every colour
			for _, id in { "hair_short", "hair_fringe", "hair_slicked", "hair_bob", "hair_long", "hair_straight" } do
				expect(`{id} {#CharacterLook.hairColors(id)}`).toBe(`{id} {#ClassLooks.HAIR_COLORS}`)
			end
			expect(#CharacterLook.hairColors("hair_shaved")).toBe(#ClassLooks.HAIR_COLORS)
			-- every range keeps black and is in the palette's order
			for _, hair in ClassLooks.HAIRS do
				local offered = CharacterLook.hairColors(hair.id)
				expect(`{hair.id} {offered[1]}`).toBe(`{hair.id} hc_black`)
				local last = 0
				for _, id in offered do
					local at = 0
					for i, c in ClassLooks.HAIR_COLORS do
						if c.id == id then
							at = i
						end
					end
					expect(`{hair.id} {id} {at > last}`).toBe(`{hair.id} {id} true`)
					last = at
				end
			end
			-- Belle Of Belfast (red): the reds and browns, no blond, grey or white
			local braid = CharacterLook.hairColors("hair_braid")
			for _, id in { "hc_black", "hc_brown", "hc_auburn", "hc_red", "hc_copper" } do
				expect(`{id} {table.find(braid, id) ~= nil}`).toBe(`{id} true`)
			end
			for _, id in { "hc_blond", "hc_paleblond", "hc_grey", "hc_white" } do
				expect(`{id} {table.find(braid, id) ~= nil}`).toBe(`{id} false`)
			end
			-- the black textures stay dark, the brown one stops before the blonds, the pastel bun takes the whole palette
			for _, id in { "hair_swept", "hair_sidetail" } do
				expect(`{id} {table.find(CharacterLook.hairColors(id), "hc_blond") ~= nil}`).toBe(`{id} false`)
			end
			expect(table.find(CharacterLook.hairColors("hair_charmer"), "hc_chestnut") ~= nil).toBe(true)
			expect(table.find(CharacterLook.hairColors("hair_charmer"), "hc_blond") ~= nil).toBe(false)
			expect(#CharacterLook.hairColors("hair_bun")).toBe(#ClassLooks.HAIR_COLORS)
			-- a colour a hairstyle does not offer: the nearest one, never a different hairstyle; a client may not send it
			expect(CharacterLook.fitHairColor("hair_braid", "hc_red")).toBe("hc_red")
			expect(CharacterLook.fitHairColor("hair_braid", "hc_blond")).toBe("hc_copper")
			expect(CharacterLook.fitHairColor("hair_swept", "hc_brown")).toBe("hc_dark")
			local look = CharacterLook.normalize({
				face = "face_calm",
				skin = "skin_2",
				hair = "hair_braid",
				hairColor = "hc_white",
			})
			expect(`{look.hair} {table.find(braid, look.hairColor :: string) ~= nil}`).toBe("hair_braid true")
			local sent = table.clone(look) :: any
			sent.hairColor = "hc_white"
			expect(CharacterLook.isValid(sent)).toBe(false)
			expect(CharacterLook.isValid(look)).toBe(true)
		end
	)

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
				local mode = HairTint.plan(c.color, if def then def.light else false, def and def.tone)
				expect(mode == "texture" or mode == "flat").toBe(true)
			end
		end
	end)

	it("hair fixes 2026-10-31: nudges a toned texture to the colour's hue and never goes flat", function()
		local function close(a: number, b: number): boolean
			return math.abs(a - b) < 1e-6
		end
		-- a colour darker than the texture: exactly the colour (texture times tint)
		local mode, t = HairTint.plan("#4A3020", false, "#9A4526")
		expect(mode).toBe("texture")
		local r, g, b = HairTint.channels("#4A3020")
		local tr, tg, tb = HairTint.channels("#9A4526")
		expect(close(t[1] * tr, r) and close(t[2] * tg, g) and close(t[3] * tb, b)).toBe(true)
		expect(HairTint.reach("#4A3020", "#9A4526") <= 1).toBe(true)
		-- a brighter one: the same hue, the brightest channel of the tint at 1
		for _, hex in { "#E8E4DA", "#C9A86A", "#9A9690" } do
			local n = HairTint.nudge(hex, "#2B2724")
			expect(close(math.max(n[1], n[2], n[3]), 1)).toBe(true)
			local cr, cg = HairTint.channels(hex)
			local kr, kg = HairTint.channels("#2B2724")
			expect(close((n[1] * kr) / (n[2] * kg), cr / cg)).toBe(true)
		end
		-- every offered colour of every toned hair keeps at least 1 / REACH of its brightness
		for hairId, def in BodyLooks.hairs do
			for _, id in CharacterLook.hairColors(hairId) do
				local c = ClassLooks.hairColorById[id].color :: string
				local ok = def.tone == nil or HairTint.reach(c, def.tone) <= HairTint.REACH
				expect(`{hairId} {id} {ok}`).toBe(`{hairId} {id} true`)
			end
		end
	end)
end)
