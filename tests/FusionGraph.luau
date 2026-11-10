--!strict
-- Package A review (owner 2026-11-10, "things covering each other, nothing folds"): loads modules of src/client under
-- Lune with the real reactive core of Fusion 0.3 from Packages (Value, Computed, Observer, scopes and peek; no
-- instances), so a spec can watch a client Fusion graph such as UI/HudSlots' column. A module's `script` is a path
-- tree over the repo (ReplicatedStorage.Shared is src/shared, ReplicatedStorage.Packages.Fusion that core); the client
-- modules a spec does not test are its `stubs` (by path, e.g. "src/client/UI/Device"). Fusion's errors (its
-- "infinite loop" check) and warnings land in `errors` instead of the output. Run from the repo root, like every spec.
--
--   local graph = FusionGraph.new()
--   graph.stubs["src/client/UI/Device"] = { Touch = graph.scope:Value(false) }
--   local HudSlots = graph.require("src/client/UI/HudSlots")

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local FusionGraph = {}

local FUSION = "Packages/_Index/elttob_fusion@0.3.0/fusion/src"

export type Graph = {
	-- loads the module at a repo path (without its extension); a stub wins
	require: (path: string) -> any,
	stubs: { [string]: any },
	errors: { string },
	-- runs what was deferred (task.defer, Fusion's deferred tasks) until nothing waits
	flush: () -> (),
	-- the core of Fusion the modules get from ReplicatedStorage.Packages.Fusion
	Fusion: any,
	-- a scope of that Fusion for the spec's own stubs
	scope: any,
}

local function dirname(path: string): string
	return string.match(path, "^(.*)/[^/]+$") or ""
end

function FusionGraph.new(): Graph
	local graph = {} :: Graph
	graph.stubs = {}
	graph.errors = {}
	local nodes: { [string]: any } = {}
	local paths: { [any]: string } = {}
	local cache: { [string]: any } = {}

	-- a module's `script`: Parent and children by name, a few roots mapped onto the repo's folders
	local special: { [string]: { [string]: string } } = {
		ReplicatedStorage = { Shared = "src/shared", Packages = "@Packages" },
		["@Packages"] = { Fusion = FUSION },
	}
	local function node(path: string): any
		local known = nodes[path]
		if known then
			return known
		end
		local made = setmetatable({}, {
			__index = function(_, key: string): any
				if key == "Parent" then
					return node(dirname(path))
				end
				local map = special[path]
				if map and map[key] then
					return node(map[key])
				end
				return node(path .. "/" .. key)
			end,
		})
		nodes[path] = made
		paths[made] = path
		return made
	end

	local services: { [string]: any } = {
		RunService = {
			IsStudio = function()
				return false
			end,
			IsClient = function()
				return true
			end,
			Heartbeat = {
				Connect = function()
					return { Disconnect = function() end }
				end,
			},
		},
	}
	local game = {
		GetService = function(_, name: string): any
			if name == "ReplicatedStorage" then
				return node("ReplicatedStorage")
			end
			return services[name] or {}
		end,
	}
	local deferred: { () -> () } = {}
	local function run(f: (...any) -> ...any, ...: any)
		local ok, err = coroutine.resume(coroutine.create(f), ...)
		if not ok then
			table.insert(graph.errors, tostring(err))
		end
	end
	local task = {
		spawn = run,
		defer = function(f: () -> ())
			table.insert(deferred, f)
		end,
	}
	graph.flush = function()
		while #deferred > 0 do
			run(table.remove(deferred, 1) :: () -> ())
		end
	end
	-- Enum.Kind.Item as a name (read at load time by some modules)
	local enum = setmetatable({}, {
		__index = function(_, kind: string): any
			return setmetatable({}, {
				__index = function(_, item: string): string
					return `Enum.{kind}.{item}`
				end,
			})
		end,
	})

	local load: (path: string) -> any
	load = function(path: string): any
		local stub = graph.stubs[path]
		if stub ~= nil then
			return stub
		end
		if cache[path] ~= nil then
			return cache[path]
		end
		local file: string? = nil
		for _, candidate in { path .. ".luau", path .. ".lua", path .. "/init.luau", path .. "/init.lua" } do
			if fs.isFile(candidate) then
				file = candidate
				break
			end
		end
		assert(file, `FusionGraph: no module at {path}`)
		local isInit = string.match(file, "/init%.luau?$") ~= nil
		local chunk = luau.load(fs.readFile(file), {
			debugName = file,
			environment = {
				script = node(path),
				game = game,
				task = task,
				Enum = enum,
				require = function(target: any): any
					if type(target) ~= "string" then
						local found: string = assert(paths[target], "FusionGraph: require of a non-module")
						return load(found)
					end
					-- a string path (src/shared): from the module's folder; "@self" is an init module's own folder
					local base = if isInit then path else dirname(path)
					local rest = target
					if string.sub(rest, 1, 6) == "@self/" then
						base = path
						rest = string.sub(rest, 7)
					end
					while true do
						if string.sub(rest, 1, 2) == "./" then
							rest = string.sub(rest, 3)
						elseif string.sub(rest, 1, 3) == "../" then
							base = dirname(base)
							rest = string.sub(rest, 4)
						else
							break
						end
					end
					return load(base .. "/" .. rest)
				end,
			},
		})
		local result = chunk()
		cache[path] = result
		return result
	end
	graph.require = load

	-- the reactive core, with a provider that keeps Fusion's errors (its callbacks run at once, as on Roblox, where an
	-- error inside one stops only that callback)
	local External = load(FUSION .. "/External")
	External.setExternalProvider({
		policies = { allowWebLinks = false },
		doTaskImmediate = function(resume: () -> ())
			run(resume)
		end,
		doTaskDeferred = function(resume: () -> ())
			table.insert(deferred, resume)
		end,
		logErrorNonFatal = function(message: any)
			table.insert(graph.errors, tostring(message))
		end,
		logWarn = function(...: any)
			local parts = {}
			for _, part in { ... } do
				table.insert(parts, tostring(part))
			end
			table.insert(graph.errors, table.concat(parts, " "))
		end,
		startScheduler = function() end,
		stopScheduler = function() end,
	})
	local Fusion = table.freeze({
		scoped = load(FUSION .. "/Memory/scoped"),
		doCleanup = load(FUSION .. "/Memory/doCleanup"),
		deriveScope = load(FUSION .. "/Memory/deriveScope"),
		innerScope = load(FUSION .. "/Memory/innerScope"),
		Observer = load(FUSION .. "/Graph/Observer"),
		Computed = load(FUSION .. "/State/Computed"),
		Value = load(FUSION .. "/State/Value"),
		peek = load(FUSION .. "/State/peek"),
	})
	graph.stubs[FUSION] = Fusion
	graph.Fusion = Fusion
	graph.scope = Fusion.scoped(Fusion)
	return graph
end

return FusionGraph
