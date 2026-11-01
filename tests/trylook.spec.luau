--!strict
-- Catalog clothing 2026-11-01 (docs/WYGLAD-KLAS.md §3): the dev try-on /trylook (Logic/TryLook): the parser, the body
-- of a bundle, the merge of a call into the trial and its chat text; every refusal key in both languages.

local AdminCommands = require("../src/shared/Data/AdminCommands")
local BodyLooks = require("../src/shared/Data/BodyLooks")
local TryLook = require("../src/shared/Logic/TryLook")
local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local function parse(line: string): (any, string?, any)
	return TryLook.parse(string.split(line, " "))
end

T.describe("Try-on of catalog items (/trylook, 2026-11-01)", function()
	T.it("1. items with a type (catalog spellings too) and an order, garments off, bare, no hair", function()
		local parsed = parse("9228400498:JacketAcc 9228379908:pants:6 5830109763:Shoulder 617605556 -belt -Hair -all")
		T.expect(parsed.kind).toBe("items")
		T.expect(parsed.pieces).toEqual({
			{ id = 9228400498, type = "Jacket", layered = true, order = 10 },
			{ id = 9228379908, type = "Pants", layered = true, order = 6 },
			{ id = 5830109763, type = "Shoulder", layered = false },
			{ id = 617605556, type = "Hat", layered = false },
		})
		T.expect(parsed.hide).toEqual({ "belt" })
		T.expect({ parsed.bare, parsed.hideHair }).toEqual({ true, true })
		T.expect(select(2, parse("12:Cape"))).toBe("admin.trylook.type")
		T.expect(select(2, parse("12:Jacket:x"))).toBe("admin.trylook.order")
		T.expect(select(2, parse("12:Jacket:4:5"))).toBe("admin.trylook.id")
		T.expect(select(2, parse("abc"))).toBe("admin.trylook.id")
		T.expect(select(2, parse("0:Hat"))).toBe("admin.trylook.id")
		T.expect(select(2, parse("12 -wings"))).toBe("admin.trylook.garment")
	end)

	T.it("2. show, clear and the bodies: presets, a bundle, five or six part ids, the game's own", function()
		T.expect(TryLook.parse({})).toEqual({ kind = "show" })
		T.expect(parse("clear")).toEqual({ kind = "clear" })
		T.expect(select(2, parse("clear now"))).toBe("admin.usage.trylook")
		T.expect(parse("body addison")).toEqual({ kind = "body", body = BodyLooks.trialBodies.addison.parts })
		local blocky = parse("body Blocky")
		T.expect(blocky.kind).toBe("body")
		T.expect(BodyLooks.isClassic(blocky.body)).toBe(true)
		T.expect(BodyLooks.isClassic(BodyLooks.trialBodies.addison.parts)).toBe(false)
		T.expect(BodyLooks.isClassic(nil)).toBe(false)
		T.expect(BodyLooks.classicScales.bodyType).toBe(0)
		T.expect(parse("body Billie")).toEqual({ kind = "body", bundle = 995 })
		T.expect(parse("body 988")).toEqual({ kind = "body", bundle = 988 })
		T.expect(parse("body dawson")).toEqual({ kind = "body" })
		T.expect(parse("body off")).toEqual({ kind = "body" })
		T.expect(parse("body 1 2 3 4 5")).toEqual({
			kind = "body",
			body = { Torso = 1, LeftArm = 2, RightArm = 3, LeftLeg = 4, RightLeg = 5 },
		})
		T.expect(parse("body 9 1 2 3 4 5").body.Head).toBe(9)
		T.expect(select(2, parse("body"))).toBe("admin.trylook.body")
		T.expect(select(2, parse("body 1 2 3"))).toBe("admin.trylook.body")
		T.expect(select(2, parse("body 1 2 x 4 5"))).toBe("admin.trylook.body")
		T.expect(select(2, parse("body nobody"))).toBe("admin.trylook.body")
		for name, preset in BodyLooks.trialBodies do
			-- the classic blocky figure has no bundle and sets every part to 0, the head too
			local classic = BodyLooks.isClassic(preset.parts)
			T.expect({ name, preset.bundle > 0 or classic, name == string.lower(name) }).toEqual({ name, true, true })
			for field in if classic then {} else preset.parts or {} do
				T.expect({ name, field, table.find(BodyLooks.PART_FIELDS, field) ~= nil and field ~= "Head" })
					.toEqual({ name, field, true })
			end
		end
	end)

	T.it(
		"2b. proportions: presets (f brings the Jordan body), numbers over the game's scales, off, the merge",
		function()
			local c = parse("scale C")
			T.expect(c).toEqual({
				kind = "scale",
				scales = { head = 0.75, height = 1.05, width = 0.95, depth = 1, bodyType = 0, proportion = 0 },
			})
			local f = parse("scale f")
			T.expect(f.body).toEqual(BodyLooks.trialBodies.jordan.parts)
			T.expect(f.scales.bodyType).toBe(0.5)
			local typed = parse("scale 0.7 1.1")
			T.expect(typed.scales.head).toBe(0.7)
			T.expect(typed.scales.height).toBe(1.1)
			T.expect(typed.scales.width).toBe(BodyLooks.scales.width)
			T.expect(parse("scale off")).toEqual({ kind = "scale" })
			T.expect(select(2, parse("scale"))).toBe("admin.trylook.scale")
			T.expect(select(2, parse("scale x"))).toBe("admin.trylook.scale")
			T.expect(select(2, parse("scale 3"))).toBe("admin.trylook.scale")
			T.expect(select(2, parse("scale 1 1 1 1 1 1 1"))).toBe("admin.trylook.scale")
			local trial = TryLook.merge(nil, f)
			T.expect(trial and trial.scales and trial.scales.head).toBe(0.8)
			T.expect(trial and trial.body).toEqual(BodyLooks.trialBodies.jordan.parts)
			T.expect(string.find(TryLook.describe(trial), "scale head=0.8", 1, true) ~= nil).toBe(true)
			local off = TryLook.merge(trial, parse("scale off"))
			T.expect(off and off.scales).toBeNil()
			T.expect(TryLook.merge({ scales = { head = 1 } }, parse("scale off"))).toBeNil()
			for name, preset in BodyLooks.trialScales do
				for _, field in { "head", "height", "width", "depth", "bodyType", "proportion" } do
					T.expect({ name, field, type(preset[field]) }).toEqual({ name, field, "number" })
				end
			end
		end
	)

	T.it("3. the body parts of a bundle's items (the head stays the face's)", function()
		local items = {
			{ Id = 11, Name = "Head", Type = "Asset", AssetType = "DynamicHead" },
			{ Id = 12, Type = "Asset", AssetType = "Torso" },
			{ Id = 13, Type = "Asset", AssetType = "LeftArm" },
			{ Id = 14, Type = "Asset", AssetType = "RightArm" },
			{ Id = 15, Type = "Asset", AssetType = "LeftLeg" },
			{ Id = 16, Type = "Asset", AssetType = "RightLeg" },
			{ Id = 17, Type = "Asset", AssetType = "EyebrowAccessory" },
			{ Id = 18, Type = "UserOutfit" },
		}
		T.expect(TryLook.bodyFromBundle(items))
			.toEqual({ Torso = 12, LeftArm = 13, RightArm = 14, LeftLeg = 15, RightLeg = 16 })
		T.expect(TryLook.bodyFromBundle({ { Id = 17, AssetType = "EyebrowAccessory" } })).toBeNil()
		T.expect(TryLook.bodyFromBundle(nil)).toBeNil()
	end)

	T.it("4. a call replaces its half of the trial and keeps the other; the text names everything", function()
		local items = parse("9001:Jacket 9002 -belt")
		local trial = TryLook.merge(nil, items)
		local body = TryLook.merge(trial, parse("body 1 2 3 4 5"))
		T.expect((body :: any).pieces).toEqual(items.pieces)
		T.expect((body :: any).body).toEqual({ Torso = 1, LeftArm = 2, RightArm = 3, LeftLeg = 4, RightLeg = 5 })
		T.expect(TryLook.describe(body))
			.toBe("9001:Jacket@10 9002:Hat; -belt; body Torso=1 LeftArm=2 RightArm=3 LeftLeg=4 RightLeg=5")
		local noBody = TryLook.merge(body, parse("body off"))
		T.expect((noBody :: any).body).toBeNil()
		T.expect(TryLook.describe(TryLook.merge(nil, parse("-all -hair")))).toBe("-all -hair")
		T.expect(TryLook.merge(trial, parse("body off")) ~= nil).toBe(true)
		T.expect(TryLook.merge(TryLook.merge(nil, parse("body 988")), parse("body off"))).toBeNil()
		T.expect(TryLook.describe(nil)).toBe("")
	end)

	T.it("5. the command and its texts in both languages", function()
		local def = AdminCommands.get("trylook")
		T.expect(def ~= nil).toBe(true)
		T.expect(#(def :: any).args).toBe(8)
		for _, key in
			{
				"admin.usage.trylook",
				"admin.trylook.now",
				"admin.trylook.none",
				"admin.trylook.cleared",
				"admin.trylook.id",
				"admin.trylook.type",
				"admin.trylook.order",
				"admin.trylook.garment",
				"admin.trylook.body",
				"admin.trylook.bundle",
				"admin.trylook.scale",
			}
		do
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
		end
	end)
end)
