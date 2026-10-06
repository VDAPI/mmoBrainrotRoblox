--!strict
-- Guide bar under the minimap (S25, DESIGN §23): "➤ Blacksmith Dorgan · 84 m ✕" while a guide target is set
-- (UI/NavTarget, NavController keeps the distance), "via: <map>" when the target is on another map, a walking
-- arrow while the character walks there by itself. A click on the bar opens the world map on the target and
-- its card; ✕ ends the guide. Under it the /navdebug line for admins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local NavTarget = require(script.Parent.Parent.Parent.NavTarget)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	ShowWindow: (id: string) -> (),
	StopGuide: () -> (),
}

local WIDTH = 264

local function NavBar(scope: Scope, props: Props): Instance
	local target = NavTarget.Target
	local text = scope:Computed(function(use): string
		local t = use(target)
		if not t then
			return ""
		end
		local name = if t.label then t.label elseif t.labelKey then Text.get(use, t.labelKey) else ""
		local distance = math.floor(use(NavTarget.Distance) or 0)
		local via = use(NavTarget.Via)
		local map = if via then Maps.get(via) else nil
		local arrow = if use(NavTarget.Walking) then "⇶" else "➤"
		if map then
			return `{arrow} {Text.get(use, "nav.barVia", {
				name = name,
				map = Text.get(use, map.nameKey),
				n = distance,
			})}`
		end
		return `{arrow} {Text.get(use, "nav.bar", { name = name, n = distance })}`
	end)

	return scope:New("Frame")({
		Name = "NavBar",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return use(target) ~= nil or use(NavTarget.Debug) ~= nil
		end),
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
			scope:New("Frame")({
				Name = "Bar",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(WIDTH, 36),
				BackgroundColor3 = Theme.Colors.Panel,
				BackgroundTransparency = 0.1,
				Visible = scope:Computed(function(use): boolean
					return use(target) ~= nil
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						Color = Theme.Colors.GoldBright,
						Transparency = 0.35,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					scope:New("TextButton")({
						Name = "Open",
						Size = UDim2.new(1, -40, 1, 0),
						BackgroundTransparency = 1,
						Text = text,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 15,
						TextColor3 = Theme.Colors.GoldBright,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						[OnEvent("Activated")] = function()
							local t = Fusion.peek(target)
							if not t then
								return
							end
							NavTarget.MapFocus:set({
								map = t.map,
								x = t.x,
								z = t.z,
								zoom = 3,
								card = if t.kind
										and t.id
										and t.kind ~= "point"
									then { kind = t.kind, id = t.id, extra = { map = t.map, x = t.x, z = t.z } } :: any
									else nil,
							})
							props.ShowWindow("map")
						end,
						[Children] = scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10) }),
					}),
					scope:New("TextButton")({
						Name = "Stop",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -2, 0.5, 0),
						Size = UDim2.fromOffset(36, 36),
						BackgroundTransparency = 1,
						Text = "✕",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 18,
						TextColor3 = Theme.Colors.Parchment,
						[OnEvent("Activated")] = props.StopGuide,
					}),
				},
			}),
			scope:New("TextLabel")({
				Name = "Debug",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(WIDTH, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Background,
				BackgroundTransparency = 0.3,
				Visible = scope:Computed(function(use): boolean
					return use(NavTarget.Debug) ~= nil
				end),
				Text = scope:Computed(function(use): string
					return use(NavTarget.Debug) or ""
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = 12,
				TextColor3 = Color3.fromHex("#E0564A"),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
end

return NavBar
