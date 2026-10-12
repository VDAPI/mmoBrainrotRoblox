--!strict
-- Small helper to declare skills compactly: fills ids, keys and defaults; maxLevel comes from the data.

local Types = require("./Types")

local Build = {}

export type Spec = {
	id: string,
	path: string?, -- S57: path id (unlock = the row level); nil = class base
	unlock: number,
	maxLevel: number,
	type: Types.SkillType,
	target: Types.TargetMode?,
	cost: Types.Scaled?,
	cooldown: Types.Scaled?,
	range: number?,
	radius: number?,
	angle: number?,
	length: number?,
	width: number?,
	delay: number?,
	hits: number?,
	interval: number?,
	duration: Types.Scaled?,
	element: ("fire" | "ice" | "lightning" | "poison")?,
	adaptive: boolean?,
	randomTarget: boolean?,
	damageKind: ("phys" | "magic")?,
	holy: boolean?,
	values: { [string]: Types.Scaled }?,
	effects: { Types.SkillEffect }?,
	passive: { flat: { [string]: string }?, pct: { [string]: string }?, hooks: { [string]: string }? }?,
	breakpoints: Types.Breakpoints?,
	glyph: string,
	vfx: string?,
}

local DEFAULT_TARGET: { [string]: Types.TargetMode } = {
	target = "enemy",
	projectile = "enemy",
	charge = "enemy",
	chain = "enemy",
	debuff = "enemy",
	cone = "none",
	circleSelf = "none",
	line = "none",
	circleTarget = "point",
	trap = "none",
	blink = "point",
	buff = "self",
	heal = "ally",
	hot = "ally",
	shield = "ally",
	channel = "self",
	resurrect = "deadAlly",
	groupBuff = "self",
	groupHeal = "self",
	passive = "none",
}

-- S55 (ROZWOJ 2.7): breakpoints at ranks 5 and 10, each { a = Breakpoint, b = Breakpoint? }. Untyped arguments:
-- every breakpoint has its own shape (tests/skills.spec checks them).
function Build.bp2(five: any, ten: any): Types.Breakpoints
	assert(
		type(five) == "table" and five.a ~= nil and type(ten) == "table" and ten.a ~= nil,
		"Build.bp2: option a is required"
	)
	return { [5] = five, [10] = ten }
end

-- Builds the class list. `resource` and `damageKind` are class-wide defaults.
function Build.class(
	classId: string,
	resource: "mana" | "energy",
	damageKind: "phys" | "magic",
	-- Literal data tables are checked by tests/skills.spec.luau (exact-type inference struggles with them).
	specs: { any }
): { Types.SkillDef }
	local list: { Types.SkillDef } = {}
	for order, spec in specs do
		local passive = spec.type == "passive"
		assert(type(spec.maxLevel) == "number", `Skills: {spec.id} needs maxLevel`)
		table.insert(list, {
			id = spec.id,
			class = classId,
			order = order,
			path = spec.path,
			unlock = spec.unlock,
			maxLevel = spec.maxLevel,
			type = spec.type,
			target = spec.target or DEFAULT_TARGET[spec.type] or "none",
			resource = if passive then nil else resource,
			cost = spec.cost or 0,
			cooldown = spec.cooldown or 0,
			range = spec.range,
			radius = spec.radius,
			angle = spec.angle,
			length = spec.length,
			width = spec.width,
			delay = spec.delay,
			hits = spec.hits,
			interval = spec.interval,
			duration = spec.duration,
			element = spec.element,
			adaptive = spec.adaptive,
			randomTarget = spec.randomTarget,
			damageKind = spec.damageKind or damageKind,
			holy = spec.holy,
			values = spec.values or {},
			effects = spec.effects,
			passive = spec.passive,
			breakpoints = spec.breakpoints,
			glyph = spec.glyph,
			vfx = spec.vfx or spec.id,
			nameKey = `skill.{spec.id}.name`,
			descKey = `skill.{spec.id}.desc`,
		})
	end
	return list
end

return Build
