--!strict
-- UI plan phase 1 (owner 2026-10-31; DESIGN §23 "lower left: chat"): the Roblox chat window stood in its default place,
-- the top left corner over the portrait. On PC it moves to the lower left corner (TextChatService
-- ChatWindowConfiguration alignment) and narrows as much as it must to end left of the action bar, measured where both
-- really stand (Logic/HudStack.chatWidthScale). A touch screen keeps Roblox's own place (top left, opened from the top
-- bar): the thumbstick takes the lower left corner there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)

type Scope = Fusion.Scope<typeof(Fusion)>

-- Keeps the chat window clear of `bar` (the HUD's action bar) for the life of `scope`.
local function ChatDock(scope: Scope, bar: GuiObject)
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if not window then
		return -- the legacy chat: nothing to place
	end
	local function fit()
		window.HorizontalAlignment = Enum.HorizontalAlignment.Left
		if Fusion.peek(Device.Touch) == true then
			window.VerticalAlignment = Enum.VerticalAlignment.Top
			window.WidthScale = 1
			return
		end
		window.VerticalAlignment = Enum.VerticalAlignment.Bottom
		local scale = HudStack.chatWidthScale(
			window.AbsolutePosition.X,
			window.AbsoluteSize.X,
			window.WidthScale,
			bar.AbsolutePosition.X
		)
		if math.abs(scale - window.WidthScale) > 0.01 then
			window.WidthScale = scale
		end
	end
	for _, item in { bar :: Instance, window :: Instance } do
		for _, property in { "AbsolutePosition", "AbsoluteSize" } do
			table.insert(scope, item:GetPropertyChangedSignal(property):Connect(fit))
		end
	end
	scope:Observer(Device.Touch):onChange(fit)
	task.defer(fit)
end

return ChatDock
