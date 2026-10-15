--!strict
-- Round portrait tile with the portrait frame cosmetic (S123, DESIGN-17 §4): the HUD portrait, the character window
-- header, another player's profile and the wardrobe preview. Without a frame the tile has today's stroke in the class
-- colour (Theme.Stroke.Thick); with one the stroke takes the frame's colour with a gradient to stroke2, its thickness
-- scaled from the 84 px HUD portrait, a soft second stroke for `glow` and the ornament glyph in the four corners
-- (inside 10 % of the tile, so a phone's small tile keeps it). `Content` (the class emblem) sits inside.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRules = require(ReplicatedStorage.Shared.Logic.CosmeticRules)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Size: number, -- side in px
	FrameId: UsedAs<string?>, -- the equipped frame cosmetic (nil = the class stroke)
	ClassColor: UsedAs<Color3>,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	LayoutOrder: number?,
	Name: string?,
	Background: Color3?,
	Visible: UsedAs<boolean>?,
	Content: any, -- what sits inside (the class emblem)
}

local BASE = 84 -- the HUD portrait the thickness is given for
local CORNERS = { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }

local function PortraitFrame(scope: Scope, props: Props): Instance
	local size = props.Size
	local frame = scope:Computed(function(use)
		return CosmeticRules.frameOf(use(props.FrameId))
	end)
	local ornaments: { Instance } = {}
	local glyphSize = math.clamp(math.floor(size * 0.2), 12, 18)
	for i, corner in CORNERS do
		-- the glyph's centre on the round tile's bounding square, pulled in by a tenth of the tile
		local inset = 0.1
		local x = if corner.X == 0 then inset else 1 - inset
		local y = if corner.Y == 0 then inset else 1 - inset
		table.insert(
			ornaments,
			scope:New("TextLabel")({
				Name = `Ornament{i}`,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, y),
				Size = UDim2.fromOffset(glyphSize, glyphSize),
				BackgroundTransparency = 1,
				ZIndex = 3,
				Visible = scope:Computed(function(use): boolean
					local f = use(frame)
					return f ~= nil and f.ornament ~= nil
				end),
				Text = scope:Computed(function(use): string
					local f = use(frame)
					return if f and f.ornament then f.ornament else ""
				end),
				TextColor3 = scope:Computed(function(use): Color3
					local f = use(frame)
					return if f then Color3.fromHex(f.stroke2 or f.stroke) else Theme.Colors.Gold
				end),
				TextStrokeTransparency = 0.3,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
			})
		)
	end
	local function thickness(use: Fusion.Use): number
		local f = use(frame)
		if not f then
			return Theme.Stroke.Thick
		end
		return math.max(1, f.thickness * size / BASE)
	end
	return scope:New("Frame")({
		Name = props.Name or "PortraitFrame",
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = props.Background or Theme.Colors.Background,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			scope:New("UIStroke")({
				Thickness = scope:Computed(thickness),
				Color = scope:Computed(function(use): Color3
					local f = use(frame)
					return if f then Color3.new(1, 1, 1) else use(props.ClassColor)
				end),
				[Children] = {
					scope:New("UIGradient")({
						Rotation = 45,
						Enabled = scope:Computed(function(use): boolean
							return use(frame) ~= nil
						end),
						Color = scope:Computed(function(use): ColorSequence
							local f = use(frame)
							if not f then
								return ColorSequence.new(Color3.new(1, 1, 1))
							end
							return ColorSequence.new(Color3.fromHex(f.stroke), Color3.fromHex(f.stroke2 or f.stroke))
						end),
					}),
				},
			}),
			-- the glow: a wider, see-through ring around the tile
			scope:New("Frame")({
				Name = "Glow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 0,
				Visible = scope:Computed(function(use): boolean
					local f = use(frame)
					return f ~= nil and f.glow == true
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					scope:New("UIStroke")({
						Transparency = 0.6,
						Thickness = scope:Computed(function(use): number
							return thickness(use) * 2.4
						end),
						Color = scope:Computed(function(use): Color3
							local f = use(frame)
							return if f then Color3.fromHex(f.stroke2 or f.stroke) else Theme.Colors.Gold
						end),
					}),
				},
			}),
			ornaments :: any,
			props.Content,
		} :: any,
	})
end

return PortraitFrame
