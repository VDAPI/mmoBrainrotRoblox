--!strict
-- A node of a direction tree (FIX 2026-10-14, owner: the trees look like trees and show descriptions only after a
-- click). S139: the same tile as the pool tree (SkillsWindow/Tile, DESIGN-18 §12 D2): the picture (a skill node's
-- skill picture, S119) or the glyph, a brass frame once bought, an ink frame while selected, a red frame when a bought
-- node does not work now, a green "+" while a rank can be bought, and the rank pips under it ("●●○", "33%" for team
-- nodes below TEAM_FULL_POINTS in their direction (S138), "⚠" when the node's weapon does not fit). Faded in a closed
-- row or when the other node of a choice row was taken. A click / tap selects it (the details show its text with Buy /
-- Refund); the PC hover shows the name. A bought active skill node drags onto the bar. Everything comes from a
-- PathView.NodeView.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tile = require(script.Parent.Tile)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

type Scope = Fusion.Scope<typeof(Fusion)>

local NodeCard = {}

NodeCard.TILE = Tile.SIZE
NodeCard.TILE_TOUCH = Tile.SIZE_TOUCH
NodeCard.PIPS = Tile.CAPTION -- the rank line under the tile
NodeCard.WIDTH = 92 -- the node's frame (the pips line may be wider than the tile)

-- S135: parchment roles
local WARN_HEX = Theme.hex(Theme.Paper.Warning)
local DANGER_HEX = Theme.hex(Theme.Paper.Danger)

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
	local bought = view.rank > 0
	-- a bought skill node with an active skill can be dragged onto the bar like a pool tile
	local dragId: string? = nil
	if node.kind == "skill" and node.skill and bought then
		local skill = SkillData.get(node.skill)
		local character = use(ctx.character)
		if skill and skill.type ~= "passive" and character and Paths.skillRank(character, skill.id) > 0 then
			dragId = `skill:{skill.id}`
		end
	end
	return Tile.new(s, {
		Name = node.id,
		Size = if touch then NodeCard.TILE_TOUCH else NodeCard.TILE,
		Width = NodeCard.WIDTH,
		Position = position,
		ArtKey = if node.kind == "skill" and node.skill then UiArt.skill(node.skill) else nil,
		Glyph = node.glyph,
		Lit = bought,
		Dim = view.taken or not rowOpen,
		Broken = bought and not view.active,
		Selected = s:Computed(function(use2): boolean
			local sel = use2(ctx.selected)
			return sel ~= nil and sel.kind == "node" and sel.id == node.id
		end),
		Plus = view.canBuy,
		Caption = dots(view),
		Tooltip = Text.get(use, node.nameKey),
		Touch = touch,
		OnClick = function()
			ctx.selected:set({ kind = "node", id = node.id })
			if touch then
				ctx.previewOpen:set(false)
				ctx.sheet:set(true)
			end
		end,
		DragId = dragId,
	})
end

return NodeCard
