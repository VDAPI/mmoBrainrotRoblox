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

T.describe("PvpRules.hostile: the client's enemy test (review 2026-11-10)", function()
	type Case = {
		zone: string?,
		pvp: boolean?,
		mine: boolean?,
		party: boolean?,
		guild: boolean?,
		protection: boolean?,
		myDuel: string?,
		duel: string?,
		mySide: number?,
		side: number?,
	}
	local function hostile(c: Case): boolean
		return PvpRules.hostile({
			zone = c.zone,
			pvpEnabled = c.pvp == true,
			myPvp = c.mine == true,
			sameParty = c.party,
			sameGuild = c.guild,
			guildProtection = c.protection,
			myDuel = c.myDuel,
			duel = c.duel,
			mySide = c.mySide,
			side = c.side,
		})
	end

	T.it("a party member is never an enemy: red zone, Blood Moon, PvP on", function()
		T.expect(hostile({ zone = "red", party = true })).toBe(false)
		T.expect(hostile({ zone = "red", pvp = true, mine = true, party = true })).toBe(false)
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true, party = true })).toBe(false)
		-- a stranger there is
		T.expect(hostile({ zone = "red" })).toBe(true)
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true })).toBe(true)
	end)
	T.it("a guild member only while the guild protects its members", function()
		T.expect(hostile({ zone = "red", guild = true })).toBe(false)
		T.expect(hostile({ zone = "red", guild = true, protection = true })).toBe(false)
		T.expect(hostile({ zone = "red", guild = true, protection = false })).toBe(true)
	end)
	T.it("the zone of the target and both flags, as the server counts them", function()
		-- a yellow zone needs our PvP on too; a green zone never, whatever their flag says
		T.expect(hostile({ zone = "yellow", pvp = true, mine = false })).toBe(false)
		T.expect(hostile({ zone = "yellow", pvp = false, mine = true })).toBe(false)
		T.expect(hostile({ zone = "green", pvp = true, mine = true })).toBe(false)
		-- a zone not known yet is green, as on the server
		T.expect(hostile({ zone = nil, pvp = true, mine = true })).toBe(false)
	end)
	-- the arena sand is a yellow zone where everyone counts as PvP on (PvpService.InArena): zone "yellow", both flags on
	T.it("our duel is fought whatever party or guild (the server's duel rule comes first)", function()
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true, party = true, myDuel = "d3", duel = "d3" }))
			.toBe(true)
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true, guild = true, myDuel = "d3", duel = "d3" }))
			.toBe(true)
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true, myDuel = "d3", duel = "d3" })).toBe(true)
	end)
	T.it("nobody else touches a duelist, and a duelist touches nobody else", function()
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true, duel = "d3" })).toBe(false)
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true, myDuel = "d3" })).toBe(false)
		T.expect(hostile({ zone = "red", duel = "d3" })).toBe(false)
	end)
	T.it("on an idle sand party and guild still protect, a stranger may be hit (review 2026-11-10)", function()
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true, party = true })).toBe(false)
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true, guild = true })).toBe(false)
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true, guild = true, protection = false })).toBe(true)
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true })).toBe(true)
		-- someone off the sand, in the green city around it
		T.expect(hostile({ zone = "green", pvp = false, mine = true })).toBe(false)
	end)
	T.it("in an arena match only the other side, whatever party, guild or flags", function()
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true, party = true, mySide = 1, side = 2 })).toBe(true)
		T.expect(hostile({ zone = "yellow", pvp = true, mine = true, mySide = 1, side = 1 })).toBe(false)
		-- not a fighter of our match (a spectator): nobody we may hit
		T.expect(hostile({ zone = "red", mySide = 1, side = 0 })).toBe(false)
		T.expect(hostile({ zone = "red", mySide = 2 })).toBe(false)
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

	T.it("the HUD toggle shows only in yellow and red zones or while a switch counts down (UI plan phase 1)", function()
		T.expect(PvpRules.toggleShown("yellow", nil)).toBe(true)
		T.expect(PvpRules.toggleShown("red", nil)).toBe(true)
		T.expect(PvpRules.toggleShown("green", nil)).toBe(false)
		T.expect(PvpRules.toggleShown(nil, nil)).toBe(false)
		-- a countdown started in a yellow zone stays visible after a step into a green one
		T.expect(PvpRules.toggleShown("green", true)).toBe(true)
		T.expect(PvpRules.toggleShown("green", false)).toBe(true)
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

T.describe("PvpRules.inPvpCombat (S61)", function()
	T.it("10 s after the last player hit", function()
		T.expect(PvpRules.inPvpCombat(100, nil, 10)).toBe(false)
		T.expect(PvpRules.inPvpCombat(105, 100, 10)).toBe(true)
		T.expect(PvpRules.inPvpCombat(110.5, 100, 10)).toBe(false)
	end)
end)

return nil
