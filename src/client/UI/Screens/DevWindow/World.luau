--!strict
-- Dev panel, "World" tab (S23): teleports (a map, its monster areas at their arrival points, caves, boss
-- dungeons, NPCs, places in the city), game clock and time of day, map tools (rebuild, nodes, detail, map cache,
-- current area).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local NumberInput = require(script.Parent.Parent.Parent.Components.NumberInput)
local Select = require(script.Parent.Parent.Parent.Components.Select)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Town = require(ReplicatedStorage.Shared.Data.Town)

local Dev = require(script.Parent.Dev)

local function World(s: Dev.Scope): Instance
	local mapIds = {}
	for id in Maps.byId do
		table.insert(mapIds, id)
	end
	table.sort(mapIds, function(a, b)
		local ma, mb = Maps.get(a), Maps.get(b)
		if ma and mb and ma.minLevel ~= mb.minLevel then
			return ma.minLevel < mb.minLevel
		end
		return a < b
	end)
	local mapOptions = {}
	for _, id in mapIds do
		local map = Maps.get(id)
		if map then
			table.insert(
				mapOptions,
				{ value = id, label = `{Text.now(map.nameKey)} ({map.minLevel}–{map.maxLevel})` }
			)
		end
	end
	local map = s:Value("meadows" :: string?)
	local seconds = s:Value(3600)
	local hour = s:Value(22)

	local caveOptions = {}
	for _, cave in Areas.caves.list do
		table.insert(
			caveOptions,
			{ value = cave.id, label = `{Text.now(cave.nameKey)} ({cave.levels[1]}–{cave.levels[2]})` }
		)
	end
	local cave = s:Value(nil :: string?)
	local bossOptions = {}
	for _, boss in Bosses.list do
		table.insert(bossOptions, { value = boss.id, label = Text.now(boss.nameKey) })
	end
	local boss = s:Value(nil :: string?)
	local npcOptions = {}
	for _, npc in Npcs.list do
		if not npc.decoration then
			table.insert(npcOptions, { value = npc.id, label = `{Text.now(npc.nameKey)} · {npc.map}` })
		end
	end
	local npc = s:Value(nil :: string?)
	local placeOptions = { { value = "arena", label = "arena" } }
	for _, special in Town.city.specials do
		table.insert(placeOptions, { value = special.id, label = special.id })
	end
	for _, square in Town.city.squares do
		table.insert(placeOptions, { value = square.id, label = square.id })
	end
	local place = s:Value("rynek" :: string?)

	local areaRows = s:Computed(function(use, inner: Dev.Scope): { Instance }
		local id = use(map)
		use(Text.Lang)
		local out = {}
		for i, area in AreaAdvice.sorted(id or "") do
			table.insert(
				out,
				Dev.row(inner, i, `{Text.now(area.nameKey)} · {area.lv[1]}–{area.lv[2]}`, {
					Dev.button(inner, Text.T(inner, "dev.world.go"), function()
						Dev.run("arrive", { id :: string, area.id })
					end, 110),
				})
			)
		end
		return out
	end)

	return Dev.column(s, {
		Dev.header(s, 1, "dev.world.teleport"),
		Dev.row(s, 2, Text.T(s, "dev.world.map"), {
			Select(s, { Options = mapOptions, Selected = map, Width = 260 }),
			Dev.button(s, Text.T(s, "dev.world.go"), function()
				local id = Fusion.peek(map)
				if id then
					Dev.run("tp", { id })
				end
			end, 110),
		}),
		s:New("Frame")({
			LayoutOrder = 3,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Fusion.Children] = {
				s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
				areaRows :: any,
			},
		}),
		Dev.row(s, 4, Text.T(s, "dev.world.cave"), {
			Select(s, { Options = caveOptions, Selected = cave, Width = 260 }),
			Dev.button(s, Text.T(s, "dev.world.go"), function()
				local id = Fusion.peek(cave)
				if id then
					Dev.run("tp", { "cave", id })
				end
			end, 110),
		}),
		Dev.row(s, 5, Text.T(s, "dev.world.boss"), {
			Select(s, { Options = bossOptions, Selected = boss, Width = 260 }),
			Dev.button(s, Text.T(s, "dev.world.go"), function()
				local id = Fusion.peek(boss)
				if id then
					Dev.run("tp", { "boss", id })
				end
			end, 110),
		}),
		Dev.row(s, 6, Text.T(s, "dev.world.npc"), {
			Select(s, { Options = npcOptions, Selected = npc, Width = 260 }),
			Dev.button(s, Text.T(s, "dev.world.go"), function()
				local id = Fusion.peek(npc)
				if id then
					Dev.run("npc", { id })
				end
			end, 110),
		}),
		Dev.row(s, 7, Text.T(s, "dev.world.city"), {
			Select(s, { Options = placeOptions, Selected = place, Width = 260 }),
			Dev.button(s, Text.T(s, "dev.world.go"), function()
				Dev.run("town", { "tp", Fusion.peek(place) or "rynek" })
			end, 110),
		}),
		Dev.header(s, 8, "dev.world.time"),
		Dev.row(s, 9, Text.T(s, "dev.world.clock"), {
			NumberInput(s, { Value = seconds, Min = 1, Max = 86400 * 30, Step = 600 }),
			Dev.button(s, Text.T(s, "dev.world.shift"), function()
				Dev.run("time", { `+{Fusion.peek(seconds)}` })
			end, 130),
		}),
		Dev.row(s, 10, Text.T(s, "dev.world.daytime"), {
			NumberInput(s, { Value = hour, Min = 0, Max = 24 }),
			Dev.button(s, Text.T(s, "dev.set"), function()
				Dev.run("daytime", { tostring(Fusion.peek(hour)) })
			end),
			Dev.button(s, "auto", function()
				Dev.run("daytime", { "auto" })
			end, 80),
		}),
		Dev.header(s, 11, "dev.world.tools"),
		Dev.row(s, 12, nil, {
			Dev.button(s, Text.T(s, "dev.world.rebuild"), function()
				local id = Fusion.peek(map)
				if id then
					Dev.run("rebuild", { id })
				end
			end, 170, true),
			Dev.button(s, Text.T(s, "dev.world.nodes"), function()
				Dev.run("nodes", { "respawn" })
			end, 170),
			Dev.button(s, Text.T(s, "dev.world.mapcache"), function()
				Dev.run("mapcache", { "clear" })
			end, 170),
			Dev.button(s, Text.T(s, "dev.world.area"), function()
				Dev.run("area")
			end, 120),
		}),
		Dev.row(s, 13, Text.T(s, "dev.world.detail"), {
			Dev.button(s, "low", function()
				Dev.run("decor", { "low" })
			end, 80),
			Dev.button(s, "mid", function()
				Dev.run("decor", { "mid" })
			end, 80),
			Dev.button(s, "high", function()
				Dev.run("decor", { "high" })
			end, 80),
		}),
		s:New("TextLabel")({
			LayoutOrder = 14,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = Text.T(s, "dev.world.rebuildNote"),
			FontFace = Theme.Fonts.Body,
			TextSize = 13,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Dev.header(s, 15, "dev.allCommands"),
		Dev.commandRows(s, 16, { "world" }) :: any,
	})
end

return World
