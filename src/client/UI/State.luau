--!strict
-- Client mirror of the server's per-player state tree (ARCHITECTURE §6).
-- State.Value({"character", "gold"}) returns a cached Fusion Value that updates when diffs touch it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PathOps = require(ReplicatedStorage.Shared.Logic.PathOps)
local Signal = require(ReplicatedStorage.Packages.Signal)
local StateBatch = require(ReplicatedStorage.Shared.Logic.StateBatch)
local Types = require(ReplicatedStorage.Shared.Types)

type Path = Types.Path
type Entry = { path: Path, value: Fusion.Value<any> }

local State = {
	-- (diffs | nil) after a snapshot (nil) or a batch of diffs was applied.
	Changed = Signal.new() :: any,
}

local scope = Fusion.scoped(Fusion)
local root: any = { slots = {}, session = { phase = "loading", dataMock = false } }
local cache: { [string]: Entry } = {}
-- The same entries in creation order, so a batch refresh visits them in a stable order (S134f).
local entries: { Entry } = {}
local entryPaths: { Path } = {}
local hasSnapshot = false

local function refreshAll()
	for _, entry in entries do
		entry.value:set(PathOps.get(root, entry.path))
	end
end

function State.Value(path: Path): Fusion.Value<any>
	local key = PathOps.key(path)
	local entry = cache[key]
	if not entry then
		local made: Entry = { path = table.clone(path), value = scope:Value(PathOps.get(root, path)) }
		cache[key] = made
		table.insert(entries, made)
		table.insert(entryPaths, made.path)
		return made.value
	end
	return entry.value
end

function State.Get(path: Path): any
	return PathOps.get(root, path)
end

function State.Root(): any
	return root
end

function State.HasSnapshot(): boolean
	return hasSnapshot
end

function State.ApplySnapshot(snapshot: any)
	root = snapshot
	if root.slots == nil then
		root.slots = {}
	end
	hasSnapshot = true
	refreshAll()
	State.Changed:Fire(nil)
end

function State.ApplyDiffs(diffs: { Types.Diff })
	for _, diff in diffs do
		PathOps.apply(root, diff)
	end
	-- One set per touched entry per batch (S134f: selling 60 items used to set the inventory value 60 times).
	for _, index in StateBatch.touched(entryPaths, diffs) do
		local entry = entries[index]
		entry.value:set(PathOps.get(root, entry.path))
	end
	State.Changed:Fire(diffs)
end

return State
