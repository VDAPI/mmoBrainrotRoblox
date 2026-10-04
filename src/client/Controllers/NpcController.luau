--!strict
-- City NPCs on the client: localized nameplates with the service icon and a "Talk [E]" prompt on every NPC
-- model (attribute NpcId). Talking opens the dialog window; its buttons open the service windows (shop,
-- vault, forge, backpacks). Walking away closes them. Services from later sessions say "soon".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AlchemyWindow = require(script.Parent.Parent.UI.Screens.AlchemyWindow)
local BackpackShop = require(script.Parent.Parent.UI.Screens.BackpackShop)
local BlacksmithWindow = require(script.Parent.Parent.UI.Screens.BlacksmithWindow)
local DepositWindow = require(script.Parent.Parent.UI.Screens.DepositWindow)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local NpcDialog = require(script.Parent.Parent.UI.Screens.NpcDialog)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local ShopWindow = require(script.Parent.Parent.UI.Screens.ShopWindow)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local UnbindPicker = require(script.Parent.Parent.UI.Screens.UnbindPicker)

local NpcController = {
	Name = "NpcController",
	Deps = { "WindowManager", "UIController", "QuestController", "GuildController", "MarketController" },
}

local scope = Fusion.scoped(Fusion)
NpcController.Current = scope:Value(nil :: string?)
NpcController.Quests = nil :: any
NpcController.Guild = nil :: any
NpcController.Market = nil :: any
-- Target of the forge's upgrade tab ({ location, key }), set by dropping an item on the anvil.
NpcController.UpgradeTarget = scope:Value(nil :: any)
NpcController.SmithTab = scope:Value("craft")

local WindowManager: any
local CLOSE_DISTANCE = 20
local SERVICE_WINDOWS = { "npc", "shop", "deposit", "blacksmith", "backpacks", "alchemy", "guildfound", "auction" }

local SERVICE_TO_WINDOW: { [string]: string } = {
	shop = "shop",
	deposit = "deposit",
	blacksmith = "blacksmith",
	backpacks = "backpacks",
	alchemy = "alchemy",
}

local function heal(npcId: string)
	task.spawn(function()
		local ok, err = Net.Invoke("HealMe", npcId)
		if ok then
			Sounds.play("levelUp")
			Toast.push(Text.now("heal.done"), "success")
		else
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

function NpcController.OpenService(service: string)
	local npcId = Fusion.peek(NpcController.Current)
	if not npcId then
		return
	end
	if service == "heal" then
		heal(npcId)
		return
	end
	if service == "story" then
		WindowManager.Close("npc")
		NpcController.Quests.OpenNpc(npcId)
		return
	elseif service == "quests" then
		WindowManager.Close("npc")
		NpcController.Quests.OpenBoard()
		return
	elseif service == "guild" then
		NpcController.Guild.OpenFromNpc()
		return
	elseif service == "auction" then
		NpcController.Market.OpenAuction()
		return
	elseif service == "mail" then
		NpcController.Market.OpenMail()
		return
	end
	local window = SERVICE_TO_WINDOW[service]
	if not window then
		Toast.push(Text.now("npc.service.soon"), "info")
		return
	end
	WindowManager.Close("npc")
	WindowManager.Open(window)
end

function NpcController.Talk(npcId: string)
	local def = Npcs.get(npcId)
	if not def or def.decoration then
		return
	end
	NpcController.Current:set(npcId)
	for _, id in SERVICE_WINDOWS do
		WindowManager.Close(id)
	end
	-- Talking counts for "talk to X" quest objectives.
	task.spawn(function()
		Net.Invoke("QuestTalk", npcId)
	end)
	WindowManager.Open("npc")
end

-- Opens the forge on the upgrade tab with an item (drop on the anvil from anywhere).
function NpcController.SetUpgradeTarget(location: string, key: string)
	NpcController.UpgradeTarget:set({ location = location, key = key })
	NpcController.SmithTab:set("upgrade")
end

function NpcController.OpenUnbind()
	WindowManager.Open("unbind")
end

local function decorate(model: Model)
	local npcId = model:GetAttribute("NpcId")
	local def = if type(npcId) == "string" then Npcs.get(npcId) else nil
	local head = model:FindFirstChild("Head") :: BasePart?
	if not def or not head or model:FindFirstChild("VaelthornPlate") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VaelthornPlate"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(260, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Parent = model
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.new(1, 0, 0, 26)
	icon.Text = def.icon
	icon.TextSize = 24
	icon.FontFace = Theme.Fonts.BodyBold
	icon.TextColor3 = Theme.Colors.GoldBright
	icon.TextStrokeTransparency = 0.4
	icon.Parent = gui
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(0, 26)
	name.Size = UDim2.new(1, 0, 0, 26)
	name.Text = Text.now(def.nameKey)
	name.TextSize = 20
	name.FontFace = Theme.Fonts.BodyBold
	name.TextColor3 = Theme.Colors.Parchment
	name.TextStrokeTransparency = 0.35
	name.Parent = gui
	scope:Observer(Text.Lang):onChange(function()
		name.Text = Text.now(def.nameKey)
	end)
	if def.decoration then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") or head
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Text.now("npc.talk")
	prompt.ObjectText = Text.now(def.nameKey)
	Keybinds.bindPrompt(prompt, "interact")
	prompt.MaxActivationDistance = Npcs.INTERACT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = root
	prompt.Triggered:Connect(function()
		NpcController.Talk(def.id)
	end)
	scope:Observer(Text.Lang):onChange(function()
		prompt.ActionText = Text.now("npc.talk")
		prompt.ObjectText = Text.now(def.nameKey)
	end)
end

local function registerWindows()
	WindowManager.Register({
		id = "npc",
		titleKey = "window.npc.title",
		size = Vector2.new(560, 460),
		build = function(s)
			return NpcDialog(s, {
				NpcId = NpcController.Current,
				OnService = NpcController.OpenService,
				HasStory = function(npcId: string): boolean
					return NpcController.Quests.HasStory(npcId)
				end,
			})
		end,
	})
	WindowManager.Register({
		id = "shop",
		titleKey = "window.shop.title",
		size = Vector2.new(720, 640),
		build = function(s)
			return ShopWindow(s, { NpcId = NpcController.Current, ShowModal = WindowManager.ShowModal })
		end,
	})
	WindowManager.Register({
		id = "deposit",
		titleKey = "window.deposit.title",
		size = Vector2.new(900, 620),
		build = function(s)
			return DepositWindow(s)
		end,
	})
	WindowManager.Register({
		id = "blacksmith",
		titleKey = "window.blacksmith.title",
		size = Vector2.new(860, 660),
		build = function(s)
			return BlacksmithWindow(s, {
				UpgradeTarget = NpcController.UpgradeTarget,
				ShowModal = WindowManager.ShowModal,
				Tab = NpcController.SmithTab,
			})
		end,
	})
	WindowManager.Register({
		id = "backpacks",
		titleKey = "window.backpacks.title",
		size = Vector2.new(640, 640),
		build = function(s)
			return BackpackShop(s, NpcController.Current)
		end,
	})
	WindowManager.Register({
		id = "alchemy",
		titleKey = "window.alchemy.title",
		size = Vector2.new(1000, 680),
		build = function(s)
			return AlchemyWindow(s, { NpcId = NpcController.Current })
		end,
	})
	WindowManager.Register({
		id = "unbind",
		titleKey = "window.unbind.title",
		size = Vector2.new(520, 420),
		build = UnbindPicker,
	})
end

function NpcController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	NpcController.Quests = registry.Get("QuestController")
	NpcController.Guild = registry.Get("GuildController")
	NpcController.Market = registry.Get("MarketController")
	registerWindows()
end

function NpcController.Start()
	local function watch(folder: Instance)
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				task.spawn(decorate, child)
			end
		end
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				task.defer(decorate, child)
			end
		end)
	end
	task.spawn(function()
		local world = Workspace:WaitForChild("World")
		local folder = world:WaitForChild("Npcs", 60)
		if folder then
			watch(folder)
		end
	end)

	-- Close service windows when walking away from the NPC.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local npcId = Fusion.peek(NpcController.Current)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local world = Workspace:FindFirstChild("World")
			local folder = world and world:FindFirstChild("Npcs")
			local model = npcId and folder and folder:FindFirstChild(npcId) :: Model?
			if npcId and root and model then
				if (model:GetPivot().Position - root.Position).Magnitude > CLOSE_DISTANCE then
					for _, id in SERVICE_WINDOWS do
						WindowManager.Close(id)
					end
					NpcController.Current:set(nil)
				end
			end
		end
	end)
end

return NpcController
