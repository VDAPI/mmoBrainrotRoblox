--!strict
-- Window pairing rules (S29, ARCHITECTURE §9). Pure state machine used by the client's WindowManager; no
-- Roblox API, tested in Lune (tests/windowrules.spec.luau).
--
--   * "character" is the main window: equipment, backpack and statistics in one (B and C open it).
--   * "inventory" is only the companion backpack next to a service window (shop, forge, trade, ...).
--     Without a service that brings the backpack, opening "inventory" opens "character" instead.
--   * A service opened by the player brings the backpack along (`inventoryByCompanion`). When the last
--     such service closes (✕, Esc, walking away, end of trade, death, map change), that backpack closes
--     too. A backpack the player opened himself (B next to a service, or the character window was open
--     when the service opened) stays.
--   * Esc on a service closes it, and the companion backpack with the last one, in one press.
--   * ✕ on the companion backpack while a service is open closes only the backpack.
--   * Any other window is exclusive: opening it closes every open window (overlays are not tracked here).

local WindowRules = {}

WindowRules.MAIN = "character"
WindowRules.INVENTORY = "inventory"

-- Windows that stay open next to the backpack (NPC services, trade, auction, mail).
WindowRules.SERVICES = {
	shop = true,
	deposit = true,
	blacksmith = true,
	backpacks = true,
	alchemy = true,
	unbind = true,
	trade = true,
	auction = true,
	mail = true,
} :: { [string]: boolean }

-- Services WITHOUT the companion backpack: the vault window has its own backpack grid next to the vault.
WindowRules.OWN_BACKPACK = {
	deposit = true,
} :: { [string]: boolean }

-- Services that stay open when another service opens: a trade only ends with the trade itself.
WindowRules.STICKY = {
	trade = true,
} :: { [string]: boolean }

export type State = {
	open: { string }, -- open (non-overlay) windows, top last
	inventoryByCompanion: boolean, -- the open backpack was brought by a service
}

export type Plan = {
	open: { string }, -- windows to open, in this order
	close: { string }, -- windows to close first
	focus: string?, -- "backpack" | "stats" for the character window
}

function WindowRules.new(): State
	return { open = {}, inventoryByCompanion = false }
end

function WindowRules.isOpen(state: State, id: string): boolean
	return table.find(state.open, id) ~= nil
end

function WindowRules.isService(id: string): boolean
	return WindowRules.SERVICES[id] == true
end

function WindowRules.bringsBackpack(id: string): boolean
	return WindowRules.SERVICES[id] == true and not WindowRules.OWN_BACKPACK[id]
end

local function remove(state: State, id: string)
	local index = table.find(state.open, id)
	if index then
		table.remove(state.open, index)
	end
end

local function push(state: State, id: string)
	remove(state, id)
	table.insert(state.open, id)
end

local function anyBackpackService(state: State): boolean
	for _, id in state.open do
		if WindowRules.bringsBackpack(id) then
			return true
		end
	end
	return false
end

-- Topmost open service window, if any.
local function topService(state: State): string?
	for i = #state.open, 1, -1 do
		if WindowRules.isService(state.open[i]) then
			return state.open[i]
		end
	end
	return nil
end

-- Which window an open request really means: "inventory" without a backpack service is the character
-- window on its backpack; "character" is the character window on its statistics.
function WindowRules.resolve(state: State, id: string): (string, string?)
	if id == WindowRules.INVENTORY then
		if anyBackpackService(state) or WindowRules.isOpen(state, WindowRules.INVENTORY) then
			return WindowRules.INVENTORY, nil
		end
		return WindowRules.MAIN, "backpack"
	elseif id == WindowRules.MAIN then
		return WindowRules.MAIN, "stats"
	end
	return id, nil
end

-- Moves an open window to the top (clicked / focused).
function WindowRules.onFocus(state: State, id: string)
	if WindowRules.isOpen(state, id) then
		push(state, id)
	end
end

-- Plans opening `id` and applies it to `state`.
function WindowRules.onOpen(state: State, id: string): Plan
	local target, focus = WindowRules.resolve(state, id)
	local plan: Plan = { open = {}, close = {}, focus = focus }
	if WindowRules.isOpen(state, target) then
		push(state, target) -- already open: to the front
		return plan
	end

	if WindowRules.isService(target) then
		local mainWasOpen = WindowRules.isOpen(state, WindowRules.MAIN)
		local keepBackpack = WindowRules.bringsBackpack(target)
		-- Services that stay: sticky ones (trade), or all of them when a trade opens.
		for _, openId in table.clone(state.open) do
			if WindowRules.isService(openId) then
				if WindowRules.STICKY[openId] or WindowRules.STICKY[target] then
					if WindowRules.bringsBackpack(openId) then
						keepBackpack = true
					end
				else
					table.insert(plan.close, openId)
				end
			end
		end
		for _, openId in table.clone(state.open) do
			if not WindowRules.isService(openId) and not (openId == WindowRules.INVENTORY and keepBackpack) then
				table.insert(plan.close, openId)
			end
		end
		for _, closeId in plan.close do
			remove(state, closeId)
		end
		if WindowRules.bringsBackpack(target) and not WindowRules.isOpen(state, WindowRules.INVENTORY) then
			table.insert(plan.open, WindowRules.INVENTORY)
			push(state, WindowRules.INVENTORY)
			-- With the character window open the player was already looking at his backpack: it stays.
			state.inventoryByCompanion = not mainWasOpen
		elseif not WindowRules.isOpen(state, WindowRules.INVENTORY) then
			state.inventoryByCompanion = false
		end
		table.insert(plan.open, target)
		push(state, target)
		return plan
	end

	if target == WindowRules.INVENTORY then
		-- Next to an open service, opened by the player.
		table.insert(plan.open, target)
		push(state, target)
		state.inventoryByCompanion = false
		return plan
	end

	-- Exclusive window.
	for _, openId in state.open do
		table.insert(plan.close, openId)
	end
	table.clear(state.open)
	state.inventoryByCompanion = false
	table.insert(plan.open, target)
	push(state, target)
	return plan
end

-- Closing `id`; returns every window to close (`id` first). Applies it to `state`.
function WindowRules.onClose(state: State, id: string): { string }
	if not WindowRules.isOpen(state, id) then
		return {}
	end
	remove(state, id)
	local toClose = { id }
	if id == WindowRules.INVENTORY then
		state.inventoryByCompanion = false
	elseif
		WindowRules.isService(id)
		and state.inventoryByCompanion
		and WindowRules.isOpen(state, WindowRules.INVENTORY)
		and not anyBackpackService(state)
	then
		remove(state, WindowRules.INVENTORY)
		table.insert(toClose, WindowRules.INVENTORY)
		state.inventoryByCompanion = false
	end
	return toClose
end

-- Closes several windows (walking away from an NPC, death, map change); missing ones are skipped.
function WindowRules.onCloseMany(state: State, ids: { string }): { string }
	local toClose = {}
	for _, id in ids do
		for _, closed in WindowRules.onClose(state, id) do
			table.insert(toClose, closed)
		end
	end
	return toClose
end

-- Every open service window (for death / map change).
function WindowRules.openServices(state: State): { string }
	local list = {}
	for _, id in state.open do
		if WindowRules.isService(id) then
			table.insert(list, id)
		end
	end
	return list
end

-- Esc: the top window; the companion backpack on top counts as its service.
function WindowRules.onEscape(state: State): { string }
	local top = state.open[#state.open]
	if not top then
		return {}
	end
	if top == WindowRules.INVENTORY and state.inventoryByCompanion then
		top = topService(state) or top
	end
	return WindowRules.onClose(state, top)
end

function WindowRules.closeAll(state: State): { string }
	local list = table.clone(state.open)
	table.clear(state.open)
	state.inventoryByCompanion = false
	return list
end

return WindowRules
