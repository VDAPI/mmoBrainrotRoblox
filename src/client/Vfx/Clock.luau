--!strict
-- Effect clock (S110, docs/ANIMACJE.md): one virtual time for every skill and combat visual, so AnimLab can stop a
-- motion and its effects in the same moment and let them play on. Without AnimLab nothing is ever frozen and it works
-- like task.delay / TweenService / os.clock (one frame of delay at most, the same accuracy as task.delay).
--   now()      os.clock() minus the time spent frozen
--   after()    task.delay on that clock (one Heartbeat connection while anything waits, none otherwise)
--   tween()    TweenService:Create + Play; frozen tweens pause and resume
--   track()    ParticleEmitter (TimeScale 0 while frozen), Trail (Lifetime held at 60 s while frozen, so the streak
--              stays; screenshot it within 0.1 s of the freeze) and Beam (kept as it is)
--   dt()       the dt of a Heartbeat loop of an effect: 0 while frozen
-- Every new delay, tween and emitter of an effect goes through this module (CLAUDE.md "Podgląd ruchu").

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Clock = {}

type Job = { at: number, fn: (...any) -> (), args: { any }, n: number }

local HELD_TRAIL_LIFETIME = 60

local frozenAt: number? = nil
local frozenTotal = 0 -- seconds spent frozen so far
local jobs: { Job } = {}
local connection: RBXScriptConnection? = nil
-- Weak keys: an effect that is destroyed or finished falls out by itself.
local tweens: { [Tween]: boolean } = setmetatable({} :: any, { __mode = "k" })
local held: { [Tween]: boolean } = setmetatable({} :: any, { __mode = "k" }) -- paused by freeze()
local emitters: { [ParticleEmitter]: number } = setmetatable({} :: any, { __mode = "k" }) -- TimeScale before freeze
local trails: { [Trail]: boolean } = setmetatable({} :: any, { __mode = "k" })
local trailLifetimes: { [Trail]: number } = setmetatable({} :: any, { __mode = "k" }) -- Lifetime before freeze

function Clock.now(): number
	return (frozenAt or os.clock()) - frozenTotal
end

function Clock.frozen(): boolean
	return frozenAt ~= nil
end

function Clock.dt(dt: number): number
	return if frozenAt then 0 else dt
end

local function step()
	if frozenAt then
		return
	end
	local now = Clock.now()
	local due: { Job } = {}
	for i = #jobs, 1, -1 do
		local job = jobs[i]
		if job.at <= now then
			table.insert(due, job)
			table.remove(jobs, i)
		end
	end
	if #jobs == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
	-- oldest first, like task.delay
	for i = #due, 1, -1 do
		local job = due[i]
		local ok, err = pcall(function()
			job.fn(table.unpack(job.args, 1, job.n))
		end)
		if not ok then
			warn(`[Vfx.Clock] {tostring(err)}`)
		end
	end
end

-- Runs fn(...) `seconds` from now on the virtual clock (never while frozen).
function Clock.after(seconds: number, fn: (...any) -> (), ...: any)
	table.insert(jobs, { at = Clock.now() + math.max(0, seconds), fn = fn, args = { ... }, n = select("#", ...) })
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

-- Creates, tracks and plays a tween (paused at once while frozen; resume() plays it).
function Clock.tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goal)
	tweens[tween] = true
	tween.Completed:Once(function()
		tweens[tween] = nil
		held[tween] = nil
	end)
	if frozenAt then
		held[tween] = true
	else
		tween:Play()
	end
	return tween
end

-- Tracks a ParticleEmitter, Trail or Beam of an effect; returns it.
function Clock.track<T>(item: T): T
	local instance = item :: any
	if typeof(instance) ~= "Instance" then
		return item
	end
	-- tracked again while frozen (a reused weapon trail, an emitter already stopped): keep the value saved before
	if instance:IsA("ParticleEmitter") then
		if not frozenAt then
			emitters[instance] = 1
		elseif not (emitters[instance] and instance.TimeScale == 0) then
			emitters[instance] = instance.TimeScale
			instance.TimeScale = 0
		end
	elseif instance:IsA("Trail") then
		trails[instance] = true
		if frozenAt and trailLifetimes[instance] == nil then
			trailLifetimes[instance] = instance.Lifetime
			instance.Lifetime = HELD_TRAIL_LIFETIME
		end
	end
	return item
end

-- Stops the virtual clock: delays wait, tweens pause, particles stand, trails stay.
function Clock.freeze()
	if frozenAt then
		return
	end
	frozenAt = os.clock()
	for tween in tweens do
		if tween.PlaybackState == Enum.PlaybackState.Playing then
			tween:Pause()
			held[tween] = true
		end
	end
	for emitter in emitters do
		if emitter.Parent then
			emitters[emitter] = emitter.TimeScale
			emitter.TimeScale = 0
		end
	end
	for trail in trails do
		if trail.Parent then
			trailLifetimes[trail] = trail.Lifetime
			trail.Lifetime = HELD_TRAIL_LIFETIME
		end
	end
end

-- Lets the clock run again from where it stopped (the frozen time is skipped).
function Clock.resume()
	local at = frozenAt
	if not at then
		return
	end
	frozenTotal += os.clock() - at
	frozenAt = nil
	for tween in held do
		held[tween] = nil
		if
			tween.PlaybackState ~= Enum.PlaybackState.Completed
			and tween.PlaybackState ~= Enum.PlaybackState.Cancelled
		then
			tween:Play()
		end
	end
	for emitter, scale in emitters do
		if emitter.Parent then
			emitter.TimeScale = if scale > 0 then scale else 1
		end
	end
	for trail, lifetime in trailLifetimes do
		trailLifetimes[trail] = nil
		if trail.Parent then
			trail.Lifetime = lifetime
		end
	end
	if #jobs > 0 and not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

-- Delays still waiting (AnimLab state).
function Clock.pending(): number
	return #jobs
end

return Clock
