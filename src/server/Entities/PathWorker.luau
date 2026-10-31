--!strict
-- S162e (Studio test 2026-10-31: one server frame of 1.7 s at a wolf's first path, the first path call in that area):
-- every PathfindingService call of the monsters. Entities/Monster only queues a job (Logic/PathQueue: no engine call and
-- no wait inside the AI tick); a Heartbeat pump starts at most Combat.pathPerFrame jobs per frame, each in a thread of
-- its own (task.defer; ComputeAsync yields there while the engine computes) and hands the answer to the job's `done`.
-- Luau runs on one thread: whatever the engine does inside ComputeAsync before it yields still lands in that frame. So
-- the pump logs a frame longer than SPIKE seconds right after a call ("[PathWorker] ..." with the agent and the
-- distance) and `stats` keeps the slowest answer and the longest such frame (read by /chasetest).

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.Shared.Data.Combat)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PathQueue = require(ReplicatedStorage.Shared.Logic.PathQueue)

export type Answer = {
	points: { Vector3 }?, -- nil = no way (or the call failed)
	waited: number, -- seconds in the queue
	seconds: number, -- seconds from the call to the answer
}

export type Job = {
	agent: { [string]: any },
	from: Vector3,
	goal: Vector3,
	done: (answer: Answer) -> (),
	queuedAt: number?,
}

local log = Log.new("PathWorker")

local PathWorker = {}

PathWorker.SPIKE = 0.25
PathWorker.stats = {
	started = 0,
	answered = 0,
	lastStartAt = 0, -- os.clock of the last call
	slowest = 0, -- seconds, the slowest answer
	spikes = 0, -- frames over SPIKE right after a call
	spikeMs = 0, -- the longest of them
}

local queue = PathQueue.new()
local connection: RBXScriptConnection? = nil
local startedLastFrame: Job? = nil

local function compute(job: Job)
	local started = os.clock()
	local path = PathfindingService:CreatePath(job.agent)
	local ok = pcall(function()
		path:ComputeAsync(job.from, job.goal)
	end)
	local seconds = os.clock() - started
	local stats = PathWorker.stats
	stats.answered += 1
	stats.slowest = math.max(stats.slowest, seconds)
	local points: { Vector3 }? = nil
	if ok and path.Status == Enum.PathStatus.Success then
		local list: { Vector3 } = {}
		for _, waypoint in path:GetWaypoints() do
			table.insert(list, waypoint.Position)
		end
		points = list
	end
	job.done({ points = points, waited = started - (job.queuedAt or started), seconds = seconds })
end

local function pump(dt: number)
	local last = startedLastFrame
	startedLastFrame = nil
	local stats = PathWorker.stats
	if last and dt > PathWorker.SPIKE then
		stats.spikes += 1
		stats.spikeMs = math.max(stats.spikeMs, dt * 1000)
		log:warn(
			"server frame of %d ms right after a path call (agent %s x %s, %d studs)",
			math.floor(dt * 1000),
			tostring(last.agent.AgentRadius),
			tostring(last.agent.AgentHeight),
			math.floor((last.goal - last.from).Magnitude)
		)
	end
	for _, job in PathQueue.take(queue, Combat.pathPerFrame) do
		stats.started += 1
		stats.lastStartAt = os.clock()
		startedLastFrame = job
		task.defer(compute, job)
	end
end

-- Queues a path for `key` (a monster; a newer ask replaces its older one still waiting). Never yields.
function PathWorker.request(key: any, job: Job)
	job.queuedAt = os.clock()
	PathQueue.push(queue, key, job)
	if not connection then
		connection = RunService.Heartbeat:Connect(pump)
	end
end

-- Forgets the waiting job of `key` (a removed monster).
function PathWorker.cancel(key: any)
	PathQueue.drop(queue, key)
end

function PathWorker.waiting(): number
	return PathQueue.size(queue)
end

return PathWorker
