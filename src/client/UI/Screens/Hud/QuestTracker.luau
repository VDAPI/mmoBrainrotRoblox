--!strict
-- Quest tracker (DESIGN §20, right side under the minimap): the tracked side quest (S27, QuestTrack.Focus) and the
-- main quest with their objectives and an arrow towards the tracked one's target (an NPC or a place on this map, or the portal leading to the target map), plus the
-- daily contracts. The header collapses it. Elite II timers moved to Hud/Elite2Timer (FIX 2026-10-09). S99: the hunting
-- contract between the story and the daily contracts (on top with the arrow when tracked; the next one to take with
-- "From: Contract board"; nothing while waiting for a level or after the 99th; S134k: up to three active ones and "+N").
-- S101b: targets follow the saved
-- answers (QuestText `quests`), and a quest with a companion shows "<NPC> is waiting for you" / "went back".
-- S151b: the tracked achievements (character.ach.track, at most Config.Achievements.trackMax) under the quests: the
-- name, "value / goal" and a thin bar; a click opens the achievements window on it. A row listens only to its own
-- counter; on a phone Config.Achievements.trackPhone of them show until "+N" unfolds the rest. Collapses with the
-- tracker.
-- S159 (owner 2026-10-20): the daily contracts under one line with the set's progress and the time to the new set
-- (minutes), one row per open contract, "Done: collect at the board" once all are done, and the weekly set's progress
-- while it has open contracts.
-- S156 (owner 2026-10-20): the player moves the tracker by the grip in its header and sizes it by the corner grip
-- (Logic/HudLayout, account.settings.hud.questTracker; "Reset HUD layout" in the menu); the quest list scrolls inside
-- it when it is longer than the tracker (the screen's height at most without a saved size).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AchData = require(ReplicatedStorage.Shared.Data.Achievements)
local AchievementView = require(ReplicatedStorage.Shared.Logic.AchievementView)
local Achievements = require(ReplicatedStorage.Shared.Logic.Achievements)
local AreaState = require(script.Parent.Parent.Parent.AreaState)
local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local Config = require(ReplicatedStorage.Shared.Config)
local Device = require(script.Parent.Parent.Parent.Device)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local Dailies = require(ReplicatedStorage.Shared.Logic.Dailies)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GuidePointer = require(ReplicatedStorage.Shared.Logic.GuidePointer)
local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local MapRoute = require(ReplicatedStorage.Shared.Logic.MapRoute)
local MapSketch = require(script.Parent.Parent.Parent.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestRows = require(ReplicatedStorage.Shared.Logic.QuestRows)
local QuestText = require(script.Parent.Parent.Parent.QuestText)
local QuestTrack = require(script.Parent.Parent.Parent.QuestTrack)
local Scale = require(script.Parent.Parent.Parent.Scale)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children, OnChange, OnEvent = Fusion.Children, Fusion.OnChange, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local WIDTH = 300
-- S156: the frame of the tracker around its scrolling body
local HEADER = 28
local GAP = 3
local PAD_TOP, PAD_BOTTOM = 6, 8
local GRIP = 22
local ELEMENT = "questTracker"
-- S29: a finished objective pulses for this long (seconds), then keeps a soft green glow.
local PULSE_TIME = 1
local GLOW_TRANSPARENCY = 0.6

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
	-- Another map: the next way out on the route there (S25: Logic/MapRoute over Data/Portals).
	local exit = MapRoute.nextExit(here.id, target.map, MapSketch.isBuilt)
	if exit then
		return Vector3.new(here.offset.x + exit.x, 0, here.offset.z + exit.z)
	end
	return nil
end

export type Props = {
	-- S25: "Guide" to the tracked quest's target (NavController).
	Guide: ((target: QuestTrack.Target) -> ())?,
	-- S101: pixels the tracker moves down while the world event panel stands above it (QuestController).
	Offset: Fusion.UsedAs<number>?,
	-- S151b: a tracked achievement's row opens the achievements window on it.
	OpenAchievement: ((id: string) -> ())?,
}

-- S151b: the layout order of the achievement section (after every quest line).
local ACH_ORDER = 100000
local ACH_ROW = 40 -- PC; a phone row is Theme.Size.RowHeight (a tap target)

-- S151b: one tracked achievement: the name and "value / goal" over a thin bar; the numbers follow only its counter.
local function achievementRow(s: Scope, def: any, order: number, height: number, props: Props?): Instance
	local root = if Achievements.scopeOf(def.counter) == "account" then "account" else "character"
	local count = State.Value({ root, "ach", "c", def.counter })
	local set = State.Value({ root, "ach", "s", def.counter })
	local row = s:Computed(function(use): AchievementView.Row?
		use(count)
		use(set)
		return AchievementView.detail(
			AchievementView.read(State.Get({ "account" }), State.Get({ "character" })),
			def.id
		)
	end)
	return s:New("TextButton")({
		Name = def.id,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		[OnEvent("Activated")] = function()
			if props and props.OpenAchievement then
				props.OpenAchievement(def.id)
			end
		end,
		[Children] = {
			s:New("TextLabel")({
				Name = "Name",
				Size = UDim2.new(1, -70, 0, 24),
				BackgroundTransparency = 1,
				Text = s:Computed(function(use): string
					return `✪ {Text.get(use, `ach.{def.id}.name`)}`
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextStrokeTransparency = 0.5,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			s:New("TextLabel")({
				Name = "Count",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(70, 24),
				BackgroundTransparency = 1,
				Text = s:Computed(function(use): string
					local r = use(row)
					return if r then `{math.min(r.value, r.goal)} / {r.goal}` else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = Theme.Brass.Bright,
				TextStrokeTransparency = 0.5,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			Bar(s, {
				Name = "Progress",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -6),
				Size = UDim2.new(1, 0, 0, 5),
				Value = s:Computed(function(use): number
					local r = use(row)
					return if r then r.pct else 0
				end),
				Max = 1,
				Color = Theme.Brass.Bright,
				Surface = "iron",
			}),
		},
	})
end

local function QuestTracker(scope: Scope, props: Props?): Instance
	local quests = State.Value({ "character", "quests" })
	local collapsed = scope:Value(false)
	-- S29: which objective rows were already seen done and when their pulse ends; kept outside the Computed, so a
	-- recompute (progress, language) does not pulse them again.
	local seen: QuestRows.Seen = {}
	local pulseUntil: { [string]: number } = {}
	local arrow = scope:Value(nil :: number?)
	-- S159: the minute of the clock (the daily set's countdown)
	local minute = scope:Value(math.floor(Clock.now() / 60))
	local minuteAcc = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			minuteAcc += dt
			if minuteAcc >= 5 then
				minuteAcc = 0
				local m = math.floor(Clock.now() / 60)
				if m ~= Fusion.peek(minute) then
					minute:set(m)
				end
			end
		end)
	)

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
			-- W28: the same maths as the world guide (Logic/GuidePointer)
			local dx, dz = point.X - root.Position.X, point.Z - root.Position.Z
			if GuidePointer.reached(GuidePointer.flat(0, 0, dx, dz), 8) then
				arrow:set(nil)
				return
			end
			local look = camera.CFrame.LookVector
			local angle = GuidePointer.bearing(dx, dz, look.X, look.Z)
			if angle then
				arrow:set(angle)
			end
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
		local function line(text: string, color: Color3, size: number, font: Font, indent: number?): TextLabel
			order += 1
			local label = s:New("TextLabel")({
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
				[Children] = if indent then s:New("UIPadding")({ PaddingLeft = UDim.new(0, indent) }) :: any else nil,
			}) :: TextLabel
			table.insert(list, label)
			return label
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
		-- S101b: the quest companion's state under its quest
		local companion = use(State.Value({ "companion" }))
		local function companionLine(questId: string)
			if type(companion) ~= "table" or companion.quest ~= questId then
				return
			end
			local key = if companion.phase == "wait" and companion.mode == "lead"
				then "companion.waiting"
				elseif companion.phase == "back" and companion.mode == "lead" then "companion.back"
				else nil
			if key then
				line(
					Text.get(use, key, { npc = npcName(companion.npc) }),
					Theme.Brass.Bright,
					Theme.TextSize.Small,
					Theme.Fonts.BodyMedium,
					6
				)
			end
		end

		-- S29: every objective stays in the list (Logic/QuestRows); finished ones are green with a soft glow and
		-- pulse once when finished; a complete quest adds the gold "Return to: <NPC>" line with its own guide button.
		local function objectives(key: string, rowList: QuestRows.List, guide: QuestTrack.Target?)
			local clockNow = os.clock()
			for _, index in QuestRows.newlyDone(seen, key, rowList) do
				pulseUntil[`{key}#{index}`] = clockNow + PULSE_TIME
			end
			for _, row in rowList.rows do
				local label = line(
					QuestRows.line(row),
					if row.done then Theme.Iron.Success else Theme.Iron.Text,
					Theme.TextSize.Small,
					Theme.Fonts.BodyMedium,
					6
				)
				if row.done then
					local pulseKey = `{key}#{row.index}`
					local left = (pulseUntil[pulseKey] or 0) - clockNow
					local alpha = math.clamp(left / PULSE_TIME, 0, 1)
					if alpha <= 0 then
						pulseUntil[pulseKey] = nil
					end
					local stroke = s:New("UIStroke")({
						Color = Theme.Iron.Success,
						Thickness = 1 + 2 * alpha,
						Transparency = GLOW_TRANSPARENCY * (1 - alpha),
						Parent = label,
					})
					if alpha > 0 then
						label.TextColor3 = Theme.Iron.Success:Lerp(Theme.Plain, alpha)
						local info = TweenInfo.new(left, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
						task.defer(function()
							if stroke.Parent then
								TweenService:Create(stroke, info, { Thickness = 1, Transparency = GLOW_TRANSPARENCY })
									:Play()
								TweenService:Create(label, info, { TextColor3 = Theme.Iron.Success }):Play()
							end
						end)
					end
				end
			end
			if rowList.complete then
				local back = QuestText.returnTo(use, rowList)
				if back ~= "" then
					order += 1
					local canGuide = props ~= nil and props.Guide ~= nil and guide ~= nil and guide.x ~= nil
					table.insert(
						list,
						s:New("Frame")({
							LayoutOrder = order,
							Size = UDim2.new(1, 0, 0, 26),
							BackgroundTransparency = 1,
							[Children] = {
								s:New("TextLabel")({
									Size = UDim2.new(1, if canGuide then -34 else 0, 1, 0),
									BackgroundTransparency = 1,
									TextWrapped = true,
									TextScaled = false,
									Text = back,
									FontFace = Theme.Fonts.BodyBold,
									TextSize = Theme.TextSize.Small,
									TextColor3 = Theme.Brass.Bright,
									TextStrokeTransparency = 0.4,
									TextXAlignment = Enum.TextXAlignment.Left,
								}),
								if canGuide
									then s:New("TextButton")({
										Name = "GuideTurnIn",
										AnchorPoint = Vector2.new(1, 0.5),
										Position = UDim2.fromScale(1, 0.5),
										Size = UDim2.fromOffset(30, 26),
										BackgroundColor3 = Theme.Iron.Raised,
										BackgroundTransparency = 0.2,
										Text = "➤",
										FontFace = Theme.Fonts.BodyBold,
										TextSize = Theme.TextSize.Small,
										TextColor3 = Theme.Brass.Bright,
										[OnEvent("Activated")] = function()
											if props and props.Guide and guide then
												props.Guide(guide)
											end
										end,
										[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
									}) :: any
									else nil,
							},
						})
					)
				end
			end
		end

		-- S27: the tracked side quest first.
		local level = use(State.Value({ "character", "level" })) or 1
		local focus = use(QuestTrack.Focus)

		-- S99: the hunting contract (active: title and objective; to take: "!" and where). S134k: up to
		-- Config.Quest.trackerContracts active contracts in the tracker's order (the tracked one, the finished ones, the
		-- nearest on this map; QuestText.contractOrder), "+N hunting contracts" under them; none active: how many to take
		local contractState = Contracts.stateOf(q)
		local function contractBlock(): boolean
			local map = use(State.Value({ "character", "location", "map" }))
			-- the nearest-ground order follows the player: re-sorted on entering another monster area
			use(AreaState.Current)
			local x, z = QuestText.mapPosition()
			local focusId = if focus and focus.kind == "contract" then focus.id else nil
			local list = QuestText.contractOrder(contractState, focusId, map, x, z)
			if #list > 0 then
				local shown = math.min(#list, Config.Quest.trackerContracts)
				for i = 1, shown do
					local taken = list[i]
					local target = QuestText.contractTarget(taken.contract, taken.entry, level, map)
					local turnIn = if target and target.npc then target.npc else Contracts.BOARD
					-- the kind, ground and progress are on the objective row below (one line)
					line(
						`◈ {Text.get(use, "contract.titleShort", { n = taken.contract.level })}`,
						Theme.Iron.Heading,
						Theme.TextSize.Small,
						Theme.Fonts.BodyBold
					)
					objectives(
						`contract:{taken.contract.id}`,
						QuestText.rows(use, taken.contract.objectives, taken.entry.progress, turnIn),
						target
					)
				end
				if #list > shown then
					line(
						Text.get(use, "contract.trackerMore", { n = #list - shown }),
						Theme.Iron.TextMuted,
						Theme.TextSize.Small,
						Theme.Fonts.Body
					)
				end
				return true
			end
			local eligible = Contracts.eligible(contractState, level)
			if #eligible > 0 then
				line(
					`! {Text.get(use, "contract.toTake", { n = #eligible })}`,
					Theme.Brass.Bright,
					Theme.TextSize.Small,
					Theme.Fonts.BodyBold
				)
				line(
					Text.get(use, "quest.tracker.from", { npc = npcName(Contracts.BOARD) }),
					Theme.Iron.TextMuted,
					Theme.TextSize.Small,
					Theme.Fonts.Body
				)
				return true
			end
			return false
		end
		local contractOnTop = focus ~= nil and focus.kind == "contract"
		if contractOnTop and contractBlock() then
			gap()
		end

		local sideQuest = if focus and focus.id then Quests.npcQuest(focus.id) else nil
		local sideEntry = if focus and focus.id then SideQuests.activeOf(q)[focus.id] else nil
		if sideQuest and type(sideEntry) == "table" then
			line(
				`◆ {Text.get(use, `quest.{sideQuest.id}.title`)}`,
				Theme.Brass.Bright,
				Theme.TextSize.Small,
				Theme.Fonts.BodyBold
			)
			objectives(
				`side:{sideQuest.id}`,
				QuestText.rows(use, sideQuest.objectives, sideEntry.progress, sideQuest.turnIn),
				QuestText.sideTarget(sideQuest, sideEntry, level, q)
			)
			companionLine(sideQuest.id)
			gap()
		end

		local main = q.main
		local quest = if type(main) == "table" then Quests.Main.get(main.id) else nil
		if quest and main and use(QuestTrack.Tracked) then
			line(
				Text.get(use, `quest.{quest.id}.title`),
				Theme.Brass.Bright,
				Theme.TextSize.Small,
				Theme.Fonts.BodyBold
			)
			local rows = QuestText.rows(use, quest.objectives, main.progress, quest.turnIn)
			if not rows.complete then
				line(
					Text.get(use, "quest.tracker.from", { npc = npcName(quest.giver) }),
					Theme.Iron.TextMuted,
					Theme.TextSize.Small,
					Theme.Fonts.Body
				)
			end
			objectives(`main:{quest.id}`, rows, QuestText.target(quest, main.progress or {}, level, q, main.used))
			companionLine(quest.id)
		elseif not quest then
			local nextQuest, ready = QuestLogic.nextMain(q.mainDone or 0, level)
			if nextQuest and ready then
				line(
					`! {Text.get(use, `quest.{nextQuest.id}.title`)}`,
					Theme.Brass.Bright,
					Theme.TextSize.Small,
					Theme.Fonts.BodyBold
				)
				line(
					Text.get(use, "quest.tracker.from", { npc = npcName(nextQuest.giver) }),
					Theme.Iron.TextMuted,
					Theme.TextSize.Small,
					Theme.Fonts.Body
				)
			end
		end

		if not contractOnTop then
			local before = order
			if before > 0 then
				gap()
			end
			if not contractBlock() and before > 0 then
				-- nothing to show: drop the gap again
				table.remove(list)
				order -= 1
			end
		end

		-- S159: the daily set (progress, countdown, open contracts) and the weekly set's progress
		local daily = q.daily
		local dailyList = if type(daily) == "table" then daily.list else nil
		local p = Dailies.progress(dailyList)
		local weekly = q.weekly
		local wp = Dailies.progress(if type(weekly) == "table" then weekly.list else nil)
		if p.claimed < p.total or wp.claimed < wp.total then
			if order > 0 then
				gap()
			end
		end
		if p.claimed < p.total then
			local t = use(minute) * 60
			local left = (Time.dayNumber(t) + 1) * 86400 - t
			local hh = math.floor(left / 3600)
			local mm = math.floor((left % 3600) / 60)
			line(
				Text.get(use, "quest.tracker.daily", {
					done = p.complete,
					total = p.total,
					time = string.format("%d:%02d", hh, mm),
				}),
				Theme.Iron.Heading,
				Theme.TextSize.Small,
				Theme.Fonts.BodyBold
			)
			if p.complete >= p.total then
				line(
					Text.get(use, "quest.tracker.collect"),
					Theme.Brass.Bright,
					Theme.TextSize.Small,
					Theme.Fonts.BodyMedium,
					4
				)
			else
				for _, entry in dailyList or {} do
					if not entry.claimed then
						local done = entry.progress >= entry.objective.n
						line(
							`{if done then "✔" else "◦"} {QuestText.objective(use, entry.objective, entry.progress)}`,
							if done then Theme.Iron.Success else Theme.Iron.Text,
							Theme.TextSize.Small,
							Theme.Fonts.Body,
							4
						)
					end
				end
			end
		end
		if wp.claimed < wp.total then
			line(
				Text.get(use, "quest.tracker.weekly", { done = wp.complete, total = wp.total }),
				if wp.complete >= wp.total then Theme.Brass.Bright else Theme.Iron.TextMuted,
				Theme.TextSize.Small,
				Theme.Fonts.BodyMedium
			)
		end
		return list
	end)

	-- S151b: the tracked achievements under the quests (the list from AchievementView.trackedRows: no unknown, done or
	-- secret one; rebuilt when the track list changes, a row follows its own counter)
	local tracked = State.Value({ "character", "ach", "track" })
	local achOpen = scope:Value(false)
	local achLines = scope:Computed(function(use, s: Scope): { Instance }
		local out: { Instance } = {}
		local list = use(tracked)
		if use(collapsed) or type(list) ~= "table" then
			return out
		end
		local defs: { any } = {}
		local st = AchievementView.read(State.Get({ "account" }), State.Get({ "character" }))
		for _, row in AchievementView.trackedRows(st) do
			local def = AchData.get(row.id)
			if def then
				table.insert(defs, def)
			end
		end
		if #defs == 0 then
			return out
		end
		local shown = #defs
		local rowHeight = if use(Device.Touch) then Theme.Size.RowHeight else ACH_ROW
		if use(Device.Touch) and not use(achOpen) then
			shown = math.min(shown, Config.Achievements.trackPhone)
		end
		table.insert(
			out,
			s:New("TextLabel")({
				Name = "AchievementsHeader",
				LayoutOrder = ACH_ORDER,
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				Text = Text.get(use, "ach.tracker"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Heading,
				TextStrokeTransparency = 0.5,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
			})
		)
		for i = 1, shown do
			table.insert(out, achievementRow(s, defs[i], ACH_ORDER + i, rowHeight, props))
		end
		if shown < #defs then
			table.insert(
				out,
				s:New("TextButton")({
					Name = "AchievementsMore",
					LayoutOrder = ACH_ORDER + #defs + 1,
					Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
					BackgroundTransparency = 1,
					Text = Text.get(use, "ach.tracker.more", { n = #defs - shown }),
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Iron.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
					[OnEvent("Activated")] = function()
						achOpen:set(true)
					end,
				})
			)
		end
		return out
	end)

	-- S156: the saved place and size; `live` holds the new ones while a grip is held and until the save comes back
	local saved = State.Value({ "account", "settings", "hud" })
	local live = scope:Value(nil :: HudLayout.Entry?)
	scope:Observer(saved):onChange(function()
		live:set(nil)
	end)
	local entry = scope:Computed(function(use): HudLayout.Entry?
		local now = use(live)
		if now then
			return now
		end
		local layout = use(saved)
		local e = if type(layout) == "table" then layout[ELEMENT] else nil
		return if type(e) == "table" and type(e.x) == "number" and type(e.y) == "number" then e else nil
	end)
	local width = scope:Computed(function(use): number
		local e = use(entry)
		return if e and e.w then e.w else WIDTH
	end)
	-- the built-in place: under the menu, lower by the panels standing above it
	local defaultTop = scope:Computed(function(use): number
		local offset = if props and props.Offset then use(props.Offset) else 0
		-- owner 2026-10-20: the menu has two rows (Hud Menu), so the tracker starts one button row lower
		return 400 + Theme.Size.IconButton + Theme.Padding.Small + offset
	end)
	local corner = scope:Computed(function(use): Vector2?
		local e = use(entry)
		if not e then
			return nil
		end
		local screen = use(Scale.VirtualSize)
		local x, y = HudLayout.place(e, use(width), screen.X, screen.Y)
		return Vector2.new(x, y)
	end)
	local contentHeight = scope:Value(0)
	local bodyHeight = scope:Computed(function(use): number
		if use(collapsed) then
			return 0
		end
		local e = use(entry)
		local chrome = PAD_TOP + HEADER + GAP + PAD_BOTTOM
		if e and e.h then
			-- a sized tracker keeps its height (the list scrolls inside)
			return math.max(0, e.h - chrome)
		end
		local screen = use(Scale.VirtualSize)
		local at = use(corner)
		local top = if at then at.Y else use(defaultTop)
		return math.min(use(contentHeight), math.max(80, screen.Y - top - 24 - chrome))
	end)

	-- S156: the grips. A drag starts on the header grip ("move") or the corner ("size") and follows the mouse or finger.
	local root: Frame? = nil
	local drag: { mode: string, start: Vector2, x: number, y: number, w: number, h: number }? = nil
	local function begin(mode: string, input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local frame = root
		local parent = frame and frame.Parent
		if not frame or not parent or not parent:IsA("GuiObject") then
			return
		end
		local k = Scale.get()
		local at = (frame.AbsolutePosition - parent.AbsolutePosition) / k
		local size = frame.AbsoluteSize / k
		drag = {
			mode = mode,
			start = Vector2.new(input.Position.X, input.Position.Y),
			x = at.X,
			y = at.Y,
			w = size.X,
			h = size.Y,
		}
	end
	table.insert(
		scope,
		UserInputService.InputChanged:Connect(function(input)
			local d = drag
			local kind = input.UserInputType
			if not d or (kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch) then
				return
			end
			local delta = (Vector2.new(input.Position.X, input.Position.Y) - d.start) / Scale.get()
			local screen = Fusion.peek(Scale.VirtualSize)
			if d.mode == "size" then
				local w, h = HudLayout.clampSize(ELEMENT, d.w + delta.X, d.h + delta.Y)
				live:set(HudLayout.entryAt(d.x, d.y, screen.X, screen.Y, w, h))
			else
				local e = Fusion.peek(entry)
				local w, h = if e and e.w and e.h then e.w else nil, if e and e.h then e.h else nil
				live:set(HudLayout.entryAt(d.x + delta.X, d.y + delta.Y, screen.X, screen.Y, w, h))
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input)
			local kind = input.UserInputType
			if not drag or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then
				return
			end
			drag = nil
			local now = Fusion.peek(live)
			if now then
				Net.Send("SetSetting", "hud", HudLayout.with(Fusion.peek(saved), ELEMENT, now))
			end
		end)
	)

	local frame = scope:New("Frame")({
		Name = "QuestTracker",
		AnchorPoint = scope:Computed(function(use): Vector2
			return if use(corner) then Vector2.zero else Vector2.new(1, 0)
		end),
		Position = scope:Computed(function(use): UDim2
			local at = use(corner)
			if at then
				return UDim2.fromOffset(at.X, at.Y)
			end
			return UDim2.new(1, -Theme.Padding.Large, 0, use(defaultTop))
		end),
		Size = scope:Computed(function(use): UDim2
			local body = use(bodyHeight)
			local height = PAD_TOP + HEADER + PAD_BOTTOM + (if use(collapsed) then 0 else GAP + body)
			return UDim2.fromOffset(use(width), height)
		end),
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, PAD_TOP),
				PaddingBottom = UDim.new(0, PAD_BOTTOM),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, HEADER),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("TextButton")({
						Name = "MoveGrip",
						Size = UDim2.fromOffset(GRIP, HEADER),
						BackgroundTransparency = 1,
						Text = "≡",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Iron.TextMuted,
						AutoButtonColor = false,
						[OnEvent("InputBegan")] = function(input: InputObject)
							begin("move", input)
						end,
					}),
					scope:New("TextButton")({
						Position = UDim2.fromOffset(GRIP, 0),
						Size = UDim2.new(1, -(74 + GRIP), 1, 0),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return `{if use(collapsed) then "▸" else "▾"} {Text.get(use, "quest.tracker")}`
						end),
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Iron.Heading,
						TextXAlignment = Enum.TextXAlignment.Left,
						[OnEvent("Activated")] = function()
							collapsed:set(not Fusion.peek(collapsed))
						end,
					}),
					scope:New("TextButton")({
						Name = "Guide",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -34, 0.5, 0),
						Size = UDim2.fromOffset(30, 28),
						BackgroundColor3 = Theme.Iron.Raised,
						BackgroundTransparency = 0.2,
						Text = "➤",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Brass.Bright,
						Visible = scope:Computed(function(use): boolean
							local target = use(QuestTrack.Target)
							return props ~= nil and props.Guide ~= nil and target ~= nil and target.x ~= nil
						end),
						[OnEvent("Activated")] = function()
							local target = Fusion.peek(QuestTrack.Target)
							if props and props.Guide and target then
								props.Guide(target)
							end
						end,
						[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					}),
					scope:New("TextLabel")({
						Name = "Arrow",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(28, 28),
						BackgroundTransparency = 1,
						Text = "▲", -- W28: the glyph the tutorial hint draws too ("⬆" is not in Builder Sans)
						TextScaled = true,
						FontFace = Theme.Fonts.BodyBold,
						TextColor3 = Theme.Brass.Bright,
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
			scope:New("ScrollingFrame")({
				Name = "Body",
				Position = UDim2.fromOffset(0, HEADER + GAP),
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, use(bodyHeight))
				end),
				Visible = scope:Computed(function(use): boolean
					return not use(collapsed)
				end),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Iron.Rule,
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 3),
						[OnChange("AbsoluteContentSize")] = function(size: Vector2)
							contentHeight:set(size.Y / Scale.get())
						end,
					}),
					lines :: any,
					achLines :: any,
				},
			}),
			scope:New("TextButton")({
				Name = "SizeGrip",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 8, 1, PAD_BOTTOM),
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1,
				Text = "◢",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = Theme.Iron.TextMuted,
				AutoButtonColor = false,
				Visible = scope:Computed(function(use): boolean
					return not use(collapsed)
				end),
				[OnEvent("InputBegan")] = function(input: InputObject)
					begin("size", input)
				end,
			}),
		},
	}) :: Frame
	root = frame
	return frame
end

return QuestTracker
