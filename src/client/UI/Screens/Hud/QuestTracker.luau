--!strict
-- Quest tracker (DESIGN §20, right side under the minimap): the main quest with its objectives and an arrow
-- towards its target (an NPC or a place on this map, or the portal leading to the target map), plus the
-- daily contracts. The header collapses it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CollectionService = game:GetService("CollectionService")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestText = require(script.Parent.Parent.Parent.QuestText)
local QuestTrack = require(script.Parent.Parent.Parent.QuestTrack)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local WIDTH = 300

-- World position the arrow points to (nil = hide the arrow).
local function aimPoint(target: QuestTrack.Target?): Vector3?
	if not target then
		return nil
	end
	local mapId = State.Get({ "character", "location", "map" })
	local here = Maps.get(mapId or "")
	if not here then
		return nil
	end
	if target.map == here.id then
		if target.x and target.z then
			return Vector3.new(here.offset.x + target.x, 0, here.offset.z + target.z)
		end
		return nil
	end
	-- Another map: the portal straight to it, or failing that the portal to the capital.
	local fallback: Vector3? = nil
	for _, portal in CollectionService:GetTagged("Portal") do
		if portal:IsA("Model") and portal:IsDescendantOf(Workspace) then
			local to = portal:GetAttribute("TargetMap")
			local position = portal:GetPivot().Position
			local local_ = position - Vector3.new(here.offset.x, 0, here.offset.z)
			if math.abs(local_.X) <= here.size.x / 2 and math.abs(local_.Z) <= here.size.z / 2 then
				if to == target.map then
					return position
				elseif to == "city" then
					fallback = position
				end
			end
		end
	end
	return fallback
end

local function QuestTracker(scope: Scope): Instance
	local quests = State.Value({ "character", "quests" })
	local timers = State.Value({ "character", "e2timers" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local clock = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			clock += dt
			if clock >= 1 then
				clock = 0
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)
	local collapsed = scope:Value(false)
	local arrow = scope:Value(nil :: number?)

	table.insert(
		scope,
		RunService.RenderStepped:Connect(function()
			local point = aimPoint(Fusion.peek(QuestTrack.Target))
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local camera = Workspace.CurrentCamera
			if not point or not root or not camera then
				arrow:set(nil)
				return
			end
			local to = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
			if to.Magnitude < 8 then
				arrow:set(nil)
				return
			end
			local look = camera.CFrame.LookVector
			local forward = Vector3.new(look.X, 0, look.Z)
			if forward.Magnitude < 0.01 then
				return
			end
			local angle = math.atan2(to.X, -to.Z) - math.atan2(forward.X, -forward.Z)
			arrow:set(math.deg(angle))
		end)
	)

	-- One block per quest (S18): title, a grey "From / Turn in: NPC" line and its own objectives, with a gap
	-- between blocks; daily contracts under their own "Contracts: Quest Board" header.
	local lines = scope:Computed(function(use, s: Scope): { Instance }
		local q = use(quests)
		local list = {}
		if type(q) ~= "table" or use(collapsed) then
			return list
		end
		local order = 0
		local function line(text: string, color: Color3, size: number, font: Font, indent: number?)
			order += 1
			table.insert(
				list,
				s:New("TextLabel")({
					LayoutOrder = order,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextWrapped = true,
					Text = text,
					FontFace = font,
					TextSize = size,
					TextColor3 = color,
					TextStrokeTransparency = 0.5,
					TextXAlignment = Enum.TextXAlignment.Left,
					[Children] = if indent
						then s:New("UIPadding")({ PaddingLeft = UDim.new(0, indent) }) :: any
						else nil,
				})
			)
		end
		local function gap()
			order += 1
			table.insert(
				list,
				s:New("Frame")({
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 6),
					BackgroundTransparency = 1,
				})
			)
		end
		local function npcName(npcId: string?): string
			local npc = npcId and Npcs.get(npcId)
			return if npc then Text.get(use, npc.nameKey) else ""
		end

		local main = q.main
		local quest = if type(main) == "table" then Quests.Main.get(main.id) else nil
		if quest and main and use(QuestTrack.Tracked) then
			line(Text.get(use, `quest.{quest.id}.title`), Theme.Colors.GoldBright, 18, Theme.Fonts.BodyBold)
			if QuestLogic.isComplete(main.progress or {}, quest.objectives) then
				line(
					Text.get(use, "quest.tracker.turnIn", { npc = npcName(quest.turnIn) }),
					Theme.Colors.Success,
					15,
					Theme.Fonts.BodyMedium
				)
			else
				line(
					Text.get(use, "quest.tracker.from", { npc = npcName(quest.giver) }),
					Theme.Colors.TextMuted,
					14,
					Theme.Fonts.Body
				)
				for i, objective in quest.objectives do
					local have = (main.progress or {})[i] or 0
					if have < objective.n then
						line(
							`• {QuestText.objective(use, objective, have)}`,
							Theme.Colors.Text,
							15,
							Theme.Fonts.BodyMedium,
							6
						)
					end
				end
			end
		elseif not quest then
			local nextQuest, ready =
				QuestLogic.nextMain(q.mainDone or 0, use(State.Value({ "character", "level" })) or 1)
			if nextQuest and ready then
				line(
					`! {Text.get(use, `quest.{nextQuest.id}.title`)}`,
					Theme.Colors.GoldBright,
					17,
					Theme.Fonts.BodyBold
				)
				line(
					Text.get(use, "quest.tracker.from", { npc = npcName(nextQuest.giver) }),
					Theme.Colors.TextMuted,
					14,
					Theme.Fonts.Body
				)
			end
		end

		local daily = q.daily
		local open = {}
		for _, entry in (if type(daily) == "table" then daily.list else {}) or {} do
			if not entry.claimed then
				table.insert(open, entry)
			end
		end
		if #open > 0 then
			if order > 0 then
				gap()
			end
			line(
				Text.get(use, "quest.tracker.contracts", { npc = npcName("questboard") }),
				Theme.Colors.Gold,
				16,
				Theme.Fonts.BodyBold
			)
			for _, entry in open do
				local done = entry.progress >= entry.objective.n
				line(
					Text.get(use, `daily.{entry.template}.title`),
					if done then Theme.Colors.Success else Theme.Colors.Parchment,
					15,
					Theme.Fonts.BodyMedium,
					4
				)
				line(
					`{if done then "✔" else "◦"} {QuestText.objective(use, entry.objective, entry.progress)}`,
					if done then Theme.Colors.Success else Theme.Colors.Text,
					14,
					Theme.Fonts.Body,
					10
				)
			end
		end
		-- Elite II timers (S20, DESIGN §15.3)
		local timerList = use(timers)
		if type(timerList) == "table" and #timerList > 0 then
			gap()
			line(Text.get(use, "e2timer.header"), Theme.Colors.Gold, 16, Theme.Fonts.BodyBold)
			local t = use(now)
			for _, timer in timerList do
				local def = Monsters.get(timer.kind)
				local name = if def then Text.get(use, def.nameKeys.elite2) else timer.kind
				local map = Maps.get(timer.map)
				local where = if map then Text.get(use, map.nameKey) else timer.map
				local state
				if timer.job ~= game.JobId then
					state = Text.get(use, "e2timer.otherServer")
				elseif t < timer.from then
					state = Text.get(use, "e2timer.window", {
						from = Time.format(timer.from - t),
						to = Time.format(timer.to - t),
					})
				elseif t < timer.to then
					state = Text.get(use, "e2timer.soon", { to = Time.format(timer.to - t) })
				else
					state = Text.get(use, "e2timer.any")
				end
				line(`{name} ({where})`, Theme.Colors.Parchment, 14, Theme.Fonts.BodyMedium, 4)
				line(state, Theme.Colors.TextMuted, 13, Theme.Fonts.Body, 10)
			end
		end
		return list
	end)

	return scope:New("Frame")({
		Name = "QuestTracker",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Theme.Padding.Large, 0, 400),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.45,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
			scope:New("Frame")({
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("TextButton")({
						Size = UDim2.new(1, -40, 1, 0),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return `{if use(collapsed) then "▸" else "▾"} {Text.get(use, "quest.tracker")}`
						end),
						FontFace = Theme.Fonts.Heading,
						TextSize = 18,
						TextColor3 = Theme.Colors.Gold,
						TextXAlignment = Enum.TextXAlignment.Left,
						[OnEvent("Activated")] = function()
							collapsed:set(not Fusion.peek(collapsed))
						end,
					}),
					scope:New("TextLabel")({
						Name = "Arrow",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(28, 28),
						BackgroundTransparency = 1,
						Text = "⬆",
						TextScaled = true,
						FontFace = Theme.Fonts.BodyBold,
						TextColor3 = Theme.Colors.GoldBright,
						TextStrokeTransparency = 0.3,
						Visible = scope:Computed(function(use): boolean
							return use(arrow) ~= nil and use(QuestTrack.Tracked)
						end),
						Rotation = scope:Computed(function(use): number
							return use(arrow) or 0
						end),
					}),
				},
			}),
			lines :: any,
		},
	})
end

return QuestTracker
