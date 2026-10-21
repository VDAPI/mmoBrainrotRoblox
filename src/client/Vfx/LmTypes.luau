--!strict
-- W30: what VfxController hands a registered piece (Vfx/LmPieces). Built once per piece from the SkillFx event.

export type Ctx = {
	name: string, -- the piece
	phase: string, -- "cast" | "release" | "impact"
	skill: any, -- the effective SkillDef (Data/Skills)
	entry: any, -- the SkillVfx entry
	data: { [string]: any }, -- the SkillFx event
	color: Color3,
	simple: boolean, -- far away or low quality: fewer parts, no trails
	caster: Model?,
	target: Model?,
	from: Model?, -- the previous link of a chain (heal chains, Chain Lightning)
	at: Vector3?, -- impact: where the blow lands; cast / release: where the shot leaves
	aim: Vector3?, -- cast / release: where the skill goes (the target's centre or the point)
	frame: CFrame?, -- the blow's facing (cones, lines), else caster -> target
	radius: number,
	seconds: number, -- impact: the event's `d` (default 1); cast: the gathering until the release
	scale: number, -- SkillVfx size (and Arcane Charges)
	wave: number, -- 1 = the first wave / target
	opts: { [string]: any }, -- SkillVfx.lmOpts[name]
	launch: (() -> Vector3)?, -- cast: the live point of the gathering hand / tip
}

export type Piece = (ctx: Ctx) -> ()

export type FlightOpts = {
	size: number,
	simple: boolean,
	maxTime: number,
	speed: number,
	count: number?,
	onArrive: (at: Vector3) -> (),
}

export type Flight = (from: Vector3, target: Model | Vector3, color: Color3, opts: FlightOpts) -> ()

return {}
