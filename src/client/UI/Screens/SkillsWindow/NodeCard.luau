--!strict
-- A node of a path tree (FIX 2026-10-14, owner: the path tabs look like trees and show descriptions only after a
-- click; before it the S59 card with text and "+" / "−"). Only pictures on the tree: the tile (S119 skill picture or
-- the glyph), a gold frame once bought, a white frame while selected, a red frame when a bought node does not work
-- now, a green "+" corner while a rank can be bought, and the rank pips under it ("●●○", "33%" for team nodes outside
-- the main path, "⚠" when the node's weapon does not fit). Greyed in a closed row or when the other node of a choice
-- row was taken. A click / tap selects it: the PC details panel or the phone sheet show its text with Buy / Refund
-- (Details). PC hover shows only the name. A bought active skill node drags onto the bar. Everything comes from a
-- PathView.NodeView.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Context = require(script.Parent.Context)
local DragDrop = require(script.Parent.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local NodeCard = {}

NodeCard.TILE = 56
NodeCard.TILE_TOUCH = 60
NodeCard.PIPS = 18 -- the rank line under the tile
NodeCard.WIDTH = 92 -- the node's frame (the pips line may be wider than the tile)

local WARN_HEX = "#E0A23B"
local DANGER_HEX = "#CC5248"
local SELECTED = Color3.new(1, 1, 1)

-- "●●○  33%  ⚠" (RichText).
local function dots(view: PathView.NodeView): string
	local text = string.rep("●", view.rank) .. string.rep("○", math.max(0, view.node.maxRank - view.rank))
	if view.scale < 1 then
		text ..= ` <font color="{WARN_HEX}">{math.floor(view.scale * 100 + 0.5)}%</font>`
	end
	if not view.weaponOk then
		text ..= ` <font color="{DANGER_HEX}">⚠</font>`
	end
	return text
end

-- The node at `position` (its top centre; AnchorPoint 0.5, 0).
function NodeCard.new(
	s: Scope,
	use: Fusion.Use,
	ctx: Context.Ctx,
	view: PathView.NodeView,
	rowOpen: boolean,
	touch: boolean,
	position: UDim2
): Instance
	local node = view.node
	local dim = view.taken or not rowOpen
	local bought = view.rank > 0
	local broken = bought and not view.active
	local tileSize = if touch then NodeCard.TILE_TOUCH else NodeCard.TILE
	local selected = s:Computed(function(use2): boolean
		local sel = use2(ctx.selected)
		return sel ~= nil and sel.kind == "node" and sel.id == node.id
	end)

	-- S119: a skill node shows its skill's picture once loaded (other nodes have no pictures: glyph).
	local artKey = if node.kind == "skill" and node.skill then UiArt.skill(node.skill) else nil
	local artShown = ArtIcon.Shown(s, artKey)
	local tile = s:New("TextButton")({
		Name = "Tile",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(tileSize, tileSize),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = s:Computed(function(use2): Color3
			if use2(selected) then
				return Theme.Colors.PanelHover
			end
			return if bought then Theme.Colors.PanelRaised else Theme.Colors.Background
		end),
		BackgroundTransparency = if dim then 0.45 else 0,
		ZIndex = 3,
		[OnEvent("Activated")] = function()
			ctx.selected:set({ kind = "node", id = node.id })
			if touch then
				ctx.previewOpen:set(false)
				ctx.sheet:set(true)
			end
		end,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			s:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = s:Computed(function(use2): number
					return if use2(selected) or broken then 3 else 2
				end),
				Color = s:Computed(function(use2): Color3
					if use2(selected) then
						return SELECTED
					elseif broken then
						return Theme.Colors.Danger
					end
					return if bought then Theme.Colors.Gold else Theme.Colors.Border
				end),
				Transparency = if dim and not bought then 0.5 else 0,
			}),
			ArtIcon.Image(s, {
				Key = artKey,
				Corner = Theme.Corner.Medium,
				ImageColor = if bought then nil else Color3.fromRGB(150, 150, 150),
				Transparency = if bought then 0 elseif dim then 0.65 else 0.35,
				ZIndex = 4,
			}),
			s:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = s:Computed(function(use2): string
					return if use2(artShown) then "" else node.glyph
				end),
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = if bought then Theme.Colors.GoldBright else Theme.Colors.TextMuted,
				TextTransparency = if dim then 0.5 else 0,
				ZIndex = 4,
				[Children] = s:New("UIPadding")({
					PaddingTop = UDim.new(0.18, 0),
					PaddingBottom = UDim.new(0.18, 0),
					PaddingLeft = UDim.new(0.18, 0),
					PaddingRight = UDim.new(0.18, 0),
				}),
			}),
			-- a rank can be bought now: a green "+" on the corner
			s:New("TextLabel")({
				Name = "CanBuy",
				Visible = view.canBuy,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = Theme.Colors.Success,
				Text = "+",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 16,
				TextColor3 = Theme.Colors.Text,
				ZIndex = 5,
				[Children] = s:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
		},
	})
	-- PC: the name on hover (the description only after a click).
	if not touch then
		Tooltip.attach(s, tile :: GuiObject, Text.get(use, node.nameKey))
	end
	-- a bought skill node with an active skill can be dragged onto the bar like a base row
	if node.kind == "skill" and node.skill and bought then
		local skill = SkillData.get(node.skill)
		local character = use(ctx.character)
		if skill and skill.type ~= "passive" and character and Paths.skillRank(character, skill.id) > 0 then
			DragDrop.register(s, tile :: GuiObject, `skill:{skill.id}`)
		end
	end

	return s:New("Frame")({
		Name = node.id,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = position,
		Size = UDim2.fromOffset(NodeCard.WIDTH, tileSize + NodeCard.PIPS),
		BackgroundTransparency = 1,
		ZIndex = 3,
		[Children] = {
			tile,
			s:New("TextLabel")({
				Name = "Ranks",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, NodeCard.PIPS),
				BackgroundTransparency = 1,
				RichText = true,
				Text = dots(view),
				FontFace = Theme.Fonts.Body,
				TextSize = 13,
				TextColor3 = if bought then Theme.Colors.GoldBright else Theme.Colors.TextMuted,
				TextTransparency = if dim and not bought then 0.4 else 0,
				ZIndex = 3,
			}),
		},
	})
end

return NodeCard
