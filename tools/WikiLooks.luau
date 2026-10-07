--!strict
-- Monster, boss and pet looks as world-space pieces (S24 preview, S38 wiki renders). Pure (no fs / process):
-- tools/lookdump.luau is the CLI. Not named LookDump: on Windows Lune confuses tools/lookdump.luau with a module
-- of the same name in another case (docs/WIKI.md, S38 decisions).
--   WikiLooks.legacy(args)  -> pieces of `lookdump.luau out.json <ids...|region:N|bosses|pets> [variant]`
--   WikiLooks.entries()     -> one entry per wiki render (tools/wiki-renders): monsters with their elite
--                              variants, bosses and pets; ground at y = 0, centred on x = 0, facing -Z

local Anatomy = require("../src/shared/Logic/Anatomy")
local Bosses = require("../src/shared/Data/Bosses")
local Combat = require("../src/shared/Data/Combat")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local Monsters = require("../src/shared/Data/Monsters")
local Plans = require("../src/shared/Logic/Anatomy/Plans")

local WikiLooks = {}

WikiLooks.VERSION = 1

-- Rotation of a piece as a row-major 3x3 matrix (CFrame.Angles order, same as Logic/Anatomy).
function WikiLooks.matrix(rot: { number }): { number }
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

export type DumpPiece = {
	s: string,
	size: { number },
	p: { number },
	r: { number },
	c: string,
	m: string,
	lod: string,
	t: number?,
}

-- Pieces of a rig standing on the ground (y = 0) with the root centre at (x, ·, 0).
function WikiLooks.pieces(rig: Anatomy.Rig, x: number): { DumpPiece }
	local out = {}
	local rootY = rig.hipHeight + rig.root.size[2] / 2
	for _, p in rig.pieces do
		table.insert(out, {
			s = if p.shape == "block" then "box" else p.shape,
			size = p.size,
			p = { x + p.pos[1], rootY + p.pos[2], p.pos[3] },
			r = WikiLooks.matrix(p.rot),
			c = p.color,
			m = p.material,
			lod = "shell",
			t = p.transparency,
		})
	end
	return out
end

type Item = { id: string, look: any, scale: number, variant: string }

-- The S24 preview row: looks stand along X with a ground plate. Returns pieces, labels ("id@x") and the width.
function WikiLooks.legacy(args: { string }): ({ DumpPiece }, { string }, number)
	local variant = "normal"
	local items: { Item } = {}
	for _, a in args do
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
			table.insert(items, {
				id = a,
				look = MonsterLooks.get(a, def and def.region),
				scale = if def then def.size else 1,
				variant = "",
			})
		end
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
		for _, piece in WikiLooks.pieces(rig, x) do
			table.insert(pieces, piece)
		end
		table.insert(labels, `{item.id}@{math.floor(x)}`)
		x += width + 1.5
	end
	-- ground
	table.insert(pieces, {
		s = "box",
		size = { x + 10, 0.2, 30 },
		p = { x / 2, -0.1, 0 },
		r = WikiLooks.matrix({ 0, 0, 0 }),
		c = "#4F6A35",
		m = "Grass",
		lod = "shell",
	})
	return pieces, labels, x
end

export type PhaseEntry = { phase: number, tint: string, amount: number, glow: string? }

export type Entry = {
	file: string,
	id: string,
	kind: string, -- "monster" | "boss" | "pet"
	variant: string,
	region: number?,
	scale: number,
	plan: string,
	hovers: boolean,
	height: number,
	hipHeight: number,
	fx: string?,
	aura: string?,
	phases: { PhaseEntry }?,
	asset: boolean,
	pieces: { DumpPiece },
}

local function visible(entity: any): boolean
	return entity.hidden ~= true and entity.wiki ~= false
end

local function round(n: number): number
	local r = math.floor(n * 10000 + 0.5) / 10000
	return if r == 0 then 0 else r
end

local function roundList(list: { number }): { number }
	local out = table.create(#list)
	for i, n in list do
		out[i] = round(n)
	end
	return out
end

local function entry(file: string, id: string, kind: string, variant: string, look: any, scale: number): Entry
	local rig = Anatomy.build(look, { id = id, variant = variant, scale = scale })
	local pieces = WikiLooks.pieces(rig, 0)
	for _, p in pieces do
		p.size = roundList(p.size)
		p.p = roundList(p.p)
		p.r = roundList(p.r)
		if p.t then
			p.t = round(p.t)
		end
	end
	return {
		file = file,
		id = id,
		kind = kind,
		variant = variant,
		scale = round(scale),
		plan = rig.plan,
		hovers = Plans.hovers(rig.plan),
		height = round(rig.height),
		hipHeight = round(rig.hipHeight),
		fx = rig.fx,
		asset = look.asset ~= nil,
		pieces = pieces,
	}
end

-- Every render of the wiki, sorted by file (monsters with elites, bosses with aura and phases, pets without price).
function WikiLooks.entries(): { Entry }
	local out: { Entry } = {}
	for _, def in Monsters.list do
		if visible(def) then
			local look = MonsterLooks.get(def.id, def.region)
			local variants = if def.elites then { "normal", "elite", "elite2" } else { "normal" }
			for _, v in variants do
				local file = if v == "normal" then def.id else `{def.id}-{v}`
				local e = entry(file, def.id, "monster", v, look, def.size * Combat.variants[v].scale)
				e.region = def.region
				table.insert(out, e)
			end
		end
	end
	for _, boss in Bosses.list do
		if visible(boss) then
			local look = MonsterLooks.get(boss.id) :: any
			local e = entry(boss.id, boss.id, "boss", "boss", look, boss.look.size)
			e.aura = boss.look.aura
			if look.phases then
				local phases: { PhaseEntry } = {}
				for n, ph in look.phases do
					table.insert(phases, { phase = n, tint = ph.tint, amount = ph.amount, glow = ph.glow })
				end
				table.sort(phases, function(a, b)
					return a.phase < b.phase
				end)
				e.phases = phases
			end
			table.insert(out, e)
		end
	end
	for _, def in Cosmetics.list do
		if def.kind == "pet" and def.look and visible(def) then
			table.insert(out, entry(def.id, def.id, "pet", "pet", def.look, Cosmetics.PET_SCALE))
		end
	end
	table.sort(out, function(a, b)
		return a.file < b.file
	end)
	return out
end

return WikiLooks
