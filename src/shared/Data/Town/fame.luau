--!strict
-- Hand-placed Hall of Fame by the town hall (S124, DESIGN-17 §5), next to the generated plan (city.luau is generated,
-- do not edit it). `board` = the double notice board, `plinths` = statue plinths in Data/Leaderboards.TOWN.plinths
-- order (left to right as seen from the market); S128 / S130 append arena and tournament plinths. x, z and facing
-- like city.npcs (facing 180 looks into the market square). tests/town.spec checks open ground, distance and reach.

export type Spot = { x: number, z: number, facing: number }
export type Fame = { board: Spot, plinths: { Spot } }

local fame: Fame = {
	-- on the north side of the market, east of the banker (56, -72) and west of the mouth of Ulica Leśna (84, -78)
	board = { x = 72, z = -66, facing = 180 },
	-- two plinths on each side, a step into the square, leaving the view of the board open
	plinths = {
		{ x = 58, z = -56, facing = 180 },
		{ x = 64, z = -56, facing = 180 },
		{ x = 80, z = -56, facing = 180 },
		{ x = 86, z = -56, facing = 180 },
	},
}

return fame
