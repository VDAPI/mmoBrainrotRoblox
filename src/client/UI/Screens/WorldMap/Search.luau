--!strict
-- Search box of the world map (S25): a text field over the map list ("Search…", the system keyboard on touch)
-- and up to 12 results from Logic/MapSearch under it; a click (or Enter for the first result) hands the result
-- to the window, which switches the map, zooms to the thing and opens its card. The index is built once per
-- language; gathering nodes come from the map sketches the client already has.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GatherNodes = require(ReplicatedStorage.Shared.Data.GatherNodes)
local MapSearch = require(ReplicatedStorage.Shared.Logic.MapSearch)
local MapSketch = require(script.Parent.Parent.Parent.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent, OnChange = Fusion.Children, Fusion.OnEvent, Fusion.OnChange

type Scope = Fusion.Scope<typeof(Fusion)>

local Search = {}

local KIND_ICONS: { [string]: string } = {
	npc = "☺",
	map = "⌖",
	cave = "⛰",
	area = "⚔",
	monster = "☗",
	boss = "☠",
	node = "●",
}

local indexes: { [string]: MapSearch.Index } = {}

-- One entry per gathering node kind and map (its first node), from the sketches already published.
local function nodeEntries(): { MapSearch.Entry }
	local out: { MapSearch.Entry } = {}
	local ids = {}
	for id in Maps.byId do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, mapId in ids do
		local sketch = if MapSketch.isBuilt(mapId) then MapSketch.get(mapId) else nil
		local seen: { [string]: boolean } = {}
		for _, icon in (if sketch then sketch.icons else {}) :: { MapSketch.Icon } do
			local kind = if icon.t == "node" and icon.id then GatherNodes.get(icon.id) else nil
			if kind and not seen[kind.id] then
				seen[kind.id] = true
				table.insert(out, {
					kind = "node",
					id = kind.id,
					map = mapId,
					x = icon.x,
					z = icon.z,
					labelKey = kind.nameKey,
					texts = { Text.now(kind.nameKey) },
				})
			end
		end
	end
	return out
end

function Search.index(): MapSearch.Index
	local lang = Fusion.peek(Text.Lang)
	local existing = indexes[lang]
	if existing then
		return existing
	end
	local started = os.clock()
	local index = MapSearch.build(function(key: string): string
		return Text.now(key)
	end, nodeEntries())
	indexes[lang] = index
	print(
		`[WorldMap] search index ({lang}): {#index.entries} entries in {math.floor((os.clock() - started) * 1000)} ms`
	)
	return index
end

function Search.clearCache()
	table.clear(indexes)
end

export type Props = {
	OnPick: (result: MapSearch.Result) -> (),
	Touch: Fusion.Value<boolean>,
}

export type Api = { box: Instance, results: Instance, active: Fusion.Computed<boolean> }

function Search.new(scope: Scope, props: Props): Api
	local query = scope:Value("")
	local results = scope:Computed(function(use): { MapSearch.Result }
		local text = use(query)
		use(Text.Lang)
		if string.match(text, "^%s*$") then
			return {}
		end
		return MapSearch.search(Search.index(), text)
	end)
	local active = scope:Computed(function(use): boolean
		return not string.match(use(query), "^%s*$")
	end)
	local box: TextBox

	local function pick(result: MapSearch.Result?)
		if not result then
			return
		end
		props.OnPick(result)
	end

	local field = scope:New("Frame")({
		Name = "Search",
		Size = UDim2.new(1, -8, 0, 40),
		BackgroundColor3 = Theme.Colors.Background,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim }),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(20, 40),
				BackgroundTransparency = 1,
				Text = "⌕",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 20,
				TextColor3 = Theme.Colors.Gold,
			}),
			(function(): TextBox
				box = scope:New("TextBox")({
					Name = "Query",
					Position = UDim2.fromOffset(32, 0),
					Size = UDim2.new(1, -72, 1, 0),
					BackgroundTransparency = 1,
					ClearTextOnFocus = false,
					Text = "",
					PlaceholderText = Text.T(scope, "worldmap.search.placeholder"),
					PlaceholderColor3 = Theme.Colors.TextMuted,
					FontFace = Theme.Fonts.Body,
					TextSize = 16,
					TextColor3 = Theme.Colors.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					[OnChange("Text")] = function(value: string)
						if #value > 40 then
							box.Text = string.sub(value, 1, 40)
							return
						end
						query:set(value)
					end,
					[OnEvent("FocusLost")] = function(enterPressed: boolean)
						if enterPressed then
							pick(Fusion.peek(results)[1])
						end
					end,
				}) :: TextBox
				return box
			end)(),
			scope:New("TextButton")({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -2, 0.5, 0),
				Size = UDim2.fromOffset(36, 36),
				BackgroundTransparency = 1,
				Visible = active,
				Text = "✕",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 16,
				TextColor3 = Theme.Colors.TextMuted,
				[OnEvent("Activated")] = function()
					box.Text = ""
					query:set("")
				end,
			}),
		},
	})

	local list = scope:New("ScrollingFrame")({
		Name = "Results",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ZIndex = 5,
		Visible = active,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Colors.GoldDim,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
			scope:New("TextLabel")({
				LayoutOrder = 0,
				Size = UDim2.new(1, -8, 0, 30),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(active) and #use(results) == 0
				end),
				Text = Text.T(scope, "worldmap.search.none"),
				FontFace = Theme.Fonts.Body,
				TextSize = 14,
				TextColor3 = Theme.Colors.TextMuted,
				ZIndex = 6,
			}),
			scope:ForValues(results, function(use, s: Scope, result: MapSearch.Result): Instance
				local map = Maps.get(result.map)
				return s:New("TextButton")({
					Size = s:Computed(function(inner): UDim2
						return UDim2.new(1, -8, 0, if inner(props.Touch) then 48 else 40)
					end),
					BackgroundColor3 = Theme.Colors.PanelRaised,
					AutoButtonColor = true,
					Text = "",
					ZIndex = 6,
					[OnEvent("Activated")] = function()
						pick(result)
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(6, 0),
							Size = UDim2.new(0, 24, 1, 0),
							BackgroundTransparency = 1,
							Text = KIND_ICONS[result.kind] or "•",
							FontFace = Theme.Fonts.BodyBold,
							TextSize = 18,
							TextColor3 = Theme.Colors.Gold,
							ZIndex = 7,
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(34, 3),
							Size = UDim2.new(1, -38, 0.55, 0),
							BackgroundTransparency = 1,
							Text = Text.get(use, result.labelKey),
							FontFace = Theme.Fonts.BodyBold,
							TextSize = 15,
							TextColor3 = Theme.Colors.Parchment,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							ZIndex = 7,
						}),
						s:New("TextLabel")({
							Position = UDim2.new(0, 34, 0.55, 0),
							Size = UDim2.new(1, -38, 0.4, 0),
							BackgroundTransparency = 1,
							Text = `{Text.get(use, `worldmap.search.kind.{result.kind}`)} · {if map
								then Text.get(use, map.nameKey)
								else result.map}`,
							FontFace = Theme.Fonts.Body,
							TextSize = 12,
							TextColor3 = Theme.Colors.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							ZIndex = 7,
						}),
					},
				})
			end) :: any,
		},
	})

	return { box = field, results = list, active = active }
end

return Search
