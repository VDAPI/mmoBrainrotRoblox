--!strict
-- Owner 2026-11-10 (a potion drunk at full is used up): what the release of a press on a potion bar slot does
-- (Logic/PotionPress). Only a plain tap or click drinks: never a long press (tooltip, quality picker), the press that
-- dropped a potion onto the slot, or a tap or click that closes the slot's open picker.
local fs = require("@lune/fs")

local T = require("./Test")
local PotionPress = require("../src/shared/Logic/PotionPress")

local describe, it, expect = T.describe, T.it, T.expect

-- One press by a finger (touch) or by the left mouse button.
local function releaseBy(touch: boolean, heldFor: number, dropped: boolean?, pickerOpen: boolean?): string
	return PotionPress.release({
		heldFor = heldFor,
		dropped = dropped == true,
		pickerOpen = pickerOpen == true,
		touch = touch,
	})
end

-- The same press by finger and by mouse, which must agree ("touch X, mouse Y" when they do not).
local function release(heldFor: number, dropped: boolean?, pickerOpen: boolean?): string
	local byTouch = releaseBy(true, heldFor, dropped, pickerOpen)
	local byMouse = releaseBy(false, heldFor, dropped, pickerOpen)
	return if byTouch == byMouse then byTouch else `touch {byTouch}, mouse {byMouse}`
end

local function has(source: string, text: string): boolean
	return string.find(source, text, 1, true) ~= nil
end

describe("PotionPress: the release of a press on a potion slot", function()
	it("a plain tap or click drinks", function()
		expect(release(0)).toBe("drink")
		expect(release(0.2)).toBe("drink")
		expect(release(PotionPress.TIP_HOLD - 0.01)).toBe("drink")
	end)

	it("a press held for the tooltip or the picker never drinks and keeps what it opened", function()
		expect(release(PotionPress.TIP_HOLD)).toBe("none")
		expect(release(PotionPress.PICKER_HOLD)).toBe("none")
		expect(release(5)).toBe("none")
		-- a finger held on a slot whose picker stood open opens it again, so the release leaves it open
		expect(releaseBy(true, PotionPress.PICKER_HOLD, false, true)).toBe("none")
		expect(releaseBy(true, PotionPress.PICKER_HOLD, true, true)).toBe("none")
	end)

	it("the press that dropped a potion onto the slot never drinks, however long it lasted", function()
		expect(release(0, true)).toBe("none")
		expect(release(0.35, true)).toBe("none") -- past the old 0.3 s window after a drop
		expect(release(PotionPress.PICKER_HOLD, true)).toBe("none")
	end)

	it("a tap or click on a slot whose picker is open closes the picker instead of drinking", function()
		expect(release(0, false, true)).toBe("close")
		expect(release(0.2, true, true)).toBe("close")
	end)

	it("a slow click on an open picker closes it too, as a held mouse button opens nothing", function()
		expect(releaseBy(false, 0.6, false, true)).toBe("close")
		expect(releaseBy(false, 5, true, true)).toBe("close")
		-- the finger held as long opened the picker again: its release keeps it (above)
		expect(releaseBy(true, 0.6, false, true)).toBe("none")
	end)

	it("the hold that skips the drink is the tooltip's, and the picker opens only later", function()
		expect(PotionPress.TIP_HOLD <= PotionPress.PICKER_HOLD).toBe(true)
		local tooltip = fs.readFile("src/client/UI/Components/Tooltip.luau")
		expect(tonumber(string.match(tooltip, "\nlocal LONG_PRESS = ([%d%.]+)"))).toBe(PotionPress.TIP_HOLD)
	end)

	it("the potion bar decides through it and the drop mark of its own press", function()
		local bar = fs.readFile("src/client/UI/Screens/Hud/PotionBar.luau")
		expect(has(bar, "PotionPress.release(")).toBe(true)
		expect(has(bar, "DragDrop.PressDropped(slotId)")).toBe(true)
		expect(has(bar, "task.delay(PotionPress.PICKER_HOLD,")).toBe(true)
		-- each press keeps its device, which decides whether a slow press closes an open picker
		expect(has(bar, "touch = touch }")).toBe(true)
		-- no time window after the last drop: a slow tap that assigned a potion passed it and drank
		expect(has(bar, "LastDropAt")).toBe(false)
		local dragDrop = fs.readFile("src/client/UI/DragDrop.luau")
		expect(has(dragDrop, "function DragDrop.PressDropped(slotId: string)")).toBe(true)
		expect(has(dragDrop, "pressDropped[to] = true")).toBe(true)
	end)
end)
