--!strict
local Bases = require("../src/shared/Data/Items/Bases")
local Gait = require("../src/shared/Logic/Gait")
local Items = require("../src/shared/Data/Items")
local T = require("./Test")
local WeaponLooks = require("../src/shared/Data/WeaponLooks")

local ROLES = { "body", "leg", "spiderLeg", "arm", "head", "tail", "wing" }

local function motion(over: { [string]: number }?): Gait.Motion
	local m: Gait.Motion = { cycle = 0, move = 0, time = 0, raise = 0, strike = 0, hit = 0, dead = 0 }
	for k, v in over or {} do
		(m :: any)[k] = v
	end
	return m
end

local function joint(role: string, side: number?, phase: number?): Gait.Joint
	return { role = role :: any, side = side or 1, phase = phase or 0, amp = 1 }
end

T.describe("Gait", function()
	T.it("limbs rest when standing still at time zero", function()
		for _, role in { "leg", "spiderLeg" } do
			T.expect(Gait.isRest(Gait.pose(joint(role), motion()))).toBe(true)
		end
	end)

	T.it("legs on opposite phases swing opposite ways", function()
		local m = motion({ cycle = math.pi / 2, move = 1 })
		local a = Gait.pose(joint("leg", -1, 0), m)
		local b = Gait.pose(joint("leg", 1, 0.5), m)
		T.expect(a.rx).toBeNear(-b.rx, 1e-9)
		T.expect(math.abs(a.rx) > 0.3).toBe(true)
	end)

	T.it("walking advances the cycle with distance, slower for big monsters", function()
		local small = Gait.advance(0, 0.1, 10, 1)
		local big = Gait.advance(0, 0.1, 10, 3)
		T.expect(small > big).toBe(true)
		T.expect(Gait.advance(1, 0.5, 0, 1)).toBe(1)
		T.expect(Gait.advance(6, 10, 20, 1)).toBeBetween(0, 2 * math.pi)
	end)

	T.it("attack rises during the windup, strikes, then returns to rest", function()
		local windup = 0.4
		local r0, s0 = Gait.attack(0, windup)
		T.expect(r0).toBe(0)
		T.expect(s0).toBe(0)
		local rUp = Gait.attack(windup - 1e-3, windup)
		T.expect(rUp).toBeNear(1, 1e-3)
		local _, sHit = Gait.attack(windup + Gait.STRIKE_SECONDS - 1e-3, windup)
		T.expect(sHit).toBeNear(1, 0.02)
		local rEnd, sEnd = Gait.attack(Gait.attackLength(windup) + 0.01, windup)
		T.expect(rEnd).toBe(0)
		T.expect(sEnd).toBe(0)
		local rNeg = Gait.attack(-1, windup)
		T.expect(rNeg).toBe(0)
	end)

	T.it("the attacking arm rises, the other follows only a little", function()
		local m = motion({ raise = 1 })
		local right = Gait.pose(joint("arm", 1), m)
		local left = Gait.pose(joint("arm", -1), m)
		T.expect(right.rx > 2).toBe(true)
		T.expect(math.abs(left.rx) < right.rx / 2).toBe(true)
	end)

	T.it("dead bodies collapse and wings fold", function()
		local body = Gait.pose(joint("body", 0), motion({ dead = 1, time = 3 }))
		T.expect(body.rz > 1).toBe(true)
		T.expect(body.y < 0).toBe(true)
		local wing = Gait.pose(joint("wing", -1), motion({ dead = 1, time = 3 }))
		T.expect(wing.rz).toBeNear(0.6, 1e-9)
	end)

	T.it("every role stays within sane angles", function()
		for _, role in ROLES do
			for i = 0, 40 do
				local m = motion({
					cycle = i * 0.37,
					move = (i % 5) / 4,
					time = i * 0.53,
					raise = (i % 3) / 2,
					strike = (i % 4) / 3,
					hit = (i % 2),
					dead = (i % 7) / 6,
				})
				for _, side in { -1, 1 } do
					local p = Gait.pose(joint(role, side, (i % 2) * 0.5), m)
					for _, v in { p.rx, p.ry, p.rz } do
						T.expect(math.abs(v) <= math.pi).toBe(true)
					end
					for _, v in { p.x, p.y, p.z } do
						T.expect(math.abs(v) <= 1).toBe(true)
					end
				end
			end
		end
	end)
end)

T.describe("WeaponLooks", function()
	T.it("every weapon and off-hand base has a look", function()
		for _, base in Bases.list do
			if base.slot == "weapon" or base.slot == "offhand" then
				T.expect(WeaponLooks.get(base.type) ~= nil).toBe(true)
			end
		end
	end)

	T.it("unique weapons use a base type with a look", function()
		for _, def in Items.uniques do
			if def.slot == "weapon" or def.slot == "offhand" then
				T.expect(WeaponLooks.get(def.type) ~= nil).toBe(true)
			end
		end
	end)

	T.it("pieces are well formed", function()
		for _, look in WeaponLooks.list do
			T.expect(#look.pieces > 0).toBe(true)
			local names = {}
			for _, piece in look.pieces do
				T.expect(names[piece.name]).toBeNil()
				names[piece.name] = true
				T.expect(#piece.size).toBe(3)
				T.expect(#piece.pos).toBe(3)
				for _, v in piece.size do
					T.expect(v > 0).toBe(true)
				end
				if piece.rot then
					T.expect(#piece.rot).toBe(3)
				end
				T.expect(piece.color == "rarity" or string.match(piece.color, "^#%x%x%x%x%x%x$") ~= nil).toBe(true)
				T.expect(table.find(WeaponLooks.MATERIALS, piece.material) ~= nil).toBe(true)
			end
		end
	end)
end)
