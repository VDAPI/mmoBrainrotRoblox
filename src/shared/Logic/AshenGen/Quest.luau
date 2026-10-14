--!strict
-- S107: props of the Ashen side quest anchors (Data/Areas/ashen questAnchors with an entry in PROPS), like
-- Logic/DuskwoodGen/Quest (S103, S106): the "before" look of an anchor whose landmark has nothing to show. The other
-- ash_* anchors stand by existing builds (the skull, the boat, the drum, the chimneys, the wagons ...).
-- A prop is one Build (`QuestProp_<anchorId>`, tag "questprop") SIDE_OFFSET studs along the anchor's local +Z (`rot`),
-- on the ground there, so the "[E]" prompt sits just before it; the client effect after the anchor's use
-- (QuestAnchorController: cairn, water, incense, mark, tracks) is drawn at the same spot. Detail and fine pieces only,
-- no collisions, no map sketch, no clearing of its own (the anchors' clearings come from AshenGen dataClearings; the
-- Wastes' terrain is frozen). Called last in AshenGen.all. Pure.

local AreaTypes = require("../../Data/Areas/Types")
local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Quest = {}

type Build = Kit.Build
type BP = Kit.BP

-- Anchor id -> prop kind.
local PROPS: { [string]: string } = {
	ash_cairn_1 = "basaltRubble",
	ash_cairn_2 = "basaltRubble",
	ash_cairn_3 = "basaltRubble",
	ash_well_1 = "buriedWell",
	ash_well_2 = "buriedWell",
	ash_well_3 = "buriedWell",
	ash_spring_stones = "flatStones",
	ash_columns_sample = "columnStump",
	ash_wyvern_lookout = "stoneHeap",
}

-- How far along the anchor's local +Z its prop stands (the client effects use the same offset).
Quest.SIDE_OFFSET = 1.8

local SULPHUR = { c = Props.SULPHUR, m = "Sand" }

local BUILD: { [string]: (bp: BP) -> () } = {
	-- loose basalt lumps where a warning cairn should stand (the cairn of the effect rises from them)
	basaltRubble = function(bp)
		bp:rbox(1.3, 0.6, 1.1, -0.6, 0.2, 0.3, 8, 25, -6, o(Props.basalt, "detail", { col = false }))
		bp:rbox(0.9, 0.5, 0.8, 0.8, 0.15, -0.4, -10, 70, 4, o(Props.basalt, "detail", { col = false }))
		bp:rbox(0.6, 0.35, 0.5, 0.3, 0.12, 0.9, 5, 140, 12, o(Props.basalt, "fine", { col = false }))
	end,
	-- an old well choked with sand: a ring of half-buried stones round a low mound
	buriedWell = function(bp)
		for k = 0, 6 do
			local a = k / 7 * math.pi * 2
			bp:rbox(
				0.8,
				0.45,
				0.6,
				math.cos(a) * 1.8,
				0.1,
				math.sin(a) * 1.8,
				0,
				math.deg(-a),
				(k % 3) * 4,
				o(Props.ashDark, if k % 2 == 0 then "detail" else "fine", { col = false })
			)
		end
		bp:add("ball", 2.6, 0.6, 2.6, 0, 0.05, 0, 0, 0, 0, o(Props.darkSand, "detail", { col = false }))
	end,
	-- three flat stones on the sulphur rim, a yellow crust between them
	flatStones = function(bp)
		for k = 0, 2 do
			local a = k * 2.1
			bp:rbox(
				1.5,
				0.25,
				1.1,
				math.cos(a) * 0.9,
				0.1,
				math.sin(a) * 0.9,
				0,
				k * 40,
				2,
				o(Props.ash, "detail", { col = false })
			)
		end
		bp:rbox(2.4, 0.06, 1.8, 0, 0.02, 0, 0, 15, 0, o(SULPHUR, "fine", { col = false }))
	end,
	-- the cracked stump of a basalt column (1.2 x 2.4 x 1.2) and the shard broken off its top
	columnStump = function(bp)
		bp:add("cyl", 2.4, 1.2, 1.2, 0, 1.2, 0, 0, 30, 90, o(Props.basalt, "detail", { col = false }))
		bp:rbox(0.08, 1.6, 0.05, 0.2, 1.3, -0.6, 0, 0, 12, o(Props.soot, "fine", { col = false }))
		bp:rbox(0.9, 0.45, 0.7, 1.2, 0.2, 0.5, 12, 40, 18, o(Props.basalt, "detail", { col = false }))
	end,
	-- a heap of four rust-red stones at the foot of the spire (the marker stick of the effect stands in it)
	stoneHeap = function(bp)
		bp:rbox(1.5, 0.6, 1.3, 0, 0.25, 0, 0, 10, 0, o(Props.rust, "detail", { col = false }))
		bp:rbox(1.1, 0.5, 1, 0.1, 0.75, -0.1, 4, 50, -3, o(Props.rust, "detail", { col = false }))
		bp:rbox(0.8, 0.4, 0.7, -0.1, 1.15, 0, -5, 95, 6, o(Props.rust, "fine", { col = false }))
		bp:rbox(0.5, 0.3, 0.45, 0, 1.45, 0.05, 0, 130, 0, o(Props.rust, "fine", { col = false }))
	end,
}

-- The prop kind of an anchor (nil: none).
function Quest.kindOf(anchorId: string): string?
	return PROPS[anchorId]
end

-- Where the prop of an anchor stands (map x, z), nil when it has none.
function Quest.spotOf(anchor: AreaTypes.QuestAnchor): (number?, number?)
	if not PROPS[anchor.id] then
		return nil, nil
	end
	return Kit.toWorld(anchor.x, anchor.z, anchor.rot or 0, 0, Quest.SIDE_OFFSET)
end

-- One Build per anchor of PROPS; an anchor of the table missing from the map data is an error naming it.
function Quest.all(env: Env.Env, out: { Build })
	local ids: { string } = {}
	for id in PROPS do
		table.insert(ids, id)
	end
	table.sort(ids)
	local anchors: { AreaTypes.QuestAnchor } = env.areas.questAnchors or {}
	for _, id in ids do
		local anchor: AreaTypes.QuestAnchor? = nil
		for _, a in anchors do
			if a.id == id then
				anchor = a
			end
		end
		local a = assert(anchor, `AshenGen/Quest: no quest anchor {id}`)
		local x, z = Quest.spotOf(a)
		local b = Kit.build(env.ctx, `QuestProp_{id}`, "questprop", x :: number, z :: number, a.rot or 0)
		BUILD[PROPS[id]](b.bp)
		table.insert(out, b)
	end
end

return Quest
