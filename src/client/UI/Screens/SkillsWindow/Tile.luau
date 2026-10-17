--!strict
-- One tile of the skills window's trees (S139, DESIGN-18 §12): the pool tree's skills and the directions' nodes use
-- the same picture, size and states (FIX 2026-10-14: pictures on the tree, text only after a click). The tile: the
-- skill picture (S119) or the glyph, raised with a brass frame once it has ranks, sunken and faded before, an ink frame
-- while selected, a red frame when bought but not working; corner marks: a green "+" (a rank to buy, top left), a
-- breakpoint mark (gold "!" to choose, "A" / "B" chosen, top right), the bar slot (bottom right); a padlock with the
-- level over a locked tile; a caption line under it (ranks, RichText). A click / tap selects; the PC hover shows a
-- tooltip (name and short sentence); `DragId` makes it draggable onto the bar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local DragDrop = require(script.Parent.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local Tile = {}

Tile.SIZE = 48 -- PC
Tile.SIZE_TOUCH = 52 -- phone (>= Theme.Size.MinTouch)
Tile.CAPTION = 18 -- the line under the tile
Tile.MARK = 20 -- corner marks

export type Mark = { text: string, color: Color3, textColor: Color3 }

export type Props = {
	Name: string,
	Size: number, -- the tile's side
	Width: number, -- the frame (the caption may be wider than the tile)
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ArtKey: string?, -- UiArt key of the picture (nil: glyph only)
	Glyph: string,
	Round: boolean?, -- passives
	Lit: boolean, -- has ranks (bought or reserved)
	Dim: boolean?, -- a closed row, a taken choice
	Broken: boolean?, -- bought but not working now
	Accent: Color3?, -- the glyph colour when lit (default Heading)
	Selected: Fusion.UsedAs<boolean>,
	Plus: boolean?, -- a rank can be bought now
	Mark: Mark?, -- breakpoint mark, top right
	Slot: string?, -- the bar slot, bottom right
	Lock: string?, -- padlock text over the tile ("🔒 15")
	Caption: string, -- RichText
	CaptionColor: Color3?,
	Tooltip: string?, -- PC hover
	Touch: boolean,
	OnClick: () -> (),
	DragId: string?, -- DragDrop slot id ("skill:<id>")
}

local function corner(s: Scope, name: string, anchor: Vector2, position: UDim2, mark: Mark, z: number): Instance
	return s:New("TextLabel")({
		Name = name,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(Tile.MARK, Tile.MARK),
		BackgroundColor3 = mark.color,
		Text = mark.text,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Caption,
		TextColor3 = mark.textColor,
		ZIndex = z,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			s:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Paper.Border,
			}),
		},
	})
end

function Tile.new(s: Scope, props: Props): Instance
	local size = props.Size
	local lit = props.Lit
	local dim = props.Dim == true
	local broken = props.Broken == true
	local cornerRadius = if props.Round then Theme.Corner.Round else Theme.Corner.Medium
	local artShown = ArtIcon.Shown(s, props.ArtKey)
	local accent = props.Accent or Theme.Paper.Heading
	local selected = props.Selected

	local overlays: { Instance } = {}
	if props.Plus then
		table.insert(
			overlays,
			corner(s, "CanBuy", Vector2.new(0.5, 0.5), UDim2.fromScale(0, 0), {
				text = "+",
				color = Theme.Paper.Accent,
				textColor = Theme.Paper.AccentText,
			}, 6)
		)
	end
	if props.Mark then
		table.insert(overlays, corner(s, "Breakpoint", Vector2.new(0.5, 0.5), UDim2.fromScale(1, 0), props.Mark, 6))
	end
	if props.Slot then
		table.insert(
			overlays,
			corner(s, "Slot", Vector2.new(0.5, 0.5), UDim2.fromScale(1, 1), {
				text = props.Slot,
				color = Theme.Paper.Surface,
				textColor = Theme.Paper.Text,
			}, 6)
		)
	end
	if props.Lock then
		table.insert(
			overlays,
			s:New("TextLabel")({
				Name = "Lock",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -2),
				Size = UDim2.new(1, -4, 0, Tile.MARK),
				BackgroundColor3 = Theme.Paper.Surface,
				BackgroundTransparency = 0.15,
				Text = props.Lock,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = Theme.Paper.TextMuted,
				ZIndex = 6,
				[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			})
		)
	end

	local button = s:New("TextButton")({
		Name = "Tile",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(size, size),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = s:Computed(function(use): Color3
			if use(selected) then
				return Theme.Paper.Hover
			end
			return if lit then Theme.Paper.Raised else Theme.Paper.Sunken
		end),
		BackgroundTransparency = if dim then 0.45 else 0,
		ZIndex = 3,
		[OnEvent("Activated")] = props.OnClick,
		[Children] = {
			s:New("UICorner")({ CornerRadius = cornerRadius }),
			s:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = s:Computed(function(use): number
					return if use(selected) or broken then Theme.Stroke.Thick else Theme.Stroke.Normal
				end),
				Color = s:Computed(function(use): Color3
					if use(selected) then
						return Theme.Paper.Heading
					elseif broken then
						return Theme.Paper.Danger
					end
					return if lit then Theme.Brass.Frame else Theme.Paper.Border
				end),
				Transparency = if dim and not lit then 0.5 else 0,
			}),
			ArtIcon.Image(s, {
				Key = props.ArtKey,
				Corner = cornerRadius,
				ImageColor = if lit then nil else Theme.mix(Theme.Plain, Theme.Shade, 0.4),
				Transparency = if lit then 0 elseif dim then 0.65 else 0.35,
				ZIndex = 4,
			}),
			s:New("TextLabel")({
				Name = "Glyph",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = s:Computed(function(use): string
					return if use(artShown) then "" else props.Glyph
				end),
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = if lit then accent else Theme.Paper.TextMuted,
				TextTransparency = if dim then 0.5 else 0,
				ZIndex = 4,
				[Children] = s:New("UIPadding")({
					PaddingTop = UDim.new(0.2, 0),
					PaddingBottom = UDim.new(0.2, 0),
					PaddingLeft = UDim.new(0.2, 0),
					PaddingRight = UDim.new(0.2, 0),
				}),
			}),
			overlays :: any,
		},
	})
	if props.Tooltip and not props.Touch then
		Tooltip.attach(s, button :: GuiObject, props.Tooltip)
	end
	if props.DragId then
		DragDrop.register(s, button :: GuiObject, props.DragId)
	end

	return s:New("Frame")({
		Name = props.Name,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(props.Width, size + Tile.CAPTION),
		BackgroundTransparency = 1,
		ZIndex = 3,
		[Children] = {
			button,
			s:New("TextLabel")({
				Name = "Caption",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, Tile.CAPTION),
				BackgroundTransparency = 1,
				RichText = true,
				Text = props.Caption,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = props.CaptionColor or (if lit then Theme.Paper.Heading else Theme.Paper.TextMuted),
				TextTransparency = if dim and not lit then 0.4 else 0,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 3,
			}),
		},
	})
end

return Tile
