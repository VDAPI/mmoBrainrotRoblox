--!strict
-- W31 (owner 2026-10-21: "about 60 NPCs stand as bare default avatars"): every NPC with a figure is dressed by role in
-- its own colours (Data/NpcLooks, Logic/NpcLook), within the piece budget, the same on every server.

local CharacterLook = require("../src/shared/Logic/CharacterLook")
local ClassLooks = require("../src/shared/Data/ClassLooks")
local NpcLook = require("../src/shared/Logic/NpcLook")
local NpcLooks = require("../src/shared/Data/NpcLooks")
local Npcs = require("../src/shared/Data/Npcs")
local T = require("./Test")

local HEX = "^#%x%x%x%x%x%x$"

-- Every NPC that stands as a figure: Data/Npcs without the quest board, and the wandering merchant.
local function figures(): { Npcs.NpcDef }
	local out: { Npcs.NpcDef } = {}
	for _, def in Npcs.list do
		if def.body ~= "board" then
			table.insert(out, def)
		end
	end
	table.insert(out, assert(Npcs.get("wanderer")))
	return out
end

T.describe("NPC looks (W31)", function()
	T.it("dresses every NPC with a figure, and only those", function()
		local ids: { [string]: boolean } = {}
		for _, def in figures() do
			ids[def.id] = true
			T.expect({ def.id, NpcLook.entry(def.id) ~= nil }).toEqual({ def.id, true })
		end
		for id, entry in NpcLooks.npcs do
			T.expect({ id, ids[id] == true, NpcLooks.roles[entry.role] ~= nil }).toEqual({ id, true, true })
		end
		T.expect(NpcLook.resolve({ id = "questboard", colors = { body = "#000000", accent = "#000000" } })).toBe(nil)
	end)

	T.it("uses only garments and look choices the player's look system draws", function()
		for name, role in NpcLooks.roles do
			for _, item in role.garments do
				T.expect({ name, item.g, CharacterLook.GARMENTS[item.g] ~= nil }).toEqual({ name, item.g, true })
			end
		end
		for id, entry in NpcLooks.npcs do
			for _, item in entry.add or {} do
				T.expect({ id, item.g, CharacterLook.GARMENTS[item.g] ~= nil }).toEqual({ id, item.g, true })
			end
		end
		for _, def in figures() do
			local look = assert(NpcLook.look(def))
			-- a valid look: normalize keeps every field as it is
			T.expect({ def.id, CharacterLook.normalize(look) }).toEqual({ def.id, look :: any })
		end
	end)

	T.it("keeps every outfit within the NPC piece budget, in its own colours", function()
		for _, def in figures() do
			local spec = assert(NpcLook.resolve(def))
			T.expect({ def.id, spec.mode, spec.pieces <= NpcLooks.MAX_PIECES }).toEqual({ def.id, "class", true })
			T.expect({ def.id, #spec.garments > 0, #spec.accessories }).toEqual({ def.id, true, 0 })
			for _, item in spec.garments do
				T.expect({ def.id, item.g, string.match(item.color, HEX) ~= nil }).toEqual({ def.id, item.g, true })
			end
			-- the main cloth is the NPC's own colour
			T.expect({ def.id, spec.body.UpperTorso }).toEqual({ def.id, def.colors.body })
		end
	end)

	T.it("gives the women no beard and the old ones grey hair", function()
		for _, def in figures() do
			local entry = assert(NpcLook.entry(def.id))
			local look = assert(NpcLook.look(def))
			if entry.female then
				T.expect({ def.id, look.beard }).toEqual({ def.id, "beard_none" })
				T.expect({ def.id, table.find(NpcLooks.HAIRS_FEMALE, look.hair) ~= nil or entry.look ~= nil }).toEqual({
					def.id,
					true,
				})
			end
			if entry.old then
				T.expect({ def.id, table.find(NpcLooks.HAIR_COLORS_OLD, look.hairColor :: string) ~= nil }).toEqual({
					def.id,
					true,
				})
			end
		end
	end)

	T.it("picks the same look for an id every time, and different looks for the guards", function()
		local a = assert(NpcLook.look(assert(Npcs.get("fishwife"))))
		local b = assert(NpcLook.look(assert(Npcs.get("fishwife"))))
		T.expect(a).toEqual(b)
		local g1 = assert(NpcLook.look(assert(Npcs.get("guard1"))))
		local g2 = assert(NpcLook.look(assert(Npcs.get("guard2"))))
		T.expect(g1.face ~= g2.face or g1.skin ~= g2.skin or g1.hairColor ~= g2.hairColor).toBe(true)
	end)

	T.it("varies faces, skins and hair across the NPCs", function()
		local faces, skins, hairs = {}, {}, {}
		local function count(set: { [string]: boolean }): number
			local n = 0
			for _ in set do
				n += 1
			end
			return n
		end
		for _, def in figures() do
			local look = assert(NpcLook.look(def))
			faces[look.face] = true
			skins[look.skin] = true
			hairs[look.hair] = true
		end
		T.expect(count(faces) >= 6).toBe(true)
		T.expect(count(skins) >= 7).toBe(true)
		T.expect(count(hairs) >= 9).toBe(true)
	end)

	T.it("darkens the second colour and keeps the hex form", function()
		T.expect(NpcLook.shade("#808080", 0.5)).toBe("#404040")
		T.expect(NpcLook.shade("#FFFFFF", 2)).toBe("#FFFFFF")
		T.expect(NpcLook.shade("#0A1B2C", 1)).toBe("#0A1B2C")
		local roll = NpcLook.roll("guard1", "face")
		T.expect(roll >= 0 and roll < 1).toBe(true)
		T.expect(NpcLook.roll("guard1", "face")).toBe(roll)
	end)

	T.it("puts a robe's legs in the robe colour", function()
		local spec = assert(NpcLook.resolve(assert(Npcs.get("vendor_cleric"))))
		T.expect(spec.body.LeftLowerLeg).toBe(spec.body.UpperTorso)
		local guard = assert(NpcLook.resolve(assert(Npcs.get("guard1"))))
		-- the helmet hides the hair
		T.expect(guard.hair).toBe(nil)
		T.expect(ClassLooks.BODY_ROLES.LeftLowerLeg).toBe("leather")
	end)
end)

return nil
