--!strict
-- Game window: framed panel with a title bar and close button. Draggable by the title bar on PC,
-- full screen on touch devices. Opened and stacked by WindowManager; content goes in [Children].
-- S135/S136 (Data/UiWindows `surface`): parchment body (iron for the admin overlay), iron frame with an inner brass
-- line, dark iron title bar with a Merriweather title and a brass rule.
-- Owner 2026-11-10 ("too much text, things covering each other, nothing folds"), UI package C: the frame follows
-- Logic/WindowFrame, which tests/uiframe.spec proves on every screen. On a touch screen the window starts under
-- Roblox's top bar (UI/Scale.TopBar; its title bar used to stand under the bar's buttons); a phone
-- (UI/PhoneLayout.Compact) gets the 44-px title bar, the tighter padding, a 20-px title and a 52 x 44 ✕. The title
-- keeps to one line, '…' at its end. A dragged PC window keeps its title bar top bar + 8 down and 80 px of it on the
-- screen (WindowFrame.clampDrag; it could reach the screen's top edge, under the bar).
-- Optional parts, for the windows that adopt them (UI packages D and E; a window without them looks as before):
--   Footer        actions pinned under the content, outside its scroll (ButtonHeight 52 buttons, right-aligned)
--   Scroll        the content in one vertical ScrollingFrame
--   HeaderAction  a button in the title bar, left of the ✕ (WindowManager's phone switch to and from the backpack)
-- A window's build function (WindowManager.WindowDef.build) may return them with its content as Window.Parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Motion = require(script.Parent.Parent.Motion)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local Scale = require(script.Parent.Parent.Scale)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(ReplicatedStorage.Shared.Logic.WindowFrame)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type UsedAs<T> = Fusion.UsedAs<T>
type Scope = Fusion.Scope<typeof(Fusion)>

-- A button in the title bar, left of the ✕: one line of text, hidden while `Visible` is false.
export type HeaderAction = {
	Text: UsedAs<string>,
	OnClick: () -> (),
	Visible: UsedAs<boolean>?,
	Name: string?,
}

-- What a window's build function may return instead of its bare content: the content plus the optional parts, which
-- WindowManager passes on to the Window as props.
export type Parts = {
	Content: Fusion.Child,
	Footer: Fusion.Child?,
	Scroll: boolean?,
	HeaderAction: HeaderAction?,
}

export type Props = {
	Title: UsedAs<string>,
	Size: Vector2, -- desktop size in virtual pixels
	Offset: Vector2?, -- initial offset from the screen centre (desktop), e.g. side-by-side windows
	-- UI package C: the offset as a value its opener may set later (WindowManager moves a service aside when the
	-- backpack opens next to it); wins over Offset, and dragging the window writes to it
	Place: Fusion.Value<Vector2>?,
	OnClose: () -> (),
	OnFocus: (() -> ())?,
	ZIndex: UsedAs<number>?,
	Name: string?,
	Surface: Theme.SurfaceName?, -- S136: "paper" (default) or "iron" (the admin overlay); Data/UiWindows
	Closing: Fusion.Value<boolean>?, -- W28: true plays the closing motion (WindowManager removes the window after it)
	-- UI package C (optional, see the header):
	Footer: Fusion.Child?,
	Scroll: boolean?,
	HeaderAction: HeaderAction?,
	[typeof(Children)]: Fusion.Child?,
}

-- The frame, title bar and close button are the same on both surfaces; the body is parchment or iron.
local FRAME = {
	frame = Theme.Brass.Frame,
	header = Theme.Iron.Raised,
	rule = Theme.Brass.Line,
	title = Theme.Iron.Text,
	close = Theme.Iron.Text,
	closeHover = Theme.Iron.Danger,
	closeHoverText = Theme.Iron.DangerText,
}

-- A title bar button (Button's iron "secondary" look), as wide as its one line of text.
local function headerButton(scope: Scope, action: HeaderAction, compact: Fusion.StateObject<boolean>): Instance
	local hovered = scope:Value(false)
	local pressed = scope:Value(false)
	return scope:New("TextButton")({
		Name = action.Name or "HeaderAction",
		LayoutOrder = 2,
		Visible = action.Visible,
		Size = UDim2.fromOffset(0, WindowFrame.CLOSE),
		AutomaticSize = Enum.AutomaticSize.X,
		AutoButtonColor = false,
		BackgroundColor3 = scope:Computed(function(use): Color3
			if use(pressed) then
				return Theme.Iron.Selected
			end
			return if use(hovered) then Theme.Iron.Hover else Theme.Iron.Raised
		end),
		Text = action.Text,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = scope:Computed(function(use): number
			return if use(compact) then Theme.TextSize.Small else Theme.TextSize.Body
		end),
		TextColor3 = Theme.Iron.Text,
		TextWrapped = false,
		ZIndex = 2,
		[OnEvent("MouseEnter")] = function()
			hovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovered:set(false)
			pressed:set(false)
		end,
		[OnEvent("MouseButton1Down")] = function()
			pressed:set(true)
		end,
		[OnEvent("MouseButton1Up")] = function()
			pressed:set(false)
		end,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			action.OnClick()
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Iron.Border,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.Padding.Medium),
				PaddingRight = UDim.new(0, Theme.Padding.Medium),
			}),
			scope:New("UISizeConstraint")({ MinSize = Vector2.new(WindowFrame.CLOSE, 0) }),
		},
	})
end

local function Window(scope: Scope, props: Props): Instance
	-- Offset from the screen centre, in virtual pixels (desktop only).
	local offset: Fusion.Value<Vector2> = props.Place or scope:Value(props.Offset or Vector2.zero) :: any
	local closeHovered = scope:Value(false)
	-- W28: the opening motion (scale up and rise into place) and, once `Closing` is set, the same path backwards
	local motion = Motion.progress(scope, props.Closing)
	local dragging = false
	local dragStart = Vector2.zero
	local offsetStart = Vector2.zero

	local fullscreen = Device.Touch
	local compact = PhoneLayout.Compact
	-- Roblox's top bar in the layer's virtual pixels (the windows' layer covers the whole screen, the bar included)
	local topBar = scope:Computed(function(use): number
		return use(Scale.TopBar) / use(Scale.Value)
	end)
	local headerHeight = scope:Computed(function(use): number
		return if use(compact) then WindowFrame.HEADER_COMPACT else WindowFrame.HEADER
	end)
	local padding = scope:Computed(function(use): UDim
		return UDim.new(0, if use(compact) then WindowFrame.PADDING_COMPACT else WindowFrame.PADDING)
	end)
	local size = { w = props.Size.X, h = props.Size.Y }

	-- The offset kept where WindowFrame.clampDrag allows on this screen, under this top bar.
	local function clampOffset(value: Vector2, screen: Vector2, bar: number): Vector2
		local o = WindowFrame.clampDrag({ w = screen.X, h = screen.Y }, size, { x = value.X, y = value.Y }, bar)
		return Vector2.new(o.x, o.y)
	end
	-- Where the PC window stands: clamped again whenever the screen or the top bar changes, not only while dragged.
	local shown = scope:Computed(function(use): Vector2
		return clampOffset(use(offset), use(Scale.VirtualSize), use(topBar))
	end)

	table.insert(
		scope,
		UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = Scale.toVirtual(Vector2.new(input.Position.X, input.Position.Y)) - dragStart
				offset:set(clampOffset(offsetStart + delta, Fusion.peek(Scale.VirtualSize), Fusion.peek(topBar)))
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
	)

	local look = FRAME
	local body = Theme.surface(props.Surface).Surface
	local rule = Theme.surface(props.Surface).Rule
	-- S135: the frame is square on the phone and only slightly rounded on PC
	local corner = Theme.Corner.Small

	-- The content: as passed, in one vertical scroll (Scroll), above a pinned footer (Footer).
	local footer = props.Footer
	local footerSpace = if footer then WindowFrame.FOOTER + WindowFrame.FOOTER_GAP else 0
	local content: Fusion.Child = props[Children] :: any
	if props.Scroll then
		content = scope:New("ScrollingFrame")({
			Name = "Scroll",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, -footerSpace),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.surface(props.Surface).TextMuted,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			[Children] = content :: any,
		})
	elseif footer then
		content = scope:New("Frame")({
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -footerSpace),
			[Children] = content :: any,
		})
	end
	local footerRow: Fusion.Child = if footer
		then scope:New("Frame")({
			Name = "Footer",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, WindowFrame.FOOTER),
			[Children] = {
				-- the line between the (scrolling) content and the actions that stay
				scope:New("Frame")({
					Name = "Rule",
					BackgroundColor3 = rule,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, -WindowFrame.FOOTER_GAP / 2),
					Size = UDim2.new(1, 0, 0, Theme.Stroke.Thin),
				}),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, Theme.Padding.Small),
				}),
				footer :: any,
			},
		})
		else {}

	return scope:New("Frame")({
		Name = props.Name or "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = scope:Computed(function(use): UDim2
			local rise = Motion.rise(use(motion))
			if use(fullscreen) then
				-- from the bottom of Roblox's top bar to the bottom of the layer (the device's safe area)
				return UDim2.new(0.5, 0, 0.5, use(topBar) / 2 + rise)
			end
			local o: Vector2 = use(shown)
			return UDim2.new(0.5, o.X, 0.5, o.Y + rise)
		end),
		Size = scope:Computed(function(use): UDim2
			if use(fullscreen) then
				return UDim2.new(1, 0, 1, -use(topBar))
			end
			return UDim2.fromOffset(props.Size.X, props.Size.Y)
		end),
		ZIndex = props.ZIndex,
		BackgroundColor3 = body,
		Active = true, -- swallow clicks so they do not reach the world

		[OnEvent("InputBegan")] = function(input: InputObject)
			if
				props.OnFocus
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				props.OnFocus()
			end
		end,

		[Children] = {
			Motion.scale(scope, motion),
			scope:New("UICorner")({
				CornerRadius = scope:Computed(function(use): UDim
					return if use(fullscreen) then UDim.new(0, 0) else corner
				end),
			}),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Size.FrameOuter,
				Color = look.frame,
			}),
			-- S135: the inner brass line of the iron frame (decorative), above the title bar and the content
			scope:New("Frame")({
				Name = "InnerLine",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(Theme.Size.FrameInner, Theme.Size.FrameInner),
				Size = UDim2.new(1, -2 * Theme.Size.FrameInner, 1, -2 * Theme.Size.FrameInner),
				ZIndex = 5,
				[Children] = {
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Size.FrameInner,
						Color = Theme.Brass.Line,
					}),
					scope:New("UICorner")({
						CornerRadius = scope:Computed(function(use): UDim
							return if use(fullscreen) then UDim.new(0, 0) else corner
						end),
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Header",
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, use(headerHeight))
				end),
				BackgroundColor3 = look.header,
				Active = true,

				[OnEvent("InputBegan")] = function(input: InputObject)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and not Fusion.peek(fullscreen) then
						dragging = true
						dragStart = Scale.toVirtual(Vector2.new(input.Position.X, input.Position.Y))
						offsetStart = Fusion.peek(shown)
					end
				end,

				[Children] = {
					scope:New("UICorner")({ CornerRadius = corner }),
					-- Square off the header's bottom corners.
					scope:New("Frame")({
						Name = "CornerFill",
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, 12),
						BackgroundColor3 = look.header,
						BorderSizePixel = 0,
					}),
					scope:New("Frame")({
						Name = "Rule",
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, Theme.Size.HeaderRule),
						BackgroundColor3 = look.rule,
						BorderSizePixel = 0,
						ZIndex = 3,
					}),
					-- the title (taking what the buttons leave), the header action and the ✕ in one row
					scope:New("Frame")({
						Name = "Bar",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 2,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, Theme.Padding.Small),
							}),
							scope:New("UIPadding")({
								PaddingLeft = padding,
								PaddingRight = UDim.new(0, WindowFrame.CLOSE_INSET),
							}),
							scope:New("TextLabel")({
								Name = "Title",
								LayoutOrder = 1,
								Size = UDim2.fromScale(0, 1),
								BackgroundTransparency = 1,
								Text = props.Title,
								FontFace = Theme.Fonts.Display,
								TextSize = scope:Computed(function(use): number
									return if use(compact) then Theme.TextSize.Body else Theme.TextSize.Large
								end),
								TextColor3 = look.title,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextWrapped = false,
								TextTruncate = Enum.TextTruncate.AtEnd,
								ZIndex = 2,
								[Children] = scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Fill }),
							}),
							(
									if props.HeaderAction then headerButton(scope, props.HeaderAction, compact) else {}
								) :: any,
							scope:New("TextButton")({
								Name = "Close",
								LayoutOrder = 3,
								-- WindowFrame.rect's ✕: 44 x 44, on a phone 52 wide and as tall as its title bar
								Size = scope:Computed(function(use): UDim2
									local w = if use(compact) then WindowFrame.CLOSE_WIDE else WindowFrame.CLOSE
									return UDim2.fromOffset(w, WindowFrame.CLOSE)
								end),
								AutoButtonColor = false,
								BackgroundColor3 = look.closeHover,
								BackgroundTransparency = scope:Computed(function(use): number
									return if use(closeHovered) then 0 else 1
								end),
								Text = "✕",
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Large,
								TextColor3 = scope:Computed(function(use): Color3
									return if use(closeHovered) then look.closeHoverText else look.close
								end),
								ZIndex = 2,
								[OnEvent("MouseEnter")] = function()
									closeHovered:set(true)
								end,
								[OnEvent("MouseLeave")] = function()
									closeHovered:set(false)
								end,
								[OnEvent("Activated")] = function()
									Sounds.play("click")
									props.OnClose()
								end,
								[Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
								},
							}),
						},
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Content",
				BackgroundTransparency = 1,
				Position = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(0, use(headerHeight))
				end),
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 1, -use(headerHeight))
				end),
				ClipsDescendants = true,
				[Children] = {
					scope:New("UIPadding")({
						PaddingTop = padding,
						PaddingBottom = padding,
						PaddingLeft = padding,
						PaddingRight = padding,
					}),
					content :: any,
					footerRow :: any,
				},
			}),
		},
	})
end

return Window
