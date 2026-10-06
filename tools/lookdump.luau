--!strict
-- Dumps generated monster looks (Logic/Anatomy) as world-space pieces for docs/miasto/tools/render3d.py
-- (S24 preview without Studio): lune run tools/lookdump.luau out.json <ids...|region:N|bosses|pets> [variant]
-- Looks stand in a row along X, facing -Z (towards a camera placed in front).

local fs = require("@lune/fs")
local process = require("@lune/process")

local Anatomy = require("../src/shared/Logic/Anatomy")
local Bosses = require("../src/shared/Data/Bosses")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local Monsters = require("../src/shared/Data/Monsters")

local args = process.args
local out = args[1] or "looks.json"
local variant = "normal"
local items: { { id: string, look: any, scale: number, variant: string } } = {}

for i = 2, #args do
	local a = args[i]
	if a == "normal" or a == "elite" or a == "elite2" then
		variant = a
	elseif string.sub(a, 1, 7) == "region:" then
		local n = tonumber(string.sub(a, 8))
		for _, def in Monsters.list do
			if def.region == n then
				table.insert(
					items,
					{ id = def.id, look = MonsterLooks.get(def.id, def.region), scale = def.size, variant = "" }
				)
			end
		end
	elseif a == "bosses" then
		for _, boss in Bosses.list do
			table.insert(
				items,
				{ id = boss.id, look = MonsterLooks.get(boss.id), scale = boss.look.size * 0.5, variant = "boss" }
			)
		end
	elseif a == "pets" then
		for _, def in Cosmetics.list do
			if def.kind == "pet" then
				table.insert(items, { id = def.id, look = def.look, scale = 1, variant = "pet" })
			end
		end
	else
		local def = Monsters.get(a)
		table.insert(
			items,
			{
				id = a,
				look = MonsterLooks.get(a, def and def.region),
				scale = if def then def.size else 1,
				variant = "",
			}
		)
	end
end

local function matrix(rot: { number }): { number }
	local x, y, z = math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	return {
		cy * cz,
		-cy * sz,
		sy,
		cx * sz + sx * sy * cz,
		cx * cz - sx * sy * sz,
		-sx * cy,
		sx * sz - cx * sy * cz,
		sx * cz + cx * sy * sz,
		cx * cy,
	}
end

local pieces = {}
local x = 0
local labels = {}
for _, item in items do
	local rig = Anatomy.build(item.look, {
		id = item.id,
		variant = if item.variant ~= "" then item.variant else variant,
		scale = item.scale,
	})
	local width = 0
	for _, p in rig.pieces do
		width = math.max(width, math.abs(p.pos[1]) + p.size[1])
	end
	x += width + 1.5
	local rootY = rig.hipHeight + rig.root.size[2] / 2
	for _, p in rig.pieces do
		table.insert(pieces, {
			s = if p.shape == "block" then "box" else p.shape,
			size = p.size,
			p = { x + p.pos[1], rootY + p.pos[2], p.pos[3] },
			r = matrix(p.rot),
			c = p.color,
			m = p.material,
			lod = "shell",
			t = p.transparency,
		})
	end
	table.insert(labels, `{item.id}@{math.floor(x)}`)
	x += width + 1.5
end
-- ground
table.insert(pieces, {
	s = "box",
	size = { x + 10, 0.2, 30 },
	p = { x / 2, -0.1, 0 },
	r = matrix({ 0, 0, 0 }),
	c = "#4F6A35",
	m = "Grass",
	lod = "shell",
})
fs.writeFile(out, `\{"pieces": {require("@lune/serde").encode("json", pieces)}\}`)
print(table.concat(labels, " "), "width", x)
