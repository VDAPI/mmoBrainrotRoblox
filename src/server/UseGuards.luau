--!strict
-- Registry of the checks behind Logic/UseBlocks (S122). Not a service: owning services register in Start, the
-- features ask. No requires and no Roblox API, so tests load it in Lune.
--   register(reason, check, owner) -> unregister   several checks per reason are OR-ed (arena: Ristalle sand + match)
--   first(player, list) -> reason?                   the first reason of `list` with a true check (list order)
--   active(player, list) -> { reason }               every active reason (admin /useblocks)
--   owners(reason) -> { owner }                      who registered checks (admin, tests)
--   lastError(reason) -> string?                     the last error of a check of that reason
-- A check that errors counts as ACTIVE (fail closed): a broken check must never let the elixir work in PvP.

export type Check = (player: any) -> boolean

type Entry = { owner: string, check: Check }

local UseGuards = {}

local checks: { [string]: { Entry } } = {}
local errors: { [string]: string } = {}

-- Registers `check` for `reason`. The same owner registering the same reason again replaces its previous check.
function UseGuards.register(reason: string, check: Check, owner: string): () -> ()
	local list = checks[reason]
	if not list then
		list = {}
		checks[reason] = list
	end
	for i = #list, 1, -1 do
		if list[i].owner == owner then
			table.remove(list, i)
		end
	end
	local entry: Entry = { owner = owner, check = check }
	table.insert(list, entry)
	return function()
		local current = checks[reason]
		if not current then
			return
		end
		for i = #current, 1, -1 do
			if current[i] == entry then
				table.remove(current, i)
			end
		end
	end
end

-- Whether any check of `reason` is true for `player`; an erroring check counts as true (fail closed).
local function isActive(player: any, reason: string): boolean
	local list = checks[reason]
	if not list then
		return false
	end
	for _, entry in list do
		local ok, result = pcall(entry.check, player)
		if not ok then
			errors[reason] = tostring(result)
			return true
		end
		if result == true then
			return true
		end
	end
	return false
end

function UseGuards.first(player: any, list: { string }): string?
	for _, reason in list do
		if isActive(player, reason) then
			return reason
		end
	end
	return nil
end

function UseGuards.active(player: any, list: { string }): { string }
	local out: { string } = {}
	for _, reason in list do
		if isActive(player, reason) then
			table.insert(out, reason)
		end
	end
	return out
end

function UseGuards.owners(reason: string): { string }
	local out: { string } = {}
	local list = checks[reason]
	if list then
		for _, entry in list do
			table.insert(out, entry.owner)
		end
	end
	return out
end

function UseGuards.lastError(reason: string): string?
	return errors[reason]
end

-- Tests only: forgets every check and error.
function UseGuards._reset()
	table.clear(checks)
	table.clear(errors)
end

return UseGuards
