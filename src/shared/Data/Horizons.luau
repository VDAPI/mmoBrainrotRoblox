--!strict
-- W12: the land beyond the edge of a map (docs/wyglad/MAPY.md "Horyzont", docs/wyglad/mapy/miasto.md Z3): a ring of
-- silhouettes the client builds from parts (Logic/HorizonGen, client/Controllers/HorizonController), no collision, no
-- server parts, facing the neighbouring regions so the horizon tells which gate leads where, and no grey band where the
-- terrain ends. Looks only.
--
-- Angles are compass degrees around the map's centre: 0 = north (-Z), 90 = east (+X), 180 = south (+Z), 270 = west
-- (-X); an arc may pass 360 (from 315 to 405 = the north quarter). Distances in studs from the centre.

export type Range = { number } -- { min, max }

export type Arc = {
	from: number,
	to: number,
	kind: "hills" | "pines" | "rocks" | "peaks" | "walls",
	dist: Range,
	height: Range,
	color: string,
	color2: string, -- a second tone mixed in (lit tops, snow, darker rock)
	step: number, -- degrees between two silhouettes (smaller = denser)
}

export type Landmark = {
	model: string, -- Data/Kit model name in ReplicatedStorage.Assets.Kit (none = nothing drawn)
	deg: number,
	dist: number,
	height: number, -- studs the model is scaled to
	turn: number?, -- yaw in degrees
}

export type Horizon = {
	groundY: number, -- the height the silhouettes stand on (relative to the map's offset)
	-- a low band of land from `ground[1]` to `ground[2]` studs, in the colour of each arc, so the terrain's edge and
	-- the silhouettes meet without a gap
	ground: Range,
	groundColor: string, -- between the arcs and under them
	arcs: { Arc },
	landmarks: { Landmark },
}

local Horizons: { [string]: Horizon } = {
	-- Vaelthorn: east the golden hills of the Meadows, north the dark wall of the Duskwood with the Old Tree's crown,
	-- west the red rocks and the volcano of the Ashen Wastes, south the white Frostpeak (miasto.md Z3).
	city = {
		groundY = -4,
		ground = { 440, 1000 },
		groundColor = "#6E8743",
		arcs = {
			{
				from = 40,
				to = 140,
				kind = "hills",
				dist = { 600, 900 },
				height = { 45, 110 },
				color = "#8C9A48",
				color2 = "#C2A55A",
				step = 5,
			},
			{
				from = 315,
				to = 405,
				kind = "pines",
				dist = { 560, 760 },
				height = { 55, 95 },
				color = "#1E3020",
				color2 = "#2C4128",
				step = 1.6,
			},
			{
				from = 225,
				to = 315,
				kind = "rocks",
				dist = { 620, 900 },
				height = { 60, 150 },
				color = "#8A4A32",
				color2 = "#5C3324",
				step = 4,
			},
			{
				from = 140,
				to = 225,
				kind = "peaks",
				dist = { 700, 950 },
				height = { 170, 320 },
				color = "#8C939C",
				color2 = "#EEF2F4",
				step = 7,
			},
		},
		landmarks = {
			{ model = "desert_landmark_01", deg = 272, dist = 930, height = 300, turn = 90 },
			{ model = "forest_landmark_01", deg = 352, dist = 720, height = 150 },
		},
	},
	-- Whispering Meadows (laki.md 1.7 c): north beyond the forest the snowy border peaks (the "lord from the north"),
	-- north-east the dark wall of the Duskwood, west behind the gate the walls of Vaelthorn, south golden hills; the
	-- east is closed by the map's own mountains, beyond them higher grey rock.
	meadows = {
		groundY = -2,
		ground = { 820, 1500 },
		groundColor = "#7C8F45",
		arcs = {
			{
				from = 300,
				to = 395,
				kind = "peaks",
				dist = { 1250, 1480 },
				height = { 220, 380 },
				color = "#8A919A",
				color2 = "#F2F5F7",
				step = 6,
			},
			{
				from = 395,
				to = 440,
				kind = "pines",
				dist = { 920, 1120 },
				height = { 70, 120 },
				color = "#1C2C1E",
				color2 = "#283C26",
				step = 1.4,
			},
			{
				from = 80,
				to = 165,
				kind = "rocks",
				dist = { 1050, 1350 },
				height = { 90, 200 },
				color = "#7E7A72",
				color2 = "#5A5650",
				step = 5,
			},
			{
				from = 165,
				to = 255,
				kind = "hills",
				dist = { 950, 1300 },
				height = { 50, 120 },
				color = "#8E9A48",
				color2 = "#C8A85A",
				step = 6,
			},
			{
				from = 262,
				to = 292,
				kind = "walls",
				dist = { 1000, 1000 },
				height = { 34, 34 },
				color = "#B9AE98",
				color2 = "#8E8676",
				step = 1.6,
			},
			{
				from = 255,
				to = 300,
				kind = "hills",
				dist = { 1150, 1400 },
				height = { 40, 80 },
				color = "#7F9446",
				color2 = "#A9A256",
				step = 7,
			},
		},
		landmarks = {},
	},
}

return table.freeze({
	byMap = Horizons,
	get = function(mapId: string): Horizon?
		return Horizons[mapId]
	end,
})
