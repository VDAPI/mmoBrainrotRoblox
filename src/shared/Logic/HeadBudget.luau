--!strict
-- Template animation (owner 2026-11-10: "modele poruszają się nie poruszając głową tak 2d"; code review 2026-11-10:
-- the low level read and kept every kind's head mesh it never showed, corpses held head places): which looks of the
-- monsters without bones wear a turning head (client/Anim/MeshHead), and when a look keeps its model's head mesh.
-- * The budget: the `heads` nearest looks within `radius` studs of the camera (Config.Graphics.levels; a look already
--   wearing one counts `hysteresis` studs nearer, so two at the edge do not swap every pass), AnimLab's subject always.
--   A dying look, a look whose mesh is out of the world (streamed out, destroyed) and a look that never can are left
--   out, so their places go to the next looks.
-- * A look keeps its model's mesh while it wears it or is wanted, so nothing is read, skinned or kept for a level that
--   turns no heads (low) or for looks beyond the radius; the first look to keep a mesh not read yet (or freed since)
--   starts reading it, as does one keeping a mesh that ran out of memory once its retry is due.
-- Pure (Lune).

local GraphicsLevel = require("./GraphicsLevel")

local HeadBudget = {}

export type Look = {
	d: number, -- its distance to the camera (studs)
	wanted: boolean, -- wanted in the last pass
	lab: boolean, -- AnimLab's subject
	dying: boolean, -- its death plays (its head goes back to rest)
	present: boolean, -- its mesh is in the world
	off: boolean, -- it can never wear one (its model's mesh failed, its part cannot be copied)
}

-- The looks of `looks` wanted now (a set of indices into it).
function HeadBudget.pick(looks: { Look }, heads: number, radius: number, hysteresis: number): { [number]: boolean }
	local wanted: { [number]: boolean } = {}
	local list: { GraphicsLevel.Candidate } = {}
	local at: { number } = {}
	for i, look in looks do
		if look.off or look.dying or not look.present then
			continue
		elseif look.lab then
			wanted[i] = true
		elseif heads > 0 and look.d <= radius + (if look.wanted then hysteresis else 0) then
			table.insert(list, { d = look.d, on = look.wanted })
			table.insert(at, i)
		end
	end
	for k in GraphicsLevel.nearest(list, heads, hysteresis) do
		wanted[at[k]] = true
	end
	return wanted
end

-- Whether a look in `state` (MeshHead's: rest, waiting, live, off) keeps its model's mesh: while it wears it, or while
-- it is wanted and may.
function HeadBudget.keeps(state: string, wanted: boolean): boolean
	return state == "live" or (wanted and state ~= "off")
end

-- Whether a look keeping its model's mesh in `state` (cold: not read or freed since; loading, ready, failed) starts
-- reading it at `now`: a cold one, or one that ran out of memory (`retryAt`) once that is due.
function HeadBudget.reads(state: string, retryAt: number?, now: number): boolean
	return state == "cold" or (state == "failed" and retryAt ~= nil and now >= retryAt)
end

return HeadBudget
