--!strict
-- Skill tooltip text (S28, DESIGN §14): name and level, the area's shape with its size, cost / cooldown / range at the
-- current level, the description, the next level's numbers in green, the breakpoints of ranks 5 and 10 (reached ones
-- bright, later ones greyed with "from level N"; the option that works, A until S57) and what the next level needs. Plain text for Components/Tooltip; the skill
-- window draws the same pieces itself.
-- S54: cost and descriptions at the character level (Skills.cost, heal curve); damage skills show the weapon speed
-- factor (Skills.speedFactor) when it is not x1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local State = require(script.Parent.State)
local Text = require(script.Parent.Text)

local SkillInfo = {}

local characterLevel = State.Value({ "character", "level" })
local weapon = State.Value({ "derived", "weapon" })

local function levelOf(use: any): number
	local level = use(characterLevel)
	return if type(level) == "number" then level else 1
end

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
	local rank = math.max(1, level)
	local def = Skills.effective(skill, rank, nil, nil)
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
	local rank = math.max(1, level)
	local def = Skills.effective(skill, rank, nil, nil)
	local parts = {}
	local cost = Skills.cost(def, rank, levelOf(use), skill.class, nil)
	if cost > 0 and skill.resource then
		-- The bar needs the full amount, so a fractional cost (Mage above level 20) shows rounded up.
		local shownCost = math.ceil(cost - 1e-6)
		table.insert(parts, Text.get(use, `skills.cost.{skill.resource}`, { cost = shownCost }))
	end
	local cooldown = math.floor(Skills.scaled(def, def.cooldown, rank) * 10 + 0.5) / 10
	table.insert(parts, Text.get(use, "skills.cooldown", { cooldown = cooldown }))
	if def.range then
		table.insert(parts, Text.get(use, "skills.range", { range = def.range }))
	end
	if skill.values.dmg ~= nil then
		local equipped = use(weapon)
		local speed = if type(equipped) == "table" and type(equipped.speed) == "number" then equipped.speed else nil
		local factor = Skills.speedFactor(speed)
		if math.abs(factor - 1) > 0.005 then
			local mul = math.floor(factor * 100 + 0.5) / 100
			table.insert(parts, Text.get(use, "skills.weaponSpeed", { mul = mul }))
		end
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
		-- the option that works (A until a choice exists, S57 / S59)
		if bp.option == Skills.chosen(skill, bp.rank, nil) then
			local label = Text.get(use, "skills.breakpoint", { level = bp.rank })
			table.insert(out, { text = `{label}: {Text.get(use, bp.key)}`, reached = level >= bp.rank })
		end
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
	local opts = { level = levelOf(use) }
	table.insert(lines, Skills.formatDescription(skill, shown, lang, opts))
	if level > 0 and level < skill.maxLevel then
		local nextText = Skills.formatDescription(skill, level + 1, lang, opts)
		table.insert(lines, `{Text.get(use, "skills.next")}: {nextText}`)
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
