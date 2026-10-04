--!strict
-- Resolving and changing key bindings (pure; S17). `overrides` is account.settings.keys.

local KeybindData = require("../Data/Keybinds")

local Keybinds = {}

export type Overrides = { [string]: string }

-- Effective key name of an action.
function Keybinds.key(overrides: Overrides?, action: string): string?
	local def = KeybindData.get(action)
	if not def then
		return nil
	end
	local custom = overrides and overrides[action]
	if type(custom) == "string" and KeybindData.allowed[custom] then
		return custom
	end
	return def.default
end

-- Action bound to a key name, or nil.
function Keybinds.actionFor(overrides: Overrides?, keyName: string): string?
	for _, def in KeybindData.actions do
		if Keybinds.key(overrides, def.id) == keyName then
			return def.id
		end
	end
	return nil
end

-- New overrides after binding `action` to `keyName` (nil = back to the default). When another action
-- already uses that key the two swap, so no key is ever bound twice. Returns nil for invalid input.
-- Only keys that differ from the default are kept, so the saved table stays small.
function Keybinds.assign(overrides: Overrides?, action: string, keyName: string?): Overrides?
	local def = KeybindData.get(action)
	if not def then
		return nil
	end
	local target = keyName or def.default
	if not KeybindData.allowed[target] then
		return nil
	end
	local effective: { [string]: string } = {}
	for _, d in KeybindData.actions do
		effective[d.id] = Keybinds.key(overrides, d.id) :: string
	end
	local previous = effective[action]
	for id, key in effective do
		if id ~= action and key == target then
			effective[id] = previous
		end
	end
	effective[action] = target
	local result: Overrides = {}
	for _, d in KeybindData.actions do
		if effective[d.id] ~= d.default then
			result[d.id] = effective[d.id]
		end
	end
	return result
end

-- Short label for a key name ("One" -> "1").
function Keybinds.label(keyName: string?): string
	if not keyName then
		return ""
	end
	return KeybindData.allowed[keyName] or keyName
end

return Keybinds
