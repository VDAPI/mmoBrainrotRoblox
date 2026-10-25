--!strict
-- S162m (owner 2026-10-25, docs/ANIM-WZORCE §9): monster paces, the melee approach, the dash of leaps and charges, the
-- release point of shots (Logic/MonsterMove, Data/MonsterRelease) and the server data the animations read.

local fs = require("@lune/fs")

local Bosses = require("../src/shared/Data/Bosses")
local Combat = require("../src/shared/Data/Combat")
local Gait = require("../src/shared/Logic/Gait")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterAssets = require("../src/shared/Data/MonsterAssets")
local MonsterMove = require("../src/shared/Logic/MonsterMove")
local MonsterRelease = require("../src/shared/Data/MonsterRelease")
local Monsters = require("../src/shared/Data/Monsters")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local cfg = Combat :: any

-- The server's root depth of a kind at a variant (Data/MonsterAssets hitbox x the kind's size x the variant's scale).
local function halfDepth(def: Monsters.MonsterDef, variant: string): number
	local asset = MonsterAssets[def.id]
	local scale = def.size * (Combat.variants :: any)[variant].scale
	return asset.rootSize[3] * scale / 2
end

local function reachOf(def: Monsters.MonsterDef, variant: string): number
	local range = def.range or (if def.attack == "ranged" then 30 else Combat.meleeRange)
	return range + halfDepth(def, variant)
end

describe("MonsterMove: paces (R1)", function()
	it("walks while idle, trots home, runs in a fight", function()
		expect(MonsterMove.gaitOf("idle")).toBe("walk")
		expect(MonsterMove.gaitOf("return")).toBe("trot")
		expect(MonsterMove.gaitOf("chase")).toBe("run")
		expect(MonsterMove.gaitOf("cast")).toBe("run")
	end)

	it("gives the wolf three speeds a gait can tell apart", function()
		local wolf = Monsters.get("wolf") :: Monsters.MonsterDef
		expect(wolf.moveSpeed * MonsterMove.speedMul("walk", cfg)).toBeNear(5.6, 1e-9)
		expect(wolf.moveSpeed * MonsterMove.speedMul("trot", cfg)).toBeNear(9.8, 1e-9)
		expect(wolf.moveSpeed * MonsterMove.speedMul("run", cfg)).toBe(14)
	end)

	it("keeps walk < trot < run with clear gaps for every kind", function()
		local walk = MonsterMove.speedMul("walk", cfg)
		local trot = MonsterMove.speedMul("trot", cfg)
		local run = MonsterMove.speedMul("run", cfg)
		expect(walk).toBeBetween(0.3, 0.5)
		expect(trot - walk >= 0.2).toBe(true)
		expect(run - trot >= 0.2).toBe(true)
		for _, def in Monsters.list do
			-- a walk is slow enough to read as one (the player runs 16)
			expect({ def.id, def.moveSpeed * walk <= 6 }).toEqual({ def.id, true })
		end
	end)

	it("lets a monster of the usual speed walk home from the hard leash before the teleport", function()
		local seconds = Combat.leashMax / (13 * Combat.returnSpeedMultiplier)
		expect(seconds < Combat.returnTimeout).toBe(true)
		-- and a monster that left the soft leash is home well before it
		expect(Combat.leashRange / (13 * Combat.returnSpeedMultiplier) < Combat.returnTimeout / 2).toBe(true)
	end)
end)

describe("MonsterMove: melee approach (R2)", function()
	it("stops the wolf at 0.6 of its reach (about 5 studs instead of 8.5)", function()
		local wolf = Monsters.get("wolf") :: Monsters.MonsterDef
		local d = halfDepth(wolf, "normal")
		local reach = reachOf(wolf, "normal")
		expect(reach).toBeNear(8.455, 1e-3)
		expect(MonsterMove.stopDistance("melee", reach, d, cfg)).toBeNear(reach * 0.6, 1e-9)
	end)

	it("keeps ranged monsters at their reach", function()
		for _, def in Monsters.list do
			if def.attack == "ranged" then
				local reach = reachOf(def, "normal")
				expect(MonsterMove.stopDistance("ranged", reach, halfDepth(def, "normal"), cfg)).toBe(reach)
			end
		end
	end)

	it("never walks a melee monster into its target nor past its reach", function()
		for _, def in Monsters.list do
			if def.attack == "melee" then
				for _, variant in { "normal", "elite", "elite2" } do
					local d = halfDepth(def, variant)
					local reach = reachOf(def, variant)
					local stop = MonsterMove.stopDistance("melee", reach, d, cfg)
					expect({ def.id, variant, stop >= d + MonsterMove.BODY_GAP - 1e-9 }).toEqual({
						def.id,
						variant,
						true,
					})
					expect({ def.id, variant, stop <= reach }).toEqual({ def.id, variant, true })
					-- inside the blow's hit rule with the whole windup's step back to spare
					expect(stop < reach * Combat.windReach + Combat.windSlack - 3).toBe(true)
				end
			end
		end
	end)

	it("walks to the point short of the target and stays when already closer", function()
		local x, z, d = MonsterMove.approach(0, 0, 10, 0, 4)
		expect(x).toBeNear(6, 1e-9)
		expect(z).toBeNear(0, 1e-9)
		expect(d).toBeNear(10, 1e-9)
		x, z = MonsterMove.approach(1, 2, 3, 2, 5)
		expect(x).toBe(1)
		expect(z).toBe(2)
		x, z, d = MonsterMove.approach(3, 3, 3, 3, 5)
		expect(d).toBe(0)
	end)
end)

describe("MonsterMove: dashes (Q6)", function()
	it("gives the wolf's leap and the boar's charge a running dash, every leap a flight", function()
		local leap = MonsterAbilities.get("leap") :: MonsterAbilities.Ability
		local charge = MonsterAbilities.get("charge") :: MonsterAbilities.Ability
		expect(leap.dash ~= nil and not leap.leap).toBe(true)
		expect(charge.dash ~= nil and not charge.leap).toBe(true)
		for id, ability in MonsterAbilities.byId do
			if ability.leap then
				expect({ id, ability.dash ~= nil }).toEqual({ id, true })
			end
		end
	end)

	it("lands every flight with the blow", function()
		for id, ability in MonsterAbilities.byId do
			local dash = ability.dash
			if dash then
				local startsIn, seconds = MonsterMove.dashStart(dash, ability.windup)
				expect({ id, startsIn >= 0, seconds > 0 }).toEqual({ id, true, true })
				expect(startsIn + seconds).toBeNear(ability.windup, 1e-9)
				-- the gather reads first: at least half the windup before it leaves the ground
				expect({ id, startsIn >= ability.windup / 2 }).toEqual({ id, true })
			end
		end
		local pounce = MonsterAbilities.get("pounce") :: MonsterAbilities.Ability
		local startsIn = MonsterMove.dashStart(pounce.dash :: MonsterMove.Dash, pounce.windup)
		expect(startsIn).toBeNear(1.0, 1e-9) -- docs/ANIM-WZORCE §3.6: flight 1.0-1.4 s
	end)

	it("runs the wolf's leap up to the approach distance in front of the circle", function()
		local wolf = Monsters.get("wolf") :: Monsters.MonsterDef
		local d = halfDepth(wolf, "elite2")
		local reach = reachOf(wolf, "elite2")
		local stop = MonsterMove.stopDistance("melee", reach, d, cfg)
		-- the leap is announced at a target within reach: a short hop that ends in front of it
		local x, z, travel = MonsterMove.dashLanding(0, 0, reach, 0, stop, math.huge)
		expect(travel).toBeNear(reach - stop, 1e-9)
		expect(x).toBeNear(reach - stop, 1e-9)
		expect(z).toBe(0)
		-- a target already at the approach distance: no dash
		local _, _, none = MonsterMove.dashLanding(0, 0, stop + MonsterMove.DASH_MIN / 2, 0, stop, math.huge)
		expect(none).toBe(0)
	end)

	it("runs the boar's charge no farther than its line, at a charge's speed", function()
		local charge = MonsterAbilities.get("charge") :: MonsterAbilities.Ability
		local length = charge.length :: number
		local _, _, travel = MonsterMove.dashLanding(0, 0, 0, 40, 5, length)
		expect(travel).toBe(length)
		local _, seconds = MonsterMove.dashStart(charge.dash :: MonsterMove.Dash, charge.windup)
		local boar = Monsters.get("boar") :: Monsters.MonsterDef
		local speed = (length - 5) / seconds
		expect(speed > boar.moveSpeed * 2).toBe(true) -- reads as a charge
		expect(speed <= 45).toBe(true) -- the humanoid keeps its feet on the ground
	end)

	it("arcs the leaps and keeps the charge on the ground", function()
		local charge = MonsterAbilities.get("charge") :: MonsterAbilities.Ability
		expect(MonsterMove.arcHeight(charge.dash :: MonsterMove.Dash, 15, 1)).toBe(0)
		local pounce = MonsterAbilities.get("pounce") :: MonsterAbilities.Ability
		local dash = pounce.dash :: MonsterMove.Dash
		expect(MonsterMove.arcHeight(dash, 4, 1)).toBe(2) -- arcMin
		expect(MonsterMove.arcHeight(dash, 20, 1)).toBeNear(5, 1e-9)
		expect(MonsterMove.arcHeight(dash, 40, 1)).toBe(6) -- arcMax
		expect(MonsterMove.arcHeight(dash, 40, 1.5)).toBeNear(9, 1e-9) -- x the look scale
	end)

	it("tells the clients where a flight is (DashAt, DashTime) and Gait.leapArc draws it", function()
		expect(MonsterMove.flightProgress(9.9, 10, 0.4)).toBeNil()
		expect(MonsterMove.flightProgress(10, 10, 0.4)).toBe(0)
		expect(MonsterMove.flightProgress(10.2, 10, 0.4)).toBeNear(0.5, 1e-9)
		expect(MonsterMove.flightProgress(10.4, 10, 0.4)).toBeNear(1, 1e-9)
		expect(MonsterMove.flightProgress(10.5, 10, 0.4)).toBeNil()
		local _, y = Gait.leapArc(0.5, { 0, 3, 0 }, { 10, 3, 0 }, 2)
		expect(y).toBeNear(5, 1e-9) -- DashArc = the apex over the straight line
	end)
end)

describe("MonsterRelease: where shots leave (problem 7)", function()
	it("names a body plan for every kind and boss look", function()
		local missing = {}
		for _, def in Monsters.list do
			if MonsterRelease.planOf(def.id) == nil then
				table.insert(missing, def.id)
			end
		end
		for _, boss in Bosses.all do
			if MonsterRelease.planOf(boss.id) == nil then
				table.insert(missing, boss.id)
			end
		end
		expect(missing).toEqual({})
	end)

	it("puts every release on the body: in front of the centre, within its height", function()
		for id in MonsterRelease.KINDS do
			local r = MonsterRelease.of(id)
			expect({ id, r.up > 0.3 and r.up < 0.8 }).toEqual({ id, true })
			expect({ id, r.fwd > 0 and r.fwd < 0.6 }).toEqual({ id, true })
			expect({ id, math.abs(r.side) <= 0.25 }).toEqual({ id, true })
		end
		-- the jaw of a quadruped is farther ahead than a caster's hand
		expect(MonsterRelease.of("wolf").fwd > MonsterRelease.of("goblinShaman").fwd).toBe(true)
		-- an unknown look falls back to the biped hand
		expect(MonsterRelease.of("nobody")).toEqual(MonsterRelease.PLANS.biped)
	end)

	it("moves a ranged kind's shot start by at most a few studs (the flight barely shortens)", function()
		for _, def in Monsters.list do
			if def.attack == "ranged" then
				local asset = MonsterAssets[def.id]
				local h = asset.height * def.size * (asset.visual or 1)
				local r = MonsterRelease.of(def.id)
				local ahead = math.sqrt((r.fwd * h) ^ 2 + (r.side * h) ^ 2)
				expect({ def.id, ahead < 3.5 }).toEqual({ def.id, true })
				-- a shot of the kind's range is at most ~15 % shorter (time to hit, tools/balance_reasons)
				expect({ def.id, ahead / (def.range or 30) < 0.15 }).toEqual({ def.id, true })
			end
		end
	end)
end)

describe("Monster server data for animations (wiring)", function()
	local monster = fs.readFile("src/server/Entities/Monster.luau")
	local rig = fs.readFile("src/server/Entities/RigBuilder.luau")
	local combat = fs.readFile("src/server/Services/CombatService.luau")

	it("stamps SpawnedAt with the server clock before the model replicates", function()
		local stamp = string.find(monster, 'SetAttribute("SpawnedAt", Workspace:GetServerTimeNow())', 1, true)
		local parent = string.find(monster, "model.Parent = parent", 1, true)
		expect(stamp ~= nil and parent ~= nil and stamp < parent).toBe(true)
	end)

	it("mirrors the pace as Gait", function()
		expect(string.find(monster, 'SetAttribute("Gait", gait)', 1, true) ~= nil).toBe(true)
		expect(string.find(monster, 'SetAttribute("Gait", MonsterMove.gaitOf("idle"))', 1, true) ~= nil).toBe(true)
	end)

	it("announces a flight with every Dash* attribute, DashAt last", function()
		local last = string.find(monster, "local function planDash", 1, true) or 0
		expect(last > 0).toBe(true)
		for _, name in { "DashId", "DashMode", "DashFrom", "DashTo", "DashTime", "DashArc", "DashAt" } do
			local at = string.find(monster, `model:SetAttribute("{name}", `, last, true)
			expect({ name, at ~= nil and (at :: number) > last }).toEqual({ name, true })
			last = at or last
		end
	end)

	it("hangs a Muzzle on the root and shoots from it", function()
		expect(string.find(rig, 'muzzle.Name = "Muzzle"', 1, true) ~= nil).toBe(true)
		expect(string.find(combat, 'monster.root:FindFirstChild("Muzzle")', 1, true) ~= nil).toBe(true)
		expect(string.find(combat, "release = release,", 1, true) ~= nil).toBe(true)
	end)
end)
