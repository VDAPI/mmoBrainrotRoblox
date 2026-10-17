--!strict
-- Choice from a list (S23): a button with the current option; a click unfolds the list below it inside the
-- same frame (no overlay, so it works inside scrolling panels), with a search box when there are more than
-- 12 options. Choosing folds it again. 44 px rows (touch).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent, Out = Fusion.Children, Fusion.OnEvent, Fusion.Out

export type Option = { value: string, label: string, color: Color3? }

export type Props = {
	Options: Fusion.UsedAs<{ Option }>,
	Selected: Fusion.Value<string?>,
	Placeholder: Fusion.UsedAs<string>?,
	OnChange: ((value: string) -> ())?,
	Width: number?,
	LayoutOrder: number?,
	ListHeight: number?,
	Surface: Theme.SurfaceName?, -- S135 (default "paper")
}

local SEARCH_FROM = 12

local function Select(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local open = scope:Value(false)
	local query = scope:Value("")
	local width = props.Width or 220
	local roles = Theme.surface(props.Surface)

	local current = scope:Computed(function(use): Option?
		local selected = use(props.Selected)
		for _, option in use(props.Options) do
			if option.value == selected then
				return option
			end
		end
		return nil
	end)

	local filtered = scope:Computed(function(use): { Option }
		local q = string.lower(use(query))
		local out = {}
		for _, option in use(props.Options) do
			if
				q == ""
				or string.find(string.lower(option.label), q, 1, true)
				or string.find(string.lower(option.value), q, 1, true)
			then
				table.insert(out, option)
			end
		end
		return out
	end)

	local rows = scope:Computed(function(use, s: Fusion.Scope<typeof(Fusion)>): { Instance }
		if not use(open) then
			return {}
		end
		local out = {}
		for i, option in use(filtered) do
			if i > 200 then
				break
			end
			table.insert(
				out,
				s:New("TextButton")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
					AutoButtonColor = true,
					BackgroundColor3 = if option.value == Fusion.peek(props.Selected)
						then roles.Selected
						else roles.Surface,
					Text = option.label,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					-- S135: an option colour from game data is corrected for the surface
					TextColor3 = if option.color
						then Theme.readable(Theme.hex(option.color), props.Surface)
						else roles.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					[OnEvent("Activated")] = function()
						Sounds.play("click")
						props.Selected:set(option.value)
						open:set(false)
						query:set("")
						if props.OnChange then
							props.OnChange(option.value)
						end
					end,
					[Children] = scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
				})
			)
		end
		return out
	end)

	return scope:New("Frame")({
		Name = "Select",
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(width, Theme.Size.MinTouch),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
			scope:New("TextButton")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
				AutoButtonColor = true,
				BackgroundColor3 = roles.Raised,
				Text = scope:Computed(function(use): string
					local option = use(current)
					return `{if option then option.label else (use(props.Placeholder) or "—")}  ▾`
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					local option = use(current)
					return if option and option.color
						then Theme.readable(Theme.hex(option.color), props.Surface)
						else roles.Text
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				[OnEvent("Activated")] = function()
					open:set(not Fusion.peek(open))
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Stroke.Thin,
						Color = roles.Border,
					}),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6) }),
				},
			}),
			scope:New("TextBox")({
				LayoutOrder = 2,
				Visible = scope:Computed(function(use): boolean
					return use(open) and #use(props.Options) > SEARCH_FROM
				end),
				Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
				BackgroundColor3 = roles.Sunken,
				ClearTextOnFocus = false,
				PlaceholderText = "🔍",
				Text = query,
				[Out("Text")] = query,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = roles.Text,
				PlaceholderColor3 = roles.TextMuted,
				[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			}),
			scope:New("ScrollingFrame")({
				LayoutOrder = 3,
				Visible = open,
				Size = UDim2.new(1, 0, 0, props.ListHeight or 220),
				BackgroundColor3 = roles.Surface,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 5,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }),
					rows :: any,
				},
			}),
		},
	})
end

return Select
