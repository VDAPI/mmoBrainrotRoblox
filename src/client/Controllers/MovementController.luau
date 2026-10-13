--!strict
-- Sprint (S18, DESIGN §24): hold the sprint key (LeftControl by default, rebindable) or toggle the touch
-- button. The server owns the walk speed (StatService.SetSprint); the client only reports the intent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)

local MovementController = {
	Name = "MovementController",
}

local scope = Fusion.scoped(Fusion)
-- True while sprinting, observable (touch button state).
MovementController.Sprinting = scope:Value(false)

local function set(on: boolean)
	if Fusion.peek(MovementController.Sprinting) == on then
		return
	end
	-- S96: no sprint in the saddle (the server ignores it there anyway)
	if on and State.Get({ "character", "mounts", "riding" }) == true then
		return
	end
	MovementController.Sprinting:set(on)
	Net.Send("SetSprint", on)
end

function MovementController.ToggleSprint()
	set(not Fusion.peek(MovementController.Sprinting))
end

function MovementController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if Keybinds.is(input.KeyCode, "sprint") then
			set(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard and Keybinds.is(input.KeyCode, "sprint") then
			set(false)
		end
	end)
	-- The server clears the sprint on death, respawn and mounting, already when the mount channel starts (S96);
	-- mirror that so the button never lies, also after an interrupted channel.
	State.Changed:Connect(function()
		if
			State.Get({ "death" }) ~= nil
			or State.Get({ "session", "phase" }) ~= "playing"
			or State.Get({ "character", "mounts", "riding" }) == true
			or State.Get({ "mountCast" }) ~= nil
		then
			if Fusion.peek(MovementController.Sprinting) then
				MovementController.Sprinting:set(false)
			end
		end
	end)
end

return MovementController
