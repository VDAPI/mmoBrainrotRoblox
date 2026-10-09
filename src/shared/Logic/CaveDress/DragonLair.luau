--!strict
-- Vaelgrath's Lair (boss 100) dressing (S51): the frozen lair of the dragon round the fight (the contract: nothing
-- collidable within 50 studs of (0, -10) but the four braziers of World/Layouts/dungeon_frostpeak, which the layout
-- builds itself; the dressing only adds what does not collide):
--   * at each brazier an iron bowl on a pedestal of bones with a big warm fire, embers and sparks, and round it a flat
--     disc of thawed, wet rock of exactly WARM_RADIUS (9) with steam: the player sees where it is warm in phase 3,
--   * the crown of ice spikes leaning towards the middle on r 76-92 (not in the south sector of the niche and the
--     corridor), bones of victims at their feet (mammoth ribs, a giant's skull),
--   * the frozen hoard in the bays north-east and north-west (gold, chests, weapons and armour in blocks of ice), the
--     predecessors frozen mid-step behind the ice in the east and west walls,
--   * the nest on the unreachable ledge in the north under the hole in the dome: crushed ice and gold in a moonbeam
--     with falling snow; icicles under the vault. Pure.

local Grotto = require("./Grotto")
local Kit = require("./Kit")

local o = Kit.o

local DragonLair = {}

type Build = Kit.Build
type Env = Kit.Env

local CX, CZ = 0, -10
local WARM_RADIUS = 9 -- Entities/BossScripts/vaelgrath (tests compare the two)
local FIRE = "#FF9A3A"
local ICE = { c = "#A8D8F0", m = "Ice" }
local ICEGLASS = { c = "#BFE8FF", m = "Glass" }
local BONE = { c = "#D8D4C8", m = "SmoothPlastic" }
local GOLD = { c = "#C9A45C", m = "Metal" }
local WET = { c = "#3A4048", m = "SmoothPlastic" }

local function at(r: number, deg: number): (number, number)
	local a = math.rad(deg)
	return CX + math.cos(a) * r, CZ + math.sin(a) * r
end

local function braziers(env: Env, out: { Build })
	local list: { { number } } = env.shape.braziers or {}
	for k, p in list do
		local b = Kit.build(env, `BrazierBowl_{k}`, "camp", p[1], p[2], 0)
		local y = Kit.gy(env, b, 0, 0)
		-- the thawed wet rock (flat, under the attacks' red discs), steam over it
		b.bp:add(
			"cyl",
			0.05,
			WARM_RADIUS * 2,
			WARM_RADIUS * 2,
			0,
			y + 0.03,
			0,
			0,
			0,
			90,
			o(WET, "detail", { col = false })
		)
		-- the bowl of wrought iron on bones (no collision: the layout's campfire collides)
		for m = 0, 2 do
			local a = m * 2 * math.pi / 3
			b.bp:beam(
				math.cos(a) * 1.6,
				y,
				math.sin(a) * 1.6,
				math.cos(a) * 0.8,
				y + 2.2,
				math.sin(a) * 0.8,
				0.5,
				o(BONE, "detail", { col = false })
			)
		end
		b.bp:add("cyl", 1, 3.6, 3.6, 0, y + 2.6, 0, 0, 0, 90, o(Kit.iron, "detail", { col = false }))
		Kit.fire(b.bp, 0, y + 3.4, 0, 2.2, FIRE, "detail")
		Kit.lifeAt(env.ctx, b, "embers", 0, 3.6, 0, 1.5)
		Kit.lifeAt(env.ctx, b, "steam", 0, 0.3, 0, WARM_RADIUS - 1)
		table.insert(out, b)
	end
end

local function crown(env: Env, out: { Build })
	local n = 0
	for k = 0, 17 do
		local deg = k * 20 + 10
		-- the south sector (the niche and the corridor) stays free
		if deg < 65 or deg > 115 then
			n += 1
			local r = 78 + (k % 3) * 6
			local x, z = at(r, deg)
			local b = Kit.build(env, `IceSpike_{n}`, "landmark", x, z, 0)
			local y = Kit.gy(env, b, 0, 0)
			local h = 15 + (k % 4) * 5
			-- leaning towards the middle
			local lean = math.rad(deg + 180)
			local tx, tz = math.cos(lean) * h * 0.35, math.sin(lean) * h * 0.35
			b.bp:beam(0, y, 0, tx, y + h, tz, 3 - (k % 2) * 0.6, o(ICE, "shell", { q = false }))
			b.bp:beam(
				tx * 0.6,
				y + h * 0.6,
				tz * 0.6,
				tx * 1.05,
				y + h * 1.1,
				tz * 1.05,
				1,
				o(ICEGLASS, "detail", { col = false, t = 0.3 })
			)
			if k % 3 == 0 then
				Kit.bones(b.bp, 3, y, 2, 5)
			end
			table.insert(out, b)
		end
	end
	-- a giant's skull and mammoth ribs at the spikes' feet (west)
	local vx, vz = at(84, 200)
	local s = Kit.build(env, "VictimBones", "traces", vx, vz, 0)
	local sy = Kit.gy(env, s, 0, 0)
	s.bp:add("ball", 5, 4, 5, 0, sy + 2, 0, 0, 0, 0, o(BONE, "detail", { col = false }))
	for m = 0, 4 do
		s.bp:beam(4 + m * 1.6, sy, -2, 4 + m * 1.6, sy + 6, 1, 0.5, o(BONE, "detail", { col = false }))
	end
	table.insert(out, s)
end

local function hoard(env: Env, out: { Build })
	for k, sx in { -1, 1 } do
		local h = Kit.build(env, `FrozenHoard_{k}`, "glow", sx * 64, -66, 0)
		local y = Kit.gy(env, h, 0, 0)
		h.bp:add("ball", 10, 3, 8, 0, y + 0.8, 0, 0, 0, 0, o(GOLD, "shell", { q = false }))
		for m = 0, 2 do
			h.bp:box(3, 5, 2.4, -4 + m * 4, y + 2.5, 4, o(ICEGLASS, "detail", { col = false, t = 0.35 }))
			h.bp:box(1.4, 3, 0.6, -4 + m * 4, y + 2.6, 4, o({ c = "#B8C0C8", m = "Metal" }, "fine", { col = false }))
		end
		h.bp:light(0, y + 3, 0, "#FFD27A", 16, 0.8, "lamp")
		table.insert(out, h)
		-- the predecessors frozen behind the ice in the east and west walls
		Grotto.window(
			env,
			out,
			{ x = sx * 100, z = CZ, w = 14, h = 12, yaw = if sx > 0 then 270 else 90 },
			`Predecessors_{k}`,
			"fallen"
		)
	end
end

local function nest(env: Env, out: { Build })
	local b = Kit.build(env, "DragonNest", "landmark", 0, -112, 0)
	local y = Kit.gy(env, b, 0, 0)
	b.bp:add("ball", 18, 2, 12, 0, y + 0.4, 0, 0, 0, 0, o({ c = "#DCEFFA", m = "Ice" }, "detail", { col = false }))
	for m = 0, 9 do
		b.bp:add(
			"cyl",
			0.1,
			0.7,
			0.7,
			math.cos(m * 2.3) * 4,
			y + 1.2,
			math.sin(m * 2.3) * 3,
			0,
			0,
			90,
			o(GOLD, "fine", { col = false })
		)
	end
	b.bp:light(0, y + 20, 0, "#CFE0FF", 40, 1.3, "crystal")
	Kit.lifeAt(env.ctx, b, "snowBeam", 0, y + 40, 0, 9)
	Kit.lifeAt(env.ctx, b, "dustBeam", 0, y + 14, 0, 9)
	table.insert(out, b)
	-- icicles under the vault round the walls
	local v = Kit.build(env, "VaultIcicles", "traces", CX, CZ + 100, 0)
	for k = 0, 23 do
		local deg = k * 15
		if deg < 70 or deg > 110 then
			local x, z = at(104, deg)
			local top = env.T.ceiling(x, z)
			if top and top < 9000 then
				local len = 3 + (k % 3) * 2
				v.bp:add(
					"cyl",
					len,
					1.4,
					1.4,
					x - v.at.x,
					top - v.at.y - len / 2,
					z - v.at.z,
					0,
					0,
					90,
					o(ICE, "detail", { col = false })
				)
			end
		end
	end
	table.insert(out, v)
	Kit.life(env.ctx, "mist", CX, 0.5, CZ + 40, 30)
	Kit.life(env.ctx, "drips", CX, 44, CZ, 40)
end

function DragonLair.all(env: Env, out: { Build })
	braziers(env, out)
	crown(env, out)
	hoard(env, out)
	nest(env, out)
end

return DragonLair
