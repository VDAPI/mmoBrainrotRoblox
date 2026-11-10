--!strict
-- What the release of a press on a potion bar slot does (UI/Screens/Hud/PotionBar). Owner 2026-11-10: an ordinary
-- potion is drunk at full too and is used up, so a press meant to look or to assign must never drink one. A plain tap
-- or click drinks. A press held long enough for the slot's tooltip or quality picker never drinks on its release,
-- touch and mouse alike (the quest tracker's rows skip such a release too). The press that dropped a potion from the
-- backpack onto the slot only assigned it, however long it lasted (UI/DragDrop.PressDropped). A tap on a slot whose
-- picker stood open when the press began closes the picker, and so does a click there however slow. The potion keys
-- drink without passing here. Pure (Lune): tests/potionpress.spec.

local PotionPress = {}

-- Seconds of hold after which the release no longer drinks: a touch held this long shows the slot's tooltip
-- (Components/Tooltip LONG_PRESS), so the player was reading, not drinking.
PotionPress.TIP_HOLD = 0.45
-- Seconds a finger rests on a slot before its quality picker opens (touch; the right click opens it on PC).
PotionPress.PICKER_HOLD = 0.5

export type Press = {
	heldFor: number, -- seconds from the press to its release
	dropped: boolean, -- the press dropped an item onto the slot (DragDrop.PressDropped)
	pickerOpen: boolean, -- the slot's quality picker stood open when the press began
	touch: boolean, -- a finger made the press (false: the left mouse button, or an activation without a press)
}

-- "drink": use the slot's potion; "close": close the slot's picker; "none": nothing (a long press keeps the tooltip
-- or the picker it opened, a drop has already assigned the potion).
export type Action = "drink" | "close" | "none"

function PotionPress.release(press: Press): Action
	-- A click on an open picker closes it however slow it was (2026-11-10 review): holding the mouse button opens
	-- nothing, as the tooltip follows the hover and the right click opens the picker. A finger held there opens the
	-- picker again, so the hold check below keeps it open.
	if press.pickerOpen and not press.touch then
		return "close"
	end
	if press.heldFor >= PotionPress.TIP_HOLD then
		return "none"
	end
	if press.pickerOpen then
		return "close"
	end
	if press.dropped then
		return "none"
	end
	return "drink"
end

return PotionPress
