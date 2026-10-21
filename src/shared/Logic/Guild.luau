--!strict
-- Guild rules (DESIGN §19), pure so they run in Lune and inside DataStore UpdateAsync callbacks:
-- rank permissions, name/tag shape, member limit, skill bonuses and every mutation of the stored guild
-- record. Mutations change `guild` in place and return (ok, errorKey?); on failure nothing is changed.
-- Member keys are "<userId>:<characterId>" (one guild per character, not per account).
-- S159g: four ranks (veteran between officer and member), rights of the ranks below the leader editable by the leader
-- (`perms`, defaults in Data/GuildProgress.RANK_DEFAULTS), the guild level from `exp` (gates skill levels), the guild
-- log, the banner. The vault lives in Logic/GuildBank, guild EXP and weekly goals in Logic/GuildProgress.

local GuildProgressData = require("../Data/GuildProgress")
local GuildBanners = require("../Data/GuildBanners")
local GuildSkills = require("../Data/GuildSkills")
local NameRules = require("./NameRules")

export type Rank = "leader" | "officer" | "veteran" | "member"

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
	| "withdrawGold" -- S159g: gold out of the treasury (daily limit per rank)
	| "takeItem" -- S159g: items out of the vault (daily limit per rank)
	| "putItem" -- S159g: items into the vault

export type Member = {
	userId: number,
	charId: string,
	name: string,
	class: string,
	level: number,
	rank: Rank,
	joinedAt: number,
	contributed: number,
	-- S159g: what the member took from the bank today (UTC day `d`): gold and items, for the daily limits
	day: { d: number, gold: number, items: number }?,
}

export type Settings = { guildPvpProtection: boolean }

-- S159g: one line of the guild log (newest last). k = kind ("deposit" | "withdraw" | "put" | "take" | "upgrade" |
-- "goal" | "level" | "join" | "leave" | "kick" | "rank"), n = member name, a = amount / level, i = item id, r = rarity,
-- x = extra text (skill / goal id / rank).
export type LogEntry = { t: number, k: string, n: string?, a: number?, i: string?, r: number?, x: string? }

-- S159g: rights and daily limits of one rank below the leader (overrides of Data/GuildProgress.RANK_DEFAULTS).
export type RankRules = { perms: { [string]: boolean }?, gold: number?, items: number? }

-- S159g: the weekly goals (Logic/GuildProgress).
export type Goal = { id: string, target: number, n: number, done: boolean }
export type Week = { w: number, goals: { Goal }, contrib: { [string]: number } }

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
	-- S159g (all optional: records from before read as level 1, an empty vault and default rights)
	exp: number?, -- guild EXP in total (Guild.levelOf)
	vault: { [string]: any }?, -- slot ("1".."N") -> ItemInstance
	log: { LogEntry }?,
	perms: { [string]: RankRules }?, -- rank -> overrides
	banner: { e: string, c: string }?, -- Data/GuildBanners emblem and colour ids
	week: Week?,
	rally: { from: number, to: number }?, -- weeks with the bonus of all weekly goals done
}

local Rules = GuildSkills.Rules

local Guild = {}

Guild.RANKS = { "leader", "officer", "veteran", "member" } :: { Rank }

-- S159g: ranks whose rights the leader edits, and the rights that can be edited (the rest is the leader's only).
Guild.EDITABLE_RANKS = { "officer", "veteran", "member" } :: { Rank }
Guild.EDITABLE = {
	"invite",
	"kick",
	"promote",
	"upgrade",
	"motd",
	"withdrawGold",
	"takeItem",
	"putItem",
} :: { Action }

local EDITABLE_SET: { [string]: boolean } = {}
for _, action in Guild.EDITABLE do
	EDITABLE_SET[action] = true
end

local RANK_POWER: { [string]: number } = { leader = 4, officer = 3, veteran = 2, member = 1 }

local function overrides(guild: any?, rank: string): RankRules?
	local perms = type(guild) == "table" and guild.perms
	local rules = type(perms) == "table" and perms[rank]
	return if type(rules) == "table" then rules else nil
end

-- Whether `rank` may do `action`. `guild` (record or the client's guild state, both carry `perms`) applies the
-- leader's changes to the rights of the lower ranks; without it the defaults count.
function Guild.can(rank: string?, action: Action, guild: any?): boolean
	if rank == nil or RANK_POWER[rank] == nil then
		return false
	end
	if rank == "leader" or action == "deposit" then
		return true
	end
	if not EDITABLE_SET[action] then
		return false
	end
	local own = overrides(guild, rank)
	local value = own and own.perms and own.perms[action]
	if type(value) == "boolean" then
		return value
	end
	local defaults = (GuildProgressData.RANK_DEFAULTS :: any)[rank]
	return defaults ~= nil and defaults.perms[action] == true
end

-- S159g: the daily bank limit of a rank: "gold" (gold out of the treasury) or "items" (items out of the vault).
-- The leader has none (math.huge).
function Guild.limit(guild: any?, rank: string?, kind: "gold" | "items"): number
	if rank == "leader" then
		return math.huge
	end
	if rank == nil or RANK_POWER[rank] == nil then
		return 0
	end
	local own = overrides(guild, rank)
	local value = own and own[kind]
	if type(value) == "number" then
		return value
	end
	local defaults = (GuildProgressData.RANK_DEFAULTS :: any)[rank]
	return if defaults then defaults[kind] else 0
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

-- Level (S159g) -----------------------------------------------------------------------------------

-- (level, EXP into the level, EXP of the level or nil at the top) of a guild EXP total.
function Guild.levelOf(exp: number?): (number, number, number?)
	local left = math.max(0, math.floor(tonumber(exp) or 0))
	local level = 1
	while level < GuildProgressData.MAX_LEVEL do
		local need = GuildProgressData.LEVEL_EXP[level]
		if left < need then
			return level, left, need
		end
		left -= need
		level += 1
	end
	return level, left, nil
end

function Guild.level(guild: any?): number
	return (Guild.levelOf(if type(guild) == "table" then guild.exp else 0))
end

-- The guild level that opens skill level `n` (1 for unknown levels).
function Guild.skillUnlock(n: number): number
	return GuildProgressData.SKILL_UNLOCK[n] or 1
end

-- Log (S159g) -------------------------------------------------------------------------------------

-- Appends a line to the guild log (oldest dropped past Data/GuildProgress.Rules.logMax).
function Guild.addLog(guild: GuildData, entry: LogEntry)
	local log = guild.log or {}
	guild.log = log
	table.insert(log, entry)
	while #log > GuildProgressData.Rules.logMax do
		table.remove(log, 1)
	end
end

-- Banner (S159g) ----------------------------------------------------------------------------------

-- The banner of a guild (defaults for records from before S159g): emblem and colour ids.
function Guild.banner(guild: any?): (string, string)
	local banner = type(guild) == "table" and guild.banner
	if type(banner) == "table" and GuildBanners.isEmblem(banner.e) and GuildBanners.isColour(banner.c) then
		return banner.e, banner.c
	end
	return GuildBanners.DEFAULT_EMBLEM, GuildBanners.DEFAULT_COLOUR
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
		exp = 0,
		vault = {},
		log = {},
		perms = {},
		banner = { e = GuildBanners.DEFAULT_EMBLEM, c = GuildBanners.DEFAULT_COLOUR },
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
	Guild.addLog(g, { t = now, k = "join", n = entry.name })
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
	Guild.addLog(g, { t = os.time(), k = "leave", n = g.members[key].name })
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
	if not actor or not Guild.can(actor, "kick", g) then
		return false, "guild.error.permission"
	end
	if not target or actorKey == targetKey then
		return false, "guild.error.notMember"
	end
	if not Guild.outranks(actor, target) then
		return false, "guild.error.rank"
	end
	Guild.addLog(g, { t = os.time(), k = "kick", n = g.members[targetKey].name })
	g.members[targetKey] = nil
	bump(g)
	return true, nil
end

-- Sets the rank of a member to officer, veteran or member. The actor needs "promote" (the leader always has it;
-- S159g: an officer when the leader allows it) and must outrank both the member's rank and the new one.
function Guild.setRank(guild: GuildData?, actorKey: string, targetKey: string, rank: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	local actor = rankOf(g, actorKey)
	if not actor or not Guild.can(actor, "promote", g) then
		return false, "guild.error.permission"
	end
	local target = g.members[targetKey]
	if not target or targetKey == actorKey then
		return false, "guild.error.notMember"
	end
	if rank ~= "officer" and rank ~= "veteran" and rank ~= "member" then
		return false, "error.badRequest"
	end
	if not Guild.outranks(actor, target.rank) or not Guild.outranks(actor, rank) then
		return false, "guild.error.rank"
	end
	if target.rank == rank then
		return false, "guild.error.sameRank"
	end
	target.rank = rank :: Rank
	Guild.addLog(g, { t = os.time(), k = "rank", n = target.name, x = rank })
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

-- `force` (admin) disbands with items still in the vault; a leader has to take them out first (S159g audit: a
-- disband wiped the members' items).
function Guild.disband(guild: GuildData?, actorKey: string, force: boolean?): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if g.leaderCharId ~= actorKey or not Guild.can(rankOf(g, actorKey), "disband") then
		return false, "guild.error.permission"
	end
	if not force and type(g.vault) == "table" and next(g.vault) ~= nil then
		return false, "guild.error.vaultNotEmpty"
	end
	g.disbanded = true
	g.members = {}
	g.treasury = 0
	g.vault = {}
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
	Guild.addLog(g, { t = os.time(), k = "deposit", n = member.name, a = amount })
	bump(g)
	return true, nil
end

function Guild.upgrade(guild: GuildData?, actorKey: string, skillId: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if not Guild.can(rankOf(g, actorKey), "upgrade", g) then
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
	if Guild.level(g) < Guild.skillUnlock(level + 1) then
		return false, "guild.error.guildLevel" -- S159g
	end
	if g.treasury < cost then
		return false, "guild.error.treasury"
	end
	g.treasury -= cost
	g.skills[skillId] = level + 1
	local actor = g.members[actorKey]
	Guild.addLog(g, { t = os.time(), k = "upgrade", n = actor and actor.name, a = level + 1, x = skillId })
	bump(g)
	return true, nil
end

function Guild.setMotd(guild: GuildData?, actorKey: string, text: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if not Guild.can(rankOf(g, actorKey), "motd", g) then
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

-- S159g: the leader changes one right of a lower rank (Guild.EDITABLE).
function Guild.setPerm(
	guild: GuildData?,
	actorKey: string,
	rank: string,
	action: string,
	value: any
): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if rankOf(g, actorKey) ~= "leader" then
		return false, "guild.error.permission"
	end
	if not table.find(Guild.EDITABLE_RANKS, rank :: any) or not EDITABLE_SET[action] or type(value) ~= "boolean" then
		return false, "error.badRequest"
	end
	local perms = g.perms or {}
	g.perms = perms
	local rules = perms[rank] or {}
	perms[rank] = rules
	local set = rules.perms or {}
	rules.perms = set
	set[action] = value
	bump(g)
	return true, nil
end

-- S159g: the leader sets the daily limit of a lower rank ("gold" or "items", whole numbers within the Rules caps).
function Guild.setLimit(
	guild: GuildData?,
	actorKey: string,
	rank: string,
	kind: string,
	value: number
): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if rankOf(g, actorKey) ~= "leader" then
		return false, "guild.error.permission"
	end
	local cap = if kind == "gold"
		then GuildProgressData.Rules.goldLimitMax
		elseif kind == "items" then GuildProgressData.Rules.itemLimitMax
		else nil
	if not table.find(Guild.EDITABLE_RANKS, rank :: any) or not cap then
		return false, "error.badRequest"
	end
	if value ~= math.floor(value) or value < 0 or value > cap then
		return false, "guild.error.amount"
	end
	local perms = g.perms or {}
	g.perms = perms
	local rules = perms[rank] or {}
	perms[rank] = rules;
	(rules :: any)[kind] = value
	bump(g)
	return true, nil
end

-- S159g: the leader picks the banner; emblems and colours open with the guild level (Data/GuildBanners).
function Guild.setBanner(guild: GuildData?, actorKey: string, emblem: string, colour: string): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	if not Guild.can(rankOf(g, actorKey), "settings", g) then
		return false, "guild.error.permission"
	end
	if not GuildBanners.isEmblem(emblem) or not GuildBanners.isColour(colour) then
		return false, "error.badRequest"
	end
	local level = Guild.level(g)
	if GuildBanners.emblem(emblem).level > level or GuildBanners.colour(colour).level > level then
		return false, "guild.error.guildLevel"
	end
	g.banner = { e = emblem, c = colour }
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
