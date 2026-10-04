--!strict
-- Single-line text box bound to a Fusion Value, with placeholder, max length and an error line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnChange, OnEvent, Out = Fusion.Children, Fusion.OnChange, Fusion.OnEvent, Fusion.Out

type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Text: Fusion.Value<string>,
	Placeholder: UsedAs<string>?,
	MaxLength: number?, -- in characters (UTF-8 aware)
	Error: UsedAs<string?>?, -- shown under the box in red when non-empty
	Size: UsedAs<UDim2>?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	LayoutOrder: UsedAs<number>?,
	OnSubmit: ((text: string) -> ())?,
	Name: string?,
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

local function TextInput(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local focused = scope:Value(false)
	local hasError = scope:Computed(function(use): boolean
		local err = use(props.Error)
		return type(err) == "string" and err ~= ""
	end)

	return scope:New("Frame")({
		Name = props.Name or "TextInput",
		Size = props.Size or UDim2.new(1, 0, 0, Theme.Size.InputHeight + 22),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,

		[Children] = {
			scope:New("TextBox")({
				Name = "Box",
				Size = UDim2.new(1, 0, 0, Theme.Size.InputHeight),
				BackgroundColor3 = Theme.Colors.Background,
				ClearTextOnFocus = false,
				Text = props.Text,
				PlaceholderText = props.Placeholder,
				PlaceholderColor3 = Theme.Colors.TextMuted,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.Text,
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
								return Theme.Colors.Danger
							end
							return if use(focused) then Theme.Colors.Gold else Theme.Colors.Border
						end),
					}),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, Theme.Padding.Medium),
						PaddingRight = UDim.new(0, Theme.Padding.Medium),
					}),
				},
			}),
			scope:New("TextLabel")({
				Name = "Error",
				Position = UDim2.fromOffset(2, Theme.Size.InputHeight + 2),
				Size = UDim2.new(1, -4, 0, 20),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local err = use(props.Error)
					return if type(err) == "string" then err else ""
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.DangerHover,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		},
	})
end

return TextInput
