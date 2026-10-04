--!strict
-- Client side of rebindable keys (S17): which Enum.KeyCode an action uses right now (account.settings.keys
-- over Data/Keybinds defaults), labels for the HUD, ProximityPrompts that follow rebinding, and the
-- "press a key" capture used by the options window. While capturing, Keybinds.is() is false for everything
-- so no hotkey fires.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local KeybindLogic = require(ReplicatedStorage.Shared.Logic.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.State)

local Keybinds = {}

local scope = Fusion.scoped(Fusion)

local overrides = State.Value({ "account", "settings", "keys" })
-- Action currently waiting for a new key (options window), observable.
Keybinds.Capturing = scope:Value(nil :: string?)

local function current(): { [string]: string }?
	local value = Fusion.peek(overrides)
	return if type(value) == "table" then value else nil
end

local function toKeyCode(name: string?): Enum.KeyCode?
	if not name then
		return nil
	end
	local ok, code = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	return if ok then code else nil
end

function Keybinds.keyCode(action: string): Enum.KeyCode?
	return toKeyCode(KeybindLogic.key(current(), action))
end

-- True when `keyCode` triggers `action` (never while a new key is being captured).
function Keybinds.is(keyCode: Enum.KeyCode, action: string): boolean
	if Fusion.peek(Keybinds.Capturing) ~= nil then
		return false
	end
	return KeybindLogic.key(current(), action) == keyCode.Name
end

-- Action bound to a key code, or nil.
function Keybinds.actionFor(keyCode: Enum.KeyCode): string?
	if Fusion.peek(Keybinds.Capturing) ~= nil then
		return nil
	end
	return KeybindLogic.actionFor(current(), keyCode.Name)
end

-- Reactive short label of an action's key, for HUD buttons.
function Keybinds.Label(useScope: Fusion.Scope<typeof(Fusion)>, action: string): Fusion.Computed<string>
	return useScope:Computed(function(use): string
		local value = use(overrides)
		return KeybindLogic.label(KeybindLogic.key(if type(value) == "table" then value else nil, action))
	end)
end

function Keybinds.label(action: string): string
	return KeybindLogic.label(KeybindLogic.key(current(), action))
end

-- Keeps a ProximityPrompt's keyboard key on the action's binding until the prompt is destroyed.
function Keybinds.bindPrompt(prompt: ProximityPrompt, action: string)
	local function apply()
		local code = Keybinds.keyCode(action)
		if code then
			prompt.KeyboardKeyCode = code
		end
	end
	apply()
	local observer = scope:Observer(overrides)
	local disconnect = observer:onChange(apply)
	prompt.Destroying:Connect(disconnect)
end

-- Starts waiting for a key for `action`; the next keyboard press is sent to the server.
-- Esc cancels. `onResult(ok, errorKey?)` reports the outcome.
local captureConnection: RBXScriptConnection? = nil

function Keybinds.capture(action: string, onResult: (boolean, string?) -> ())
	if captureConnection then
		captureConnection:Disconnect()
	end
	Keybinds.Capturing:set(action)
	captureConnection = UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if captureConnection then
			captureConnection:Disconnect()
			captureConnection = nil
		end
		local name = input.KeyCode.Name
		-- Clear on the next frame, so this very key press does not also fire its new action.
		task.defer(function()
			Keybinds.Capturing:set(nil)
		end)
		if input.KeyCode == Enum.KeyCode.Escape then
			return
		end
		task.spawn(function()
			local ok, err = Net.Invoke("SetKeybind", action, name)
			onResult(ok == true, err)
		end)
	end)
end

function Keybinds.isCapturing(): boolean
	return Fusion.peek(Keybinds.Capturing) ~= nil
end

return Keybinds
