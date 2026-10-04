--!strict
-- Path-based reads and writes on nested tables. Shared by the server state service (which mutates
-- profile data and emits diffs) and the client state mirror (which applies those diffs).

local Types = require("../Types")

type Path = Types.Path
type Diff = Types.Diff

local PathOps = {}

function PathOps.get(root: any, path: Path): any
	local node = root
	for _, key in path do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return node
end

-- Returns the parent table of the last key, creating missing intermediate tables.
local function parentOf(root: any, path: Path): (any, Types.PathKey)
	assert(#path > 0, "PathOps: empty path")
	local node = root
	for i = 1, #path - 1 do
		local key = path[i]
		local nextNode = node[key]
		if nextNode == nil then
			nextNode = {}
			node[key] = nextNode
		end
		assert(type(nextNode) == "table", `PathOps: '{tostring(key)}' is not a table`)
		node = nextNode
	end
	return node, path[#path]
end

-- Sets the value at path (nil deletes).
function PathOps.set(root: any, path: Path, value: any)
	local parent, key = parentOf(root, path)
	parent[key] = value
end

-- Inserts value into the array at path (appends when index is nil). Returns the index used.
function PathOps.insert(root: any, path: Path, value: any, index: number?): number
	local array = PathOps.get(root, path)
	if array == nil then
		array = {}
		PathOps.set(root, path, array)
	end
	assert(type(array) == "table", "PathOps.insert: target is not a table")
	local at = index or (#array + 1)
	table.insert(array, at, value)
	return at
end

-- Removes the element at index from the array at path. Returns the removed value.
function PathOps.remove(root: any, path: Path, index: number): any
	local array = PathOps.get(root, path)
	assert(type(array) == "table", "PathOps.remove: target is not a table")
	return table.remove(array, index)
end

function PathOps.apply(root: any, diff: Diff)
	if diff.op == "set" then
		PathOps.set(root, diff.path, diff.value)
	elseif diff.op == "insert" then
		PathOps.insert(root, diff.path, diff.value, diff.index)
	elseif diff.op == "remove" then
		PathOps.remove(root, diff.path, (assert(diff.index, "remove diff without index")))
	else
		error(`PathOps.apply: unknown op {tostring(diff.op)}`)
	end
end

-- True when `prefix` is a prefix of (or equal to) `path`.
function PathOps.startsWith(path: Path, prefix: Path): boolean
	if #prefix > #path then
		return false
	end
	for i, key in prefix do
		if path[i] ~= key then
			return false
		end
	end
	return true
end

-- Stable string form used as a cache key ("character.stats.str").
function PathOps.key(path: Path): string
	local parts = table.create(#path)
	for i, key in path do
		parts[i] = tostring(key)
	end
	return table.concat(parts, ".")
end

return PathOps
