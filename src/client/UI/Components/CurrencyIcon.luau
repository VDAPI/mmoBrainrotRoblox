--!strict
-- Currency icon (S35): gold, experience or Dragon Currency from the item atlases (ItemIcons.named "ui/gold",
-- "ui/exp", "ui/dragon") while they are loaded, otherwise the glyph the UI used before. S52: a picture of the key
-- (art/icons/src/ui) once its sheet is loaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.Parent.IconState)
local ItemIcons = require(ReplicatedStorage.Shared.Logic.ItemIcons)
local Theme = require(script.Parent.Parent.Theme)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)

local Children = Fusion.Children

-- S128: "token" = Arena Tokens (no atlas picture yet: the glyph); S134k: "huntmarks" = Hunter's Marks (the same)
export type Currency = "gold" | "exp" | "dragon" | "token" | "huntmarks"

export type Props = {
	Currency: Currency,
	Size: Fusion.UsedAs<UDim2>?,
	Position: Fusion.UsedAs<UDim2>?,
	AnchorPoint: Fusion.UsedAs<Vector2>?,
	LayoutOrder: Fusion.UsedAs<number>?,
	ZIndex: Fusion.UsedAs<number>?,
	Surface: Theme.SurfaceName?, -- S135: the background of the fallback glyph (default "paper")
}

-- Glyphs shown without the atlases (as before S35); S135: colours from UiPalette.currency, readable (3:1, an icon)
-- on the surface.
local GLYPHS: { [string]: string } = {
	gold = "◉",
	exp = "✦",
	dragon = "◆",
	token = "⚔",
	huntmarks = "➶",
}

local MAX_LAYERS = 3

local function CurrencyIcon(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local key = `ui/{props.Currency}`
	local glyph = GLYPHS[props.Currency]
	local glyphColor = Theme.readable((UiPalette.currency :: any)[props.Currency], props.Surface, 3)
	local named = scope:Computed(function(use): ItemIcons.Resolved?
		if not use(IconState.Art) then
			return nil
		end
		return ItemIcons.named(key, IconState.readyIn(use))
	end)
	local layers = {}
	for i = 1, MAX_LAYERS do
		local layer = scope:Computed(function(use): ItemIcons.Layer?
			local r = use(named)
			return if r then r.layers[i] else nil
		end)
		table.insert(
			layers,
			scope:New("ImageLabel")({
				Name = `Layer{i}`,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = i,
				Visible = scope:Computed(function(use): boolean
					return use(layer) ~= nil
				end),
				Image = scope:Computed(function(use): string
					local l = use(layer)
					return if l then ItemIcons.sheet(l.image) or "" else ""
				end),
				ImageRectOffset = scope:Computed(function(use): Vector2
					local l = use(layer)
					return if l then Vector2.new(l.x, l.y) else Vector2.zero
				end),
				ImageRectSize = Vector2.new(ItemIcons.CELL, ItemIcons.CELL),
				ImageColor3 = scope:Computed(function(use): Color3
					local l = use(layer)
					return if l and l.tint then Theme.tint(l.tint) else Theme.Plain
				end),
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
					return use(named) == nil
				end),
				Text = glyph,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = glyphColor,
			}),
		} :: any,
	})
end

return CurrencyIcon
