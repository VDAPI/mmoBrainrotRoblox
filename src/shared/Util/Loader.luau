--!strict
-- Minimal service/controller loader (ARCHITECTURE §3).
-- Requires every ModuleScript in a folder, orders them by Deps, calls Init(registry) on all
-- (must not yield), then Start() on all (each in its own thread). Logs timings.

local DepSort = require("../Logic/DepSort")
local Log = require("./Log")

export type Registry = {
	Get: (name: string) -> any,
}

export type Module = {
	Name: string,
	Deps: { string }?,
	Init: ((registry: Registry) -> ())?,
	Start: (() -> ())?,
}

local Loader = {}

function Loader.load(folder: Instance, label: string): Registry
	local log = Log.new(label)
	local startedAt = os.clock()

	local modules: { Module } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if not ok then
				log:error("failed to require %s: %s", child.Name, tostring(result))
				continue
			end
			local module = result :: Module
			if type(module) ~= "table" or type(module.Name) ~= "string" then
				log:error("%s does not export a Name, skipped", child.Name)
				continue
			end
			table.insert(modules, module)
		end
	end

	local ordered = DepSort.sort(modules)
	local byName: { [string]: Module } = {}
	for _, module in ordered do
		byName[module.Name] = module
	end

	local registry: Registry = {
		Get = function(name: string): any
			local module = byName[name]
			assert(module, `{label}: unknown module '{name}'`)
			return module
		end,
	}

	for _, module in ordered do
		local t0 = os.clock()
		if module.Init then
			local ok, err = pcall(module.Init :: any, registry)
			if not ok then
				log:error("%s.Init failed: %s", module.Name, tostring(err))
			end
		end
		log:debug("init %-22s %.2f ms", module.Name, (os.clock() - t0) * 1000)
	end

	for _, module in ordered do
		local start = module.Start
		if start then
			task.spawn(function()
				local t0 = os.clock()
				local ok, err = pcall(start :: any)
				if not ok then
					log:error("%s.Start failed: %s", module.Name, tostring(err))
				else
					log:debug("start %-21s %.2f ms", module.Name, (os.clock() - t0) * 1000)
				end
			end)
		end
	end

	log:info("%d modules loaded in %.1f ms", #ordered, (os.clock() - startedAt) * 1000)
	return registry
end

return Loader
