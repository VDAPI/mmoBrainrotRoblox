--!strict
-- Which titles a character has unlocked (pure; DESIGN §4, S16).
-- S59 (ROZWOJ 3.2): path titles (req.kind "mainPath") are unlocked while the active set's main path is their path;
-- character.title nil = never chose (the main path title shows), Titles.NONE = the player hid the title. S138
-- (DESIGN-18 §7): the "main path" is the leading direction (Logic/Paths.mainOf: the most ranks, at least
-- MAIN_MIN_POINTS); when it changes the old title locks and a chosen one falls back as before. Every
-- function takes an optional title list (tests); default Data/Titles.
-- S121: an optional account context as the last argument; the VIP title (req.kind "vip") is unlocked only with
-- ctx.vip == true, so every call without a context keeps the VIP title locked.
-- S123: bought titles (req.kind "cosmetic") are unlocked only with ctx.owned[req.id] == true (the account owns the
-- cosmetic of kind title); Titles.contextOf builds the context the same way on the server and the client.
-- S125: timed titles (req.kind "timed") are unlocked while character.timedTitles[id] > now; `now` comes in the context
-- (ctx.now, default Util/Clock.now(): the server clock with the /time offset on both sides).
-- S151: achievement titles (req.kind "achievement") are unlocked when the achievement is done: a character achievement
-- in character.ach.done, an account one in ctx.ach (account.ach.done, Titles.contextOf).

local Clock = require("../Util/Clock")
local Paths = require("./Paths")
local TitleData = require("../Data/Titles")

type TitleDef = TitleData.TitleDef

local Titles = {}

-- Account facts a title may need (server: MonetizationService.HasVip; client: the replicated `vip` branch) and, S123,
-- the account's owned cosmetics (account.cosmetics.owned) for bought titles.
-- one context argument for every account-dependent title kind (S121 vip, S123 cosmetic)
-- S125: `now` for timed titles (unix seconds; nil = Clock.now()).
-- S151: `ach` = the account's done achievements (account.ach.done).
export type Context = { vip: boolean?, owned: { [string]: boolean }?, now: number?, ach: { [string]: number }? }

Titles.NONE = TitleData.NONE

-- Progress of a character towards a requirement kind.
local function progress(character: any, kind: string): number
	if kind == "level" then
		return character.level or 0
	elseif kind == "mainDone" then
		return if character.quests then character.quests.mainDone or 0 else 0
	elseif kind == "pvpKills" then
		return if character.pvp then character.pvp.kills or 0 else 0
	elseif kind == "duelsWon" then
		return if character.pvp then character.pvp.duelsWon or 0 else 0
	end
	return 0
end

-- S138: the leading direction of the active set (nil for a view without a class).
local function mainPathOf(character: any): string?
	if type(character) ~= "table" or type(character.class) ~= "string" then
		return nil
	end
	return Paths.mainOf(character)
end

local function nowOf(ctx: Context?): number
	return if ctx ~= nil and type(ctx.now) == "number" then ctx.now else Clock.now()
end

-- S125: until when the timed title `id` is unlocked (nil = never granted or the data is broken).
function Titles.timedUntil(character: any, id: string): number?
	local timed = if type(character) == "table" then character.timedTitles else nil
	local untilTs = if type(timed) == "table" then timed[id] else nil
	return if type(untilTs) == "number" then untilTs else nil
end

-- S128: the season of the latest finished arena season at `tier` (character.arena.titles[tier]), nil when none.
function Titles.arenaSeason(character: any, tier: string): string?
	local arena = if type(character) == "table" then character.arena else nil
	local titles = if type(arena) == "table" then arena.titles else nil
	local season = if type(titles) == "table" then titles[tier] else nil
	return if type(season) == "string" and season ~= "" then season else nil
end

local function meets(character: any, def: TitleDef, ctx: Context?): boolean
	local req = def.req
	if req.kind == "timed" then
		local untilTs = Titles.timedUntil(character, def.id)
		return untilTs ~= nil and untilTs > nowOf(ctx)
	elseif req.kind == "mainPath" then
		return mainPathOf(character) == req.path
	elseif req.kind == "vip" then
		return ctx ~= nil and ctx.vip == true
	elseif req.kind == "cosmetic" then
		return ctx ~= nil and ctx.owned ~= nil and ctx.owned[req.id] == true
	elseif req.kind == "achievement" then
		-- S151: either scope; achievement ids are unique over both
		local own = if type(character) == "table" and type(character.ach) == "table" then character.ach.done else nil
		if type(own) == "table" and own[req.id] ~= nil then
			return true
		end
		return ctx ~= nil and ctx.ach ~= nil and ctx.ach[req.id] ~= nil
	elseif req.kind == "arenaSeason" then
		-- S128: only the character (character.arena.titles[tier]); the account context stays as it is
		return Titles.arenaSeason(character, req.tier) ~= nil
	end
	return progress(character, req.kind) >= (req :: any).value
end

-- S123: the context of an account (anything with cosmetics.owned) and its VIP state (a subscription is not in the
-- account: the server passes MonetizationService.HasVip, the client the replicated `vip` branch).
function Titles.contextOf(account: any, vip: boolean?, now: number?): Context
	local cosmetics = if type(account) == "table" then account.cosmetics else nil
	local owned = if type(cosmetics) == "table" and type(cosmetics.owned) == "table" then cosmetics.owned else nil
	-- S151: the account's done achievements
	local ach = if type(account) == "table" then account.ach else nil
	local done = if type(ach) == "table" and type(ach.done) == "table" then ach.done else nil
	return { vip = vip == true, owned = owned, now = now, ach = done }
end

-- S125: a new map with `id` unlocked until `untilTs` (the later of the old and the new term; the input is not
-- changed, so a repeated grant never shortens a title).
function Titles.grantTimed(timed: { [string]: number }?, id: string, untilTs: number): { [string]: number }
	local out: { [string]: number } = if type(timed) == "table" then table.clone(timed) else {}
	local old = out[id]
	out[id] = if type(old) == "number" then math.max(old, untilTs) else untilTs
	return out
end

-- S125: a copy without the entries that ended at or before `now`, and whether anything was removed.
function Titles.pruneTimed(timed: { [string]: number }?, now: number): ({ [string]: number }, boolean)
	local out: { [string]: number } = {}
	local removed = false
	if type(timed) == "table" then
		for id, untilTs in timed do
			if type(untilTs) == "number" and untilTs > now then
				out[id] = untilTs
			else
				removed = true
			end
		end
	end
	return out, removed
end

local function find(id: string, list: { TitleDef }?): TitleDef?
	if list == nil then
		return TitleData.get(id)
	end
	for _, def in list do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- S128: the arguments of a title's name: { season = "YYYYMM" } for a title with seasonArg (the client formats it,
-- Logic/ArenaRules.seasonLabel), nil otherwise or without a season. Only for the name, never for unlocking.
function Titles.argsOf(character: any, id: string, list: { TitleDef }?): { [string]: string }?
	local def = find(id, list)
	if not def or def.seasonArg ~= true or def.req.kind ~= "arenaSeason" then
		return nil
	end
	local season = Titles.arenaSeason(character, (def.req :: any).tier)
	return if season then { season = season } else nil
end

function Titles.isUnlocked(character: any, id: string, list: { TitleDef }?, ctx: Context?): boolean
	local def = find(id, list)
	return def ~= nil and meets(character, def, ctx)
end

-- Unlocked title ids in display order.
function Titles.unlocked(character: any, list: { TitleDef }?, ctx: Context?): { string }
	local result = {}
	for _, def in list or TitleData.list do
		if meets(character, def, ctx) then
			table.insert(result, def.id)
		end
	end
	return result
end

-- The title of the character's leading direction (nil without one or without its title).
function Titles.pathTitle(character: any, list: { TitleDef }?): string?
	local main = mainPathOf(character)
	if main == nil then
		return nil
	end
	for _, def in list or TitleData.list do
		local req = def.req
		if req.kind == "mainPath" and req.path == main then
			return def.id
		end
	end
	return nil
end

-- The title to show: none when hidden, the chosen one while it is still unlocked, otherwise the leading direction's
-- title.
function Titles.shown(character: any, list: { TitleDef }?, ctx: Context?): string?
	local chosen = character.title
	if chosen == Titles.NONE then
		return nil
	end
	if type(chosen) == "string" and Titles.isUnlocked(character, chosen, list, ctx) then
		return chosen
	end
	return Titles.pathTitle(character, list)
end

return Titles
