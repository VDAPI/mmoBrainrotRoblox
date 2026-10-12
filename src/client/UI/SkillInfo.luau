--!strict
-- Skill tooltip text (S28, DESIGN §14): name and rank, the area's shape with its size, cost / cooldown / range at the
-- current rank, the description, the next rank's numbers with the level it comes at, the breakpoints of ranks 5 and
-- 10 (reached ones marked, each with its character level; the option that works). Plain text for
-- Components/Tooltip; the skill window draws the same pieces itself.
-- S57: `rank` comes from Logic/Paths.skillRank (0 = not available yet); numbers and descriptions through
-- Paths.effectiveFor / Paths.skillMods with the chosen breakpoints (path.bp) and the modify nodes.
-- S54: cost and descriptions at the character level (Skills.cost, heal curve); damage skills show the weapon speed
-- factor (Skills.speedFactor) when it is not x1.
-- S59: breakpoints with the player's choice: the line shows the option that works (chosen, else A);
-- breakpointCards gives the skills window both options of ranks 5 and 10 with their state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local State = require(script.Parent.State)
local Text = require(script.Parent.Text)

local SkillInfo = {}

local characterLevel = State.Value({ "character", "level" })
local characterClass = State.Value({ "character", "class" })
local characterPath = State.Value({ "character", "path" })
local equipment = State.Value({ "character", "equipment" })
local weapon = State.Value({ "derived", "weapon" })
local costReduce = State.Value({ "derived", "values", "costReduce" }) -- S62: the bar shows the cost after saving

-- The character as Logic/Paths reads it, tracked by `use`.
local function charOf(use: any): Paths.Char
	local level = use(characterLevel)
	return {
		class = use(characterClass) or "",
		level = if type(level) == "number" then level else 1,
		path = use(characterPath),
		equipment = use(equipment),
	}
end

-- The skill as it works for the character at `rank` (chosen breakpoints, modify nodes).
local function effective(use: any, skill: SkillData.SkillDef, rank: number): SkillData.SkillDef
	local c = charOf(use)
	return (Paths.effectiveFor(c, skill.id, Paths.weaponTypesOf(c.equipment), rank))
end

-- Description options: the character level, path.bp and the modify nodes.
local function descOpts(use: any, skill: SkillData.SkillDef): Skills.DescOpts
	local c = charOf(use)
	local state = c.path
	return {
		level = c.level,
		choices = if state then state.bp else nil,
		mods = Paths.skillMods(c, skill.id, Paths.weaponTypesOf(c.equipment)),
	}
end

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
function SkillInfo.shapeLine(use: any, skill: SkillData.SkillDef, shownRank: number): string
	local rank = math.max(1, shownRank)
	local def = effective(use, skill, rank)
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
function SkillInfo.costLine(use: any, skill: SkillData.SkillDef, shownRank: number): string
	local rank = math.max(1, shownRank)
	local def = effective(use, skill, rank)
	local parts = {}
	local saving = use(costReduce)
	local cost = Skills.cost(def, rank, levelOf(use), skill.class, {
		costReduce = if type(saving) == "number" then saving else 0,
	})
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

local function choicesOf(use: any, choices: Skills.Choices?): Skills.Choices?
	if choices then
		return choices
	end
	local state = charOf(use).path
	return if state then state.bp else nil
end

-- Lines of the breakpoints: { text, reached }; `choices` default: path.bp of the character.
function SkillInfo.breakpoints(
	use: any,
	skill: SkillData.SkillDef,
	rank: number,
	choices: Skills.Choices?
): { { text: string, reached: boolean } }
	local out = {}
	choices = choicesOf(use, choices)
	for _, bp in Skills.breakpointKeys(skill) do
		-- the option that works (A without a choice)
		if bp.option == Skills.chosen(skill, bp.rank, choices) then
			local label =
				Text.get(use, "skills.breakpoint", { rank = bp.rank, level = Skills.rankLevel(skill, bp.rank) })
			table.insert(out, { text = `{label}: {Text.get(use, bp.key)}`, reached = rank >= bp.rank })
		end
	end
	return out
end

export type BpOption = { option: SkillData.BreakpointOption, text: string }
export type BpCard = {
	at: number,
	level: number, -- character level of the rank
	reached: boolean,
	chosen: SkillData.BreakpointOption?, -- saved in path.bp
	working: SkillData.BreakpointOption, -- chosen, else A
	options: { BpOption }, -- A, and B when the breakpoint has it
}

-- Both options of the breakpoints at ranks 5 and 10 (S59; passives have none).
function SkillInfo.breakpointCards(
	use: any,
	skill: SkillData.SkillDef,
	rank: number,
	choices: Skills.Choices?
): { BpCard }
	local out: { BpCard } = {}
	if skill.type == "passive" or not skill.breakpoints then
		return out
	end
	choices = choicesOf(use, choices)
	for _, at in Skills.BREAKPOINT_LEVELS do
		local pair = skill.breakpoints[at]
		if pair then
			local options: { BpOption } =
				{ { option = "a", text = Text.get(use, Skills.breakpointKey(skill.id, at, "a")) } }
			if pair.b then
				table.insert(options, { option = "b", text = Text.get(use, Skills.breakpointKey(skill.id, at, "b")) })
			end
			table.insert(out, {
				at = at,
				level = Skills.rankLevel(skill, at),
				reached = rank >= at,
				chosen = if choices then choices[Skills.choiceKey(skill.id, at)] else nil,
				working = Skills.chosen(skill, at, choices),
				options = options,
			})
		end
	end
	return out
end

-- The whole tooltip as plain text (the skill bar); `choices` default: path.bp of the character.
function SkillInfo.tooltip(use: any, skill: SkillData.SkillDef, rank: number, choices: Skills.Choices?): string
	local lang = use(Text.Lang)
	local shown = math.max(1, rank)
	local rankText = Text.get(use, "skills.rank", { rank = rank, max = skill.maxLevel })
	local lines = { `{Text.get(use, skill.nameKey)} · {rankText}` }
	if rank <= 0 then
		table.insert(lines, Text.get(use, "skills.unlockAt", { level = skill.unlock }))
	end
	local shape = SkillInfo.shapeLine(use, skill, shown)
	if shape ~= "" then
		table.insert(lines, shape)
	end
	if skill.type ~= "passive" then
		table.insert(lines, SkillInfo.costLine(use, skill, shown))
	end
	local opts = descOpts(use, skill)
	table.insert(lines, Skills.formatDescription(skill, shown, lang, opts))
	if rank > 0 and rank < skill.maxLevel then
		local nextText = Skills.formatDescription(skill, rank + 1, lang, opts)
		local label = Text.get(use, "skills.nextRank", { rank = rank + 1, level = Skills.rankLevel(skill, rank + 1) })
		table.insert(lines, `{label}: {nextText}`)
	end
	for _, bp in SkillInfo.breakpoints(use, skill, rank, choices) do
		table.insert(lines, (if bp.reached then "✔ " else "· ") .. bp.text)
	end
	local element = Skills.requiredElement(skill)
	if element then
		table.insert(lines, Text.get(use, "skill.requiresElement", { element = Text.get(use, `element.{element}`) }))
	end
	return table.concat(lines, "\n")
end

return SkillInfo
