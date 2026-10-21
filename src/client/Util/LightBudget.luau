--!strict
-- W29: the surface light budget (Config.Graphics.levels[*].lights, Logic/GraphicsLevel.nearest). Two owners decide
-- whether a PointLight of a Build shines: the one that wants it on (TownFxController: city and road lamps only at
-- night; every other light is wanted from the start) and the budget (RegionLightController: only the nearest few of
-- the wanted lights). Both write through here, so `Enabled` is always `wanted and not capped`.

local LightBudget = {}

local wanted: { [PointLight]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local capped: { [PointLight]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function apply(light: PointLight)
	local on = wanted[light] ~= false and not capped[light]
	if light.Enabled ~= on then
		light.Enabled = on
	end
end

-- The owner's wish (lamps: night).
function LightBudget.SetWanted(light: PointLight, on: boolean)
	wanted[light] = on
	apply(light)
end

-- Whether the light's owner wants it on (a light nobody spoke for is wanted).
function LightBudget.Wanted(light: PointLight): boolean
	return wanted[light] ~= false
end

-- The budget's verdict (true = kept off).
function LightBudget.SetCapped(light: PointLight, off: boolean)
	capped[light] = off
	apply(light)
end

function LightBudget.Forget(light: PointLight)
	wanted[light] = nil
	capped[light] = nil
end

return LightBudget
