--!strict
-- Dev panel, "Quests" tab (S23): the main story in order with the current quest marked ("Set" / "Complete"),
-- daily quests reroll and a short state line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Dev = require(script.Parent.Dev)

local function QuestsTab(s: Dev.Scope): Instance
	local quests = State.Value({ "character", "quests" })

	local rows = s:Computed(function(use, inner: Dev.Scope): { Instance }
		local q = use(quests)
		use(Text.Lang)
		local current = if type(q) == "table" and type(q.main) == "table" then q.main.id else nil
		local out = {}
		for i, quest in Quests.Main.list do
			local isCurrent = quest.id == current
			local label = `{if isCurrent then "▶ " else ""}{i}. {Text.now(`quest.{quest.id}.title`)} · {quest.level}`
			local buttons: { any } = {
				Dev.button(inner, Text.T(inner, "dev.set"), function()
					Dev.run("quest", { "set", quest.id })
				end, 90),
			}
			if isCurrent then
				table.insert(
					buttons,
					Dev.button(inner, Text.T(inner, "dev.quest.complete"), function()
						Dev.run("quest", { "complete" })
					end, 120)
				)
			end
			local row = Dev.row(inner, i, label, buttons)
			if isCurrent then
				local first = row:FindFirstChildWhichIsA("TextLabel")
				if first then
					first.TextColor3 = Theme.Colors.GoldBright
				end
			end
			table.insert(out, row)
		end
		return out
	end)

	return Dev.column(s, {
		Dev.header(s, 1, "dev.quest.daily"),
		Dev.row(s, 2, nil, {
			Dev.button(s, Text.T(s, "dev.quest.reroll"), function()
				Dev.run("daily", { "reroll" })
			end, 200),
		}),
		s:New("TextLabel")({
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = s:Computed(function(use): string
				local q = use(quests)
				local main = if type(q) == "table" and type(q.main) == "table" then q.main else nil
				local dailies = if type(q) == "table" and type(q.daily) == "table" then q.daily else {}
				local count = 0
				for _ in dailies do
					count += 1
				end
				return Text.get(use, "dev.quest.state", {
					main = if main then main.id else "-",
					progress = if main and type(main.progress) == "table"
						then table.concat(main.progress :: { any }, "/")
						else "-",
					daily = count,
				})
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.Parchment,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Dev.header(s, 4, "dev.quest.main"),
		s:New("Frame")({
			LayoutOrder = 5,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Fusion.Children] = {
				s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
				rows :: any,
			},
		}),
		Dev.header(s, 6, "dev.allCommands"),
		Dev.commandRows(s, 7, { "quests" }) :: any,
	})
end

return QuestsTab
