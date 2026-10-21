--!strict
-- Guild bank (S159g, DESIGN §19): gold out of the treasury and the item vault, with the rights and daily limits of
-- the ranks (Logic/Guild.can / limit) and every move in the guild log. Pure: runs in Lune and inside the UpdateAsync
-- callback of the guild record; mutations change `guild` in place and return (ok, errorKey?), nothing on failure.
-- The vault is `guild.vault`: slot ("1".."N") -> ItemInstance; N = GuildBank.vaultSize (grows with the guild level).
-- Bound items never go in (like trading); a smaller vault never loses items (the slots above N can only be emptied).

local GuildProgressData = require("../Data/GuildProgress")
local GuildSkills = require("../Data/GuildSkills")
local Guild = require("./Guild")

local Rules = GuildProgressData.Rules

local GuildBank = {}

type GuildData = Guild.GuildData

function GuildBank.vaultSize(guild: any?): number
	return Rules.vaultBase + Rules.vaultPerLevel * (Guild.level(guild) - 1)
end

-- What a member took from the bank on UTC day `day` (zeros on another day).
function GuildBank.used(member: any?, day: number): { d: number, gold: number, items: number }
	local use = type(member) == "table" and member.day
	if type(use) == "table" and use.d == day then
		return { d = day, gold = tonumber(use.gold) or 0, items = tonumber(use.items) or 0 }
	end
	return { d = day, gold = 0, items = 0 }
end

-- How much more a member may take today: (gold, items); math.huge for the leader.
function GuildBank.left(guild: any?, member: any?, day: number): (number, number)
	if type(member) ~= "table" then
		return 0, 0
	end
	local use = GuildBank.used(member, day)
	local gold = if Guild.can(member.rank, "withdrawGold", guild)
		then math.max(0, Guild.limit(guild, member.rank, "gold") - use.gold)
		else 0
	local items = if Guild.can(member.rank, "takeItem", guild)
		then math.max(0, Guild.limit(guild, member.rank, "items") - use.items)
		else 0
	return gold, items
end

local function alive(guild: GuildData?): (boolean, string?)
	if not guild or guild.disbanded then
		return false, "guild.error.gone"
	end
	return true, nil
end

-- The first free vault slot within the size, or nil.
function GuildBank.freeSlot(guild: GuildData): number?
	local vault = guild.vault or {}
	for i = 1, GuildBank.vaultSize(guild) do
		if vault[tostring(i)] == nil then
			return i
		end
	end
	return nil
end

function GuildBank.count(guild: any?): number
	local n = 0
	if type(guild) == "table" and type(guild.vault) == "table" then
		for _ in guild.vault do
			n += 1
		end
	end
	return n
end

-- Gold out of the treasury to the member (the caller gives it to the character after the write).
function GuildBank.withdrawGold(
	guild: GuildData?,
	key: string,
	amount: number,
	now: number,
	day: number
): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	local member = g.members[key]
	if not member then
		return false, "guild.error.notMember"
	end
	if not Guild.can(member.rank, "withdrawGold", g) then
		return false, "guild.error.permission"
	end
	if amount ~= math.floor(amount) or amount < 1 or amount > GuildSkills.Rules.maxDeposit then
		return false, "guild.error.amount"
	end
	if g.treasury < amount then
		return false, "guild.error.treasury"
	end
	local gold = GuildBank.left(g, member, day)
	if amount > gold then
		return false, "guild.error.dailyLimit"
	end
	local use = GuildBank.used(member, day)
	use.gold += amount
	member.day = use
	g.treasury -= amount
	Guild.addLog(g, { t = now, k = "withdraw", n = member.name, a = amount })
	g.version = (g.version or 0) + 1
	return true, nil
end

-- An item into the vault: into `slot` when it is free and within the size, else the first free slot.
function GuildBank.putItem(guild: GuildData?, key: string, item: any, slot: number?, now: number): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	local member = g.members[key]
	if not member then
		return false, "guild.error.notMember"
	end
	if not Guild.can(member.rank, "putItem", g) then
		return false, "guild.error.permission"
	end
	if type(item) ~= "table" or type(item.id) ~= "string" then
		return false, "error.badRequest"
	end
	if item.bound then
		return false, "trade.error.bound"
	end
	local vault = g.vault or {}
	g.vault = vault
	local target: number? = nil
	if slot and slot >= 1 and slot <= GuildBank.vaultSize(g) and vault[tostring(slot)] == nil then
		target = slot
	else
		target = GuildBank.freeSlot(g)
	end
	if not target then
		return false, "guild.error.vaultFull"
	end
	local stored = table.clone(item)
	stored.locked = nil -- the owner's sale lock is personal
	vault[tostring(target)] = stored
	Guild.addLog(g, { t = now, k = "put", n = member.name, i = item.id, r = item.rarity, a = item.n })
	g.version = (g.version or 0) + 1
	return true, nil
end

-- An item out of the vault. `uid` must still be in `slot` (another member may have taken it). Returns the item as
-- a third value on success.
function GuildBank.takeItem(
	guild: GuildData?,
	key: string,
	slot: number,
	uid: string,
	now: number,
	day: number
): (boolean, string?, any?)
	local ok, err = alive(guild)
	if not ok then
		return false, err, nil
	end
	local g = guild :: GuildData
	local member = g.members[key]
	if not member then
		return false, "guild.error.notMember", nil
	end
	if not Guild.can(member.rank, "takeItem", g) then
		return false, "guild.error.permission", nil
	end
	local vault = g.vault or {}
	local item = vault[tostring(slot)]
	if type(item) ~= "table" or item.uid ~= uid then
		return false, "error.stale", nil
	end
	local _, items = GuildBank.left(g, member, day)
	if items < 1 then
		return false, "guild.error.dailyLimit", nil
	end
	local use = GuildBank.used(member, day)
	use.items += 1
	member.day = use
	vault[tostring(slot)] = nil
	Guild.addLog(g, { t = now, k = "take", n = member.name, i = item.id, r = item.rarity, a = item.n })
	g.version = (g.version or 0) + 1
	return true, nil, item
end

-- Moves an item between two vault slots (any member who may take items); swaps when the target holds one.
function GuildBank.move(guild: GuildData?, key: string, from: number, to: number): (boolean, string?)
	local ok, err = alive(guild)
	if not ok then
		return false, err
	end
	local g = guild :: GuildData
	local member = g.members[key]
	if not member then
		return false, "guild.error.notMember"
	end
	if not Guild.can(member.rank, "putItem", g) then
		return false, "guild.error.permission"
	end
	local size = GuildBank.vaultSize(g)
	local vault = g.vault or {}
	g.vault = vault
	local a, b = tostring(from), tostring(to)
	if from == to or to < 1 or to > size or vault[a] == nil then
		return false, "error.stale"
	end
	vault[a], vault[b] = vault[b], vault[a]
	g.version = (g.version or 0) + 1
	return true, nil
end

return GuildBank
