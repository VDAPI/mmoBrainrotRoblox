--!strict
-- S112: effect textures (Data/VfxTextures) against the generator's manifest (art/vfx/manifest.json) and the PNG files,
-- the new Config.Vfx limits and the texture keys of Data/SkillVfx.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local AnimLab = require("../src/shared/Logic/AnimLab")
local Classes = require("../src/shared/Data/Classes")
local Config = require("../src/shared/Config")
local SkillVfx = require("../src/shared/Data/SkillVfx")
local Test = require("./Test")
local VfxTextures = require("../src/shared/Data/VfxTextures")

local describe, it, expect = Test.describe, Test.it, Test.expect

local MANIFEST = "art/vfx/manifest.json"
local PNG_SIGNATURE = "\137PNG\r\n\26\n"
local FRAMES_OF_GRID: { [string]: number } = { ["2x2"] = 4, ["4x4"] = 16, ["8x8"] = 64 }

local function manifest(): { [string]: any }
	return serde.decode("json", fs.readFile(MANIFEST))
end

local function isPowerOfTwo(n: number): boolean
	local p = 1
	while p < n do
		p *= 2
	end
	return p == n
end

describe("Data/VfxTextures (S112)", function()
	it("ORDER holds every key of the list exactly once", function()
		local seen: { [string]: boolean } = {}
		for _, key in VfxTextures.ORDER do
			if seen[key] then
				error(`{key} twice in ORDER`)
			end
			seen[key] = true
			if not VfxTextures.list[key] then
				error(`{key} in ORDER but not in the list`)
			end
		end
		for key in VfxTextures.list do
			if not seen[key] then
				error(`{key} missing from ORDER`)
			end
		end
	end)

	it("matches the manifest row by row (keys, order, file, size, kind, flipbook)", function()
		local data = manifest()
		expect(data.version).toBe(1)
		local rows = data.textures
		expect(#rows).toBe(#VfxTextures.ORDER)
		for i, row in rows do
			local key = VfxTextures.ORDER[i]
			if row.key ~= key then
				error(`row {i}: manifest {row.key}, ORDER {key}`)
			end
			local def = VfxTextures.list[key]
			for _, field in { "file", "w", "h", "kind", "grid", "frames" } do
				if (def :: any)[field] ~= row[field] then
					error(`{key}.{field}: data {tostring((def :: any)[field])}, manifest {tostring(row[field])}`)
				end
			end
		end
	end)

	it("every file is a PNG of the size the data says", function()
		for _, key in VfxTextures.ORDER do
			local def = VfxTextures.list[key]
			local path = `art/vfx/{def.file}`
			if not fs.isFile(path) then
				error(`{key}: {path} is missing`)
			end
			local bytes = fs.readFile(path)
			if string.sub(bytes, 1, 8) ~= PNG_SIGNATURE then
				error(`{key}: {path} is not a PNG`)
			end
			local w, h = string.unpack(">I4I4", bytes, 17)
			if w ~= def.w or h ~= def.h then
				error(`{key}: {path} is {w}x{h}, data {def.w}x{def.h}`)
			end
		end
	end)

	it("sizes, flipbooks and wrapping follow the rules", function()
		for key, def in VfxTextures.list do
			if def.w < 64 or def.w > 1024 or def.h < 64 or def.h > 1024 then
				error(`{key}: {def.w}x{def.h} outside 64..1024`)
			end
			if def.grid then
				-- Roblox draws a flipbook only from a 1024 x 1024 texture (FlipbookIncompatible otherwise)
				expect(def.kind).toBe("particle")
				expect(def.w).toBe(def.h)
				expect(def.w).toBe(1024)
				expect(isPowerOfTwo(def.w)).toBe(true)
				expect(def.frames).toBe(FRAMES_OF_GRID[def.grid])
				expect(def.mode ~= nil).toBe(true)
			else
				if def.frames ~= nil or def.mode ~= nil then
					error(`{key}: frames / mode without a grid`)
				end
			end
			if def.wrap and def.kind ~= "beam" and def.kind ~= "trail" then
				error(`{key}: wrap on a {def.kind}`)
			end
		end
	end)

	it("ids are empty or rbxassetid://<digits>, never repeated", function()
		local seen: { [string]: string } = {}
		for key, def in VfxTextures.list do
			if def.id ~= "" then
				if not string.match(def.id, "^rbxassetid://%d+$") then
					error(`{key}: bad id {def.id}`)
				end
				if seen[def.id] then
					error(`{key}: id of {seen[def.id]}`)
				end
				seen[def.id] = key
			end
		end
	end)

	it("emission is within 0..1 and every class has a rune circle of kind beam", function()
		for key, def in VfxTextures.list do
			if def.emission and (def.emission < 0 or def.emission > 1) then
				error(`{key}: emission {def.emission}`)
			end
		end
		for _, classId in Classes.order do
			local rune = VfxTextures.RUNE_OF_CLASS[classId]
			if not rune then
				error(`{classId}: no rune`)
			end
			local def = VfxTextures.get(rune)
			expect(def and def.kind).toBe("beam")
			expect(VfxTextures.runeOf(classId)).toBe(rune)
		end
		expect(VfxTextures.runeOf(nil)).toBe("magicCircle")
		expect(VfxTextures.runeOf("Nobody")).toBe("magicCircle")
	end)

	it("idOf: nil for an empty id and an unknown key, the id once filled in", function()
		local copy: { [string]: VfxTextures.Texture } = {}
		for key, def in VfxTextures.list do
			copy[key] = table.clone(def)
		end
		copy.glow.id = ""
		expect(VfxTextures.idOf("glow", copy)).toBeNil()
		expect(VfxTextures.idOf("nope", copy)).toBeNil()
		copy.glow.id = "rbxassetid://123"
		expect(VfxTextures.idOf("glow", copy)).toBe("rbxassetid://123")
		expect(VfxTextures.idOf("nope")).toBeNil()
	end)

	it("Config.Vfx: the S112 fields are positive, phones get no more than PCs", function()
		local vfx = Config.Vfx
		expect(type(vfx.textures)).toBe("boolean")
		expect(vfx.holdersPerKey >= 1).toBe(true)
		expect(vfx.decalFade).toBeBetween(0.1, 1)
		expect(vfx.spinStep > 0).toBe(true)
		for _, pair in { vfx.maxEmitters, vfx.maxBeams, vfx.maxDecals, vfx.maxLights, vfx.maxBurst } do
			expect(pair.touch > 0).toBe(true)
			expect(pair.desktop > 0).toBe(true)
			expect(pair.touch <= pair.desktop).toBe(true)
		end
		expect(Config.AnimLab.vfxEvery > 0).toBe(true)
	end)

	it("SkillVfx texture keys exist and are of the right kind", function()
		local function check(id: string, key: string?, kind: string)
			if key == nil then
				return
			end
			local def = VfxTextures.get(key)
			if not def or def.kind ~= kind then
				error(`{id}: {key} is not a {kind} texture`)
			end
		end
		for id, entry in SkillVfx do
			check(id, entry.decal, "decal")
			check(id, entry.circle, "beam")
			check(id, entry.sparks, "particle")
		end
	end)
end)

describe("AnimLab vfx (S112)", function()
	it("parses pieces, colours and tools", function()
		local command = AnimLab.parse({ "vfx", "impactFlash", "#ff7a1a" })
		expect(command and command.action).toBe("vfx")
		expect(command and command.id).toBe("impactFlash")
		expect(command and AnimLab.isVfxPiece(command)).toBe(true)
		local tool = AnimLab.parse({ "vfx", "tex", "off" })
		expect(tool and tool.slot).toBe("off")
		expect(tool and AnimLab.isVfxPiece(tool)).toBe(false)
		expect(AnimLab.parse({ "vfx", "all", "stress" })).toBeTruthy()
		expect(AnimLab.parse({ "vfx", "stats" })).toBeTruthy()
		expect(AnimLab.parse({ "vfx", "lingering:frost", "class:Mage" })).toBeTruthy()
		expect(AnimLab.vfxColor("class:Mage")).toBe((Classes.get("Mage") :: any).color)
		expect(AnimLab.vfxColor("#ff7a1a")).toBe("#FF7A1A")
		expect(AnimLab.vfxColor("red")).toBeNil()
		for _, case in
			{
				{ { "vfx" }, "animlab.error.vfx" },
				{ { "vfx", "nope" }, "animlab.error.vfx" },
				{ { "vfx", "tex", "maybe" }, "animlab.error.vfx" },
				{ { "vfx", "all", "x" }, "animlab.error.vfx" },
				{ { "vfx", "stats", "x" }, "animlab.error.args" },
				{ { "vfx", "burst", "#12345" }, "animlab.error.vfxColor" },
				{ { "vfx", "burst", "class:Bard" }, "animlab.error.vfxColor" },
			}
		do
			local parsed, err = AnimLab.parse(case[1])
			expect(parsed).toBeNil()
			expect(err).toBe(case[2])
		end
	end)

	it("lists every new piece once", function()
		local seen: { [string]: boolean } = {}
		for _, name in AnimLab.VFX_PIECES do
			expect(seen[name]).toBeNil()
			seen[name] = true
		end
		for _, name in { "impactFlash", "sparks", "groundDecal", "smokePuff", "magicCircle", "ringWave" } do
			expect(seen[name]).toBe(true)
		end
		-- old pieces with a textured layer (D1) can be compared with `vfx tex on/off`
		for _, name in { "glow", "weaponTrail", "falcon" } do
			expect(seen[name]).toBe(true)
		end
	end)
end)
