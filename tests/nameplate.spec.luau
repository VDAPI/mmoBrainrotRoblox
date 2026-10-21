--!strict
-- S135: what a player's nameplate shows (Logic/Nameplate): name colour roles by priority, the title only with a
-- definition, the guild tag, the HP bar while hurt, and only the name beyond the detail distance. W28: the size factor
-- by camera distance (Nameplate.scale).

local Config = require("../src/shared/Config")
local Nameplate = require("../src/shared/Logic/Nameplate")
local T = require("./Test")

local describe, it, expect = T.describe, T.it, T.expect

local function input(over: { [string]: any }): Nameplate.Input
	local base: { [string]: any } = {
		isLocal = false,
		hostile = false,
		vip = false,
		titleHex = nil,
		guildTag = nil,
		hurt = false,
		distance = 10,
	}
	for k, v in over do
		base[k] = v
	end
	return base :: any
end

describe("Nameplate view (S135)", function()
	it("an enemy wins over VIP and your own plate", function()
		local v = Nameplate.view(input({ hostile = true, vip = true }))
		expect(v.nameRole).toBe("hostile")
		expect(Nameplate.view(input({ hostile = true, isLocal = true })).nameRole).toBe("hostile")
	end)

	it("own, VIP and plain names", function()
		expect(Nameplate.view(input({ isLocal = true, vip = true })).nameRole).toBe("own")
		expect(Nameplate.view(input({ vip = true })).nameRole).toBe("vip")
		expect(Nameplate.view(input({})).nameRole).toBe("text")
	end)

	it("shows a title only with its definition", function()
		expect(Nameplate.view(input({})).showTitle).toBe(false)
		local v = Nameplate.view(input({ titleHex = "#E8C25A" }))
		expect(v.showTitle).toBe(true)
		expect(v.titleHex).toBe("#E8C25A")
	end)

	it("keeps the guild tag, drops an empty one", function()
		expect(Nameplate.view(input({ guildTag = "VLT" })).guildTag).toBe("VLT")
		expect(Nameplate.view(input({ guildTag = "" })).guildTag).toBeNil()
	end)

	it("only the name beyond the detail distance; your own title always, never your own HP bar (W28)", function()
		local far = Config.Nameplate.detailDistance + 1
		local v = Nameplate.view(input({ distance = far, titleHex = "#E8C25A", hurt = true, guildTag = "VLT" }))
		expect(v.showTitle).toBe(false)
		expect(v.showHp).toBe(false)
		expect(v.guildTag).toBe("VLT")
		local own = Nameplate.view(input({ isLocal = true, distance = far, hurt = true, titleHex = "#E8C25A" }))
		expect(own.showTitle).toBe(true)
		expect(own.showHp).toBe(false)
		local near = Nameplate.view(input({ distance = Config.Nameplate.detailDistance, hurt = true }))
		expect(near.showHp).toBe(true)
	end)

	it("other players' names open the menu, your own does not", function()
		expect(Nameplate.view(input({})).clickable).toBe(true)
		expect(Nameplate.view(input({ isLocal = true })).clickable).toBe(false)
	end)

	it("shows the level and the VIP tag on every plate at any distance (owner 2026-10-21)", function()
		local far = Config.Nameplate.detailDistance + 50
		local v = Nameplate.view(input({ level = 37, vip = true, distance = far }))
		expect(v.level).toBe(37)
		expect(v.showVip).toBe(true)
		local own = Nameplate.view(input({ isLocal = true, level = 12.6, vip = true }))
		expect(own.level).toBe(12)
		expect(own.showVip).toBe(true)
		expect(Nameplate.view(input({ hostile = true, vip = true })).showVip).toBe(true)
		expect(Nameplate.view(input({})).showVip).toBe(false)
		expect(Nameplate.view(input({})).level).toBeNil()
		expect(Nameplate.view(input({ level = 0 })).level).toBeNil()
		expect(Nameplate.view(input({ level = 0 / 0 })).level).toBeNil()
	end)

	it("reaches further than the detail distance", function()
		expect(Config.Nameplate.maxDistance > Config.Nameplate.detailDistance).toBe(true)
		expect(Config.Nameplate.maxDistance >= 150).toBe(true)
	end)
end)

describe("Monster and NPC plates (S136)", function()
	local function monster(over: { [string]: any }): Nameplate.MonsterInput
		local base: { [string]: any } = { variant = "normal", returning = false, targeted = false, groupSize = nil }
		for k, v in over do
			base[k] = v
		end
		return base :: any
	end

	it("colours the name by variant, unknown variants as normal", function()
		expect(Nameplate.monster(monster({})).nameRole).toBe("normal")
		expect(Nameplate.monster(monster({ variant = "elite" })).nameRole).toBe("elite")
		expect(Nameplate.monster(monster({ variant = "elite2" })).nameRole).toBe("elite2")
		expect(Nameplate.monster(monster({ variant = "boss" })).nameRole).toBe("boss")
		expect(Nameplate.monster(monster({ variant = "weird" })).nameRole).toBe("normal")
		expect(Nameplate.monster(monster({ variant = nil })).nameRole).toBe("normal")
	end)

	it("shows the group badge only for two or more", function()
		expect(Nameplate.monster(monster({})).groupSize).toBeNil()
		expect(Nameplate.monster(monster({ groupSize = 1 })).groupSize).toBeNil()
		expect(Nameplate.monster(monster({ groupSize = 3 })).groupSize).toBe(3)
	end)

	it("HP numbers and the wide bar only on the selected target; the return mark follows the monster", function()
		local plain = Nameplate.monster(monster({}))
		expect(plain.showHpNumbers).toBe(false)
		expect(plain.wideBar).toBe(false)
		local target = Nameplate.monster(monster({ targeted = true, returning = true }))
		expect(target.showHpNumbers).toBe(true)
		expect(target.wideBar).toBe(true)
		expect(target.returning).toBe(true)
	end)

	it("NPC plates: the service glyph without companions, the tag only on your own companion", function()
		local npc = Nameplate.npc({ icon = "⚒", companion = false, mine = false })
		expect(npc.showIcon).toBe(true)
		expect(npc.showTag).toBe(false)
		expect(npc.nameRole).toBe("text")
		expect(Nameplate.npc({ icon = "", companion = false, mine = false }).showIcon).toBe(false)
		expect(Nameplate.npc({ icon = nil, companion = true, mine = true }).showTag).toBe(true)
		expect(Nameplate.npc({ icon = nil, companion = true, mine = false }).showTag).toBe(false)
		expect(Nameplate.npc({ icon = "⚒", companion = true, mine = true }).showIcon).toBe(false)
	end)
end)

describe("Nameplate scale (W28)", function()
	local cfg = { scaleNear = 20, scaleFar = 120, scaleMin = 0.7, scaleStep = 0.05 }

	it("never grows past 1 up close; 1 for an unknown distance", function()
		expect(Nameplate.scale(0, cfg)).toBe(1)
		expect(Nameplate.scale(20, cfg)).toBe(1)
		expect(Nameplate.scale(nil, cfg)).toBe(1)
	end)

	it("shrinks with distance down to the minimum", function()
		local mid = Nameplate.scale(70, cfg)
		expect(mid < 1).toBe(true)
		expect(mid > 0.7).toBe(true)
		expect(math.abs(mid - 0.85) < 1e-6).toBe(true)
		expect(math.abs(Nameplate.scale(120, cfg) - 0.7) < 1e-6).toBe(true)
		expect(math.abs(Nameplate.scale(5000, cfg) - 0.7) < 1e-6).toBe(true)
	end)

	it("is monotonic and moves in steps", function()
		local last = 2
		for d = 0, 200, 3 do
			local s = Nameplate.scale(d, cfg)
			expect(s <= last).toBe(true)
			local steps = s / cfg.scaleStep
			expect(math.abs(steps - math.floor(steps + 0.5)) < 1e-6).toBe(true)
			last = s
		end
	end)

	it("the game config is sane", function()
		local c = Config.Nameplate
		expect(c.scaleMin > 0 and c.scaleMin < 1).toBe(true)
		expect(c.scaleFar > c.scaleNear).toBe(true)
		expect(math.abs(Nameplate.scale(c.maxDistance) - c.scaleMin) < 1e-6).toBe(true)
	end)
end)
