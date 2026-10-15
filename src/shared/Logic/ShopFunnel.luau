--!strict
-- Shop and VIP analytics funnels (S131, DESIGN-17 §9). Pure: which funnel step to log (src/server/PremiumFunnel.luau
-- sends it to AnalyticsService:LogFunnelStepEvent through Analytics.funnel).
--   * FUNNELS: the steps of each funnel in order; the step number is the position (1-based).
--   * "open" (the first step) starts a new funnel session; a session ends after Config.ShopFunnel.sessionTimeout s
--     without a step, and then any other step starts a new session and logs itself (no artificial "open").
--   * every step is logged at most once per session.
-- `track` never modifies its input state: it returns a new state (the old one stays valid for the caller).

local ShopFunnel = {}

export type Session = { id: number, started: number, last: number, done: { [string]: boolean } }
export type State = { [string]: Session }

ShopFunnel.FUNNELS = table.freeze({
	shop = table.freeze({ "open", "tab", "item", "prompt", "granted" }),
	vip = table.freeze({ "open", "prompt", "active" }),
}) :: { [string]: { string } }

-- Steps the client may report (the PremiumFunnel remote); the rest only the server logs.
ShopFunnel.CLIENT_STEPS = table.freeze({
	shop = table.freeze({ open = true, tab = true, item = true }),
	vip = table.freeze({ open = true }),
}) :: { [string]: { [string]: boolean } }

function ShopFunnel.empty(): State
	return {}
end

-- The 1-based number of `stepName` in `funnel`, or nil.
function ShopFunnel.stepOf(funnel: string, stepName: string): number?
	local steps = ShopFunnel.FUNNELS[funnel]
	if not steps then
		return nil
	end
	return table.find(steps, stepName)
end

function ShopFunnel.clientAllowed(funnel: string, stepName: string): boolean
	local allowed = ShopFunnel.CLIENT_STEPS[funnel]
	return allowed ~= nil and allowed[stepName] == true
end

local function copyState(state: State): State
	local out: State = {}
	for funnel, session in state do
		out[funnel] =
			{ id = session.id, started = session.started, last = session.last, done = table.clone(session.done) }
	end
	return out
end

-- The step to log now (nil = unknown funnel / step or already logged in this session) and the new state.
-- `timeout` = seconds without a step that end a session.
function ShopFunnel.track(
	state: State,
	funnel: string,
	stepName: string,
	now: number,
	timeout: number
): (number?, State)
	local step = ShopFunnel.stepOf(funnel, stepName)
	if step == nil then
		return nil, state
	end
	local nextState = copyState(state)
	local session = nextState[funnel]
	local expired = session == nil or now - session.last > timeout
	if session == nil or expired or step == 1 then
		local id = if session then session.id + 1 else 1
		session = { id = id, started = now, last = now, done = {} }
		nextState[funnel] = session
	end
	local current = session :: Session
	if current.done[stepName] then
		return nil, state
	end
	current.done[stepName] = true
	current.last = now
	return step, nextState
end

-- The session id of `funnel` (0 = none yet).
function ShopFunnel.sessionId(state: State, funnel: string): number
	local session = state[funnel]
	return if session then session.id else 0
end

return ShopFunnel
