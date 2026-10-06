--!strict
-- S24: procedural monster / boss / pet looks (Data/MonsterLooks, Logic/Anatomy), new Gait roles and the clip
-- choice for real models (Logic/LookAnim).

local Anatomy = require("../src/shared/Logic/Anatomy")
local Bosses = require("../src/shared/Data/Bosses")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Gait = require("../src/shared/Logic/Gait")
local LookAnim = require("../src/shared/Logic/LookAnim")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local Monsters = require("../src/shared/Data/Monsters")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

type Case = { id: string, look: any, variants: { string }, region: number? }

local function cases(): { Case }
	local out: { Case } = {}
	for _, def in Monsters.list do
		local look = MonsterLooks.get(def.id, def.region)
		table.insert(out, {
			id = def.id,
			look = look,
			variants = if def.elites then { "normal", "elite", "elite2" } else { "normal" },
			region = def.region,
		})
	end
	for _, boss in Bosses.list do
		table.insert(out, { id = boss.id, look = MonsterLooks.get(boss.id), variants = { "boss" } })
	end
	return out
end

local MATERIALS: { [string]: boolean } = {}
for _, m in Anatomy.MATERIALS do
	MATERIALS[m] = true
end
local ROLES: { [string]: boolean } = {}
for _, r in Anatomy.ROLES do
	ROLES[r] = true
end

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function checkRig(name: string, rig: Anatomy.Rig, budget: number)
	local function check(ok: boolean, what: string)
		if not ok then
			error(`{name}: {what}`)
		end
	end
	check(#rig.pieces > 0, "no pieces")
	check(#rig.pieces <= budget, `{#rig.pieces} pieces > budget {budget}`)
	local seen: { [string]: boolean } = {}
	for _, piece in rig.pieces do
		check(not seen[piece.name], `duplicate piece {piece.name}`)
		for i = 1, 3 do
			check(finite(piece.size[i]) and piece.size[i] > 0.03, `{piece.name} size`)
			check(finite(piece.pos[i]), `{piece.name} position`)
			check(finite(piece.rot[i]), `{piece.name} rotation`)
		end
		check(string.match(piece.color, "^#%x%x%x%x%x%x$") ~= nil, `{piece.name} colour {piece.color}`)
		check(MATERIALS[piece.material] == true, `{piece.name} material {piece.material}`)
		check(piece.parent == nil or seen[piece.parent] == true, `{piece.name} parent {piece.parent} not built before`)
		if piece.joint then
			check(ROLES[piece.joint.role] == true, `{piece.name} role {piece.joint.role}`)
		end
		seen[piece.name] = true
	end
	check(rig.hipHeight >= 0.1, "hipHeight")
	check(rig.height > rig.root.size[2], "height below the root")
	for i = 1, 3 do
		check(rig.root.size[i] > 0.3 and finite(rig.root.size[i]), "root size")
	end
end

describe("Monster looks: data", function()
	it("cover every monster kind and boss, nothing orphaned", function()
		local ids: { [string]: boolean } = {}
		for _, def in Monsters.list do
			ids[def.id] = true
			expect(MonsterLooks.has(def.id)).toBe(true)
		end
		for _, boss in Bosses.list do
			ids[boss.id] = true
			expect(MonsterLooks.has(boss.id)).toBe(true)
		end
		for id in MonsterLooks.raw do
			if not ids[id] then
				error(`orphaned look {id}`)
			end
		end
	end)

	it("inherit existing looks without cycles", function()
		for id, entry in MonsterLooks.raw do
			local seen: { [string]: boolean } = { [id] = true }
			local current = entry
			while current.inherit do
				expect(MonsterLooks.raw[current.inherit] ~= nil).toBe(true)
				expect(seen[current.inherit]).toBeNil()
				seen[current.inherit] = true
				current = MonsterLooks.raw[current.inherit]
			end
			local look = assert(MonsterLooks.get(id), id)
			expect(type(look.plan)).toBe("string")
			expect(Anatomy.isHex(look.colors.base) and Anatomy.isHex(look.colors.accent)).toBe(true)
		end
	end)

	it("have valid assets when given", function()
		for id, entry in MonsterLooks.raw do
			local asset = entry.asset
			if asset then
				expect(type(asset.model)).toBe("string")
				expect(asset.rig == "animator" or asset.rig == "gait" or asset.rig == "static").toBe(true)
				expect(#asset.rootSize).toBe(3)
				expect(asset.hipHeight >= 0 and asset.height > 0).toBe(true)
				for slot, anim in asset.anims or {} do
					expect(table.find(LookAnim.SLOTS, slot) ~= nil).toBe(true)
					if string.match(anim, "^rbxassetid://%d+$") == nil then
						error(`{id}: bad animation id for {slot}`)
					end
				end
			end
		end
	end)

	it("tint inherited colours with the region", function()
		local wolf = assert(MonsterLooks.get("wolf", 1))
		local iceWolf = assert(MonsterLooks.get("iceWolf", 4))
		expect(iceWolf.plan).toBe(wolf.plan)
		expect(iceWolf.colors.base ~= wolf.colors.base).toBe(true)
	end)
end)

describe("Monster looks: generator", function()
	it("builds every look for every variant and LOD within budget", function()
		for _, case in cases() do
			for _, variant in case.variants do
				local rig = Anatomy.build(case.look, { id = case.id, variant = variant, scale = 1 })
				local budget = if variant == "boss" then Anatomy.BUDGET.boss else Anatomy.BUDGET.normal
				checkRig(`{case.id}/{variant}`, rig, budget)
				local far = Anatomy.build(case.look, { id = case.id, variant = variant, lod = "far" })
				checkRig(`{case.id}/{variant}/far`, far, Anatomy.BUDGET.far)
				for _, piece in far.pieces do
					expect(piece.joint).toBeNil()
				end
			end
		end
	end)

	it("keeps the body inside the hitbox", function()
		for _, case in cases() do
			local rig = Anatomy.build(case.look, { id = case.id, scale = 1 })
			local core = rig.pieces[1]
			for _, piece in rig.pieces do
				if piece.joint and piece.joint.role == "body" then
					core = piece
				end
			end
			local e = Anatomy.extents(core.size, core.rot)
			for i = 1, 3 do
				if i ~= 2 then
					expect(e[i] <= rig.root.size[i] / 2 + 1e-6).toBe(true)
				end
			end
		end
	end)

	it("grows elites and Elite II", function()
		for _, case in cases() do
			if table.find(case.variants, "elite2") then
				local normal = Anatomy.build(case.look, { id = case.id, variant = "normal" })
				local elite = Anatomy.build(case.look, { id = case.id, variant = "elite" })
				local elite2 = Anatomy.build(case.look, { id = case.id, variant = "elite2" })
				expect(#elite.pieces > #normal.pieces).toBe(true)
				expect(#elite2.pieces > #elite.pieces).toBe(true)
				local glowing = false
				for _, piece in elite.pieces do
					if string.sub(piece.name, 1, 3) == "Eye" and piece.glow then
						glowing = true
					end
				end
				expect(glowing).toBe(true)
			end
		end
	end)

	it("mirrors left / right pairs", function()
		for _, case in cases() do
			local rig = Anatomy.build(case.look, { id = case.id })
			local byName: { [string]: Anatomy.Piece } = {}
			for _, piece in rig.pieces do
				byName[piece.name] = piece
			end
			for name, piece in byName do
				-- Weapon pieces ("W" + name) keep the weapon's own layout.
				if string.sub(name, -1) == "L" and not string.match(name, "^W%u") then
					local right = byName[string.sub(name, 1, -2) .. "R"]
					if right then
						expect(piece.pos[1]).toBeNear(-right.pos[1], 1e-6)
						expect(piece.pos[2]).toBeNear(right.pos[2], 1e-6)
						for i = 1, 3 do
							expect(piece.size[i]).toBeNear(right.size[i], 1e-6)
						end
					end
				end
			end
		end
	end)

	it("is deterministic and scales", function()
		for _, case in cases() do
			local a = Anatomy.build(case.look, { id = case.id, variant = case.variants[1], scale = 1.3 })
			local b = Anatomy.build(case.look, { id = case.id, variant = case.variants[1], scale = 1.3 })
			expect(a).toEqual(b)
			local one = Anatomy.build(case.look, { id = case.id, variant = case.variants[1], scale = 1 })
			expect(a.hipHeight).toBeNear(one.hipHeight * 1.3, 1e-6)
			expect(a.height).toBeNear(one.height * 1.3, 1e-6)
		end
	end)

	it("keeps Neon to small glowing details", function()
		for _, case in cases() do
			local rig = Anatomy.build(case.look, { id = case.id, variant = case.variants[1] })
			local total, neon = 0, 0
			for _, piece in rig.pieces do
				local s = piece.size
				local area = 2 * (s[1] * s[2] + s[2] * s[3] + s[1] * s[3])
				total += area
				if piece.material == "Neon" then
					neon += area
				end
			end
			if neon / total > 0.15 then
				error(`{case.id}: Neon is {math.floor(neon / total * 100)}% of the surface`)
			end
		end
	end)

	it("makes every kind of a region look different", function()
		local seen: { [string]: string } = {}
		for _, def in Monsters.list do
			local look = assert(MonsterLooks.get(def.id, def.region))
			local key =
				`{def.region}|{look.plan}|{look.colors.base}|{look.colors.accent}|{table.concat(look.parts or {}, ",")}`
			if seen[key] then
				error(`{def.id} looks like {seen[key]}`)
			end
			seen[key] = def.id
		end
	end)

	it("gives each body plan a body joint and the sockets accessories need", function()
		for _, case in cases() do
			local rig = Anatomy.build(case.look, { id = case.id })
			local hasBody = false
			for _, piece in rig.pieces do
				if piece.joint and piece.joint.role == "body" then
					hasBody = true
				end
			end
			expect(hasBody).toBe(true)
			expect(rig.sockets.Head ~= nil and rig.sockets.Back ~= nil).toBe(true)
		end
	end)
end)

describe("Pet looks", function()
	it("every pet has a look within 16 parts and says whether it flies", function()
		local count = 0
		for _, def in Cosmetics.list do
			if def.kind == "pet" then
				count += 1
				expect(def.look ~= nil).toBe(true)
				expect(type(def.flies)).toBe("boolean")
				local rig = Anatomy.build(def.look, { id = def.id, variant = "pet" })
				checkRig(def.id, rig, Anatomy.BUDGET.pet)
			end
		end
		expect(count >= 6).toBe(true)
	end)

	it("flying pets flap", function()
		for _, def in Cosmetics.list do
			if def.kind == "pet" and def.flies and def.look.plan ~= "elemental" then
				local rig = Anatomy.build(def.look, { id = def.id, variant = "pet" })
				local flaps = false
				for _, piece in rig.pieces do
					if piece.joint and piece.joint.role == "flap" then
						flaps = true
					end
				end
				expect(flaps).toBe(true)
			end
		end
	end)
end)

describe("Gait: S24 roles", function()
	local rest: Gait.Motion = { cycle = 0, move = 0, time = 0, raise = 0, strike = 0, hit = 0, dead = 0 }
	for _, role in { "flap", "segment", "claw", "sting", "jaw", "orbit" } do
		it(`{role} rests at zero and stays finite`, function()
			for _, side in { -1, 0, 1 } do
				local joint: Gait.Joint = { role = role :: any, side = side, phase = 0.3, amp = 1 }
				expect(Gait.isRest(Gait.pose(joint, rest))).toBe(true)
				for t = 0.1, 20, 0.7 do
					local m: Gait.Motion = {
						cycle = t,
						move = (t % 3) / 3,
						time = t,
						raise = (t % 2) / 2,
						strike = (t % 5) / 5,
						hit = 0,
						dead = 0,
					}
					local p = Gait.pose(joint, m)
					for _, v in { p.rx, p.ry, p.rz, p.x, p.y, p.z } do
						expect(finite(v)).toBe(true)
						expect(math.abs(v) <= 2 * math.pi + 1e-6).toBe(true)
					end
				end
			end
		end)
	end

	it("claws open in the windup and jaws open to bite", function()
		local m: Gait.Motion = { cycle = 0, move = 0, time = 5, raise = 1, strike = 0, hit = 0, dead = 0 }
		expect(Gait.pose({ role = "claw", side = 1, phase = 0, amp = 1 }, m).rx < 0).toBe(true)
		expect(Gait.pose({ role = "jaw", side = 0, phase = 0, amp = 1 }, m).rx < 0).toBe(true)
	end)
end)

describe("LookAnim", function()
	local all: { [string]: boolean } = {}
	for _, slot in LookAnim.SLOTS do
		all[slot] = true
	end

	it("puts death over hit over attacks over walking", function()
		expect(assert(LookAnim.pick({ dead = true, hit = true, attack = "attack1", speed = 10 }, all)).slot).toBe(
			"death"
		)
		expect(assert(LookAnim.pick({ hit = true, attack = "attack1", speed = 10 }, all)).slot).toBe("hit")
		expect(assert(LookAnim.pick({ attack = "attack2", speed = 10 }, all)).slot).toBe("attack2")
		expect(assert(LookAnim.pick({ speed = 10 }, all)).slot).toBe("walk")
		expect(assert(LookAnim.pick({ speed = 20 }, all)).slot).toBe("run")
		expect(assert(LookAnim.pick({ speed = 0 }, all)).slot).toBe("idle")
		expect(assert(LookAnim.pick({ speed = 0, spawning = true }, all)).slot).toBe("spawn")
	end)

	it("falls back to the clips the model has", function()
		local few = { idle = true, attack1 = true }
		expect(assert(LookAnim.pick({ speed = 20 }, few)).slot).toBe("idle")
		expect(assert(LookAnim.pick({ attack = "cast", speed = 0 }, few)).slot).toBe("attack1")
		expect(assert(LookAnim.pick({ attack = "attack2", speed = 0 }, few)).slot).toBe("attack1")
		expect(assert(LookAnim.pick({ speed = 0, spawning = true }, few)).slot).toBe("idle")
		expect(LookAnim.pick({ dead = true, speed = 0 }, few)).toBeNil()
		local hitPick = assert(LookAnim.pick({ hit = true, speed = 0 }, few))
		expect(hitPick.slot).toBe("idle")
		expect(LookAnim.pick({ speed = 0 }, {})).toBeNil()
	end)

	it("plays walking at the monster's speed", function()
		local pick = assert(LookAnim.pick({ speed = 12, walkSpeed = 8 }, all))
		expect(pick.speed).toBeNear(1.5, 1e-9)
		expect(assert(LookAnim.pick({ speed = 100, walkSpeed = 8, runAbove = 200 }, all)).speed).toBe(2)
		expect(assert(LookAnim.pick({ speed = 1, walkSpeed = 8 }, all)).speed).toBe(0.5)
	end)
end)
