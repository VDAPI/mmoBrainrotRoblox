--!strict
-- Dungeons on the client (DESIGN §16): the gate prompt and window (tag "DungeonEntrance"), the boss HP bar at
-- the top of the screen (state `boss`: name, phase, HP, time left, enrage / shield / stagger, S134: the bar of a channel
-- to break under it) and big centred
-- messages of the fight (BossAnnounce: countdown, phases, victory, wipe); the post-fight reward card with the
-- grind progress (S30, ShowReward from the CombatFx "reward" event; S149b: also the world boss's `WorldBossReward`). S103 (FABULA §2.3): when Morvane enters her last
-- phase and the player is on the story quest `morvane`, the same message speaks her true name a moment later (text
-- only: the fight does not change).
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): the boss bar stands
-- in the target band (Logic/TopBand.bossBar: 600..1320 x 22..134 at 1920 wide; a phone: min(720, W - 16) wide under
-- the target row, its rows folded to 64 tall); the fight's messages (BossAnnounce) are UI/Notify's alert line instead
-- of the big frame in the Toasts layer; the reward card is one of UI/Notify's cards (the PC corner) with the full card
-- behind 'Szczegóły'; the ready check is a prompt (Components/Prompt, Screens/ReadyCheck).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossReward = require(script.Parent.Parent.UI.Screens.BossReward)
local Device = require(script.Parent.Parent.UI.Device)
local BossScaling = require(ReplicatedStorage.Shared.Logic.BossScaling)
local LevelLock = require(ReplicatedStorage.Shared.Logic.LevelLock)
local ChannelBar = require(script.Parent.Parent.UI.Components.ChannelBar)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local DungeonWindow = require(script.Parent.Parent.UI.Screens.DungeonWindow)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local ReadyCheck = require(script.Parent.Parent.UI.Screens.ReadyCheck)
local Scale = require(script.Parent.Parent.UI.Scale)
local FightView = require(script.Parent.Parent.UI.FightView)
local HudGate = require(script.Parent.Parent.UI.HudGate)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Notify = require(script.Parent.Parent.UI.Notify)
local PhoneLayout = require(script.Parent.Parent.UI.PhoneLayout)
local Portals = require(ReplicatedStorage.Shared.Data.Portals)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local TopBand = require(ReplicatedStorage.Shared.Logic.TopBand)
local WorldLabel = require(script.Parent.Parent.UI.WorldLabel)

local Children = Fusion.Children

local DungeonController = {
	Name = "DungeonController",
	Deps = { "WindowManager", "UIController" },
}

local scope = Fusion.scoped(Fusion)
local WindowManager: any
local RegistryRef: any -- S134f: FightLogController ("Details" on the reward card), looked up lazily
local rewardCard: Notify.Handle? = nil
local rewardOpen = false -- the reward's full card ('Szczegóły') is open

local REWARD_SECONDS = 20
local ANNOUNCE_SECONDS = 3
local region = scope:Value(nil :: string?)

local function bossBar(): Instance
	local boss = State.Value({ "boss" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			now:set(Workspace:GetServerTimeNow())
		end)
	)
	local ratio = scope:Computed(function(use): number
		local b = use(boss)
		return if type(b) == "table" then math.clamp(b.hp / math.max(1, b.maxHp), 0, 1) else 0
	end)
	local animated = scope:Tween(ratio, TweenInfo.new(0.25))
	-- S134: the channel to break (`channel` = { id, endsAt, need, done }): its share done of the share needed
	local channel = scope:Computed(function(use): any
		local b = use(boss)
		return if type(b) == "table" and type(b.channel) == "table" then b.channel else nil
	end)
	-- where it stands (the HUD's layer): the target band, or under a phone's target row with its rows folded
	local phone = scope:Computed(function(use): boolean
		return use(PhoneLayout.Compact)
	end)
	local rect = scope:Computed(function(use): TopBand.Rect
		local size: Vector2 = use(Scale.HudSize)
		local device: TopBand.Device = if use(phone) then "phone" elseif use(Device.Touch) then "tablet" else "pc"
		return TopBand.bossBar(device, size.X, size.Y)
	end)
	local function pick<T>(pc: T, folded: T): Fusion.Computed<T>
		return scope:Computed(function(use): T
			return if use(phone) then folded else pc
		end)
	end
	return scope:New("Frame")({
		Name = "BossBar",
		Position = scope:Computed(function(use): UDim2
			local r = use(rect)
			return UDim2.fromOffset(r.left, r.top)
		end),
		Size = scope:Computed(function(use): UDim2
			local r = use(rect)
			return UDim2.fromOffset(r.right - r.left, r.bottom - r.top)
		end),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return type(use(boss)) == "table"
		end),
		[Children] = {
			scope:New("TextLabel")({
				Name = "Title",
				Size = pick(UDim2.new(1, 0, 0, 30), UDim2.new(1, -96, 0, 22)),
				TextXAlignment = pick(Enum.TextXAlignment.Center, Enum.TextXAlignment.Left),
				TextTruncate = Enum.TextTruncate.AtEnd,
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local b = use(boss)
					if type(b) ~= "table" then
						return ""
					end
					local tags = {}
					if b.enraged then
						table.insert(tags, Text.get(use, "boss.enraged"))
					end
					if b.shielded then
						table.insert(tags, Text.get(use, "boss.shielded"))
					end
					if b.staggered then
						table.insert(tags, Text.get(use, "boss.staggered"))
					end
					local suffix = if #tags > 0 then `  ·  {table.concat(tags, " · ")}` else ""
					return `{Text.get(use, b.nameKey)}  ·  {Text.get(use, "boss.phase", { phase = b.phase })}{suffix}`
				end),
				FontFace = Theme.Fonts.Display,
				TextSize = pick(Theme.TextSize.Large, Theme.TextSize.Small),
				TextColor3 = Theme.Brass.Bright,
				TextStrokeTransparency = 0.3,
			}),
			scope:New("Frame")({
				Name = "Health",
				Position = pick(UDim2.fromOffset(0, 32), UDim2.fromOffset(0, 24)),
				Size = pick(UDim2.new(1, 0, 0, 22), UDim2.new(1, 0, 0, 20)),
				BackgroundColor3 = Theme.Iron.Sunken,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
					scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = 1.5 }),
					scope:New("Frame")({
						Size = scope:Computed(function(use): UDim2
							return UDim2.fromScale(use(animated), 1)
						end),
						BackgroundColor3 = scope:Computed(function(use): Color3
							local b = use(boss)
							return if type(b) == "table" and b.shielded then Theme.Iron.Link else Theme.Iron.Danger
						end),
						[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local b = use(boss)
							return if type(b) == "table" then `{b.hp} / {b.maxHp}` else ""
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = pick(Theme.TextSize.Small, Theme.TextSize.Caption),
						TextColor3 = Theme.Iron.Text,
						TextStrokeTransparency = 0.3,
						ZIndex = 2,
					}),
				},
			}),
			-- S134: the channel bar (purple fill = damage dealt of the damage that breaks it, the time left);
			-- S149b: the shared component (also on the world boss panel)
			ChannelBar(scope, {
				Channel = channel,
				Now = now,
				Position = pick(UDim2.fromOffset(110, 86), UDim2.fromOffset(0, 46)),
				Size = pick(UDim2.new(1, -220, 0, 22), UDim2.new(1, 0, 0, 18)),
			}),
			-- The fight lasts at most Bosses.timeLimit; the time left turns yellow under 3 min and red under 1 min.
			-- A phone: at the right end of the title's row.
			scope:New("TextLabel")({
				Name = "TimeLeft",
				AnchorPoint = pick(Vector2.zero, Vector2.new(1, 0)),
				Position = pick(UDim2.fromOffset(0, 58), UDim2.fromScale(1, 0)),
				Size = pick(UDim2.new(1, 0, 0, 26), UDim2.fromOffset(96, 22)),
				TextXAlignment = pick(Enum.TextXAlignment.Center, Enum.TextXAlignment.Right),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local b = use(boss)
					if type(b) ~= "table" then
						return ""
					end
					local left = Time.format(Time.remaining(b.endsAt or 0, use(now)))
					return `⌛ {Text.get(use, "boss.timeLeft", { time = left })}`
				end),
				FontFace = Theme.Fonts.Display,
				TextSize = pick(Theme.TextSize.Large, Theme.TextSize.Small),
				TextColor3 = scope:Computed(function(use): Color3
					local b = use(boss)
					local left = if type(b) == "table" then Time.remaining(b.endsAt or 0, use(now)) else math.huge
					return if left <= 60
						then Theme.Iron.Danger
						elseif left <= 180 then Theme.Iron.Warning
						else Theme.Iron.Text
				end),
				TextStrokeTransparency = 0.25,
			}),
		},
	})
end

-- The fight's messages (countdown, phases, victory, wipe; S103 the story's line) on UI/Notify's alert line.
local function showAnnouncement(text: string)
	Notify.alert(text, ANNOUNCE_SECONDS)
end

-- S103: the story's line in the last phase of a boss, for a player on the story quest of that boss (boss id -> quest
-- id, text key); seconds after the phase message.
local STORY_NAME: { [string]: { quest: string, key: string } } =
	{ morvane = { quest = "morvane", key = "story.morvane.name" } }
local STORY_NAME_DELAY = 3.5

local function storyName(key: string)
	for bossId, story in STORY_NAME do
		local boss = Bosses.get(bossId)
		if boss and key == `boss.{bossId}.phase{#boss.phases + 1}` then
			if State.Get({ "character", "quests", "main", "id" }) == story.quest then
				task.delay(STORY_NAME_DELAY, function()
					showAnnouncement(Text.now(story.key))
				end)
			end
		end
	end
end

local function decorate(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	local gateRegion = model:GetAttribute("DungeonRegion")
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if type(gateRegion) ~= "string" or not anchor or anchor:FindFirstChild("VaelthornDungeon") then
		return
	end
	local def = Bosses.forRegion(gateRegion)
	if not def then
		return
	end
	-- W31: the gate's name on the same dark plate as the portals' (UI/WorldLabel), over the horns' caps
	local label = WorldLabel.new(
		anchor,
		"VaelthornDungeon",
		Portals.GATE.height - Portals.GATE.door.y + 2.5,
		90,
		Theme.Iron.Danger,
		Theme.Iron.Text
	)
	local title, sub = label.title, label.sub
	local prompt = Instance.new("ProximityPrompt")
	Keybinds.bindPrompt(prompt, "interact")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Portals.PROMPT_RANGE -- W28: the server checks from the same door
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	local function refresh()
		title.Text = Text.now(def.nameKey)
		sub.Text = Text.now("dungeon.levels", {
			level = def.level,
			required = BossScaling.requiredLevel(def.level),
			max = LevelLock.maxLevel(def.level), -- S157
		})
		prompt.ActionText = Text.now("dungeon.open")
		prompt.ObjectText = Text.now(def.nameKey)
	end
	refresh()
	scope:Observer(Text.Lang):onChange(refresh)
	prompt.Triggered:Connect(function()
		region:set(gateRegion)
		WindowManager.Close("dungeon")
		WindowManager.Open("dungeon")
	end)
end

-- Post-fight reward card (S30): one at a time, closes on OK or after REWARD_SECONDS. UI plan package B: the card's
-- summary in UI/Notify's card place, the full card behind its 'Szczegóły'.
function DungeonController.ShowReward(reward: BossReward.Reward)
	if rewardCard then
		rewardCard.close()
		rewardCard = nil
	end
	if reward.gotMyth or reward.gotLeg or reward.mount ~= nil or reward.mountSkin ~= nil then
		Sounds.play("levelUp")
	end
	-- S134f: "Details" of the full card opens the fight log (its summary arrives right after the card)
	local function openLog()
		local log = RegistryRef and RegistryRef.Get("FightLogController")
		if log then
			log.Open(1)
		end
	end
	local title, line, accent = BossReward.summary(reward)
	rewardCard = Notify.card({
		class = "bossReward",
		title = title,
		line = line,
		accent = accent,
		seconds = REWARD_SECONDS,
		details = function()
			rewardOpen = true
			Notify.details(function(s: Fusion.Scope<typeof(Fusion)>, close: () -> (), sheet: boolean): Instance
				table.insert(s, function()
					rewardOpen = false
				end)
				return BossReward.view(s, { Reward = reward, Close = close, OpenDetails = openLog, Sheet = sheet })
			end, REWARD_SECONDS * 3)
		end,
	})
end

-- S102: for CutsceneController: whether the post-fight reward card is on screen.
function DungeonController.RewardVisible(): boolean
	return rewardOpen or (rewardCard ~= nil and rewardCard.alive())
end

function DungeonController.Init(registry)
	RegistryRef = registry
	WindowManager = registry.Get("WindowManager")
	local UIController = registry.Get("UIController")
	WindowManager.Register({
		id = "dungeon",
		titleKey = "window.dungeon.title",
		size = Vector2.new(560, 520),
		build = function(s)
			return DungeonWindow(s, {
				Region = region,
				Close = function()
					WindowManager.Close("dungeon")
				end,
			})
		end,
	})
	bossBar().Parent = HudGate.Layer(UIController.GetLayer("Screens")) -- owner 2026-10-21: not over the loading screen
	ReadyCheck.watch(scope) -- S134f: the ready check at the gate (a prompt)
end

function DungeonController.Start()
	for _, instance in CollectionService:GetTagged("DungeonEntrance") do
		task.spawn(decorate, instance)
	end
	CollectionService:GetInstanceAddedSignal("DungeonEntrance"):Connect(function(instance)
		task.defer(decorate, instance)
	end)
	-- S149b: the world boss reward card (WorldBossService): the loot of a winner or the reason he got none
	Net.On("WorldBossReward", function(raw: any)
		if type(raw) ~= "table" or type(raw.boss) ~= "string" or not Bosses.get(raw.boss) then
			return
		end
		local reason = if raw.reason == "level"
				or raw.reason == "share"
				or raw.reason == "claimed"
			then raw.reason :: string
			else nil
		local items = if reason then nil else FightView.drop({ mine = raw.items })
		local best = 0
		if items then
			for _, item in items.mine do
				best = math.max(best, item.r)
			end
		end
		DungeonController.ShowReward({
			boss = raw.boss,
			world = true,
			reason = reason,
			minLevel = tonumber(raw.level),
			exp = tonumber(raw.exp),
			gold = tonumber(raw.gold),
			gotLeg = best == Rarities.LEGENDARY,
			gotMyth = best >= Rarities.MYTHIC,
			drop = items,
			share = tonumber(raw.share), -- S149c
			factor = tonumber(raw.f),
		})
	end)
	Net.On("BossAnnounce", function(key: string, args: { [string]: any }?)
		Sounds.play("levelUp")
		showAnnouncement(Text.now(key, args))
		storyName(key)
	end)
end

return DungeonController
