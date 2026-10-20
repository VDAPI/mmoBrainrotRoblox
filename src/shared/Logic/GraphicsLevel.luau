--!strict
-- W29: what a graphics level (settings.quality: low / medium / high, Config.Graphics.levels) changes on the client,
-- in one place for every controller: the level's table, the "World detail" level it allows (low caps the player's
-- setting at "low"), which filler trees and undergrowth of the client detail it keeps (by position, the same on every
-- machine), how many decorations a chunk tries, and which lights stay on under the light budget. Pure.

local Config = require("../Config")

local GraphicsLevel = {}

export type Level = typeof(Config.Graphics.levels.high)

local ORDER = { low = 1, mid = 2, high = 3 } :: { [string]: number }

-- The table of a quality value (unknown or nil: Config.Graphics.default).
function GraphicsLevel.get(quality: any): Level
	local levels = Config.Graphics.levels :: { [string]: Level }
	local key = if type(quality) == "string" and levels[quality] then quality else Config.Graphics.default
	return levels[key] or levels.high
end

-- The "World detail" level the client uses: the player's setting (settings.decor: low / mid / high, default mid),
-- lowered to the graphics level's `detail` cap.
function GraphicsLevel.detail(quality: any, decor: any): string
	local setting = if decor == "low" or decor == "high" then decor else "mid"
	local cap = GraphicsLevel.get(quality).detail
	if cap and ORDER[cap] and ORDER[cap] < ORDER[setting] then
		return cap
	end
	return setting
end

-- Decorations a chunk tries at this level (DecorController: `base` tries at full density; the first ones are kept,
-- so a lower level shows a subset of the same layout).
function GraphicsLevel.decorTries(quality: any, base: number): number
	return math.max(0, math.floor(base * GraphicsLevel.get(quality).decor + 0.5))
end

-- Deterministic 0..1 value of a point (the same on every machine and every visit).
local function hash01(x: number, z: number): number
	local h = math.floor(x * 7.31 + 0.5) * 73856093 + math.floor(z * 5.17 + 0.5) * 19349663
	h = (h % 2147483647 + 2147483647) % 2147483647
	h = (h * 48271) % 2147483647
	return h / 2147483647
end
GraphicsLevel.hash01 = hash01

-- Whether the client builds a kit slot of the detail level (`key` "tree:<kind>" = a filler tree, "under:<kind>" =
-- undergrowth) at map-relative (x, z) at this level. Other slots and every server (shell) slot always stay.
function GraphicsLevel.keepSlot(quality: any, key: string, lod: string, x: number, z: number): boolean
	if lod == "shell" then
		return true
	end
	local level = GraphicsLevel.get(quality)
	local share = if string.sub(key, 1, 5) == "tree:"
		then level.fill
		elseif string.sub(key, 1, 6) == "under:" then level.under
		else 1
	if share >= 1 then
		return true
	end
	return hash01(x, z) < share
end

export type Candidate = { d: number, on: boolean? }

-- The light budget: of `list` (distance to the camera `d`, `on` = on in the last pass), which stay on when at most
-- `limit` may (nil = all). The nearest win; a light that is on counts `hysteresis` studs nearer, so two lights at
-- the edge do not swap every pass. Returns a set of indices into `list`.
function GraphicsLevel.nearest(list: { Candidate }, limit: number?, hysteresis: number): { [number]: boolean }
	local keep: { [number]: boolean } = {}
	if not limit or #list <= limit then
		for i in list do
			keep[i] = true
		end
		return keep
	end
	local order = table.create(#list, 0)
	for i in list do
		order[i] = i
	end
	table.sort(order, function(a, b)
		local da = list[a].d - (if list[a].on then hysteresis else 0)
		local db = list[b].d - (if list[b].on then hysteresis else 0)
		if da == db then
			return a < b
		end
		return da < db
	end)
	for k = 1, math.min(limit, #order) do
		keep[order[k]] = true
	end
	return keep
end

return GraphicsLevel
