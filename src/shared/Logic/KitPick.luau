--!strict
-- W02: which model of the asset kit (Data/Kit) stands in a kit slot of a Blueprint (Logic/TownGen/Blueprint
-- beginKit), at what scale and turned how far. Pure and deterministic: the choice depends only on the slot's key, the
-- map's biome and the slot's world position, so the server (shell) and every client (detail) pick the same model
-- without sending anything, and a map looks the same after every server start. Uses no shared random numbers.

local Kit = require("../Data/Kit")

local KitPick = {}

export type Choice = {
	variant: Kit.Variant,
	fit: "height" | "width",
	-- the model's height (or widest side) in studs: Data/Kit size x the slot's scale x the variant's extra scale
	size: number,
	yaw: number, -- degrees around the vertical axis
	sink: number, -- fraction of the model's height below the slot's foot
}

-- Stable hash of a key and a point in [0, 1). Points closer than a quarter stud share it.
function KitPick.hash(key: string, x: number, z: number, salt: number?): number
	-- MINSTD steps (products stay below 2^53, so Luau and Lune agree exactly)
	local M = 2147483647
	local h = 1
	local function mix(v: number)
		h = (h * 48271 + v % M) % M
		h = (h * 48271) % M
	end
	for i = 1, #key do
		mix(string.byte(key, i))
	end
	mix(math.floor(x * 4))
	mix(math.floor(z * 4))
	mix(salt or 0)
	return (h % 1000003) / 1000003
end

-- The variants of a slot key on a biome (its own list, else the key's default list), or nil: no model, the
-- generator's pieces stay.
function KitPick.variants(key: string, biome: string): { Kit.Variant }?
	local entry = Kit.slots[key]
	if not entry then
		return nil
	end
	local list = (entry :: any)[biome] or (entry :: any).default
	if not list or #list == 0 then
		return nil
	end
	return list
end

-- The model, size and turn of a slot `key` of generator scale `s` standing at world (x, z) on `biome`.
function KitPick.pick(key: string, biome: string, x: number, z: number, s: number): Choice?
	local list = KitPick.variants(key, biome)
	local entry = Kit.slots[key]
	if not list or not entry then
		return nil
	end
	local total = 0
	for _, v in list do
		total += v.weight
	end
	local roll = KitPick.hash(key, x, z, 1) * total
	local chosen = list[#list]
	for _, v in list do
		roll -= v.weight
		if roll < 0 then
			chosen = v
			break
		end
	end
	local t = KitPick.hash(key, x, z, 2)
	local extra = chosen.scale[1] + (chosen.scale[2] - chosen.scale[1]) * t
	local yaw = if chosen.yaw then KitPick.hash(key, x, z, 3) * 360 else chosen.turn or 0
	return { variant = chosen, fit = entry.fit, size = entry.size * s * extra, yaw = yaw, sink = chosen.sink or 0 }
end

return KitPick
