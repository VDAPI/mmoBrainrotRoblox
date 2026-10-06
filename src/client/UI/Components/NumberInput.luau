--!strict
-- Number field (S23): [−] [box] [+], clamped to Min..Max, whole numbers by default (Step 1). Typing a value
-- and leaving the box (or Enter) applies it; invalid text snaps back. 44 px high (touch).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent, Out = Fusion.Children, Fusion.OnEvent, Fusion.Out

export type Props = {
	Value: Fusion.Value<number>,
	Min: number?,
	Max: number?,
	Step: number?,
	Integer: boolean?, -- default true
	Size: Fusion.UsedAs<UDim2>?,
	LayoutOrder: number?,
}

local function NumberInput(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local min = props.Min or -math.huge
	local max = props.Max or math.huge
	local step = props.Step or 1
	local integer = props.Integer ~= false

	local function clamp(n: number): number
		if integer then
			n = math.floor(n + 0.5)
		end
		return math.clamp(n, min, max)
	end

	local typed = scope:Value(tostring(Fusion.peek(props.Value)))
	scope:Observer(props.Value):onChange(function()
		typed:set(tostring(Fusion.peek(props.Value)))
	end)

	local function apply(text: string)
		local n = tonumber(text)
		if n == nil or n ~= n then
			typed:set(tostring(Fusion.peek(props.Value)))
			return
		end
		local value = clamp(n)
		props.Value:set(value)
		typed:set(tostring(value))
	end

	local function stepButton(text: string, delta: number, order: number): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = UDim2.fromOffset(Theme.Size.MinTouch - 6, Theme.Size.MinTouch),
			AutoButtonColor = true,
			BackgroundColor3 = Theme.Colors.PanelRaised,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Large,
			TextColor3 = Theme.Colors.Parchment,
			[OnEvent("Activated")] = function()
				props.Value:set(clamp(Fusion.peek(props.Value) + delta))
			end,
			[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		})
	end

	return scope:New("Frame")({
		Name = "NumberInput",
		LayoutOrder = props.LayoutOrder,
		Size = props.Size or UDim2.fromOffset(170, Theme.Size.MinTouch),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			stepButton("−", -step, 1),
			scope:New("TextBox")({
				LayoutOrder = 2,
				Size = UDim2.new(1, -2 * (Theme.Size.MinTouch - 6) - 8, 1, 0),
				BackgroundColor3 = Theme.Colors.Background,
				ClearTextOnFocus = false,
				Text = typed,
				[Out("Text")] = typed,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Text,
				[OnEvent("FocusLost")] = function()
					apply(Fusion.peek(typed))
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						Color = Theme.Colors.Border,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				},
			}),
			stepButton("+", step, 3),
		},
	})
end

return NumberInput
