--!strict
-- Hunting contracts 1–99 (docs/DESIGN-15.md §3.3). Filled by S99 (generated from the hunting grounds); empty until
-- then, so the journal tab stays hidden.

local Types = require("./Types")

local MAX_LEVEL = 99

-- BEGIN GENERATED (tools/contracts_gen.luau)
local LIST: { Types.ContractQuest } = {}
-- END GENERATED

local byLevel: { [number]: Types.ContractQuest } = {}
local byId: { [string]: Types.ContractQuest } = {}
for _, contract in LIST do
	byLevel[contract.level] = contract
	byId[contract.id] = contract
end

local function get(id: string): Types.ContractQuest?
	return byId[id]
end

local function forLevel(level: number): Types.ContractQuest?
	return byLevel[level]
end

return table.freeze({
	list = LIST,
	byLevel = byLevel,
	byId = byId,
	get = get,
	forLevel = forLevel,
	MAX_LEVEL = MAX_LEVEL,
})
