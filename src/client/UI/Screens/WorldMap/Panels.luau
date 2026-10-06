--!strict
-- Side panels of the world map window: the map list (S22: region -> map -> caves in the band colour of the
-- player's level, the PvP zone as a dot, the areas of the selected map under it), the band legend with
-- "Show only recommended" (S22), the service chips (S25: highlight NPCs with a service) and the bottom bar
-- (layer toggles, zoom, "Centre on me").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local Panels = {}

local ZONE_COLORS = {
	green = Theme.Colors.ZoneGreen,
	yellow = Theme.Colors.ZoneYellow,
	red = Theme.Colors.ZoneRed,
}

local REGIONS = {
	{ "city" },
	{ "meadows", "meadows_hideout", "meadows_burrow", "meadows_cave" },
	{ "duskwood", "duskwood_den", "duskwood_barrow", "duskwood_cave" },
	{ "ashen", "ashen_mine", "ashen_lair", "ashen_cave" },
	{ "frostpeak", "frostpeak_grotto", "frostpeak_hold", "frostpeak_cave" },
}

-- Service chips (S25): label key -> services that match.
Panels.CHIPS = {
	{ key = "worldmap.chip.shops", icon = "⚖", services = { "shop" } },
	{ key = "worldmap.chip.smith", icon = "⚒", services = { "blacksmith" } },
	{ key = "worldmap.chip.alchemy", icon = "⚗", services = { "alchemy" } },
	{ key = "worldmap.chip.quests", icon = "❗", services = { "story", "quests" } },
	{ key = "worldmap.chip.bank", icon = "⛃", services = { "deposit", "mail", "auction" } },
} :: { { key: string, icon: string, services: { string } } }

-- Services matched by the chips that are on.
function Panels.servicesOf(on: { [string]: boolean }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, chip in Panels.CHIPS do
		if on[chip.key] then
			for _, service in chip.services do
				set[service] = true
			end
		end
	end
	return set
end

export type ListProps = {
	Selected: Fusion.Value<string>,
	MapId: Fusion.UsedAs<string?>,
	Level: Fusion.UsedAs<number?>,
	Highlight: Fusion.UsedAs<string?>,
	OnArea: (area: Areas.Area) -> (),
}

-- Rows of the map list.
function Panels.mapList(scope: Scope, props: ListProps): { Instance }
	local rows = {}
	local order = 0
	for _, region in REGIONS do
		for i, id in region do
			local map = Maps.get(id)
			if map then
				order += 1
				local zoneHex = (ZONE_COLORS[map.zone] or Theme.Colors.Text):ToHex()
				table.insert(
					rows,
					scope:New("TextButton")({
						LayoutOrder = order,
						Size = UDim2.new(1, -8, 0, if i == 1 then 34 else 28),
						AutoButtonColor = false,
						BackgroundColor3 = scope:Computed(function(use): Color3
							return if use(props.Selected) == id
								then Theme.Colors.PanelHover
								else Theme.Colors.PanelRaised
						end),
						BackgroundTransparency = if i == 1 then 0.1 else 0.4,
						RichText = true,
						Text = scope:Computed(function(use): string
							local here = if use(props.MapId) == id then " ▲" else ""
							local levels = if id == "city" then "" else ` · {map.minLevel}–{map.maxLevel}`
							local indent = if i == 1 then "" else "   "
							return `{indent}<font color="#{zoneHex}">●</font> {Text.get(use, map.nameKey)}{levels}{here}`
						end),
						FontFace = if i == 1 then Theme.Fonts.BodyBold else Theme.Fonts.Body,
						TextSize = if i == 1 then 16 else 14,
						TextColor3 = scope:Computed(function(use): Color3
							if id == "city" then
								return Theme.Colors.Parchment
							end
							local range = { lv = { map.minLevel, map.maxLevel } } :: any
							return Color3.fromHex(LevelBand.COLORS[AreaAdvice.bandOf(range, use(props.Level) or 1)])
						end),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						[OnEvent("Activated")] = function()
							props.Selected:set(id)
						end,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
						},
					})
				)
				for _, area in AreaAdvice.sorted(id) do
					order += 1
					table.insert(
						rows,
						scope:New("TextButton")({
							LayoutOrder = order,
							Visible = scope:Computed(function(use): boolean
								return use(props.Selected) == id
							end),
							Size = UDim2.new(1, -8, 0, 24),
							AutoButtonColor = false,
							BackgroundColor3 = scope:Computed(function(use): Color3
								return if use(props.Highlight) == area.id
									then Theme.Colors.PanelHover
									else Theme.Colors.Panel
							end),
							BackgroundTransparency = 0.2,
							Text = scope:Computed(function(use): string
								local star = if AreaAdvice.isRecommended(area, use(props.Level) or 1)
									then "★ "
									else ""
								return `      {star}{Text.get(use, area.nameKey)} · {area.lv[1]}–{area.lv[2]}`
							end),
							FontFace = Theme.Fonts.Body,
							TextSize = 13,
							TextColor3 = scope:Computed(function(use): Color3
								return Color3.fromHex(LevelBand.COLORS[AreaAdvice.bandOf(area, use(props.Level) or 1)])
							end),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							[OnEvent("Activated")] = function()
								props.OnArea(area)
							end,
							[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						})
					)
				end
			end
		end
	end
	return rows
end

export type BandProps = {
	Position: UDim2,
	Selected: Fusion.UsedAs<string>,
	Level: Fusion.UsedAs<number?>,
	OnlyRecommended: Fusion.Value<boolean>,
}

-- Band legend (S22): your level, the five bands, "Show only recommended". Only on maps with areas.
function Panels.bands(scope: Scope, props: BandProps): Instance
	local rows = {}
	for i, band in { "grey", "green", "white", "yellow", "red" } do
		table.insert(
			rows,
			scope:New("Frame")({
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				ZIndex = 21,
				[Children] = {
					scope:New("Frame")({
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromOffset(12, 12),
						BackgroundColor3 = Color3.fromHex((LevelBand.COLORS :: any)[band]),
						ZIndex = 22,
						[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(18, 0),
						Size = UDim2.new(1, -18, 1, 0),
						BackgroundTransparency = 1,
						Text = Text.T(scope, `worldmap.band.{band}`),
						FontFace = Theme.Fonts.Body,
						TextSize = 12,
						TextColor3 = Theme.Colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 22,
					}),
				},
			})
		)
	end
	local onlyRecommended = props.OnlyRecommended
	return scope:New("Frame")({
		Name = "Bands",
		Position = props.Position,
		Size = UDim2.fromOffset(196, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.12,
		ZIndex = 20,
		Visible = scope:Computed(function(use): boolean
			return Areas.byMap[use(props.Selected)] ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
			scope:New("TextLabel")({
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return Text.get(use, "worldmap.yourLevel", { level = use(props.Level) or 1 })
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 14,
				TextColor3 = Theme.Colors.GoldBright,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 21,
			}),
			rows :: any,
			scope:New("TextButton")({
				LayoutOrder = 9,
				Size = UDim2.new(1, 0, 0, 28),
				AutoButtonColor = false,
				BackgroundColor3 = scope:Computed(function(use): Color3
					return if use(onlyRecommended) then Theme.Colors.PanelHover else Theme.Colors.PanelRaised
				end),
				Text = scope:Computed(function(use): string
					return `{if use(onlyRecommended) then "☑" else "☐"} {Text.get(use, "worldmap.onlyRecommended")}`
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = 13,
				TextColor3 = Theme.Colors.Parchment,
				ZIndex = 21,
				[OnEvent("Activated")] = function()
					onlyRecommended:set(not Fusion.peek(onlyRecommended))
				end,
				[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			}),
		},
	})
end

export type ChipProps = {
	Position: UDim2,
	RightGap: number, -- space kept free on the right (the card) on desktop
	Selected: Fusion.UsedAs<string>,
	Chips: Fusion.Value<{ [string]: boolean }>,
	Touch: Fusion.UsedAs<boolean>,
}

-- Service chips (S25): on maps with NPCs (the city), several can be on at once.
function Panels.chips(scope: Scope, props: ChipProps): Instance
	local buttons: { Instance } = {}
	for i, chip in Panels.CHIPS do
		local on = scope:Computed(function(use): boolean
			return use(props.Chips)[chip.key] == true
		end)
		table.insert(
			buttons,
			scope:New("TextButton")({
				LayoutOrder = i,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(0, if use(props.Touch) then 44 else 30)
				end),
				AutoButtonColor = false,
				BackgroundColor3 = scope:Computed(function(use): Color3
					return if use(on) then Theme.Colors.Accent else Theme.Colors.Panel
				end),
				BackgroundTransparency = 0.08,
				Text = scope:Computed(function(use): string
					return `{chip.icon} {Text.get(use, chip.key)}`
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 14,
				TextColor3 = Theme.Colors.Parchment,
				ZIndex = 21,
				[OnEvent("Activated")] = function()
					local next: { [string]: boolean } = table.clone(Fusion.peek(props.Chips))
					if next[chip.key] then
						next[chip.key] = nil
					else
						next[chip.key] = true
					end
					props.Chips:set(next)
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 15) }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
					scope:New("UIStroke")({
						Color = Theme.Colors.GoldDim,
						Transparency = scope:Computed(function(use): number
							return if use(on) then 0 else 0.5
						end),
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				},
			})
		)
	end
	return scope:New("Frame")({
		Name = "Chips",
		Position = props.Position,
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(1, -(props.Position.X.Offset + (if use(props.Touch) then 20 else props.RightGap)), 0, 0)
		end),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 20,
		Visible = scope:Computed(function(use): boolean
			local selected = use(props.Selected)
			local count = 0
			for _, npc in Npcs.list do
				if npc.map == selected and not npc.decoration then
					count += 1
				end
			end
			return count >= 3 and Areas.byMap[selected] == nil
		end),
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Wraps = true,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			buttons :: any,
		},
	})
end

export type BarProps = {
	Position: UDim2,
	Size: UDim2,
	Toggles: { [string]: Fusion.Value<boolean> },
	ZoomBy: (delta: number) -> (),
	CentreOnMe: () -> (),
}

-- Bottom bar: layer toggles, zoom buttons, "Centre on me".
function Panels.bar(scope: Scope, props: BarProps): Instance
	local function toggleButton(order: number, key: string, value: Fusion.Value<boolean>): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = UDim2.fromOffset(104, 34),
			AutoButtonColor = false,
			BackgroundColor3 = scope:Computed(function(use): Color3
				return if use(value) then Theme.Colors.PanelHover else Theme.Colors.Panel
			end),
			Text = scope:Computed(function(use): string
				return `{if use(value) then "☑" else "☐"} {Text.get(use, key)}`
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = 14,
			TextColor3 = Theme.Colors.Parchment,
			[OnEvent("Activated")] = function()
				value:set(not Fusion.peek(value))
			end,
			[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		})
	end
	local function smallButton(order: number, text: Fusion.UsedAs<string>, onClick: () -> ()): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = UDim2.fromOffset(if type(text) == "string" and #text <= 3 then 34 else 140, 34),
			BackgroundColor3 = Theme.Colors.PanelRaised,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = 15,
			TextColor3 = Theme.Colors.Parchment,
			[OnEvent("Activated")] = onClick,
			[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		})
	end
	local toggles = props.Toggles
	return scope:New("Frame")({
		Name = "Legend",
		AnchorPoint = Vector2.new(0, 1),
		Position = props.Position,
		Size = props.Size,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
			}),
			toggleButton(1, "worldmap.layer.areas", toggles.areas),
			toggleButton(2, "worldmap.layer.icons", toggles.icons),
			toggleButton(3, "worldmap.layer.npcs", toggles.npcs),
			toggleButton(4, "worldmap.layer.nodes", toggles.nodes),
			toggleButton(5, "worldmap.layer.quest", toggles.quest),
			smallButton(6, "+", function()
				props.ZoomBy(1)
			end),
			smallButton(7, "−", function()
				props.ZoomBy(-1)
			end),
			smallButton(8, Text.T(scope, "worldmap.center"), props.CentreOnMe),
		},
	})
end

return Panels
