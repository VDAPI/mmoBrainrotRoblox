--!strict
-- S156 (owner 2026-10-20: "let me move some HUD elements, the quests on the right, and make a long list scroll and the
-- window resizable"): the player's own HUD layout, saved in `account.settings.hud` (SetSetting "hud", SettingsService).
-- One entry per movable element: `x`, `y` = the top-left corner as a fraction of the screen (so a layout survives a
-- window resize), `w`, `h` = width and the highest height in virtual pixels (only for elements with `resize`). No entry
-- = the element's built-in place. Pure.

local HudLayout = {}

export type Entry = { x: number, y: number, w: number?, h: number? }
export type ElementDef = {
	resize: boolean,
	minW: number,
	maxW: number,
	minH: number,
	maxH: number,
}

-- The movable elements (the Hud module reads its entry by this id).
HudLayout.ELEMENTS = table.freeze({
	questTracker = table.freeze({ resize = true, minW = 240, maxW = 560, minH = 120, maxH = 1000 }),
}) :: { [string]: ElementDef }

-- Part of an element (virtual pixels) that must stay on the screen when it is dragged off an edge.
HudLayout.KEEP = 60

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Whether `value` is a layout a client may save: known elements only, fractions in 0..1, sizes in the element's range.
function HudLayout.valid(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for id, entry in value do
		local def = if type(id) == "string" then HudLayout.ELEMENTS[id] else nil
		if not def or type(entry) ~= "table" then
			return false
		end
		if not finite(entry.x) or not finite(entry.y) or entry.x < 0 or entry.x > 1 or entry.y < 0 or entry.y > 1 then
			return false
		end
		for key in entry do
			if key ~= "x" and key ~= "y" and key ~= "w" and key ~= "h" then
				return false
			end
		end
		if entry.w ~= nil or entry.h ~= nil then
			if not def.resize or not finite(entry.w) or not finite(entry.h) then
				return false
			end
			if entry.w < def.minW or entry.w > def.maxW or entry.h < def.minH or entry.h > def.maxH then
				return false
			end
		end
	end
	return true
end

-- The size of an element clamped to its range.
function HudLayout.clampSize(id: string, w: number, h: number): (number, number)
	local def = HudLayout.ELEMENTS[id]
	return math.clamp(w, def.minW, def.maxW), math.clamp(h, def.minH, def.maxH)
end

-- The top-left corner (virtual pixels) of an element of width `w` on a screen of `screenW` x `screenH`, kept so that
-- at least HudLayout.KEEP pixels (and the header) stay on the screen.
function HudLayout.place(entry: Entry, w: number, screenW: number, screenH: number): (number, number)
	local x = entry.x * screenW
	local y = entry.y * screenH
	x = math.clamp(x, HudLayout.KEEP - w, math.max(0, screenW - HudLayout.KEEP))
	y = math.clamp(y, 0, math.max(0, screenH - HudLayout.KEEP))
	return x, y
end

-- The entry for a corner at (x, y) virtual pixels and an optional size, as fractions of the screen.
function HudLayout.entryAt(x: number, y: number, screenW: number, screenH: number, w: number?, h: number?): Entry
	local entry: Entry = {
		x = math.clamp(x / math.max(1, screenW), 0, 1),
		y = math.clamp(y / math.max(1, screenH), 0, 1),
	}
	if w and h then
		entry.w = math.floor(w + 0.5)
		entry.h = math.floor(h + 0.5)
	end
	return entry
end

-- A copy of `layout` with element `id` set to `entry` (nil = back to the built-in place).
function HudLayout.with(layout: any, id: string, entry: Entry?): { [string]: Entry }
	local out: { [string]: Entry } = {}
	if type(layout) == "table" then
		for k, v in layout do
			if HudLayout.ELEMENTS[k] and type(v) == "table" then
				out[k] = table.clone(v)
			end
		end
	end
	(out :: any)[id] = entry
	return out
end

return HudLayout
