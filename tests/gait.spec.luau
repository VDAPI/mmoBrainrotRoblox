--!strict
local Anatomy = require("../src/shared/Logic/Anatomy")
local Bases = require("../src/shared/Data/Items/Bases")
local Bosses = require("../src/shared/Data/Bosses")
local Config = require("../src/shared/Config")
local Gait = require("../src/shared/Logic/Gait")
local Items = require("../src/shared/Data/Items")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local MonsterMotions = require("../src/shared/Data/MonsterMotions")
local Monsters = require("../src/shared/Data/Monsters")
local MotionKeys = require("../src/shared/Logic/MotionKeys")
local Plans = require("../src/shared/Logic/Anatomy/Plans")
local T = require("./Test")
local Telegraph = require("../src/shared/Logic/Telegraph")
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
		-- S117: the strike takes the last STRIKE_SECONDS of the windup and peaks at its end (the server's hit)
		local windup = 0.4
		local r0, s0 = Gait.attack(0, windup)
		T.expect(r0).toBe(0)
		T.expect(s0).toBe(0)
		local rUp = Gait.attack(windup - Gait.STRIKE_SECONDS - 1e-3, windup)
		T.expect(rUp).toBeNear(1, 1e-3)
		local _, sHit = Gait.attack(windup, windup)
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

-- S117 ------------------------------------------------------------------------------------------------------------

-- The pose before S117 (a copy of the formulas), for test 1.
local TAU = 2 * math.pi
local function oldPose(joint: Gait.Joint, m: Gait.Motion): { number }
	local amp = joint.amp
	local swing = math.sin(m.cycle + joint.phase * TAU)
	local alive = 1 - m.dead
	local idle = 1 - m.move
	local role = joint.role
	if role == "body" then
		local hover = if amp > 1 then amp - 1 else 0
		local bob = math.sin(m.time * 2) * 0.05 + math.sin(m.time * 1.6) * hover
		local step = math.abs(swing) * 0.08 * m.move
		local lean = -m.strike * 0.14 + m.raise * 0.06 + m.hit * 0.12
		return {
			lean * alive,
			0,
			m.dead * 1.35,
			0,
			(bob + step) * alive - m.dead * 0.4,
			-m.strike * 0.5 * alive + m.hit * 0.15,
		}
	elseif role == "leg" then
		return { swing * 0.65 * amp * m.move * alive + m.dead * 0.5, 0, 0, 0, 0, 0 }
	elseif role == "spiderLeg" then
		local lift = math.max(0, math.cos(m.cycle + joint.phase * TAU)) * 0.35 * m.move
		local twitch = math.sin(m.time * 9 + joint.phase * TAU) * 0.04 * idle
		return {
			0,
			swing * 0.4 * amp * m.move * alive,
			joint.side * (lift + twitch) * alive + joint.side * m.dead * 0.6,
			0,
			0,
			0,
		}
	elseif role == "arm" then
		local walk = -swing * 0.5 * amp * m.move
		local share = if joint.side > 0 then 1 else 0.3
		local attack = (m.raise * 2.3 - m.strike * 0.5 * (1 - m.raise)) * share
		local sway = math.sin(m.time * 1.8 + joint.side) * 0.04 * idle
		return { (walk + attack + sway) * alive, 0, joint.side * (0.05 + m.raise * 0.15 * share) * alive, 0, 0, 0 }
	elseif role == "head" then
		local look = math.sin(m.time * 0.7) * 0.25 * idle
		local nod = math.sin(m.cycle * 2) * 0.05 * m.move
		local rx = m.raise * 0.45 - m.strike * 0.55 + nod - m.hit * 0.2
		return { rx * alive - m.dead * 0.3, look * alive, 0, 0, 0, 0 }
	elseif role == "tail" then
		local wag = math.sin(m.time * 2.4) * 0.35 + math.sin(m.cycle) * 0.25 * m.move
		return { math.sin(m.time * 1.3) * 0.08 * alive, wag * amp * alive, 0, 0, 0, 0 }
	elseif role == "flap" then
		local ramp = math.clamp(m.time, 0, 1)
		local busy = math.max(m.move, m.raise)
		local beat = math.sin(m.time * (5 + 7 * busy)) * (0.32 + 0.3 * busy) * ramp
		return { 0, 0, joint.side * (beat * amp * alive - m.dead * 0.7), 0, 0, 0 }
	elseif role == "segment" then
		local ramp = math.clamp(m.time, 0, 1)
		local wave = math.sin(m.time * (1.6 + 2.4 * m.move) - joint.phase * TAU) * 0.28 * amp * ramp
		return { (-m.strike * 0.25 + m.raise * 0.12) * amp * alive, wave * alive, 0, 0, 0, 0 }
	elseif role == "claw" then
		return { (-m.raise * 0.6 + m.strike * 0.25) * alive, 0, 0, 0, 0, 0 }
	elseif role == "sting" then
		local ramp = math.clamp(m.time, 0, 1)
		local sway = math.sin(m.time * 1.5 + joint.phase * TAU) * 0.05 * idle * ramp
		return { (m.raise * 0.35 - m.strike * 0.85) * amp * alive, sway * alive, 0, 0, 0, 0 }
	elseif role == "jaw" then
		local open = m.raise * 0.5 + m.strike * 0.15 * (1 - m.raise) + m.hit * 0.15
		return { -open * amp * alive - m.dead * 0.35, 0, 0, 0, 0, 0 }
	elseif role == "orbit" then
		local ramp = math.clamp(m.time, 0, 1)
		return { 0, ((m.time * (0.8 - m.dead * 0.5) * amp) % TAU) * ramp, 0, 0, 0, 0 }
	elseif role == "wing" then
		local busy = math.max(m.move, m.raise)
		local flap = 0.15 + math.sin(m.time * (3 + 4 * busy)) * (0.3 + 0.25 * busy)
		return { 0, 0, joint.side * flap * amp * alive - joint.side * m.dead * 0.6, 0, 0, 0 }
	end
	return { 0, 0, 0, 0, 0, 0 }
end

local function values(p: Gait.Pose): { number }
	return { p.rx, p.ry, p.rz, p.x, p.y, p.z }
end

local function same(a: { number }, b: { number }, eps: number?): boolean
	for i = 1, 6 do
		if math.abs(a[i] - b[i]) > (eps or 1e-9) then
			return false
		end
	end
	return true
end

local function grid(fn: (Gait.Motion) -> ())
	for i = 0, 30 do
		fn(motion({
			cycle = i * 0.41,
			move = (i % 5) / 4,
			time = i * 0.37,
			raise = (i % 3) / 2,
			strike = (i % 4) / 3,
			hit = (i % 2) * 0.7,
			dead = (i % 6) / 5,
		}))
	end
end

-- The plans of the monster looks: plan -> the first look id (sorted) of that plan.
local function representatives(): { [string]: string }
	local ids: { string } = {}
	for id in MonsterLooks.raw do
		table.insert(ids, id)
	end
	table.sort(ids)
	local out: { [string]: string } = {}
	for _, id in ids do
		local look = MonsterLooks.get(id)
		if look and not out[look.plan] then
			out[look.plan] = id
		end
	end
	return out
end

local function rolesOf(lookId: string): { [string]: boolean }
	local look = MonsterLooks.get(lookId) :: MonsterLooks.Look
	local rig = Anatomy.build(look :: any, { id = lookId, variant = "normal" })
	local roles: { [string]: boolean } = {}
	for _, piece in rig.pieces do
		if piece.joint then
			roles[piece.joint.role] = true
		end
	end
	return roles
end

local function finite(v: number): boolean
	return v == v and v ~= math.huge and v ~= -math.huge
end

-- Plans the test may skip, with the reason (none of their looks lives in MonsterLooks).
local NO_LOOK = { horse = "S96 mounts: their looks are in Data/Mounts, they never fight" }

T.describe("Gait: attack styles (S117)", function()
	T.it("1. without a style and the new fields the pose is the one before S117", function()
		for _, role in Gait.ROLES do
			for _, side in { -1, 0, 1 } do
				for _, amp in { 1, 1.35 } do
					local j: Gait.Joint = { role = role :: any, side = side, phase = 0.3, amp = amp }
					grid(function(m)
						T.expect({ role, side, same(values(Gait.pose(j, m)), oldPose(j, m)) })
							.toEqual({ role, side, true })
					end)
				end
			end
		end
	end)

	T.it("2. every plan has a basic, a default special and a death, all of them known", function()
		for plan in Plans.list do
			local entry = MonsterMotions.PLANS[plan]
			T.expect({ plan, entry ~= nil }).toEqual({ plan, true })
			if entry then
				T.expect({ plan, MonsterMotions.STYLES[entry.basic] ~= nil }).toEqual({ plan, true })
				T.expect({ plan, entry.special.default ~= nil }).toEqual({ plan, true })
				for ability, styleId in entry.special do
					T.expect({ plan, ability, MonsterMotions.STYLES[styleId] ~= nil }).toEqual({ plan, ability, true })
				end
				T.expect({ plan, MonsterMotions.DEATH[entry.death] ~= nil }).toEqual({ plan, true })
				if entry.roar then
					T.expect({ plan, MonsterMotions.STYLES[entry.roar] ~= nil }).toEqual({ plan, true })
				end
			end
		end
		for plan in MonsterMotions.PLANS do
			T.expect({ plan, Plans.get(plan) ~= nil }).toEqual({ plan, true })
		end
	end)

	T.it("3. styles: finite numbers in bounds, known roles, each plan's styles move a role it has", function()
		local function checkPose(label: string, role: string, o: { number }?)
			if not o then
				return
			end
			T.expect({ label, role, table.find(Gait.ROLES, role) ~= nil }).toEqual({ label, role, true })
			T.expect({ label, role, #o }).toEqual({ label, role, 6 })
			for i, v in o do
				T.expect({ label, role, i, finite(v) }).toEqual({ label, role, i, true })
				local limit = if i <= 3 then 2.5 else 3
				T.expect({ label, role, i, math.abs(v) <= limit }).toEqual({ label, role, i, true })
			end
		end
		for id, style in MonsterMotions.STYLES do
			for role, o in style.windup do
				checkPose(id, role, o)
			end
			for role, o in style.strike do
				checkPose(id, role, o)
			end
			checkPose(id, "leg", style.hindWindup)
			checkPose(id, "leg", style.hindStrike)
			if style.left then
				checkPose(id, "arm", style.left.windup)
				checkPose(id, "arm", style.left.strike)
			end
			T.expect({ id, (style.dash or 0) >= 0 and (style.dash or 0) <= 4 }).toEqual({ id, true })
			T.expect({ id, (style.hop or 0) >= 0 and (style.hop or 0) <= 2 }).toEqual({ id, true })
			T.expect({ id, (style.tremble or 0) >= 0 and (style.tremble or 0) <= 0.2 }).toEqual({ id, true })
			T.expect({ id, (style.spin or 0) >= 0 and (style.spin or 0) <= 3 }).toEqual({ id, true })
		end
		for id, def in MonsterMotions.DEATH do
			for role, o in def.pose do
				checkPose(id, role, o)
			end
			for role, o in def.early or {} do
				checkPose(id, role, o)
			end
		end
		local reps = representatives()
		for plan, entry in MonsterMotions.PLANS do
			local lookId = reps[plan]
			if not lookId then
				T.expect({ plan, NO_LOOK[plan] ~= nil }).toEqual({ plan, true })
				continue
			end
			local roles = rolesOf(lookId)
			local used: { string } = { entry.basic }
			for _, styleId in entry.special do
				table.insert(used, styleId)
			end
			for _, styleId in used do
				local style = MonsterMotions.STYLES[styleId]
				local moves = false
				for role in style.windup do
					moves = moves or roles[role] == true
				end
				for role in style.strike do
					moves = moves or roles[role] == true
				end
				T.expect({ plan, styleId, moves }).toEqual({ plan, styleId, true })
			end
			local deathMoves = false
			for role in MonsterMotions.DEATH[entry.death].pose do
				deathMoves = deathMoves or roles[role] == true
			end
			T.expect({ plan, entry.death, deathMoves }).toEqual({ plan, entry.death, true })
		end
	end)

	T.it("4. every Elite II kind has a style, every humanoid weapon a basic attack", function()
		local EXCEPTIONS: { [string]: boolean } = {} -- weapons that fall back to the plan's basic on purpose
		for _, def in Monsters.list do
			local look = MonsterLooks.get(def.id, def.region)
			if look then
				if def.ability then
					local styleId = MonsterMotions.styleFor(look.plan, look.weapon, def.ability)
					T.expect({ def.id, styleId ~= nil and MonsterMotions.STYLES[styleId :: string] ~= nil }).toEqual({
						def.id,
						true,
					})
				end
				local basic = MonsterMotions.styleFor(look.plan, look.weapon)
				T.expect({ def.id, basic ~= nil and MonsterMotions.STYLES[basic :: string] ~= nil }).toEqual({
					def.id,
					true,
				})
			end
		end
		for id in MonsterLooks.raw do
			local look = MonsterLooks.get(id)
			if look and look.weapon and (look.plan == "humanoid" or look.plan == "beast") then
				local known = MonsterMotions.WEAPON_BASIC[look.weapon] ~= nil or EXCEPTIONS[look.weapon] == true
				T.expect({ id, look.weapon, known }).toEqual({ id, look.weapon, true })
			end
		end
		for _, styleId in MonsterMotions.WEAPON_BASIC do
			T.expect({ styleId, MonsterMotions.STYLES[styleId] ~= nil }).toEqual({ styleId, true })
		end
	end)

	T.it("5. a style at rest adds nothing", function()
		local rest = motion({ time = 0 })
		for id in MonsterMotions.STYLES do
			local m = motion({ time = 0 })
			m.style = id
			m.tremble, m.hop, m.spin, m.roar, m.rise = 0, 0, 0, 0, 1
			for _, role in Gait.ROLES do
				for _, side in { -1, 0, 1 } do
					for _, front in { -1, 0, 1 } do
						local j: Gait.Joint = { role = role :: any, side = side, phase = 0, amp = 1, front = front }
						local plain = Gait.pose(j, rest)
						local styled = Gait.pose(j, m)
						T.expect({ id, role, same(values(plain), values(styled)) }).toEqual({ id, role, true })
						if role == "leg" or role == "spiderLeg" or role == "head" or role == "body" then
							T.expect({ id, role, Gait.isRest(styled) }).toEqual({ id, role, true })
						end
					end
				end
			end
		end
	end)

	T.it("6. the gather peaks at the server's hit, in step with the telegraph's flash", function()
		local cfg = Config.Telegraph
		local function check(label: string, windup: number)
			local w = Telegraph.windup(windup)
			local from = w - Gait.STRIKE_SECONDS
			local _, peak, full = Gait.charge(w, w)
			T.expect({ label, math.abs(peak - 1) <= 0.02 }).toEqual({ label, true })
			T.expect({ label, full }).toEqual({ label, 1 })
			local _, _, none = Gait.charge(0, w)
			T.expect({ label, none }).toEqual({ label, 0 })
			local lastRaise = -1
			for i = 0, 200 do
				local t = w * i / 200
				local raise, strike = Gait.charge(t, w)
				T.expect({ label, strike <= peak + 1e-9 }).toEqual({ label, true })
				if t < from - 1e-9 then
					T.expect({ label, strike }).toEqual({ label, 0 })
					T.expect({ label, raise >= lastRaise - 1e-12 }).toEqual({ label, true })
					lastRaise = raise
				end
				-- D2: before the blow no flash and the strike below its peak; at the blow both
				if t < w - 1e-9 then
					T.expect({ label, Telegraph.flashing(t, w, cfg) }).toEqual({ label, 0 })
					T.expect({ label, strike < 1 }).toEqual({ label, true })
				end
			end
			T.expect({ label, Telegraph.flashing(w, w, cfg) > 0 }).toEqual({ label, true })
		end
		for id, ability in MonsterAbilities.byId do
			check(id, ability.windup)
			local keys = MotionKeys.ability(id) :: MotionKeys.Keys
			T.expect(MotionKeys.at(keys, "strikePeak")).toBeNear(ability.windup, 1e-9)
			T.expect(MotionKeys.at(keys, "hit")).toBeNear(ability.windup, 1e-9)
		end
		for _, boss in Bosses.all do -- S149: the world boss too
			for _, attack in boss.attacks do
				check(`{boss.id}.{attack.id}`, attack.windup)
				local keys = MotionKeys.boss(boss.id, attack.id) :: MotionKeys.Keys
				T.expect(MotionKeys.at(keys, "strikePeak")).toBeNear(attack.windup, 1e-9)
			end
		end
		-- a basic attack starts STRIKE_NOW_LEAD before the end of its windup when its event arrives: peak 0.03 s later
		local w = Gait.DEFAULT_WINDUP
		local start = w - Gait.STRIKE_NOW_LEAD
		local _, atEvent = Gait.attack(start, w)
		local _, atPeak = Gait.attack(start + Gait.STRIKE_NOW_LEAD, w)
		T.expect(atPeak).toBeNear(1, 1e-9)
		T.expect(atEvent < atPeak).toBe(true)
	end)

	T.it("7. every death moves the body, fliers fall at least their hover height", function()
		for id in MonsterMotions.DEATH do
			local m = motion({ dead = 1, time = 3 })
			m.deathStyle = id
			m.deathSide = -1
			m.hover = 2.5
			local body = Gait.pose({ role = "body", side = 0, phase = 0, amp = 1 }, m)
			T.expect({ id, Gait.isRest(body) }).toEqual({ id, false })
			for _, v in values(body) do
				T.expect({ id, finite(v) }).toEqual({ id, true })
			end
			if MonsterMotions.DEATH[id].hoverDrop then
				T.expect({ id, body.y <= -2.5 }).toEqual({ id, true })
			end
		end
	end)

	T.it("8. a hit pushes the body away from the attacker", function()
		local rx, rz, x, z = Gait.hitLean(0, 1, 1)
		T.expect(rx > 0).toBe(true) -- from the front: leans back
		T.expect(z > 0).toBe(true)
		T.expect(rz).toBe(-0)
		T.expect(x).toBe(0)
		local rx2, rz2, x2 = Gait.hitLean(-1, 0, 1)
		T.expect(rz2 > 0).toBe(true) -- from the right (pushed to -X): the top tilts left
		T.expect(x2 < 0).toBe(true)
		T.expect(rx2).toBe(0)
		local _, _, _, zBoss = Gait.hitLean(0, Config.MonsterLook.bossHitScale, 1)
		T.expect(zBoss < z).toBe(true)
		-- without a direction: the flinch before S117
		local m = motion({ hit = 1, time = 2 })
		m.hitX, m.hitZ = 0, 0
		local j: Gait.Joint = { role = "body", side = 0, phase = 0, amp = 1 }
		T.expect(same(values(Gait.pose(j, m)), oldPose(j, m))).toBe(true)
		m.hitZ = 1
		T.expect(Gait.pose(j, m).rx > 0).toBe(true)
	end)

	T.it("9. a leap arc starts and ends on its points, highest in the middle", function()
		local from, to = { 0, 0, 0 }, { 10, 0, -4 }
		local x0, y0, z0 = Gait.leapArc(0, from, to, 6)
		T.expect({ x0, y0, z0 }).toEqual({ 0, 0, 0 })
		local x1, y1, z1 = Gait.leapArc(1, from, to, 6)
		T.expect({ x1, y1, z1 }).toEqual({ 10, 0, -4 })
		local _, yMid = Gait.leapArc(0.5, from, to, 6)
		T.expect(yMid).toBeNear(6, 1e-9)
		for i = 0, 20 do
			local x, y, z = Gait.leapArc(i / 20, from, to, 6)
			T.expect(finite(x) and finite(y) and finite(z)).toBe(true)
			T.expect(y <= yMid + 1e-9).toBe(true)
		end
	end)

	T.it("roar, rise and flight stay finite and leave no trace when off", function()
		local j: Gait.Joint = { role = "body", side = 0, phase = 0, amp = 1 }
		local m = motion({ time = 1.3 })
		local plain = values(Gait.pose(j, m))
		m.roar, m.rise, m.flying = 0, 1, 0
		T.expect(same(values(Gait.pose(j, m)), plain)).toBe(true)
		m.rise = 0
		T.expect(Gait.pose(j, m).y <= -Gait.RISE_DEPTH + 0.2).toBe(true)
		T.expect(Gait.roarEnvelope(0, 1.2)).toBe(0)
		T.expect(Gait.roarEnvelope(0.6, 1.2)).toBe(1)
		T.expect(Gait.roarEnvelope(1.2, 1.2)).toBe(0)
	end)

	T.it("a summoned helper climbs out on the same curve in the game and in AnimLab", function()
		T.expect(Gait.riseOf(0, 0.8)).toBe(0)
		T.expect(Gait.riseOf(0.8, 0.8)).toBe(1)
		local last = 0
		for i = 1, 16 do
			local t = i * 0.05
			local rise = Gait.riseOf(t, 0.8)
			T.expect(rise >= last).toBe(true)
			T.expect(Gait.stateMotion("spawn", t, { rise = true, riseSeconds = 0.8 }).rise).toBe(rise)
			last = rise
		end
	end)
end)
