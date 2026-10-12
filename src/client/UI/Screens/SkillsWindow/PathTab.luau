--!strict
-- A path tab of the skills window (S59, ROZWOJ 4), drawn only from Logic/PathView.path: the path header (name, role,
-- description, the weapon ✓ / ✗, the path title, "Choose as main" / "Change path (scroll)" or why not), one warning
-- bar before the first row the wrong weapon blocks, then the rows from the top ("Row 4 · lv. 26 · 4/6 points in the
-- path", the row kind, a closed row grey with its reason) with their node cards (any number per row; "or" between the
-- cards of a choice row) and "Refund all nodes" at the end. PC: cards side by side in a 510 px list; phone: cards
-- one under another at full width.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NodeCard = require(script.Parent.NodeCard)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local PathTab = {}

PathTab.LIST_WIDTH = 510
local GAP = 6
local OR_WIDTH = 44
local OR_HEIGHT = 24

function PathTab.new(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions, touch: boolean): Fusion.Computed<any>
	local buttonHeight = if touch then Theme.Size.MinTouch else Theme.Size.ButtonHeightSmall

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
		local lang = use(Text.Lang)
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
				TextColor3 = color or Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
			}))
		end
		local function button(text: string, enabled: boolean, run: () -> ())
			add(Button(s, {
				Size = UDim2.fromOffset(260, buttonHeight),
				TextSize = Theme.TextSize.Small,
				Variant = "primary",
				Text = text,
				Disabled = not enabled,
				OnClick = run,
			}))
		end

		-- Path header
		label(Text.get(use, def.nameKey), Theme.Colors.Gold, Theme.Fonts.Heading, Theme.TextSize.Large)
		label(Text.get(use, `paths.role.{def.role}`), Theme.Colors.Parchment, Theme.Fonts.BodyBold)
		label(Text.get(use, def.descKey), Theme.Colors.Text)
		local weapons = Text.get(use, "paths.weapon.label", { weapons = PathView.weaponText(def.weapon, lang) })
		label(
			`{if view.weaponOk then "✓" else "✗"} {weapons}`,
			if view.weaponOk then Theme.Colors.Success else Theme.Colors.DangerHover,
			Theme.Fonts.BodyBold
		)
		if not view.weaponOk then
			label(Text.get(use, "paths.weapon.missing"), Theme.Colors.DangerHover)
		end
		local title = TitleData.get(def.titleId)
		if title then
			label(Text.get(use, "paths.title", { title = Text.get(use, title.nameKey) }), Theme.Colors.Parchment)
		end
		local main = view.main
		if main.ok then
			local cost: ("free" | "scroll")? = main.cost
			button(Text.get(use, if cost == "scroll" then "paths.changeMain" else "paths.chooseMain"), true, function()
				actions.chooseMain(def.id, cost)
			end)
		elseif main.reason == "paths.error.sameMain" then
			label(Text.get(use, "paths.isMain"), Theme.Colors.Success, Theme.Fonts.BodyBold)
		elseif main.reason == "paths.error.mainLevel" then
			button(Text.get(use, "paths.chooseMain"), false, function() end)
			label(Text.get(use, "paths.mainFrom", { level = Paths.MAIN_LEVEL }), Theme.Colors.TextMuted)
		else
			button(Text.get(use, "paths.chooseMain"), false, function() end)
			label(Text.get(use, main.reason or "error.internal"), Theme.Colors.TextMuted)
		end

		-- Rows
		local warned = false
		for _, row in view.rows do
			if row.weaponBlocked and not warned then
				warned = true
				add(s:New("TextLabel")({
					Name = "WeaponBar",
					Size = UDim2.new(1, -8, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Theme.Colors.Background,
					Text = Text.get(use, "paths.weapon.bar"),
					TextWrapped = true,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 14,
					TextColor3 = Theme.Colors.Warning,
					TextXAlignment = Enum.TextXAlignment.Left,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIStroke")({ Color = Theme.Colors.Warning, Thickness = 1 }),
						s:New("UIPadding")({
							PaddingTop = UDim.new(0, 6),
							PaddingBottom = UDim.new(0, 6),
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
						}),
					},
				}))
			end
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
			label(head, if row.open then Theme.Colors.Parchment else Theme.Colors.TextMuted, Theme.Fonts.BodyBold)
			if row.closedKey then
				label(Text.get(use, row.closedKey, row.closedArgs), Theme.Colors.TextMuted, nil, 14)
			end
			local n = #row.nodes
			local ors = if row.choice then n - 1 else 0
			local function orLabel(size: UDim2): Instance
				return s:New("TextLabel")({
					BackgroundTransparency = 1,
					Size = size,
					Text = Text.get(use, "paths.row.or"),
					FontFace = Theme.Fonts.Body,
					TextSize = 14,
					TextColor3 = Theme.Colors.TextMuted,
				})
			end
			if touch then
				for i, nodeView in row.nodes do
					if i > 1 and row.choice then
						add(orLabel(UDim2.new(1, -8, 0, OR_HEIGHT)))
					end
					add(
						NodeCard.new(
							s,
							use,
							ctx,
							actions,
							nodeView,
							row.open,
							true,
							UDim2.new(1, -8, 0, NodeCard.HEIGHT_TOUCH)
						)
					)
				end
			else
				local items = n + ors
				local width = (PathTab.LIST_WIDTH - 12 - (items - 1) * GAP - ors * OR_WIDTH) / math.max(1, n)
				local children: { Instance } = {}
				for i, nodeView in row.nodes do
					if i > 1 and row.choice then
						local item = orLabel(UDim2.fromOffset(OR_WIDTH, NodeCard.HEIGHT));
						(item :: any).LayoutOrder = #children + 1
						table.insert(children, item)
					end
					local card = NodeCard.new(
						s,
						use,
						ctx,
						actions,
						nodeView,
						row.open,
						false,
						UDim2.fromOffset(width, NodeCard.HEIGHT)
					);
					(card :: any).LayoutOrder = #children + 1
					table.insert(children, card)
				end
				add(s:New("Frame")({
					Name = `Row{row.index}`,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -8, 0, NodeCard.HEIGHT),
					[Children] = {
						s:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, GAP),
						}),
						children :: any,
					},
				}))
			end
		end

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
