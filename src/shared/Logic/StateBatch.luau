--!strict
-- Picks which cached client-state entries a batch of diffs touches (S134f). The client mirror applies every
-- diff first and then sets each touched entry exactly once, so a batch of 60 inventory slot diffs refreshes the
-- whole-inventory value once instead of 60 times. A snapshot (empty path) touches every entry.

local PathOps = require("./PathOps")
local Types = require("../Types")

type Path = Types.Path
type Diff = Types.Diff

local StateBatch = {}

-- Paths overlap when one is a prefix of the other (a write to either affects the other).
function StateBatch.overlaps(a: Path, b: Path): boolean
	return PathOps.startsWith(a, b) or PathOps.startsWith(b, a)
end

-- Indexes (ascending, no repeats) of the cache paths that overlap at least one diff path of the batch.
function StateBatch.touched(cachePaths: { Path }, diffs: { Diff }): { number }
	local out = {}
	for i, path in cachePaths do
		for _, diff in diffs do
			if StateBatch.overlaps(path, diff.path) then
				table.insert(out, i)
				break
			end
		end
	end
	return out
end

return StateBatch
