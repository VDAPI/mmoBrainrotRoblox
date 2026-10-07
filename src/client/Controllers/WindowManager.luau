--!strict
-- Window registry and stack (ARCHITECTURE §9).
--   WindowManager.Register({ id, titleKey, size, hotkey?, build })
--   Open / Close / Toggle / CloseAll / IsOpen(id) -> Fusion Value<boolean>
--   ShowModal(spec): one modal at a time, later ones wait in a queue.
-- Esc closes the modal, then the top window, and otherwise opens the game menu (while playing).
-- One window at a time (S18, DESIGN §23): opening a window closes the others. Service windows open together
-- with the companion backpack, side by side on desktop. S29: the pairing rules (what closes with what, the
-- B/C alias of the character window) live in Shared/Logic/WindowRules; every way of closing goes through them.
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
local WindowRules = require(ReplicatedStorage.Shared.Logic.WindowRules)
local State = require(script.Parent.Parent.UI.State)

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
	-- S29: which part of the character window B / C asked for ("backpack" | "stats"), set on open.
	FocusHint = nil :: any,
}

local INVENTORY = WindowRules.INVENTORY
local GAP = 12

local UIController: any
local rootScope: Scope
local defs: { [string]: WindowDef } = {}
local open: { [string]: OpenWindow } = {}
local stack: { string } = {} -- open window ids (overlays included), top last
local rules = WindowRules.new() -- pairing state of the non-overlay windows (S29)
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

local function isOverlay(id: string): boolean
	local def = defs[id]
	return def ~= nil and def.overlay == true
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
	if not isOverlay(id) then
		WindowRules.onFocus(rules, id)
	end
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

-- Removes one window from the screen (no pairing rules).
local function destroyWindow(id: string)
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

local function destroyAll(ids: { string })
	for _, id in ids do
		destroyWindow(id)
	end
end

-- Closes a window and whatever closes with it (the companion backpack after the last service, S29).
function WindowManager.Close(id: string)
	if not open[id] then
		return
	end
	if isOverlay(id) then
		destroyWindow(id)
		return
	end
	local closing = WindowRules.onClose(rules, id)
	if #closing == 0 then
		closing = { id } -- out of sync: close it anyway
	end
	destroyAll(closing)
end

-- Closes several windows through the pairing rules (walking away from an NPC, death, map change).
function WindowManager.CloseMany(ids: { string })
	destroyAll(WindowRules.onCloseMany(rules, ids))
end

-- Closes every service window and its companion backpack.
function WindowManager.CloseServices()
	WindowManager.CloseMany(WindowRules.openServices(rules))
end

local openWindow: (id: string, offset: Vector2?) -> ()

-- Desktop offsets of a backpack + service pair (backpack on the left, service on the right).
local function pairOffsets(serviceId: string): (Vector2, Vector2)
	local inventory = defs[INVENTORY]
	local service = defs[serviceId]
	local invWidth = if inventory then inventory.size.X else 0
	local serviceWidth = if service then service.size.X else 0
	local half = (invWidth + serviceWidth + GAP) / 2
	return Vector2.new(-half + invWidth / 2, 0), Vector2.new(half - serviceWidth / 2, 0)
end

local function topService(): string?
	for i = #rules.open, 1, -1 do
		local id = rules.open[i]
		if WindowRules.isService(id) and open[id] then
			return id
		end
	end
	return nil
end

function WindowManager.Open(id: string)
	if not defs[id] then
		log:warn("unknown window '%s'", id)
		return
	end
	if isOverlay(id) then
		if open[id] then
			bringToFront(id)
			return
		end
		-- Overlay (dev panel): at the right edge on desktop, nothing else closes.
		local def = defs[id]
		local screen = Fusion.peek(Scale.VirtualSize)
		local desktop = not Fusion.peek(Device.Touch)
		openWindow(id, if desktop then Vector2.new(math.max(0, screen.X / 2 - def.size.X / 2 - 16), 0) else nil)
		return
	end
	local plan = WindowRules.onOpen(rules, id)
	if plan.focus then
		WindowManager.FocusHint:set(plan.focus)
	end
	destroyAll(plan.close)
	if #plan.open == 0 then
		local target = WindowRules.resolve(rules, id)
		bringToFront(target)
		return
	end
	local desktop = not Fusion.peek(Device.Touch)
	for _, openId in plan.open do
		if not defs[openId] then
			log:warn("unknown window '%s'", openId)
			WindowRules.onClose(rules, openId)
			continue
		end
		local offset: Vector2? = nil
		if desktop and WindowRules.isService(openId) and WindowRules.bringsBackpack(openId) then
			local invOffset, serviceOffset = pairOffsets(openId)
			if open[INVENTORY] and not table.find(plan.open, INVENTORY) then
				-- The backpack was already open: move it next to the new service.
				destroyWindow(INVENTORY)
				openWindow(INVENTORY, invOffset)
			end
			offset = serviceOffset
		elseif desktop and openId == INVENTORY then
			-- Next to the service opening with it, else next to the open one.
			local service: string? = nil
			for _, other in plan.open do
				if WindowRules.bringsBackpack(other) then
					service = other
				end
			end
			service = service or topService()
			if service then
				offset = (pairOffsets(service))
			end
		end
		openWindow(openId, offset)
	end
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

-- Toggle with the backpack alias (S29): B / C toggle the character window; on touch, pressing the other
-- one while it is open switches its tab instead of closing it.
function WindowManager.Toggle(id: string)
	if isOverlay(id) then
		if open[id] then
			WindowManager.Close(id)
		else
			WindowManager.Open(id)
		end
		return
	end
	local target, focus = WindowRules.resolve(rules, id)
	if open[target] then
		if focus and Fusion.peek(Device.Touch) and Fusion.peek(WindowManager.FocusHint) ~= focus then
			WindowManager.FocusHint:set(focus)
			bringToFront(target)
			return
		end
		WindowManager.Close(target)
	else
		WindowManager.Open(id)
	end
end

function WindowManager.CloseAll()
	WindowRules.closeAll(rules)
	for id in open do
		destroyWindow(id)
	end
end

-- Closes the top-most window (normal windows before overlays; a service together with its companion
-- backpack). Returns false when none was open.
function WindowManager.CloseTop(): boolean
	local closing = WindowRules.onEscape(rules)
	if #closing > 0 then
		destroyAll(closing)
		return true
	end
	for i = #stack, 1, -1 do
		local id = stack[i]
		if not isOverlay(id) then
			-- Not tracked by the rules (should not happen): close it directly.
			destroyWindow(id)
			return true
		end
	end
	local top = stack[#stack]
	if top then
		destroyWindow(top)
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
	WindowManager.FocusHint = rootScope:Value("stats")
end

function WindowManager.Start()
	-- Death and map changes end every service (and take the companion backpack along).
	rootScope:Observer(State.Value({ "death" })):onChange(function()
		if State.Get({ "death" }) ~= nil then
			WindowManager.CloseServices()
		end
	end)
	rootScope:Observer(State.Value({ "character", "location", "map" })):onChange(function()
		WindowManager.CloseServices()
	end)
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
