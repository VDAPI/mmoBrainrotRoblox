--!strict
-- Window registry and stack (ARCHITECTURE §9).
--   WindowManager.Register({ id, titleKey, size, hotkey?, build })
--   Open / Close / Toggle / CloseAll / IsOpen(id) -> Fusion Value<boolean>
--   ShowModal(spec): one modal at a time, later ones wait in a queue.
-- Esc closes the modal, then the top window, and otherwise opens the game menu (while playing).
-- Hotkeys only work while enabled (ScreenController enables them in the "playing" phase).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Modal = require(script.Parent.Parent.UI.Components.Modal)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Text = require(script.Parent.Parent.UI.Text)
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

-- Closes the top-most window. Returns false when none was open.
function WindowManager.CloseTop(): boolean
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
		if input.KeyCode == Enum.KeyCode.Escape then
			onEscape()
			return
		end
		if gameProcessed or not hotkeysEnabled or modalScope then
			return
		end
		for id, def in defs do
			if def.hotkey == input.KeyCode then
				WindowManager.Toggle(id)
				return
			end
		end
	end)
end

return WindowManager
