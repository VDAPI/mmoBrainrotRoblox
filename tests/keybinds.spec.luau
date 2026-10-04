--!strict
local KeybindData = require("../src/shared/Data/Keybinds")
local Keybinds = require("../src/shared/Logic/Keybinds")
local T = require("./Test")

local function noDuplicates(overrides: any): boolean
	local seen = {}
	for _, def in KeybindData.actions do
		local key = Keybinds.key(overrides, def.id)
		if seen[key] then
			return false
		end
		seen[key] = true
	end
	return true
end

T.describe("Keybinds", function()
	T.it("defaults are allowed and unique", function()
		for _, def in KeybindData.actions do
			T.expect(KeybindData.allowed[def.default] ~= nil).toBe(true)
		end
		T.expect(noDuplicates({})).toBe(true)
	end)

	T.it("movement and system keys are reserved", function()
		for _, key in { "W", "A", "S", "D", "Space", "Escape", "Slash", "I", "O", "LeftShift", "F9", "F11" } do
			T.expect(KeybindData.allowed[key]).toBeNil()
			T.expect(Keybinds.assign({}, "interact", key)).toBeNil()
		end
	end)

	T.it("binds a free key", function()
		local result = Keybinds.assign({}, "interact", "R") :: any
		T.expect(result.interact).toBe("R")
		T.expect(Keybinds.key(result, "interact")).toBe("R")
	end)

	T.it("swaps with the action that used the key", function()
		local result = Keybinds.assign({}, "interact", "F") :: any
		T.expect(Keybinds.key(result, "interact")).toBe("F")
		T.expect(Keybinds.key(result, "pickup")).toBe("E")
		T.expect(noDuplicates(result)).toBe(true)
	end)

	T.it("reset to default swaps a colliding custom key back", function()
		local first = Keybinds.assign({}, "pickup", "R") :: any
		local second = Keybinds.assign(first, "win_map", "F") :: any -- F is free now
		T.expect(Keybinds.key(second, "win_map")).toBe("F")
		local reset = Keybinds.assign(second, "pickup", nil) :: any
		T.expect(Keybinds.key(reset, "pickup")).toBe("F")
		T.expect(noDuplicates(reset)).toBe(true)
	end)

	T.it("drops unknown actions and invalid saved keys", function()
		local result = Keybinds.assign({ nope = "R", interact = "W" } :: any, "pickup", "Q") :: any
		T.expect(result.nope).toBeNil()
		T.expect(result.interact).toBeNil()
		T.expect(Keybinds.assign({}, "nope", "R")).toBeNil()
	end)

	T.it("random rebinding never binds a key twice", function()
		local names = {}
		for name in KeybindData.allowed do
			table.insert(names, name)
		end
		table.sort(names)
		local overrides: any = {}
		local seed = 7
		for _ = 1, 400 do
			seed = (seed * 1103515245 + 12345) % 2147483648
			local def = KeybindData.actions[seed % #KeybindData.actions + 1]
			local key = if seed % 5 == 0 then nil else names[seed % #names + 1]
			overrides = Keybinds.assign(overrides, def.id, key) or overrides
			T.expect(noDuplicates(overrides)).toBe(true)
		end
	end)

	T.it("labels", function()
		T.expect(Keybinds.label("One")).toBe("1")
		T.expect(Keybinds.label("Zero")).toBe("0")
		T.expect(Keybinds.label("E")).toBe("E")
	end)
end)
