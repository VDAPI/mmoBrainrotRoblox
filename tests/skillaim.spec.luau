--!strict
-- What a skill cast from the bar aims at (Logic/SkillAim). Owner 2026-10-31: Blink never lands in the target. Owner
-- 2026-11-10: a tap aims at the enemy we fight by itself (the target, else the nearest enemy within reach, else in
-- front); holding the key (dragging the button) aims by hand; "Cast at cursor" is the old way.

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
	T.it("Blink goes the way you move, never into the target; Disengage keeps jumping back", function()
		T.expect(tap("blink", "point", { target = true })).toBe("move")
		T.expect(tap("blink", "point", { nearest = true })).toBe("move")
		T.expect(tap("blink", "point", {})).toBe("move")
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

T.describe("Skill aim: texts", function()
	T.it("Blink says where it goes on a tap and that holding aims", function()
		for _, key in { "skill.blink.desc", "skill.blink.short" } do
			T.expect(string.find(pl[key], "dokąd idziesz", 1, true) ~= nil).toBe(true)
			T.expect(string.find(en[key], "moving", 1, true) ~= nil).toBe(true)
			T.expect(string.find(pl[key], "kursor", 1, true)).toBe(nil)
		end
		T.expect(string.find(pl["skill.blink.desc"], "rzytrzymaj", 1, true) ~= nil).toBe(true)
		T.expect(string.find(en["skill.blink.desc"], "Hold", 1, true) ~= nil).toBe(true)
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
