--!strict
-- Shared bits of the guild window tabs: server calls with error toasts, small labelled rows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Common = {}

-- Yields. Plays an error sound and shows the reason on failure.
function Common.invoke(name: string, ...: any): (boolean, string?)
	local ok, err = Net.Invoke(name, ...)
	if not ok then
		Sounds.play("error")
		Toast.push(Text.now(err or "error.internal"), "error")
	end
	return ok, err
end

-- Modal variant: returns (ok, localized error) for Modal.OnConfirm.
function Common.modalInvoke(name: string, ...: any): (boolean, string?)
	local ok, err = Net.Invoke(name, ...)
	if not ok then
		return false, Text.now(err or "error.internal")
	end
	return true, nil
end

-- "Label: value" line.
function Common.infoRow(
	scope: Scope,
	order: number,
	label: Fusion.UsedAs<string>,
	value: Fusion.UsedAs<string>
): Instance
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("TextLabel")({
				Size = UDim2.fromScale(0.4, 1),
				BackgroundTransparency = 1,
				Text = label,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromScale(0.4, 0),
				Size = UDim2.fromScale(0.6, 1),
				BackgroundTransparency = 1,
				Text = value,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		},
	})
end

function Common.list(scope: Scope, padding: number?): Instance
	return scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, padding or 6) })
end

-- S159g: rank colours (members list, rights table).
Common.RANK_COLORS = table.freeze({
	leader = Theme.Paper.Heading,
	officer = Theme.Paper.Link,
	veteran = Theme.Paper.Success,
	member = Theme.Paper.TextMuted,
}) :: { [string]: Color3 }

-- S159g: a section heading in the display font.
function Common.heading(scope: Scope, order: number, text: Fusion.UsedAs<string>): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = text,
		FontFace = Theme.Fonts.Display,
		TextSize = Theme.TextSize.Large,
		TextColor3 = Theme.Paper.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

-- S159g: wrapped small text that grows with its content.
function Common.paragraph(
	scope: Scope,
	order: number,
	text: Fusion.UsedAs<string>,
	color: Fusion.UsedAs<Color3>?
): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		RichText = true,
		TextWrapped = true,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		TextColor3 = color or Theme.Paper.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end

-- S159g: a vertical scrolling page with a list layout (every tab that can grow past the window).
function Common.page(scope: Scope, padding: number, children: { any }): Instance
	return scope:New("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Rule,
		[Children] = {
			Common.list(scope, padding),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }),
			children :: any,
		},
	})
end

-- S159g: "12:34" style UTC date of a log line (day.month hour:minute).
function Common.stamp(t: number): string
	return os.date("!%d.%m %H:%M", t) :: string
end

return Common
