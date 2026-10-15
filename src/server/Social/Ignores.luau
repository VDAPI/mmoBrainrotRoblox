--!strict
-- S133: "does this player ignore that one" for services that must not depend on SocialService (trade, duel, party,
-- guild): SocialService installs the reader of the live account lists at Init. Both players are on this server.
-- An ignored player gets the same answer as for an unavailable one (social.error.unavailable): the ignore stays secret.

local Ignores = {}

local reader: (userId: number) -> { [string]: any }? = function(_userId: number)
	return nil
end

function Ignores.setReader(fn: (userId: number) -> { [string]: any }?)
	reader = fn
end

-- Whether `target` ignores `from`.
function Ignores.blocks(target: Player, from: Player): boolean
	local list = reader(target.UserId)
	return list ~= nil and list[tostring(from.UserId)] ~= nil
end

-- Either of the two ignores the other: no invitations, trades or duels between them.
function Ignores.between(a: Player, b: Player): boolean
	return Ignores.blocks(a, b) or Ignores.blocks(b, a)
end

-- The error of an invitation from `from` to `target`, nil when neither ignores the other.
function Ignores.check(from: Player, target: Player): string?
	if Ignores.blocks(target, from) then
		return "social.error.unavailable"
	end
	if Ignores.blocks(from, target) then
		return "social.error.youIgnore"
	end
	return nil
end

return Ignores
