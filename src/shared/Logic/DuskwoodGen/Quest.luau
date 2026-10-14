--!strict
-- S103: props of the Duskwood quest anchors (Data/Areas/duskwood questAnchors with an entry in PROPS); the other
-- anchors stand at existing builds. S106: side quest anchors dw_* with an entry in PROPS; the other dw_* anchors stand
-- at existing builds (their props stand in the anchor's own frame, SIDE_OFFSET along +Z).
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
	-- S106: Duskwood side quest anchors (dw_*)
	dw_lantern_1 = "lanternPost",
	dw_lantern_2 = "lanternPost",
	dw_lantern_3 = "lanternPost",
	dw_hive_2 = "wildHive",
	dw_hive_3 = "wildHive",
	dw_ossuary = "ossuary",
	dw_waymark_1 = "waymark",
	dw_waymark_2 = "waymark",
	dw_waymark_3 = "waymark",
	dw_trap_1 = "eelTrap",
	dw_trap_2 = "eelTrap",
	dw_charm_2 = "charmPole",
	dw_charm_3 = "charmPole",
	dw_shore_1 = "shoring",
	dw_shore_2 = "shoring",
	dw_shore_3 = "shoring",
}

-- S106: the side quest props stand in their anchor's own frame (no THINGS entry), this far along local +Z (away from
-- the road, towards the water), so the "[E]" prompt sits just before them; the client effects use the same offset.
Quest.SIDE_OFFSET = 1.8

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

-- S106: swatches of the side quest props
local HONEY = { c = "#D8A43A", m = "SmoothPlastic" }
local WAX = { c = "#EADFC4", m = "SmoothPlastic" }
local PAINT = { c = "#8A4AC0", m = "SmoothPlastic" }
local WICKER = { c = "#8A6A3E", m = "Fabric" }
local FRESH = { c = "#C9A06A", m = "Wood" }

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

	-- S106: Duskwood side quest anchors (dw_*); every piece SIDE_OFFSET along +Z, detail / fine, no collisions.
	-- a road lantern knocked down: the post's stump with claw marks, the broken post and the dark cage in the mud
	lanternPost = function(bp)
		local z = Quest.SIDE_OFFSET
		bp:box(0.5, 1.2, 0.5, 0, 0.6, z, o(Kit.timber, "detail"))
		bp:rbox(0.45, 4.6, 0.45, 1.6, 0.25, z + 0.8, 0, 20, 86, o(Kit.timber, "detail"))
		bp:rbox(0.9, 1.1, 0.9, -1.1, 0.45, z + 0.6, 0, 25, 70, o(Kit.iron, "detail"))
		bp:rbox(0.6, 0.7, 0.6, -1.1, 0.45, z + 0.6, 0, 25, 70, o({ c = "#2A3440", m = "Glass" }, "fine", { t = 0.2 }))
		for k = -1, 1 do
			bp:rbox(
				0.06,
				0.8,
				0.05,
				k * 0.13,
				0.7,
				z - 0.27,
				0,
				0,
				14 + k * 4,
				o({ c = "#D8CFC0", m = "Wood" }, "fine")
			)
		end
	end,
	-- a wild hive in a hollow standing trunk: the dark mouth of the hive, a board pulled off, combs on the ground
	wildHive = function(bp)
		local z = Quest.SIDE_OFFSET
		bp:add("cyl", 4.6, 2.2, 2.2, 0, 2.3, z, 0, 0, 90, o(Kit.darkBark, "detail"))
		bp:box(0.8, 1.3, 0.3, 0, 2.7, z - 1.05, o(Kit.dark, "detail"))
		bp:rbox(0.9, 1.4, 0.15, 1.1, 0.7, z - 1, -15, 20, 0, o(Kit.planks, "fine"))
		for k = 1, 3 do
			bp:rbox(1.1, 0.2, 0.8, -1.5 + k * 0.9, 0.1, z - 1.6 - (k % 2) * 0.4, 0, k * 50, 0, o(HONEY, "fine"))
		end
	end,
	-- the servants' common grave behind the fence: a low cairn, an empty board on a pole, candle stubs gone out
	ossuary = function(bp)
		local z = Quest.SIDE_OFFSET
		bp:add("ball", 3.6, 1.4, 2.6, 0, 0.4, z, 0, 0, 0, o(Kit.mossyStone, "detail"))
		bp:add("ball", 1.2, 0.9, 1.1, 1.6, 0.35, z - 0.6, 0, 30, 0, o(Kit.stone, "fine"))
		bp:box(0.25, 2.8, 0.25, 0, 1.4, z + 1.4, o(Kit.timber, "detail"))
		bp:box(1.6, 1, 0.12, 0, 2.3, z + 1.25, o(Kit.greyPlanks, "detail"))
		for k = -1, 1 do
			bp:add("cyl", 0.3, 0.22, 0.22, k * 0.7, 1.15 - math.abs(k) * 0.2, z - 0.7, 0, 0, 90, o(WAX, "fine"))
		end
	end,
	-- a wayside stone with a false waymark in violet paint (the road's own sign, a cross and an arrow) and the pot
	waymark = function(bp)
		local z = Quest.SIDE_OFFSET
		bp:rbox(1.4, 2.2, 0.9, 0, 1, z, 0, 0, 4, o(Kit.mossyStone, "detail"))
		for _, a in { 30, -30 } do
			bp:rbox(0.14, 1.1, 0.05, 0, 1.3, z - 0.47, 0, 0, a, o(PAINT, "fine"))
		end
		bp:rbox(0.14, 0.6, 0.05, 0.35, 1.85, z - 0.47, 0, 0, 90, o(PAINT, "fine"))
		bp:add("cyl", 0.5, 0.55, 0.55, 0.9, 0.25, z - 1, 0, 0, 90, o({ c = "#5A4636", m = "Slate" }, "fine"))
		bp:add("cyl", 0.04, 0.45, 0.45, 0.9, 0.51, z - 1, 0, 0, 90, o(PAINT, "fine"))
	end,
	-- two wicker eel traps by a mooring pole, the rope to the pole and a gnawed net on the ground
	eelTrap = function(bp)
		local z = Quest.SIDE_OFFSET
		bp:box(0.3, 3, 0.3, 0, 1.5, z + 0.4, o(Kit.timber, "detail"))
		bp:add("cyl", 2.2, 0.9, 0.9, -0.5, 0.45, z - 0.4, 0, 20, 0, o(WICKER, "detail"))
		bp:add("cyl", 1.8, 0.8, 0.8, 0.9, 0.4, z + 1.1, 0, -30, 0, o(WICKER, "detail"))
		bp:beam(0, 1.2, z + 0.4, -0.5, 0.6, z - 0.2, 0.06, o(Kit.rope, "fine"))
		bp:rbox(1.6, 0.08, 1.2, 0.7, 0.05, z - 1, 0, 25, 0, o(Kit.rope, "fine", { t = 0.3 }))
	end,
	-- a crooked pole by the marsh path with a crossbar, a charm of bone, hair and string hanging from it
	charmPole = function(bp)
		local z = Quest.SIDE_OFFSET
		bp:rbox(0.3, 3.6, 0.3, 0, 1.8, z, 0, 0, 4, o(Kit.blackBark, "detail"))
		bp:box(1.5, 0.18, 0.18, 0.1, 3.2, z, o(Kit.darkBark, "detail"))
		for _, x in { -0.5, 0.6 } do
			bp:beam(x, 3.1, z, x, 2.4, z, 0.04, o(Kit.rope, "fine"))
		end
		bp:rbox(0.15, 0.7, 0.15, -0.5, 2.1, z, 0, 0, 20, o(Kit.bone, "fine"))
		bp:add("ball", 0.5, 0.5, 0.5, 0.6, 2.2, z, 0, 0, 0, o(Kit.oldBone, "fine"))
		bp:add("ball", 0.45, 0.6, 0.3, 0.1, 2.9, z - 0.2, 0, 0, 0, o({ c = "#2A2420", m = "Fabric" }, "fine"))
	end,
	-- three beams of the cut's shoring cracked against the wall, one cut straight through, a waler and fresh chips
	shoring = function(bp)
		local z = Quest.SIDE_OFFSET
		bp:rbox(0.5, 4, 0.5, -1.6, 1.8, z + 0.4, -15, 0, 0, o(Kit.timber, "detail"))
		bp:rbox(0.5, 4, 0.5, 0, 1.8, z + 0.4, -15, 0, 0, o(Kit.timber, "detail"))
		bp:rbox(0.5, 2, 0.5, 1.6, 1, z + 0.2, -15, 0, 0, o(Kit.timber, "detail"))
		bp:rbox(0.5, 2, 0.5, 1.9, 0.25, z - 0.8, 0, 10, 80, o(Kit.timber, "detail"))
		bp:box(4.2, 0.4, 0.25, 0, 2.8, z + 0.9, o(Kit.planks, "detail"))
		bp:rbox(0.54, 0.25, 0.54, 0, 1.3, z + 0.27, -15, 0, 0, o(FRESH, "fine"))
		bp:rbox(0.6, 0.08, 0.4, 0.4, 0.04, z - 0.6, 0, 35, 0, o(FRESH, "fine"))
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
	if not thing then
		-- S106: a side quest prop stands in its anchor's own frame
		return { x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0 }
	end
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
