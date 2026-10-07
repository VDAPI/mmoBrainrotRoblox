--!strict
local AccountSchema = require("../src/shared/Logic/AccountSchema")
local DamageNumbers = require("../src/shared/Data/DamageNumbers")
local DamageText = require("../src/shared/Logic/DamageText")
local Locale = require("../src/shared/Util/Locale")
local T = require("./Test")

local ME = "p1"
local MOB = "m7"

T.describe("DamageText.format", function()
	T.it("a critical hit says KRYT! / CRIT! with the grouped amount", function()
		local pl = DamageText.format({ k = "dmg", e = MOB, s = ME, a = 1234, c = true }, ME, "pl")
		T.expect(pl.text).toBe("KRYT! 1 234")
		T.expect(pl.style).toBe("mineCrit")
		T.expect(pl.crit).toBe(true)
		local en = DamageText.format({ k = "dmg", e = MOB, s = ME, a = 1234, c = true }, ME, "en")
		T.expect(en.text).toBe("CRIT! 1 234")
	end)

	T.it("absorbed, immune and dodge use their Locale texts in both languages", function()
		for _, lang in { "pl", "en" } do
			local ab = DamageText.format({ k = "dmg", e = ME, s = MOB, a = 0, ab = true }, ME, lang)
			T.expect(ab.style).toBe("absorbed")
			T.expect(ab.text).toBe(`{DamageText.SHIELD_ICON} {Locale.T("combat.absorbed", nil, lang)}`)
			local im = DamageText.format({ k = "dmg", e = MOB, s = ME, a = 0, im = true }, ME, lang)
			T.expect(im.style).toBe("immune")
			T.expect(im.text).toBe(Locale.T("combat.immune", nil, lang))
			local d = DamageText.format({ k = "dmg", e = MOB, s = ME, a = 0, d = true }, ME, lang)
			T.expect(d.style).toBe("dodge")
			T.expect(d.text).toBe(Locale.T("combat.dodge", nil, lang))
			T.expect(Locale.has("combat.absorbed", lang)).toBe(true)
			T.expect(Locale.has("combat.immune", lang)).toBe(true)
			T.expect(Locale.has("combat.crit", lang)).toBe(true)
		end
		T.expect(Locale.T("combat.absorbed", nil, "pl")).toBe("Pochłonięto")
		T.expect(Locale.T("combat.immune", nil, "pl")).toBe("Odporny")
		T.expect(Locale.T("combat.dodge", nil, "pl")).toBe("Unik")
	end)

	T.it("my hits, others' hits and hits on me have different styles", function()
		local mine = DamageText.format({ k = "dmg", e = MOB, s = ME, a = 50 }, ME, "en")
		local other = DamageText.format({ k = "dmg", e = MOB, s = "p2", a = 50 }, ME, "en")
		local received = DamageText.format({ k = "dmg", e = ME, s = MOB, a = 50 }, ME, "en")
		T.expect(mine.style).toBe("mine")
		T.expect(other.style).toBe("other")
		T.expect(received.style).toBe("received")
		T.expect(mine.text).toBe("50")
		-- Others' numbers are smaller and dimmer.
		local styles = DamageNumbers.styles
		T.expect(styles.other.size < styles.mine.size).toBe(true)
		T.expect((styles.other.dim or 0) > 0).toBe(true)
		T.expect(styles.mineCrit.size > styles.mine.size).toBe(true)
		T.expect(styles.mineCrit.pop).toBe(1.4)
		-- A crit on me is red and says KRYT! too.
		local rc = DamageText.format({ k = "dmg", e = ME, s = MOB, a = 80, c = true }, ME, "pl")
		T.expect(rc.style).toBe("receivedCrit")
		T.expect(rc.text).toBe("KRYT! 80")
		-- The S28 attacker field still counts as the attacker.
		T.expect(DamageText.format({ k = "dmg", e = MOB, by = ME, a = 5 }, ME, "en").style).toBe("mine")
	end)

	T.it("heals and DoT ticks", function()
		local heal = DamageText.format({ k = "heal", e = ME, a = 123 }, ME, "en")
		T.expect(heal.text).toBe("+123")
		T.expect(heal.style).toBe("heal")
		T.expect(DamageText.format({ k = "heal", e = ME, a = 9, hot = true }, ME, "en").style).toBe("hot")
		local dot = DamageText.format({ k = "dmg", e = MOB, s = ME, a = 12, dot = true, el = "fire" }, ME, "en")
		T.expect(dot.style).toBe("dot")
		T.expect(dot.element).toBe("fire")
		T.expect(DamageText.dotElement("burn")).toBe("fire")
		T.expect(DamageText.dotElement("poison")).toBe("poison")
		T.expect(DamageText.sumText("heal", 40)).toBe("+40")
		T.expect(DamageText.sumText("mine", 1500)).toBe("1 500")
	end)

	T.it("a = 0 without flags (or junk) does not throw and draws nothing", function()
		T.expect(DamageText.format({ k = "dmg", e = MOB, a = 0 }, ME, "en").style).toBe("none")
		T.expect(DamageText.format({ k = "dmg" }, nil, "en").style).toBe("none")
		T.expect(DamageText.format({ k = "dmg", e = MOB, a = "x" :: any }, ME).style).toBe("none")
		T.expect(DamageText.format({ k = "heal", e = ME, a = 0 }, ME).style).toBe("none")
	end)
end)

T.describe("DamageText settings", function()
	T.it("mode falls back to the old switch", function()
		T.expect(DamageText.mode(nil)).toBe("all")
		T.expect(DamageText.mode({ dmgNumbers = false })).toBe("off")
		T.expect(DamageText.mode({ dmgNumbers = true })).toBe("all")
		T.expect(DamageText.mode({ dmgMode = "mine", dmgNumbers = false })).toBe("mine")
		T.expect(DamageText.mode({ dmgMode = "weird" })).toBe("all")
	end)

	T.it("visible filters by mode", function()
		local mine = { k = "dmg", e = MOB, s = ME, a = 1 }
		local onMe = { k = "dmg", e = ME, s = MOB, a = 1 }
		local others = { k = "dmg", e = MOB, s = "p2", a = 1 }
		T.expect(DamageText.visible(others, ME, "all")).toBe(true)
		T.expect(DamageText.visible(others, ME, "mine")).toBe(false)
		T.expect(DamageText.visible(mine, ME, "mine")).toBe(true)
		T.expect(DamageText.visible(onMe, ME, "mine")).toBe(true)
		T.expect(DamageText.visible(mine, ME, "off")).toBe(false)
	end)

	T.it("an old save with dmgNumbers = false reads as off, a new account as all", function()
		local old: any = { schema = 1, characters = {}, settings = { dmgNumbers = false } }
		AccountSchema.migrate(old)
		T.expect(DamageText.mode(old.settings)).toBe("off")
		T.expect(DamageText.mode(AccountSchema.accountTemplate().settings :: any)).toBe("all")
	end)
end)

T.describe("DamageText stacking", function()
	T.it("numbers of one target take rising slots and free them after their lifetime", function()
		local stack = DamageText.newStack()
		local a = stack:add(MOB, 0, "mine", 10)
		local b = stack:add(MOB, 0.1, "mine", 10)
		local c = stack:add("m8", 0.1, "mine", 10)
		T.expect(a.action).toBe("new")
		T.expect(a.slot).toBe(0)
		T.expect(b.slot).toBe(1)
		T.expect(c.slot).toBe(0)
		local later = stack:add(MOB, DamageNumbers.lifetime + 0.2, "mine", 10)
		T.expect(later.slot).toBe(0)
	end)

	T.it("at most maxPerTarget fly at once (the oldest gives way)", function()
		local stack = DamageText.newStack()
		local first = stack:add(MOB, 0, "mineCrit", 1)
		for i = 2, DamageNumbers.maxPerTarget do
			stack:add(MOB, i * 0.1, "mineCrit", 1)
		end
		T.expect(stack:count(MOB, 1.1)).toBe(DamageNumbers.maxPerTarget)
		local extra = stack:add(MOB, 1.15, "mineCrit", 1)
		T.expect(extra.evict).toBe(first.id)
		T.expect(extra.slot).toBe(first.slot)
		T.expect(stack:count(MOB, 1.15)).toBe(DamageNumbers.maxPerTarget)
	end)

	T.it("more than mergeRate hits per second merge into a sum", function()
		local stack = DamageText.newStack()
		local merged = 0
		local last
		for i = 1, 14 do
			last = stack:add(MOB, i * 0.05, "mine", 5)
			if last.action == "merge" then
				merged += 1
			end
		end
		T.expect(merged > 0).toBe(true)
		T.expect(stack:count(MOB, 0.75) <= DamageNumbers.maxPerTarget).toBe(true)
		-- Crits never merge.
		T.expect(stack:add(MOB, 0.75, "mineCrit", 5).action).toBe("new")
		-- The sum of everything shown equals the damage dealt: the merged one carries its hits.
		T.expect(last.sum >= 10).toBe(true)
	end)

	T.it("release frees the slot", function()
		local stack = DamageText.newStack()
		local a = stack:add(MOB, 0, "mine", 1)
		stack:release(MOB, a.id)
		T.expect(stack:count(MOB, 0)).toBe(0)
		T.expect(stack:add(MOB, 0.01, "mine", 1).slot).toBe(0)
	end)
end)
