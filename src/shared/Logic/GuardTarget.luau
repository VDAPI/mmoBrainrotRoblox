--!strict
-- S74 (ROZWOJ 10.3, 14.2): whom a guard skill (Intercept) protects. Pure: the server builds the candidates (party,
-- health, red zones) and Skills/Types/Movement.guard acts on the answer.

local GuardTarget = {}

export type Candidate = { key: any, hpFraction: number, distance: number } -- key: Player in the game
export type Reason = "selected" | "zone" | "wounded" | "self"

local function inRange(candidate: Candidate?, range: number): boolean
	return candidate ~= nil and candidate.distance <= range
end

-- Who a guard skill protects: the selected ally within `range`; else the most wounded ally standing in an active
-- red zone (tie: nearer, then list order); else the most wounded ally below full health; else nobody (= the guard
-- itself, the self variant). Returns the key (or nil) and the reason.
function GuardTarget.pick(
	selected: Candidate?,
	inZone: { Candidate },
	wounded: Candidate?,
	range: number
): (any?, Reason)
	if selected and inRange(selected, range) then
		return selected.key, "selected"
	end
	local best: Candidate? = nil
	for _, candidate in inZone do
		if not inRange(candidate, range) then
			continue
		end
		local current = best
		if
			current == nil
			or candidate.hpFraction < current.hpFraction
			or (candidate.hpFraction == current.hpFraction and candidate.distance < current.distance)
		then
			best = candidate
		end
	end
	if best then
		return best.key, "zone"
	end
	if wounded and inRange(wounded, range) and wounded.hpFraction < 1 then
		return wounded.key, "wounded"
	end
	return nil, "self"
end

return GuardTarget
