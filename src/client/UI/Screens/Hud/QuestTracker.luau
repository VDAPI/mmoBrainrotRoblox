--!strict
-- Quest tracker (DESIGN §20, right side under the minimap): the tracked side quest (S27, QuestTrack.Focus) and the
-- main quest with their objectives and an arrow towards the tracked one's target (an NPC or a place on this map, or the portal leading to the target map), plus the
-- daily contracts. The header collapses it. Elite II timers moved to Hud/Elite2Timer (FIX 2026-10-09). S99: the hunting
-- contract between the story and the daily contracts (on top with the arrow when tracked; the next one to take with
-- "From: Contract board"; nothing while waiting for a level or after the 99th; S134k: up to three active ones and "+N").
-- S101b: targets follow the saved
-- answers (QuestText `quests`), and a quest with a companion shows "<NPC> is waiting for you" / "went back".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AreaState = require(script.Parent.Parent.Parent.AreaState)
local Config = require(ReplicatedStorage.Shared.Config)
local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MapRoute = require(ReplicatedStorage.Shared.Logic.MapRoute)
local MapSketch = require(script.Parent.Parent.Parent.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestRows = require(ReplicatedStorage.Shared.Logic.QuestRows)
local QuestText = require(script.Parent.Parent.Parent.QuestText)
local QuestTrack = require(script.Parent.Parent.Parent.QuestTrack)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local WIDTH = 300
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
}

local function QuestTracker(scope: Scope, props: Props?): Instance
	local quests = State.Value({ "character", "quests" })
	local collapsed = scope:Value(false)
	-- S29: which objective rows were already seen done and when their pulse ends; kept outside the Computed, so a
	-- recompute (progress, language) does not pulse them again.
	local seen: QuestRows.Seen = {}
	local pulseUntil: { [string]: number } = {}
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
				Theme.Iron.Heading,
				Theme.TextSize.Small,
				Theme.Fonts.BodyBold
			)
			for _, entry in open do
				local done = entry.progress >= entry.objective.n
				line(
					Text.get(use, `daily.{entry.template}.title`),
					if done then Theme.Iron.Success else Theme.Iron.Text,
					Theme.TextSize.Small,
					Theme.Fonts.BodyMedium,
					4
				)
				line(
					`{if done then "✔" else "◦"} {QuestText.objective(use, entry.objective, entry.progress)}`,
					if done then Theme.Iron.Success else Theme.Iron.Text,
					Theme.TextSize.Small,
					Theme.Fonts.Body,
					10
				)
			end
		end
		return list
	end)

	return scope:New("Frame")({
		Name = "QuestTracker",
		AnchorPoint = Vector2.new(1, 0),
		Position = scope:Computed(function(use): UDim2
			local offset = if props and props.Offset then use(props.Offset) else 0
			return UDim2.new(1, -Theme.Padding.Large, 0, 400 + offset)
		end),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
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
						Size = UDim2.new(1, -74, 1, 0),
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
						Text = "⬆",
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
			lines :: any,
		},
	})
end

return QuestTracker
