--!strict
-- Small helper to declare skills compactly: fills ids, keys, max level and defaults.

local Types = require("./Types")

local Build = {}

export type Spec = {
	id: string,
	unlock: number,
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
	requires: { { skill: string, level: number } }?,
	col: number,
	row: number,
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
		table.insert(list, {
			id = spec.id,
			class = classId,
			order = order,
			unlock = spec.unlock,
			maxLevel = if passive then 5 else 10,
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
			requires = spec.requires,
			col = spec.col,
			row = spec.row,
			glyph = spec.glyph,
			vfx = spec.vfx or spec.id,
			nameKey = `skill.{spec.id}.name`,
			descKey = `skill.{spec.id}.desc`,
		})
	end
	return list
end

return Build
