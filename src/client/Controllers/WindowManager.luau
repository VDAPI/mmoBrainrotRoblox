--!strict
-- Window registry and stack (ARCHITECTURE §9).
--   WindowManager.Register({ id, titleKey, size, hotkey?, build })
--   Open / Close / Toggle / CloseAll / IsOpen(id) -> Fusion Value<boolean>
--   ShowModal(spec): one modal at a time, later ones wait in a queue.
-- Esc closes the modal, then the top window, and otherwise opens the game menu (while playing).
-- One window at a time (S18, DESIGN §23): opening a window closes the others. Service windows (COMPANIONS)
-- open together with the backpack, side by side on desktop.
-- Hotkeys only work while enabled (ScreenController enables them in the "playing" phase).
-- S23: `overlay` windows (the dev panel) neither close other windows nor get closed by them; on desktop they
-- open at the right edge. Esc closes the normal windows first and overlays last. Overlay hotkeys win over
-- the other windows' keys; `enabled` hides a window's hotkey from players who may not use it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local KeybindData = require(ReplicatedStorage.Shared.Data.Keybinds)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Modal = require(script.Parent.Parent.UI.Components.Modal)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Text = require(script.Parent.Parent.UI.Text)
local Device = require(script.Parent.Parent.UI.Device)
local Scale = require(script.Parent.Parent.UI.Scale)
local Window = require(script.Parent.Parent.UI.Components.Window)

local log = Log.new("WindowManager")

type Scope = Fusion.Scope<typeof(Fusion)>

export type WindowDef = {
	id: string,
	titleKey: string,
	size: Vector2,
	hotkey: Enum.KeyCode?,
	-- Builds the window content. `close` closes this window.
	build: (scope: Scope, close: () -> ()) -> Fusion.Child,
	overlay: boolean?, -- S23: stays open next to other windows
	enabled: (() -> boolean)?, -- S23: hotkey only while this returns true
}

type OpenWindow = {
	scope: Scope,
	z: Fusion.Value<number>,
}

local WindowManager = {
	Name = "WindowManager",
	Deps = { "UIController" },
	-- Window id opened by Esc when nothing else is open.
	MenuWindowId = "menu",
}

-- Windows that may stay open next to the backpack (NPC services, trade, auction, mail).
local COMPANIONS: { [string]: boolean } = {
	shop = true,
	weaponsmith = true,
	deposit = true,
	blacksmith = true,
	backpacks = true,
	alchemy = true,
	unbind = true,
	trade = true,
	auction = true,
	mail = true,
}
local INVENTORY = "inventory"
local GAP = 12

local UIController: any
local rootScope: Scope
local defs: { [string]: WindowDef } = {}
local open: { [string]: OpenWindow } = {}
local stack: { string } = {} -- open window ids, top last
local openValues: { [string]: Fusion.Value<boolean> } = {}
local hotkeysEnabled = false
local zCounter = 1

local modalQueue: { Modal.Spec } = {}
local modalScope: Scope? = nil
local modalCancel: (() -> ())? = nil -- Escape action for the visible modal (nil = cannot be dismissed)

local function openValue(id: string): Fusion.Value<boolean>
	local value = openValues[id]
	if not value then
		value = rootScope:Value(false)
		openValues[id] = value
	end
	return value
end

local function bringToFront(id: string)
	local window = open[id]
	if not window then
		return
	end
	local index = table.find(stack, id)
	if index then
		table.remove(stack, index)
	end
	table.insert(stack, id)
	zCounter += 1
	window.z:set(zCounter)
end

function WindowManager.Register(def: WindowDef)
	assert(defs[def.id] == nil, `WindowManager: window '{def.id}' registered twice`)
	defs[def.id] = def
end

function WindowManager.IsOpen(id: string): Fusion.Value<boolean>
	return openValue(id)
end

function WindowManager.Close(id: string)
	local window = open[id]
	if not window then
		return
	end
	open[id] = nil
	local index = table.find(stack, id)
	if index then
		table.remove(stack, index)
	end
	Fusion.doCleanup(window.scope)
	openValue(id):set(false)
end

local openWindow: (id: string, offset: Vector2?) -> ()

-- Closes every open window except `keep` (a set of ids) and the overlays.
local function closeOthers(keep: { [string]: boolean })
	for openId in open do
		local openDef = defs[openId]
		if not keep[openId] and not (openDef and openDef.overlay) then
			WindowManager.Close(openId)
		end
	end
end

function WindowManager.Open(id: string)
	if open[id] then
		bringToFront(id)
		return
	end
	local def = defs[id]
	if not def then
		log:warn("unknown window '%s'", id)
		return
	end
	if def.overlay then
		-- Overlay (dev panel): at the right edge on desktop, nothing else closes.
		local screen = Fusion.peek(Scale.VirtualSize)
		local desktop = not Fusion.peek(Device.Touch)
		openWindow(id, if desktop then Vector2.new(math.max(0, screen.X / 2 - def.size.X / 2 - 16), 0) else nil)
		return
	end
	if COMPANIONS[id] then
		-- Service window: backpack on the left, the service on the right.
		closeOthers({ [INVENTORY] = true })
		local inventory = defs[INVENTORY]
		local desktop = not Fusion.peek(Device.Touch)
		local half = (def.size.X + (if inventory then inventory.size.X else 0) + GAP) / 2
		if inventory and desktop then
			if open[INVENTORY] then
				WindowManager.Close(INVENTORY)
			end
			openWindow(INVENTORY, Vector2.new(-half + inventory.size.X / 2, 0))
		end
		openWindow(id, if inventory and desktop then Vector2.new(half - def.size.X / 2, 0) else nil)
		return
	end
	if id == INVENTORY then
		-- The backpack may join an open service window.
		local keep: { [string]: boolean } = {}
		for openId in open do
			if COMPANIONS[openId] then
				keep[openId] = true
			end
		end
		closeOthers(keep)
		if next(keep) then
			local companionId = next(keep) :: string
			local companion = defs[companionId]
			local half = (def.size.X + companion.size.X + GAP) / 2
			openWindow(id, if Fusion.peek(Device.Touch) then nil else Vector2.new(-half + def.size.X / 2, 0))
			return
		end
	else
		closeOthers({})
	end
	openWindow(id, nil)
end

openWindow = function(id: string, offset: Vector2?)
	local def = defs[id]
	local scope = rootScope:innerScope()
	local z = scope:Value(zCounter)
	open[id] = { scope = scope, z = z }
	local function close()
		WindowManager.Close(id)
	end
	Window(scope, {
		Name = `Window_{id}`,
		Title = Text.T(scope, def.titleKey),
		Size = def.size,
		Offset = offset,
		ZIndex = z,
		OnClose = close,
		OnFocus = function()
			bringToFront(id)
		end,
		[Fusion.Children] = def.build(scope, close),
	}).Parent =
		UIController.GetLayer("Windows")
	bringToFront(id)
	openValue(id):set(true)
	Sounds.play("open")
end

function WindowManager.Toggle(id: string)
	if open[id] then
		WindowManager.Close(id)
	else
		WindowManager.Open(id)
	end
end

function WindowManager.CloseAll()
	for id in open do
		WindowManager.Close(id)
	end
end

-- Closes the top-most window (normal windows before overlays). Returns false when none was open.
function WindowManager.CloseTop(): boolean
	for i = #stack, 1, -1 do
		local id = stack[i]
		local def = defs[id]
		if not (def and def.overlay) then
			WindowManager.Close(id)
			return true
		end
	end
	local top = stack[#stack]
	if top then
		WindowManager.Close(top)
		return true
	end
	return false
end

function WindowManager.HasModal(): boolean
	return modalScope ~= nil
end

local function showNextModal()
	if modalScope or #modalQueue == 0 then
		return
	end
	local spec = table.remove(modalQueue, 1) :: Modal.Spec
	local scope = rootScope:innerScope()
	modalScope = scope
	local props = table.clone(spec) :: any
	props.Close = function()
		if modalScope == scope then
			modalScope = nil
			modalCancel = nil
			Fusion.doCleanup(scope)
			showNextModal()
		end
	end
	if spec.CancelText then
		modalCancel = function()
			if spec.OnCancel then
				spec.OnCancel()
			end
			props.Close()
		end
	end
	Modal(scope, props).Parent = UIController.GetLayer("Modals")
	Sounds.play("open")
end

function WindowManager.ShowModal(spec: Modal.Spec)
	table.insert(modalQueue, spec)
	showNextModal()
end

-- Cancels the visible modal (as if Cancel was pressed) and drops queued ones.
function WindowManager.DismissModals()
	table.clear(modalQueue)
	local scope = modalScope
	if scope then
		modalScope = nil
		modalCancel = nil
		Fusion.doCleanup(scope)
	end
end

function WindowManager.SetHotkeysEnabled(enabled: boolean)
	hotkeysEnabled = enabled
end

-- Extra Escape step between "close the top window" and "open the menu" (e.g. clear the combat target).
-- Returns true when it consumed the key.
local escapeHandler: (() -> boolean)? = nil

function WindowManager.SetEscapeHandler(handler: () -> boolean)
	escapeHandler = handler
end

local function onEscape()
	if modalScope then
		-- Escape on a modal behaves like Cancel; a modal without Cancel stays.
		if modalCancel then
			modalCancel()
		end
		return
	end
	if WindowManager.CloseTop() then
		return
	end
	if escapeHandler and escapeHandler() then
		return
	end
	if hotkeysEnabled and defs[WindowManager.MenuWindowId] then
		WindowManager.Open(WindowManager.MenuWindowId)
	end
end

function WindowManager.Init(registry)
	UIController = registry.Get("UIController")
	rootScope = UIController.Scope
end

function WindowManager.Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if Keybinds.isCapturing() then
			return -- the options window is waiting for a new key (Esc there only cancels)
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			onEscape()
			return
		end
		if gameProcessed or not hotkeysEnabled or modalScope then
			return
		end
		-- Overlay keys first (the dev panel's F2 wins over a player's own binding of F2).
		for id, def in defs do
			if def.overlay and def.hotkey == input.KeyCode and (def.enabled == nil or def.enabled()) then
				WindowManager.Toggle(id)
				return
			end
		end
		for id, def in defs do
			if def.overlay or (def.enabled and not def.enabled()) then
				continue
			end
			-- Rebindable windows (S17) follow Data/Keybinds; others keep their registered key.
			local action = `win_{id}`
			local matches = if KeybindData.get(action)
				then Keybinds.is(input.KeyCode, action)
				else def.hotkey == input.KeyCode
			if matches then
				WindowManager.Toggle(id)
				return
			end
		end
	end)
end

return WindowManager
