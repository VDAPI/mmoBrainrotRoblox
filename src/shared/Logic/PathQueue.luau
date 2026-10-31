--!strict
-- S162e (Studio test 2026-10-31: one server frame of 1.7 s at a monster's first path): the monsters' path jobs wait
-- here until Entities/PathWorker starts them, at most Combat.pathPerFrame per server frame. A monster's AI tick only
-- pushes a job (no engine call, no wait); one job per key, a newer one replaces the older one still waiting in its place
-- in the line. Pure.

local PathQueue = {}

export type Queue = { order: { any }, jobs: { [any]: any } }

function PathQueue.new(): Queue
	return { order = {}, jobs = {} }
end

-- Queues `job` under `key`. Returns true when it replaced a job of that key still waiting.
function PathQueue.push(queue: Queue, key: any, job: any): boolean
	local replaced = queue.jobs[key] ~= nil
	if not replaced then
		table.insert(queue.order, key)
	end
	queue.jobs[key] = job
	return replaced
end

-- Forgets the job of `key` (a monster removed meanwhile).
function PathQueue.drop(queue: Queue, key: any)
	if queue.jobs[key] == nil then
		return
	end
	queue.jobs[key] = nil
	local index = table.find(queue.order, key)
	if index then
		table.remove(queue.order, index)
	end
end

-- Takes up to `n` jobs, oldest first.
function PathQueue.take(queue: Queue, n: number): { any }
	local taken = {}
	while #taken < n and #queue.order > 0 do
		local key = table.remove(queue.order, 1)
		local job = queue.jobs[key]
		queue.jobs[key] = nil
		if job ~= nil then
			table.insert(taken, job)
		end
	end
	return taken
end

function PathQueue.size(queue: Queue): number
	return #queue.order
end

return PathQueue
