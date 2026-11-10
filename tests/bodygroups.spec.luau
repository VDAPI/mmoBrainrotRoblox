--!strict
-- Data/BodyGroups (owner 2026-11-10: "monsters run into me and I climb on them", then "they may block, but no
-- climbing"): a player never touches a monster's root, only its blocker, a column that touches nothing but player
-- characters and stands over the highest a player's body gets beside a monster (any mount's seat, a jump and a slope);
-- monsters still bump into monsters and players into players, and a quest companion touches no body at all.

local Anatomy = require("../src/shared/Logic/Anatomy")
local BodyGroups = require("../src/shared/Data/BodyGroups")
local BodyLooks = require("../src/shared/Data/BodyLooks")
local Config = require("../src/shared/Config")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local MountData = require("../src/shared/Data/Mounts")
local Mounts = require("../src/shared/Logic/Mounts")
local T = require("./Test")

local describe, it, expect = T.describe, T.it, T.expect

local P, M, B, C = BodyGroups.PLAYERS, BodyGroups.MONSTERS, BodyGroups.BLOCKERS, BodyGroups.COMPANIONS

describe("BodyGroups", function()
	it("puts a player against a monster's blocker, never against its root", function()
		expect(BodyGroups.collide(P, M)).toBe(false)
		expect(BodyGroups.collide(M, P)).toBe(false)
		expect(BodyGroups.collide(P, B)).toBe(true)
	end)

	it("keeps the blocker off the world, the monsters and itself", function()
		expect(BodyGroups.collide(B, "Default")).toBe(false)
		expect(BodyGroups.collide(B, M)).toBe(false)
		expect(BodyGroups.collide(B, B)).toBe(false)
		expect(BodyGroups.collide(B, C)).toBe(false)
	end)

	it("keeps monsters bumping into monsters and players into players, both on the world", function()
		expect(BodyGroups.collide(M, M)).toBe(true)
		expect(BodyGroups.collide(P, P)).toBe(true)
		expect(BodyGroups.collide(M, "Default")).toBe(true)
		expect(BodyGroups.collide(P, "Default")).toBe(true)
	end)

	it("lets a companion touch no body", function()
		for _, group in { P, M, B, C } do
			expect(BodyGroups.collide(C, group)).toBe(false)
		end
	end)

	it("gives a blocker its own group under the monsters' folder", function()
		expect(BodyGroups.monsterPart(BodyGroups.BLOCKER)).toBe(B)
		expect(BodyGroups.monsterPart("HumanoidRootPart")).toBe(M)
		expect(BodyGroups.monsterPart("Aura")).toBe(M)
	end)

	it("names only registered groups in its pairs, within Roblox's limit", function()
		local known: { [string]: boolean } = { Default = true }
		for _, group in BodyGroups.ALL do
			expect(known[group]).toBe(nil)
			known[group] = true
		end
		for _, pair in BodyGroups.APART do
			expect(known[pair[1]]).toBe(true)
			expect(known[pair[2]]).toBe(true)
		end
		expect(#BodyGroups.ALL + 1 <= 32).toBe(true)
	end)
end)

describe("BodyGroups.blocker", function()
	-- the column's bottom and top over the feet (the root's centre stands hip + half its height over them)
	local function span(root: { number }, hip: number, drawn: number): (number, number, { number })
		local size, y = BodyGroups.blocker(root, hip, drawn)
		local centre = hip + root[2] / 2 + y
		return centre - size[2] / 2, centre + size[2] / 2, size
	end

	it("stands from the root's bottom to over a jump for a wolf-sized monster", function()
		local bottom, top, size = span({ 1.6, 1.9, 3.2 }, 1.94, 3.5)
		expect(math.abs(bottom - 1.94) < 1e-9).toBe(true)
		expect(math.abs(top - BodyGroups.BLOCK_TOP) < 1e-9).toBe(true)
		expect(size[1]).toBe(1.6)
		expect(size[3]).toBe(3.2)
	end)

	it("reaches a jump's height for any monster", function()
		for _, case in { { { 1, 1, 1 }, 0.5, 1 }, { { 1.23, 1.18, 1.83 }, 2.88, 4.33 }, { { 4, 6, 4 }, 3, 9 } } do
			local _, top = span(case[1], case[2], case[3])
			expect(top >= BodyGroups.BLOCK_TOP - 1e-9).toBe(true)
			expect(top > BodyGroups.JUMP_RISE).toBe(true)
		end
	end)

	it("covers a tall monster up to its drawn top and its root", function()
		local _, top = span({ 6, 10, 8 }, 4, 20)
		expect(math.abs(top - 20) < 1e-9).toBe(true)
		local _, rootTop = span({ 6, 14, 8 }, 4, 12)
		expect(math.abs(rootTop - 18) < 1e-9).toBe(true)
	end)

	-- review 2026-11-10: at 9.5 a rider hopped onto a wolf's column and rode it. A rider stands on his root's bottom at
	-- the seat's HipHeight, highest with the smallest root a player wears (the block R15's 2-stud root at the lowest
	-- height scale of either mode); every mount counts with its real model's saddle and with its procedural look (the
	-- fallback without a model) under every mount skin.
	it("tops out over any mount's seat, a jump and a slope", function()
		local scale = BodyLooks.current().scales.height
		local rootHalf = math.min(1, Config.CharacterLook.avatarScale.height[1]) * scale
		local skins: { any } = { false }
		for _, def in Cosmetics.list do
			if def.kind == "mountskin" then
				table.insert(skins, def)
			end
		end
		expect(#skins > 1).toBe(true)
		local seat = 0
		for _, def in MountData.list do
			for _, skin in skins do
				local look = Mounts.lookWith(def.look, if skin then skin else nil)
				local rig = Anatomy.build(look, { id = def.id, variant = "mount", scale = def.scale or 1 })
				seat = math.max(seat, Mounts.seat(rig :: any, rootHalf).hipHeight)
			end
			local asset = MountData.assets[def.id]
			if asset then
				local lift = if asset.rider then asset.rider.seatLift else nil
				seat = math.max(seat, Mounts.seatAt(0, asset.saddle, rootHalf, lift).hipHeight)
			end
		end
		expect(seat > 2).toBe(true) -- a rider sits over a walker (HipHeight 2)
		expect(BodyGroups.BLOCK_TOP > seat + BodyGroups.JUMP_RISE + BodyGroups.SLOPE).toBe(true)
		local _, top = span({ 1.6, 1.9, 3.2 }, 1.94, 3.5)
		expect(top > seat + BodyGroups.JUMP_RISE + BodyGroups.SLOPE).toBe(true)
	end)
end)

describe("BodyGroups.bodyBox", function()
	it("runs from a monster's feet to its root's top, as wide and deep as the root", function()
		local root, hip = { 1.6, 1.9, 3.2 }, 1.94
		local size, y = BodyGroups.bodyBox(root, hip)
		local centre = hip + root[2] / 2 + y -- over the feet
		expect(math.abs(centre - size[2] / 2) < 1e-9).toBe(true)
		expect(math.abs(centre + size[2] / 2 - (hip + root[2])) < 1e-9).toBe(true)
		expect(size[1]).toBe(1.6)
		expect(size[3]).toBe(3.2)
		local blocker = BodyGroups.blocker(root, hip, 3.5)
		expect(size[2] < blocker[2]).toBe(true)
	end)
end)
