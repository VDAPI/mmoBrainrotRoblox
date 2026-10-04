--!strict
-- Client mirror of the server's per-player state tree (ARCHITECTURE §6).
-- State.Value({"character", "gold"}) returns a cached Fusion Value that updates when diffs touch it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PathOps = require(ReplicatedStorage.Shared.Logic.PathOps)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

type Path = Types.Path

local State = {
	-- (diffs | nil) after a snapshot (nil) or a batch of diffs was applied.
	Changed = Signal.new() :: any,
}

local scope = Fusion.scoped(Fusion)
local root: any = { slots = {}, session = { phase = "loading", dataMock = false } }
local cache: { [string]: { path: Path, value: Fusion.Value<any> } } = {}
local hasSnapshot = false

-- Paths overlap when one is a prefix of the other (a write to either affects the other).
local function overlaps(a: Path, b: Path): boolean
	return PathOps.startsWith(a, b) or PathOps.startsWith(b, a)
end

local function refresh(changed: Path?)
	for _, entry in cache do
		if changed == nil or overlaps(entry.path, changed) then
			entry.value:set(PathOps.get(root, entry.path))
		end
	end
end

function State.Value(path: Path): Fusion.Value<any>
	local key = PathOps.key(path)
	local entry = cache[key]
	if not entry then
		entry = { path = table.clone(path), value = scope:Value(PathOps.get(root, path)) }
		cache[key] = entry
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
	refresh(nil)
	State.Changed:Fire(nil)
end

function State.ApplyDiffs(diffs: { Types.Diff })
	for _, diff in diffs do
		PathOps.apply(root, diff)
	end
	for _, diff in diffs do
		refresh(diff.path)
	end
	State.Changed:Fire(diffs)
end

return State
