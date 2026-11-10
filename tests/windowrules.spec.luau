--!strict
-- S29: which windows close together (Logic/WindowRules). UI package C (owner 2026-11-10: "things covering each
-- other"): on a touch screen a service and its backpack swap places from their title bars (partner); both stay open,
-- and Esc and the one-main-window rule work as before.

local Test = require("./Test")
local WindowRules = require("../src/shared/Logic/WindowRules")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function opened(...: string): WindowRules.State
	local state = WindowRules.new()
	for _, id in { ... } do
		WindowRules.onOpen(state, id)
	end
	return state
end

describe("WindowRules.onOpen", function()
	it("opens a service with the companion backpack", function()
		local state = WindowRules.new()
		local plan = WindowRules.onOpen(state, "shop")
		expect(plan.open).toEqual({ "inventory", "shop" })
		expect(state.inventoryByCompanion).toBe(true)
	end)

	it("redirects the backpack to the character window without a service", function()
		local state = WindowRules.new()
		local plan = WindowRules.onOpen(state, "inventory")
		expect(plan.open).toEqual({ "character" })
		expect(plan.focus).toBe("backpack")
		expect(WindowRules.onOpen(WindowRules.new(), "character").focus).toBe("stats")
	end)

	it("keeps the backpack as a companion while a service is open", function()
		local state = opened("shop")
		local target = WindowRules.resolve(state, "inventory")
		expect(target).toBe("inventory")
	end)

	it("closes everything for an exclusive window", function()
		local state = opened("shop")
		local plan = WindowRules.onOpen(state, "skills")
		table.sort(plan.close)
		expect(plan.close).toEqual({ "inventory", "shop" })
		expect(state.open).toEqual({ "skills" })
	end)

	it("closes the character window when a service opens", function()
		local state = opened("character")
		local plan = WindowRules.onOpen(state, "blacksmith")
		expect(plan.close).toEqual({ "character" })
		expect(plan.open).toEqual({ "inventory", "blacksmith" })
	end)

	it("opens the vault without the companion backpack (it has its own grid)", function()
		local state = opened("shop")
		local plan = WindowRules.onOpen(state, "deposit")
		table.sort(plan.close)
		expect(plan.close).toEqual({ "inventory", "shop" })
		expect(plan.open).toEqual({ "deposit" })
		expect(WindowRules.resolve(state, "inventory")).toBe("character")
	end)

	it("replaces one NPC service with another but keeps the backpack", function()
		local state = opened("shop")
		local plan = WindowRules.onOpen(state, "alchemy")
		expect(plan.close).toEqual({ "shop" })
		expect(plan.open).toEqual({ "alchemy" })
		expect(state.inventoryByCompanion).toBe(true)
	end)
end)

describe("WindowRules.onClose", function()
	it("closes the companion backpack with the service (✕)", function()
		local state = opened("shop")
		expect(WindowRules.onClose(state, "shop")).toEqual({ "shop", "inventory" })
		expect(#state.open).toBe(0)
	end)

	it("closes the companion backpack with the service (Esc)", function()
		local state = opened("blacksmith")
		expect(WindowRules.onEscape(state)).toEqual({ "blacksmith", "inventory" })
	end)

	it("Esc with the companion backpack in front still closes both", function()
		local state = opened("shop")
		WindowRules.onFocus(state, "inventory")
		expect(WindowRules.onEscape(state)).toEqual({ "shop", "inventory" })
	end)

	it("closes the companion backpack when walking away", function()
		local state = opened("alchemy")
		local closed = WindowRules.onCloseMany(state, { "npc", "questnpc", "shop", "alchemy", "mail" })
		expect(closed).toEqual({ "alchemy", "inventory" })
	end)

	it("✕ on the companion backpack closes only the backpack", function()
		local state = opened("shop")
		expect(WindowRules.onClose(state, "inventory")).toEqual({ "inventory" })
		expect(state.open).toEqual({ "shop" })
		expect(WindowRules.onClose(state, "shop")).toEqual({ "shop" })
	end)

	it("keeps a backpack the player opened himself next to the service", function()
		local state = opened("shop")
		WindowRules.onClose(state, "inventory")
		WindowRules.onOpen(state, "inventory")
		expect(state.inventoryByCompanion).toBe(false)
		expect(WindowRules.onClose(state, "shop")).toEqual({ "shop" })
		expect(state.open).toEqual({ "inventory" })
	end)

	it("keeps the backpack when the character window was open before the service", function()
		local state = opened("character", "shop")
		expect(WindowRules.onClose(state, "shop")).toEqual({ "shop" })
		expect(state.open).toEqual({ "inventory" })
	end)

	it("with trade and mail the backpack goes only with the last service", function()
		local state = opened("trade", "mail")
		expect(WindowRules.isOpen(state, "trade")).toBe(true)
		expect(WindowRules.onClose(state, "mail")).toEqual({ "mail" })
		expect(WindowRules.onClose(state, "trade")).toEqual({ "trade", "inventory" })
	end)

	it("a trade starting next to a service keeps both", function()
		local state = opened("shop", "trade")
		expect(WindowRules.isOpen(state, "shop")).toBe(true)
		expect(WindowRules.onClose(state, "trade")).toEqual({ "trade" })
		expect(WindowRules.onEscape(state)).toEqual({ "shop", "inventory" })
	end)

	it("death / map change closes every service and the backpack", function()
		local state = opened("trade", "mail")
		local closed = WindowRules.onCloseMany(state, WindowRules.openServices(state))
		expect(closed).toEqual({ "trade", "mail", "inventory" })
		expect(#state.open).toBe(0)
	end)

	it("ignores windows that are not open", function()
		local state = WindowRules.new()
		expect(WindowRules.onClose(state, "shop")).toEqual({})
		expect(WindowRules.onEscape(state)).toEqual({})
	end)
end)

describe("WindowRules.partner (the phone's switch, UI package C)", function()
	it("swaps every service and its backpack, both stay open", function()
		for id in WindowRules.SERVICES do
			if not WindowRules.bringsBackpack(id) then
				continue
			end
			local state = opened(id)
			expect(WindowRules.partner(state, id)).toBe("inventory")
			expect(WindowRules.partner(state, "inventory")).toBe(id)
			-- the switch opens the partner, which only brings it to the front
			local plan = WindowRules.onOpen(state, "inventory")
			expect(#plan.open + #plan.close).toBe(0)
			expect(state.open).toEqual({ id, "inventory" })
			plan = WindowRules.onOpen(state, id)
			expect(#plan.open + #plan.close).toBe(0)
			expect(state.open).toEqual({ "inventory", id })
			expect(state.inventoryByCompanion).toBe(true)
			-- Esc still closes both in one press
			expect(WindowRules.onEscape(state)).toEqual({ id, "inventory" })
		end
	end)

	it("offers the backpack again after its ✕, and the backpack the service on top", function()
		local state = opened("shop")
		WindowRules.onClose(state, "inventory")
		expect(WindowRules.partner(state, "shop")).toBe("inventory")
		WindowRules.onOpen(state, WindowRules.partner(state, "shop") :: string)
		expect(state.open).toEqual({ "shop", "inventory" })
		-- a trade over the shop: the backpack goes back to the trade
		WindowRules.onOpen(state, "trade")
		expect(WindowRules.partner(state, "inventory")).toBe("trade")
	end)

	it("none for the vault, other windows, closed ones and a backpack left without a service", function()
		expect(WindowRules.partner(opened("deposit"), "deposit")).toBe(nil)
		expect(WindowRules.partner(opened("skills"), "skills")).toBe(nil)
		expect(WindowRules.partner(WindowRules.new(), "shop")).toBe(nil)
		expect(WindowRules.partner(opened("shop"), "trade")).toBe(nil)
		-- the player's own backpack stays after the last service closes, with nothing to go back to
		local state = opened("character", "shop")
		WindowRules.onClose(state, "shop")
		expect(state.open).toEqual({ "inventory" })
		expect(WindowRules.partner(state, "inventory")).toBe(nil)
	end)
end)
