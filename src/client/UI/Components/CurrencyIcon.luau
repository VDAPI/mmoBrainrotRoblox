--!strict
-- Currency icon (S35): gold, experience or Dragon Currency from the item atlases (ItemIcons.named "ui/gold",
-- "ui/exp", "ui/dragon") while they are loaded, otherwise the glyph the UI used before.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.Parent.IconState)
local ItemIcons = require(ReplicatedStorage.Shared.Logic.ItemIcons)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

export type Currency = "gold" | "exp" | "dragon"

export type Props = {
	Currency: Currency,
	Size: Fusion.UsedAs<UDim2>?,
	Position: Fusion.UsedAs<UDim2>?,
	AnchorPoint: Fusion.UsedAs<Vector2>?,
	LayoutOrder: Fusion.UsedAs<number>?,
	ZIndex: Fusion.UsedAs<number>?,
}

-- Glyphs and colours shown without the atlases (as before S35).
local GLYPHS: { [string]: { glyph: string, color: Color3 } } = {
	gold = { glyph = "◉", color = Theme.Colors.GoldBright },
	exp = { glyph = "✦", color = Theme.Colors.Exp },
	dragon = { glyph = "◆", color = Color3.fromHex("#E5302A") },
}

local function CurrencyIcon(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local named = ItemIcons.named(`ui/{props.Currency}`)
	local fallback = GLYPHS[props.Currency]
	local art = scope:Computed(function(use): boolean
		return named ~= nil and use(IconState.Art)
	end)
	local layers = {}
	for i, layer in (if named then named.layers else {}) :: { ItemIcons.Layer } do
		table.insert(
			layers,
			scope:New("ImageLabel")({
				Name = `Layer{i}`,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = i,
				Visible = art,
				Image = ItemIcons.sheet(layer.image) or "",
				ImageRectOffset = Vector2.new(layer.x, layer.y),
				ImageRectSize = Vector2.new(ItemIcons.CELL, ItemIcons.CELL),
				ImageColor3 = if layer.tint then Color3.fromHex(layer.tint) else Color3.new(1, 1, 1),
			})
		)
	end
	return scope:New("Frame")({
		Name = `Currency_{props.Currency}`,
		Size = props.Size or UDim2.fromOffset(18, 18),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
		BackgroundTransparency = 1,
		[Children] = {
			layers :: any,
			scope:New("TextLabel")({
				Name = "Glyph",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(art)
				end),
				Text = fallback.glyph,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = fallback.color,
			}),
		} :: any,
	})
end

return CurrencyIcon
