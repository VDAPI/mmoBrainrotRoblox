--!strict
-- Dungeons on the client (DESIGN §16): the gate prompt and window (tag "DungeonEntrance"), the boss HP bar at
-- the top of the screen (state `boss`: name, phase, HP, time left, enrage / shield / stagger, S134: the bar of a channel
-- to break under it) and big centred
-- messages of the fight (BossAnnounce: countdown, phases, victory, wipe); the post-fight reward card with the
-- grind progress (S30, ShowReward from the CombatFx "reward" event; S149b: also the world boss's `WorldBossReward`). S103 (FABULA §2.3): when Morvane enters her last
-- phase and the player is on the story quest `morvane`, the same message speaks her true name a moment later (text
-- only: the fight does not change).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossReward = require(script.Parent.Parent.UI.Screens.BossReward)
local BossScaling = require(ReplicatedStorage.Shared.Logic.BossScaling)
local LevelLock = require(ReplicatedStorage.Shared.Logic.LevelLock)
local ChannelBar = require(script.Parent.Parent.UI.Components.ChannelBar)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local DungeonWindow = require(script.Parent.Parent.UI.Screens.DungeonWindow)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local ReadyCheckScreen = require(script.Parent.Parent.UI.Screens.ReadyCheck)
local FightView = require(script.Parent.Parent.UI.FightView)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

local DungeonController = {
	Name = "DungeonController",
	Deps = { "WindowManager", "UIController" },
}

local scope = Fusion.scoped(Fusion)
local WindowManager: any
local UIControllerRef: any
local RegistryRef: any -- S134f: FightLogController ("Details" on the reward card), looked up lazily
local rewardScope: Fusion.Scope<typeof(Fusion)>? = nil

local REWARD_SECONDS = 20
local region = scope:Value(nil :: string?)
local announceText = scope:Value("")
local announceAlpha = scope:Value(1)

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
	return scope:New("Frame")({
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(720, 112),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return type(use(boss)) == "table"
		end),
		[Children] = {
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 30),
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
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Brass.Bright,
				TextStrokeTransparency = 0.3,
			}),
			scope:New("Frame")({
				Position = UDim2.fromOffset(0, 32),
				Size = UDim2.new(1, 0, 0, 22),
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
						TextSize = Theme.TextSize.Small,
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
				Position = UDim2.fromOffset(110, 86),
				Size = UDim2.new(1, -220, 0, 22),
			}),
			-- The fight lasts at most Bosses.timeLimit; the time left turns yellow under 3 min and red under 1 min.
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(0, 58),
				Size = UDim2.new(1, 0, 0, 26),
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
				TextSize = Theme.TextSize.Large,
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

local function announcer(): Instance
	return scope:New("TextLabel")({
		Name = "BossAnnounce",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(1000, 70),
		BackgroundTransparency = 1,
		Text = announceText,
		TextWrapped = true,
		FontFace = Theme.Fonts.Display,
		TextSize = Theme.TextSize.Title + 10,
		TextColor3 = Theme.Brass.Bright,
		TextStrokeTransparency = scope:Computed(function(use): number
			return 0.2 + use(announceAlpha) * 0.8
		end),
		TextTransparency = announceAlpha,
	})
end

local function showAnnouncement(text: string)
	announceText:set(text)
	announceAlpha:set(0)
	local token = os.clock()
	DungeonController._announceToken = token
	task.delay(3, function()
		if DungeonController._announceToken ~= token then
			return
		end
		local steps = 10
		for i = 1, steps do
			task.wait(0.05)
			if DungeonController._announceToken ~= token then
				return
			end
			announceAlpha:set(i / steps)
		end
	end)
end
DungeonController._announceToken = 0

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
	local gui = Instance.new("BillboardGui")
	gui.Name = "VaelthornDungeon"
	gui.Size = UDim2.fromOffset(300, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = anchor
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 32)
	title.BackgroundTransparency = 1
	title.FontFace = Theme.Fonts.Display
	title.TextSize = Theme.TextSize.Large
	title.TextColor3 = Theme.Iron.Danger
	title.TextStrokeTransparency = 0.3
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromOffset(0, 32)
	sub.Size = UDim2.new(1, 0, 0, 24)
	sub.BackgroundTransparency = 1
	sub.FontFace = Theme.Fonts.BodyBold
	sub.TextSize = Theme.TextSize.Small
	sub.TextColor3 = Theme.Iron.Text
	sub.TextStrokeTransparency = 0.3
	sub.Parent = gui
	local prompt = Instance.new("ProximityPrompt")
	Keybinds.bindPrompt(prompt, "interact")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
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

-- Post-fight reward card (S30): one at a time, closes on OK or after REWARD_SECONDS.
function DungeonController.ShowReward(reward: BossReward.Reward)
	if rewardScope then
		Fusion.doCleanup(rewardScope)
		rewardScope = nil
	end
	local inner = scope:innerScope()
	rewardScope = inner
	local function close()
		if rewardScope == inner then
			rewardScope = nil
			Fusion.doCleanup(inner)
		end
	end
	if reward.gotMyth or reward.gotLeg or reward.mount ~= nil or reward.mountSkin ~= nil then
		Sounds.play("levelUp")
	end
	BossReward(inner, {
		Reward = reward,
		Close = close,
		-- S134f: "Details" opens the fight log (its summary arrives right after the card)
		OpenDetails = function()
			local log = RegistryRef and RegistryRef.Get("FightLogController")
			if log then
				log.Open(1)
			end
		end,
	}).Parent =
		UIControllerRef.GetLayer("Toasts")
	task.delay(REWARD_SECONDS, close)
end

-- S102: for CutsceneController: whether the post-fight reward card is on screen.
function DungeonController.RewardVisible(): boolean
	return rewardScope ~= nil
end

function DungeonController.Init(registry)
	RegistryRef = registry
	WindowManager = registry.Get("WindowManager")
	local UIController = registry.Get("UIController")
	UIControllerRef = UIController
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
	bossBar().Parent = UIController.GetLayer("Screens")
	announcer().Parent = UIController.GetLayer("Toasts")
	ReadyCheckScreen(scope).Parent = UIController.GetLayer("Toasts") -- S134f: the ready check at the gate
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
		})
	end)
	Net.On("BossAnnounce", function(key: string, args: { [string]: any }?)
		Sounds.play("levelUp")
		showAnnouncement(Text.now(key, args))
		storyName(key)
	end)
end

return DungeonController
