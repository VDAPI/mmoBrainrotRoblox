--!strict
-- Side panels of the world map window: the map list (S22: region -> map -> caves in the band colour of the
-- player's level, the PvP zone as a dot, the areas of the selected map under it), the band legend with
-- "Show only recommended" (S22), the filter panel (owner 2026-10-20 "Mapa": one chip per symbol category with its
-- symbol and count, All / None, collapsible; it replaced the S25 service chips and the layer toggles) and the bottom
-- bar (zoom, "Centre on me"). S101: the world event's glyph after its map and its hunting ground.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local AreaProfileText = require(script.Parent.Parent.Parent.AreaProfileText)
local AreaProfiles = require(ReplicatedStorage.Shared.Data.AreaProfiles)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Canvas = require(script.Parent.Canvas)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local MapMarkers = require(ReplicatedStorage.Shared.Logic.MapMarkers)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)
local WorldBoss = require(ReplicatedStorage.Shared.Logic.WorldBoss)
local WorldEvents = require(ReplicatedStorage.Shared.Logic.WorldEvents)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local Panels = {}

local ZONE_COLORS = {
	green = Theme.Paper.Success,
	yellow = Theme.Paper.Warning,
	red = Theme.Paper.Danger,
}

local REGIONS = {
	{ "city" },
	{ "meadows", "meadows_hideout", "meadows_burrow", "meadows_cave" },
	{ "duskwood", "duskwood_den", "duskwood_barrow", "duskwood_cave" },
	{ "ashen", "ashen_mine", "ashen_lair", "ashen_cave" },
	{ "frostpeak", "frostpeak_grotto", "frostpeak_hold", "frostpeak_cave" },
}

export type ListProps = {
	Selected: Fusion.Value<string>,
	MapId: Fusion.UsedAs<string?>,
	Level: Fusion.UsedAs<number?>,
	Highlight: Fusion.UsedAs<string?>,
	OnArea: (area: Areas.Area) -> (),
}

-- S101: the world event glyph (rich text) when the event is on `mapId` (and on `areaId`, when given).
local function eventGlyph(event: any, mapId: string, areaId: string?): string
	if type(event) ~= "table" or event.map ~= mapId or (areaId ~= nil and event.area ~= areaId) then
		return ""
	end
	local def = WorldEvents.kindOf(event.kind)
	return if def then ` <font color="{def.color}">{def.glyph}</font>` else ""
end

-- S149b: the world boss's crown (rich text) on its map's row while it wakes, fights or has just fallen.
local function bossGlyph(branch: any, mapId: string): string
	if type(branch) ~= "table" or branch.map ~= mapId then
		return ""
	end
	local marker = WorldBoss.markerOf(branch, 0)
	if not WorldBoss.markerLive(marker) then
		return ""
	end
	return ` <font color="{UiPalette.map.worldBoss}">♛</font>`
end

-- Rows of the map list.
function Panels.mapList(scope: Scope, props: ListProps): { Instance }
	local worldEvent = State.Value({ "worldEvent" })
	local worldBoss = State.Value({ "worldBoss" }) -- S149b
	local rows = {}
	local order = 0
	for _, region in REGIONS do
		for i, id in region do
			local map = Maps.get(id)
			if map then
				order += 1
				local zoneHex = (ZONE_COLORS[map.zone] or Theme.Paper.Text):ToHex()
				table.insert(
					rows,
					scope:New("TextButton")({
						LayoutOrder = order,
						Size = UDim2.new(1, -8, 0, if i == 1 then 34 else 28),
						AutoButtonColor = false,
						BackgroundColor3 = scope:Computed(function(use): Color3
							return if use(props.Selected) == id then Theme.Paper.Hover else Theme.Paper.Raised
						end),
						BackgroundTransparency = if i == 1 then 0.1 else 0.4,
						RichText = true,
						Text = scope:Computed(function(use): string
							local here = if use(props.MapId) == id then " ▲" else ""
							local levels = if id == "city" then "" else ` · {map.minLevel}–{map.maxLevel}`
							local indent = if i == 1 then "" else "   "
							local event = eventGlyph(use(worldEvent), id) .. bossGlyph(use(worldBoss), id)
							return `{indent}<font color="#{zoneHex}">●</font> {Text.get(use, map.nameKey)}{levels}{here}{event}`
						end),
						FontFace = if i == 1 then Theme.Fonts.BodyBold else Theme.Fonts.Body,
						TextSize = if i == 1 then Theme.TextSize.Body else Theme.TextSize.Small,
						TextColor3 = scope:Computed(function(use): Color3
							if id == "city" then
								return Theme.Paper.Text
							end
							local range = { lv = { map.minLevel, map.maxLevel } } :: any
							return Theme.readable(
								LevelBand.COLORS[AreaAdvice.bandOf(range, use(props.Level) or 1)],
								"paper"
							)
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
									then Theme.Paper.Hover
									else Theme.Paper.Surface
							end),
							BackgroundTransparency = 0.2,
							RichText = true, -- S33: the profile icon in its colour
							Text = scope:Computed(function(use): string
								local star = if AreaAdvice.isRecommended(area, use(props.Level) or 1)
									then "★ "
									else ""
								local name = AreaProfileText.escape(Text.get(use, area.nameKey))
								return `      {star}{name} · {area.lv[1]}–{area.lv[2]}`
									.. AreaProfileText.iconRich(area.profile, " ")
									.. eventGlyph(use(worldEvent), id, area.id)
							end),
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = scope:Computed(function(use): Color3
								return Theme.readable(
									LevelBand.COLORS[AreaAdvice.bandOf(area, use(props.Level) or 1)],
									"paper"
								)
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
	ShowProfiles: Fusion.Value<boolean>, -- S33
}

-- Band legend (S22): your level, the five bands, "Show only recommended". Only on maps with areas.
-- S33: the three hunting ground profiles (icon, name) and a switch for their icons on the map.
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
						BackgroundColor3 = Theme.tint((LevelBand.COLORS :: any)[band]),
						ZIndex = 22,
						[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(18, 0),
						Size = UDim2.new(1, -18, 1, 0),
						BackgroundTransparency = 1,
						Text = Text.T(scope, `worldmap.band.{band}`),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 22,
					}),
				},
			})
		)
	end
	local onlyRecommended = props.OnlyRecommended
	local showProfiles = props.ShowProfiles
	for i, id in AreaProfiles.order do
		local profile = AreaProfiles.get(id) :: AreaProfiles.Profile
		table.insert(
			rows,
			scope:New("TextLabel")({
				LayoutOrder = 5 + i,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Visible = showProfiles,
				Text = scope:Computed(function(use): string
					return AreaProfileText.tag(use, profile)
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = AreaProfileText.color(profile),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 22,
			})
		)
	end
	table.insert(
		rows,
		scope:New("TextButton")({
			LayoutOrder = 10,
			Size = UDim2.new(1, 0, 0, 28),
			AutoButtonColor = false,
			BackgroundColor3 = scope:Computed(function(use): Color3
				return if use(showProfiles) then Theme.Paper.Hover else Theme.Paper.Raised
			end),
			Text = scope:Computed(function(use): string
				return `{if use(showProfiles) then "☑" else "☐"} {Text.get(use, "worldmap.showProfiles")}`
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Paper.Text,
			ZIndex = 21,
			[OnEvent("Activated")] = function()
				showProfiles:set(not Fusion.peek(showProfiles))
			end,
			[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		})
	)
	return scope:New("Frame")({
		Name = "Bands",
		Position = props.Position,
		Size = UDim2.fromOffset(196, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Paper.Surface,
		BackgroundTransparency = 0.12,
		ZIndex = 20,
		Visible = scope:Computed(function(use): boolean
			return Areas.byMap[use(props.Selected)] ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Paper.Rule }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
			scope:New("TextLabel")({
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return Text.get(use, "worldmap.yourLevel", { level = use(props.Level) or 1 })
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 21,
			}),
			rows :: any,
			scope:New("TextButton")({
				LayoutOrder = 9,
				Size = UDim2.new(1, 0, 0, 28),
				AutoButtonColor = false,
				BackgroundColor3 = scope:Computed(function(use): Color3
					return if use(onlyRecommended) then Theme.Paper.Hover else Theme.Paper.Raised
				end),
				Text = scope:Computed(function(use): string
					return `{if use(onlyRecommended) then "☑" else "☐"} {Text.get(use, "worldmap.onlyRecommended")}`
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Text,
				ZIndex = 21,
				[OnEvent("Activated")] = function()
					onlyRecommended:set(not Fusion.peek(onlyRecommended))
				end,
				[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			}),
		},
	})
end

export type FilterProps = {
	Position: UDim2,
	RightGap: number, -- space kept free on the right (the card) on desktop
	Hidden: Fusion.Value<{ [string]: boolean }>, -- hidden categories (Logic/MapMarkers)
	Counts: Fusion.UsedAs<{ [string]: number }>, -- symbols per category on the shown map
	Open: Fusion.Value<boolean>,
	Touch: Fusion.UsedAs<boolean>,
}

-- Owner 2026-10-20 "Mapa": the filter panel over the lower left of the map. A header (☰ Filters, how many categories
-- show, All, None) and, while open, one chip per category present on the shown map: its symbol (the map's shape and
-- colour), name and count; a tap hides or shows the category. Collapsible (closed by default on touch); the hidden
-- set is saved on the account by the window.
function Panels.filters(scope: Scope, props: FilterProps): Instance
	local function height(use: Fusion.Use): number
		return if use(props.Touch) then Theme.Size.MinTouch else 34
	end
	local function textSize(use: Fusion.Use): number
		return if use(props.Touch) then Theme.TextSize.Body else Theme.TextSize.Small
	end
	local present = scope:Computed(function(use): { string }
		local counts = use(props.Counts)
		local out = {}
		for _, category in MapMarkers.CATEGORIES do
			if (counts[category.id] or 0) > 0 then
				table.insert(out, category.id)
			end
		end
		return out
	end)
	local function headerButton(
		order: number,
		text: Fusion.UsedAs<string>,
		onClick: () -> (),
		visible: Fusion.UsedAs<boolean>
	): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Visible = visible,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = scope:Computed(function(use): UDim2
				return UDim2.fromOffset(0, height(use))
			end),
			AutoButtonColor = true,
			BackgroundColor3 = Theme.Paper.Raised,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = scope:Computed(textSize),
			TextColor3 = Theme.Paper.Text,
			ZIndex = 21,
			[OnEvent("Activated")] = onClick,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
				scope:New("UIStroke")({ Color = Theme.Paper.Rule, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			},
		})
	end
	local chips: { Instance } = {}
	for i, category in MapMarkers.CATEGORIES do
		local color = Canvas.categoryColor(category.id)
		local on = scope:Computed(function(use): boolean
			return not use(props.Hidden)[category.id]
		end)
		table.insert(
			chips,
			scope:New("TextButton")({
				Name = category.id,
				LayoutOrder = i,
				Visible = scope:Computed(function(use): boolean
					return (use(props.Counts)[category.id] or 0) > 0
				end),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(0, height(use))
				end),
				AutoButtonColor = false,
				BackgroundColor3 = scope:Computed(function(use): Color3
					return if use(on) then Theme.Paper.Raised else Theme.Paper.Sunken
				end),
				BackgroundTransparency = scope:Computed(function(use): number
					return if use(on) then 0 else 0.35
				end),
				Text = "",
				ZIndex = 21,
				[OnEvent("Activated")] = function()
					props.Hidden:set(MapMarkers.toggle(Fusion.peek(props.Hidden), category.id))
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 12) }),
					scope:New("UIStroke")({
						Color = scope:Computed(function(use): Color3
							return if use(on) then color else Theme.Paper.Rule
						end),
						Thickness = scope:Computed(function(use): number
							return if use(on) then 2 else 1
						end),
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					-- the category's symbol as on the map: a dark plate in its shape with the coloured ring and glyph
					scope:New("Frame")({
						LayoutOrder = 1,
						Size = UDim2.fromOffset(28, 28),
						BackgroundTransparency = 1,
						ZIndex = 22,
						[Children] = {
							scope:New("Frame")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = if category.shape == "diamond"
									then UDim2.fromOffset(20, 20)
									else UDim2.fromOffset(26, 26),
								Rotation = if category.shape == "diamond" then 45 else 0,
								BackgroundColor3 = Theme.tint(UiPalette.map.plate),
								BackgroundTransparency = scope:Computed(function(use): number
									return if use(on) then 0.05 else 0.5
								end),
								ZIndex = 22,
								[Children] = {
									scope:New("UICorner")({
										CornerRadius = if category.shape == "round"
											then UDim.new(0.5, 0)
											else UDim.new(0, 5),
									}),
									scope:New("UIStroke")({
										Color = color,
										Thickness = 2,
										Transparency = scope:Computed(function(use): number
											return if use(on) then 0 else 0.6
										end),
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									}),
								},
							}),
							scope:New("TextLabel")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = category.glyph,
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Caption,
								TextColor3 = color,
								TextTransparency = scope:Computed(function(use): number
									return if use(on) then 0 else 0.6
								end),
								ZIndex = 23,
							}),
						},
					}),
					scope:New("TextLabel")({
						LayoutOrder = 2,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromScale(0, 1),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return `{Text.get(use, `worldmap.cat.{category.id}`)}  {use(props.Counts)[category.id] or 0}`
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = scope:Computed(textSize),
						TextColor3 = scope:Computed(function(use): Color3
							return if use(on) then Theme.Paper.Text else Theme.Paper.TextMuted
						end),
						ZIndex = 22,
					}),
				},
			})
		)
	end
	return scope:New("Frame")({
		Name = "Filters",
		AnchorPoint = Vector2.new(0, 1),
		Position = props.Position,
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(1, -(props.Position.X.Offset + (if use(props.Touch) then 20 else props.RightGap)), 0, 0)
		end),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Paper.Surface,
		BackgroundTransparency = 0.12,
		ZIndex = 20,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Paper.Rule }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			scope:New("Frame")({
				Name = "Header",
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				ZIndex = 21,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Wraps = true,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
					}),
					headerButton(
						1,
						scope:Computed(function(use): string
							local ids = use(present)
							local hidden = use(props.Hidden)
							local shown = 0
							for _, id in ids do
								if not hidden[id] then
									shown += 1
								end
							end
							local arrow = if use(props.Open) then "▾" else "▸"
							return `☰ {Text.get(use, "worldmap.filter.title")} {arrow}   {Text.get(
								use,
								"worldmap.filter.shown",
								{ shown = shown, total = #ids }
							)}`
						end),
						function()
							props.Open:set(not Fusion.peek(props.Open))
						end,
						true
					),
					headerButton(2, Text.T(scope, "worldmap.filter.all"), function()
						props.Hidden:set(MapMarkers.setAll(true))
					end, props.Open),
					headerButton(3, Text.T(scope, "worldmap.filter.none"), function()
						props.Hidden:set(MapMarkers.setAll(false))
					end, props.Open),
				},
			}),
			scope:New("Frame")({
				Name = "Chips",
				LayoutOrder = 2,
				Visible = props.Open,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				ZIndex = 21,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Wraps = true,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					chips :: any,
				},
			}),
		},
	})
end

export type BarProps = {
	Position: UDim2,
	Size: UDim2,
	ZoomBy: (delta: number) -> (),
	CentreOnMe: () -> (),
}

-- Bottom bar: zoom buttons, "Centre on me" (the layer toggles became the filter panel's chips).
function Panels.bar(scope: Scope, props: BarProps): Instance
	local function smallButton(order: number, text: Fusion.UsedAs<string>, onClick: () -> ()): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = UDim2.fromOffset(if type(text) == "string" and #text <= 3 then 34 else 140, 34),
			BackgroundColor3 = Theme.Paper.Raised,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Paper.Text,
			[OnEvent("Activated")] = onClick,
			[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		})
	end
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
