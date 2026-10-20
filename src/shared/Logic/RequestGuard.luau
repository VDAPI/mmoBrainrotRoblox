--!strict
-- W28: the guards around client -> server requests (Net), pure so Lune can test them.
--
-- Client (Net.Invoke) asks `begin` before it invokes a RemoteFunction:
--   "send"  invoke now (then `finish` with the packed results);
--   "join"  the same request (remote + arguments) is in flight: wait for it and answer its results, no second call;
--   "reuse" the same request finished less than SAME_WINDOW ago (a double click): answer its results again, so a
--           second click never acts on slots or ids the first one already changed;
--   "drop"  a toggle remote (Definitions.toggle) was sent less than TOGGLE_WINDOW ago with other arguments:
--           answer (false, TOO_FAST) without calling the server.
-- Server (Net) answers a request that failed admission with `rejectCode`: a full rate limit bucket is
-- "error.rateLimited", never "error.badRequest" (that one stays for arguments that fail Definitions.args).
-- SILENT keys are never shown as toasts (Toast.push drops them): they mean "too fast" or "already done", not an error.

local RequestGuard = {}
RequestGuard.__index = RequestGuard

RequestGuard.TOO_FAST = "error.tooFast"
RequestGuard.RATE_LIMITED = "error.rateLimited"
RequestGuard.BAD_REQUEST = "error.badRequest"
-- the slot / item the request named is gone already (the click before took it): nothing to do
RequestGuard.STALE = "error.stale"
RequestGuard.SILENT = {
	[RequestGuard.TOO_FAST] = true,
	[RequestGuard.RATE_LIMITED] = true,
	[RequestGuard.STALE] = true,
}

RequestGuard.SAME_WINDOW = 0.25
RequestGuard.TOGGLE_WINDOW = 0.2
local KEEP = 2 -- seconds a finished request's results are kept (pruned on the next begin)
-- a call in flight longer than this no longer holds its twins (a thread that never came back must not block forever)
RequestGuard.INFLIGHT_MAX = 30
local MAX_DEPTH = 3

export type Verdict = "send" | "join" | "reuse" | "drop"
export type Options = { toggle: boolean?, repeatable: boolean? }
type Done = { at: number, results: { n: number, [number]: any } }

export type RequestGuard = typeof(setmetatable(
	{} :: {
		inflight: { [string]: number },
		done: { [string]: Done },
		lastStart: { [string]: number },
	},
	RequestGuard
))

function RequestGuard.new(): RequestGuard
	return setmetatable({ inflight = {}, done = {}, lastStart = {} }, RequestGuard)
end

local function encode(value: any, depth: number, out: { string }): boolean
	local kind = typeof(value)
	if kind == "nil" then
		table.insert(out, "_")
	elseif kind == "boolean" then
		table.insert(out, if value then "T" else "F")
	elseif kind == "number" then
		table.insert(out, `n{string.format("%.17g", value)}`)
	elseif kind == "string" then
		table.insert(out, `s{#value}:{value}`)
	elseif kind == "Vector3" or kind == "Vector2" then
		table.insert(out, `v{tostring(value)}`)
	elseif kind == "table" then
		if depth >= MAX_DEPTH then
			return false
		end
		local keys = {}
		for k in value do
			local keyKind = type(k)
			if keyKind ~= "string" and keyKind ~= "number" then
				return false
			end
			table.insert(keys, k)
		end
		table.sort(keys, function(a: any, b: any): boolean
			if type(a) ~= type(b) then
				return type(a) < type(b)
			end
			return a < b
		end)
		table.insert(out, "{")
		for _, k in keys do
			if not encode(k, depth + 1, out) or not encode(value[k], depth + 1, out) then
				return false
			end
		end
		table.insert(out, "}")
	else
		return false -- an Instance or another userdata: no stable key, the request is never merged
	end
	return true
end

-- A stable key for (remote, arguments); nil when an argument cannot be keyed (then the request is never merged).
function RequestGuard.key(name: string, args: { any }, n: number?): string?
	local out = { name }
	for i = 1, n or #args do
		table.insert(out, "|")
		if not encode(args[i], 0, out) then
			return nil
		end
	end
	return table.concat(out)
end

-- The answer to a request that failed admission on the server; nil when it may run.
function RequestGuard.rejectCode(rateOk: boolean, argsOk: boolean): string?
	if not rateOk then
		return RequestGuard.RATE_LIMITED
	end
	if not argsOk then
		return RequestGuard.BAD_REQUEST
	end
	return nil
end

-- Whether a toast with this error key should be skipped.
function RequestGuard.isSilent(key: any): boolean
	return type(key) == "string" and RequestGuard.SILENT[key] == true
end

function RequestGuard.begin(self: RequestGuard, name: string, key: string?, opts: Options?, now: number): Verdict
	for k, entry in self.done do
		if now - entry.at > KEEP then
			self.done[k] = nil
		end
	end
	local toggle = opts ~= nil and opts.toggle == true
	local repeatable = opts ~= nil and opts.repeatable == true
	if key then
		if self:pending(key, now) then
			return "join"
		end
		local done = self.done[key]
		if done and not repeatable and now - done.at < RequestGuard.SAME_WINDOW then
			return "reuse"
		end
	end
	local last = self.lastStart[name]
	if toggle and last and now - last < RequestGuard.TOGGLE_WINDOW then
		return "drop"
	end
	if key then
		self.inflight[key] = now
	end
	self.lastStart[name] = now
	return "send"
end

function RequestGuard.finish(self: RequestGuard, key: string?, results: { n: number, [number]: any }, now: number)
	if key then
		self.inflight[key] = nil
		self.done[key] = { at = now, results = results }
	end
end

-- Whether a call with this key is in flight (started less than INFLIGHT_MAX before `now`).
function RequestGuard.pending(self: RequestGuard, key: string, now: number): boolean
	local started = self.inflight[key]
	return started ~= nil and now - started < RequestGuard.INFLIGHT_MAX
end

-- The packed results of the last finished request with this key (nil when none is kept).
function RequestGuard.results(self: RequestGuard, key: string): { n: number, [number]: any }?
	local done = self.done[key]
	return if done then done.results else nil
end

return RequestGuard
