--!strict
-- Orders modules so every module comes after its dependencies (used by the service/controller loader).
-- Ties are broken alphabetically, so start order is stable between runs.

export type Node = { Name: string, Deps: { string }? }

local DepSort = {}

function DepSort.sort(modules: { any }): { any }
	local byName: { [string]: Node } = {}
	for _, module in modules do
		assert(byName[module.Name] == nil, `DepSort: duplicate module name '{module.Name}'`)
		byName[module.Name] = module
	end

	local names = {}
	for name in byName do
		table.insert(names, name)
	end
	table.sort(names)

	local result: { any } = {}
	local state: { [string]: "visiting" | "done" } = {}

	local function visit(name: string, from: string?)
		local module = byName[name]
		if module == nil then
			error(`DepSort: '{from or "?"}' depends on missing module '{name}'`)
		end
		if state[name] == "done" then
			return
		end
		if state[name] == "visiting" then
			error(`DepSort: dependency cycle through '{name}'`)
		end
		state[name] = "visiting"
		local deps = table.clone(module.Deps or {})
		table.sort(deps)
		for _, dep in deps do
			visit(dep, name)
		end
		state[name] = "done"
		table.insert(result, module)
	end

	for _, name in names do
		visit(name, nil)
	end
	return result
end

return DepSort
