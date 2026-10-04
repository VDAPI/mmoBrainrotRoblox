--!strict
-- Deterministic xorshift32 RNG. Pure Luau (no Roblox Random), so it runs in Lune tests
-- and can be injected with a fixed seed wherever game logic rolls dice.

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { _state: number }, Rng))

local UINT32 = 4294967296

local function normalizeSeed(seed: number): number
	local s = math.floor(math.abs(seed)) % UINT32
	if s == 0 then
		s = 2463534242 -- xorshift state must never be zero
	end
	return s
end

function Rng.new(seed: number?): Rng
	local initial = seed or (os.time() + math.floor(os.clock() * 1e6))
	return setmetatable({ _state = normalizeSeed(initial) }, Rng)
end

-- Returns a uint32 and advances the state.
function Rng.nextUint(self: Rng): number
	local x = self._state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self._state = x
	return x
end

-- Float in [0, 1).
function Rng.next(self: Rng): number
	return self:nextUint() / UINT32
end

-- Integer in [a, b] inclusive.
function Rng.int(self: Rng, a: number, b: number): number
	assert(b >= a, "Rng.int: b must be >= a")
	return a + math.floor(self:next() * (b - a + 1))
end

-- Float in [a, b).
function Rng.float(self: Rng, a: number, b: number): number
	return a + self:next() * (b - a)
end

-- True with probability p (0..1).
function Rng.chance(self: Rng, p: number): boolean
	return self:next() < p
end

-- Picks a key from { [key] = weight }. Keys are iterated in sorted order so the result
-- is deterministic for a given seed regardless of table hashing.
function Rng.weighted<K>(self: Rng, weights: { [K]: number }): K
	local keys: { K } = {}
	local total = 0
	for key, weight in weights do
		if weight > 0 then
			table.insert(keys, key)
			total += weight
		end
	end
	assert(total > 0, "Rng.weighted: no positive weights")
	table.sort(keys, function(a: any, b: any)
		return tostring(a) < tostring(b)
	end)
	local roll = self:next() * total
	for _, key in keys do
		roll -= weights[key]
		if roll < 0 then
			return key
		end
	end
	return keys[#keys]
end

function Rng.pick<T>(self: Rng, list: { T }): T
	assert(#list > 0, "Rng.pick: empty list")
	return list[self:int(1, #list)]
end

-- Fisher-Yates shuffle in place; returns the same list.
function Rng.shuffle<T>(self: Rng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return Rng
