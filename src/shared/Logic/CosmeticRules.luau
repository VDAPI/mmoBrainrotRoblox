--!strict
-- Cosmetic rules of S123 (DESIGN-17 §4), pure: ownership (the only place that knows about `free`), slots, emotes and
-- their blocks, the dye over the worn outfit, the level-up style and the chat decoration. Used by the server
-- (CosmeticService, EmoteService, PremiumShopService), the windows and the client effects.

local Cosmetics = require("../Data/Cosmetics")
local Emotes = require("../Data/Emotes")

type Def = Cosmetics.Def

local CosmeticRules = {}

-- Kinds saved in account.cosmetics.equipped (pets in account.pets, titles on the character through SetTitle, emotes
-- have no slot: every owned emote is in the wheel).
CosmeticRules.SLOT_KINDS = table.freeze({
	"outfit",
	"aura",
	"trail",
	"weapon",
	"mountskin",
	"dye",
	"frame",
	"chatframe",
	"levelup",
})

-- The S22 pillar: GOLD_BRIGHT mirrors Data/UiPalette brass.bright, GOLD keeps the former theme gold (no palette role
-- since S136)
local GOLD_BRIGHT = "#E8C25A"
local GOLD = "#C9A45C"

-- What ownership reads from an account: cosmetics.owned and pets.owned (the server passes AccountData, the windows
-- their replicated branches); typed `any` so every shape of account fits.
export type OwnAccount = any

-- Whether `def` is owned with the owned map of its kind (`free` ones always).
function CosmeticRules.ownsIn(def: Def, owned: { [string]: boolean }?): boolean
	return def.free == true or (owned ~= nil and owned[def.id] == true)
end

-- Whether the account owns `def` (pets in account.pets, everything else in account.cosmetics).
function CosmeticRules.owns(def: Def, account: OwnAccount?): boolean
	if def.free == true then
		return true
	end
	if type(account) ~= "table" then
		return false
	end
	local branch = if def.kind == "pet" then account.pets else account.cosmetics
	local owned = if type(branch) == "table" then branch.owned else nil
	return CosmeticRules.ownsIn(def, if type(owned) == "table" then owned else nil)
end

-- Ids of the emote cosmetics the account may play, in list order.
function CosmeticRules.ownedEmotes(account: OwnAccount?): { string }
	local out: { string } = {}
	for _, def in Cosmetics.list do
		if def.kind == "emote" and CosmeticRules.owns(def, account) then
			table.insert(out, def.id)
		end
	end
	return out
end

-- The emote cosmetic of a motion id (Data/Emotes), nil when none.
function CosmeticRules.emoteCosmetic(emoteId: string): Def?
	for _, def in Cosmetics.list do
		if def.kind == "emote" and def.emote == emoteId then
			return def
		end
	end
	return nil
end

-- "/e <alias>": the cosmetic id, or the error key (unknown alias, or an emote the account does not own).
function CosmeticRules.emoteByAlias(alias: string, account: OwnAccount?): (string?, string?)
	local emote = Emotes.byAlias(alias)
	local def = if emote then CosmeticRules.emoteCosmetic(emote.id) else nil
	if not def then
		return nil, "emote.error.unknown"
	end
	if not CosmeticRules.owns(def, account) then
		return nil, "emote.error.notOwned"
	end
	return def.id, nil
end

export type EmoteInput = {
	owned: boolean,
	dead: boolean,
	combat: boolean,
	riding: boolean,
	casting: boolean,
	last: number, -- when the player's previous emote started (0 = never)
	now: number,
}

-- Whether an emote may start now; the first failing reason in a fixed order.
function CosmeticRules.canEmote(input: EmoteInput): (boolean, string?)
	if not input.owned then
		return false, "emote.error.notOwned"
	elseif input.dead then
		return false, "emote.error.dead"
	elseif input.combat then
		return false, "emote.error.combat"
	elseif input.riding then
		return false, "emote.error.riding"
	elseif input.casting then
		return false, "emote.error.casting"
	elseif input.last > 0 and input.now - input.last < Emotes.COOLDOWN then
		return false, "emote.error.cooldown"
	end
	return true, nil
end

-- The worn outfit's main and second colour after the dye; nil, nil without an outfit or a dye. A dye without `second`
-- keeps the outfit's second colour (its main one when it has none).
function CosmeticRules.dyed(outfit: Def?, dye: Def?): (string?, string?)
	if not outfit or outfit.kind ~= "outfit" or not dye or dye.kind ~= "dye" or not dye.dye then
		return nil, nil
	end
	return dye.dye.main, dye.dye.second or outfit.color2 or outfit.color
end

export type LevelUpLook = { style: string, color: string, color2: string }

-- The level-up effect of an equipped cosmetic; nothing equipped (or another kind) = the gold pillar of S22.
function CosmeticRules.levelUpStyle(def: Def?): LevelUpLook
	local look = if def and def.kind == "levelup" then def.levelup else nil
	if not look then
		return { style = "pillar", color = GOLD_BRIGHT, color2 = GOLD }
	end
	return { style = look.style, color = look.color, color2 = look.color2 or look.color }
end

-- The glyphs and colour around the name in chat, nil without a chat frame.
function CosmeticRules.chatDecor(def: Def?): { left: string, right: string, color: string }?
	local chat = if def and def.kind == "chatframe" then def.chat else nil
	if not chat then
		return nil
	end
	return { left = chat.left, right = chat.right, color = chat.color }
end

-- The speech bubble's colours, nil without a chat frame.
function CosmeticRules.bubble(def: Def?): { bg: string, text: string }?
	local chat = if def and def.kind == "chatframe" then def.chat else nil
	if not chat then
		return nil
	end
	return { bg = chat.bubble, text = chat.bubbleText }
end

-- The portrait frame look, nil without a frame.
function CosmeticRules.frameOf(id: string?): Cosmetics.Frame?
	local def = if type(id) == "string" then Cosmetics.get(id) else nil
	return if def and def.kind == "frame" then def.frame else nil
end

return CosmeticRules
