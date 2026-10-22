--!strict
-- The tree of a weapon pool in the skills window (S139, DESIGN-18 §5, §12; replaces the S56-S138 Base list, owner:
-- "everything blends together on the left"). Drawn only from Logic/PathView.poolView: a toolbar ("Spend as the pool
-- suggests", "Reset"), the role columns signed above the tree (PC: the role names, phone: small icons with the name
-- on a long press), one row per rung of the shared ladder with its level on the left, a tile in the column of its role
-- (analogous skills of every pool stand in one column) and threads joining the tiles of a column; the direction
-- skills in a "From directions" row and a skill without a role (none since S145, every pool is on the ladder) in an
-- "Others" row under the ladder. A tile (SkillsWindow/Tile): the picture, ranks "4/10" (with "+1" reserved),
-- a padlock with the level, a gold "!" for a breakpoint to choose or the chosen letters, a green "+" while a rank can
-- be bought, the bar slot. No description on the tree: the PC hover shows the name and the short sentence, a click
-- selects (details panel), a tap opens the phone sheet; a bought active of the worn pool drags onto the bar.
-- Owner 2026-10-21 (too many detailed descriptions): the preview note of another pool in one short line with the rest
-- behind its "i"; the "click / drag" hint only until a skill is selected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Parent.Components.InfoTip)
local Inventory = require(ReplicatedStorage.Shared.Logic.Inventory)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local SectionLabel = require(script.Parent.Parent.Parent.Components.SectionLabel)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local SkillInfo = require(script.Parent.Parent.Parent.SkillInfo)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tile = require(script.Parent.Tile)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local PoolTree = {}

-- Icons of the role columns (the phone's column heads; the PC shows the role names).
PoolTree.ROLE_GLYPH = table.freeze({
	S = "🎯",
	A = "✺",
	K = "🌀",
	O = "🛡",
	P = "✦",
	U = "☄",
	C = "⚜",
})

type Geometry = { tile: number, column: number, level: number, row: number, empty: number, head: number }

-- The PC column heads: one text size (Caption) for every role name. The names are wider than a column, so the heads
-- take two lines in turn (odd columns on top, with a tick down to their column; even ones below), which gives each
-- head two columns of room (HEAD_WIDTH; uifit.spec checks every role name fits it).
local HEAD_LINE = 18
PoolTree.HEAD_WIDTH = 120 -- two PC columns (2 x 64) less a gap

local PC: Geometry = {
	tile = Tile.SIZE,
	column = 64,
	level = 36,
	row = Tile.SIZE + Tile.CAPTION + 10,
	empty = 24,
	head = 2 * HEAD_LINE,
}
local TOUCH: Geometry = {
	tile = Tile.SIZE_TOUCH,
	column = 62,
	level = 34,
	row = Tile.SIZE_TOUCH + Tile.CAPTION + 10,
	empty = 26,
	head = Theme.Size.MinTouch - 14,
}
local THREAD = 3

local SUCCESS_HEX = Theme.hex(Theme.Paper.Success)

-- "4/10", "4+1/10" (the reserved part in green), "" while locked (the padlock says the level).
local function caption(tile: PathView.PoolTile): string
	if tile.locked then
		return ""
	end
	local text = tostring(tile.bought)
	if tile.reserved > 0 then
		text ..= `<font color="{SUCCESS_HEX}">+{tile.reserved}</font>`
	end
	return `{text}/{tile.max}`
end

-- A gold "!" while a breakpoint waits for a choice, else the letters of the reached ones ("A", "AB").
local function bpMark(tile: PathView.PoolTile): Tile.Mark?
	local letters = ""
	for _, mark in tile.bp do
		if mark.mark == "pending" then
			return { text = "!", color = Theme.Brass.Bright, textColor = Theme.Paper.Heading }
		elseif mark.mark == "a" or mark.mark == "b" then
			letters ..= string.upper(mark.mark)
		end
	end
	if letters == "" then
		return nil
	end
	return { text = letters, color = Theme.Paper.Surface, textColor = Theme.Paper.Text }
end

-- One skill tile of the pool (Tile), selected by a click.
function PoolTree.tile(
	s: Scope,
	use: Fusion.Use,
	ctx: Context.Ctx,
	tile: PathView.PoolTile,
	touch: boolean,
	geometry: Geometry,
	accent: Color3
): Instance
	local skill = SkillData.get(tile.skillId) :: SkillData.SkillDef
	local name = Text.get(use, skill.nameKey)
	local passive = skill.type == "passive"
	return Tile.new(s, {
		Name = skill.id,
		Size = geometry.tile,
		Width = geometry.column - 4,
		ArtKey = UiArt.skill(skill.id),
		Glyph = skill.glyph,
		Round = passive,
		Lit = tile.rank > 0,
		-- S143: grey without the skill's own weapon (Shield Bash without a shield), red when bought
		Dim = not tile.weaponOk,
		Broken = tile.rank > 0 and not tile.weaponOk,
		Accent = accent,
		Selected = s:Computed(function(use2): boolean
			local sel = use2(ctx.selected)
			return sel ~= nil and sel.kind == "skill" and sel.id == skill.id
		end),
		Plus = tile.buyable,
		Mark = bpMark(tile),
		Slot = if passive then nil else tile.onBar,
		Lock = if tile.locked then `🔒{tile.unlock}` else nil,
		Caption = caption(tile),
		Tooltip = if tile.weaponError
			then `{name}\n{SkillInfo.short(use, skill, tile.rank)}\n{Text.get(use, tile.weaponError)}`
			else `{name}\n{SkillInfo.short(use, skill, tile.rank)}`,
		Touch = touch,
		OnClick = function()
			ctx.selected:set({ kind = "skill", id = skill.id })
			if touch then
				ctx.previewOpen:set(false)
				ctx.sheet:set(true)
			end
		end,
		DragId = if tile.active
				and not passive
				and tile.bought > 0
				and not tile.locked
			then `skill:{skill.id}`
			else nil,
	})
end

function PoolTree.new(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions, touch: boolean): Fusion.Computed<any>
	local geometry = if touch then TOUCH else PC
	local buttonHeight = if touch then Theme.Size.MinTouch else Theme.Size.ButtonHeightSmall
	local width = geometry.level + #PathView.COLUMNS * geometry.column

	return scope:Computed(function(use, s: Scope): { Instance }
		if not use(ctx.onPools) then
			return {}
		end
		local character: any = use(ctx.character)
		local view = use(ctx.poolView)
		if not character or not view then
			return {}
		end
		local class = Classes.get(character.class)
		local accent = if class then Theme.readable(class.color, "paper") else Theme.Paper.Heading
		local out: { Instance } = {}
		local function add(item: Instance)
			(item :: any).LayoutOrder = #out + 1
			table.insert(out, item)
		end
		-- a muted note; owner 2026-10-21: `info` puts the longer text behind an "i" on its right
		local function note(text: string, color: Color3?, info: string?): Instance
			local label = s:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, if info then -40 else -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = text,
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = color or Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			local item = if info
				then s:New("Frame")({
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					[Children] = {
						label,
						InfoTip.new(s, {
							Text = info,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -8, 0, 0),
						}),
					},
				})
				else label
			add(item)
			return item
		end

		-- Toolbar: "Spend as the pool suggests", "Reset" (free below Progression.freeRespecLevel or with respecFree;
		-- S138: else with a Scroll of Skill Renewal in the backpack).
		local free = character.respecFree == true or character.level < Progression.freeRespecLevel
		local inventory = use(ctx.inventory)
		local scrolls = if type(inventory) == "table" then Inventory.count(inventory, "scroll_skillreset") else 0
		add(s:New("Frame")({
			Name = "Toolbar",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, buttonHeight),
			[Children] = {
				s:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, Theme.Padding.Small),
				}),
				Button(s, {
					LayoutOrder = 1,
					Size = UDim2.new(0.6, -Theme.Padding.Small, 1, 0),
					Variant = "secondary",
					TextSize = Theme.TextSize.Small,
					Text = Text.get(use, "skills.points.suggest"),
					Disabled = view.free <= 0,
					OnClick = actions.suggest,
				}),
				Button(s, {
					LayoutOrder = 2,
					Size = UDim2.fromScale(0.4, 1),
					Variant = "ghost",
					TextSize = Theme.TextSize.Small,
					Text = Text.get(use, if free then "skills.points.resetFree" else "skills.points.resetScroll"),
					Disabled = not free and scrolls < 1,
					OnClick = actions.resetSkills,
				}),
			},
		}))
		if not view.active then
			note(Text.get(use, "skills.pool.preview.short"), nil, Text.get(use, "skills.pool.preview"))
		end
		if not touch then
			-- owner 2026-10-21: only until a skill is selected (a separate state: the tree is not rebuilt on a click)
			s:Hydrate(note(Text.get(use, "skills.tree.hint")))({
				Visible = s:Computed(function(use2): boolean
					return use2(ctx.selected) == nil
				end),
			})
		end

		local function gridOf(name: string, tiles: { PathView.PoolTile }): Instance
			local items: { Instance } = {}
			for i, tile in tiles do
				local item = PoolTree.tile(s, use, ctx, tile, touch, geometry, accent);
				(item :: any).LayoutOrder = i;
				(item :: any).AnchorPoint = Vector2.zero
				table.insert(items, item)
			end
			return s:New("Frame")({
				Name = name,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(width, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				[Children] = {
					s:New("UIPadding")({ PaddingLeft = UDim.new(0, geometry.level), PaddingTop = UDim.new(0, 10) }),
					s:New("UIGridLayout")({
						CellSize = UDim2.fromOffset(geometry.column, geometry.tile + Tile.CAPTION + 6),
						CellPadding = UDim2.fromOffset(0, 4),
						FillDirectionMaxCells = #PathView.COLUMNS,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					items :: any,
				},
			})
		end
		local function extraRow(row: PathView.PoolRow)
			add(SectionLabel(s, {
				Name = if row.kind == "paths" then "PathsLabel" else "OtherLabel",
				Text = Text.get(use, if row.kind == "paths" then "skills.row.paths" else "skills.row.other"),
			}))
			add(gridOf(if row.kind == "paths" then "Paths" else "Other", row.tiles))
		end

		local ladder: { PathView.PoolRow } = {}
		local extra: { PathView.PoolRow } = {}
		for _, row in view.rows do
			if row.kind == "ladder" then
				table.insert(ladder, row)
			elseif #row.tiles > 0 then
				table.insert(extra, row)
			end
		end
		-- The column heads: one text size for all (no TextScaled per head); on the PC in two lines in turn (HEAD_LINE).
		local heads: { Instance } = {}
		for i, column in view.columns do
			local roleName = Text.get(use, `skills.role.{column}`)
			local x = geometry.level + (i - 0.5) * geometry.column
			local lower = not touch and i % 2 == 0
			local head = s:New("TextLabel")({
				Name = column,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(x, if lower then HEAD_LINE else 0),
				Size = if touch
					then UDim2.fromOffset(geometry.column - 4, geometry.head)
					else UDim2.fromOffset(PoolTree.HEAD_WIDTH, HEAD_LINE),
				BackgroundTransparency = 1,
				Text = if touch then PoolTree.ROLE_GLYPH[column] or column else roleName,
				TextSize = if touch then Theme.TextSize.Body else Theme.TextSize.Caption,
				TextTruncate = Enum.TextTruncate.AtEnd,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = Theme.Paper.Label,
			})
			Tooltip.attach(s, head :: GuiObject, roleName)
			table.insert(heads, head)
			if not touch and not lower then
				-- the top line's tick down past the lower heads, so the name reads as its column's
				table.insert(
					heads,
					s:New("Frame")({
						Name = `{column}Tick`,
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.fromOffset(x, HEAD_LINE + 3),
						Size = UDim2.fromOffset(1, HEAD_LINE - 6),
						BackgroundColor3 = Theme.Paper.Rule,
						BorderSizePixel = 0,
					})
				)
			end
		end
		add(s:New("Frame")({
			Name = "Columns",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(width, geometry.head),
			[Children] = heads :: any,
		}))

		-- The ladder: a row per rung, the tile in its role's column, threads down each column.
		local parts: { Instance } = {}
		local y = 0
		local lastInColumn: { [string]: { y: number, lit: boolean } } = {}
		for i, row in ladder do
			local filled = #row.tiles > 0
			local height = if filled then geometry.row else geometry.empty
			local centre = if filled then y + geometry.tile / 2 + 4 else y + height / 2
			local column = row.column or "S"
			local ci = table.find(view.columns, column) or 1
			local x = geometry.level + (ci - 0.5) * geometry.column
			-- the row's band (alternating, so a row reads across) and its level on the left
			table.insert(
				parts,
				s:New("Frame")({
					Name = `Band{i}`,
					Position = UDim2.fromOffset(0, y),
					Size = UDim2.fromOffset(width, height),
					BackgroundColor3 = Theme.Paper.Sunken,
					BackgroundTransparency = if i % 2 == 0 then 0.6 else 1,
					BorderSizePixel = 0,
					ZIndex = 1,
				})
			)
			table.insert(
				parts,
				s:New("TextLabel")({
					Name = `Level{i}`,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromOffset(0, centre),
					Size = UDim2.fromOffset(geometry.level - 6, math.min(height - 4, 22)),
					BackgroundColor3 = Theme.Paper.Raised,
					BackgroundTransparency = if filled then 0 else 0.5,
					Text = tostring(row.level),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Caption,
					TextColor3 = if filled then Theme.Paper.Text else Theme.Paper.TextMuted,
					ZIndex = 2,
					[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				})
			)
			if filled then
				for _, tile in row.tiles do
					local item = PoolTree.tile(s, use, ctx, tile, touch, geometry, accent);
					(item :: any).Position = UDim2.fromOffset(x, y + 4)
					table.insert(parts, item)
					-- the thread from the tile above in this column
					local above = lastInColumn[column]
					if above then
						local lit = above.lit and tile.rank > 0
						table.insert(
							parts,
							s:New("Frame")({
								Name = `Thread{i}`,
								AnchorPoint = Vector2.new(0.5, 0),
								Position = UDim2.fromOffset(x, above.y),
								Size = UDim2.fromOffset(THREAD, centre - above.y),
								BackgroundColor3 = if lit then Theme.Brass.Frame else Theme.Paper.Rule,
								BorderSizePixel = 0,
								ZIndex = 2,
							})
						)
					end
					lastInColumn[column] = { y = centre, lit = tile.rank > 0 }
				end
			else
				-- an empty rung: its code in a faint plaque where its skill will stand
				table.insert(
					parts,
					s:New("TextLabel")({
						Name = `Empty{i}`,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromOffset(x, centre),
						Size = UDim2.fromOffset(geometry.column - 18, height - 8),
						BackgroundColor3 = Theme.Paper.Sunken,
						BackgroundTransparency = 0.3,
						Text = row.code or "",
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Caption,
						TextColor3 = Theme.Paper.TextMuted,
						ZIndex = 2,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							s:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Thickness = Theme.Stroke.Thin,
								Color = Theme.Paper.Border,
								Transparency = 0.4,
							}),
						},
					})
				)
			end
			y += height
		end
		add(s:New("Frame")({
			Name = "Ladder",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(width, y),
			[Children] = parts :: any,
		}))

		for _, row in extra do
			extraRow(row)
		end
		return out
	end)
end

return PoolTree
