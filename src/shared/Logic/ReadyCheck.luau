--!strict
-- Ready check at the dungeon gate (S134f, DESIGN §16): the leader asks "Ready?", every asked member answers; all "yes"
-- starts a short countdown, one "no" or the time running out cancels it. Pure; DungeonService holds one check per
-- dungeon and calls these. The leader is ready from the start; an answer may change while the check is still waiting.

local ReadyCheck = {}

export type Status = "waiting" | "go" | "declined" | "expired"

export type Cfg = { readyTimeout: number, readyCountdown: number }

export type Check = {
	members: { number }, -- user ids asked, the leader included
	leader: number,
	startedAt: number,
	endsAt: number,
	countdown: number,
	answers: { [number]: boolean },
	goAt: number?,
}

function ReadyCheck.new(memberIds: { number }, leaderId: number, now: number, cfg: Cfg): Check
	local members = table.clone(memberIds)
	if not table.find(members, leaderId) then
		table.insert(members, 1, leaderId)
	end
	return {
		members = members,
		leader = leaderId,
		startedAt = now,
		endsAt = now + cfg.readyTimeout,
		countdown = cfg.readyCountdown,
		answers = { [leaderId] = true },
		goAt = nil,
	}
end

function ReadyCheck.status(check: Check, now: number): Status
	if check.goAt ~= nil then
		return "go"
	end
	for _, id in check.members do
		if check.answers[id] == false then
			return "declined"
		end
	end
	if now >= check.endsAt then
		return "expired"
	end
	return "waiting"
end

-- Records an answer; all "yes" sets the start (`goAt` = now + countdown).
function ReadyCheck.answer(check: Check, id: number, yes: boolean, now: number): (boolean, string?)
	if not table.find(check.members, id) then
		return false, "dungeon.ready.notAsked"
	end
	if ReadyCheck.status(check, now) ~= "waiting" then
		return false, "dungeon.ready.over"
	end
	check.answers[id] = yes
	if yes and #ReadyCheck.pending(check) == 0 then
		local allYes = true
		for _, member in check.members do
			if check.answers[member] ~= true then
				allYes = false
				break
			end
		end
		if allYes then
			check.goAt = now + check.countdown
		end
	end
	return true, nil
end

-- The moment the party goes in (after the countdown), or nil while not everyone said yes.
function ReadyCheck.goAt(check: Check): number?
	return check.goAt
end

-- Members who have not answered yet.
function ReadyCheck.pending(check: Check): { number }
	local out = {}
	for _, id in check.members do
		if check.answers[id] == nil then
			table.insert(out, id)
		end
	end
	return out
end

return ReadyCheck
