--!strict
-- A path node card (S59, ROZWOJ 4), shared by PC and phone: the glyph tile (gold frame once bought), the name, rank
-- dots, "+" / "−" (off with the reason in the tooltip), the strength mark "33%" for team nodes outside the main
-- path, "⚠" when the node's weapon does not fit and a red frame when a bought node does not work now. Greyed in a
-- closed row or when the other node of a choice row was taken. Everything comes from a PathView.NodeView.
-- PC: a card in a horizontal row (84 px high); phone: a full-width card with 44 x 44 buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Parent.Components.Button)
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

NodeCard.HEIGHT = 84
NodeCard.HEIGHT_TOUCH = 68

local WARN_HEX = "#E0A23B"
local DANGER_HEX = "#CC5248"

-- "●●○  33%  ⚠" (RichText).
local function dots(view: PathView.NodeView): string
	local text = string.rep("●", view.rank) .. string.rep("○", math.max(0, view.node.maxRank - view.rank))
	if view.scale < 1 then
		text ..= `  <font color="{WARN_HEX}">{math.floor(view.scale * 100 + 0.5)}%</font>`
	end
	if not view.weaponOk then
		text ..= `  <font color="{DANGER_HEX}">⚠</font>`
	end
	return text
end

function NodeCard.new(
	s: Scope,
	use: Fusion.Use,
	ctx: Context.Ctx,
	actions: Actions.Actions,
	view: PathView.NodeView,
	rowOpen: boolean,
	touch: boolean,
	size: UDim2
): Instance
	local node = view.node
	local dim = view.taken or not rowOpen
	local bought = view.rank > 0
	local broken = bought and not view.active
	local buttonSize = if touch then Theme.Size.MinTouch else 28
	local tileSize = if touch then 44 else 36

	local function step(text: string, ok: boolean, reason: string?, x: number, run: () -> ()): Instance
		local button = Button(s, {
			AnchorPoint = Vector2.new(1, if touch then 0.5 else 1),
			Position = if touch then UDim2.new(1, x, 0.5, 0) else UDim2.new(1, x, 1, -6),
			Size = UDim2.fromOffset(buttonSize, buttonSize),
			Variant = "secondary",
			TextSize = Theme.TextSize.Small,
			Text = text,
			Disabled = not ok,
			OnClick = run,
		})
		if not ok and reason then
			Tooltip.attach(s, button :: GuiObject, Text.get(use, reason))
		end
		return button
	end

	-- S119: a skill node shows its skill's picture once loaded (other nodes have no pictures: glyph).
	local artKey = if node.kind == "skill" and node.skill then UiArt.skill(node.skill) else nil
	local artShown = ArtIcon.Shown(s, artKey)
	local tile = s:New("Frame")({
		Name = "Tile",
		Position = if touch
			then UDim2.fromOffset(8, (NodeCard.HEIGHT_TOUCH - tileSize) / 2)
			else UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(tileSize, tileSize),
		BackgroundColor3 = if bought then Theme.Colors.PanelRaised else Theme.Colors.Background,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 2,
				Color = if bought then Theme.Colors.Gold else Theme.Colors.Border,
			}),
			ArtIcon.Image(s, {
				Key = artKey,
				Corner = Theme.Corner.Small,
				ImageColor = if bought then nil else Color3.fromRGB(150, 150, 150),
				Transparency = if bought then 0 else 0.35,
			}),
			s:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = s:Computed(function(use): string
					return if use(artShown) then "" else node.glyph
				end),
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = if bought then Theme.Colors.GoldBright else Theme.Colors.TextMuted,
				[Children] = s:New("UIPadding")({
					PaddingTop = UDim.new(0.18, 0),
					PaddingBottom = UDim.new(0.18, 0),
					PaddingLeft = UDim.new(0.18, 0),
					PaddingRight = UDim.new(0.18, 0),
				}),
			}),
		},
	})
	-- a bought skill node with an active skill can be dragged onto the bar like a base row
	if node.kind == "skill" and node.skill and bought then
		local skill = SkillData.get(node.skill)
		local character = use(ctx.character)
		if skill and skill.type ~= "passive" and character and Paths.skillRank(character, skill.id) > 0 then
			DragDrop.register(s, tile :: GuiObject, `skill:{skill.id}`)
		end
	end

	local textLeft = 8 + tileSize + 8
	local buttonsWidth = 2 * buttonSize + 12
	local card = s:New("TextButton")({
		Name = node.id,
		Size = size,
		AutoButtonColor = false,
		BackgroundColor3 = s:Computed(function(use2): Color3
			local sel = use2(ctx.selected)
			return if sel and sel.id == node.id then Theme.Colors.PanelHover else Theme.Colors.PanelRaised
		end),
		BackgroundTransparency = if dim then 0.75 else (if bought then 0.15 else 0.5),
		Text = "",
		[OnEvent("Activated")] = function()
			ctx.selected:set({ kind = "node", id = node.id })
			if touch then
				ctx.previewOpen:set(false)
				ctx.sheet:set(true)
			end
		end,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = if broken then 2 else 1,
				Color = if broken then Theme.Colors.Danger else Theme.Colors.Border,
				Transparency = if broken then 0 else 0.4,
			}),
			tile,
			s:New("TextLabel")({
				Name = "Name",
				Position = UDim2.fromOffset(textLeft, if touch then 8 else 6),
				Size = if touch
					then UDim2.new(1, -(textLeft + buttonsWidth + 8), 0, 26)
					else UDim2.new(1, -(textLeft + 6), 0, 38),
				BackgroundTransparency = 1,
				Text = Text.get(use, node.nameKey),
				TextWrapped = not touch,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 14,
				TextColor3 = if dim then Theme.Colors.TextMuted else Theme.Colors.Parchment,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			s:New("TextLabel")({
				Name = "Ranks",
				Position = if touch then UDim2.fromOffset(textLeft, 36) else UDim2.new(0, 8, 1, -30),
				Size = if touch
					then UDim2.new(1, -(textLeft + buttonsWidth + 8), 0, 22)
					else UDim2.new(1, -(buttonsWidth + 16), 0, 22),
				BackgroundTransparency = 1,
				RichText = true,
				Text = dots(view),
				FontFace = Theme.Fonts.Body,
				TextSize = 14,
				TextColor3 = if bought then Theme.Colors.GoldBright else Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			step("−", view.canRefund, view.refundReason, -(buttonSize + 12), function()
				actions.refund(node.id)
			end),
			step("+", view.canBuy, view.buyReason, -6, function()
				actions.buy(node.id)
			end),
		},
	})
	if broken then
		Tooltip.attach(s, card :: GuiObject, Text.get(use, "paths.node.inactive"))
	end
	return card
end

return NodeCard
