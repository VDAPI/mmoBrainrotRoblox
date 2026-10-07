--!strict
-- Skill tooltip text (S28, DESIGN §14): name and level, the area's shape with its size, cost / cooldown / range at the
-- current level, the description, the next level's numbers in green, both breakpoints (reached ones bright, later
-- ones greyed with "from level N") and what the next level needs. Plain text for Components/Tooltip; the skill
-- window draws the same pieces itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Text = require(script.Parent.Text)

local SkillInfo = {}

local SHAPE_GLYPH: { [string]: string } = {
	circle = "◯",
	self = "◉",
	cone = "◣",
	line = "▬",
	target = "◎",
	none = "",
}

-- "◣ Cone 90° · 10 studs" (empty for skills without an area).
function SkillInfo.shapeLine(use: any, skill: SkillData.SkillDef, level: number): string
	local def = Skills.effective(skill, math.max(1, level))
	local shape = Skills.shape(skill)
	if shape == "none" or shape == "target" then
		return ""
	end
	local size = if shape == "cone"
		then Text.get(use, "skills.shape.cone", { angle = def.angle or 90, radius = def.radius or 10 })
		elseif shape == "line" then Text.get(
			use,
			"skills.shape.line",
			{ length = def.length or 20, width = def.width or 4 }
		)
		else Text.get(use, `skills.shape.{shape}`, { radius = def.radius or 6 })
	return `{SHAPE_GLYPH[shape]} {size}`
end

-- "15 energy · Cooldown 4 s · Range 8 studs"
function SkillInfo.costLine(use: any, skill: SkillData.SkillDef, level: number): string
	local shown = math.max(1, level)
	local def = Skills.effective(skill, shown)
	local parts = {}
	local cost = Skills.scaled(def, def.cost, shown)
	if cost > 0 and skill.resource then
		table.insert(parts, Text.get(use, `skills.cost.{skill.resource}`, { cost = math.floor(cost) }))
	end
	local cooldown = math.floor(Skills.scaled(def, def.cooldown, shown) * 10 + 0.5) / 10
	table.insert(parts, Text.get(use, "skills.cooldown", { cooldown = cooldown }))
	if def.range then
		table.insert(parts, Text.get(use, "skills.range", { range = def.range }))
	end
	return table.concat(parts, " · ")
end

-- Lines of the breakpoints: { text, reached }.
function SkillInfo.breakpoints(
	use: any,
	skill: SkillData.SkillDef,
	level: number
): { { text: string, reached: boolean } }
	local out = {}
	for _, bp in Skills.breakpointKeys(skill) do
		local reached = level >= bp.level
		local label = Text.get(use, "skills.breakpoint", { level = bp.level })
		table.insert(out, { text = `{label}: {Text.get(use, bp.key)}`, reached = reached })
	end
	return out
end

-- The whole tooltip as plain text (the skill bar).
function SkillInfo.tooltip(use: any, skill: SkillData.SkillDef, level: number): string
	local lang = use(Text.Lang)
	local shown = math.max(1, level)
	local lines = { `{Text.get(use, skill.nameKey)} ({level}/{skill.maxLevel})` }
	local shape = SkillInfo.shapeLine(use, skill, shown)
	if shape ~= "" then
		table.insert(lines, shape)
	end
	if skill.type ~= "passive" then
		table.insert(lines, SkillInfo.costLine(use, skill, shown))
	end
	table.insert(lines, Skills.formatDescription(skill, shown, lang))
	if level > 0 and level < skill.maxLevel then
		table.insert(lines, `{Text.get(use, "skills.next")}: {Skills.formatDescription(skill, level + 1, lang)}`)
	end
	for _, bp in SkillInfo.breakpoints(use, skill, level) do
		table.insert(lines, (if bp.reached then "✔ " else "· ") .. bp.text)
	end
	local element = Skills.requiredElement(skill)
	if element then
		table.insert(lines, Text.get(use, "skill.requiresElement", { element = Text.get(use, `element.{element}`) }))
	end
	return table.concat(lines, "\n")
end

return SkillInfo
