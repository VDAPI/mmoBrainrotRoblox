--!strict
-- Stand-in for Logic/Rng returning extreme values (S34): mode "min" (lowest roll, every chance succeeds), "max"
-- (highest roll, every chance fails) or "fail" (every chance fails, for Upgrade.attempt). Used where a game function
-- rolls but the wiki wants its bounds (damage min-max, drop item levels, failed upgrades). Monte Carlo uses the real
-- Rng.new(seed) with WikiDump.seedOf.

local StubRng = {}
StubRng.__index = StubRng

export type Mode = "min" | "max" | "fail"

function StubRng.new(mode: Mode): any
	return setmetatable({ mode = mode }, StubRng)
end

function StubRng.next(self: any): number
	return if self.mode == "min" then 0 else 0.999999
end

function StubRng.int(self: any, low: number, high: number): number
	return if self.mode == "min" then low else high
end

function StubRng.float(self: any, low: number, high: number): number
	return if self.mode == "min" then low else high
end

function StubRng.chance(self: any, _p: number): boolean
	return self.mode == "min"
end

function StubRng.weighted(self: any, weights: { [any]: number }): any
	local keys = {}
	for key, weight in weights do
		if weight > 0 then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a: any, b: any)
		return tostring(a) < tostring(b)
	end)
	return if self.mode == "min" then keys[1] else keys[#keys]
end

function StubRng.pick(self: any, list: { any }): any
	return if self.mode == "min" then list[1] else list[#list]
end

function StubRng.shuffle(_self: any, list: { any }): { any }
	return list
end

-- Stable seed of a text (adding a monster does not change the others' results).
function StubRng.seedOf(text: string): number
	local seed = 7
	for i = 1, #text do
		seed = (seed * 31 + string.byte(text, i)) % 2147483647
	end
	return seed
end

return StubRng
