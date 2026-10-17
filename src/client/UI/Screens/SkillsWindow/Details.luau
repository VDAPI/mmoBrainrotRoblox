--!strict
-- Details of the selection in the skills window (S59, ROZWOJ 4).
-- S139 (DESIGN-18 §12, owner: "more readable descriptions"): a skill shows fixed sections with headers, only from
-- Logic/PathView.skillDetails and UI/SkillInfo: the name with its picture, role and type; "What it does" (the short
-- sentence); "Rank N → N+1" (the rank, the limit, a table of the values now / after buying / the change in bold, "next
-- rank from level X" while the limit holds it back); "Cost and cooldown"; "Breakpoints" (A / B cards); "Changes from
-- directions" (the modify nodes of the class for this skill and their state); "From items" (S134g effects); "Full
-- description" folded. A direction node (FIX 2026-10-14) shows its name, kind, the state (rank, one-third strength,
-- node weapon, why it does not work or why its row is closed) and its text now and at the next rank (Paths.nodeArgs);
-- a skill node shows its skill above. Details.actions lists the buttons ("+ rank", "- rank" with the gold price,
-- "To bar"; Buy / Refund for a node) for the PC panel and the phone sheet. Same lines on PC (panel) and phone (sheet).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Breakpoints = require(script.Parent.Breakpoints)
local Context = require(script.Parent.Context)
local Elements = require(ReplicatedStorage.Shared.Data.Elements)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SectionLabel = require(script.Parent.Parent.Parent.Components.SectionLabel)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local SkillInfo = require(script.Parent.Parent.Parent.SkillInfo)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.Parent.UiArtState)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>
type SkillDef = SkillData.SkillDef

export type Resolved = {
	path: PathData.PathDef?, -- FIX 2026-10-14: a selected path (its description)
	skill: SkillDef?,
	node: PathData.PathNode?,
	view: PathView.NodeView?,
	row: PathView.RowView?,
	details: PathView.SkillDetails?, -- S139: the skill in the shown pool (with the reservation)
}
-- S139: `text` is the shown (localised) label; `reason` the shown reason of a disabled button.
export type ActionSpec = { text: string, enabled: boolean, reason: string?, run: () -> (), secondary: boolean? }

local Details = {}

local NUMBER_W = 56 -- a number column of the rank table

-- The selection as a skill and / or a node with its current view.
function Details.resolve(use: Fusion.Use, ctx: Context.Ctx): Resolved
	local sel = use(ctx.selected)
	if not sel then
		return {}
	end
	local character = use(ctx.character)
	local function withDetails(out: Resolved): Resolved
		local skill = out.skill
		local pool = use(ctx.pool)
		if skill and character and pool then
			out.details = PathView.skillDetails(character, pool, skill.id, use(ctx.reserve))
		end
		return out
	end
	if sel.kind == "skill" then
		return withDetails({ skill = SkillData.get(sel.id) })
	elseif sel.kind == "path" then
		return { path = PathData.get(sel.id) }
	end
	local node, def = Paths.findNode(sel.id)
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
	return withDetails(out)
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

-- Buttons of the selection: Buy and Refund for a node; for a skill (S139) "+ rank" and "- rank" (the reservation, a
-- bought rank back with its price) unless the selection is a node, and "To bar" for an active.
function Details.actions(use: Fusion.Use, ctx: Context.Ctx, actions: Actions.Actions): { ActionSpec }
	local out: { ActionSpec } = {}
	local resolved = Details.resolve(use, ctx)
	local view = resolved.view
	if view then
		local id = view.node.id
		table.insert(out, {
			text = Text.get(use, "paths.node.buy"),
			enabled = view.canBuy,
			reason = if view.buyReason then Text.get(use, view.buyReason) else nil,
			run = function()
				actions.buy(id)
			end,
		})
		table.insert(out, {
			text = Text.get(use, "paths.node.refund"),
			enabled = view.canRefund,
			reason = if view.refundReason then Text.get(use, view.refundReason) else nil,
			run = function()
				actions.refund(id)
			end,
			secondary = true,
		})
	end
	local d = resolved.details
	if not d then
		return out
	end
	local skillId = d.skillId
	if not view then
		table.insert(out, {
			text = Text.get(use, "skills.action.add"),
			enabled = d.buyable,
			reason = if d.buyReason then Text.get(use, d.buyReason) else nil,
			run = function()
				actions.addRank(skillId)
			end,
		})
		table.insert(out, {
			text = if d.refundCost > 0
				then Text.get(use, "skills.action.refundGold", { gold = d.refundCost })
				else Text.get(use, "skills.action.remove"),
			enabled = d.refundable,
			reason = if d.refundable then nil else Text.get(use, "skills.error.noRank"),
			run = function()
				actions.removeRank(skillId)
			end,
			secondary = true,
		})
	end
	if not d.passive then
		table.insert(out, {
			text = Text.get(use, "skills.toBar"),
			enabled = d.canBar and d.onBar == nil,
			reason = if d.onBar
				then Text.get(use, "skills.onBar", { slot = d.onBar })
				elseif not d.canBar then Text.get(use, "skills.error.locked")
				else nil,
			run = function()
				actions.toBar(skillId)
			end,
			secondary = true,
		})
	end
	return out
end

-- FIX 2026-10-14: the path's description (moved off the tree): name, role, description, title; S138: the ranks in the
-- direction and whether it leads (no main path, no direction weapon).
function Details.pathLines(
	use: Fusion.Use,
	character: Paths.Char,
	def: PathData.PathDef,
	weapons: Paths.WeaponTypes,
	line: (text: string, color: Color3?, size: number?, font: Font?) -> (),
	heading: (text: string) -> ()
)
	local view = PathView.path(character, def.id, weapons)
	heading(Text.get(use, def.nameKey))
	line(Text.get(use, `paths.role.{def.role}`), Theme.Paper.Text, nil, Theme.Fonts.BodyBold)
	line(Text.get(use, def.descKey))
	if view then
		line(Text.get(use, "skills.tree.points", { n = view.spent }), Theme.Paper.Text, nil, Theme.Fonts.BodyBold)
	end
	local title = TitleData.get(def.titleId)
	if title then
		line(Text.get(use, "paths.title", { title = Text.get(use, title.nameKey) }), Theme.Paper.Text)
	end
	if view and view.leading then
		line(Text.get(use, "paths.isMain"), Theme.Paper.Success, nil, Theme.Fonts.BodyBold)
	else
		line(Text.get(use, "skills.tree.leadingHint", { n = Paths.MAIN_MIN_POINTS }), Theme.Paper.TextMuted)
	end
end

-- S135: the numbers of a description in bold (RichText), so the values stand out in the ink text.
function Details.boldNumbers(text: string): string
	if string.find(text, "<", 1, true) then
		return text -- already rich text: leave it alone
	end
	return (string.gsub(text, "(%d[%d%.,]*%%?)", "<b>%1</b>"))
end

-- S139: the label of a row of the rank table (a value field, the time of an effect, cost, cooldown).
function Details.fieldLabel(use: Fusion.Use, field: string): string
	local effect = string.match(field, "^(%w+)Duration$")
	if effect and effect ~= "" then
		return Text.get(use, "skills.field.effectDuration", { effect = Text.get(use, `effect.{effect}`) })
	end
	return Text.get(use, `skills.field.{field}`)
end

local function number(value: number?): string
	return if value == nil then "—" else tostring(value)
end

local function signed(value: number?): string
	if value == nil or value == 0 then
		return if value == 0 then "0" else ""
	end
	return if value > 0 then `+{value}` else `−{-value}`
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
			TextColor3 = color or Theme.Paper.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			LineHeight = 1.15, -- S135
		}))
	end
	-- S119: a line with a picture in front (skill heading, element) only while that picture is loaded; the plain
	-- line otherwise.
	local function pictureLine(key: string, side: number, text: string, color: Color3, size: number?, font: Font?)
		if not UiArtState.ready(use, key) then
			line(text, color, size, font)
			return
		end
		add(s:New("Frame")({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			[Children] = {
				s:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				ArtIcon.Image(s, {
					Key = key,
					Size = UDim2.fromOffset(side, side),
					Corner = Theme.Corner.Small,
				}),
				s:New("TextLabel")({
					LayoutOrder = 2,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -side - 8, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Text = text,
					RichText = true,
					TextWrapped = true,
					FontFace = font or Theme.Fonts.Body,
					TextSize = size or Theme.TextSize.Small,
					TextColor3 = color,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			},
		}))
	end
	local function heading(text: string)
		line(text, Theme.Paper.Heading, Theme.TextSize.Large, Theme.Fonts.Display)
	end
	-- S135: sections as upper-case labels with a rule
	local function sub(text: string)
		add(SectionLabel(s, { Text = text }))
	end
	-- S139: a row of the rank table: the label, then three number columns (the last one bold)
	local function tableRow(cells: { string }, head: boolean, changeColor: Color3?)
		local labels: { Instance } = {}
		for i, text in cells do
			local first = i == 1
			table.insert(
				labels,
				s:New("TextLabel")({
					LayoutOrder = i,
					BackgroundTransparency = 1,
					Size = if first
						then UDim2.new(1, -3 * NUMBER_W, 0, 0)
						else UDim2.fromOffset(NUMBER_W, Theme.TextSize.Small + 4),
					AutomaticSize = if first then Enum.AutomaticSize.Y else Enum.AutomaticSize.None,
					Text = text,
					TextWrapped = first,
					FontFace = if head
						then Theme.Fonts.BodyBold
						elseif i == 4 then Theme.Fonts.BodyBold
						else Theme.Fonts.Body,
					TextSize = if head then Theme.TextSize.Caption else Theme.TextSize.Small,
					TextColor3 = if head
						then Theme.Paper.Label
						elseif i == 4 then changeColor or Theme.Paper.Text
						else Theme.Paper.Text,
					TextXAlignment = if first then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
				})
			)
		end
		add(s:New("Frame")({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			[Children] = {
				s:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				labels :: any,
			},
		}))
	end

	local character = use(ctx.character)
	local resolved = Details.resolve(use, ctx)
	local skill, node, view, row = resolved.skill, resolved.node, resolved.view, resolved.row
	local lang = use(Text.Lang)
	local weapons = use(ctx.weapons)
	local pathDef = resolved.path
	if character and pathDef then
		Details.pathLines(use, character, pathDef, weapons, line, heading)
		return out
	end
	if not character or (not skill and not node) then
		-- FIX 2026-10-14: a tree shows nothing until a tile (or the direction's name) is clicked
		line(Text.get(use, if use(ctx.onPools) then "skills.tree.hint" else "paths.tree.hint"), Theme.Paper.TextMuted)
		return out
	end

	local d = resolved.details
	if skill and not d then
		-- a skill of another pool than the shown one (the selection outlived a tab change)
		heading(Text.get(use, skill.nameKey))
		line(SkillInfo.short(use, skill, 1))
		line(Text.get(use, "skills.error.pool"), Theme.Paper.TextMuted)
	elseif skill and d then
		local pool = use(ctx.pool)
		local actual = if pool then Paths.skillRank(character, skill.id, pool) else 0
		local shown = math.max(1, d.rank)
		-- the name, the role and the type
		pictureLine(
			UiArt.skill(skill.id),
			48,
			Text.get(use, skill.nameKey),
			Theme.Paper.Heading,
			Theme.TextSize.Large,
			Theme.Fonts.Display
		)
		local parts: { string } = {}
		if d.column then
			table.insert(parts, Text.get(use, `skills.role.{d.column}`))
		end
		table.insert(parts, Text.get(use, if d.passive then "skills.passive" else "skills.kind.active"))
		if not d.passive and d.delivery then
			table.insert(parts, Text.get(use, `skills.delivery.{d.delivery}`))
		end
		line(table.concat(parts, " · "), Theme.Paper.Text, Theme.TextSize.Body, Theme.Fonts.BodyBold)
		local fromPath = if d.path then PathData.get(d.path) else nil
		if fromPath then
			line(Text.get(use, "skills.detail.direction", { path = Text.get(use, fromPath.nameKey) }), Theme.Paper.Text)
		end
		if not d.active then
			line(Text.get(use, "skills.detail.otherPool"), Theme.Paper.TextMuted)
		end
		if d.cap <= 0 then
			line(Text.get(use, "skills.unlockAt", { level = skill.unlock }), Theme.Paper.Danger)
		end
		-- "What it does"
		sub(Text.get(use, "skills.section.what"))
		line(Details.boldNumbers(SkillInfo.short(use, skill, shown)), Theme.Paper.Text, Theme.TextSize.Body)
		-- "Rank N → N+1"
		sub(
			if d.nextRank
				then Text.get(use, "skills.section.rank", { rank = d.rank, next = d.nextRank })
				else Text.get(use, "skills.section.rankMax", { rank = d.rank })
		)
		local rankText = Text.get(use, "skills.points.rank", { rank = d.rank, max = d.max, limit = d.cap })
		if d.reserved > 0 then
			rankText ..= ` {Text.get(use, "skills.points.reserved", { n = d.reserved })}`
		end
		line(rankText, Theme.Paper.Text, nil, Theme.Fonts.BodyBold)
		if d.rank <= 0 then
			line(Text.get(use, "skills.detail.notLearned"), Theme.Paper.TextMuted)
		end
		if d.nextRank and d.nextLevel then
			line(Text.get(use, "skills.nextRank", { rank = d.nextRank, level = d.nextLevel }), Theme.Paper.Warning)
		elseif not d.nextRank then
			line(Text.get(use, "skills.detail.maxRank"), Theme.Paper.TextMuted)
		end
		if #d.rows > 0 then
			tableRow({
				Text.get(use, "skills.table.field"),
				Text.get(use, "skills.table.now"),
				Text.get(use, "skills.table.after"),
				Text.get(use, "skills.table.diff"),
			}, true)
			for _, entry in d.rows do
				local diff = entry.diff
				tableRow(
					{ Details.fieldLabel(use, entry.field), number(entry.now), number(entry.after), signed(diff) },
					false,
					if diff and diff ~= 0 then Theme.Paper.Success else Theme.Paper.TextMuted
				)
			end
		end
		local heal = SkillInfo.healLine(use, skill, shown) -- S69
		if heal ~= "" then
			line(heal, Theme.Paper.Text)
		end
		-- "Cost and cooldown"
		if table.find(d.sections, "cost") then
			sub(Text.get(use, "skills.section.cost"))
			local shape = SkillInfo.shapeLine(use, skill, shown)
			if shape ~= "" then
				line(shape, Theme.Paper.Text)
			end
			line(SkillInfo.costLine(use, skill, shown), Theme.Paper.Text)
			-- Weapon element (Mage, S18): requirement in red while the weapon does not fit, adaptive note.
			local element = Skills.requiredElement(skill)
			if element then
				local weapon = use(ctx.weapon)
				local fits = type(weapon) == "table" and weapon.element == element
				pictureLine(
					UiArt.element(element),
					20,
					Text.get(use, "skill.requiresElement", { element = Text.get(use, `element.{element}`) }),
					if fits then Theme.readable(Elements.COLORS[element], "paper") else Theme.Paper.Danger
				)
			elseif skill.adaptive then
				line(Text.get(use, "skill.adaptive"), Theme.Paper.Text)
			end
			if skill.path and actual > 0 then
				local usable, err = Paths.skillUsable(character, skill.id, weapons)
				if not usable and err then
					line(Text.get(use, err), Theme.Paper.Danger)
				end
			end
		end
		-- "Breakpoints" (the cards have their own section label)
		for _, item in Breakpoints.new(s, use, ctx, actions, skill, Paths.bpRank(character, skill.id), not touch) do
			add(item)
		end
		-- "Changes from directions"
		if #d.mods > 0 then
			sub(Text.get(use, "skills.section.directions"))
			for _, mod in d.mods do
				local args = {
					node = Text.get(use, mod.nameKey),
					path = Text.get(use, mod.pathNameKey),
					rank = mod.rank,
					max = mod.maxRank,
					row = mod.row,
				}
				if mod.rank <= 0 then
					line(`• {Text.get(use, "skills.mod.idle", args)}`, Theme.Paper.TextMuted)
				elseif mod.active then
					line(`• {Text.get(use, "skills.mod.active", args)}`, Theme.Paper.Success)
				else
					line(`• {Text.get(use, "skills.mod.inactive", args)}`, Theme.Paper.Warning)
				end
			end
		end
		-- "From items" (S134g, DESIGN-18 §0.9)
		if #d.items > 0 then
			sub(Text.get(use, "skills.section.items"))
			for _, nameKey in d.items do
				line(Text.get(use, "skills.item.line", { name = Text.get(use, nameKey) }), Theme.Paper.Success)
			end
		end
		-- "Full description", folded
		sub(Text.get(use, "skills.section.full"))
		local open = use(ctx.fullOpen)
		add(s:New("TextButton")({
			Name = "FullToggle",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, if touch then Theme.Size.MinTouch else Theme.TextSize.Small + 10),
			AutoButtonColor = false,
			Text = Text.get(use, if open then "skills.full.hide" else "skills.full.show"),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Paper.Link,
			TextXAlignment = Enum.TextXAlignment.Left,
			[OnEvent("Activated")] = function()
				ctx.fullOpen:set(not Fusion.peek(ctx.fullOpen))
			end,
		}))
		if open then
			line(Details.boldNumbers(SkillInfo.full(use, skill, shown)))
		end
	end

	if node and view then
		local rank = view.rank
		if skill then
			-- the skill's node: only its own part (the skill text is above)
			sub(Text.get(use, "skills.section.node"))
			line(
				Text.get(use, "paths.node.rank", { rank = rank, max = node.maxRank }),
				Theme.Paper.Text,
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
			line(kind, Theme.Paper.Text, Theme.TextSize.Body, Theme.Fonts.BodyBold)
			sub(Text.get(use, "skills.section.state"))
			line(Text.get(use, "paths.node.rank", { rank = rank, max = node.maxRank }), Theme.Paper.Text)
		end
		-- FIX 2026-10-14: the row's place in the tree (the tree shows only its level)
		if row then
			local head = if row.need == 0
				then Text.get(use, "paths.rowFree", { row = row.index, level = row.level })
				else Text.get(
					use,
					"paths.row",
					{ row = row.index, level = row.level, have = row.have, need = row.need }
				)
			if row.kind ~= "normal" then
				head ..= ` · {Text.get(use, `paths.row.{row.kind}`)}`
			end
			line(head, Theme.Paper.TextMuted, Theme.TextSize.Small)
		end
		if view.scale < 1 then
			line(
				Text.get(
					use,
					"paths.node.dip",
					{ pct = math.floor(view.scale * 100 + 0.5), n = Paths.TEAM_FULL_POINTS }
				),
				Theme.Paper.Warning
			)
		end
		if node.weapon then
			line(
				Text.get(use, "paths.node.weapon", { weapons = PathView.weaponText(node.weapon, lang) }),
				if view.weaponOk then Theme.Paper.Text else Theme.Paper.Danger
			)
		end
		if rank > 0 and not view.active then
			line(Text.get(use, "paths.node.inactive"), Theme.Paper.Danger)
		end
		if row and row.closedKey then
			line(Text.get(use, row.closedKey, row.closedArgs), Theme.Paper.TextMuted)
		end
		if not skill then
			if rank > 0 then
				sub(Text.get(use, "paths.node.now"))
				line(Text.get(use, node.descKey, Paths.nodeArgs(node, rank, view.scale)))
				if rank < node.maxRank then
					sub(Text.get(use, "paths.node.atRank", { rank = rank + 1 }))
					line(Text.get(use, node.descKey, Paths.nodeArgs(node, rank + 1, view.scale)), Theme.Paper.Success)
				end
			else
				sub(Text.get(use, "paths.node.atRank", { rank = 1 }))
				line(Text.get(use, node.descKey, Paths.nodeArgs(node, 1, view.scale)), Theme.Paper.TextMuted)
			end
		end
	end

	-- the phone sheet has no room for reasons next to its buttons: they go here
	if touch then
		for _, spec in Details.actions(use, ctx, actions) do
			if not spec.enabled and spec.reason then
				line(`{spec.text}: {spec.reason}`, Theme.Paper.TextMuted)
			end
		end
	end
	return out
end

return Details
