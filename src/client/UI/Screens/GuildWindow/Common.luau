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
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromScale(0.4, 0),
				Size = UDim2.fromScale(0.6, 1),
				BackgroundTransparency = 1,
				Text = value,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		},
	})
end

function Common.list(scope: Scope, padding: number?): Instance
	return scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, padding or 6) })
end

return Common
