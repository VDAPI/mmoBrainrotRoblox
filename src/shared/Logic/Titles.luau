--!strict
-- Which titles a character has unlocked (pure; DESIGN §4, S16).
-- S59 (ROZWOJ 3.2): path titles (req.kind "mainPath") are unlocked while the active set's main path is their path;
-- character.title nil = never chose (the main path title shows), Titles.NONE = the player hid the title. Every
-- function takes an optional title list (tests); default Data/Titles.
-- S121: an optional account context as the last argument; the VIP title (req.kind "vip") is unlocked only with
-- ctx.vip == true, so every call without a context keeps the VIP title locked.
-- S123: bought titles (req.kind "cosmetic") are unlocked only with ctx.owned[req.id] == true (the account owns the
-- cosmetic of kind title); Titles.contextOf builds the context the same way on the server and the client.

local TitleData = require("../Data/Titles")

type TitleDef = TitleData.TitleDef

local Titles = {}

-- Account facts a title may need (server: MonetizationService.HasVip; client: the replicated `vip` branch) and, S123,
-- the account's owned cosmetics (account.cosmetics.owned) for bought titles.
-- one context argument for every account-dependent title kind (S121 vip, S123 cosmetic)
export type Context = { vip: boolean?, owned: { [string]: boolean }? }

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

local function mainPathOf(character: any): string?
	local state = character.path
	return if type(state) == "table" and type(state.main) == "string" then state.main else nil
end

local function meets(character: any, req: TitleData.Requirement, ctx: Context?): boolean
	if req.kind == "mainPath" then
		return mainPathOf(character) == req.path
	elseif req.kind == "vip" then
		return ctx ~= nil and ctx.vip == true
	elseif req.kind == "cosmetic" then
		return ctx ~= nil and ctx.owned ~= nil and ctx.owned[req.id] == true
	end
	return progress(character, req.kind) >= (req :: any).value
end

-- S123: the context of an account (anything with cosmetics.owned) and its VIP state (a subscription is not in the
-- account: the server passes MonetizationService.HasVip, the client the replicated `vip` branch).
function Titles.contextOf(account: any, vip: boolean?): Context
	local cosmetics = if type(account) == "table" then account.cosmetics else nil
	local owned = if type(cosmetics) == "table" and type(cosmetics.owned) == "table" then cosmetics.owned else nil
	return { vip = vip == true, owned = owned }
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

function Titles.isUnlocked(character: any, id: string, list: { TitleDef }?, ctx: Context?): boolean
	local def = find(id, list)
	return def ~= nil and meets(character, def.req, ctx)
end

-- Unlocked title ids in display order.
function Titles.unlocked(character: any, list: { TitleDef }?, ctx: Context?): { string }
	local result = {}
	for _, def in list or TitleData.list do
		if meets(character, def.req, ctx) then
			table.insert(result, def.id)
		end
	end
	return result
end

-- The title of the character's main path (nil without a main path or without its title).
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

-- The title to show: none when hidden, the chosen one while it is still unlocked, otherwise the main path title.
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
