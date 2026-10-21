--!strict
-- W31 (owner 2026-10-21): the look of an NPC without the owner's model (Data/NpcLooks) as Logic/CharacterLook's
-- LookSpec for Util/AvatarBuild (NpcService): the face, skin, hair, beard and build fixed in the data or picked from the
-- NPC's id (the same on every server and in every test), and the role's garments in the NPC's colours. Pure.

local CharacterLook = require("./CharacterLook")
local ClassLooks = require("../Data/ClassLooks")
local NpcLooks = require("../Data/NpcLooks")

local NpcLook = {}

-- What NpcLook reads of an NPC (Data/Npcs.NpcDef).
export type Def = { id: string, colors: { body: string, accent: string } }

-- a * b mod 2^32 without losing digits in a double
local function mul32(a: number, b: number): number
	local lo, hi = bit32.band(a, 0xFFFF), bit32.rshift(a, 16)
	return (lo * b + ((hi * b) % 0x10000) * 0x10000) % 0x100000000
end

-- A deterministic 0..1 of the id and a salt, one roll per look field: FNV-1a with the MurmurHash3 finish, so the
-- fields of one NPC do not follow each other.
function NpcLook.roll(id: string, salt: string): number
	local text = `{id}|{salt}`
	local h = 2166136261
	for i = 1, #text do
		h = mul32(bit32.bxor(h, string.byte(text, i)), 16777619)
	end
	h = mul32(bit32.bxor(h, bit32.rshift(h, 16)), 0x85EBCA6B)
	h = mul32(bit32.bxor(h, bit32.rshift(h, 13)), 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / 0x100000000
end

local function pick(list: { string }, r: number): string
	return list[math.clamp(math.floor(r * #list) + 1, 1, #list)]
end

-- `hex` ("#RRGGBB") with every channel times k (k < 1 darker), clamped.
function NpcLook.shade(hex: string, k: number): string
	local function channel(from: number): number
		local v = tonumber(string.sub(hex, from, from + 1), 16) or 0
		return math.clamp(math.floor(v * k + 0.5), 0, 255)
	end
	return string.format("#%02X%02X%02X", channel(2), channel(4), channel(6))
end

-- The entry of the NPC in Data/NpcLooks, nil for an NPC without one (the board, an NPC added without a look).
function NpcLook.entry(id: string): NpcLooks.Npc?
	return NpcLooks.npcs[id]
end

-- The face, skin, hair and the rest of the NPC's look (Data/ClassLooks ids), nil without an entry.
function NpcLook.look(def: Def): ClassLooks.Look?
	local entry = NpcLook.entry(def.id)
	local role = entry and NpcLooks.roles[entry.role]
	if not entry or not role then
		return nil
	end
	local fixed: { [string]: string } = entry.look or {}
	local female = entry.female == true
	local id = def.id
	local skins: { string } = {}
	for i = 1, CharacterLook.NATURAL_SKINS do
		table.insert(skins, ClassLooks.SKINS[i].id)
	end
	local brows: { string } = {}
	for _, choice in ClassLooks.BROWS do
		table.insert(brows, choice.id)
	end
	local colors = if entry.old
		then NpcLooks.HAIR_COLORS_OLD
		elseif entry.north then NpcLooks.HAIR_COLORS_NORTH
		else NpcLooks.HAIR_COLORS
	local beard = "beard_none"
	if not female and (entry.old or NpcLook.roll(id, "bearded") < NpcLooks.BEARDED) then
		beard = pick(NpcLooks.BEARDS, NpcLook.roll(id, "beard"))
	end
	return {
		face = fixed.face or pick(if female then NpcLooks.FACES_FEMALE else NpcLooks.FACES, NpcLook.roll(id, "face")),
		skin = fixed.skin or pick(skins, NpcLook.roll(id, "skin")),
		hair = fixed.hair or pick(if female then NpcLooks.HAIRS_FEMALE else NpcLooks.HAIRS, NpcLook.roll(id, "hair")),
		hairColor = fixed.hairColor or pick(colors, NpcLook.roll(id, "hairColor")),
		brows = fixed.brows or pick(brows, NpcLook.roll(id, "brows")),
		beard = if female then "beard_none" else fixed.beard or beard,
		build = fixed.build or role.build or "build_medium",
		paint = "paint_none",
		paintColor = "pc_ochre",
	}
end

-- The NPC's outfit: the role's garments and its own in the NPC's colours, nil without an entry.
function NpcLook.outfit(def: Def): ClassLooks.OutfitSpec?
	local entry = NpcLook.entry(def.id)
	local role = entry and NpcLooks.roles[entry.role]
	if not entry or not role then
		return nil
	end
	local garments = table.clone(role.garments)
	for _, item in entry.add or ({} :: { ClassLooks.Garment }) do
		table.insert(garments, item)
	end
	return {
		colors = {
			main = def.colors.body,
			second = NpcLook.shade(def.colors.body, NpcLooks.SECOND),
			trim = def.colors.accent,
			leather = NpcLooks.LEATHER,
			metal = NpcLooks.METAL,
		},
		body = role.body,
		garments = garments,
		shirt = 0,
		pants = 0,
	}
end

-- What Util/AvatarBuild draws for the NPC (Logic/CharacterLook.resolve), nil without an entry.
function NpcLook.resolve(def: Def): CharacterLook.LookSpec?
	local look, outfit = NpcLook.look(def), NpcLook.outfit(def)
	if not look or not outfit then
		return nil
	end
	return CharacterLook.resolve({ classId = "Npc", look = look, spec = outfit, robloxAvatar = false })
end

return NpcLook
