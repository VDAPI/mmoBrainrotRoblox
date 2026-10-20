--!strict
-- W30: how an owner's NPC model (ReplicatedStorage.Assets.Npcs.<id>, NpcService.Figure) is fitted to the R15 figure it
-- replaces. Pure: NpcService passes the heights and the model's optional attributes. The model gets the figure's
-- height (times its own "Scale" attribute: a dwarf 0.85, a big smith 1.1) and turns by its "Yaw" attribute (degrees)
-- when the export faces another way than the figure.

local NpcAssetFit = {}

-- A model attribute outside these bounds is ignored (a typo must not make a giant or a speck).
NpcAssetFit.SCALE_MIN = 0.5
NpcAssetFit.SCALE_MAX = 2

-- Factor for Model:ScaleTo (times the current scale) that makes a model `modelHeight` studs tall as tall as the
-- figure; nil for a model without height (empty or flat: the figure stays).
function NpcAssetFit.scale(modelHeight: number, figureHeight: number, extra: any): number?
	if modelHeight <= 0.01 or figureHeight <= 0 then
		return nil
	end
	local factor = 1
	if type(extra) == "number" and extra >= NpcAssetFit.SCALE_MIN and extra <= NpcAssetFit.SCALE_MAX then
		factor = extra
	end
	return figureHeight * factor / modelHeight
end

-- Turn of the model in radians from its "Yaw" attribute (degrees; anything else = 0).
function NpcAssetFit.yaw(attribute: any): number
	if type(attribute) == "number" and attribute == attribute and math.abs(attribute) <= 360 then
		return math.rad(attribute)
	end
	return 0
end

return NpcAssetFit
