--!strict
-- Single-line text box bound to a Fusion Value, with placeholder, max length and an error line.
-- UI plan 2026-11-10 (package C): the box fills a frame too low for the box and the error line under it (a 44-px
-- frame drew a 52-px box over what stood below); the error line then hangs under the frame. Placeholder: at most 20
-- characters (Logic/TextCaps "placeholder").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnChange, OnEvent, Out = Fusion.Children, Fusion.OnChange, Fusion.OnEvent, Fusion.Out

type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Text: Fusion.Value<string>,
	Placeholder: UsedAs<string>?, -- at most 20 characters
	MaxLength: number?, -- in characters (UTF-8 aware)
	Error: UsedAs<string?>?, -- shown under the box in red when non-empty
	-- false: no error line under the box, the caller shows the error on a line of its own (the character creator's
	-- pinned footer, review 2026-11-11); the box's stroke still turns red
	ErrorLine: boolean?,
	Size: UsedAs<UDim2>?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	LayoutOrder: UsedAs<number>?,
	OnSubmit: ((text: string) -> ())?,
	Name: string?,
	Surface: Theme.SurfaceName?, -- S135 (default "paper")
}

local function clampLength(text: string, max: number?): string
	if not max then
		return text
	end
	local length = utf8.len(text)
	if length == nil or length <= max then
		return text
	end
	local cut = utf8.offset(text, max + 1)
	return if cut then string.sub(text, 1, cut - 1) else text
end

-- The default frame: the box and the error line under it.
local ERROR_LINE = 22

local function TextInput(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local roles = Theme.surface(props.Surface)
	local focused = scope:Value(false)
	local hasError = scope:Computed(function(use): boolean
		local err = use(props.Error)
		return type(err) == "string" and err ~= ""
	end)
	local errorLine = props.ErrorLine ~= false
	local frameSize = props.Size or UDim2.new(1, 0, 0, Theme.Size.InputHeight + (if errorLine then ERROR_LINE else 0))
	-- a frame given in pixels, too low for the box and the error line: the box fills it
	local fill = scope:Computed(function(use): boolean
		local size: UDim2 = use(frameSize)
		return size.Y.Scale == 0 and size.Y.Offset < Theme.Size.InputHeight + (if errorLine then ERROR_LINE else 0)
	end)

	-- the error line under the box (none with ErrorLine = false)
	local errorLabel = if errorLine
		then scope:New("TextLabel")({
			Name = "Error",
			Position = scope:Computed(function(use): UDim2
				return if use(fill) then UDim2.new(0, 2, 1, 2) else UDim2.fromOffset(2, Theme.Size.InputHeight + 2)
			end),
			Size = UDim2.new(1, -4, 0, 20),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local err = use(props.Error)
				return if type(err) == "string" then err else ""
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Small,
			TextColor3 = roles.Danger,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		else nil

	return scope:New("Frame")({
		Name = props.Name or "TextInput",
		Size = frameSize,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,

		[Children] = {
			scope:New("TextBox")({
				Name = "Box",
				Size = scope:Computed(function(use): UDim2
					return if use(fill) then UDim2.fromScale(1, 1) else UDim2.new(1, 0, 0, Theme.Size.InputHeight)
				end),
				BackgroundColor3 = roles.Sunken,
				ClearTextOnFocus = false,
				Text = props.Text,
				PlaceholderText = props.Placeholder,
				PlaceholderColor3 = roles.TextMuted,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Large,
				TextColor3 = roles.Text,
				TextXAlignment = Enum.TextXAlignment.Left,

				[Out("Text")] = props.Text,
				[OnChange("Text")] = function(text: string)
					local clamped = clampLength(text, props.MaxLength)
					if clamped ~= text then
						props.Text:set(clamped)
					end
				end,
				[OnEvent("Focused")] = function()
					focused:set(true)
				end,
				[OnEvent("FocusLost")] = function(enterPressed: boolean)
					focused:set(false)
					if enterPressed and props.OnSubmit then
						props.OnSubmit(Fusion.peek(props.Text))
					end
				end,

				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Stroke.Normal,
						Color = scope:Computed(function(use): Color3
							if use(hasError) then
								return roles.Danger
							end
							return if use(focused) then roles.Heading else roles.Border
						end),
					}),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, Theme.Padding.Medium),
						PaddingRight = UDim.new(0, Theme.Padding.Medium),
					}),
				},
			}),
			errorLabel :: any,
		},
	})
end

return TextInput
