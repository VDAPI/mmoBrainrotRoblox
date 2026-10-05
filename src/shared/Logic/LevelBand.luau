--!strict
-- Level difference colour band (DESIGN §24, after the S17 tests): how dangerous a monster (or monster area)
-- is compared with the player. Used by monster plates, area banners and the map. Pure.

local LevelBand = {}

export type Band = "grey" | "green" | "white" | "yellow" | "red"

-- grey <= -10, green -9..-3, white -2..+2, yellow +3..+5, red > +5 (monster level minus player level).
function LevelBand.of(monsterLevel: number, playerLevel: number): Band
	local diff = monsterLevel - playerLevel
	if diff <= -10 then
		return "grey"
	elseif diff <= -3 then
		return "green"
	elseif diff <= 2 then
		return "white"
	elseif diff <= 5 then
		return "yellow"
	end
	return "red"
end

-- Hex colours of the bands (UI only).
LevelBand.COLORS = table.freeze({
	grey = "#8C8C8C",
	green = "#5FCF6B",
	white = "#F0ECE2",
	yellow = "#E8C83A",
	red = "#E0503F",
} :: { [Band]: string })

return LevelBand
