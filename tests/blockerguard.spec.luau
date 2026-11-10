--!strict
-- Logic/BlockerGuard (owner 2026-11-10: "they may block, but no climbing"): a character that stands on a monster's
-- blocker or comes down onto it from not far above slides off it, away from the column's centre, past its edge; a
-- character on the ground beside a monster (on foot, jumping or riding), on a ledge over a column, off its footprint or
-- on a dead monster's column is never pushed.

local BlockerGuard = require("../src/shared/Logic/BlockerGuard")
local BodyGroups = require("../src/shared/Data/BodyGroups")
local T = require("./Test")

local describe, it, expect = T.describe, T.it, T.expect

local WOLF_ROOT, WOLF_HIP, WOLF_DRAWN = { 1.6, 1.9, 3.2 }, 1.94, 3.5
local HALF = 1 -- the block R15's root: 2 wide

-- A wolf's column (Data/BodyGroups.blocker) with its feet on y = 0 at (x, z), its right vector (rx, rz).
local function wolf(x: number, z: number, rx: number?, rz: number?): BlockerGuard.Column
	local size, y = BodyGroups.blocker(WOLF_ROOT, WOLF_HIP, WOLF_DRAWN)
	return {
		x = x,
		y = WOLF_HIP + WOLF_ROOT[2] / 2 + y,
		z = z,
		rightX = rx or 1,
		rightZ = rz or 0,
		width = size[1],
		height = size[2],
		depth = size[3],
		vx = 0,
		vz = 0,
		collides = true,
	}
end

local function topOf(column: BlockerGuard.Column): number
	return column.y + column.height / 2
end

local function body(x: number, z: number, feet: number, vy: number?): BlockerGuard.Body
	return { x = x, z = z, feet = feet, half = HALF, vy = vy or 0, lookX = 0, lookZ = -1 }
end

-- Where the push leaves the body relative to the column after its time (the column moves at its own velocity).
local function after(b: BlockerGuard.Body, column: BlockerGuard.Column, push: BlockerGuard.Push): BlockerGuard.Body
	local rx, rz = (push.vx - column.vx) * push.time, (push.vz - column.vz) * push.time
	return { x = b.x + rx, z = b.z + rz, feet = b.feet, half = b.half, vy = b.vy, lookX = b.lookX, lookZ = b.lookZ }
end

describe("BlockerGuard: who is pushed", function()
	it("pushes a body standing on a wolf's column off past its edge, away from its centre", function()
		local column = wolf(0, 0)
		expect(topOf(column)).toBeNear(BodyGroups.BLOCK_TOP, 1e-9)
		local b = body(0.4, 0.3, topOf(column))
		local push = BlockerGuard.push(b, column)
		expect(push ~= nil).toBe(true)
		local p = push :: BlockerGuard.Push
		local length = math.sqrt(0.4 * 0.4 + 0.3 * 0.3)
		expect(p.dirX).toBeNear(0.4 / length, 1e-9)
		expect(p.dirZ).toBeNear(0.3 / length, 1e-9)
		expect(BlockerGuard.over(after(b, column, p), column)).toBe(false)
		-- a little sunk into the top or over it still stands on it
		expect(BlockerGuard.push(body(0.4, 0.3, topOf(column) - 0.5), column) ~= nil).toBe(true)
		expect(BlockerGuard.push(body(0.4, 0.3, topOf(column) + 0.5), column) ~= nil).toBe(true)
	end)

	it("pushes a body coming down onto the column, but not one falling from far above", function()
		local column = wolf(0, 0)
		expect(BlockerGuard.push(body(0.5, 0, topOf(column) + 3, -20), column) ~= nil).toBe(true)
		expect(BlockerGuard.push(body(0.5, 0, topOf(column) + BlockerGuard.ABOVE + 1, -20), column)).toBeNil()
	end)

	it("leaves a body standing on a ledge or a bridge over the column", function()
		local column = wolf(0, 0)
		expect(BlockerGuard.push(body(0.5, 0, topOf(column) + 2, 0), column)).toBeNil()
		expect(BlockerGuard.push(body(0.5, 0, topOf(column) + 2, 3), column)).toBeNil()
	end)

	it("never pushes a body on the ground beside a monster: walking, jumping or riding up a slope", function()
		local column = wolf(0, 0)
		-- pressed against the column's side and its front (the grown footprint's edge)
		for _, at in { { column.width / 2 + HALF, 0 }, { 0, column.depth / 2 + HALF } } do
			-- the feet on the monster's ground, up a slope, and at the top of a jump from there (a walker's or a
			-- rider's: the feet are the root's bottom less HipHeight either way)
			for _, feet in { 0, BodyGroups.SLOPE, BodyGroups.SLOPE + BodyGroups.JUMP_RISE } do
				for _, vy in { 0, -30, 30 } do
					expect(BlockerGuard.push(body(at[1], at[2], feet, vy), column)).toBeNil()
				end
			end
		end
	end)

	it("never pushes from a dead monster's column", function()
		local column = wolf(0, 0)
		column.collides = false
		expect(BlockerGuard.push(body(0.4, 0, topOf(column)), column)).toBeNil()
		expect(BlockerGuard.push(body(0.4, 0, topOf(column) + 2, -20), column)).toBeNil()
	end)

	it("needs the body over the footprint grown by its half width, turned with the column", function()
		local column = wolf(0, 0)
		local top = topOf(column)
		expect(BlockerGuard.push(body(column.width / 2 + HALF + 0.05, 0, top), column)).toBeNil()
		expect(BlockerGuard.push(body(column.width / 2 + HALF - 0.05, 0, top), column) ~= nil).toBe(true)
		-- turned a quarter: the long side runs along x
		local turned = wolf(0, 0, 0, 1)
		expect(BlockerGuard.over(body(2.2, 0, top), turned)).toBe(true)
		expect(BlockerGuard.over(body(0, 2.2, top), turned)).toBe(false)
		expect(BlockerGuard.over(body(2.2, 0, top), column)).toBe(false)
		expect(BlockerGuard.over(body(0, 2.2, top), column)).toBe(true)
	end)
end)

describe("BlockerGuard: the push", function()
	it("goes along the facing from dead centre", function()
		local column = wolf(5, -3)
		local b = body(5, -3, topOf(column))
		b.lookX, b.lookZ = 0.6, -0.8
		local push = BlockerGuard.push(b, column) :: BlockerGuard.Push
		expect(push.dirX).toBeNear(0.6, 1e-9)
		expect(push.dirZ).toBeNear(-0.8, 1e-9)
		expect(BlockerGuard.over(after(b, column, push), column)).toBe(false)
	end)

	it("carries the column's own velocity, so a walking monster does not keep the body on it", function()
		local column = wolf(0, 0)
		column.vx, column.vz = 14, -6
		local b = body(0, 1, topOf(column))
		local push = BlockerGuard.push(b, column) :: BlockerGuard.Push
		expect(push.dirX).toBeNear(0, 1e-9)
		expect(push.dirZ).toBeNear(1, 1e-9)
		-- across the monster's walk it keeps the monster's pace, and slides off on top of it
		expect(push.vx).toBeNear(14, 1e-9)
		expect(push.vz > -6 + BlockerGuard.MIN_SPEED - 1e-9).toBe(true)
		expect(BlockerGuard.over(after(b, column, push), column)).toBe(false)
	end)

	it("turns after pushes in a row: a quarter each way, then back", function()
		local column = wolf(0, 0)
		local b = body(0, 1, topOf(column))
		local first = BlockerGuard.push(b, column, 0) :: BlockerGuard.Push
		local second = BlockerGuard.push(b, column, 1) :: BlockerGuard.Push
		local third = BlockerGuard.push(b, column, 2) :: BlockerGuard.Push
		local fourth = BlockerGuard.push(b, column, 3) :: BlockerGuard.Push
		expect(first.dirX * second.dirX + first.dirZ * second.dirZ).toBeNear(0, 1e-9)
		expect(first.dirX * third.dirX + first.dirZ * third.dirZ).toBeNear(0, 1e-9)
		expect(second.dirX * third.dirX + second.dirZ * third.dirZ).toBeNear(-1, 1e-9)
		expect(first.dirX * fourth.dirX + first.dirZ * fourth.dirZ).toBeNear(-1, 1e-9)
		local fifth = BlockerGuard.push(b, column, 4) :: BlockerGuard.Push
		expect(fifth.dirX).toBeNear(first.dirX, 1e-9)
		expect(fifth.dirZ).toBeNear(first.dirZ, 1e-9)
		for _, push in { first, second, third, fourth } do
			expect(BlockerGuard.over(after(b, column, push), column)).toBe(false)
		end
	end)

	it("slides between MIN_SPEED and MAX_SPEED, longer on a wide boss's column", function()
		local edge = wolf(0, 0)
		local near = BlockerGuard.push(body(edge.width / 2 + HALF - 0.1, 0, topOf(edge)), edge) :: BlockerGuard.Push
		expect(math.sqrt(near.vx * near.vx + near.vz * near.vz)).toBeNear(BlockerGuard.MIN_SPEED, 1e-9)
		expect(near.time < BlockerGuard.PUSH_TIME).toBe(true)
		local boss: BlockerGuard.Column = {
			x = 0,
			y = 10,
			z = 0,
			rightX = 1,
			rightZ = 0,
			width = 24,
			height = 20,
			depth = 24,
			vx = 0,
			vz = 0,
			collides = true,
		}
		local b = body(0.5, 0, 20)
		local far = BlockerGuard.push(b, boss) :: BlockerGuard.Push
		expect(math.sqrt(far.vx * far.vx + far.vz * far.vz)).toBeNear(BlockerGuard.MAX_SPEED, 1e-9)
		expect(far.time > BlockerGuard.PUSH_TIME).toBe(true)
		expect(BlockerGuard.over(after(b, boss, far), boss)).toBe(false)
	end)

	it("measures the way out of the grown footprint along any direction", function()
		local column = wolf(0, 0)
		local b = body(0, 0, topOf(column))
		expect(BlockerGuard.exit(b, column, 1, 0)).toBeNear(column.width / 2 + HALF, 1e-9)
		expect(BlockerGuard.exit(b, column, 0, -1)).toBeNear(column.depth / 2 + HALF, 1e-9)
		local d = math.sqrt(0.5)
		expect(BlockerGuard.exit(b, column, d, d)).toBeNear((column.width / 2 + HALF) / d, 1e-9)
		expect(BlockerGuard.exit(body(9, 0, 0), column, 1, 0)).toBe(0)
	end)
end)
