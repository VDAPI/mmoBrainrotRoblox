--!strict
-- Quest journal (L): Main / Daily tabs. Main: the active story quest (or the next one and where to get it),
-- the story so far as a list. Daily: today's three contracts with progress and the time to the reset.
-- "Track" toggles the HUD tracker for the main quest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestText = require(script.Parent.Parent.QuestText)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Tracked: Fusion.Value<boolean>,
}

local function label(
	scope: Scope,
	order: number,
	text: Fusion.UsedAs<string>,
	font: Font,
	size: number,
	color: Color3
): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		RichText = true,
		TextWrapped = true,
		Text = text,
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function QuestJournal(scope: Scope, props: Props): Fusion.Child
	local tab = scope:Value("main")
	local quests = State.Value({ "character", "quests" })
	local level = State.Value({ "character", "level" })
	local now = scope:Value(Clock.now())
	local accumulator = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			accumulator += dt
			if accumulator > 1 then
				accumulator = 0
				now:set(Clock.now())
			end
		end)
	)

	local content = scope:Computed(function(use, s: Scope): { Instance }
		local q = use(quests)
		local list = {}
		if type(q) ~= "table" then
			return list
		end
		if use(tab) == "main" then
			local main = q.main
			local quest = if type(main) == "table" then Quests.Main.get(main.id) else nil
			if quest and main then
				table.insert(
					list,
					label(
						s,
						1,
						Text.get(use, `quest.{quest.id}.title`),
						Theme.Fonts.Heading,
						26,
						Theme.Colors.GoldBright
					)
				)
				table.insert(
					list,
					label(s, 2, Text.get(use, `quest.{quest.id}.text`), Theme.Fonts.Body, 17, Theme.Colors.Parchment)
				)
				local lines = {}
				for i, objective in quest.objectives do
					local have = (main.progress or {})[i] or 0
					local text = QuestText.objective(use, objective, have)
					table.insert(
						lines,
						if have >= objective.n then `<font color="#4FD16B">✔ {text}</font>` else `• {text}`
					)
				end
				local turnIn = Npcs.get(quest.turnIn)
				if QuestLogic.isComplete(main.progress or {}, quest.objectives) and turnIn then
					table.insert(
						lines,
						`<font color="#E8C25A">{Text.get(use, "quest.handInAt", {
							npc = Text.get(use, turnIn.nameKey),
						})}</font>`
					)
				end
				table.insert(
					list,
					label(s, 3, table.concat(lines, "\n"), Theme.Fonts.BodyMedium, 17, Theme.Colors.Text)
				)
				table.insert(
					list,
					Button(s, {
						LayoutOrder = 4,
						Size = UDim2.fromOffset(200, 44),
						Text = s:Computed(function(use2): string
							return Text.get(use2, if use2(props.Tracked) then "quest.untrack" else "quest.track")
						end),
						OnClick = function()
							props.Tracked:set(not Fusion.peek(props.Tracked))
						end,
					})
				)
			else
				local nextQuest, ready = QuestLogic.nextMain(q.mainDone or 0, use(level) or 1)
				if nextQuest then
					local giver = Npcs.get(nextQuest.giver)
					table.insert(
						list,
						label(
							s,
							1,
							Text.get(use, `quest.{nextQuest.id}.title`),
							Theme.Fonts.Heading,
							26,
							Theme.Colors.GoldBright
						)
					)
					table.insert(
						list,
						label(
							s,
							2,
							if ready
								then Text.get(
									use,
									"quest.getFrom",
									{ npc = if giver then Text.get(use, giver.nameKey) else "?" }
								)
								else Text.get(
									use,
									"quest.nextAt",
									{ level = nextQuest.level - Quests.Main.LEVEL_SLACK }
								),
							Theme.Fonts.BodyMedium,
							18,
							Theme.Colors.Parchment
						)
					)
				else
					table.insert(
						list,
						label(s, 1, Text.get(use, "quest.storyDone"), Theme.Fonts.Heading, 24, Theme.Colors.GoldBright)
					)
				end
			end
			-- Story so far
			local done = {}
			for i = 1, q.mainDone or 0 do
				local finished = Quests.Main.list[i]
				if finished then
					table.insert(done, `✔ {Text.get(use, `quest.{finished.id}.title`)}`)
				end
			end
			if #done > 0 then
				table.insert(
					list,
					label(s, 10, `<b>{Text.get(use, "quest.history")}</b>`, Theme.Fonts.BodyBold, 17, Theme.Colors.Gold)
				)
				table.insert(list, label(s, 11, table.concat(done, "\n"), Theme.Fonts.Body, 15, Theme.Colors.TextMuted))
			end
		else
			local daily = q.daily
			table.insert(
				list,
				label(
					s,
					0,
					Text.get(
						use,
						"quest.dailyReset",
						{ time = Time.format((Time.dayNumber(use(now)) + 1) * 86400 - use(now)) }
					),
					Theme.Fonts.BodyMedium,
					16,
					Theme.Colors.TextMuted
				)
			)
			for i, entry in (if type(daily) == "table" then daily.list else {}) or {} do
				local status = if entry.claimed
					then ` <font color="#8E8E93">({Text.get(use, "quest.claimed")})</font>`
					elseif entry.progress >= entry.objective.n then ` <font color="#4FD16B">({Text.get(
						use,
						"quest.claimAtBoard"
					)})</font>`
					else ""
				table.insert(
					list,
					label(
						s,
						i * 2,
						`<b>{Text.get(use, `daily.{entry.template}.title`)}</b>{status}`,
						Theme.Fonts.BodyBold,
						18,
						Theme.Colors.GoldBright
					)
				)
				table.insert(
					list,
					label(
						s,
						i * 2 + 1,
						QuestText.objective(use, entry.objective, entry.progress),
						Theme.Fonts.Body,
						16,
						Theme.Colors.Text
					)
				)
			end
		end
		return list
	end)

	return {
		Tabs(scope, {
			Selected = tab,
			Tabs = {
				{ id = "main", label = Text.T(scope, "quest.tab.main") },
				{ id = "daily", label = Text.T(scope, "quest.tab.daily") },
			},
		}),
		scope:New("ScrollingFrame")({
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 1, -52),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
				content :: any,
			},
		}),
	}
end

return QuestJournal
