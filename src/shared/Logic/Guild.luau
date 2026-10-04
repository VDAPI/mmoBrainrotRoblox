--!strict
-- Guild rules (DESIGN §19), pure so they run in Lune and inside DataStore UpdateAsync callbacks:
-- rank permissions, name/tag shape, member limit, skill bonuses and every mutation of the stored guild
-- record. Mutations change `guild` in place and return (ok, errorKey?); on failure nothing is changed.
-- Member keys are "<userId>:<characterId>" (one guild per character, not per account).

local GuildSkills = require("../Data/GuildSkills")
local NameRules = require("./NameRules")

export type Rank = "leader" | "officer" | "member"

export type Action =
	"invite"
	| "kick"
	| "upgrade"
	| "motd"
	| "promote" -- set officer/member
	| "settings"
	| "transfer"
	| "disband"
	| "deposit"

export type Member = {
	userId: number,
	charId: string,
	name: string,
	class: string,
	level: number,
	rank: Rank,
	joinedAt: number,
	contributed: number,
}

export type Settings = { guildPvpProtection: boolean }

export type GuildData = {
	id: string,
	name: string,
	tag: string,
	leaderCharId: string, -- member key of the leader
	members: { [string]: Member },
	treasury: number,
	skills: { [string]: number },
	motd: string,
	createdAt: number,
	settings: Settings,
	version: number,
	disbanded: boolean?, -- tombstone left for offline members
}

local Rules = GuildSkills.Rules

local Guild = {}

Guild.RANKS = { "leader", "officer", "member" } :: { Rank }

local PERMISSIONS: { [Rank]: { [Action]: boolean } } = {
	leader = {
		invite = true,
		kick = true,
		upgrade = true,
		motd = true,
		promote = true,
		settings = true,
		transfer = true,
		disband = true,
		deposit = true,
	},
	officer = { invite = true, kick = true, upgrade = true, motd = true, deposit = true },
	member = { deposit = true },
}

local RANK_POWER: { [string]: number } = { leader = 3, officer = 2, member = 1 }

function Guild.can(rank: string?, action: Action): boolean
	local set = rank and PERMISSIONS[rank :: Rank]
	return set ~= nil and set[action] == true
end

function Guild.outranks(a: string, b: string): boolean
	return (RANK_POWER[a] or 0) > (RANK_POWER[b] or 0)
end

function Guild.memberKey(userId: number, charId: string): string
	return `{userId}:{charId}`
end

-- Names -------------------------------------------------------------------------------------------

-- Letters (incl. Polish), digits and single inner spaces; at least one letter. Errors "guild.error.name.*".
function Guild.validateName(name: string): (boolean, string?)
	local length = utf8.len(name)
	if length == nil then
		return false, "guild.error.name.chars"
	end
	if length < Rules.nameMin then
		return false, "guild.error.name.short"
	end
	if length > Rules.nameMax then
		return false, "guild.error.name.long"
	end
	if string.sub(name, 1, 1) == " " or string.sub(name, -1) == " " or string.find(name, "  ", 1, true) then
		return false, "guild.error.name.spaces"
	end
	local hasLetter = false
	for _, cp in utf8.codes(name) do
		if cp == 32 or (cp >= 48 and cp <= 57) then
			continue
		end
		if not NameRules.isLetter(cp) then
			return false, "guild.error.name.chars"
		end
		hasLetter = true
	end
	if not hasLetter then
		return false, "guild.error.name.chars"
	end
	return true, nil
end

-- 2-4 capital letters A-Z or digits. Errors "guild.error.tag.*".
function Guild.validateTag(tag: string): (boolean, string?)
	if #tag < Rules.tagMin or #tag > Rules.tagMax or not string.match(tag, "^[A-Z0-9]+$") then
		return false, "guild.error.tag.shape"
	end
	return true, nil
end

-- Uniqueness keys (GuildNames store).
function Guild.nameKey(name: string): string
	return "n:" .. NameRules.normalize(name)
end

function Guild.tagKey(tag: string): string
	return "t:" .. string.upper(tag)
end

-- Skills ------------------------------------------------------------------------------------------

function Guild.skillLevel(skills: { [string]: number }?, id: string): number
	return if skills then math.clamp(skills[id] or 0, 0, GuildSkills.MAX_LEVEL) else 0
end

-- Total effect of a skill at a level (EXP %, gold %, discount %, extra members, drop %).
function Guild.skillEffect(id: string, level: number): number
	local def = GuildSkills.get(id)
	return if def then def.perLevel * math.clamp(level, 0, GuildSkills.MAX_LEVEL) else 0
end

-- Treasury cost of the next level, nil at max level / unknown skill.
function Guild.upgradeCost(id: string, currentLevel: number): number?
	local def = GuildSkills.get(id)
	if not def or currentLevel >= GuildSkills.MAX_LEVEL then
		return nil
	end
	return def.costs[currentLevel + 1]
end

function Guild.memberLimit(skills: { [string]: number }?): number
	return Rules.baseMembers + Guild.skillEffect("expansion", Guild.skillLevel(skills, "expansion"))
end

-- Derived stat bonuses for members: { expBonus, goldBonus, potionDiscount, dropBonus } (members skipped).
function Guild.bonuses(skills: { [string]: number }?): { [string]: number }
	local result = {}
	for _, def in GuildSkills.list do
		local level = Guild.skillLevel(skills, def.id)
		if def.stat ~= "members" and level > 0 then
			result[def.stat] = (result[def.stat] or 0) + Guild.skillEffect(def.id, level)
		end
	end
	return result
end

function Guild.memberCount(guild: GuildData): number
	local n = 0
	for _ in guild.members do
		n += 1
	end
	return n
end

-- Mutations ---------------------------------------------------------------------------------------

local function bump(guild: GuildData)
	guild.version = (guild.version or 0) + 1
end

local function rankOf(guild: GuildData, key: string): Rank?
	local member = guild.members[key]
	return if member then member.rank else nil
end

local function alive(guild: GuildData?): (boolean, string?)
	if not guild or guild.disbanded then
		return false, "guild.error.gone"
	end
	return true, nil
end

export type NewGuild = {
	id: string,
	name: string,
	tag: string,
	founder: Member,
	now: number,
}

function Guild.create(info: NewGuild): GuildData
	local founder = table.clone(info.founder)
	founder.rank = "leader"
	founder.joinedAt = info.now
	local key = Guild.memberKey(founder.userId, founder.charId)
	return {
		id = info.id,
		name = info.name,
		tag = info.tag,
		leaderCharId = key,
		members = { [key] = founder },
		treasury = 0,
		skills = {},
		motd = "",
		createdAt = info.now,
		settings = { guildPvpProtection = true },
		version = 1,
	}
end

function Guild.join(guild: GuildData?, member: Member, now: number): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	local key = Guild.memberKey(member.userId, member.charId)
	if g.members[key] then
		return false, "guild.error.alreadyMember"
	end
	if Guild.memberCount(g) >= Guild.memberLimit(g.skills) then
		return false, "guild.error.full"
	end
	local entry = table.clone(member)
	entry.rank = "member"
	entry.joinedAt = now
	entry.contributed = 0
	g.members[key] = entry
	bump(g)
	return true, nil
end

-- Voluntary leave. The leader must hand over leadership first (or disband when alone).
function Guild.leave(guild: GuildData?, key: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if not g.members[key] then
		return false, "guild.error.notMember"
	end
	if g.leaderCharId == key then
		return false, if Guild.memberCount(g) > 1 then "guild.error.leaderLeave" else "guild.error.leaderAlone"
	end
	g.members[key] = nil
	bump(g)
	return true, nil
end

function Guild.kick(guild: GuildData?, actorKey: string, targetKey: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	local actor, target = rankOf(g, actorKey), rankOf(g, targetKey)
	if not actor or not Guild.can(actor, "kick") then
		return false, "guild.error.permission"
	end
	if not target or actorKey == targetKey then
		return false, "guild.error.notMember"
	end
	if not Guild.outranks(actor, target) then
		return false, "guild.error.rank"
	end
	g.members[targetKey] = nil
	bump(g)
	return true, nil
end

-- Promote/demote between officer and member (leader only).
function Guild.setRank(guild: GuildData?, actorKey: string, targetKey: string, rank: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if not Guild.can(rankOf(g, actorKey), "promote") then
		return false, "guild.error.permission"
	end
	local target = g.members[targetKey]
	if not target or targetKey == actorKey then
		return false, "guild.error.notMember"
	end
	if rank ~= "officer" and rank ~= "member" then
		return false, "error.badRequest"
	end
	if target.rank == rank then
		return false, "guild.error.sameRank"
	end
	target.rank = rank :: Rank
	bump(g)
	return true, nil
end

-- Hands leadership over; the old leader becomes an officer.
function Guild.transfer(guild: GuildData?, actorKey: string, targetKey: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if g.leaderCharId ~= actorKey or not Guild.can(rankOf(g, actorKey), "transfer") then
		return false, "guild.error.permission"
	end
	local target = g.members[targetKey]
	if not target or targetKey == actorKey then
		return false, "guild.error.notMember"
	end
	target.rank = "leader"
	g.members[actorKey].rank = "officer"
	g.leaderCharId = targetKey
	bump(g)
	return true, nil
end

-- Removes a member no matter the rank (character deleted). A leaving leader is replaced by the highest
-- rank, then the longest-serving member. Returns "empty" when nobody is left (caller disbands).
function Guild.forceRemove(guild: GuildData?, key: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if not g.members[key] then
		return false, "guild.error.notMember"
	end
	g.members[key] = nil
	bump(g)
	if g.leaderCharId == key then
		local best: string? = nil
		for candidate, member in g.members do
			local current = best and g.members[best]
			if
				not current
				or Guild.outranks(member.rank, current.rank)
				or (
					member.rank == current.rank
					and (
						member.joinedAt < current.joinedAt
						or (member.joinedAt == current.joinedAt and candidate < (best :: string))
					)
				)
			then
				best = candidate
			end
		end
		if not best then
			return true, "empty"
		end
		g.members[best].rank = "leader"
		g.leaderCharId = best
	end
	return true, nil
end

function Guild.disband(guild: GuildData?, actorKey: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if g.leaderCharId ~= actorKey or not Guild.can(rankOf(g, actorKey), "disband") then
		return false, "guild.error.permission"
	end
	g.disbanded = true
	g.members = {}
	g.treasury = 0
	bump(g)
	return true, nil
end

function Guild.deposit(guild: GuildData?, key: string, amount: number): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	local member = g.members[key]
	if not member then
		return false, "guild.error.notMember"
	end
	if amount ~= math.floor(amount) or amount < 1 or amount > Rules.maxDeposit then
		return false, "guild.error.amount"
	end
	g.treasury += amount
	member.contributed = (member.contributed or 0) + amount
	bump(g)
	return true, nil
end

function Guild.upgrade(guild: GuildData?, actorKey: string, skillId: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if not Guild.can(rankOf(g, actorKey), "upgrade") then
		return false, "guild.error.permission"
	end
	if not GuildSkills.get(skillId) then
		return false, "error.badRequest"
	end
	local level = Guild.skillLevel(g.skills, skillId)
	local cost = Guild.upgradeCost(skillId, level)
	if not cost then
		return false, "guild.error.maxLevel"
	end
	if g.treasury < cost then
		return false, "guild.error.treasury"
	end
	g.treasury -= cost
	g.skills[skillId] = level + 1
	bump(g)
	return true, nil
end

function Guild.setMotd(guild: GuildData?, actorKey: string, text: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if not Guild.can(rankOf(g, actorKey), "motd") then
		return false, "guild.error.permission"
	end
	local length = utf8.len(text)
	if length == nil or length > Rules.motdMax then
		return false, "guild.error.motd"
	end
	g.motd = text
	bump(g)
	return true, nil
end

function Guild.setSetting(guild: GuildData?, actorKey: string, name: string, value: any): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if not Guild.can(rankOf(g, actorKey), "settings") then
		return false, "guild.error.permission"
	end
	if name ~= "guildPvpProtection" or type(value) ~= "boolean" then
		return false, "error.badRequest"
	end
	g.settings.guildPvpProtection = value
	bump(g)
	return true, nil
end

-- Refreshes the cached name/class/level of a member (no permission needed). Fails when nothing changed.
function Guild.touchMember(
	guild: GuildData?,
	key: string,
	name: string,
	class: string,
	level: number
): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local member = (guild :: GuildData).members[key]
	if not member then
		return false, "guild.error.notMember"
	end
	if member.name == name and member.class == class and member.level == level then
		return false, "unchanged"
	end
	member.name, member.class, member.level = name, class, level
	bump(guild :: GuildData)
	return true, nil
end

-- Members sorted for display: rank, then level (desc), then name.
function Guild.sortedKeys(guild: GuildData): { string }
	local keys = {}
	for key in guild.members do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local ma, mb = guild.members[a], guild.members[b]
		if ma.rank ~= mb.rank then
			return Guild.outranks(ma.rank, mb.rank)
		end
		if ma.level ~= mb.level then
			return ma.level > mb.level
		end
		return ma.name < mb.name
	end)
	return keys
end

return Guild
