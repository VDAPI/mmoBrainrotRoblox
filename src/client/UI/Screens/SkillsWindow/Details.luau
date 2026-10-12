--!strict
-- Details of the selection in the skills window (S59, ROZWOJ 4): a skill (rank, shape, cost and cooldown only from
-- UI/SkillInfo, element, the description at the current and the next rank with the chosen breakpoints and the path
-- nodes, the A / B cards of ranks 5 and 10) or a path node (kind, rank, its text now and at the next rank with
-- Paths.nodeArgs, one-third strength, weapon, why it does not work or why its row is closed). A skill node shows the
-- skill and under it only the node's own part. Details.actions lists the buttons (Buy, Refund, To bar) for the PC
-- panel and the phone sheet. Same lines on PC (panel) and phone (sheet, `touch`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local Breakpoints = require(script.Parent.Breakpoints)
local Context = require(script.Parent.Context)
local Elements = require(ReplicatedStorage.Shared.Data.Elements)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local SkillInfo = require(script.Parent.Parent.Parent.SkillInfo)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

type Scope = Fusion.Scope<typeof(Fusion)>
type SkillDef = SkillData.SkillDef

export type Resolved = {
	skill: SkillDef?,
	node: PathData.PathNode?,
	view: PathView.NodeView?,
	row: PathView.RowView?,
}
export type ActionSpec = { key: string, enabled: boolean, reason: string?, run: () -> () } -- reason: shown text

local Details = {}

-- The selection as a skill and / or a node with its current view.
function Details.resolve(use: Fusion.Use, ctx: Context.Ctx): Resolved
	local sel = use(ctx.selected)
	if not sel then
		return {}
	end
	if sel.kind == "skill" then
		return { skill = SkillData.get(sel.id) }
	end
	local node, def = Paths.findNode(sel.id)
	local character = use(ctx.character)
	if not node or not def or not character then
		return {}
	end
	local out: Resolved = {
		node = node,
		skill = if node.kind == "skill" and node.skill then SkillData.get(node.skill) else nil,
	}
	local view = PathView.path(character, def.id, use(ctx.weapons))
	if view then
		for _, row in view.rows do
			for _, nodeView in row.nodes do
				if nodeView.node.id == node.id then
					out.view = nodeView
					out.row = row
				end
			end
		end
	end
	return out
end

-- The active skill the preview plays for the selection (a skill, a skill node, a modify node's skill).
function Details.previewSkill(use: Fusion.Use, ctx: Context.Ctx): string?
	local resolved = Details.resolve(use, ctx)
	local skill = resolved.skill
	local node = resolved.node
	if not skill and node and node.modify then
		skill = SkillData.get(node.modify.skill)
	end
	return if skill and skill.type ~= "passive" then skill.id else nil
end

-- Buttons of the selection: Buy and Refund for a node, To bar for an available active.
function Details.actions(use: Fusion.Use, ctx: Context.Ctx, actions: Actions.Actions): { ActionSpec }
	local out: { ActionSpec } = {}
	local resolved = Details.resolve(use, ctx)
	local view = resolved.view
	if view then
		local id = view.node.id
		table.insert(out, {
			key = "paths.node.buy",
			enabled = view.canBuy,
			reason = if view.buyReason then Text.get(use, view.buyReason) else nil,
			run = function()
				actions.buy(id)
			end,
		})
		table.insert(out, {
			key = "paths.node.refund",
			enabled = view.canRefund,
			reason = if view.refundReason then Text.get(use, view.refundReason) else nil,
			run = function()
				actions.refund(id)
			end,
		})
	end
	local skill = resolved.skill
	local character = use(ctx.character)
	if skill and skill.type ~= "passive" and character and Paths.skillRank(character, skill.id) > 0 then
		local slot = Actions.slotOf(use(ctx.hotbar), skill.id)
		local skillId = skill.id
		table.insert(out, {
			key = "skills.toBar",
			enabled = slot == nil,
			reason = if slot then Text.get(use, "skills.onBar", { slot = slot }) else nil,
			run = function()
				actions.toBar(skillId)
			end,
		})
	end
	return out
end

-- The detail lines of the selection (instances in the inner scope `s`).
function Details.lines(
	s: Scope,
	use: Fusion.Use,
	ctx: Context.Ctx,
	actions: Actions.Actions,
	touch: boolean
): { Instance }
	local out: { Instance } = {}
	local function add(item: Instance)
		(item :: any).LayoutOrder = #out + 1
		table.insert(out, item)
	end
	local function line(text: string, color: Color3?, size: number?, font: Font?)
		add(s:New("TextLabel")({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = text,
			RichText = true,
			TextWrapped = true,
			FontFace = font or Theme.Fonts.Body,
			TextSize = size or Theme.TextSize.Small,
			TextColor3 = color or Theme.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		}))
	end
	local function heading(text: string)
		line(text, Theme.Colors.Gold, Theme.TextSize.Large, Theme.Fonts.Heading)
	end
	local function sub(text: string)
		line(text, Theme.Colors.Gold, nil, Theme.Fonts.BodyBold)
	end

	local character = use(ctx.character)
	local resolved = Details.resolve(use, ctx)
	local skill, node, view, row = resolved.skill, resolved.node, resolved.view, resolved.row
	if not character or (not skill and not node) then
		line(Text.get(use, "skills.dragHint"), Theme.Colors.TextMuted)
		return out
	end
	local lang = use(Text.Lang)
	local weapons = use(ctx.weapons)

	if skill then
		local rank = Paths.skillRank(character, skill.id)
		local shown = math.max(1, rank)
		local choices = if character.path then character.path.bp else nil
		local opts: Skills.DescOpts = {
			level = character.level,
			choices = choices,
			mods = Paths.skillMods(character, skill.id, weapons),
			cdr = SkillInfo.cdr(use), -- S64
		}
		heading(Text.get(use, skill.nameKey))
		local header = Text.get(use, "skills.rank", { rank = rank, max = skill.maxLevel })
		if skill.type == "passive" then
			header ..= ` · {Text.get(use, "skills.passive")}`
		end
		line(header, Theme.Colors.Parchment, Theme.TextSize.Body, Theme.Fonts.BodyBold)
		if rank <= 0 then
			line(Text.get(use, "skills.unlockAt", { level = skill.unlock }), Theme.Colors.DangerHover)
		end
		if skill.type ~= "passive" then
			local shape = SkillInfo.shapeLine(use, skill, shown)
			if shape ~= "" then
				line(shape, Theme.Colors.Parchment)
			end
			line(SkillInfo.costLine(use, skill, shown), Theme.Colors.TextMuted)
		end
		-- Weapon element (Mage, S18): requirement in red while the weapon does not fit, adaptive note.
		local element = Skills.requiredElement(skill)
		if element then
			local weapon = use(ctx.weapon)
			local fits = type(weapon) == "table" and weapon.element == element
			line(
				Text.get(use, "skill.requiresElement", { element = Text.get(use, `element.{element}`) }),
				if fits then Color3.fromHex(Elements.COLORS[element]) else Theme.Colors.DangerHover
			)
		elseif skill.adaptive then
			line(Text.get(use, "skill.adaptive"), Theme.Colors.Parchment)
		end
		if skill.path and rank > 0 then
			local usable, err = Paths.skillUsable(character, skill.id, weapons)
			if not usable and err then
				line(Text.get(use, err), Theme.Colors.DangerHover)
			end
		end
		sub(Text.get(use, if rank > 0 then "skills.current" else "skills.notLearned"))
		line(Skills.formatDescription(skill, shown, lang, opts))
		local heal = SkillInfo.healLine(use, skill, shown) -- S69
		if heal ~= "" then
			line(heal, Theme.Colors.Parchment)
		end
		if rank < skill.maxLevel then
			local nextRank = rank + 1
			sub(Text.get(use, "skills.next"))
			line(
				Text.get(use, "skills.nextRank", { rank = nextRank, level = Skills.rankLevel(skill, nextRank) }),
				Theme.Colors.TextMuted
			)
			line(Skills.formatDescription(skill, nextRank, lang, opts), Theme.Colors.Success)
		end
		for _, item in Breakpoints.new(s, use, ctx, actions, skill, rank, not touch) do
			add(item)
		end
	end

	if node and view then
		local rank = view.rank
		if skill then
			-- the skill's node: only its own part (the skill text is above)
			line(
				Text.get(use, "paths.node.rank", { rank = rank, max = node.maxRank }),
				Theme.Colors.Parchment,
				nil,
				Theme.Fonts.BodyBold
			)
		else
			heading(Text.get(use, node.nameKey))
			local kind = Text.get(use, `paths.kind.{node.kind}`)
			local modified = node.modify and SkillData.get(node.modify.skill)
			if modified then
				kind ..= ` · {Text.get(use, "paths.node.modifies", { skill = Text.get(use, modified.nameKey) })}`
			end
			line(kind, Theme.Colors.Parchment, nil, Theme.Fonts.BodyBold)
			line(Text.get(use, "paths.node.rank", { rank = rank, max = node.maxRank }), Theme.Colors.Parchment)
			if rank > 0 then
				sub(Text.get(use, "paths.node.now"))
				line(Text.get(use, node.descKey, Paths.nodeArgs(node, rank, view.scale)))
				if rank < node.maxRank then
					sub(Text.get(use, "paths.node.atRank", { rank = rank + 1 }))
					line(Text.get(use, node.descKey, Paths.nodeArgs(node, rank + 1, view.scale)), Theme.Colors.Success)
				end
			else
				sub(Text.get(use, "paths.node.atRank", { rank = 1 }))
				line(Text.get(use, node.descKey, Paths.nodeArgs(node, 1, view.scale)), Theme.Colors.TextMuted)
			end
			if view.scale < 1 then
				line(
					Text.get(use, "paths.node.dip", { pct = math.floor(view.scale * 100 + 0.5) }),
					Theme.Colors.Warning
				)
			end
		end
		if node.weapon then
			line(
				Text.get(use, "paths.node.weapon", { weapons = PathView.weaponText(node.weapon, lang) }),
				if view.weaponOk then Theme.Colors.Parchment else Theme.Colors.DangerHover
			)
		end
		if rank > 0 and not view.active then
			line(Text.get(use, "paths.node.inactive"), Theme.Colors.DangerHover)
		end
		if row and row.closedKey then
			line(Text.get(use, row.closedKey, row.closedArgs), Theme.Colors.TextMuted)
		end
	end

	-- the phone sheet has no room for reasons next to its buttons: they go here
	if touch then
		for _, spec in Details.actions(use, ctx, actions) do
			if not spec.enabled and spec.reason then
				line(`{Text.get(use, spec.key)}: {spec.reason}`, Theme.Colors.TextMuted)
			end
		end
	end
	return out
end

return Details
