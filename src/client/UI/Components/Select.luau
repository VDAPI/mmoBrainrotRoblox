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
}

local SEARCH_FROM = 12

local function Select(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local open = scope:Value(false)
	local query = scope:Value("")
	local width = props.Width or 220

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
					Size = UDim2.new(1, 0, 0, 34),
					AutoButtonColor = true,
					BackgroundColor3 = if option.value == Fusion.peek(props.Selected)
						then Theme.Colors.PanelHover
						else Theme.Colors.Panel,
					Text = option.label,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = option.color or Theme.Colors.Text,
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
				BackgroundColor3 = Theme.Colors.PanelRaised,
				Text = scope:Computed(function(use): string
					local option = use(current)
					return `{if option then option.label else (use(props.Placeholder) or "—")}  ▾`
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					local option = use(current)
					return if option and option.color then option.color else Theme.Colors.Parchment
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				[OnEvent("Activated")] = function()
					open:set(not Fusion.peek(open))
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6) }),
				},
			}),
			scope:New("TextBox")({
				LayoutOrder = 2,
				Visible = scope:Computed(function(use): boolean
					return use(open) and #use(props.Options) > SEARCH_FROM
				end),
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = Theme.Colors.Background,
				ClearTextOnFocus = false,
				PlaceholderText = "🔍",
				Text = query,
				[Out("Text")] = query,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Text,
				[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			}),
			scope:New("ScrollingFrame")({
				LayoutOrder = 3,
				Visible = open,
				Size = UDim2.new(1, 0, 0, props.ListHeight or 220),
				BackgroundColor3 = Theme.Colors.Panel,
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
