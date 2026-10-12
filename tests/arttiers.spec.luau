--!strict
-- S52: real art per item tier (Logic/ArtTiers), real weapon models in the hand (WeaponLooks.assets / MOUNTS,
-- Logic/WeaponMount) and the Grip convention checked against today's Part looks.
local ArtTiers = require("../src/shared/Logic/ArtTiers")
local Items = require("../src/shared/Data/Items")
local T = require("./Test")
local WeaponLooks = require("../src/shared/Data/WeaponLooks")
local WeaponMount = require("../src/shared/Logic/WeaponMount")

local function set(list: { string }): (id: string) -> boolean
	local s = {}
	for _, v in list do
		s[v] = true
	end
	return function(id: string): boolean
		return s[id] == true
	end
end

T.describe("ArtTiers", function()
	T.it("takes the nearest lower tier with art, never a higher one", function()
		local has = function(t: number): boolean
			return t == 1 or t == 20
		end
		T.expect(ArtTiers.pick(1, has)).toBe(1)
		T.expect(ArtTiers.pick(15, has)).toBe(1)
		T.expect(ArtTiers.pick(20, has)).toBe(20)
		T.expect(ArtTiers.pick(100, has)).toBe(20)
		T.expect(ArtTiers.pick(37, has)).toBe(20)
		T.expect(ArtTiers.pick(10, function(t: number): boolean
			return t == 20
		end)).toBeNil()
	end)

	T.it("model: boss item first, then its tier, then lower tiers, else the Part look", function()
		local sword25 = Items.get("sword1h_25") :: any
		T.expect(ArtTiers.modelId(sword25, set({ "sword1h_1", "sword1h_20" }))).toBe("sword1h_20")
		T.expect(ArtTiers.modelId(sword25, set({ "sword1h_25", "sword1h_20" }))).toBe("sword1h_25")
		T.expect(ArtTiers.modelId(sword25, set({ "sword1h_30" }))).toBeNil()
		T.expect(ArtTiers.modelId(sword25, set({ "axe1h_1" }))).toBeNil()
		local cleaver = Items.get("unique_grimrok_cleaver") :: any
		T.expect(ArtTiers.modelId(cleaver, set({ "unique_grimrok_cleaver", "axe1h_20" })))
			.toBe("unique_grimrok_cleaver")
		T.expect(ArtTiers.modelId(cleaver, set({ "axe1h_15", "axe1h_25" }))).toBe("axe1h_15")
	end)

	T.it("icon keys of tiers, best first", function()
		T.expect(table.concat(ArtTiers.iconKeys("eq/sword1h", 12), ",")).toBe("eq/sword1h@10,eq/sword1h@5,eq/sword1h@1")
		T.expect(#ArtTiers.iconKeys("eq/ring", 100)).toBe(#Items.bases.tiers)
		T.expect(#ArtTiers.iconKeys("eq/ring", nil)).toBe(1)
	end)
end)

T.describe("Weapon models (S52)", function()
	T.it("every entry is a held item with a sensible length and grip, one model per entry", function()
		local models = {}
		for id, asset in WeaponLooks.assets do
			local def = Items.get(id) :: any
			T.expect(def ~= nil and WeaponLooks.get(def.type) ~= nil).toBe(true)
			T.expect(models[asset.model]).toBeNil()
			models[asset.model] = true
			T.expect(asset.grip > 0 and asset.grip < 1).toBe(true)
			local span = WeaponMount.lookSpan(WeaponLooks.get(def.type) :: any, WeaponLooks.MOUNTS[def.type])
			-- About as long as today's Part look, held at about the same place (docs/GRAFIKA.md 3.4).
			local ratio = asset.length / span.length
			if ratio < 0.75 or ratio > 1.35 or math.abs(asset.grip - span.grip) > 0.2 then
				error(`{id}: length {asset.length} / grip {asset.grip} vs Part look {span.length} / {span.grip}`)
			end
		end
	end)

	T.it("every held type has a mount with valid axes", function()
		for itemType in WeaponLooks.list do
			local mount = WeaponLooks.MOUNTS[itemType]
			T.expect(mount ~= nil).toBe(true)
			local x, y = WeaponMount.axis(mount.x), WeaponMount.axis(mount.y)
			T.expect(x ~= nil and y ~= nil).toBe(true)
			local d = (x :: any)[1] * (y :: any)[1] + (x :: any)[2] * (y :: any)[2] + (x :: any)[3] * (y :: any)[3]
			T.expect(d).toBe(0)
		end
		T.expect(WeaponLooks.IMPORT_YAW == 0 or WeaponLooks.IMPORT_YAW == 180).toBe(true)
	end)

	T.it("Grip convention: a model laid out by the rule stands where today's Part look stands", function()
		-- +Y of the Grip frame runs along the look's long axis from the hand to the tip; +X points to the head /
		-- face / top (bows: the string is on -X).
		local SIDE: { [string]: number } = {
			axe1h = 1,
			shield = 1,
			crossbow = 1,
			heavycrossbow = 1,
			tome = 1,
			relic = 1,
			bow = -1,
			shortbow = -1,
			longbow = -1,
		}
		for itemType, look in WeaponLooks.list do
			local span = WeaponMount.lookSpan(look, WeaponLooks.MOUNTS[itemType])
			local ext = { span.max[1] - span.min[1], span.length, span.max[3] - span.min[3] }
			if span.length < math.max(ext[1], ext[3]) - 0.05 or span.grip > 0.55 then
				error(`{itemType}: Grip +Y is not the length axis from the hand ({span.length}, grip {span.grip})`)
			end
			local side = SIDE[itemType]
			if side and (span.max[1] + span.min[1]) * side <= 0 then
				error(`{itemType}: Grip +X points the wrong way ({span.min[1]}..{span.max[1]})`)
			end
		end
		-- The far end of a model is ahead of the hand like the look's tip (sword: forward, staff: up).
		local tip = WeaponMount.assetTip(WeaponLooks.assets.sword1h_1, WeaponLooks.MOUNTS.sword1h)
		T.expect(tip[3] < -2.5 and math.abs(tip[1]) < 0.1 and math.abs(tip[2]) < 0.1).toBe(true)
		local staff = WeaponMount.assetTip(WeaponLooks.assets.staff_1, WeaponLooks.MOUNTS.staff)
		T.expect(staff[2] > 3).toBe(true)
	end)

	T.it("handle offsets (hold): the palm on the haft, riser or stock, not on the box centre line", function()
		-- An axe whose head sticks out to one side: the box centre line is beside the haft, so the centre moves away.
		local axe = { model = "x", length = 4, grip = 0.25, hold = { -0.1, 0.05 } }
		local p = WeaponMount.assetPoint(axe, 0.25)
		T.expect(p[1]).toBeNear(0.4)
		T.expect(p[2]).toBeNear(0)
		T.expect(p[3]).toBeNear(-0.2)
		local tip = WeaponMount.assetPoint(axe, 1)
		T.expect(tip[2]).toBeNear(3)
		T.expect(tip[1]).toBeNear(0.4)
		-- Measured offsets are small and only for weapons held by a handle (off-hands sit on their mount centre).
		local offhand = { shield = true, tome = true, orb = true, relic = true, quiver = true }
		local any = false
		for id, asset in WeaponLooks.assets do
			if asset.hold then
				any = true
				local itemType = string.match(id, "^(.-)_%d+$") or "axe1h"
				if offhand[itemType] then
					error(`{id}: off-hands have no hold`)
				end
				if #asset.hold ~= 2 or math.abs(asset.hold[1]) > 0.2 or math.abs(asset.hold[2]) > 0.2 then
					error(`{id}: hold must be two numbers (x, z) within 0.2 of the length`)
				end
			end
		end
		T.expect(any).toBe(true)
	end)

	T.it("mount maths: toGrip undoes toHand (with tilt and offset)", function()
		local quiver = WeaponLooks.MOUNTS.quiver
		local p = WeaponMount.toGrip(quiver, WeaponMount.toHand(quiver, { 0.3, -0.7, 0.2 }))
		T.expect(p[1]).toBeNear(0.3)
		T.expect(p[2]).toBeNear(-0.7)
		T.expect(p[3]).toBeNear(0.2)
		-- The Part look sizes of docs/GRAFIKA.md 3.4 (sword: about 3.6 studs, hand 0.55 from the pommel end).
		local sword = WeaponMount.lookSpan(WeaponLooks.list.sword1h, WeaponLooks.MOUNTS.sword1h)
		T.expect(math.abs(sword.length - 3.6) < 0.05).toBe(true)
		T.expect(math.abs(sword.grip * sword.length - 0.56) < 0.05).toBe(true)
	end)
end)
