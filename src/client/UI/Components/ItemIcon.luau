--!strict
-- Item icon (S35, DESIGN §5, §23): up to 3 stacked atlas layers from Logic/ItemIcons (tier-tinted metal, fixed
-- colours, accent: element / potion / ore colour) while the atlases are loaded (UI/IconState.Art); otherwise the
-- old glyph on its coloured tile. Rarity is never drawn here (the slot frame shows it). Layers are three fixed
-- ImageLabels changed by Computed values, so a slot never rebuilds instances when its item changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Elements = require(ReplicatedStorage.Shared.Data.Elements)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.Parent.IconState)
local ItemIcons = require(ReplicatedStorage.Shared.Logic.ItemIcons)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type UsedAs<T> = Fusion.UsedAs<T>
type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Def: UsedAs<Items.ItemDef?>,
	Element: UsedAs<string?>?, -- mage weapon element (ItemRoll.elementOf)
	Fallback: UsedAs<string?>?, -- glyph when there is no item (empty equipment slot)
	Size: UsedAs<UDim2>?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	Transparency: UsedAs<number>?, -- extra fade (0 = solid), e.g. while dragged
	Name: string?,
	ZIndex: UsedAs<number>?,
	LayoutOrder: UsedAs<number>?,
	Visible: UsedAs<boolean>?,
}

local MAX_LAYERS = 3

local function ItemIcon(scope: Scope, props: Props): Instance
	local resolved = scope:Computed(function(use): ItemIcons.Resolved?
		if not use(IconState.Art) then
			return nil
		end
		local def = use(props.Def)
		if not def then
			return nil
		end
		local element = if props.Element ~= nil then use(props.Element) else nil
		return ItemIcons.resolve(def, element)
	end)
	local fade = scope:Computed(function(use): number
		return if props.Transparency ~= nil then use(props.Transparency) else 0
	end)
	local tileColor = scope:Computed(function(use): Color3
		local def = use(props.Def)
		local element = if props.Element ~= nil then use(props.Element) else nil
		if element and Elements.COLORS[element] then
			return Color3.fromHex(Elements.COLORS[element])
		end
		return if def then Color3.fromHex(def.icon.color) else Theme.Colors.Background
	end)
	local hasThing = scope:Computed(function(use): boolean
		return use(props.Def) ~= nil
	end)

	local layers = {}
	for i = 1, MAX_LAYERS do
		local layer = scope:Computed(function(use): ItemIcons.Layer?
			local r = use(resolved)
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
					return if l and l.tint then Color3.fromHex(l.tint) else Color3.new(1, 1, 1)
				end),
				ImageTransparency = fade,
			})
		)
	end

	return scope:New("Frame")({
		Name = props.Name or "Icon",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromScale(0.78, 0.78),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
		Visible = props.Visible,
		-- The glyph tile only while glyphs are shown; pictures sit on the dark slot background.
		BackgroundColor3 = tileColor,
		BackgroundTransparency = scope:Computed(function(use): number
			if use(resolved) or not use(hasThing) then
				return 1
			end
			return 0.55 + (1 - 0.55) * use(fade)
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIGradient")({ Rotation = 90, Transparency = NumberSequence.new(0, 0.5) }),
			layers :: any,
			scope:New("TextLabel")({
				Name = "Glyph",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = MAX_LAYERS + 1,
				Visible = scope:Computed(function(use): boolean
					return use(resolved) == nil
				end),
				Text = scope:Computed(function(use): string
					local def = use(props.Def)
					if def then
						return def.icon.glyph
					end
					return if props.Fallback ~= nil then use(props.Fallback) or "" else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextScaled = true,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(hasThing) then Theme.Colors.Text else Theme.Colors.Border
				end),
				TextTransparency = scope:Computed(function(use): number
					return math.min(1, use(fade) * 0.85)
				end),
				[Children] = scope:New("UIPadding")({
					PaddingTop = UDim.new(0.12, 0),
					PaddingBottom = UDim.new(0.12, 0),
					PaddingLeft = UDim.new(0.12, 0),
					PaddingRight = UDim.new(0.12, 0),
				}),
			}),
		} :: any,
	})
end

return ItemIcon
