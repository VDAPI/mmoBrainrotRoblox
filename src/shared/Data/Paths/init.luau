--!strict
-- Class paths (ROZWOJ 2.2-2.4, 3.1, S57): the shared row layout and every path of every class. Rules in Logic/Paths.

local Classes = require("./Classes")
local Cleric = require("@self/Cleric")
local Hunter = require("@self/Hunter")
local Mage = require("@self/Mage")
local Types = require("@self/Types")
local Warrior = require("@self/Warrior")

export type Scaled = Types.Scaled
export type WeaponReq = Types.WeaponReq
export type NodeKind = Types.NodeKind
export type PathNode = Types.PathNode
export type PathRow = Types.PathRow
export type ReferenceBuild = Types.ReferenceBuild
export type Role = Types.Role
export type PathDef = Types.PathDef
export type RowKind = Types.RowKind
export type RowDef = Types.RowDef

-- ROZWOJ 2.2: row levels and the ranks needed in the lower rows of the same path. Rows 3, 6, 9 pick 1 of 2 nodes,
-- row 8 is the capstone (one node, rank 1), row 11 its upgrade (one node, rank 2). In a class with two paths rows
-- 2, 5 and 10 get one extra node (twoPathExtra).
local ROWS: { RowDef } = {
	{ level = 10, need = 0, kind = "normal" },
	{ level = 15, need = 2, kind = "normal", twoPathExtra = true },
	{ level = 20, need = 4, kind = "choice" },
	{ level = 26, need = 6, kind = "normal" },
	{ level = 33, need = 9, kind = "normal", twoPathExtra = true },
	{ level = 40, need = 12, kind = "choice" },
	{ level = 48, need = 15, kind = "normal" },
	{ level = 60, need = 18, kind = "capstone" },
	{ level = 70, need = 21, kind = "choice" },
	{ level = 80, need = 24, kind = "normal", twoPathExtra = true },
	{ level = 90, need = 28, kind = "upgrade" },
}

local byClassFile: { [string]: { PathDef } } = {
	Warrior = Warrior,
	Hunter = Hunter,
	Mage = Mage,
	Cleric = Cleric,
}

local list: { PathDef } = {}
local byId: { [string]: PathDef } = {}
local byClass: { [string]: { PathDef } } = {}
local nodeIds: { [string]: boolean } = {}

for _, classId in Classes.order do
	local own = table.clone(byClassFile[classId] or {})
	table.sort(own, function(a: PathDef, b: PathDef): boolean
		return a.order < b.order
	end)
	byClass[classId] = own
	for _, path in own do
		assert(byId[path.id] == nil, `Paths: duplicate id {path.id}`)
		assert(path.class == classId, `Paths: {path.id} is in the {classId} file but has class {path.class}`)
		assert(#path.rows == #ROWS, `Paths: {path.id} needs {#ROWS} rows`)
		byId[path.id] = path
		table.insert(list, path)
		for _, row in path.rows do
			for _, node in row.nodes do
				assert(nodeIds[node.id] == nil, `Paths: duplicate node id {node.id}`)
				nodeIds[node.id] = true
			end
		end
	end
end

return table.freeze({
	ROWS = ROWS,
	DIP_ROWS = 2, -- rows open in every path (ROZWOJ 2.2); the rest only in the main path
	DIP_SCALE = 1 / 3, -- team effect strength of rows 1..DIP_ROWS outside the main path
	list = list,
	byId = byId,
	byClass = byClass,
	get = function(id: string): PathDef?
		return byId[id]
	end,
})
