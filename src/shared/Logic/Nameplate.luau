--!strict
-- S135: what a player's nameplate shows (NameplateController draws it on iron, DESIGN §23). Pure (Lune test
-- tests/nameplate.spec).
--   Nameplate.view(input, cfg?) -> View
--   Nameplate.monster(input) -> MonsterView   (S136, MonsterPlateController)
--   Nameplate.npc(input) -> NpcView           (S136, NpcController and CompanionController)
-- Name colour role by priority: an enemy (PvP on or a red zone) > your own plate > VIP > plain. The title line only
-- with a known title definition (its colour made readable on iron by the client). Beyond cfg.detailDistance (the
-- distance from the camera) only the name row stays: no title, level line or HP bar. Your own plate always has the
-- details.

local Config = require("../Config")

local Nameplate = {}

export type NameRole = "hostile" | "own" | "vip" | "text"

export type Input = {
	isLocal: boolean,
	hostile: boolean,
	vip: boolean,
	titleHex: string?, -- the colour of the title definition, nil without a (known) title
	guildTag: string?,
	hurt: boolean, -- HP below full or a recent hit
	distance: number?, -- studs from the camera (nil = near)
}

export type View = {
	nameRole: NameRole,
	swords: boolean, -- "⚔" in front of the name (enemy)
	guildTag: string?,
	showTitle: boolean,
	titleHex: string?,
	showLevel: boolean,
	showHp: boolean,
	showVip: boolean,
	clickable: boolean, -- the name opens the player menu (S133)
}

export type Cfg = { detailDistance: number }

function Nameplate.view(input: Input, cfg: Cfg?): View
	local detail = (cfg or Config.Nameplate).detailDistance
	local near = input.isLocal or input.distance == nil or (input.distance :: number) <= detail
	local role: NameRole = if input.hostile
		then "hostile"
		elseif input.isLocal then "own"
		elseif input.vip then "vip"
		else "text"
	local tag = if input.guildTag ~= nil and input.guildTag ~= "" then input.guildTag else nil
	return {
		nameRole = role,
		swords = input.hostile,
		guildTag = tag,
		showTitle = near and input.titleHex ~= nil,
		titleHex = if near then input.titleHex else nil,
		showLevel = near,
		showHp = near and input.hurt,
		showVip = input.vip,
		clickable = not input.isLocal,
	}
end

-- S136: monster plates (the same iron style as the players'): the name colour role by variant (an unknown variant reads
-- as normal), "↩" and a faded name while the monster walks home, the "×N" group badge only for a group of two or more,
-- the HP numbers and the wider bar only on the selected target.
export type MonsterRole = "normal" | "elite" | "elite2" | "boss"

export type MonsterInput = {
	variant: string?,
	returning: boolean,
	targeted: boolean,
	groupSize: number?,
}

export type MonsterView = {
	nameRole: MonsterRole,
	returning: boolean,
	groupSize: number?, -- nil: no badge
	showHpNumbers: boolean,
	wideBar: boolean,
}

local MONSTER_ROLES: { [string]: MonsterRole } =
	{ normal = "normal", elite = "elite", elite2 = "elite2", boss = "boss" }

function Nameplate.monster(input: MonsterInput): MonsterView
	local n = if type(input.groupSize) == "number" then math.floor(input.groupSize) else 1
	return {
		nameRole = MONSTER_ROLES[input.variant or "normal"] or "normal",
		returning = input.returning,
		groupSize = if n > 1 then n else nil,
		showHpNumbers = input.targeted,
		wideBar = input.targeted,
	}
end

-- S136: NPC plates: the service glyph row only for an NPC with an icon (companions have none), the "your companion" tag
-- only on your own companion; names always in the plain iron text role.
export type NpcInput = {
	icon: string?,
	companion: boolean,
	mine: boolean,
}

export type NpcView = {
	showIcon: boolean,
	showTag: boolean,
	nameRole: NameRole,
}

function Nameplate.npc(input: NpcInput): NpcView
	return {
		showIcon = not input.companion and input.icon ~= nil and input.icon ~= "",
		showTag = input.companion and input.mine,
		nameRole = "text",
	}
end

return Nameplate
