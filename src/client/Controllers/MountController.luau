--!strict
-- Mounts (S96, docs/DESIGN-15.md §2), client side: the mount key (Data/Keybinds "mount", H by default) and the HUD
-- buttons ask the server to mount or dismount (SetMounted); the server checks everything and runs the channel.
-- In water the client asks to dismount (a horse does not swim). Observables for the HUD: Riding and Has (the
-- character owns a mount and is old enough; without one the buttons stay hidden).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local MountController = {
	Name = "MountController",
}

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

function MountController.Start()
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
