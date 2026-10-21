--!strict
-- S155 (docs/DESIGN.md §20 "Samouczek"): the hint of the hands-on tutorial, an iron HUD tile with a brass edge (S136,
-- never parchment over the world): the step caption in upper case, the step text (keys of the player's own bindings on
-- PC, buttons on a phone), a key plaque on PC, a small brass arrow towards the HUD element of the step and "Skip the
-- tutorial" with a one-click confirmation ("Are you sure?" -> "Skip"). The closing "done" hint has no skip row and goes
-- on a touch. Only its buttons take input: the tile and the outline let clicks through to the game. The controller
-- (TutorialController) places it next to the element (UI/HudAnchors) and sets what it shows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudAnchors = require(script.Parent.Parent.Parent.HudAnchors)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

-- What the tile shows (texts already in the viewer's language).
-- `veteran` (S155b): the account knows the game (Logic/Tutorial.veteran): the skip button says "I know the game, skip".
export type View = { caption: string, text: string, key: string?, finale: boolean, veteran: boolean? }
-- The arrow: a glyph (▼ ▲ ◀ ▶) and its centre in the layer (next to the tile, towards the element).
export type Arrow = { glyph: string, position: UDim2 }

export type Props = {
	View: UsedAs<View?>,
	Visible: UsedAs<boolean>,
	Position: UsedAs<UDim2>, -- top left corner of the tile in the layer
	Width: UsedAs<number>,
	Arrow: UsedAs<Arrow?>,
	Outline: UsedAs<HudAnchors.Rect?>,
	OnSkip: () -> (),
	OnClose: () -> (), -- the closing hint was touched
}

export type Api = { frame: Instance, box: Frame }

local PAD = 14
local CONFIRM_SECONDS = 5 -- the "Are you sure?" state goes back by itself

local function TutorialHint(scope: Scope, props: Props): Api
	local confirming = scope:Value(false)
	local token = 0
	local function view(use: Fusion.Use): View?
		return use(props.View)
	end
	local finale = scope:Computed(function(use): boolean
		local v = view(use)
		return v ~= nil and v.finale
	end)

	local function startConfirm()
		token += 1
		local mine = token
		confirming:set(true)
		task.delay(CONFIRM_SECONDS, function()
			if token == mine then
				confirming:set(false)
			end
		end)
	end

	local box = scope:New("Frame")({
		Name = "TutorialHint",
		Position = props.Position,
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(use(props.Width), 0)
		end),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Active = false,
		ZIndex = 51,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Brass.Line,
				Thickness = Theme.Stroke.Normal,
			}),
			-- the closing hint goes on a touch / click anywhere on the tile
			scope:New("TextButton")({
				Name = "Close",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 53,
				Visible = finale,
				[OnEvent("Activated")] = function()
					props.OnClose()
				end,
			}),
			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Active = false,
				ZIndex = 51,
				[Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, PAD),
						PaddingRight = UDim.new(0, PAD),
						PaddingTop = UDim.new(0, PAD - 4),
						PaddingBottom = UDim.new(0, PAD - 2),
					}),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Padding.Small),
					}),
					-- the caption and, on PC, the key plaque
					scope:New("Frame")({
						Name = "Header",
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundTransparency = 1,
						Active = false,
						ZIndex = 52,
						[Children] = {
							scope:New("TextLabel")({
								Name = "Caption",
								Size = UDim2.new(1, -110, 1, 0),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use): string
									local v = view(use)
									return if v then string.upper(v.caption) else ""
								end),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Caption,
								TextColor3 = Theme.Brass.Bright,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								ZIndex = 52,
							}),
							scope:New("TextLabel")({
								Name = "Key",
								AnchorPoint = Vector2.new(1, 0.5),
								Position = UDim2.fromScale(1, 0.5),
								Size = UDim2.fromOffset(0, 26),
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundColor3 = Theme.Iron.Raised,
								Visible = scope:Computed(function(use): boolean
									local v = view(use)
									return v ~= nil and v.key ~= nil and v.key ~= ""
								end),
								Text = scope:Computed(function(use): string
									local v = view(use)
									return if v and v.key then v.key else ""
								end),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Small,
								TextColor3 = Theme.Iron.Heading,
								ZIndex = 52,
								[Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
										Color = Theme.Brass.Line,
										Thickness = Theme.Stroke.Thin,
									}),
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, Theme.Padding.Small),
										PaddingRight = UDim.new(0, Theme.Padding.Small),
									}),
								},
							}),
						},
					}),
					scope:New("TextLabel")({
						Name = "Body",
						LayoutOrder = 2,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local v = view(use)
							return if v then v.text else ""
						end),
						TextWrapped = true,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Iron.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						ZIndex = 52,
					}),
					-- skip with a one-click confirmation (not on the closing hint)
					scope:New("Frame")({
						Name = "Skip",
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
						BackgroundTransparency = 1,
						Active = false,
						ZIndex = 52,
						Visible = scope:Computed(function(use): boolean
							return not use(finale)
						end),
						[Children] = {
							Button(scope, {
								Name = "SkipTutorial",
								Size = UDim2.fromOffset(220, Theme.Size.MinTouch),
								Variant = "secondary",
								Surface = "iron",
								TextSize = Theme.TextSize.Small,
								Text = scope:Computed(function(use): string
									local v = view(use)
									return Text.get(
										use,
										if v ~= nil and v.veteran then "tutorial.skipVeteran" else "tutorial.skip"
									)
								end),
								Visible = scope:Computed(function(use): boolean
									return not use(confirming)
								end),
								OnClick = startConfirm,
							}),
							scope:New("TextLabel")({
								Name = "Sure",
								Size = UDim2.new(1, -150, 1, 0),
								BackgroundTransparency = 1,
								Visible = confirming,
								Text = Text.T(scope, "tutorial.skipConfirm"),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = Theme.Iron.Heading,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 52,
							}),
							Button(scope, {
								Name = "SkipYes",
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.fromScale(1, 0),
								Size = UDim2.fromOffset(140, Theme.Size.MinTouch),
								Variant = "danger",
								Surface = "iron",
								TextSize = Theme.TextSize.Small,
								Text = Text.T(scope, "tutorial.skipYes"),
								Visible = confirming,
								OnClick = function()
									token += 1
									confirming:set(false)
									props.OnSkip()
								end,
							}),
						},
					}),
				},
			}),
		},
	})

	local arrow = scope:New("TextLabel")({
		Name = "TutorialArrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = scope:Computed(function(use): UDim2
			local a = use(props.Arrow)
			return if a then a.position else UDim2.new()
		end),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Active = false,
		Visible = scope:Computed(function(use): boolean
			return use(props.Arrow) ~= nil
		end),
		Text = scope:Computed(function(use): string
			local a = use(props.Arrow)
			return if a then a.glyph else ""
		end),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Large,
		TextColor3 = Theme.Brass.Bright,
		ZIndex = 52,
	})

	local frame = scope:New("Frame")({
		Name = "Tutorial",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 50,
		Visible = props.Visible,
		[Children] = {
			HudAnchors.outline(scope, props.Outline),
			box,
			arrow,
		},
	})
	return { frame = frame, box = box :: Frame }
end

return TutorialHint
