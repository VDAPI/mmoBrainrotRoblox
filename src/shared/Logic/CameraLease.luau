--!strict
-- Who holds the game camera and the player's movement (Studio review 2026-10-31: the camera stayed Scriptable at an
-- AnimLab stage after a teleport and at a scene's shot while the player walked on, and the character could not
-- move). Pure bookkeeping for CameraController: owners in the order they took it (the last camera owner has the
-- camera), each with an optional deadline, a "travel" flag (let go when the character teleports, changes map or is
-- replaced) and a movement lock; `watch` is the watchdog's decision for a frame. Numbers and strings only (Lune).

export type Options = {
	camera: boolean?, -- takes the camera (Scriptable); false: only the movement lock (default true)
	lock: boolean?, -- the player's movement input is off while it holds
	ttl: number?, -- seconds until the watchdog takes it back (nil: until released)
	travel: boolean?, -- let go when the character teleports, changes map or is replaced
}

export type Lease = { owner: string, camera: boolean, lock: boolean, travel: boolean, untilAt: number? }

export type State = { leases: { Lease }, unownedSince: number? }

local CameraLease = {}

-- Seconds a Scriptable camera may stand with no owner before the watchdog gives it back to the player (several
-- frames even at the 15 fps of a background Studio window).
CameraLease.GRACE = 0.5
-- Studs the character's root may move between two frames before it counts as a teleport (a mount at 15 fps moves
-- a few studs a frame, Blink 20).
CameraLease.TELEPORT = 60

function CameraLease.new(): State
	return { leases = {}, unownedSince = nil }
end

local function find(state: State, owner: string): number?
	for i, lease in state.leases do
		if lease.owner == owner then
			return i
		end
	end
	return nil
end

-- `owner` takes the camera (or only the lock) at `now`; taking it again moves it to the top with the new options.
function CameraLease.claim(state: State, owner: string, now: number, options: Options?)
	local o: Options = options or {}
	local at = find(state, owner)
	if at then
		table.remove(state.leases, at)
	end
	table.insert(state.leases, {
		owner = owner,
		camera = o.camera ~= false,
		lock = o.lock == true,
		travel = o.travel == true,
		untilAt = if o.ttl then now + o.ttl else nil,
	})
end

-- True when `owner` held anything.
function CameraLease.release(state: State, owner: string): boolean
	local at = find(state, owner)
	if not at then
		return false
	end
	table.remove(state.leases, at)
	return true
end

-- The owner the camera belongs to (the last camera claim still held), nil: the player's game camera.
function CameraLease.holder(state: State): string?
	for i = #state.leases, 1, -1 do
		local lease = state.leases[i]
		if lease.camera then
			return lease.owner
		end
	end
	return nil
end

-- Whether any owner holds the movement lock.
function CameraLease.locked(state: State): boolean
	for _, lease in state.leases do
		if lease.lock then
			return true
		end
	end
	return false
end

-- Takes out the leases matching `test` and returns their owners.
local function drop(state: State, test: (Lease) -> boolean): { string }
	local out: { string } = {}
	for i = #state.leases, 1, -1 do
		local lease = state.leases[i]
		if test(lease) then
			table.insert(out, 1, lease.owner)
			table.remove(state.leases, i)
		end
	end
	return out
end

-- Takes out the leases past their deadline.
function CameraLease.expired(state: State, now: number): { string }
	return drop(state, function(lease: Lease): boolean
		return lease.untilAt ~= nil and now >= lease.untilAt
	end)
end

-- Takes out the leases that end with a teleport, a map change or a new character.
function CameraLease.travelled(state: State): { string }
	return drop(state, function(lease: Lease): boolean
		return lease.travel
	end)
end

-- Whether the root moved from `a` to `b` (x, y, z) faster than walking: a teleport.
function CameraLease.teleported(a: { number }?, b: { number }?): boolean
	if not a or not b then
		return false
	end
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	return dx * dx + dy * dy + dz * dz > CameraLease.TELEPORT * CameraLease.TELEPORT
end

-- The watchdog for a frame: true when the camera is Scriptable, nobody holds it and it has stood so for GRACE
-- seconds (the caller gives it back to the player).
function CameraLease.watch(state: State, scriptable: boolean, now: number): boolean
	if not scriptable or CameraLease.holder(state) ~= nil then
		state.unownedSince = nil
		return false
	end
	local since = state.unownedSince
	if since == nil then
		state.unownedSince = now
		return false
	end
	if now - since >= CameraLease.GRACE then
		state.unownedSince = nil
		return true
	end
	return false
end

return CameraLease
