--!strict
-- S156 (owner 2026-10-20: "let me move some HUD elements, the quests on the right, and make a long list scroll and the
-- window resizable"): the player's own HUD layout, saved in `account.settings.hud` (SetSetting "hud", SettingsService).
-- One entry per movable element: `x`, `y` = the top-left corner as a fraction of the screen (so a layout survives a
-- window resize), `w`, `h` = width and the highest height in virtual pixels (only for elements with `resize`). No entry
-- = the element's built-in place. Pure.
-- Owner 2026-10-21 ("the invasion covers the map, let me move it around the whole screen like the quests"): the event
-- panels (world event, world boss, Blood Moon, tournament) move the same way; their corner grip scales the whole panel
-- (`s`, a UIScale factor in the element's minS..maxS), since their height follows their content.

local HudLayout = {}

export type Entry = { x: number, y: number, w: number?, h: number?, s: number? }
export type ElementDef = {
	resize: boolean,
	minW: number,
	maxW: number,
	minH: number,
	maxH: number,
	minS: number?, -- a scaled element (`s` instead of `w` and `h`)
	maxS: number?,
}

-- An event panel: moved by its grip, scaled by its corner grip (no `w` / `h`).
local PANEL: ElementDef =
	table.freeze({ resize = false, minW = 0, maxW = 0, minH = 0, maxH = 0, minS = 0.7, maxS = 1.5 })

-- The movable elements (the Hud module reads its entry by this id).
HudLayout.ELEMENTS = table.freeze({
	questTracker = table.freeze({ resize = true, minW = 240, maxW = 560, minH = 120, maxH = 1000 }),
	worldEvent = PANEL, -- Hud/WorldEventPanel (the Invasion and the other world events)
	worldBoss = PANEL, -- Hud/WorldBossPanel
	bloodMoon = PANEL, -- Hud/BloodMoonPanel
	tourney = PANEL, -- Hud/TourneyPanel
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
			if key ~= "x" and key ~= "y" and key ~= "w" and key ~= "h" and key ~= "s" then
				return false
			end
		end
		if entry.s ~= nil then
			local minS, maxS = def.minS, def.maxS
			if not minS or not maxS or not finite(entry.s) or entry.s < minS or entry.s > maxS then
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

-- The scale of an element clamped to its range (1 for an element without one).
function HudLayout.clampScale(id: string, s: number): number
	local def = HudLayout.ELEMENTS[id]
	if not def or not def.minS or not def.maxS then
		return 1
	end
	return math.clamp(s, def.minS, def.maxS)
end

-- The scale an entry gives its element (1 without one).
function HudLayout.scaleOf(entry: Entry?): number
	return if entry and type(entry.s) == "number" then entry.s else 1
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

-- The entry for a corner at (x, y) virtual pixels and an optional size (or scale, rounded to hundredths), as
-- fractions of the screen.
function HudLayout.entryAt(
	x: number,
	y: number,
	screenW: number,
	screenH: number,
	w: number?,
	h: number?,
	s: number?
): Entry
	local entry: Entry = {
		x = math.clamp(x / math.max(1, screenW), 0, 1),
		y = math.clamp(y / math.max(1, screenH), 0, 1),
	}
	if w and h then
		entry.w = math.floor(w + 0.5)
		entry.h = math.floor(h + 0.5)
	end
	if s then
		entry.s = math.floor(s * 100 + 0.5) / 100
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
