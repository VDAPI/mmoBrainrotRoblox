--!strict
-- Types of the starting city plan (S21). The data itself is generated: see city.luau and docs/miasto/MIASTO.md.
-- Coordinates are map-relative studs: x east, z south (north = -z). `rot` and `facing` are degrees around Y;
-- the front of a building is its local -Z, so the front direction is (-sin(rot), -cos(rot)): 0 north, 90 west,
-- 180 south, 270 east.

export type Vec2 = { number } -- { x, z }
export type Vec3 = { number } -- { x, z, y }

export type Gate = {
	id: string,
	x: number,
	z: number,
	rot: number,
	out: Vec2,
	portal: string,
	target: string,
	arrive: Vec2,
}

export type Plateau = { id: string, y: number, blend: number, edge: "soft" | "wall" | "cliff", poly: { Vec2 } }
export type Ramp = { id: string, name: string, w: number, stairs: boolean, pts: { Vec3 } }

export type Terrain = {
	insideNoise: { amp: number, scale: number, seed: number },
	outside: {
		fade: number,
		base: number,
		amp: number,
		scale: number,
		seed: number,
		riseFrom: number,
		rise: number,
	},
	moat: { center: number, half: number, bed: number },
	river: { pts: { Vec2 }, width: number, bank: number, bed: number, water: number },
	plateaus: { Plateau },
	ramps: { Ramp },
}

export type Street = { id: string, name: string, kind: "main" | "lane" | "alley", w: number, pts: { Vec2 } }
export type Bridge = { id: string, kind: "stone" | "wood", x: number, z: number, rot: number, len: number, w: number }
export type Square = { id: string, mat: string, poly: { Vec2 } }
export type Special = { id: string, kind: string, x: number, z: number, w: number, d: number, rot: number }
export type Stall = { id: string, x: number, z: number, rot: number, color: string, npc: string? }
export type Spot = { x: number, z: number, facing: number, at: string? }
export type District = { id: string, style: string, poly: { Vec2 } }

export type Lot = {
	id: string,
	kind: "townhouse" | "workshopHouse" | "cottage",
	style: "burgher" | "patrician" | "craft" | "cottage",
	x: number,
	z: number,
	w: number,
	d: number,
	rot: number,
	floors: number,
	seed: number,
	arcade: boolean?,
}

export type Retaining = {
	id: string,
	kind: "retaining" | "cliff" | "rampSide",
	a: Vec2,
	b: Vec2,
	top: number,
	bottom: number,
	parapet: boolean,
}

export type Garden = { id: string, kind: string, seed: number, poly: { Vec2 } }
export type Lamp = { id: string, kind: "post" | "rampLantern", x: number, z: number }
export type Field = { id: string, crop: string, rows: number, seed: number, poly: { Vec2 } }
export type OutsideRoad = {
	gate: string,
	w: number,
	pts: { Vec2 },
	bridge: { x: number, z: number, rot: number, len: number, w: number },
}

export type City = {
	size: number,
	wall: { Vec2 },
	gates: { Gate },
	terrain: Terrain,
	streets: { Street },
	bridges: { Bridge },
	squares: { Square },
	specials: { Special },
	stalls: { Stall },
	npcs: { [string]: Spot },
	spawn: Spot,
	arena: { x: number, z: number, half: number, stands: number, exit: Vec2, duel: { Vec2 } },
	selectCamera: { eye: { number }, look: { number } },
	fountain: Vec2,
	wells: { Vec2 },
	cemetery: { Vec2 },
	districts: { District },
	lots: { Lot },
	retaining: { Retaining },
	gardens: { Garden },
	lamps: { Lamp },
	outside: {
		forestStart: number,
		windmill: { x: number, z: number, rot: number },
		farms: { { x: number, z: number, rot: number } },
		ruin: { x: number, z: number },
		roads: { OutsideRoad },
		fields: { Field },
	},
}

return nil
