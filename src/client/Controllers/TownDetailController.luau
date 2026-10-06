--!strict
-- Starting city detail on the client (S21, docs/miasto/MIASTO.md §5). The server builds only the "shell" level
-- of every city Build; this controller runs the same pure generator (TownGen.all with TownTerrain.heightAt,
-- identical lists on every machine) and builds the "detail" level of the buildings within
-- Config.TownDetailRadius of the camera and the "fine" level within Config.TownFineRadius (per "World detail"
-- setting). A building enters when (distance - its reach) < radius and leaves at radius + hysteresis; the
-- nearest go first and at most Config.TownDetailPartsPerFrame parts are created per frame. Everything lives in
-- Workspace.Vaelthorn_TownDetail (local only, no collisions, not clickable). Leaving the city drops the models
-- and the generated list (it is rebuilt in a fraction of a second on the next visit).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BlueprintBuild = require(ReplicatedStorage.Shared.Util.BlueprintBuild)
local Config = require(ReplicatedStorage.Shared.Config)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)
local Town = require(ReplicatedStorage.Shared.Data.Town)
local TownGen = require(ReplicatedStorage.Shared.Logic.TownGen)
local TownTerrain = require(ReplicatedStorage.Shared.Logic.TownTerrain)

local TownDetailController = {
	Name = "TownDetailController",
}

local CITY = "city"
local TICK = 0.25

type Level = "detail" | "fine"

type Entry = {
	build: BlueprintBuild.Build,
	x: number, -- map-relative centre
	z: number,
	reach: number,
	counts: { detail: number, fine: number },
	want: { detail: boolean, fine: boolean },
	models: { detail: Model?, fine: Model? },
}

type Job = { entry: Entry, level: Level, distance: number }

local folder: Folder
local entries: { Entry }? = nil
local preparing = false
local origin = Vector3.zero
local queue: { Job } = {}
local stats = { builds = 0, detail = 0, fine = 0, lastMs = 0, prepareMs = 0 }

local function setting(): string
	local value = State.Get({ "account", "settings", "decor" })
	return if value == "low" or value == "high" then value else "mid"
end

-- Generates the city Builds once per visit (same list as the server) and counts their parts per level.
local function prepare()
	if entries or preparing then
		return
	end
	preparing = true
	local started = os.clock()
	local map = Maps.get(CITY)
	origin = if map then Vector3.new(map.offset.x, map.offset.y, map.offset.z) else Vector3.zero
	local list: { Entry } = {}
	for _, build in TownGen.all(Town.city, TownTerrain.heightAt) do
		local counts = { detail = 0, fine = 0 }
		for _, piece in build.bp.pieces do
			local lod = piece.lod
			if lod == "detail" or lod == "fine" then
				counts[lod] += 1
			end
		end
		if counts.detail + counts.fine + #build.bp.lights > 0 then
			table.insert(list, {
				build = build :: any,
				x = build.at.x,
				z = build.at.z,
				reach = TownGen.radius(build :: any),
				counts = counts,
				want = { detail = false, fine = false },
				models = {},
			})
		end
	end
	entries = list
	preparing = false
	stats.prepareMs = (os.clock() - started) * 1000
end

local function drop(entry: Entry, level: Level)
	local model = entry.models[level]
	if model then
		model:Destroy()
		entry.models[level] = nil
		stats[level] -= entry.counts[level]
		if level == "detail" then
			stats.builds -= 1
		end
	end
end

local function clearAll(release: boolean)
	if entries then
		for _, entry in entries do
			drop(entry, "detail")
			drop(entry, "fine")
			entry.want.detail = false
			entry.want.fine = false
		end
	end
	table.clear(queue)
	if release then
		entries = nil
	end
end

local function focusPoint(): Vector3?
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		return root.Position
	end
	return if camera then camera.Focus.Position else nil
end

-- Decides what should exist around the focus point; removes what left the radius, queues what entered.
local function tick()
	local mapId = State.Get({ "character", "location", "map" })
	if mapId ~= CITY then
		if entries then
			clearAll(true)
		end
		return
	end
	if not entries then
		prepare()
	end
	local list = entries
	local focus = focusPoint()
	if not list or not focus then
		return
	end
	local level = setting()
	local radius = {
		detail = (Config.TownDetailRadius :: any)[level] :: number,
		fine = (Config.TownFineRadius :: any)[level] :: number,
	}
	local fx, fz = focus.X - origin.X, focus.Z - origin.Z
	table.clear(queue)
	for _, entry in list do
		local distance = math.sqrt((entry.x - fx) ^ 2 + (entry.z - fz) ^ 2) - entry.reach
		for _, lod: Level in { "detail", "fine" } :: { Level } do
			if entry.counts[lod] == 0 and lod == "fine" then
				continue
			end
			local r = radius[lod]
			local built = entry.models[lod] ~= nil
			local want = if built then distance <= r + Config.TownDetailHysteresis else distance < r
			entry.want[lod] = want
			if built and not want then
				drop(entry, lod)
			elseif want and not built then
				table.insert(queue, { entry = entry, level = lod, distance = distance })
			end
		end
	end
	table.sort(queue, function(a, b)
		return a.distance < b.distance
	end)
end

-- Builds queued levels, nearest first, up to the per-frame part budget (always at least one Build).
local function buildSome()
	if #queue == 0 then
		return
	end
	local started = os.clock()
	local budget = Config.TownDetailPartsPerFrame
	local spent = 0
	local done = 0
	for _, job in queue do
		local entry, lod = job.entry, job.level
		done += 1
		if not entry.want[lod] or entry.models[lod] then
			continue
		end
		local cost = entry.counts[lod]
		if spent > 0 and spent + cost > budget then
			done -= 1
			break
		end
		local result = BlueprintBuild.build(entry.build, origin, { [lod] = true } :: any, folder)
		if result.model then
			entry.models[lod] = result.model
			stats[lod] += entry.counts[lod]
			if lod == "detail" then
				stats.builds += 1
			end
		end
		spent += cost
	end
	queue = table.move(queue, done + 1, #queue, 1, {})
	stats.lastMs = (os.clock() - started) * 1000
end

-- Buildings with detail, detail parts, fine parts, last build step (ms), generation time (ms) for /perf.
function TownDetailController.Stats(): (number, number, number, number, number)
	return stats.builds, stats.detail, stats.fine, stats.lastMs, stats.prepareMs
end

-- Map-relative Build nearest to a map-relative point and its distance (admin /town info on the client).
function TownDetailController.Nearest(x: number, z: number): (BlueprintBuild.Build?, number)
	local best, bestDistance = nil, math.huge
	local list: { Entry } = entries or {}
	for _, entry in list do
		local d = math.sqrt((entry.x - x) ^ 2 + (entry.z - z) ^ 2)
		if d < bestDistance then
			best, bestDistance = entry.build, d
		end
	end
	return best, bestDistance
end

function TownDetailController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_TownDetail"
	folder.Parent = Workspace
end

function TownDetailController.Start()
	-- Generate the list under the loading screen when travelling to the city.
	Net.On("MapTransition", function(mapId: string?)
		if mapId == CITY then
			task.defer(prepare)
		end
	end)
	local accumulator = TICK
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator >= TICK then
			accumulator = 0
			local ok, err = pcall(function()
				tick()
			end)
			if not ok then
				warn(`[TownDetailController] {err}`)
			end
		end
		local ok, err = pcall(function()
			buildSome()
		end)
		if not ok then
			warn(`[TownDetailController] {err}`)
			table.clear(queue)
		end
	end)
end

return TownDetailController
