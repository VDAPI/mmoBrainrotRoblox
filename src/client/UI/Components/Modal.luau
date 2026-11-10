--!strict
-- Confirmation dialog over a dimmed overlay, optionally with a text field (e.g. "type the name to
-- delete"). OnConfirm may yield (server call); returning false keeps the dialog open and shows the error.
-- Shown through WindowManager.ShowModal, which guarantees one modal at a time.
-- Owner 2026-10-21 (descriptions: nothing removed, only hidden): `Details` is the longer text of a short message,
-- under the shared "More ▸" (Components/Details), closed. Owner 2026-10-31: `Check` = one switch above the buttons
-- (off at first, e.g. "do not ask again"), its state reported through OnChange.
-- Owner 2026-11-10 ("too much text, things covering each other"), UI package C: a modal is a small window. Its title
-- stands on one line in an iron title bar with the ✕ (cancel, like Esc; only a dialog that can be cancelled has it);
-- the short message (at most 90 characters, not repeating the title), its Details under "Więcej ▸", the field and
-- the switch scroll in the body; the buttons stay in a footer under it. ModalWidth (520) wide, less on a narrow
-- screen, at most the screen less Roblox's top bar less 16 tall, centred under the bar (Logic/WindowFrame.modal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local Details = require(script.Parent.Details)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Motion = require(script.Parent.Parent.Motion)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local Scale = require(script.Parent.Parent.Scale)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)
local TextInput = require(script.Parent.TextInput)
local Toggle = require(script.Parent.Toggle)
local WindowFrame = require(ReplicatedStorage.Shared.Logic.WindowFrame)

local Children, OnEvent, Out = Fusion.Children, Fusion.OnEvent, Fusion.Out

type UsedAs<T> = Fusion.UsedAs<T>

export type InputSpec = {
	Placeholder: UsedAs<string>?,
	-- When set, the confirm button stays disabled until the text equals this exactly.
	MustMatch: string?,
	MaxLength: number?,
}

export type CheckSpec = {
	Label: UsedAs<string>,
	OnChange: (checked: boolean) -> (),
}

export type Spec = {
	Title: UsedAs<string>, -- one line in the title bar (at most 28 characters)
	Message: UsedAs<string>?, -- the short message (at most 90 characters, not repeating the title)
	Details: UsedAs<string>?, -- the longer text under "Więcej ▸" (closed; at most 240 characters)
	Check: CheckSpec?, -- a switch above the buttons, off at first
	ConfirmText: UsedAs<string>,
	CancelText: UsedAs<string>?, -- nil = no cancel button (info dialog)
	Variant: ("primary" | "danger")?,
	Input: InputSpec?,
	-- Returns (ok, errorText?). Errors are already localized by the caller.
	OnConfirm: ((text: string) -> (boolean, string?))?,
	OnCancel: (() -> ())?,
}

export type Props = Spec & {
	Close: () -> (),
	Closing: Fusion.Value<boolean>?, -- W28: true plays the closing motion (WindowManager removes the dialog after it)
}

local DIM = 0.45 -- overlay transparency once the dialog is in place

local function Modal(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local text = scope:Value("")
	local busy = scope:Value(false)
	local errorText = scope:Value(nil :: string?)
	local closeHovered = scope:Value(false)

	local canConfirm = scope:Computed(function(use): boolean
		if use(busy) then
			return false
		end
		local input = props.Input
		if input and input.MustMatch then
			return use(text) == input.MustMatch
		end
		return true
	end)

	local function cancel()
		if Fusion.peek(busy) then
			return
		end
		if props.OnCancel then
			props.OnCancel()
		end
		props.Close()
	end

	local function confirm()
		if not Fusion.peek(canConfirm) then
			return
		end
		if not props.OnConfirm then
			props.Close()
			return
		end
		busy:set(true)
		errorText:set(nil)
		task.spawn(function()
			local ok, err = props.OnConfirm(Fusion.peek(text))
			busy:set(false)
			if ok then
				props.Close()
			else
				errorText:set(err)
			end
		end)
	end

	-- W28: the dialog opens and closes like a window, the dim behind it fades with it
	local motion = Motion.progress(scope, props.Closing)
	local compact = PhoneLayout.Compact
	local headerHeight = scope:Computed(function(use): number
		return if use(compact) then WindowFrame.HEADER_COMPACT else WindowFrame.HEADER
	end)
	local pad = scope:Computed(function(use): number
		return if use(compact) then WindowFrame.PADDING_COMPACT else WindowFrame.PADDING
	end)
	-- The Modals layer (the overlay covers it) in screen pixels, and Roblox's top bar in virtual ones.
	local layerSize = scope:Value(Vector2.zero)
	local topBar = scope:Computed(function(use): number
		return use(Scale.TopBar) / use(Scale.Value)
	end)
	-- Logic/WindowFrame.modal at the largest height: its width, and the room the body may scroll in under the title
	-- bar and over the footer.
	local room = scope:Computed(function(use): WindowFrame.Rect
		local real: Vector2 = use(layerSize)
		local layer = if real.X > 0 and real.Y > 0 then real / use(Scale.Value) else use(Scale.VirtualSize)
		return WindowFrame.modal({ w = layer.X, h = layer.Y }, math.huge, use(topBar))
	end)
	local maxBody = scope:Computed(function(use): number
		local r = use(room)
		return math.max(0, r.bottom - r.top - use(headerHeight) - WindowFrame.FOOTER - use(pad))
	end)
	local padding = scope:Computed(function(use): UDim
		return UDim.new(0, use(pad))
	end)

	local body: ScrollingFrame
	body = scope:New("ScrollingFrame")({
		Name = "Body",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.TextMuted,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		[Children] = {
			-- grows with its content up to the room under the title bar, then scrolls
			scope:New("UISizeConstraint")({
				MaxSize = scope:Computed(function(use): Vector2
					return Vector2.new(math.huge, use(maxBody))
				end),
			}),
			scope:New("UIPadding")({
				PaddingTop = padding,
				PaddingBottom = padding,
				PaddingLeft = padding,
				PaddingRight = padding,
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Medium),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			if props.Message
				then scope:New("TextLabel")({
					Name = "Message",
					LayoutOrder = 2,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Text = props.Message,
					RichText = true,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Text,
					TextWrapped = true,
				}) :: any
				else nil,
			if props.Details
				then Details.new(scope, {
					Name = "Details",
					LayoutOrder = 3,
					Children = {
						scope:New("TextLabel")({
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Text = props.Details,
							RichText = true,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.Text,
							TextWrapped = true,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
					},
				}) :: any
				else nil,
			if props.Input
				then TextInput(scope, {
					LayoutOrder = 4,
					Text = text,
					Placeholder = props.Input.Placeholder,
					MaxLength = props.Input.MaxLength,
					Error = errorText,
					OnSubmit = function()
						confirm()
					end,
				})
				else scope:New("TextLabel")({
					Name = "Error",
					LayoutOrder = 6,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Visible = scope:Computed(function(use): boolean
						return use(errorText) ~= nil
					end),
					Text = scope:Computed(function(use): string
						return use(errorText) or ""
					end),
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.Danger,
					TextWrapped = true,
				}),
			if props.Check
				then Toggle(scope, {
					LayoutOrder = 5,
					Value = scope:Value(false),
					Label = props.Check.Label,
					OnChange = props.Check.OnChange,
					Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
				}) :: any
				else nil,
		},
	}) :: ScrollingFrame
	-- an error shows at the end of a body that scrolls: scroll to it
	scope:Observer(errorText):onChange(function()
		if Fusion.peek(errorText) ~= nil then
			body.CanvasPosition = Vector2.new(0, math.huge)
		end
	end)

	return scope:New("TextButton")({
		Name = "ModalOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Shade,
		BackgroundTransparency = scope:Computed(function(use): number
			return 1 - (1 - DIM) * math.clamp(use(motion), 0, 1)
		end),
		AutoButtonColor = false,
		Text = "",
		Active = true,
		[Out("AbsoluteSize")] = layerSize,

		[Children] = {
			scope:New("Frame")({
				Name = "Dialog",
				-- centred in the room under Roblox's top bar (it is never taller than that less 16)
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = scope:Computed(function(use): UDim2
					return UDim2.new(0.5, 0, 0.5, use(topBar) / 2 + Motion.rise(use(motion)))
				end),
				Size = scope:Computed(function(use): UDim2
					local r = use(room)
					return UDim2.fromOffset(r.right - r.left, 0)
				end),
				AutomaticSize = Enum.AutomaticSize.Y,
				-- S135: parchment with the iron frame of a window (a danger dialog keeps a red frame)
				BackgroundColor3 = Theme.Paper.Surface,
				Active = true,

				[Children] = {
					Motion.scale(scope, motion),
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Size.FrameOuter,
						Color = if props.Variant == "danger" then Theme.Paper.Danger else Theme.Brass.Frame,
					}),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					-- the title bar: the title on one line and the ✕ of a dialog that can be cancelled
					scope:New("Frame")({
						Name = "Header",
						LayoutOrder = 1,
						Size = scope:Computed(function(use): UDim2
							return UDim2.new(1, 0, 0, use(headerHeight))
						end),
						BackgroundColor3 = Theme.Iron.Raised,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							scope:New("Frame")({
								Name = "CornerFill",
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.new(1, 0, 0, 12),
								BackgroundColor3 = Theme.Iron.Raised,
								BorderSizePixel = 0,
							}),
							scope:New("Frame")({
								Name = "Rule",
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.new(1, 0, 0, Theme.Size.HeaderRule),
								BackgroundColor3 = Theme.Brass.Line,
								BorderSizePixel = 0,
								ZIndex = 3,
							}),
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
										TextColor3 = Theme.Iron.Text,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextWrapped = false,
										TextTruncate = Enum.TextTruncate.AtEnd,
										ZIndex = 2,
										[Children] = scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Fill }),
									}),
									if props.CancelText
										then scope:New("TextButton")({
											Name = "Close",
											LayoutOrder = 2,
											Size = scope:Computed(function(use): UDim2
												local w = if use(compact)
													then WindowFrame.CLOSE_WIDE
													else WindowFrame.CLOSE
												return UDim2.fromOffset(w, WindowFrame.CLOSE)
											end),
											AutoButtonColor = false,
											BackgroundColor3 = Theme.Iron.Danger,
											BackgroundTransparency = scope:Computed(function(use): number
												return if use(closeHovered) then 0 else 1
											end),
											Text = "✕",
											FontFace = Theme.Fonts.BodyBold,
											TextSize = Theme.TextSize.Large,
											TextColor3 = scope:Computed(function(use): Color3
												return if use(closeHovered)
													then Theme.Iron.DangerText
													else Theme.Iron.Text
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
												cancel()
											end,
											[Children] = {
												scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
											},
										}) :: any
										else nil,
								},
							}),
						},
					}),
					body,
					-- the footer: the buttons stay under the scrolling body
					scope:New("Frame")({
						Name = "Buttons",
						LayoutOrder = 3,
						BackgroundTransparency = 1,
						Size = scope:Computed(function(use): UDim2
							return UDim2.new(1, 0, 0, WindowFrame.FOOTER + use(pad))
						end),
						[Children] = {
							scope:New("UIPadding")({
								PaddingBottom = padding,
								PaddingLeft = padding,
								PaddingRight = padding,
							}),
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, Theme.Padding.Medium),
							}),
							if props.CancelText
								then Button(scope, {
									LayoutOrder = 1,
									Text = props.CancelText,
									Variant = "ghost",
									Size = UDim2.new(0.5, -Theme.Padding.Medium / 2, 1, 0),
									Disabled = busy,
									OnClick = cancel,
								}) :: any
								else nil,
							Button(scope, {
								LayoutOrder = 2,
								Text = props.ConfirmText,
								Variant = props.Variant or "primary",
								Size = if props.CancelText
									then UDim2.new(0.5, -Theme.Padding.Medium / 2, 1, 0)
									else UDim2.fromScale(0.6, 1),
								Disabled = scope:Computed(function(use): boolean
									return not use(canConfirm)
								end),
								OnClick = confirm,
							}),
						},
					}),
				},
			}),
		},
	})
end

return Modal
