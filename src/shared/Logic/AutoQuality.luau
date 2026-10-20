--!strict
-- W29 (docs/wyglad/STAN-W.md, W01 "Niedokończone"): the graphics level a device gets on its first entry, before the
-- player picks one in the menu (settings.qualityPicked). A touch-only device with a short side under
-- Config.Graphics.phoneShortSide pixels is a phone (low), a larger touch-only screen a tablet (medium); anything with a
-- keyboard keeps the default. Pure.

local Config = require("../Config")

local AutoQuality = {}

-- The level to switch to, or nil to keep the current one.
function AutoQuality.pick(touchOnly: boolean, shortSide: number): string?
	if not touchOnly then
		return nil
	end
	return if shortSide < Config.Graphics.phoneShortSide then "low" else "medium"
end

return AutoQuality
