--!strict
local PvpRules = require("../src/shared/Logic/PvpRules")
local T = require("./Test")

local ON = { pvpEnabled = true }
local OFF = { pvpEnabled = false }

T.describe("PvpRules.canAttack", function()
	-- zone, attacker, target -> allowed
	local cases: { { any } } = {
		{ "green", ON, ON, false },
		{ "green", OFF, OFF, false },
		{ "yellow", ON, ON, true },
		{ "yellow", ON, OFF, false },
		{ "yellow", OFF, ON, false },
		{ "yellow", OFF, OFF, false },
		{ "red", ON, ON, true },
		{ "red", OFF, OFF, true },
		{ "red", ON, OFF, true },
	}
	for _, case in cases do
		local zone, a, b, allowed = case[1], case[2], case[3], case[4]
		T.it(`{zone} {a.pvpEnabled}/{b.pvpEnabled} -> {allowed}`, function()
			T.expect((PvpRules.canAttack(a, b, { zone = zone }))).toBe(allowed)
		end)
	end

	T.it("party members are protected everywhere", function()
		for _, zone in { "green", "yellow", "red" } do
			local ok, reason = PvpRules.canAttack(ON, ON, { zone = zone :: any, sameParty = true })
			T.expect({ ok, reason }).toEqual({ false, "pvp.deny.party" })
		end
	end)

	T.it("guild members are protected unless protection is off", function()
		T.expect((PvpRules.canAttack(ON, ON, { zone = "red", sameGuild = true }))).toBe(false)
		T.expect((PvpRules.canAttack(ON, ON, { zone = "red", sameGuild = true, guildProtection = false }))).toBe(true)
	end)

	T.it("gives reasons", function()
		T.expect(select(2, PvpRules.canAttack(ON, ON, { zone = "green" }))).toBe("pvp.deny.safeZone")
		T.expect(select(2, PvpRules.canAttack(OFF, ON, { zone = "yellow" }))).toBe("pvp.deny.selfDisabled")
		T.expect(select(2, PvpRules.canAttack(ON, OFF, { zone = "yellow" }))).toBe("pvp.deny.targetDisabled")
	end)
end)

T.describe("PvpRules.canToggle", function()
	T.it("only in yellow zones", function()
		T.expect((PvpRules.canToggle("green", true, 100, nil, 15))).toBe(false)
		T.expect((PvpRules.canToggle("red", true, 100, nil, 15))).toBe(false)
		T.expect((PvpRules.canToggle("yellow", true, 100, nil, 15))).toBe(true)
	end)

	T.it("turning off is blocked shortly after PvP combat", function()
		T.expect((PvpRules.canToggle("yellow", false, 100, 90, 15))).toBe(false)
		T.expect((PvpRules.canToggle("yellow", false, 100, 80, 15))).toBe(true)
		T.expect((PvpRules.canToggle("yellow", true, 100, 99, 15))).toBe(true)
	end)

	T.it("toggle matters only in yellow", function()
		T.expect(PvpRules.toggleMatters("yellow")).toBe(true)
		T.expect(PvpRules.toggleMatters("red")).toBe(false)
	end)
end)

T.describe("PvP indicator", function()
	T.it("follows zone, countdown, lock and toggle", function()
		T.expect(PvpRules.indicator(false, "red", nil, nil, 0)).toBe("forced")
		T.expect(PvpRules.indicator(true, "yellow", false, nil, 0)).toBe("switching")
		T.expect(PvpRules.indicator(true, "green", nil, nil, 0)).toBe("locked")
		T.expect(PvpRules.indicator(true, "yellow", nil, 100, 50)).toBe("locked")
		T.expect(PvpRules.indicator(true, "yellow", nil, 100, 150)).toBe("on")
		T.expect(PvpRules.indicator(false, "yellow", nil, nil, 0)).toBe("off")
		T.expect(PvpRules.indicator(false, nil, nil, nil, 0)).toBe("off")
	end)
end)

return nil
