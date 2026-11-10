--!strict
-- What a skill cast from the bar aims at (Logic/SkillAim). Owner 2026-10-31: Blink never lands in the target. Owner
-- 2026-11-10: a tap aims at the enemy we fight by itself (the target, else the nearest enemy within reach, else in
-- front); holding the key (dragging the button) aims by hand; "Cast at cursor" is the old way. Review 2026-11-10: a
-- tapped Blink goes the way the player steers, else away from the enemy (never toward it), and a selected ally stays
-- selected.

local Config = require("../src/shared/Config")
local SkillAim = require("../src/shared/Logic/SkillAim")
local SkillData = require("../src/shared/Data/Skills")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local T = require("./Test")

type Case = { target: boolean?, nearest: boolean?, ally: boolean?, manual: boolean? }

local function tap(kind: string, mode: string?, case: Case?): SkillAim.Source
	local c: Case = case or {}
	return SkillAim.source({
		kind = kind,
		mode = mode,
		manual = c.manual == true,
		target = c.target == true,
		nearest = c.nearest == true,
		ally = c.ally,
	})
end

T.describe("Skill aim: tap or hold (owner 2026-11-10)", function()
	T.it("a key of a skill that aims waits for the release; others cast at once", function()
		for _, pair in { { "circleTarget", "point" }, { "cone", "none" }, { "line", "none" }, { "blink", "point" } } do
			T.expect(SkillAim.press(pair[1], pair[2], false, false)).toBe("wait")
		end
		-- the area of a circle around you and of a trap at your feet shows while held, too
		T.expect(SkillAim.press("circleSelf", "none", false, false)).toBe("wait")
		T.expect(SkillAim.press("trap", "none", false, false)).toBe("wait")
		-- skills on an enemy, buffs, Disengage (always back): at once
		T.expect(SkillAim.press("projectile", "enemy", false, false)).toBe("cast")
		T.expect(SkillAim.press("buff", "self", false, false)).toBe("cast")
		T.expect(SkillAim.press("blink", "none", false, false)).toBe("cast")
		-- a keyboard on a touch device: at once (a tap)
		T.expect(SkillAim.press("circleTarget", "point", true, false)).toBe("cast")
	end)
	T.it("a release shorter than the hold time is a tap, a longer one aims by hand", function()
		local hold = Config.Skills.holdToAim
		T.expect(hold > 0.1 and hold <= 0.3).toBe(true)
		T.expect(SkillAim.held(0.08, hold)).toBe(false)
		T.expect(SkillAim.held(hold - 0.01, hold)).toBe(false)
		T.expect(SkillAim.held(hold, hold)).toBe(true)
		T.expect(SkillAim.held(1.5, hold)).toBe(true)
	end)
	T.it("a held key or a dragged button aims where the player points", function()
		for _, pair in { { "circleTarget", "point" }, { "cone", "none" }, { "line", "none" }, { "blink", "point" } } do
			T.expect(tap(pair[1], pair[2], { manual = true, target = true })).toBe("manual")
		end
		-- a frost trap held: where its preview stood (as before)
		T.expect(tap("trap", "none", { manual = true })).toBe("manual")
	end)
	T.it('"Cast at cursor" casts on key press at the cursor (the old way)', function()
		T.expect(SkillAim.press("circleTarget", "point", false, true)).toBe("cursor")
		T.expect(SkillAim.press("cone", "none", false, true)).toBe("cursor")
		T.expect(SkillAim.press("blink", "point", false, true)).toBe("cursor")
		-- what does not aim: at once, without a point
		T.expect(SkillAim.press("circleSelf", "none", false, true)).toBe("cast")
		T.expect(SkillAim.press("projectile", "enemy", false, true)).toBe("cast")
		-- touch has no cursor: a tap
		T.expect(SkillAim.press("cone", "none", true, true)).toBe("cast")
	end)
end)

T.describe("Skill aim: a tap aims at the enemy we fight", function()
	T.it("circles on a point, snares, cones and lines: the target first", function()
		for _, pair in { { "circleTarget", "point" }, { "trap", "point" }, { "cone", "none" }, { "line", "none" } } do
			T.expect(tap(pair[1], pair[2], { target = true, nearest = true })).toBe("target")
			T.expect(tap(pair[1], pair[2], { nearest = true })).toBe("nearest")
			T.expect(tap(pair[1], pair[2], {})).toBe("front")
			T.expect(SkillAim.seeks(pair[1], pair[2])).toBe(true)
		end
	end)
	T.it("skills that do not aim stay as they are", function()
		for _, pair in { { "circleSelf", "none" }, { "buff", "self" }, { "trap", "none" }, { "projectile", "enemy" } } do
			T.expect(tap(pair[1], pair[2], { target = true, nearest = true })).toBe("none")
			T.expect(SkillAim.seeks(pair[1], pair[2])).toBe(false)
		end
	end)
	T.it(
		"a selected ally stays selected: a tapped damage area goes to the nearest enemy without taking its place",
		function()
			for _, pair in { { "circleTarget", "point" }, { "trap", "point" }, { "cone", "none" }, { "line", "none" } } do
				T.expect(tap(pair[1], pair[2], { ally = true, nearest = true })).toBe("nearby")
				-- nobody in reach: in front, as with nothing selected
				T.expect(tap(pair[1], pair[2], { ally = true })).toBe("front")
			end
			-- a healing field still goes under the ally, a banner still at our feet
			T.expect(tap("healZone", "point", { ally = true, nearest = true })).toBe("ally")
			T.expect(tap("banner", "point", { ally = true, nearest = true })).toBe("feet")
		end
	)
	T.it(
		"a skill on an enemy: the target, else the nearest enemy (the target only when nothing living is selected)",
		function()
			local function onEnemy(case: Case): SkillAim.Source
				return SkillAim.onEnemy({
					kind = "projectile",
					mode = "enemy",
					manual = false,
					target = case.target == true,
					nearest = case.nearest == true,
					ally = case.ally,
				})
			end
			T.expect(onEnemy({ target = true, nearest = true })).toBe("target")
			T.expect(onEnemy({ nearest = true })).toBe("nearest")
			T.expect(onEnemy({})).toBe("none")
			-- a selected ally: the nearest enemy for this cast only, else the ally as before (the server refuses it)
			T.expect(onEnemy({ ally = true, nearest = true })).toBe("nearby")
			T.expect(onEnemy({ ally = true })).toBe("ally")
		end
	)
	T.it("Blink goes the way SkillAim.escape picks, never into the target; Disengage keeps jumping back", function()
		T.expect(tap("blink", "point", { target = true })).toBe("escape")
		T.expect(tap("blink", "point", { nearest = true })).toBe("escape")
		T.expect(tap("blink", "point", {})).toBe("escape")
		T.expect(SkillAim.seeks("blink", "point")).toBe(false)
		T.expect(tap("blink", "none", { target = true })).toBe("none")
		T.expect(SkillAim.previews("blink", "none")).toBe(false)
		-- held: where the player points
		T.expect(SkillAim.previews("blink", "point")).toBe(true)
	end)
	T.it("a healing field under the selected ally or at your feet, a banner at the target or your feet", function()
		T.expect(tap("healZone", "point", { ally = true })).toBe("ally")
		T.expect(tap("healZone", "point", { target = true, nearest = true })).toBe("feet")
		T.expect(SkillAim.seeks("healZone", "point")).toBe(false)
		T.expect(tap("banner", "point", { target = true })).toBe("target")
		T.expect(tap("banner", "point", { nearest = true })).toBe("feet")
		T.expect(SkillAim.seeks("banner", "point")).toBe(false)
	end)
	T.it("the character turns to a skill on an enemy, a cone, a line and a circle on a point, not for Blink", function()
		T.expect(SkillAim.turns("projectile", "enemy")).toBe(true)
		T.expect(SkillAim.turns("cone", "none")).toBe(true)
		T.expect(SkillAim.turns("line", "none")).toBe(true)
		T.expect(SkillAim.turns("circleTarget", "point")).toBe(true)
		T.expect(SkillAim.turns("blink", "point")).toBe(false)
		T.expect(SkillAim.turns("circleSelf", "none")).toBe(false)
		T.expect(SkillAim.turns("heal", "ally")).toBe(false)
	end)
	T.it("the nearest enemy is looked for as far as the skill can hit", function()
		T.expect(SkillAim.reach("cone", nil, 10, nil)).toBe(11.5)
		T.expect(SkillAim.reach("line", nil, nil, 26)).toBe(27.5)
		T.expect(SkillAim.reach("circleTarget", 38, 8, nil)).toBe(47.5)
		-- every skill that looks has a reach beyond melee
		for _, def in SkillData.byId do
			if SkillAim.seeks(def.type, def.target) then
				T.expect(SkillAim.reach(def.type, def.range, def.radius, def.length) > 6).toBe(true)
			end
		end
	end)
	T.it("every skill that aims is known by its shape", function()
		-- a new aiming kind needs a rule in SkillAim (and a preview in SkillController.drawPreview)
		local known =
			{ circleTarget = true, trap = true, cone = true, line = true, blink = true, healZone = true, banner = true }
		for id, def in SkillData.byId do
			if SkillAim.aims(def.type, def.target) and not known[def.type] then
				error(`{id}: {def.type} aims, but SkillAim has no rule for it`)
			end
		end
	end)
end)

T.describe("Skill aim: a tapped Blink escapes (review 2026-11-10, owner 2026-10-31: never into the monster)", function()
	local MARGIN = Config.Skills.escapeMargin
	local JUMP = 15 -- Blink's length; 20 with the 5B breakpoint
	local NORTH = { x = 0, z = -1 } -- Roblox forward: -Z

	local function same(d: SkillAim.Flat, x: number, z: number)
		T.expect(d.x).toBeNear(x, 1e-6)
		T.expect(d.z).toBeNear(z, 1e-6)
	end

	local function escape(e: {
		steer: SkillAim.Flat?,
		facing: SkillAim.Flat?,
		length: number?,
		enemy: SkillAim.Flat?,
		nearest: SkillAim.Flat?,
		radius: number?,
	})
		return SkillAim.escape({
			steer = e.steer,
			facing = e.facing or NORTH,
			length = e.length or JUMP,
			enemy = e.enemy,
			nearest = e.nearest,
			radius = e.radius,
		})
	end

	T.it("an enemy that is not selected counts within the whole jump and a margin, to its body's edge", function()
		T.expect(MARGIN >= 2 and MARGIN <= 6).toBe(true)
		T.expect(SkillAim.escapeReach(15)).toBe(15 + MARGIN)
		-- the 5B breakpoint jumps 20: it reaches farther (review 2026-11-10: a fixed 15 landed it in a monster 18 ahead)
		T.expect(SkillAim.escapeReach(20)).toBe(20 + MARGIN)
		local blink = SkillData.get("blink") :: SkillData.SkillDef
		T.expect(blink.length).toBe(JUMP)
	end)
	T.it("standing with the enemy in front (the character faces its target): straight away from it", function()
		same(escape({ facing = NORTH, enemy = { x = 0, z = -10 } }), 0, 1)
		-- a melee monster right next to us, a ranged one far off: the same
		same(escape({ facing = NORTH, enemy = { x = 0, z = -2 } }), 0, 1)
		same(escape({ facing = NORTH, enemy = { x = 0, z = -33 } }), 0, 1)
		-- facing elsewhere does not matter: away from the enemy
		same(escape({ facing = { x = 1, z = 0 }, enemy = { x = 3, z = -4 } }), -0.6, 0.8)
	end)
	T.it("the player's own steering wins: that way", function()
		same(escape({ steer = { x = 1, z = 0 }, facing = NORTH, enemy = { x = 0, z = -10 } }), 1, 0)
		same(escape({ steer = { x = 0, z = 2 }, facing = NORTH }), 0, 1)
	end)
	T.it(
		"walking to the target by itself (MoveTo: the approach, Auto Hunt) is no steering: away, not toward",
		function()
			-- the approach and Auto Hunt walk the character with MoveTo: Humanoid.MoveDirection points at the target, but
			-- the player's move input is zero, so there is no steering and the character faces the target it walks to
			local steer = SkillAim.steering({ x = 0, z = 0 }, NORTH)
			T.expect(steer).toBeNil()
			local d = escape({ steer = steer, facing = NORTH, enemy = { x = 0, z = -12 } })
			same(d, 0, 1)
			T.expect(d.x * 0 + d.z * -12 < 0).toBe(true)
		end
	)
	T.it("no enemy selected: away from the nearest one close by, else straight ahead", function()
		same(escape({ facing = NORTH, nearest = { x = -5, z = 0 }, radius = 1 }), 1, 0)
		same(escape({ facing = NORTH, nearest = { x = 0, z = -(JUMP + MARGIN + 5) }, radius = 1 }), 0, -1)
		same(escape({ facing = { x = 1, z = 0 } }), 1, 0)
		-- the selected enemy first, even with another one nearer
		same(escape({ facing = NORTH, enemy = { x = 0, z = -20 }, nearest = { x = -2, z = 0 } }), 0, 1)
		-- an enemy standing in us: back, away from where we face
		same(escape({ facing = NORTH, enemy = { x = 0, z = 0 } }), 0, 1)
	end)
	T.it("5B (20 studs), nothing selected, an enemy 18 studs ahead: away, not onto it (review 2026-11-10)", function()
		same(escape({ facing = NORTH, length = 20, nearest = { x = 0, z = -18 }, radius = 1.5 }), 0, 1)
		-- the base jump and a monster 16 to 17 studs ahead: away too
		same(escape({ facing = NORTH, nearest = { x = 0, z = -17 }, radius = 1 }), 0, 1)
		-- a big boss: its centre 24 studs ahead, but its body reaches within 18
		same(escape({ facing = NORTH, nearest = { x = 0, z = -24 }, radius = 6 }), 0, 1)
	end)
	T.it("straight ahead never lands in a body: whatever enemy is not fled from stays the margin clear", function()
		for _, length in { 15, 20 } do
			for _, radius in { 0.5, 1.5, 3, 6 } do
				for x = -40, 40, 2 do
					for z = -40, 40, 2 do
						local d =
							escape({ facing = NORTH, length = length, nearest = { x = x, z = z }, radius = radius })
						-- where the jump lands, and how far that is from the enemy's body
						local clear = math.sqrt((d.x * length - x) ^ 2 + (d.z * length - z) ^ 2) - radius
						if d.z == -1 then
							T.expect(clear >= MARGIN).toBe(true)
						else
							-- fled: straight away, so never closer than where we stood
							T.expect(d.x * x + d.z * z <= 0).toBe(true)
						end
					end
				end
			end
		end
	end)
	T.it("never toward the selected enemy without the player's own steering", function()
		for angle = 0, 345, 15 do
			local a = math.rad(angle)
			local enemy = { x = math.sin(a) * 9, z = -math.cos(a) * 9 }
			for _, facing in { NORTH, { x = 1, z = 0 }, { x = enemy.x, z = enemy.z } } do
				local d = escape({ facing = facing, enemy = enemy })
				T.expect(d.x * enemy.x + d.z * enemy.z < 0).toBe(true)
			end
		end
	end)
	T.it("the own steering is the move input turned by the camera; a stick at rest steers nowhere", function()
		-- move input: x right, z back (W is z = -1), relative to the camera
		same(SkillAim.steering({ x = 0, z = -1 }, NORTH) :: SkillAim.Flat, 0, -1)
		same(SkillAim.steering({ x = 1, z = 0 }, NORTH) :: SkillAim.Flat, 1, 0)
		-- the camera looking along +X: W goes +X, D goes +Z
		same(SkillAim.steering({ x = 0, z = -1 }, { x = 1, z = 0 }) :: SkillAim.Flat, 1, 0)
		same(SkillAim.steering({ x = 1, z = 0 }, { x = 1, z = 0 }) :: SkillAim.Flat, 0, 1)
		-- W + D on keys (not normalised): diagonal, unit length
		local d = SkillAim.steering({ x = 1, z = -1 }, NORTH) :: SkillAim.Flat
		same(d, math.sqrt(0.5), -math.sqrt(0.5))
		T.expect(SkillAim.steering({ x = 0.05, z = 0 }, NORTH)).toBeNil()
		T.expect(SkillAim.steering({ x = 0, z = -1 }, { x = 0, z = 0 })).toBeNil()
	end)
end)

T.describe("Skill aim: texts", function()
	T.it("Blink says where it goes on a tap and that holding aims", function()
		for _, key in { "skill.blink.desc", "skill.blink.short" } do
			T.expect(string.find(pl[key], "dokąd idziesz", 1, true) ~= nil).toBe(true)
			T.expect(string.find(en[key], "moving", 1, true) ~= nil).toBe(true)
			T.expect(string.find(pl[key], "kursor", 1, true)).toBe(nil)
		end
		T.expect(string.find(pl["skill.blink.desc"], "rzytrzymaj", 1, true) ~= nil).toBe(true)
		T.expect(string.find(en["skill.blink.desc"], "Hold", 1, true) ~= nil).toBe(true)
		-- review 2026-11-10: standing, away from the enemy (no longer straight ahead, which in a fight is the monster)
		T.expect(string.find(pl["skill.blink.desc"], "od wroga", 1, true) ~= nil).toBe(true)
		T.expect(string.find(en["skill.blink.desc"], "away from the enemy", 1, true) ~= nil).toBe(true)
		T.expect(string.find(pl["skill.blink.desc"], "przed siebie", 1, true)).toBe(nil)
		T.expect(string.find(en["skill.blink.desc"], "straight ahead", 1, true)).toBe(nil)
	end)
	T.it('"Cast at cursor" and the tutorial say how aiming works, shortly', function()
		for _, texts in { pl, en } :: { { [string]: string } } do
			for _, key in { "menu.quickCast", "menu.quickCast.info", "tutorial.skill.pc", "tutorial.skill.touch" } do
				local text = texts[key]
				T.expect(text ~= nil).toBe(true)
				T.expect((utf8.len(text) or #text) <= 90).toBe(true)
				T.expect(string.find(text, "—", 1, true)).toBe(nil)
			end
		end
		T.expect(string.find(pl["menu.quickCast"], "kursor", 1, true) ~= nil).toBe(true)
		T.expect(string.find(en["menu.quickCast"], "cursor", 1, true) ~= nil).toBe(true)
	end)
end)
