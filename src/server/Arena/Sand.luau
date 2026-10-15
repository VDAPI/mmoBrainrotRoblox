--!strict
-- The sand of Ristalle (S126): one fight at a time for friendly duels (DuelService) and ranked matches (ArenaService,
-- the local host). A FIFO of requests in the order they were made: the owner of the sand runs, the others wait.
-- S127 arena servers do not use it (their pit belongs to one match).

export type Request = { owner: string, id: string, start: () -> () }

local Sand = {}

local current: Request? = nil
local waiting: { Request } = {}

local function grant(request: Request)
	current = request
	task.spawn(request.start)
end

local function nextOne()
	current = nil
	local request = table.remove(waiting, 1)
	if request then
		grant(request)
	end
end

-- Asks for the sand: `start` runs (task.spawn) once the sand is free and every earlier request is done. Returns the
-- place in the line (0 = started at once).
function Sand.request(owner: string, id: string, start: () -> ()): number
	local request: Request = { owner = owner, id = id, start = start }
	if current == nil and #waiting == 0 then
		grant(request)
		return 0
	end
	table.insert(waiting, request)
	return #waiting
end

-- Drops a waiting request (or releases the sand when it already runs).
function Sand.cancel(id: string)
	local now = current
	if now and now.id == id then
		nextOne()
		return
	end
	for i, request in waiting do
		if request.id == id then
			table.remove(waiting, i)
			return
		end
	end
end

-- Frees the sand (only its owner) and starts the next request.
function Sand.release(owner: string, id: string)
	local now = current
	if now and now.owner == owner and now.id == id then
		nextOne()
	end
end

-- (owner, id) of the fight on the sand now.
function Sand.owner(): (string?, string?)
	local now = current
	if now then
		return now.owner, now.id
	end
	return nil, nil
end

-- Requests waiting for the sand (all, or of one owner).
function Sand.waiting(owner: string?): number
	if owner == nil then
		return #waiting
	end
	local n = 0
	for _, request in waiting do
		if request.owner == owner then
			n += 1
		end
	end
	return n
end

-- Place of a waiting request in the line (1 = next), nil when it is not waiting.
function Sand.position(id: string): number?
	for i, request in waiting do
		if request.id == id then
			return i
		end
	end
	return nil
end

return Sand
