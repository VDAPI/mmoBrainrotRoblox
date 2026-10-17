--!strict
-- Blood Moon window (S129, DESIGN-17 §7): the state (running / next start in UTC / ended), the top 10 of each region
-- with the player's own line, where the ranking comes from (every server, or this server only without MemoryStore:
-- never an unexplained empty list) and the rules and rewards with the numbers of Data/ScheduledEvents. One scrolling
-- column on PC and phone (region tabs, rows 40 / 44 px). Opened from the HUD menu (from 10 min before the start until
-- the results go), the HUD panel and the game menu; no key (DECYZJE S129).
-- Reads UI/BloodMoonView, `bloodMoonBoard`, `character.bloodMoon` and `zone.map` only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BloodMoon = require(ReplicatedStorage.Shared.Logic.BloodMoon)
local BloodMoonView = require(script.Parent.Parent.BloodMoonView)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local ScheduledEvents = require(ReplicatedStorage.Shared.Data.ScheduledEvents)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)

local Children = Fusion.Children
local peek = Fusion.peek

type Scope = Fusion.Scope<typeof(Fusion)>

local BLOOD = Theme.Paper.Danger -- S136: the Blood Moon red as text on parchment
local RULES = ScheduledEvents.bloodMoon
local REWARD = RULES.reward

local function line(
	scope: Scope,
	order: number,
	text: Fusion.UsedAs<string>,
	color: Fusion.UsedAs<Color3>?,
	size: number?,
	font: Font?
): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		TextColor3 = color or Theme.Paper.Text,
		TextSize = size or Theme.TextSize.Small,
		FontFace = font or Theme.Fonts.Body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function cell(s: Scope, text: string, width: number, color: Color3?, align: Enum.TextXAlignment?): Instance
	return s:New("TextLabel")({
		BackgroundTransparency = 1,
		Size = if width > 0 then UDim2.new(0, width, 1, 0) else UDim2.new(1, -400, 1, 0),
		Text = text,
		TextColor3 = color or Theme.Paper.Text,
		TextSize = Theme.TextSize.Small,
		FontFace = Theme.Fonts.Body,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local function BloodMoonWindow(scope: Scope): Fusion.Child
	local board = BloodMoonView.Board
	local phase = BloodMoonView.Phase
	local mine = State.Value({ "character", "bloodMoon" })
	local zoneMap = State.Value({ "zone", "map" })
	local touch = Device.Touch

	-- the default tab: the region the player stands in, else the first one with own points, else the first
	local function defaultRegion(): string
		local map = peek(zoneMap)
		local here = if type(map) == "string" then BloodMoon.regionOf(map) else nil
		if here then
			return here
		end
		local state = peek(mine)
		if type(state) == "table" and type(state.regions) == "table" then
			for _, region in RULES.regions do
				if (tonumber(state.regions[region]) or 0) > 0 then
					return region
				end
			end
		end
		return RULES.regions[1]
	end
	local selected = scope:Value(defaultRegion())

	local tabs: { Tabs.Tab } = {}
	for _, region in RULES.regions do
		local def = Maps.get(region)
		table.insert(tabs, { id = region, label = Text.T(scope, if def then def.nameKey else region) })
	end

	local header = scope:Computed(function(use): string
		local p = use(phase)
		local t = use(BloodMoonView.Now)
		if p == "active" then
			local ends = tonumber(use(BloodMoonView.EndsAt)) or t
			return Text.get(use, "bloodmoon.window.active", { time = Time.format(ends - t) })
		end
		if p == "ended" then
			return Text.get(use, "bloodmoon.window.ended")
		end
		local starts = tonumber(use(BloodMoonView.Next)) or 0
		if starts <= 0 then
			return Text.get(use, "bloodmoon.desc")
		end
		local weekday, clock = BloodMoon.when(starts)
		local d, h, m = Time.split(starts - t)
		local countdown = if d > 0
			then Text.get(use, "arena.time.dh", { d = d, h = h })
			elseif h > 0 then Text.get(use, "lure.left.h", { h = h, m = m })
			else Time.format(starts - t)
		return Text.get(
			use,
			"bloodmoon.window.next",
			{ day = Text.get(use, `day.{weekday}`), time = clock, countdown = countdown }
		)
	end)

	local source = scope:Computed(function(use): string
		local b = use(board)
		if type(b) ~= "table" then
			return ""
		end
		if b.global == false then
			return Text.get(use, "bloodmoon.window.localOnly")
		end
		local at = tonumber(b.updatedAt) or 0
		if at <= 0 then
			return ""
		end
		return Text.get(use, "bloodmoon.window.updated", { ago = Time.format(use(BloodMoonView.Now) - at) })
	end)
	local sourceColor = scope:Computed(function(use): Color3
		local b = use(board)
		return if type(b) == "table" and b.global == false then Theme.Paper.Warning else Theme.Paper.TextMuted
	end)

	local rows = scope:Computed(function(use, s: Scope): { any }
		local b = use(board)
		local region = use(selected)
		local small = use(touch)
		local data = if type(b) == "table" and type(b.regions) == "table" then b.regions[region] else nil
		local top = if type(data) == "table" and type(data.top) == "table" then data.top else {}
		local out: { any } = {}
		for i, row in top do
			local class = if type(row.class) == "string" then Classes.get(row.class) else nil
			local mineRow = type(data) == "table" and data.me == row.rank
			table.insert(
				out,
				s:New("Frame")({
					Name = `Row{i}`,
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, if small then 44 else 40),
					BackgroundColor3 = if mineRow then Theme.Paper.Hover else Theme.Paper.Raised,
					BackgroundTransparency = if mineRow then 0.1 else 0.4,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
						s:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 6),
						}),
						cell(s, `#{row.rank}`, 44, if row.rank == 1 then Theme.Paper.Heading else Theme.Paper.Text),
						cell(
							s,
							if class then class.icon else "",
							28,
							if class then Theme.readable(class.color, "paper") else nil,
							Enum.TextXAlignment.Center
						),
						cell(s, tostring(row.name or "?"), 0),
						-- no guild column on phones (width 0 would make it a second flexible cell)
						(if small
							then nil
							else cell(
								s,
								if type(row.guild) == "string" then `[{row.guild}]` else "",
								80,
								Theme.Paper.TextMuted
							)) :: any,
						cell(s, if row.level then `{row.level}` else "", 44, Theme.Paper.TextMuted),
						cell(s, `{row.points}`, 70, BLOOD, Enum.TextXAlignment.Right),
					},
				})
			)
		end
		if #out == 0 then
			table.insert(
				out,
				line(
					s,
					1,
					Text.get(use, if type(b) == "table" then "bloodmoon.window.empty" else "bloodmoon.window.noBoard"),
					Theme.Paper.TextMuted
				)
			)
		end
		return out
	end)

	local you = scope:Computed(function(use): string
		local b = use(board)
		local region = use(selected)
		local data = if type(b) == "table" and type(b.regions) == "table" then b.regions[region] else nil
		if type(data) == "table" and type(data.me) == "number" then
			return Text.get(use, "bloodmoon.window.you", { rank = data.me })
		end
		local state = use(mine)
		local id = if type(b) == "table" then b.id else use(BloodMoonView.Id)
		local points = if type(state) == "table"
				and state.id == id
				and type(state.regions) == "table"
			then tonumber(state.regions[region]) or 0
			else 0
		if points > 0 then
			return Text.get(use, "bloodmoon.window.youOut", { points = points })
		end
		return Text.get(use, "bloodmoon.window.youNone")
	end)

	local titleDef = TitleData.get(REWARD.titleId)
	local frameDef = Cosmetics.get(REWARD.frameId)
	local titleName = if titleDef then Text.T(scope, titleDef.nameKey) else REWARD.titleId
	local frameName = if frameDef then Text.T(scope, frameDef.nameKey) else REWARD.frameId
	local rules: { { key: string, args: { [string]: any } } } = {
		{
			key = "bloodmoon.rules.player",
			args = { n = RULES.points.player, gap = RULES.levelGap, max = RULES.sameVictimMax },
		},
		{ key = "bloodmoon.rules.elite", args = { n = RULES.points.elite } },
		{ key = "bloodmoon.rules.elite2", args = { n = RULES.points.elite2 } },
		{ key = "bloodmoon.rules.death", args = {} },
		{ key = "bloodmoon.rules.participation", args = { min = REWARD.minPoints, tokens = REWARD.tokens } },
		{
			key = "bloodmoon.rules.top100",
			args = {
				n = REWARD.titleTop,
				title = titleName,
				days = REWARD.titleDays,
			},
		},
		{
			key = "bloodmoon.rules.top10",
			args = { n = REWARD.frameTop, frame = frameName },
		},
		{ key = "bloodmoon.rules.top1", args = { shards = REWARD.shards } },
		{ key = "bloodmoon.rules.blocked", args = {} },
	}
	local ruleLines: { Instance } = {}
	for i, rule in rules do
		table.insert(ruleLines, line(scope, 20 + i, Text.T(scope, rule.key, rule.args), Theme.Paper.Text))
	end

	return scope:New("ScrollingFrame")({
		Name = "BloodMoon",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Rule,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
			line(
				scope,
				1,
				scope:Computed(function(use): string
					return `☾ {Text.get(use, "bloodmoon.name")}`
				end),
				BLOOD,
				Theme.TextSize.Large,
				Theme.Fonts.Display
			),
			line(scope, 2, header, Theme.Paper.Heading, Theme.TextSize.Body, Theme.Fonts.BodyBold),
			line(scope, 3, Text.T(scope, "bloodmoon.desc"), Theme.Paper.TextMuted),
			Tabs(scope, {
				Tabs = tabs,
				Selected = selected,
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 44),
				Scroll = true,
			}),
			scope:New("Frame")({
				Name = "Rows",
				LayoutOrder = 5,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
					rows :: any,
				},
			}),
			line(scope, 6, you, Theme.Paper.Text, Theme.TextSize.Small, Theme.Fonts.BodyBold),
			line(scope, 7, source, sourceColor),
			line(scope, 20, Text.T(scope, "bloodmoon.window.rules"), BLOOD, Theme.TextSize.Body, Theme.Fonts.BodyBold),
			ruleLines :: any,
		},
	})
end

return BloodMoonWindow
