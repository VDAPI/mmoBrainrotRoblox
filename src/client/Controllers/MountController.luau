--!strict
-- Mounts (S96, docs/DESIGN-15.md §2), client side: the mount key (Data/Keybinds "mount", H by default) and the HUD
-- buttons ask the server to mount or dismount (SetMounted); the server checks everything and runs the channel.
-- In water the client asks to dismount (a horse does not swim). Observables for the HUD: Riding and Has (the
-- character owns a mount and is old enough; without one the buttons stay hidden).
-- S97: the mounts window (J, the HUD menu and the stablemaster's dialog); Access = the menu entry and the key show
-- (from Config.Mount.minLevel or with a mount), NearStable = next to an NPC with the "mounts" service (upgrades).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local MountWindow = require(script.Parent.Parent.UI.Screens.MountWindow)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local WardrobeStart = require(script.Parent.Parent.UI.WardrobeStart)

local MountController = {
	Name = "MountController",
	Deps = { "WindowManager" },
}

local WindowManager: any
local NEAR_EVERY = 0.5
-- The server allows Npcs.INTERACT_RANGE + 4 studs (NpcService.Near); the client asks for a little less.
local NEAR_RANGE = Npcs.INTERACT_RANGE + 2

local scope = Fusion.scoped(Fusion)

-- True while riding (character.mounts.riding, replicated by the server), observable.
MountController.Riding = State.Value({ "character", "mounts", "riding" })
local owned = State.Value({ "character", "mounts", "owned" })
local level = State.Value({ "character", "level" })

-- The character owns a mount and is old enough to ride it (the HUD shows the mount buttons).
MountController.Has = scope:Computed(function(use): boolean
	local list = use(owned)
	local lvl = use(level)
	return type(list) == "table" and next(list) ~= nil and type(lvl) == "number" and lvl >= Config.Mount.minLevel
end)

-- S97: the mounts window in the HUD menu and on its key: from the mount level, or earlier with a mount.
MountController.Access = scope:Computed(function(use): boolean
	local list = use(owned)
	local lvl = use(level)
	return (type(list) == "table" and next(list) ~= nil) or (type(lvl) == "number" and lvl >= Config.Mount.minLevel)
end)

-- S97: next to an NPC offering the "mounts" service (the stablemaster).
MountController.NearStable = scope:Value(false)

local function nearStable(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Npcs")
	if not root or not folder then
		return false
	end
	for _, def in Npcs.list do
		if table.find(def.services, "mounts") then
			local model = folder:FindFirstChild(def.id)
			if model and model:IsA("Model") then
				local offset = model:GetPivot().Position - root.Position
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= NEAR_RANGE then
					return true
				end
			end
		end
	end
	return false
end

local pending = false

local function request(on: boolean)
	if pending then
		return
	end
	pending = true
	task.spawn(function()
		local ok, err = Net.Invoke("SetMounted", on)
		pending = false
		if not ok and type(err) == "string" then
			Toast.push(Text.now(err, { level = Config.Mount.minLevel }), "warning")
		end
	end)
end

-- Mounts when on foot, dismounts when riding (key and buttons).
function MountController.Toggle()
	local riding = State.Get({ "character", "mounts", "riding" }) == true
	request(not riding)
end

local function watchSwimming(model: Model)
	local humanoid = model:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Swimming and State.Get({ "character", "mounts", "riding" }) == true then
			request(false)
		end
	end)
end

function MountController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	WindowManager.Register({
		id = "mounts",
		titleKey = "window.mounts.title",
		size = Vector2.new(900, 620),
		hotkey = Enum.KeyCode.J,
		enabled = function(): boolean
			return Fusion.peek(MountController.Access)
		end,
		build = function(windowScope: any)
			return MountWindow(windowScope, {
				Near = MountController.NearStable,
				OpenWardrobe = function()
					WardrobeStart.kind = "mountskin"
					WindowManager.Close("wardrobe")
					WindowManager.Open("wardrobe")
				end,
			})
		end,
	})
end

function MountController.Start()
	task.spawn(function()
		while true do
			task.wait(NEAR_EVERY)
			local near = nearStable()
			if Fusion.peek(MountController.NearStable) ~= near then
				MountController.NearStable:set(near)
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if Keybinds.is(input.KeyCode, "mount") then
			MountController.Toggle()
		end
	end)
	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(watchSwimming, player.Character)
	end
	player.CharacterAdded:Connect(function(model)
		watchSwimming(model)
	end)
end

return MountController
