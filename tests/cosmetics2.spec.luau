--!strict
-- Cosmetics 2 (S123, DESIGN-17 §4): the six new kinds and their fields, wardrobe groups, bought titles, ownership with
-- free emotes, emote aliases and blocks, emote motions, the dye, the level-up style, the cosmetic rules of
-- Logic/Premium, the starter packs and the new account fields.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local CosmeticRules = require("../src/shared/Logic/CosmeticRules")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Emotes = require("../src/shared/Data/Emotes")
local Premium = require("../src/shared/Logic/Premium")
local Products = require("../src/shared/Data/Products")
local SkillMotions = require("../src/shared/Data/SkillMotions")
local T = require("./Test")
local TitleData = require("../src/shared/Data/Titles")
local Titles = require("../src/shared/Logic/Titles")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local NEW_KINDS = { "dye", "frame", "chatframe", "title", "emote", "levelup" }
-- The field each new kind carries; no other kind may have it.
local FIELD_OF: { [string]: string } =
	{ dye = "dye", frame = "frame", chatframe = "chat", title = "title", emote = "emote", levelup = "levelup" }
-- KATALOG.md price ranges of what is sold (no obtain, not free).
local RANGES: { [string]: { number } } = {
	frame = { 100, 300 },
	chatframe = { 100, 250 },
	title = { 100, 250 },
	emote = { 50, 150 },
	levelup = { 250, 600 },
	dye = { 30, 60 },
}
local STYLES = { pillar = true, rings = true, runes = true, embers = true, frost = true }
local HEX = "^#%x%x%x%x%x%x$"

local function hex(value: any): boolean
	return type(value) == "string" and string.match(value, HEX) ~= nil
end

local function account(owned: { [string]: boolean }?, pets: { [string]: boolean }?): any
	return { cosmetics = { owned = owned or {}, equipped = {} }, pets = { owned = pets or {} } }
end

T.describe("Cosmetics 2: kinds and groups (S123)", function()
	T.it("the six new kinds, each in exactly one group, all named in both languages", function()
		for _, kind in NEW_KINDS do
			T.expect({ kind, table.find(Cosmetics.kinds, kind :: any) ~= nil }).toEqual({ kind, true })
		end
		local groupOf: { [string]: string } = {}
		for _, group in Cosmetics.groups do
			T.expect({ group.id, #group.kinds >= 1 }).toEqual({ group.id, true })
			local key = `wardrobe.group.{group.id}`
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
			for _, kind in group.kinds do
				T.expect({ kind, groupOf[kind] }).toEqual({ kind, nil })
				groupOf[kind] = group.id
			end
		end
		for _, kind in Cosmetics.kinds do
			T.expect({ kind, groupOf[kind] ~= nil }).toEqual({ kind, true })
			local key = `wardrobe.kind.{kind}`
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
		end
	end)

	T.it("new entries carry their kind's field, never another's, priced in the catalogue ranges", function()
		local count = 0
		for _, def in Cosmetics.list do
			local raw = def :: any
			if FIELD_OF[def.kind] then
				count += 1
			end
			for kind, field in FIELD_OF do
				if kind ~= def.kind then
					T.expect({ def.id, field, raw[field] }).toEqual({ def.id, field, nil })
				end
			end
			if def.kind == "frame" then
				local f = def.frame :: Cosmetics.Frame
				T.expect({ def.id, hex(f.stroke), f.thickness >= 1 and f.thickness <= 6 })
					.toEqual({ def.id, true, true })
				T.expect({ def.id, f.stroke2 == nil or hex(f.stroke2) }).toEqual({ def.id, true })
			elseif def.kind == "chatframe" then
				local c = def.chat :: Cosmetics.ChatFrame
				T.expect({ def.id, hex(c.color), hex(c.bubble), hex(c.bubbleText) })
					.toEqual({ def.id, true, true, true })
				T.expect({ def.id, #c.left > 0 and #c.right > 0 }).toEqual({ def.id, true })
			elseif def.kind == "title" then
				local title = TitleData.get(def.title or "")
				T.expect({ def.id, title ~= nil }).toEqual({ def.id, true })
			elseif def.kind == "emote" then
				T.expect({ def.id, Emotes.get(def.emote or "") ~= nil }).toEqual({ def.id, true })
			elseif def.kind == "levelup" then
				local l = def.levelup :: Cosmetics.LevelUp
				T.expect({ def.id, STYLES[l.style] == true, hex(l.color) }).toEqual({ def.id, true, true })
			elseif def.kind == "dye" then
				local d = def.dye :: Cosmetics.Dye
				T.expect({ def.id, hex(d.main), d.second == nil or hex(d.second) }).toEqual({ def.id, true, true })
			end
			-- price 0 exactly when free or earned somewhere else
			T.expect({ def.id, def.price == 0 }).toEqual({ def.id, def.free == true or def.obtain ~= nil })
			local range = RANGES[def.kind]
			if range and def.obtain == nil and def.free ~= true then
				T.expect({ def.id, def.price >= range[1] and def.price <= range[2] }).toEqual({ def.id, true })
			end
		end
		T.expect(count >= 32).toBe(true)
		for _, id in { "outfit_wayfarer", "pet_hound", "aura_valor" } do
			T.expect({ id, Cosmetics.get(id) ~= nil }).toEqual({ id, true })
		end
	end)
end)

T.describe("Cosmetics 2: bought titles (S123)", function()
	local function hero(title: string?): any
		return { level = 30, title = title, path = { main = nil, nodes = {}, bp = {}, freeUsed = true } }
	end

	T.it("every title cosmetic has its title and every bought title its cosmetic", function()
		local cosmeticOf: { [string]: string } = {}
		for _, def in Cosmetics.list do
			if def.kind == "title" then
				cosmeticOf[def.title :: string] = def.id
			end
		end
		local bought = 0
		for _, def in TitleData.list do
			local req: any = def.req
			if req.kind == "cosmetic" then
				bought += 1
				T.expect({ def.id, cosmeticOf[def.id] }).toEqual({ def.id, req.id })
			end
		end
		local n = 0
		for title, id in cosmeticOf do
			n += 1
			local def = TitleData.get(title)
			local req: any = def and def.req
			T.expect({ id, req and req.kind, req and req.id }).toEqual({ id, "cosmetic", id })
		end
		T.expect(bought).toBe(n)
		T.expect(bought >= 5).toBe(true)
	end)

	T.it("a bought title needs the owned cosmetic in the context", function()
		local c = hero(nil)
		T.expect(Titles.isUnlocked(c, "pilgrim")).toBe(false)
		T.expect(Titles.isUnlocked(c, "pilgrim", nil, { owned = {} })).toBe(false)
		T.expect(Titles.isUnlocked(c, "pilgrim", nil, { owned = { title_pilgrim = true } })).toBe(true)
		local ctx = Titles.contextOf(account({ title_pilgrim = true, title_highborn = true }), true)
		T.expect(ctx.vip).toBe(true)
		T.expect(ctx.owned and ctx.owned.title_pilgrim).toBe(true)
		T.expect(Titles.isUnlocked(c, "vip", nil, ctx)).toBe(true)
		local list = Titles.unlocked(c, nil, ctx)
		local pilgrim = table.find(list, "pilgrim")
		local highborn = table.find(list, "highborn")
		T.expect(pilgrim ~= nil and highborn ~= nil and (pilgrim :: number) < (highborn :: number)).toBe(true)
		T.expect(table.find(list, "lorekeeper")).toBeNil()
		-- chosen without the context: like a locked title (the path title or nothing)
		T.expect(Titles.shown(hero("pilgrim"))).toBeNil()
		T.expect(Titles.shown(hero("pilgrim"), nil, ctx)).toBe("pilgrim")
		T.expect(Titles.contextOf(nil, nil).vip).toBe(false)
	end)
end)

T.describe("Cosmetics 2: ownership and emotes (S123)", function()
	T.it("free emotes are owned by everyone, pets only from pets.owned", function()
		local wave = Cosmetics.get("emote_wave") :: Cosmetics.Def
		local fox = Cosmetics.get("pet_fox") :: Cosmetics.Def
		T.expect(CosmeticRules.owns(wave, account())).toBe(true)
		T.expect(CosmeticRules.owns(wave, nil)).toBe(true)
		T.expect(CosmeticRules.owns(fox, account(nil, { pet_fox = true }))).toBe(true)
		T.expect(CosmeticRules.owns(fox, account({ pet_fox = true }, nil))).toBe(false)
		T.expect(CosmeticRules.ownedEmotes(account())).toEqual({ "emote_wave", "emote_point" })
		local free = 0
		for _, def in Cosmetics.list do
			if def.free == true then
				free += 1
				T.expect({ def.id, def.kind }).toEqual({ def.id, "emote" })
			end
		end
		T.expect(free).toBe(2)
	end)

	T.it("/e aliases: case-insensitive, owned, unknown", function()
		T.expect({ CosmeticRules.emoteByAlias("UKLON", account({ emote_bow = true })) }).toEqual({ "emote_bow", nil })
		T.expect({ CosmeticRules.emoteByAlias("bow", account()) }).toEqual({ nil, "emote.error.notOwned" })
		T.expect({ CosmeticRules.emoteByAlias("dance", account()) }).toEqual({ nil, "emote.error.unknown" })
		T.expect({ CosmeticRules.emoteByAlias("machaj", account()) }).toEqual({ "emote_wave", nil })
		local seen: { [string]: boolean } = {}
		for _, emote in Emotes.list do
			for _, alias in emote.aliases do
				T.expect({ alias, seen[alias] }).toEqual({ alias, nil })
				seen[alias] = true
				T.expect({ alias, string.match(alias, "^[a-z]+$") ~= nil }).toEqual({ alias, true })
			end
		end
	end)

	T.it("emote blocks in their order and the cooldown", function()
		local base = {
			owned = true,
			dead = false,
			combat = false,
			riding = false,
			casting = false,
			last = 100,
			now = 200,
		}
		local function with(change: { [string]: any }): any
			local c: { [string]: any } = table.clone(base) :: any
			for k, v in change do
				c[k] = v
			end
			return c
		end
		T.expect({ CosmeticRules.canEmote(base) }).toEqual({ true, nil })
		T.expect({ CosmeticRules.canEmote(with({ owned = false, dead = true })) }).toEqual({
			false,
			"emote.error.notOwned",
		})
		T.expect({ CosmeticRules.canEmote(with({ dead = true, combat = true })) })
			.toEqual({ false, "emote.error.dead" })
		T.expect({ CosmeticRules.canEmote(with({ combat = true, riding = true })) }).toEqual({
			false,
			"emote.error.combat",
		})
		T.expect({ CosmeticRules.canEmote(with({ riding = true, casting = true })) }).toEqual({
			false,
			"emote.error.riding",
		})
		T.expect({ CosmeticRules.canEmote(with({ casting = true })) }).toEqual({ false, "emote.error.casting" })
		T.expect({ CosmeticRules.canEmote(with({ now = 102.9 })) }).toEqual({ false, "emote.error.cooldown" })
		T.expect({ CosmeticRules.canEmote(with({ now = 103 })) }).toEqual({ true, nil })
		T.expect({ CosmeticRules.canEmote(with({ last = 0, now = 1 })) }).toEqual({ true, nil })
	end)

	T.it("emote motions: rising keys, known joints and sizes, no combat events, loops inside the keys", function()
		local size = SkillMotions.SIZE :: { [string]: number }
		for _, emote in Emotes.list do
			local m = emote.motion
			local raw = m :: any
			for _, event in { "hit", "release", "land", "lock" } do
				T.expect({ emote.id, event, raw[event] }).toEqual({ emote.id, event, nil })
			end
			T.expect({ emote.id, m.recover > 0, #m.keys >= 1 }).toEqual({ emote.id, true, true })
			local t = 0
			for _, key in m.keys do
				T.expect({ emote.id, key.t > t }).toEqual({ emote.id, true })
				t = key.t
				for joint, value in key.pose do
					T.expect({ emote.id, joint, table.find(SkillMotions.JOINTS, joint) ~= nil }).toEqual({
						emote.id,
						joint,
						true,
					})
					T.expect({ emote.id, joint, #value }).toEqual({ emote.id, joint, size[joint] or 3 })
				end
			end
			if m.loop then
				local loop = m.loop
				T.expect({ emote.id, loop.from >= m.keys[1].t, loop.to <= t, loop.from < loop.to }).toEqual({
					emote.id,
					true,
					true,
					true,
				})
			end
			-- exactly one cosmetic per emote
			local n = 0
			for _, def in Cosmetics.list do
				if def.kind == "emote" and def.emote == emote.id then
					n += 1
				end
			end
			T.expect({ emote.id, n }).toEqual({ emote.id, 1 })
		end
		T.expect(#Emotes.list).toBe(8)
		T.expect(Emotes.COOLDOWN).toBe(3)
	end)
end)

T.describe("Cosmetics 2: dye and level-up (S123)", function()
	T.it("a dye recolours the worn outfit", function()
		local royal = Cosmetics.get("outfit_royal")
		local azure = Cosmetics.get("dye_azure")
		T.expect({ CosmeticRules.dyed(royal, azure) }).toEqual({ "#1F4E8C", "#D8D2C0" })
		local half: any = { id = "dye_half", kind = "dye", dye = { main = "#101010" } }
		T.expect({ CosmeticRules.dyed(royal, half) }).toEqual({ "#101010", (royal :: Cosmetics.Def).color2 })
		T.expect({ CosmeticRules.dyed(nil, azure) }).toEqual({ nil, nil })
		T.expect({ CosmeticRules.dyed(royal, nil) }).toEqual({ nil, nil })
		T.expect({ CosmeticRules.dyed(azure, royal) }).toEqual({ nil, nil })
	end)

	T.it("level-up styles: the gold pillar by default", function()
		local default = CosmeticRules.levelUpStyle(nil)
		T.expect(default.style).toBe("pillar")
		T.expect(hex(default.color) and hex(default.color2)).toBe(true)
		T.expect(CosmeticRules.levelUpStyle(Cosmetics.get("levelup_frost")).style).toBe("frost")
		T.expect(CosmeticRules.levelUpStyle(Cosmetics.get("frame_royal")).style).toBe("pillar")
		T.expect(CosmeticRules.chatDecor(Cosmetics.get("chatframe_royal"))).toEqual({
			left = "⟨",
			right = "⟩",
			color = "#E8C25A",
		})
		T.expect(CosmeticRules.bubble(Cosmetics.get("frame_royal"))).toBeNil()
		T.expect(CosmeticRules.frameOf("frame_runic") ~= nil).toBe(true)
		T.expect(CosmeticRules.frameOf("dye_gold")).toBeNil()
	end)
end)

T.describe("Cosmetics 2: Premium rules and starter packs (S123)", function()
	T.it("free, pack and slotless cosmetics", function()
		T.expect({ Premium.canBuyCosmetic("emote_wave", {}, 1e6) }).toEqual({ false, "premium.error.owned" })
		T.expect({ Premium.canBuyCosmetic("pet_hound", {}, 1e6) }).toEqual({ false, "premium.error.notForSale" })
		T.expect({ Premium.canBuyCosmetic("aura_valor", {}, 1e6) }).toEqual({ false, "premium.error.notForSale" })
		T.expect((Premium.canBuyCosmetic("emote_bow", {}, 50))).toBe(true)
		T.expect({ Premium.canEquip("emote", "emote_bow", { emote_bow = true }) })
			.toEqual({ false, "error.badRequest" })
		T.expect({ Premium.canEquip("title", "title_pilgrim", { title_pilgrim = true }) }).toEqual({
			false,
			"error.badRequest",
		})
		T.expect({ Premium.canEquip("frame", "frame_bronze", { frame_bronze = true }) }).toEqual({ true, nil })
		T.expect({ Premium.canEquip("frame", "frame_bronze", {}) }).toEqual({ false, "premium.error.notOwned" })
		T.expect({ Premium.canEquip("frame", nil, {}) }).toEqual({ true, nil })
		T.expect({ Premium.canEquip("dye", "frame_bronze", { frame_bronze = true }) }).toEqual({
			false,
			"error.badRequest",
		})
		-- SLOT_KINDS (plus pets) is the one list of equippable kinds: every kind of it exists, emotes and titles are not in it
		for _, kind in CosmeticRules.SLOT_KINDS do
			T.expect(table.find(Cosmetics.kinds, kind :: any) ~= nil).toBe(true)
			T.expect((Premium.canEquip(kind, nil, {}))).toBe(true)
		end
		T.expect((Premium.canEquip("pet", nil, {}))).toBe(true)
		T.expect((Premium.canEquip("emote", nil, {}))).toBe(false)
		T.expect((Premium.canEquip("title", nil, {}))).toBe(false)
	end)

	T.it("a starter pack once per account", function()
		T.expect({ Premium.canBuyPack("starter_hero", { packs = {} }) }).toEqual({ true, nil })
		T.expect({ Premium.canBuyPack("starter_hero", { packs = { starter_hero = true } }) }).toEqual({
			false,
			"premium.error.owned",
		})
		T.expect({ Premium.canBuyPack("nope", { packs = {} }) }).toEqual({ false, "error.badRequest" })
		T.expect(Premium.packVisible("starter_hero", { packs = {} })).toBe(true)
		T.expect(Premium.packVisible("starter_hero", { packs = { starter_hero = true } })).toBe(false)
		T.expect(Premium.packVisible("nope", { packs = {} })).toBe(false)
	end)

	T.it("the two packs of DESIGN-17 §4", function()
		local packs = Products.starterPacks
		T.expect(#packs).toBe(2)
		local want = {
			starter_wanderer = { robux = 199, shards = 500 },
			starter_hero = { robux = 799, shards = 2200 },
		}
		local other: { [string]: boolean } = {}
		for _, list in { Products.shardPacks, Products.passes, Products.shop, Products.mounts, Products.subscriptions } do
			for _, entry in list :: { any } do
				other[entry.key] = true
			end
		end
		other[Products.respawn.key] = true
		for _, pack in packs do
			local w = want[pack.key]
			T.expect({ pack.key, w ~= nil }).toEqual({ pack.key, true })
			T.expect({ pack.key, pack.robux, pack.shards, pack.productId }).toEqual({ pack.key, w.robux, w.shards, 0 })
			T.expect({ pack.key, other[pack.key] }).toEqual({ pack.key, nil })
			T.expect(Products.getStarterPack(pack.key)).toBe(pack)
			for _, id in pack.cosmetics do
				local def = Cosmetics.get(id)
				T.expect({ id, def and def.obtain and def.obtain.pack }).toEqual({ id, pack.key })
			end
			for _, key in pack.passes do
				T.expect({ key, Products.getPass(key) ~= nil }).toEqual({ key, true })
			end
			for _, key in { `premium.pack.{pack.key}`, `premium.pack.{pack.key}.desc` } do
				T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
			end
		end
		T.expect((Products.getStarterPack("starter_hero") :: Products.StarterPack).passes).toEqual({ "pockets" })
	end)

	T.it("the account has packs and grantedPasses without a migration", function()
		local template = AccountSchema.accountTemplate()
		T.expect(template.packs).toEqual({})
		T.expect(template.grantedPasses).toEqual({})
		local old: any = AccountSchema.accountTemplate()
		old.packs = nil
		old.grantedPasses = nil
		local schema = AccountSchema.CURRENT
		AccountSchema.migrate(old)
		T.expect(old.packs).toEqual({})
		T.expect(old.grantedPasses).toEqual({})
		T.expect(AccountSchema.CURRENT).toBe(schema)
		T.expect(old.schema).toBe(schema)
	end)
end)

return nil
