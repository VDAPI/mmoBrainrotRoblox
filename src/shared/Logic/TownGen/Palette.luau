--!strict
-- Colours and materials of the old-wood medieval city (S21, docs/miasto/MIASTO.md §3). Everything is a little
-- dirty and dark: no pure white, no saturated colours except small accents (doors, shutters, awnings, flags).

local Palette = {}

export type Swatch = { c: string, m: string }

local function list(material: string, colours: { string }): { Swatch }
	local out = {}
	for _, c in colours do
		table.insert(out, { c = c, m = material })
	end
	return out
end

-- Weathered oak beams of the timber frame (dark, greyish brown).
Palette.timber = list("Wood", { "#3B2A1E", "#46321F", "#2F241B", "#4F3A28", "#3A2C22" })
-- Planks: doors, shutters, gables of sheds, fences.
Palette.planks = list("WoodPlanks", { "#6B5038", "#5C4632", "#735A41", "#4E3B2A", "#5F4A36" })
-- Old silver-grey planks (barns, sheds, fences in the lower town).
Palette.greyPlanks = list("WoodPlanks", { "#6E675E", "#5E5850", "#7A7166", "#655B50" })
-- Lime plaster between the beams: off-white, ochre, faded colours.
Palette.plaster = list("Plaster", {
	"#D6C9AE",
	"#CDBF9F",
	"#C8B38D",
	"#BDAE90",
	"#D0C2A5",
	"#C2A383",
	"#B5B49C",
	"#C9B6A0",
	"#BFA88A",
})
-- Painted plaster of the rich stone houses (rynek, upper town).
Palette.richPlaster = list("Plaster", {
	"#C9A27A",
	"#B98D6A",
	"#A9B39A",
	"#C7B27E",
	"#B7A6A0",
	"#C4B49A",
	"#9FA6A8",
	"#C99E86",
})
-- Rubble stone for plinths and ground floors.
Palette.rubble = list("Cobblestone", { "#6E6A63", "#7A746A", "#5F5B55", "#847B6E", "#6A6560" })
-- Dressed stone (ashlar) for rich houses, arches, quoins, the temple and the town hall.
Palette.ashlar = list("Limestone", { "#A79C88", "#9A907E", "#B0A590", "#8F8676" })
Palette.slate = list("Slate", { "#5A5652", "#4E4B48", "#625D57" })
-- Roofs.
Palette.shingles = list("RoofShingles", { "#4B3A32", "#3E3430", "#5A4335", "#463B36", "#52463E" })
Palette.tiles = list("ClayRoofTiles", { "#8E4A35", "#7A3F2E", "#9A5A3E", "#6F3B2C", "#86503A" })
Palette.thatch = list("Grass", { "#9C8550", "#8C7A4A", "#A38E5A", "#857146" })
Palette.slateRoof = list("Slate", { "#3F4247", "#45484C", "#3A3C40" })
-- Accents.
Palette.brick = list("Brick", { "#6E3B2E", "#7D4434", "#683A2F" })
Palette.door = list("WoodPlanks", { "#4A2F22", "#3E2A1E", "#5A3A26", "#2F3A2E", "#4A2A2A" })
Palette.shutter = list("WoodPlanks", { "#3F5A4A", "#5A3A2E", "#4A4A3A", "#6B5038", "#3E4E5E", "#6A4A30" })
Palette.awning = list("Fabric", { "#7A3B2E", "#3E5A7A", "#6B6B3E", "#5A3E6B", "#8A6A3A", "#3E6B5A" })
Palette.moss = list("LeafyGrass", { "#4F6B35", "#5B7340", "#46602F" })
Palette.metal = list("CorrodedMetal", { "#3A3836", "#45403A" })
Palette.glass = { c = "#262A2E", m = "Glass" }
Palette.glassNight = { c = "#FFC46E", m = "Neon" }
Palette.soot = { c = "#2A2622", m = "Slate" }

function Palette.pick(rng: any, swatches: { Swatch }): Swatch
	return swatches[rng:int(1, #swatches)]
end

return Palette
