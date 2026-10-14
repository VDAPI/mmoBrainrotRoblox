--!strict
-- Interface picture with today's glyph as the fallback (S119). One ImageLabel (atlas cell or a single picture) and
-- one TextLabel with the glyph inside a transparent frame: the picture shows while its file is uploaded and loaded
-- (UiArtState), the glyph otherwise, looking exactly as before (the old label's properties go through `Label`).
-- Silhouette atlases (hud, map) take the glyph colour (or `Tint`). Keys only from Logic/UiArt.
--   ArtIcon(scope, props)        frame with picture + glyph
--   ArtIcon.Image(scope, props)  only the picture (an ImageLabel child for an existing glyph label or button)
--   ArtIcon.Shown(scope, key)    Computed: the picture of `key` is drawn now (hide a glyph next to ArtIcon.Image)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UiArtState = require(script.Parent.Parent.UiArtState)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

export type ImageProps = {
	Key: UsedAs<string?>,
	Tint: UsedAs<Color3?>?, -- silhouettes: their colour (white otherwise)
	ImageColor: UsedAs<Color3?>?, -- overrides the colour for every style (greyed out)
	Transparency: UsedAs<number>?,
	Size: UsedAs<UDim2>?, -- default: the whole parent
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	ZIndex: UsedAs<number>?,
	Rotation: UsedAs<number>?,
	Corner: UDim?, -- rounded picture (UICorner)
	ScaleType: Enum.ScaleType?,
	Name: string?,
	LayoutOrder: UsedAs<number>?,
	Visible: UsedAs<boolean>?, -- shown only while this is true too
}

export type Props = {
	Key: UsedAs<string?>,
	Glyph: UsedAs<string>,
	GlyphColor: UsedAs<Color3>?,
	GlyphStroke: UsedAs<number>?, -- TextStrokeTransparency of the glyph (default 1)
	Tint: UsedAs<Color3?>?, -- silhouettes: default GlyphColor
	ImageColor: UsedAs<Color3?>?,
	ImageScale: number?, -- picture side relative to the frame (default 1)
	Transparency: UsedAs<number>?, -- glyph and picture
	Size: UsedAs<UDim2>?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	ZIndex: UsedAs<number>?,
	LayoutOrder: UsedAs<number>?,
	Visible: UsedAs<boolean>?,
	Rotation: UsedAs<number>?,
	Corner: UDim?,
	ScaleType: Enum.ScaleType?,
	Name: string?,
	-- Further properties of the glyph TextLabel, exactly as the old label had them (FontFace, TextSize, TextScaled,
	-- TextStrokeColor3, alignment ...). Text, TextColor3, TextTransparency and TextStrokeTransparency come from above.
	Label: { [any]: any }?,
	LabelChildren: any?, -- children of the glyph label (UIPadding ...)
	Children: any?, -- more children of the frame (badges over the picture)
}

local function colorOf(
	use: Fusion.Use,
	look: UiArtState.Look?,
	override: UsedAs<Color3?>?,
	tint: UsedAs<Color3?>?
): Color3
	local o = use(override)
	if o then
		return o
	end
	if look and look.tint then
		return use(tint) or Color3.new(1, 1, 1)
	end
	return Color3.new(1, 1, 1)
end

local function image(scope: Scope, props: ImageProps, look: Fusion.Computed<UiArtState.Look?>): ImageLabel
	return scope:New("ImageLabel")({
		Name = props.Name or "Art",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex,
		Rotation = props.Rotation,
		ScaleType = props.ScaleType or Enum.ScaleType.Fit,
		LayoutOrder = props.LayoutOrder,
		Visible = scope:Computed(function(use): boolean
			return use(look) ~= nil and (props.Visible == nil or use(props.Visible) == true)
		end),
		Image = scope:Computed(function(use): string
			local l = use(look)
			return if l then l.image else ""
		end),
		ImageRectOffset = scope:Computed(function(use): Vector2
			local l = use(look)
			return if l then l.offset else Vector2.zero
		end),
		ImageRectSize = scope:Computed(function(use): Vector2
			local l = use(look)
			return if l then l.size else Vector2.zero
		end),
		ImageColor3 = scope:Computed(function(use): Color3
			return colorOf(use, use(look), props.ImageColor, props.Tint)
		end),
		ImageTransparency = props.Transparency or 0,
		[Children] = if props.Corner then scope:New("UICorner")({ CornerRadius = props.Corner }) else nil,
	}) :: ImageLabel
end

local function lookOf(scope: Scope, key: UsedAs<string?>): Fusion.Computed<UiArtState.Look?>
	return scope:Computed(function(use): UiArtState.Look?
		return UiArtState.look(use, use(key))
	end)
end

local ArtIcon = {}

function ArtIcon.Image(scope: Scope, props: ImageProps): ImageLabel
	return image(scope, props, lookOf(scope, props.Key))
end

function ArtIcon.Shown(scope: Scope, key: UsedAs<string?>): Fusion.Computed<boolean>
	return scope:Computed(function(use): boolean
		return UiArtState.ready(use, use(key))
	end)
end

local function new(_: any, scope: Scope, props: Props): Frame
	local look = lookOf(scope, props.Key)
	local scale = props.ImageScale or 1
	local label: { [any]: any } = if props.Label then table.clone(props.Label) else {}
	label.Name = "Glyph"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = props.ZIndex
	label.Text = props.Glyph
	label.TextColor3 = props.GlyphColor
	label.TextTransparency = scope:Computed(function(use): number
		return if use(look) then 1 else (use(props.Transparency) or 0)
	end)
	label.TextStrokeTransparency = scope:Computed(function(use): number
		return if use(look) then 1 else (use(props.GlyphStroke) or 1)
	end)
	label[Children] = props.LabelChildren
	return scope:New("Frame")({
		Name = props.Name or "ArtIcon",
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		Visible = if props.Visible ~= nil then props.Visible else true,
		Rotation = props.Rotation,
		[Children] = {
			image(scope, {
				Key = props.Key,
				Tint = props.Tint or props.GlyphColor :: any,
				ImageColor = props.ImageColor,
				Transparency = props.Transparency,
				Size = UDim2.fromScale(scale, scale),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = props.ZIndex,
				Corner = props.Corner,
				ScaleType = props.ScaleType,
			}, look) :: any,
			scope:New("TextLabel")(label) :: any,
			props.Children,
		} :: any,
	}) :: Frame
end

return setmetatable(ArtIcon, { __call = new })
