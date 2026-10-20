--!strict
-- W28: geometry of an item slot's rarity frame (pure, tested in Lune; drawn by UI/Components/RarityFrame).
-- The frame lies inside the slot (inner stroke) so thick frames never touch the neighbours in a tight grid; its
-- width grows with the rarity (Data/Rarities `frame.thickness` + 1 px at the 64 px reference slot) and scales with the
-- slot size, so a 40 px phone slot keeps the same proportions as an 84 px smith slot. Everything the frame draws
-- inside the slot (band + inner glow) stays within the icon's margin (ItemIcon is 78 % of the slot).

local Rarities = require("../Data/Rarities")

local RarityFrame = {}

RarityFrame.REFERENCE = 64 -- slot size (px) the data thickness is tuned for (Theme.Size.SlotSize)
RarityFrame.MIN_SCALE = 0.65
RarityFrame.MAX_SCALE = 1.3
RarityFrame.ICON_MARGIN = 0.11 -- free border around the icon, as a share of the slot side
RarityFrame.KEYLINE = 1 -- dark outer edge (px) that keeps light frames visible on parchment

local function round(value: number): number
	return math.floor(value * 2 + 0.5) / 2
end

-- Scale of the frame for a slot side (clamped: tiny slots keep a readable frame, huge ones do not get clumsy).
function RarityFrame.scale(size: number): number
	return math.clamp(size / RarityFrame.REFERENCE, RarityFrame.MIN_SCALE, RarityFrame.MAX_SCALE)
end

-- Width (px, step 0.5) of the coloured band of a rarity's frame in a slot of `size` px.
function RarityFrame.band(rarity: number?, size: number): number
	local r = Rarities.get(rarity or Rarities.COMMON)
	return math.max(1.5, round((r.frame.thickness + 1) * RarityFrame.scale(size)))
end

-- Width (px) of the inner glow strip measured from the slot edge (band included); never past the icon margin.
function RarityFrame.glow(rarity: number?, size: number): number
	local band = RarityFrame.band(rarity, size)
	return math.max(band, math.min(band * 1.8, size * RarityFrame.ICON_MARGIN))
end

-- Side (px) of a corner stud (Unique and better); 0 = no studs.
function RarityFrame.stud(rarity: number?, size: number): number
	local id = rarity or Rarities.COMMON
	if id < Rarities.UNIQUE then
		return 0
	end
	return math.max(4, round(RarityFrame.band(id, size) * 1.7))
end

-- Strength of the background tint at its bright edge (transparency: 1 = none). Common items get none.
function RarityFrame.tint(rarity: number?): number
	local id = rarity or Rarities.COMMON
	if id < Rarities.UNIQUE then
		return 1
	end
	return if id >= Rarities.LEGENDARY then 0.55 elseif id >= Rarities.HEROIC then 0.62 else 0.68
end

return table.freeze(RarityFrame)
