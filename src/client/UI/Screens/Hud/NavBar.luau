--!strict
-- Guide bar under the minimap (S25, DESIGN §23): "➤ Blacksmith Dorgan · 84 m ✕" while a guide target is set
-- (UI/NavTarget, NavController keeps the distance), "via: <map>" when the target is on another map, a walking
-- arrow while the character walks there by itself. A click on the bar opens the world map on the target and
-- its card; ✕ ends the guide. Under it the /navdebug line for admins.
-- Owner 2026-11-10 ("things covering each other"; UI plan package A): on a phone the bar left the minimap's column (it
-- reached the skill arc): a second bar (`Phone`) stands in the M zone under the cast line while the zone reaches down
-- far enough (Logic/PhoneHud `navBar`), else it takes a line of the stack ("guide", UI/HudSlots); the bar in the menu
-- under the minimap is PC's and a tablet's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local NavTarget = require(script.Parent.Parent.Parent.NavTarget)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	ShowWindow: (id: string) -> (),
	StopGuide: () -> (),
	Phone: boolean?, -- the phone's bar (M zone or the stack); else the menu's (PC and a tablet)
}

local WIDTH = 264

local function NavBar(scope: Scope, props: Props): Instance
	local target = NavTarget.Target
	local phone = props.Phone == true
	local compact = PhoneLayout.Compact
	local inM = PhoneLayout.Has(scope, "navBar")
	-- a phone whose M zone is too short: one line of the stack
	local slot = if phone
		then HudSlots.join(
			scope,
			"guide",
			scope:Computed(function(use): HudSlots.Box
				local line = Theme.Size.MinTouch
				return {
					shown = use(compact) and use(target) ~= nil and not use(inM),
					w = PhoneHud.PANEL_WIDTH,
					h = line,
					line = line,
				}
			end)
		)
		else nil
	local barWidth = scope:Computed(function(use): number
		if not phone then
			return WIDTH
		end
		local place = use(PhoneLayout.Places).navBar
		return if place then place.w else PhoneHud.PANEL_WIDTH
	end)
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

	local stackAt = if slot then HudSlots.position(scope, slot) else nil
	return scope:New("Frame")({
		Name = "NavBar",
		LayoutOrder = 3,
		Position = if phone
			then scope:Computed(function(use): UDim2
				local place = use(PhoneLayout.Places).navBar
				if place then
					return UDim2.fromOffset(place.x, place.y)
				end
				return if stackAt then use(stackAt) else UDim2.new()
			end)
			else nil,
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(use(barWidth), 0)
		end),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			if not (use(target) ~= nil or use(NavTarget.Debug) ~= nil) then
				return false
			end
			if not phone then
				return not use(compact)
			end
			return use(compact) and (use(inM) or (slot ~= nil and use(slot) ~= nil))
		end),
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
			scope:New("Frame")({
				Name = "Bar",
				LayoutOrder = 1,
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(use(barWidth), Theme.Size.MinTouch)
				end),
				BackgroundColor3 = Theme.Iron.Surface,
				BackgroundTransparency = Theme.HudAlpha,
				Visible = scope:Computed(function(use): boolean
					return use(target) ~= nil
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						Color = Theme.Brass.Line,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					scope:New("TextButton")({
						Name = "Open",
						Size = UDim2.new(1, -Theme.Size.MinTouch - 4, 1, 0),
						BackgroundTransparency = 1,
						Text = text,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Brass.Bright,
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
						Size = UDim2.fromOffset(Theme.Size.MinTouch, Theme.Size.MinTouch),
						BackgroundTransparency = 1,
						Text = "✕",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Iron.Text,
						[OnEvent("Activated")] = props.StopGuide,
					}),
				},
			}),
			scope:New("TextLabel")({
				Name = "Debug",
				LayoutOrder = 2,
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(use(barWidth), 0)
				end),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Iron.Sunken,
				BackgroundTransparency = Theme.HudAlpha,
				Visible = scope:Computed(function(use): boolean
					return use(NavTarget.Debug) ~= nil
				end),
				Text = scope:Computed(function(use): string
					return use(NavTarget.Debug) or ""
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Danger,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
end

return NavBar
