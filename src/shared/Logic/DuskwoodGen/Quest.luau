--!strict
-- S103: props of the Duskwood quest anchors (Data/Areas/duskwood questAnchors with an entry in PROPS); the other
-- anchors stand at existing builds. S106 adds its side quest props here.
-- A prop is one Build at its anchor (`QuestProp_<anchorId>`, tag "questprop": the anchor's x / z, the ground there,
-- the anchor's `rot`) whose pieces sit in the frame of the thing they are on (`Quest.frame`: the menhir of the Moon
-- Glade, the Elder Tree, the Crypt Gate; the same numbers as Thicket / Heart / Cliffs). The client effect after the
-- anchor's use (QuestAnchorController: frostbreak, heartglow, sealbreak) is drawn in the same frame, so the changed
-- look covers the prop exactly. Detail and fine pieces only, no collisions, no map sketch. Pure.

local AreaTypes = require("../../Data/Areas/Types")
local Areas = require("../../Data/Areas/duskwood")
local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local MapTerrain = require("../MapTerrain")

local o = Kit.o

local Quest = {}

type Build = Kit.Build
type BP = Kit.BP

-- A frame relative to an anchor's Build frame (studs, degrees; Blueprint.push / CFrame.Angles order).
export type Frame = { x: number, y: number, z: number, rx: number, ry: number, rz: number }

-- Anchor id -> prop kind.
local PROPS: { [string]: string } = {
	moonstone_rune = "frostRune",
	elder_tree = "iceShard",
	crypt_seal = "cultSeal",
}

-- What each kind sits on: a site and, inside it, the thing's own frame over the site's ground.
local THINGS: { [string]: { site: string, y: number?, rx: number?, ry: number?, rz: number? } } = {
	frostRune = { site = "moonstone", y = 4.8, rx = 3, ry = 20, rz = 2 }, -- the menhir (Thicket moonGlade)
	iceShard = { site = "elderTree" }, -- the split trunk; the crack's front at z = -4.2 (Heart elderTree)
	cultSeal = { site = "cryptGate" }, -- the facade; the right niches at x = 15, z = -17.2 (Cliffs cryptGate)
}

-- Where the effects of the client centre: the rune on the menhir's face, the shard in the crack, the seal before the
-- lowest right niche (in the frame of Quest.frame).
Quest.RUNE = { x = 0.2, y = 1.9, z = -1.36 }
Quest.SHARD = { x = 0.2, y = 4.2, z = -4.1 }
Quest.SEAL = { x = 15, y = 7.5, z = -17.85 }

-- The snowflake pierced by a thorn (the frost sign of FABULA §1): three crossed bars and a longer slanted one.
local function sign(bp: BP, at: { x: number, y: number, z: number }, size: number, bar: string, thorn: string)
	for _, a in { 0, 60, -60 } do
		bp:rbox(
			size * 0.075,
			size,
			0.06,
			at.x,
			at.y,
			at.z,
			0,
			0,
			a,
			{ c = bar, m = "Neon", lod = "detail", col = false, jitter = 0 }
		)
	end
	bp:rbox(
		size * 0.06,
		size * 1.4,
		0.08,
		at.x,
		at.y,
		at.z - 0.05,
		0,
		0,
		38,
		{ c = thorn, m = "Neon", lod = "detail", col = false, jitter = 0 }
	)
end

local BUILD: { [string]: (bp: BP) -> () } = {
	-- a fresh frost rune on the menhir's face (cold blue light instead of the silver) and rime at the stone's foot
	frostRune = function(bp)
		sign(bp, Quest.RUNE, 2.2, "#9FD8FF", "#6FB0E8")
		bp:rbox(
			4.4,
			0.1,
			1.4,
			0,
			-4.74,
			-1.9,
			0,
			0,
			0,
			o({ c = "#EAF6FF", m = "Ice" }, "detail", { col = false, t = 0.2 })
		)
		bp:rbox(
			2.2,
			0.1,
			1,
			1.4,
			-4.72,
			-2.9,
			0,
			30,
			0,
			o({ c = "#EAF6FF", m = "Ice" }, "fine", { col = false, t = 0.3 })
		)
	end,
	-- a blue shard of ice driven slantwise into the crack of the Elder Tree, rime on the bark around it
	iceShard = function(bp)
		local s = Quest.SHARD
		local ice = { c = "#8FCBFF", m = "Glass", lod = "detail" :: any, col = false, t = 0.3, jitter = 0 }
		bp:rbox(0.7, 2.8, 0.7, s.x, s.y, s.z, 25, 0, -18, ice)
		bp:rbox(0.35, 1.2, 0.35, s.x - 0.5, s.y - 0.8, s.z, 10, 0, 30, ice)
		bp:rbox(0.3, 0.9, 0.3, s.x + 0.5, s.y + 0.9, s.z + 0.1, -20, 0, -40, ice)
		bp:box(2.4, 3, 0.08, 0, s.y, -4.26, o({ c = "#EAF6FF", m = "Ice" }, "fine", { col = false, t = 0.4 }))
		bp:light(s.x, s.y, s.z - 1, "#8FCBFF", 8, 0.7)
	end,
	-- the cult's violet seal hung before the right niche: a disc with the frost sign, two chains
	cultSeal = function(bp)
		local s = Quest.SEAL
		bp:add(
			"cyl",
			0.12,
			3,
			3,
			s.x,
			s.y,
			s.z,
			0,
			90,
			0,
			{ c = "#7A4AA0", m = "Neon", lod = "detail", col = false, t = 0.1, jitter = 0 }
		)
		sign(bp, { x = s.x, y = s.y, z = s.z - 0.1 }, 2, "#D8C8FF", "#F0E8FF")
		for _, side in { -1, 1 } do
			bp:beam(s.x + side * 1.4, s.y + 2.6, -17.3, s.x + side * 0.9, s.y + 1.2, s.z, 0.12, o(Kit.iron, "fine"))
		end
		bp:light(s.x, s.y, s.z - 1.2, Kit.VIOLET, 8, 0.6)
	end,
}

local function anchorOf(id: string): AreaTypes.QuestAnchor?
	local anchors: { AreaTypes.QuestAnchor } = Areas.questAnchors or {}
	for _, anchor in anchors do
		if anchor.id == id then
			return anchor
		end
	end
	return nil
end

local function ground(x: number, z: number): number
	return MapTerrain.height("duskwood", x, z) or 0
end

-- The frame of the thing a prop sits on, relative to its anchor's Build frame (nil: no prop at this anchor). The
-- anchor's `rot` is its site's yaw, so only the site's centre (and the thing's own height and tilt) is left.
function Quest.frame(anchorId: string): Frame?
	local kind = PROPS[anchorId]
	local anchor = anchorOf(anchorId)
	if not kind or not anchor then
		return nil
	end
	local thing = THINGS[kind]
	local sites = assert(Areas.sites, "duskwood sites")
	local site = assert(sites[thing.site], thing.site)
	assert((anchor.rot or 0) == site.rot, `{anchorId}: rot {anchor.rot} is not the yaw of {thing.site}`)
	local r = math.rad(site.rot)
	local c, s = math.cos(r), math.sin(r)
	local dx, dz = site.x - anchor.x, site.z - anchor.z
	return {
		x = c * dx - s * dz, -- the inverse of Kit.toWorld
		y = ground(site.x, site.z) - ground(anchor.x, anchor.z) + (thing.y or 0),
		z = s * dx + c * dz,
		rx = thing.rx or 0,
		ry = thing.ry or 0,
		rz = thing.rz or 0,
	}
end

-- The prop kind of an anchor (nil: none).
function Quest.kindOf(anchorId: string): string?
	return PROPS[anchorId]
end

-- One Build per anchor of PROPS; an anchor of the table missing from the map data is an error naming it.
function Quest.all(env: Env.Env, out: { Build })
	local ids: { string } = {}
	for id in PROPS do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local anchor: AreaTypes.QuestAnchor? = nil
		local anchors: { AreaTypes.QuestAnchor } = env.areas.questAnchors or {}
		for _, a in anchors do
			if a.id == id then
				anchor = a
			end
		end
		local a = assert(anchor, `DuskwoodGen/Quest: no quest anchor {id}`)
		local f = assert(Quest.frame(id), id)
		local b = Kit.build(env.ctx, `QuestProp_{id}`, "questprop", a.x, a.z, a.rot or 0)
		b.bp:push(f.x, f.y, f.z, f.rx, f.ry, f.rz)
		BUILD[PROPS[id]](b.bp)
		b.bp:pop()
		table.insert(out, b)
	end
end

return Quest
