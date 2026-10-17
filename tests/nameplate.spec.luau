--!strict
-- S135: what a player's nameplate shows (Logic/Nameplate): name colour roles by priority, the title only with a
-- definition, the guild tag, the HP bar while hurt, and only the name beyond the detail distance.

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
		expect(v.swords).toBe(true)
		expect(v.showVip).toBe(true)
		expect(Nameplate.view(input({ hostile = true, isLocal = true })).nameRole).toBe("hostile")
	end)

	it("own, VIP and plain names", function()
		expect(Nameplate.view(input({ isLocal = true, vip = true })).nameRole).toBe("own")
		expect(Nameplate.view(input({ vip = true })).nameRole).toBe("vip")
		expect(Nameplate.view(input({})).nameRole).toBe("text")
		expect(Nameplate.view(input({})).swords).toBe(false)
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

	it("only the name beyond the detail distance; your own plate always in full", function()
		local far = Config.Nameplate.detailDistance + 1
		local v = Nameplate.view(input({ distance = far, titleHex = "#E8C25A", hurt = true, guildTag = "VLT" }))
		expect(v.showTitle).toBe(false)
		expect(v.showLevel).toBe(false)
		expect(v.showHp).toBe(false)
		expect(v.guildTag).toBe("VLT")
		local own = Nameplate.view(input({ isLocal = true, distance = far, hurt = true }))
		expect(own.showLevel).toBe(true)
		expect(own.showHp).toBe(true)
		local near = Nameplate.view(input({ distance = Config.Nameplate.detailDistance, hurt = true }))
		expect(near.showLevel).toBe(true)
		expect(near.showHp).toBe(true)
	end)

	it("other players' names open the menu, your own does not", function()
		expect(Nameplate.view(input({})).clickable).toBe(true)
		expect(Nameplate.view(input({ isLocal = true })).clickable).toBe(false)
	end)

	it("reaches further than the detail distance", function()
		expect(Config.Nameplate.maxDistance > Config.Nameplate.detailDistance).toBe(true)
		expect(Config.Nameplate.maxDistance >= 150).toBe(true)
	end)
end)
