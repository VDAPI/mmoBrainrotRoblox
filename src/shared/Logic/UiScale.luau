--!strict
-- The adaptive UI scale (UI/Scale, ARCHITECTURE §9) as pure numbers, so tests can lay the HUD out on real screens.
-- Owner 2026-10-22 (Studio, a 1456 x 776 viewport: the quest tracker ran 26 px into the PvP toggle): the HUD's layer
-- (Screens) keeps clear of Roblox's top bar (CoreUISafeInsets), so it is shorter than the screen; the HUD column is
-- laid out in that layer's size (`hud`), the size the corner buttons anchored to its bottom see.

local UiScale = {}

UiScale.BASE_PC = table.freeze({ x = 1920, y = 1080 })
UiScale.BASE_TOUCH = table.freeze({ x = 1280, y = 720 })
UiScale.MIN_PC = 0.6
UiScale.MIN_TOUCH = 44 / 52 -- Theme.Size.MinTouch / Theme.Size.ButtonHeight
UiScale.MAX = 1.5
-- Roblox's top bar in real pixels (the 2024 top bar; the older one was 36).
UiScale.TOP_BAR = 58

-- The UI scale of a w x h screen (real pixels).
function UiScale.factor(w: number, h: number, touch: boolean): number
	local base = if touch then UiScale.BASE_TOUCH else UiScale.BASE_PC
	local raw = math.min(w / base.x, h / base.y)
	return math.clamp(raw, if touch then UiScale.MIN_TOUCH else UiScale.MIN_PC, UiScale.MAX)
end

-- The HUD layer of a w x h screen in virtual pixels: the screen less `inset` real pixels on top (the top bar), over
-- the scale of the whole screen.
function UiScale.hud(w: number, h: number, touch: boolean, inset: number): (number, number)
	local k = UiScale.factor(w, h, touch)
	return w / k, (h - inset) / k
end

return UiScale
