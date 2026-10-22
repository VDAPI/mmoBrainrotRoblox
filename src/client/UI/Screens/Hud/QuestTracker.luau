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
-- Owner 2026-10-21 (the tracker took ~40 % of the screen): groups under a header with an arrow (Quests, Hunting
-- contracts, Daily, Weekly, Achievements) that fold, remembered on the account (Logic/TrackerFold,
-- account.settings.trackerFold); one line per entry (name, progress on the right), the full text in its tooltip, a
-- click unfolds an entry's objectives (the story and the tracked side quest start unfolded).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local GuidePointer = require(ReplicatedStorage.Shared.Logic.GuidePointer)
local HudDrag = require(script.Parent.Parent.Parent.HudDrag)
local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
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
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)
local TrackerFold = require(ReplicatedStorage.Shared.Logic.TrackerFold)

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
-- Owner 2026-10-21: one line per entry, group headers (PC / touch heights), the indent of an unfolded entry's lines
local ROW_PC, ROW_TOUCH = 22, 28
local GROUP_PC, GROUP_TOUCH = 22, 30
local INDENT = 12
local LONG_PRESS = 0.45 -- Components/Tooltip: a touch held this long shows the tooltip

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

-- Owner 2026-10-21 (the tracker took ~40 % of the screen): one entry of a group, a single line: the mark and name
-- (cut at the end), the progress on the right and "▸" / "▾" when it unfolds (its objectives, "Return to" with ➤).
export type Entry = {
	key: string, -- its id (pulse and unfolded state)
	text: string, -- mark and name
	progress: string?,
	color: Color3,
	tip: string, -- the full text (tooltip: hover on PC, long press on touch)
	pulse: string?, -- the pulse key of the whole entry (it turned done)
	body: (() -> ())?, -- the lines under it while unfolded (a click on the entry folds and unfolds it)
	openFirst: boolean?, -- unfolded until the player folds it
}

-- Entries unfolded or folded by the player this session (key -> open).
local openRows: { [string]: boolean } = {}

local function QuestTracker(scope: Scope, props: Props?): Instance
	local quests = State.Value({ "character", "quests" })
	-- Owner 2026-10-21: the folded groups (Logic/TrackerFold, account.settings.trackerFold); a click shows its result at
	-- once (`liveFold`) and keeps it until the save comes back.
	local savedFold = State.Value({ "account", "settings", "trackerFold" })
	local liveFold = scope:Value(nil :: { [string]: boolean }?)
	scope:Observer(savedFold):onChange(function()
		local live = Fusion.peek(liveFold)
		if live and TrackerFold.same(live, Fusion.peek(savedFold)) then
			liveFold:set(nil)
		end
	end)
	local fold = scope:Computed(function(use): any
		local live = use(liveFold)
		return if live then live else use(savedFold)
	end)
	local function toggleFold(group: string)
		local now = Fusion.peek(fold)
		local nextFold = TrackerFold.with(now, group, not TrackerFold.isFolded(now, group))
		liveFold:set(nextFold)
		Net.Send("SetSetting", "trackerFold", nextFold)
	end
	local collapsed = scope:Computed(function(use): boolean
		return TrackerFold.isFolded(use(fold), "all")
	end)
	-- bumped when the player folds or unfolds one entry (openRows)
	local openTick = scope:Value(0)
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

	-- Owner 2026-10-21: a group header with its arrow, the name and a short summary on the right ("2/5 · 5:12"); a
	-- click folds or unfolds the group. Returns whether the group is open.
	local function groupHeader(
		s: Scope,
		out: { Instance },
		order: number,
		group: string,
		label: string,
		summary: string?,
		touch: boolean,
		foldNow: any
	): boolean
		local isFolded = TrackerFold.isFolded(foldNow, group)
		table.insert(
			out,
			s:New("TextButton")({
				Name = `Group_{group}`,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, if touch then GROUP_TOUCH else GROUP_PC),
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Text = "",
				[OnEvent("Activated")] = function()
					toggleFold(group)
				end,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Bottom,
						Padding = UDim.new(0, 6),
					}),
					s:New("TextLabel")({
						Name = "Name",
						LayoutOrder = 1,
						Size = UDim2.fromScale(0, 1),
						BackgroundTransparency = 1,
						Text = `{if isFolded then "▸" else "▾"} {label}`,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Iron.Heading,
						TextStrokeTransparency = 0.5,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Bottom,
						TextTruncate = Enum.TextTruncate.AtEnd,
						[Children] = s:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Fill }),
					}),
					if summary and summary ~= ""
						then s:New("TextLabel")({
							Name = "Summary",
							LayoutOrder = 2,
							Size = UDim2.fromScale(0, 1),
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							Text = summary,
							FontFace = Theme.Fonts.BodyMedium,
							TextSize = Theme.TextSize.Caption,
							TextColor3 = Theme.Iron.TextMuted,
							TextStrokeTransparency = 0.5,
							TextYAlignment = Enum.TextYAlignment.Bottom,
						}) :: any
						else nil,
				},
			})
		)
		return not isFolded
	end

	-- One block per group (owner 2026-10-21, before: S18 blocks with every objective): the story and the tracked side
	-- quest, the hunting contracts, the daily and the weekly set, each under its folding header; one line per entry.
	local lines = scope:Computed(function(use, s: Scope): { Instance }
		local q = use(quests)
		local list = {}
		if type(q) ~= "table" or use(collapsed) then
			return list
		end
		local foldNow = use(fold)
		use(openTick)
		local touch = use(Device.Touch)
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
					Size = UDim2.new(1, 0, 0, 4),
					BackgroundTransparency = 1,
				})
			)
		end
		local function group(id: string, label: string, summary: string?): boolean
			if order > 0 then
				gap()
			end
			order += 1
			return groupHeader(s, list, order, id, label, summary, touch, foldNow)
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
					INDENT
				)
			end
		end
		-- S29: a finished line keeps a soft green glow; it pulses once (stronger stroke, white to green) while its pulse
		-- time runs
		local function glow(label: TextLabel, pulseKey: string)
			local clockNow = os.clock()
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
						TweenService:Create(stroke, info, { Thickness = 1, Transparency = GLOW_TRANSPARENCY }):Play()
						TweenService:Create(label, info, { TextColor3 = Theme.Iron.Success }):Play()
					end
				end)
			end
		end
		-- S29: the rows that turned done since the last build pulse (also while their entry is folded, so unfolding it
		-- later does not pulse old ones); the entry itself pulses when the last one is done.
		local function track(key: string, rowList: QuestRows.List)
			local clockNow = os.clock()
			local fresh = QuestRows.newlyDone(seen, key, rowList)
			for _, index in fresh do
				pulseUntil[`{key}#{index}`] = clockNow + PULSE_TIME
			end
			if #fresh > 0 and rowList.complete then
				pulseUntil[`{key}#all`] = clockNow + PULSE_TIME
			end
		end

		-- S29: every objective stays in the list (Logic/QuestRows); finished ones are green with a soft glow and
		-- pulse once when finished; a complete quest adds the gold "Return to: <NPC>" line with its own guide button.
		local function objectives(key: string, rowList: QuestRows.List, guide: QuestTrack.Target?)
			for _, row in rowList.rows do
				local label = line(
					QuestRows.line(row),
					if row.done then Theme.Iron.Success else Theme.Iron.Text,
					Theme.TextSize.Small,
					Theme.Fonts.BodyMedium,
					INDENT
				)
				if row.done then
					glow(label, `{key}#{row.index}`)
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
								s:New("UIPadding")({ PaddingLeft = UDim.new(0, INDENT) }),
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

		-- one entry: a single line; a click on an entry with a body folds / unfolds it (openRows, this session)
		local function entry(e: Entry)
			order += 1
			local key = e.key
			local isOpen = e.body ~= nil and (if openRows[key] ~= nil then openRows[key] else e.openFirst == true)
			local hasBody = e.body ~= nil
			local name = s:New("TextLabel")({
				Name = "Name",
				LayoutOrder = 1,
				Size = UDim2.fromScale(0, 1),
				BackgroundTransparency = 1,
				Text = e.text,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = e.color,
				TextStrokeTransparency = 0.5,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				[Children] = s:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Fill }),
			}) :: TextLabel
			if e.pulse then
				glow(name, e.pulse)
			end
			-- touch: a long press shows the tooltip, so its release does not fold the entry
			local pressedAt: number? = nil
			local row = s:New("TextButton")({
				Name = key,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, if touch then ROW_TOUCH else ROW_PC),
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Text = "",
				[OnEvent("InputBegan")] = function(input: InputObject)
					pressedAt = if input.UserInputType == Enum.UserInputType.Touch then os.clock() else nil
				end,
				[OnEvent("Activated")] = function()
					local heldFor = if pressedAt then os.clock() - pressedAt else 0
					pressedAt = nil
					if hasBody and heldFor < LONG_PRESS then
						openRows[key] = not isOpen
						openTick:set(Fusion.peek(openTick) + 1)
					end
				end,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
					}),
					name,
					if e.progress and e.progress ~= ""
						then s:New("TextLabel")({
							Name = "Progress",
							LayoutOrder = 2,
							Size = UDim2.fromScale(0, 1),
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							Text = e.progress,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if e.progress == QuestRows.DONE_MARK
								then Theme.Iron.Success
								else Theme.Brass.Bright,
							TextStrokeTransparency = 0.5,
						}) :: any
						else nil,
					if hasBody
						then s:New("TextLabel")({
							Name = "Fold",
							LayoutOrder = 3,
							Size = UDim2.new(0, 12, 1, 0),
							BackgroundTransparency = 1,
							Text = if isOpen then "▾" else "▸",
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Caption,
							TextColor3 = Theme.Iron.TextMuted,
						}) :: any
						else nil,
				},
			}) :: TextButton
			Tooltip.attach(s, row, e.tip)
			table.insert(list, row)
			if isOpen and e.body then
				e.body()
			end
		end

		-- S27: the tracked side quest first.
		local level = use(State.Value({ "character", "level" })) or 1
		local focus = use(QuestTrack.Focus)

		-- S99: the hunting contracts. S134k: up to Config.Quest.trackerContracts active contracts in the tracker's order
		-- (the tracked one, the finished ones, the nearest on this map; QuestText.contractOrder), "+N" under them; none
		-- active: how many to take. Owner 2026-10-21: one line each, the monster kind and the kills.
		local contractState = Contracts.stateOf(q)
		local function contractBlock()
			local map = use(State.Value({ "character", "location", "map" }))
			-- the nearest-ground order follows the player: re-sorted on entering another monster area
			use(AreaState.Current)
			local x, z = QuestText.mapPosition()
			local focusId = if focus and focus.kind == "contract" then focus.id else nil
			local taken = QuestText.contractOrder(contractState, focusId, map, x, z)
			if #taken > 0 then
				local finished = 0
				for _, t in taken do
					if Contracts.isTakenComplete(t) then
						finished += 1
					end
				end
				if not group("contracts", Text.get(use, "tracker.group.contracts"), `{finished}/{#taken}`) then
					return
				end
				local lookup = function(key: string, args: { [string]: any }?): string
					return Text.get(use, key, args)
				end
				local shown = math.min(#taken, Config.Quest.trackerContracts)
				for i = 1, shown do
					local t = taken[i]
					local target = QuestText.contractTarget(t.contract, t.entry, level, map)
					local turnIn = if target and target.npc then target.npc else Contracts.BOARD
					local key = `contract:{t.contract.id}`
					local rowList = QuestText.rows(use, t.contract.objectives, t.entry.progress, turnIn)
					track(key, rowList)
					local tip = { QuestText.contractTitle(lookup, t.contract) }
					for _, row in rowList.rows do
						table.insert(tip, QuestRows.line(row))
					end
					local back = if rowList.complete then QuestText.returnTo(use, rowList) else ""
					table.insert(tip, if back ~= "" then back else Text.get(use, "contract.whereTurnIn.short"))
					entry({
						key = key,
						text = `◈ {QuestText.contractMonster(lookup, t.contract)}`,
						progress = QuestRows.compact(rowList),
						color = if rowList.complete then Theme.Iron.Success else Theme.Iron.Text,
						tip = table.concat(tip, "\n"),
						pulse = if rowList.complete then `{key}#all` else nil,
						body = function()
							objectives(key, rowList, target)
						end,
					})
				end
				if #taken > shown then
					line(
						Text.get(use, "tracker.contracts.more", { n = #taken - shown }),
						Theme.Iron.TextMuted,
						Theme.TextSize.Caption,
						Theme.Fonts.Body,
						INDENT
					)
				end
				return
			end
			local eligible = Contracts.eligible(contractState, level)
			if #eligible > 0 then
				if not group("contracts", Text.get(use, "tracker.group.contracts"), nil) then
					return
				end
				local from = Text.get(use, "quest.tracker.from", { npc = npcName(Contracts.BOARD) })
				entry({
					key = "contract:toTake",
					text = `! {Text.get(use, "tracker.contracts.toTake")}`,
					progress = tostring(#eligible),
					color = Theme.Brass.Bright,
					tip = `{Text.get(use, "contract.toTake", { n = #eligible })}\n{from}`,
				})
			end
		end
		local contractOnTop = focus ~= nil and focus.kind == "contract"
		if contractOnTop then
			contractBlock()
		end

		-- the story and the tracked side quest: one entry each, unfolded at first (their objectives say what to do)
		local questEntries: { Entry } = {}
		local sideQuest = if focus and focus.id then Quests.npcQuest(focus.id) else nil
		local sideEntry = if focus and focus.id then SideQuests.activeOf(q)[focus.id] else nil
		if sideQuest and type(sideEntry) == "table" then
			local key = `side:{sideQuest.id}`
			local rowList = QuestText.rows(use, sideQuest.objectives, sideEntry.progress, sideQuest.turnIn)
			track(key, rowList)
			local title = Text.get(use, `quest.{sideQuest.id}.title`)
			local tip = { title }
			for _, row in rowList.rows do
				table.insert(tip, QuestRows.line(row))
			end
			local quest = sideQuest
			table.insert(questEntries, {
				key = key,
				text = `◆ {title}`,
				progress = QuestRows.compact(rowList),
				color = if rowList.complete then Theme.Iron.Success else Theme.Brass.Bright,
				tip = table.concat(tip, "\n"),
				pulse = if rowList.complete then `{key}#all` else nil,
				openFirst = true,
				body = function()
					objectives(key, rowList, QuestText.sideTarget(quest, sideEntry, level, q))
					companionLine(quest.id)
				end,
			})
		end

		local main = q.main
		local quest = if type(main) == "table" then Quests.Main.get(main.id) else nil
		if quest and main and use(QuestTrack.Tracked) then
			local key = `main:{quest.id}`
			local rowList = QuestText.rows(use, quest.objectives, main.progress, quest.turnIn)
			track(key, rowList)
			local title = Text.get(use, `quest.{quest.id}.title`)
			local tip = { title, Text.get(use, "quest.tracker.from", { npc = npcName(quest.giver) }) }
			for _, row in rowList.rows do
				table.insert(tip, QuestRows.line(row))
			end
			table.insert(questEntries, {
				key = key,
				text = title,
				progress = QuestRows.compact(rowList),
				color = if rowList.complete then Theme.Iron.Success else Theme.Brass.Bright,
				tip = table.concat(tip, "\n"),
				pulse = if rowList.complete then `{key}#all` else nil,
				openFirst = true,
				body = function()
					objectives(key, rowList, QuestText.target(quest, main.progress or {}, level, q, main.used))
					companionLine(quest.id)
				end,
			})
		elseif not quest then
			local nextQuest, ready = QuestLogic.nextMain(q.mainDone or 0, level)
			if nextQuest and ready then
				local title = Text.get(use, `quest.{nextQuest.id}.title`)
				local from = Text.get(use, "quest.tracker.from", { npc = npcName(nextQuest.giver) })
				table.insert(questEntries, {
					key = `next:{nextQuest.id}`,
					text = `! {title}`,
					color = Theme.Brass.Bright,
					tip = `{title}\n{from}`,
					openFirst = true,
					body = function()
						line(from, Theme.Iron.TextMuted, Theme.TextSize.Small, Theme.Fonts.Body, INDENT)
					end,
				})
			end
		end
		if #questEntries > 0 and group("quests", Text.get(use, "tracker.group.quests"), nil) then
			for _, e in questEntries do
				entry(e)
			end
		end

		if not contractOnTop then
			contractBlock()
		end

		-- S159: the daily set (progress, countdown, open contracts) and the weekly set's progress; owner 2026-10-21: the
		-- open contracts of a set one line each (the label without its count, the count on the right), the weekly ones
		-- folded at first.
		local function setEntries(prefix: string, setList: any, progress: Dailies.SetProgress)
			if progress.complete >= progress.total then
				line(
					Text.get(use, "quest.tracker.collect"),
					Theme.Brass.Bright,
					Theme.TextSize.Small,
					Theme.Fonts.BodyMedium,
					INDENT
				)
				return
			end
			for i, setEntry in setList or {} do
				if not setEntry.claimed then
					local need = setEntry.objective.n
					local have = math.min(setEntry.progress, need)
					local done = have >= need
					local full = QuestText.objective(use, setEntry.objective, setEntry.progress)
					local label = QuestRows.withoutCount(full, have, need)
					entry({
						key = `{prefix}:{i}`,
						text = `{if done then QuestRows.DONE_MARK else QuestRows.OPEN_MARK} {label}`,
						progress = if done then QuestRows.DONE_MARK elseif need > 1 then `{have}/{need}` else "",
						color = if done then Theme.Iron.Success else Theme.Iron.Text,
						tip = full,
					})
				end
			end
		end
		local daily = q.daily
		local dailyList = if type(daily) == "table" then daily.list else nil
		local p = Dailies.progress(dailyList)
		if p.claimed < p.total then
			local t = use(minute) * 60
			local left = (Time.dayNumber(t) + 1) * 86400 - t
			local hh = math.floor(left / 3600)
			local mm = math.floor((left % 3600) / 60)
			local summary = `{p.complete}/{p.total} · {string.format("%d:%02d", hh, mm)}`
			if group("daily", Text.get(use, "tracker.group.daily"), summary) then
				setEntries("daily", dailyList, p)
			end
		end
		local weekly = q.weekly
		local weeklyList = if type(weekly) == "table" then weekly.list else nil
		local wp = Dailies.progress(weeklyList)
		if wp.claimed < wp.total then
			if group("weekly", Text.get(use, "tracker.group.weekly"), `{wp.complete}/{wp.total}`) then
				setEntries("weekly", weeklyList, wp)
			end
		end
		return list
	end)

	-- S151b: the tracked achievements under the quests (the list from AchievementView.trackedRows: no unknown, done or
	-- secret one; rebuilt when the track list changes, a row follows its own counter); owner 2026-10-21: under a folding
	-- header like the quest groups.
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
		local touch = use(Device.Touch)
		table.insert(
			out,
			s:New("Frame")({
				Name = "AchievementsGap",
				LayoutOrder = ACH_ORDER - 1,
				Size = UDim2.new(1, 0, 0, 4),
				BackgroundTransparency = 1,
			})
		)
		if
			not groupHeader(s, out, ACH_ORDER, "ach", Text.get(use, "ach.tracker"), tostring(#defs), touch, use(fold))
		then
			return out
		end
		local shown = #defs
		local rowHeight = if touch then Theme.Size.RowHeight else ACH_ROW
		if touch and not use(achOpen) then
			shown = math.min(shown, Config.Achievements.trackPhone)
		end
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

	-- S156: the saved place and size (UI/HudDrag: the entry being dragged until the save comes back)
	local function widthOf(use: Fusion.Use, e: HudLayout.Entry?): number
		return if e and e.w then e.w elseif use(PhoneLayout.Compact) then PhoneHud.TRACKER_WIDTH else WIDTH
	end
	local handle = HudDrag.new(scope, ELEMENT, widthOf)
	local entry = handle.entry
	local width = scope:Computed(function(use): number
		return widthOf(use, use(entry))
	end)
	local corner = handle.corner
	local contentHeight = scope:Value(0)
	local chrome = PAD_TOP + HEADER + GAP + PAD_BOTTOM
	-- the body of a tracker at `top` whose list may reach down to `floor` (a sized one keeps its height, the list
	-- scrolls inside; owner 2026-10-22: never past the floor, HudStack.trackerBody)
	local function bodyTo(use: Fusion.Use, top: number, floor: number): number
		local e = use(entry)
		return HudStack.trackerBody(top, floor, chrome, use(contentHeight), if e then e.h else nil)
	end
	-- the floor of a tracker moved to `at`: the bottom of the screen (a phone: of its stack), at least a few lines
	-- under its top, but above the corner's buttons in its lane (owner 2026-10-22: a tracker moved near its built-in
	-- place ran into the PvP toggle; HudStack.floorUnder)
	local function movedFloor(use: Fusion.Use, at: Vector2): number
		local screen = use(Scale.HudSize).Y - (if use(PhoneLayout.Compact) then PhoneHud.STACK_BOTTOM else 24)
		local bottom = math.max(at.Y + 80 + chrome, screen)
		return HudStack.floorUnder(at.X, at.X + use(width), at.Y, bottom, use(HudSlots.Corner))
	end
	-- owner 2026-10-21: the built-in place in the HUD column (UI/HudSlots): under the event panels, over the corner's
	-- buttons (PC) or the sprint row (touch); a moved tracker is in the panels' way instead (they go round it)
	local slot = HudSlots.join(
		scope,
		"questTracker",
		scope:Computed(function(use): HudSlots.Box
			local w = use(width)
			local folded = use(collapsed)
			local at = use(corner)
			if at then
				local body = if folded then 0 else bodyTo(use, at.Y, movedFloor(use, at))
				local h = PAD_TOP + HEADER + PAD_BOTTOM + (if folded then 0 else GAP + body)
				return { shown = true, w = w, h = h, custom = HudSlots.moved(at, w, h, 1) }
			end
			return { shown = true, w = w, h = if folded then PAD_TOP + HEADER + PAD_BOTTOM else HudStack.TRACKER_MIN }
		end)
	)
	local bodyHeight = scope:Computed(function(use): number
		if use(collapsed) then
			return 0
		end
		local at = use(corner)
		if at then
			return bodyTo(use, at.Y, movedFloor(use, at))
		end
		local place = use(slot)
		return if place then bodyTo(use, place.top, place.bottom) else 0
	end)
	local position = HudSlots.position(scope, slot)

	local frame = scope:New("Frame")({
		Name = "QuestTracker",
		AnchorPoint = Vector2.zero,
		Position = scope:Computed(function(use): UDim2
			local at = use(corner)
			return if at then UDim2.fromOffset(at.X, at.Y) else use(position)
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
							handle.begin("move", input)
						end,
					}),
					scope:New("TextButton")({
						Position = UDim2.fromOffset(GRIP, 0),
						Size = UDim2.new(1, -(74 + GRIP), 1, 0),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return `{if use(collapsed) then "▸" else "▾"} {Text.get(use, "tracker.title")}`
						end),
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Iron.Heading,
						TextXAlignment = Enum.TextXAlignment.Left,
						[OnEvent("Activated")] = function()
							toggleFold("all")
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
					handle.begin("size", input)
				end,
			}),
		},
	}) :: Frame
	handle.bind(frame)
	return frame
end

return QuestTracker
