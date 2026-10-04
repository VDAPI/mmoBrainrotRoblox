--!strict
-- Story quest dialog with an NPC (DESIGN §20): the quest this NPC gives (story text, objectives, rewards,
-- "Accept") or the one handed in here (closing text, rewards, "Hand in"); otherwise a short note.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.ItemText)
local Net = require(ReplicatedStorage.Shared.Net)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestText = require(script.Parent.Parent.QuestText)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	NpcId: Fusion.UsedAs<string?>,
	Close: () -> (),
}

-- "120 EXP · 300 gold · Small Healing Potion x5"
local function rewardLine(use: any, reward: Quests.Reward): string
	local parts = {
		Text.get(use, "quest.reward.exp", { exp = Format.number(reward.exp) }),
		Text.get(use, "quest.reward.gold", { gold = Format.number(reward.gold) }),
	}
	for _, item in (reward.items or {}) :: { { id: string, n: number } } do
		table.insert(parts, `{ItemText.get(use, item.id)}{if item.n > 1 then ` x{item.n}` else ""}`)
	end
	return table.concat(parts, "  ·  ")
end

local function QuestDialog(scope: Scope, props: Props): Fusion.Child
	local quests = State.Value({ "character", "quests" })
	local level = State.Value({ "character", "level" })

	-- What this NPC offers: { mode, quest, progress }
	local view = scope:Computed(function(use): any
		local npcId = use(props.NpcId)
		local q = use(quests)
		if not npcId or type(q) ~= "table" then
			return nil
		end
		local main = q.main
		if type(main) == "table" then
			local quest = Quests.Main.get(main.id)
			if quest and quest.turnIn == npcId then
				return { mode = "turnIn", quest = quest, progress = main.progress or {} }
			end
			if quest then
				return { mode = "busy", quest = quest, progress = main.progress or {} }
			end
			return nil
		end
		local nextQuest, ready = QuestLogic.nextMain(q.mainDone or 0, use(level) or 1)
		if nextQuest and nextQuest.giver == npcId then
			return {
				mode = if ready then "offer" else "tooLow",
				quest = nextQuest,
				progress = QuestLogic.emptyProgress(nextQuest.objectives),
			}
		end
		return nil
	end)

	local function act()
		local v = Fusion.peek(view)
		local npcId = Fusion.peek(props.NpcId)
		if not v or not npcId then
			return
		end
		task.spawn(function()
			local name = if v.mode == "offer" then "QuestAccept" else "QuestTurnIn"
			local ok, err = Net.Invoke(name, npcId)
			if ok then
				Sounds.play("levelUp")
				if v.mode == "offer" then
					Toast.push(Text.now("quest.accepted", { title = Text.now(`quest.{v.quest.id}.title`) }), "success")
				end
				props.Close()
			else
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	return {
		scope:New("TextLabel")({
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local v = use(view)
				return if v then Text.get(use, `quest.{v.quest.id}.title`) else Text.get(use, "quest.nothing")
			end),
			FontFace = Theme.Fonts.Heading,
			TextSize = 28,
			TextColor3 = Theme.Colors.GoldBright,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(1, 0, 0, 150),
			BackgroundTransparency = 1,
			TextWrapped = true,
			Text = scope:Computed(function(use): string
				local v = use(view)
				if not v then
					return ""
				end
				if v.mode == "turnIn" and QuestLogic.isComplete(v.progress, v.quest.objectives) then
					return Text.get(use, `quest.{v.quest.id}.done`)
				elseif v.mode == "busy" then
					return Text.get(use, "quest.busyElsewhere")
				elseif v.mode == "tooLow" then
					return Text.get(use, "quest.error.level") .. ` ({v.quest.level - Quests.Main.LEVEL_SLACK}+)`
				end
				return Text.get(use, `quest.{v.quest.id}.text`)
			end),
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Colors.Parchment,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(0, 204),
			Size = UDim2.new(1, 0, 0, 120),
			BackgroundTransparency = 1,
			TextWrapped = true,
			RichText = true,
			Text = scope:Computed(function(use): string
				local v = use(view)
				if not v then
					return ""
				end
				local lines = { `<b>{Text.get(use, "quest.objectives")}</b>` }
				for i, objective in v.quest.objectives do
					local have = v.progress[i] or 0
					local done = have >= objective.n
					local label = QuestText.objective(use, objective, have)
					table.insert(lines, if done then `<font color="#4FD16B">✔ {label}</font>` else `• {label}`)
				end
				return table.concat(lines, "\n")
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(0, 330),
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			TextWrapped = true,
			Text = scope:Computed(function(use): string
				local v = use(view)
				return if v then `{Text.get(use, "quest.rewards")}: {rewardLine(use, v.quest.reward)}` else ""
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.GoldBright,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Button(scope, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(240, 54),
			Variant = "primary",
			Visible = scope:Computed(function(use): boolean
				local v = use(view)
				return v ~= nil and (v.mode == "offer" or v.mode == "turnIn")
			end),
			Text = scope:Computed(function(use): string
				local v = use(view)
				return Text.get(use, if v and v.mode == "turnIn" then "quest.turnIn" else "quest.accept")
			end),
			Disabled = scope:Computed(function(use): boolean
				local v = use(view)
				return v ~= nil and v.mode == "turnIn" and not QuestLogic.isComplete(v.progress, v.quest.objectives)
			end),
			OnClick = act,
		}),
	}
end

return QuestDialog
