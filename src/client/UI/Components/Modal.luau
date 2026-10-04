--!strict
-- Confirmation dialog over a dimmed overlay, optionally with a text field (e.g. "type the name to
-- delete"). OnConfirm may yield (server call); returning false keeps the dialog open and shows the error.
-- Shown through WindowManager.ShowModal, which guarantees one modal at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)
local TextInput = require(script.Parent.TextInput)

local Children = Fusion.Children

type UsedAs<T> = Fusion.UsedAs<T>

export type InputSpec = {
	Placeholder: UsedAs<string>?,
	-- When set, the confirm button stays disabled until the text equals this exactly.
	MustMatch: string?,
	MaxLength: number?,
}

export type Spec = {
	Title: UsedAs<string>,
	Message: UsedAs<string>?,
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
}

local function Modal(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local text = scope:Value("")
	local busy = scope:Value(false)
	local errorText = scope:Value(nil :: string?)

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

	local width = 520

	return scope:New("TextButton")({
		Name = "ModalOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Overlay,
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		Active = true,

		[Children] = {
			scope:New("Frame")({
				Name = "Dialog",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(width, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Panel,
				Active = true,

				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Stroke.Thick,
						Color = if props.Variant == "danger" then Theme.Colors.Danger else Theme.Colors.Gold,
					}),
					scope:New("UISizeConstraint")({ MaxSize = Vector2.new(width, math.huge) }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, Theme.Padding.Large),
						PaddingBottom = UDim.new(0, Theme.Padding.Large),
						PaddingLeft = UDim.new(0, Theme.Padding.Large),
						PaddingRight = UDim.new(0, Theme.Padding.Large),
					}),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Padding.Medium),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),
					scope:New("TextLabel")({
						Name = "Title",
						LayoutOrder = 1,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 36),
						Text = props.Title,
						FontFace = Theme.Fonts.Heading,
						TextSize = Theme.TextSize.Title,
						TextColor3 = Theme.Colors.Gold,
						TextWrapped = true,
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
							TextColor3 = Theme.Colors.Text,
							TextWrapped = true,
						}) :: any
						else nil,
					if props.Input
						then TextInput(scope, {
							LayoutOrder = 3,
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
							LayoutOrder = 3,
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
							TextColor3 = Theme.Colors.DangerHover,
							TextWrapped = true,
						}),
					scope:New("Frame")({
						Name = "Buttons",
						LayoutOrder = 4,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
						[Children] = {
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
