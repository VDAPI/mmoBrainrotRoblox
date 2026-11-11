--!strict
-- UI plan phase 1 (owner 2026-10-31; DESIGN §23 "lower left: chat"): the Roblox chat window stood in its default place,
-- the top left corner over the portrait. On PC it moves to the lower left corner (TextChatService
-- ChatWindowConfiguration alignment) and narrows as much as it must to end left of the action bar, measured where both
-- really stand (Logic/HudStack.chatWidthScale). A touch screen keeps Roblox's own place (top left, opened from the top
-- bar): the thumbstick takes the lower left corner there.
-- Owner 2026-11-10 ("things covering each other"; UI plan package A): the place stays (owner 2026-10-31), but on a
-- short PC screen the window, as tall as Roblox makes it, reached the party rows and the NPC bark's slot under them
-- (Logic/HudZones.barkSlot). It shortens as much as it must to keep its top HudStack.CHAT_GAP under that slot, down to
-- half its height (Logic/HudStack.chatHeightScale; Logic/HudZones.chat is the same rule in tests/hudzones.spec). The
-- slot is measured from the action bar, which stands at its zone's bottom (Logic/HudZones `actionBar`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local Scale = require(script.Parent.Parent.Parent.Scale)

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
			window.HeightScale = 1
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
		-- the bark slot's bottom in screen pixels, from the bar's bottom (both in the HUD's layer)
		local zones = Fusion.peek(HudSlots.Zones)
		local bark = zones.bark
		local k = Scale.get()
		if not bark or k <= 0 then
			return
		end
		local ceiling = bar.AbsolutePosition.Y + bar.AbsoluteSize.Y - (zones.actionBar.bottom - bark.bottom) * k
		local height =
			HudStack.chatHeightScale(window.AbsolutePosition.Y, window.AbsoluteSize.Y, window.HeightScale, ceiling)
		if math.abs(height - window.HeightScale) > 0.01 then
			window.HeightScale = height
		end
	end
	for _, item in { bar :: Instance, window :: Instance } do
		for _, property in { "AbsolutePosition", "AbsoluteSize" } do
			table.insert(scope, item:GetPropertyChangedSignal(property):Connect(fit))
		end
	end
	scope:Observer(Device.Touch):onChange(fit)
	scope:Observer(HudSlots.Zones):onChange(fit) -- the party grew or shrank: the bark slot moved
	task.defer(fit)
end

return ChatDock
