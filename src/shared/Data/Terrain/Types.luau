--!strict
-- Shape of a region's terrain (S45), read by the shared height function Logic/RegionTerrain. Roads, lakes,
-- streams and sites stay in Data/Areas/<map> (one source with the monster groups, the map and the wiki); a
-- Data/Terrain/<map> file holds only what shapes, paints and plants the ground. Map-relative studs; y = 0 is the
-- old flat ground. Names follow Data/Terrain/meadows where the meaning is the same.
--
-- Layers, in order: noise (swell + detail x zone amplitude + fine) -> hills, ridges, plateaus -> gorges, basins
-- -> marshes -> flats -> roads -> ramps -> lakes -> streams. Later sessions add their own optional fields (S46:
-- dunes, lava, mesas, cracks; S47: snow, ice, frozen lakes, crevasses); every field here keeps its meaning.

-- Soft rectangle { x1, z1, x2, z2 } where the detail noise has amplitude `amp` (blended over `blend` studs).
export type Zone = { rect: { number }, blend: number, amp: number }

-- Soft ellipse added to the ground: `h` studs at the centre (negative = a dip), flat top over `flat` (0..1) of the
-- radius.
export type Hill = { x: number, z: number, rx: number, rz: number, rot: number, h: number, flat: number }

-- Ridge along a polyline. Every point is { x, z, h, w }: crest height over the ground and half-width of the gentle
-- side there. `sharp` (default 1) > 1 makes the crest narrower. `steep` = 1 or -1 makes one side a scarp `cliff`
-- studs wide: the side left (1) or right (-1) of the direction of travel along the points.
export type Ridge = {
	pts: { { number } },
	sharp: number?,
	steep: number?,
	cliff: number?,
}

-- Flat-topped table at height `y` (absolute). Either an ellipse (x, z, rx, rz, rot) or a polygon `poly`
-- { x1, z1, x2, z2, ... } (counter- or clockwise). The edge falls to the ground over `cliff` studs; for a polygon
-- `cliff` may be one width per vertex (blended along each edge), so a scarp can fade out at its ends. `noise` adds
-- that many studs of uneven ground on the top.
export type Plateau = {
	y: number,
	cliff: number | { number },
	x: number?,
	z: number?,
	rx: number?,
	rz: number?,
	rot: number?,
	poly: { number }?,
	noise: number?,
}

-- Gorge cut along a polyline (like Bear Ravine of the Meadows): every point { x, z, half, floor } gives the floor's
-- half-width and absolute height; walls `wall` studs wide.
export type GorgePoint = { x: number, z: number, half: number, floor: number }
export type Gorge = { wall: number, pts: { GorgePoint } }

-- Bowl pressed into the ground: `depth` studs at the centre, flat bottom over `flat` (0..1) of the radius.
export type Basin = { x: number, z: number, rx: number, rz: number, rot: number, depth: number, flat: number }

-- Island of a marsh: dry ground `h` studs over the marsh water inside radius `r` (edge blends over 10 studs).
export type Island = { x: number, z: number, r: number, h: number }

-- Marsh: a soft ellipse whose edge is pushed in and out by noise (`ragged`), pulled down towards `level` with
-- noise of `amp` (scale `scale`), so shallow pools open between tussocks; water stands at `water` (default the
-- map's lakeLevel). `edge` = width of the transition as a fraction of the radii. `theme` paints its core.
export type Marsh = {
	x: number,
	z: number,
	rx: number,
	rz: number,
	edge: number,
	ragged: number,
	level: number,
	amp: number,
	scale: number,
	strength: number,
	water: number?,
	theme: string?,
	islands: { Island }?,
}

-- Flattened place (portals, cave mouths, respawn points, buildings): radius `r`, edge blend, height `y` (default
-- the ground there).
export type Flat = { x: number, z: number, r: number, blend: number, y: number? }

-- Path with its own height: points { x, z, y? } (y = nil: the ground there before the ramp).
export type Ramp = { w: number, pts: { { number } } }

-- Bridge or ford where a road crosses a stream (hint by position).
export type Crossing = { x: number, z: number, kind: "stone" | "wood" | "ford" }

export type Theme = { rect: { number }, theme: string }
export type Patch = { x: number, z: number, r: number, material: string }

-- Material rule (first match wins), after water beds, roads, ramps, banks and shores. Every condition is
-- optional: the surface theme (one or a list), slope in degrees, absolute height, the theme noise 0..1 (scale 31),
-- inside a gorge, on a plateau's edge or top, inside a marsh.
export type MaterialRule = {
	mat: string,
	theme: (string | { string })?,
	minSlope: number?,
	maxSlope: number?,
	minY: number?,
	maxY: number?,
	minNoise: number?,
	maxNoise: number?,
	gorge: boolean?,
	plateau: boolean?,
	marsh: boolean?,
	-- S46: distance to lava and glowing cracks (charred bands), on a mesa or spire (walls, skirts), inside a dune
	-- field, on a dry lake's floor
	minLava: number?,
	maxLava: number?,
	rock: boolean?,
	dune: boolean?,
	drylake: boolean?,
}

-- Plants of a theme: big trees on a jittered grid (`spacing`, probability `dense` where the clump noise is over
-- `clump`, `sparse` under it, species weights `kinds`), client-only filler trees (`filler` per 128-stud tile) and
-- undergrowth (`under`: count per tile and kinds).
export type FloraRule = {
	spacing: number,
	dense: number,
	sparse: number,
	clump: number,
	kinds: { [string]: number },
	filler: number?,
	fillerKinds: { [string]: number }?,
	under: { n: number, kinds: { [string]: number } }?,
}

-- S46 desert shapes -----------------------------------------------------------------------------------------------

-- Field of dunes inside a soft rectangle: crests run across the wind (`wind`: compass bearing in degrees the wind
-- blows towards, 0 = north/-Z, 90 = east/+X), one every `wave` studs, `height` studs tall (scaled 0.6..1 by noise),
-- the windward side gentle and the lee side steep (`lee` 0..1: the share of the wave the lee slope takes, ~0.18),
-- flat valleys between them (`valley` 0..1: the share of the wave that stays flat), crests winding by `wander`
-- studs. `material` paints the field (default Sand; S47: Snow drifts).
export type Dunes = {
	rect: { number },
	blend: number,
	wind: number,
	wave: number,
	height: number,
	lee: number,
	valley: number,
	wander: number,
	material: string?,
}

-- Table mountain with a flat top at `top` (absolute), near-vertical walls `cliff` studs wide (6-12), a ragged
-- outline (`ragged` studs of noise) cut by gullies, and a scree skirt (`skirt` studs wide, `skirtH` studs tall at
-- the wall's foot, ~27 degrees). Ellipse (x, z, rx, rz, rot) or polygon `poly` { x1, z1, x2, z2, ... }. `cap`
-- paints the top (default the region's cap material).
export type Mesa = {
	top: number,
	cliff: number,
	ragged: number,
	skirt: number,
	skirtH: number,
	x: number?,
	z: number?,
	rx: number?,
	rz: number?,
	rot: number?,
	poly: { number }?,
	cap: string?,
}

-- Rock spire: base radius `r` (8-20), `h` studs over the ground, a narrow flat top (`top` 0..1 of the radius),
-- one side steeper (`lean`: bearing of the steep side in degrees, `asym` 0..0.5 how much steeper), an uneven
-- outline; `cap` paints the top (default the region's cap material).
export type Spire = {
	x: number,
	z: number,
	r: number,
	h: number,
	top: number?,
	lean: number?,
	asym: number?,
	cap: string?,
}

-- River of lava along points { x1, z1, ... } with a lava width per point; the surface starts at `level` (absolute)
-- and never rises downstream (the ground under the channel minus `sink`, like the streams); low banks `wall` studs
-- over the lava, `bank` studs wide. `into` = "pool:<n>" (it ends in a pool at that pool's level) or "end".
export type LavaRiver = {
	id: string,
	points: { number },
	widths: { number },
	level: number,
	sink: number,
	wall: number,
	bank: number,
	into: string,
	-- "pool:<n>": the river leaves that pool (it keeps the pool's level until it is out of it)
	from: string?,
}

-- Pool of lava: soft ellipse with a ragged shore; surface at `level` (absolute); `crust` = a cooling lake (dark
-- crust with glowing veins); `islands` of crust `h` studs over the surface.
export type LavaPool = {
	id: string,
	x: number,
	z: number,
	rx: number,
	rz: number,
	rot: number,
	level: number,
	wall: number,
	bank: number,
	crust: boolean?,
	islands: { Island }?,
}

-- Lava fall: where a river leaves the lip at (x, z) falling `drop` studs towards `rot` (degrees, Build convention);
-- read by the generator (glow, sparks, smoke), the terrain shape comes from the river's profile.
export type LavaFall = { x: number, z: number, rot: number, drop: number, river: string }

export type Lava = { rivers: { LavaRiver }, pools: { LavaPool }, falls: { LavaFall } }

-- Crack along points { x1, z1, ... }: `width` studs, `depth` studs deep (2-5; under ~8 studs wide it is mostly
-- paint), `glow` = a bottom of glowing lava (counts like lava for monster groups and arrivals) or cold basalt.
export type Crack = { points: { number }, width: number, depth: number, glow: boolean }

-- Dry lake: a basin `depth` studs under its rim with a flat bottom (ellipse, ragged shore over `shore` studs);
-- the floor is a salt crust cracked into polygons, a band of bleached sand marks the old waterline.
export type DryLake = {
	x: number,
	z: number,
	rx: number,
	rz: number,
	rot: number,
	depth: number,
	shore: number,
	y: number?, -- absolute height of the floor (default: the ground at the centre minus `depth`)
	crust: string?, -- floor material (default Concrete)
	seam: string?, -- polygon seams (default Ground)
	line: string?, -- old waterline (default Sand)
}

-- Horizontal rock layers on the walls of mesas and spires: one layer every `period` studs, `bands` are thin layers
-- { material, from, to } as fractions 0..1 of the period; the rest is `base`.
export type Strata = { period: number, base: string, bands: { { any } } }

-- Terrain writer limits (World/TerrainWriter.Options): lowest voxel layer, top of the highest, margin past the edge.
export type Writer = { bottom: number, top: number, margin: number }

-- Respawn point: position and the point it looks at.
export type Respawn = { x: number, z: number, lookX: number, lookZ: number }

export type Shape = {
	map: string,
	seed: number,
	writer: Writer,
	lakeLevel: number,
	lakeDepth: number,
	lakeShore: number,
	swell: { amp: number, scale: number },
	detail: { amp: number, scale: number },
	fine: { amp: number, scale: number },
	zones: { Zone },
	hills: { Hill },
	ridges: { Ridge },
	plateaus: { Plateau },
	gorges: { Gorge },
	basins: { Basin },
	marshes: { Marsh },
	flats: { Flat },
	ramps: { Ramp },
	crossings: { Crossing },
	themes: { Theme },
	defaultTheme: string,
	themeJitter: number,
	patches: { Patch },
	materialRules: { MaterialRule },
	flora: { [string]: FloraRule },
	respawns: { Respawn },
	-- Stream valley: max rise per stud beside the water and how far it reaches (Meadows: 0.17, 50).
	valley: { slope: number, reach: number }?,
	-- S46 (all optional): dune fields, table mountains, spires, lava, cracks, dry lakes, rock layers, the material
	-- of mesa and spire tops, the surface of lava and of cooling crust, the fallback material
	dunes: { Dunes }?,
	mesas: { Mesa }?,
	spires: { Spire }?,
	lava: Lava?,
	cracks: { Crack }?,
	drylakes: { DryLake }?,
	strata: Strata?,
	capMaterial: string?,
	fallback: string?,
}

return nil
