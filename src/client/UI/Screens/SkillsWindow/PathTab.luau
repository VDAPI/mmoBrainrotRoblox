--!strict
-- A path tab of the skills window (S59, ROZWOJ 4), drawn only from Logic/PathView.path.
-- FIX 2026-10-14 (owner: "skill trees should look like trees, descriptions only after a click, before that only
-- connected pictures"): a short header (the path name, a click on it shows the path's description in the details;
-- S138: the ranks in this direction, "leading direction" when it leads, "one capstone per set"), then the tree: one row of node tiles (NodeCard) per path row from the top, a trunk
-- down the middle with a branch to every node, gold where the row is open or the node bought, a diamond on the trunk
-- for a choice row ("pick one"), a knot where branches meet, and the row's level on the left ("⚠" when the set's
-- capstone is in another direction, S138; the row's points, kind and reason in its tooltip). No description text on the tree: a click / tap on a
-- node shows it in the PC details panel or the phone sheet (Buy / Refund there). "Refund all nodes" at the end.
-- Same tree on PC (510 px list) and phone (full width, bigger tiles).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NodeCard = require(script.Parent.NodeCard)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local PathTab = {}

PathTab.LIST_WIDTH = 510
local TOP_PAD = 12
local LINE = 3 -- connector thickness
local KNOT = 10 -- knot / diamond on the trunk
local LEVEL_WIDTH = 44

-- Text of a row's tooltip: "Row 4 · lv. 26 · 4/6 points in the path · pick one" and why it is closed.
local function rowText(use: Fusion.Use, row: PathView.RowView): string
	local head = if row.need == 0
		then Text.get(use, "paths.rowFree", { row = row.index, level = row.level })
		else Text.get(use, "paths.row", { row = row.index, level = row.level, have = row.have, need = row.need })
	if row.kind ~= "normal" then
		head ..= ` · {Text.get(use, `paths.row.{row.kind}`)}`
	end
	if row.closedKey then
		head ..= `\n{Text.get(use, row.closedKey, row.closedArgs)}`
	end
	return head
end

function PathTab.new(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions, touch: boolean): Fusion.Computed<any>
	local buttonHeight = if touch then Theme.Size.MinTouch else Theme.Size.ButtonHeightSmall
	local tileSize = if touch then NodeCard.TILE_TOUCH else NodeCard.TILE
	local rowHeight = tileSize + NodeCard.PIPS + (if touch then 30 else 24)
	local spread = if touch then 124 else 112 -- distance between the centres of neighbouring nodes

	return scope:Computed(function(use, s: Scope): { Instance }
		local tab = use(ctx.activeTab)
		local character = use(ctx.character)
		if tab == "base" or tab == "soon" or not character then
			return {}
		end
		local view = PathView.path(character, tab, use(ctx.weapons))
		if not view then
			return {}
		end
		local def = view.path
		local out: { Instance } = {}
		local function add(item: Instance)
			(item :: any).LayoutOrder = #out + 1
			table.insert(out, item)
		end
		local function label(text: string, color: Color3?, font: Font?, size: number?)
			add(s:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = text,
				TextWrapped = true,
				FontFace = font or Theme.Fonts.Body,
				TextSize = size or Theme.TextSize.Small,
				TextColor3 = color or Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
			}))
		end
		-- Header: the name (a click shows the path's description), the ranks in the direction (S138).
		local pathSelected = s:Computed(function(use2): boolean
			local sel = use2(ctx.selected)
			return sel ~= nil and sel.kind == "path" and sel.id == def.id
		end)
		add(s:New("TextButton")({
			Name = "PathName",
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = `{Text.get(use, def.nameKey)}  ⓘ`,
			TextWrapped = true,
			FontFace = Theme.Fonts.Display,
			TextSize = Theme.TextSize.Large,
			TextColor3 = s:Computed(function(use2): Color3
				return if use2(pathSelected) then Theme.Paper.Heading else Theme.Paper.Heading
			end),
			TextXAlignment = Enum.TextXAlignment.Left,
			[OnEvent("Activated")] = function()
				ctx.selected:set({ kind = "path", id = def.id })
				if touch then
					ctx.previewOpen:set(false)
					ctx.sheet:set(true)
				end
			end,
		}))
		-- S138 (DESIGN-18 §7): a direction to mix, no main path choice and no direction weapon
		label(Text.get(use, "skills.tree.points", { n = view.spent }), Theme.Paper.Text, Theme.Fonts.BodyBold)
		if view.leading then
			label(Text.get(use, "paths.isMain"), Theme.Paper.Success, Theme.Fonts.BodyBold)
		end
		label(Text.get(use, "skills.tree.oneCapstone"), Theme.Paper.TextMuted)

		-- The tree.
		local rows = view.rows
		local parts: { Instance } = {}
		local function centreY(i: number): number
			return TOP_PAD + (i - 1) * rowHeight + tileSize / 2
		end
		local function bar(name: string, x: number, y: number, w: number, h: number, color: Color3, lit: boolean)
			table.insert(
				parts,
				s:New("Frame")({
					Name = name,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, x, 0, y),
					Size = UDim2.fromOffset(w, h),
					BackgroundColor3 = color,
					BackgroundTransparency = if lit then 0 else 0.35,
					BorderSizePixel = 0,
					ZIndex = 1,
				})
			)
		end
		for i, row in rows do
			local y = centreY(i)
			local n = #row.nodes
			-- trunk down to the next row: gold once that row is open
			local nextRow = rows[i + 1]
			if nextRow then
				local length = rowHeight
				bar(
					`Trunk{i}`,
					0,
					y + length / 2,
					LINE,
					length,
					if nextRow.open then Theme.Paper.Heading else Theme.Paper.TextMuted,
					nextRow.open
				)
			end
			local anyBought = false
			for j, nodeView in row.nodes do
				local dx = (j - (n + 1) / 2) * spread
				if nodeView.rank > 0 then
					anyBought = true
				end
				if dx ~= 0 then
					local lit = nodeView.rank > 0
					bar(
						`Branch{i}_{j}`,
						dx / 2,
						y,
						math.abs(dx),
						LINE,
						if lit then Theme.Paper.Heading elseif row.open then Theme.Paper.Label else Theme.Paper.TextMuted,
						lit or row.open
					)
				end
				table.insert(
					parts,
					NodeCard.new(s, use, ctx, nodeView, row.open, touch, UDim2.new(0.5, dx, 0, y - tileSize / 2))
				)
			end
			-- where the branches meet: a diamond for a choice row ("pick one"), a knot otherwise
			if row.choice or n % 2 == 0 then
				table.insert(
					parts,
					s:New("Frame")({
						Name = `Knot{i}`,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 0, y),
						Size = UDim2.fromOffset(KNOT, KNOT),
						Rotation = if row.choice then 45 else 0,
						BackgroundColor3 = if anyBought
							then Theme.Brass.Bright
							elseif row.open then Theme.Paper.Rule
							else Theme.Paper.Border,
						BorderSizePixel = 0,
						ZIndex = 2,
						[Children] = if row.choice then nil else s:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					})
				)
			end
			-- the row's level on the left; its points, kind and why it is closed in the tooltip
			local blocked = row.closedKey == "skills.error.capstoneTaken"
			local level = s:New("TextLabel")({
				Name = `Level{i}`,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromOffset(0, y),
				Size = UDim2.fromOffset(LEVEL_WIDTH, 24),
				BackgroundColor3 = Theme.Paper.Sunken,
				BackgroundTransparency = 0.3,
				Text = if blocked then `⚠{row.level}` else tostring(row.level),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = if blocked
					then Theme.Paper.Warning
					elseif row.open then Theme.Paper.Text
					else Theme.Paper.TextMuted,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					s:New("UIStroke")({
						Color = if row.open then Theme.Paper.Rule else Theme.Paper.Border,
						Thickness = 1,
					}),
				},
			})
			Tooltip.attach(s, level :: GuiObject, rowText(use, row))
			table.insert(parts, level)
		end
		add(s:New("Frame")({
			Name = "Tree",
			Size = UDim2.new(1, -8, 0, TOP_PAD * 2 + #rows * rowHeight - (rowHeight - tileSize - NodeCard.PIPS)),
			BackgroundTransparency = 1,
			[Children] = parts :: any,
		}))

		-- Footer
		add(Button(s, {
			Size = UDim2.fromOffset(260, buttonHeight),
			TextSize = Theme.TextSize.Small,
			Variant = "ghost",
			Text = Text.get(use, "paths.resetAll"),
			OnClick = actions.resetAll,
		}))
		return out
	end)
end

return PathTab
