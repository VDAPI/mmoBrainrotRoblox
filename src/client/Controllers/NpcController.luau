--!strict
-- City NPCs on the client: localized nameplates with the service icon and a "Talk [E]" prompt on every NPC
-- model (attribute NpcId). Talking opens the dialog window; its buttons open the service windows (shop,
-- vault, forge, backpacks). Walking away closes them. Services from later sessions say "soon". S104: an NPC the
-- character does not see yet (NpcDef.showFrom, Logic/NpcVisibility) is invisible here, without plate and prompt, and
-- appears as soon as its quest starts (the server refuses to talk with it meanwhile). While hidden its parts do not
-- collide and are not hit by raycasts for this client (the originals come back when it appears).

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
local NpcMarkState = require(script.Parent.Parent.UI.NpcMarkState)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local ShopWindow = require(script.Parent.Parent.UI.Screens.ShopWindow)
local Shops = require(ReplicatedStorage.Shared.Data.Shops)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.UI.UiArtState)
local UnbindPicker = require(script.Parent.Parent.UI.Screens.UnbindPicker)

local NpcController = {
	Name = "NpcController",
	Deps = {
		"WindowManager",
		"UIController",
		"QuestController",
		"GuildController",
		"MarketController",
		"NavController",
	},
}

local scope = Fusion.scoped(Fusion)
NpcController.Current = scope:Value(nil :: string?)
NpcController.Quests = nil :: any
NpcController.Guild = nil :: any
NpcController.Market = nil :: any
NpcController.Nav = nil :: any
-- Target of the forge's upgrade tab ({ location, key }), set by dropping an item on the anvil.
NpcController.UpgradeTarget = scope:Value(nil :: any)
NpcController.SmithTab = scope:Value("craft")

local WindowManager: any
local CLOSE_DISTANCE = 20
-- Windows of an NPC; closing them goes through WindowRules, so the companion backpack closes with the last.
local SERVICE_WINDOWS = {
	"npc",
	"questnpc",
	"shop",
	"deposit",
	"blacksmith",
	"backpacks",
	"alchemy",
	"guildfound",
	"auction",
	"mail",
}
-- S97: the mounts window opens anywhere (J, the HUD menu); it closes with the NPC's windows only when the
-- stablemaster's dialog opened it. S126: the arena window the same way (U, the HUD menu, the Arena Master).
local NPC_OPTIONAL: { string } = { "mounts", "arena" }
local fromNpc: { [string]: boolean } = {}

local function closeServiceWindows()
	WindowManager.CloseMany(SERVICE_WINDOWS)
	for id in fromNpc do
		WindowManager.Close(id)
	end
	table.clear(fromNpc)
end

local SERVICE_TO_WINDOW: { [string]: string } = {
	shop = "shop",
	deposit = "deposit",
	blacksmith = "blacksmith",
	backpacks = "backpacks",
	alchemy = "alchemy",
	mounts = "mounts", -- S97: the stablemaster (MountController registers the window)
	arena = "arena", -- S126: the Arena Master (ArenaController registers the window)
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

-- S95: leads to the vendor of the player's class (the dealer's "Where can I buy gear?", the shop's "Guide me").
function NpcController.GuideToNpc(npcId: string)
	local def = Npcs.get(npcId)
	if not def or not NpcController.Nav.GuideToNpc(npcId) then
		Toast.push(Text.now("error.internal"), "error")
		return
	end
	closeServiceWindows()
	Toast.push(
		Text.now("npc.vendors.guide", { name = Text.now(def.nameKey), where = Text.now(`npc.{npcId}.where`) }),
		"info",
		4
	)
end

local function guideToClassVendor()
	local vendorId = Shops.vendorOf(State.Get({ "character", "class" }))
	if not vendorId then
		Toast.push(Text.now("error.internal"), "error")
		return
	end
	NpcController.GuideToNpc(vendorId)
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
	if service == "quests" then
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
	elseif service == "vendors" then
		guideToClassVendor()
		return
	end
	local window = SERVICE_TO_WINDOW[service]
	if not window then
		Toast.push(Text.now("npc.service.soon"), "info")
		return
	end
	WindowManager.Close("npc")
	WindowManager.Open(window)
	if table.find(NPC_OPTIONAL, window) then
		fromNpc[window] = true
	end
end

function NpcController.Talk(npcId: string)
	local def = Npcs.get(npcId)
	if not def or def.decoration then
		return
	end
	NpcController.Current:set(npcId)
	-- S25: talking (opening a service) ends the guide's walk.
	NpcController.Nav.StopWalk(true)
	closeServiceWindows()
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

-- S104: decorated figures by NPC id, shown or hidden for the character (NpcMarkState.Hidden).
-- `physics` keeps each hidden part's original CanCollide / CanQuery until the NPC is shown again.
type Figure = {
	model: Model,
	gui: BillboardGui,
	prompt: ProximityPrompt?,
	physics: { [BasePart]: { collide: boolean, query: boolean } },
}
local figures: { [string]: Figure } = {}

local function applyVisibility(npcId: string)
	local entry = figures[npcId]
	local def = Npcs.get(npcId)
	-- only an NPC with showFrom can ever be hidden; the others are left exactly as built
	if not entry or not entry.model.Parent or not def or def.showFrom == nil then
		return
	end
	local hidden = NpcMarkState.isHidden(npcId)
	for _, part in entry.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if hidden then 1 else 0
			if hidden and not entry.physics[part] then
				entry.physics[part] = { collide = part.CanCollide, query = part.CanQuery }
				part.CanCollide = false
				part.CanQuery = false
			end
		elseif part:IsA("Decal") then
			part.LocalTransparencyModifier = if hidden then 1 else 0
		elseif part:IsA("Light") then
			part.Enabled = not hidden
		end
	end
	if not hidden then
		for part, saved in entry.physics do
			part.CanCollide = saved.collide
			part.CanQuery = saved.query
		end
		table.clear(entry.physics)
	end
	entry.gui.Enabled = not hidden
	if entry.prompt then
		entry.prompt.Enabled = not hidden
	end
	if hidden and Fusion.peek(NpcController.Current) == npcId then
		closeServiceWindows()
		NpcController.Current:set(nil)
	end
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
	-- S119: the silhouette of the NPC's service (Logic/UiArt.serviceOfNpc) once loaded.
	UiArtState.decorate(icon, UiArt.serviceOfNpc(def), { size = 24 })
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
	figures[def.id] = { model = model, gui = gui, prompt = nil, physics = {} }
	if def.decoration then
		applyVisibility(def.id)
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
	figures[def.id].prompt = prompt
	applyVisibility(def.id)
end

local function registerWindows()
	WindowManager.Register({
		id = "npc",
		titleKey = "window.npc.title",
		size = Vector2.new(580, 520),
		build = function(s)
			return NpcDialog(s, {
				NpcId = NpcController.Current,
				OnService = NpcController.OpenService,
				OnQuest = function(row)
					local npcId = Fusion.peek(NpcController.Current)
					if not npcId then
						return
					end
					-- S99: the hunting contract at the board is handled in the board window (one place)
					local def = Npcs.get(npcId)
					if row.kind == "contract" and def and table.find(def.services, "quests") then
						WindowManager.Close("npc")
						NpcController.Quests.OpenBoard()
						return
					end
					NpcController.Quests.OpenQuest(npcId, row)
				end,
			})
		end,
	})
	WindowManager.Register({
		id = "shop",
		titleKey = "window.shop.title",
		size = Vector2.new(720, 640),
		build = function(s)
			return ShopWindow(s, {
				NpcId = NpcController.Current,
				ShowModal = WindowManager.ShowModal,
				Guide = NpcController.GuideToNpc,
			})
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
	NpcController.Nav = registry.Get("NavController")
	registerWindows()
end

function NpcController.Start()
	-- S104: NPCs appear (or hide) when the character's story moves
	scope:Observer(NpcMarkState.Hidden):onChange(function()
		for npcId in figures do
			applyVisibility(npcId)
		end
	end)
	-- A mounts (arena) window closed by hand and reopened with J (U) no longer belongs to the NPC.
	for _, id in NPC_OPTIONAL do
		local isOpen = WindowManager.IsOpen(id)
		scope:Observer(isOpen):onChange(function()
			if not Fusion.peek(isOpen) then
				fromNpc[id] = nil
			end
		end)
	end
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
					closeServiceWindows()
					NpcController.Current:set(nil)
				end
			end
		end
	end)
end

return NpcController
