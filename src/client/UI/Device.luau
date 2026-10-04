--!strict
-- Input/device detection. Device.Touch is a Fusion Value that flips when the last input was touch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local Device = {}

local scope = Fusion.scoped(Fusion)

local function isTouchInput(inputType: Enum.UserInputType): boolean
	return inputType == Enum.UserInputType.Touch
end

Device.Touch = scope:Value(UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	if inputType == Enum.UserInputType.Keyboard or inputType == Enum.UserInputType.MouseMovement then
		Device.Touch:set(false)
	elseif isTouchInput(inputType) then
		Device.Touch:set(true)
	end
end)

function Device.isTouch(): boolean
	return Fusion.peek(Device.Touch)
end

return Device
