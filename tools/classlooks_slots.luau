--!strict
-- S132 (DESIGN-17 §9a): `lune run tools/classlooks_slots.luau` prints the Markdown table of every empty catalog slot of
-- the class looks (catalog / shirt / pants = 0): the default outfits of Data/ClassLooks, the class outfits of
-- Data/Cosmetics, the faces and the hairstyles. docs/WYGLAD-KLAS.md pastes its output, so the owner's list always
-- matches the data. Prints the number of empty slots last.

local CharacterLook = require("../src/shared/Logic/CharacterLook")
local ClassLooks = require("../src/shared/Data/ClassLooks")
local Classes = require("../src/shared/Data/Classes")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local pl = require("../src/shared/Data/Localization/pl")

local rows: { string } = {}
local function row(owner: string, element: string, role: string, file: string, field: string)
	table.insert(rows, `| {owner} | {element} | {role} | \`{file}\` | \`{field}\` |`)
end

local function outfit(owner: string, file: string, path: string, spec: ClassLooks.OutfitSpec)
	for i, g in spec.garments do
		if (g.catalog or 0) == 0 then
			local def = CharacterLook.GARMENTS[g.g]
			local role = g.role or (if def then def.role else "?")
			row(owner, pl[`garment.{g.g}`] or g.g, role, file, `{path}.garments[{i}].catalog`)
		end
	end
	if (spec.shirt or 0) == 0 then
		row(owner, "koszula (Classic Shirt)", "—", file, `{path}.shirt`)
	end
	if (spec.pants or 0) == 0 then
		row(owner, "spodnie (Classic Pants)", "—", file, `{path}.pants`)
	end
end

for _, classId in Classes.order do
	local look = ClassLooks.get(classId)
	if look then
		outfit(pl[look.nameKey] or classId, "src/shared/Data/ClassLooks.luau", `classes.{classId}.outfit`, look.outfit)
	end
end
for _, def in Cosmetics.list do
	if def.class and def.outfit then
		local class = Classes.get(def.class)
		local owner = `{pl[def.nameKey] or def.id} ({if class then pl[class.nameKey] or def.class else def.class})`
		outfit(owner, "src/shared/Data/Cosmetics.luau", `{def.id}.outfit`, def.outfit)
	end
end
-- W10: faces and hairstyles are Roblox items of Data/BodyLooks (dynamic heads, catalog hair), no empty slots here

print("| Klasa / strój | Element | Rola koloru | Plik | Pole |")
print("|---|---|---|---|---|")
for _, line in rows do
	print(line)
end
print("")
print(`Pustych miejsc: {#rows}.`)
