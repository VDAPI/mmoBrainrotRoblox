--!strict
-- Look dump for the wiki renders (S38, tools/WikiLooks.luau): one entry per monster variant, boss and pet, unique
-- files, valid pieces, game scales, JSON-safe phases, no price, determinism; the S24 preview row is unchanged.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Anatomy = require("../src/shared/Logic/Anatomy")
local Bosses = require("../src/shared/Data/Bosses")
local Combat = require("../src/shared/Data/Combat")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Json = require("../tools/WikiData/Json")
local Monsters = require("../src/shared/Data/Monsters")
local T = require("./Test")
local WikiLooks = require("../tools/WikiLooks")

local entries = WikiLooks.entries()

local MATERIALS: { [string]: boolean } = {}
for _, m in Anatomy.MATERIALS do
	MATERIALS[m] = true
end
local SHAPES = { box = true, ball = true, cyl = true, wedge = true, corner = true }

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function hasKey(v: any, key: string): boolean
	if type(v) ~= "table" then
		return false
	end
	for k, child in v do
		if k == key or hasKey(child, key) then
			return true
		end
	end
	return false
end

T.describe("Look dump: wiki entries", function()
	T.it("has one entry per monster variant, boss and pet", function()
		local expected = 0
		for _, def in Monsters.list do
			expected += if def.elites then 3 else 1
		end
		expected += #Bosses.list
		for _, def in Cosmetics.list do
			if def.kind == "pet" then
				expected += 1
			end
		end
		T.expect(#entries).toBe(expected)
	end)

	T.it("uses unique, sorted file names", function()
		local seen: { [string]: boolean } = {}
		for i, e in entries do
			T.expect(seen[e.file]).toBeNil()
			seen[e.file] = true
			if i > 1 then
				T.expect(entries[i - 1].file < e.file).toBeTruthy()
			end
			local expectedFile = if e.variant == "elite" or e.variant == "elite2" then `{e.id}-{e.variant}` else e.id
			T.expect(e.file).toBe(expectedFile)
		end
	end)

	T.it("has valid pieces", function()
		for _, e in entries do
			T.expect(#e.pieces > 0).toBeTruthy()
			for _, p in e.pieces do
				if not SHAPES[p.s] or not MATERIALS[p.m] or not string.match(p.c, "^#%x%x%x%x%x%x$") then
					error(`{e.file}: bad piece {p.s} {p.m} {p.c}`)
				end
				for _, list in { p.size, p.p, p.r } do
					for _, n in list do
						if not finite(n) then
							error(`{e.file}: non-finite number`)
						end
					end
				end
				T.expect(#p.r).toBe(9)
			end
			T.expect(finite(e.height) and finite(e.hipHeight)).toBeTruthy()
		end
	end)

	T.it("scales like the game", function()
		local byFile: { [string]: WikiLooks.Entry } = {}
		for _, e in entries do
			byFile[e.file] = e
		end
		for _, def in Monsters.list do
			for _, v in (if def.elites then { "normal", "elite", "elite2" } else { "normal" }) do
				local e = byFile[if v == "normal" then def.id else `{def.id}-{v}`]
				T.expect(e.kind).toBe("monster")
				T.expect(e.region).toBe(def.region)
				T.expect(e.scale).toBeNear(def.size * Combat.variants[v].scale, 1e-4)
			end
		end
		for _, boss in Bosses.list do
			local e = byFile[boss.id]
			T.expect(e.kind).toBe("boss")
			T.expect(e.scale).toBeNear(boss.look.size, 1e-4)
			T.expect(e.aura).toBe(boss.look.aura)
		end
		for _, def in Cosmetics.list do
			if def.kind == "pet" then
				T.expect(byFile[def.id].scale).toBeNear(Cosmetics.PET_SCALE, 1e-4)
			end
		end
	end)

	T.it("encodes as JSON with phases as a list and no price", function()
		local text = serde.encode("json", { looks = entries })
		T.expect(#text > 0).toBeTruthy()
		T.expect(hasKey(entries, "price")).toBeFalsy()
		local any = false
		for _, e in entries do
			if e.phases then
				any = true
				for i, ph in e.phases do
					T.expect(type(ph.phase)).toBe("number")
					if i > 1 then
						T.expect(e.phases[i - 1].phase < ph.phase).toBeTruthy()
					end
				end
			end
		end
		T.expect(any).toBeTruthy()
	end)

	T.it("is deterministic", function()
		local a = Json.file({ version = WikiLooks.VERSION, looks = entries })
		local b = Json.file({ version = WikiLooks.VERSION, looks = WikiLooks.entries() })
		T.expect(a == b).toBeTruthy()
	end)

	T.it("keeps the S24 preview row unchanged", function()
		local pieces = WikiLooks.legacy({ "wolf" })
		local text = `\{"pieces": {serde.encode("json", pieces)}\}`
		T.expect(text == fs.readFile("tests/fixtures/lookdump_wolf.json")).toBeTruthy()
	end)
end)
