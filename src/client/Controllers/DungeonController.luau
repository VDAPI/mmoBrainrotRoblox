--!strict
-- Dungeons on the client (DESIGN §16): the gate prompt and window (tag "DungeonEntrance"), the boss HP bar at
-- the top of the screen (state `boss`: name, phase, HP, time left, enrage / shield) and big centred
-- messages of the fight (BossAnnounce: countdown, phases, victory, wipe).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local DungeonWindow = require(script.Parent.Parent.UI.Screens.DungeonWindow)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
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
	return scope:New("Frame")({
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(720, 74),
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
					local suffix = if #tags > 0 then `  ·  {table.concat(tags, " · ")}` else ""
					return `{Text.get(use, b.nameKey)}  ·  {Text.get(use, "boss.phase", { phase = b.phase })}{suffix}`
				end),
				FontFace = Theme.Fonts.Heading,
				TextSize = 24,
				TextColor3 = Theme.Colors.GoldBright,
				TextStrokeTransparency = 0.3,
			}),
			scope:New("Frame")({
				Position = UDim2.fromOffset(0, 32),
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundColor3 = Theme.Colors.Background,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
					scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 1.5 }),
					scope:New("Frame")({
						Size = scope:Computed(function(use): UDim2
							return UDim2.fromScale(use(animated), 1)
						end),
						BackgroundColor3 = scope:Computed(function(use): Color3
							local b = use(boss)
							return if type(b) == "table" and b.shielded
								then Theme.Colors.Accent
								else Theme.Colors.Danger
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
						TextSize = 15,
						TextColor3 = Theme.Colors.Text,
						TextStrokeTransparency = 0.3,
						ZIndex = 2,
					}),
				},
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local b = use(boss)
					if type(b) ~= "table" then
						return ""
					end
					return `⌛ {Time.format(Time.remaining(b.endsAt or 0, use(now)))}`
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 15,
				TextColor3 = Theme.Colors.Parchment,
				TextStrokeTransparency = 0.4,
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
		FontFace = Theme.Fonts.Heading,
		TextSize = 40,
		TextColor3 = Theme.Colors.GoldBright,
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
	title.FontFace = Theme.Fonts.Heading
	title.TextSize = 26
	title.TextColor3 = Theme.Colors.DangerHover
	title.TextStrokeTransparency = 0.3
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromOffset(0, 32)
	sub.Size = UDim2.new(1, 0, 0, 24)
	sub.BackgroundTransparency = 1
	sub.FontFace = Theme.Fonts.BodyBold
	sub.TextSize = 18
	sub.TextColor3 = Theme.Colors.Parchment
	sub.TextStrokeTransparency = 0.3
	sub.Parent = gui
	local prompt = Instance.new("ProximityPrompt")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	local function refresh()
		title.Text = Text.now(def.nameKey)
		sub.Text = Text.now("dungeon.levels", { level = def.level, required = def.level - 5 })
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

function DungeonController.Init(registry)
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
	bossBar().Parent = UIController.GetLayer("Screens")
	announcer().Parent = UIController.GetLayer("Toasts")
end

function DungeonController.Start()
	for _, instance in CollectionService:GetTagged("DungeonEntrance") do
		task.spawn(decorate, instance)
	end
	CollectionService:GetInstanceAddedSignal("DungeonEntrance"):Connect(function(instance)
		task.defer(decorate, instance)
	end)
	Net.On("BossAnnounce", function(key: string, args: { [string]: any }?)
		Sounds.play("levelUp")
		showAnnouncement(Text.now(key, args))
	end)
end

return DungeonController
