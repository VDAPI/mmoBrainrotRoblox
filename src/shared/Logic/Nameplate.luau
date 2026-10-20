--!strict
-- S135: what a player's nameplate shows (NameplateController draws it, DESIGN §23). Pure (Lune test
-- tests/nameplate.spec).
--   Nameplate.view(input, cfg?) -> View
--   Nameplate.scale(distance, cfg?) -> number   (W28)
--   Nameplate.monster(input) -> MonsterView   (S136, MonsterPlateController)
--   Nameplate.npc(input) -> NpcView           (S136, NpcController and CompanionController)
-- Name colour role by priority: an enemy (PvP on or a red zone) > your own plate > VIP > plain. The title line only
-- with a known title definition. Beyond cfg.detailDistance (the distance from the camera) only the name stays: no
-- title or HP bar. Your own plate always has the title and never an HP bar (the HUD shows it).
-- W28 (owner: "too visible, too big, with a frame; just the nick and the title"): no plate, no level line, no VIP
-- badge, no PvP dot; the PvP state is the name colour.

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
	guildTag: string?,
	showTitle: boolean,
	titleHex: string?,
	showHp: boolean,
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
		guildTag = tag,
		showTitle = near and input.titleHex ~= nil,
		titleHex = if near then input.titleHex else nil,
		showHp = near and input.hurt and not input.isLocal,
		clickable = not input.isLocal,
	}
end

export type ScaleCfg = { scaleNear: number, scaleFar: number, scaleMin: number, scaleStep: number }

-- W28: the size factor of a plate (UIScale) by its distance from the camera: 1 up to scaleNear studs (never larger,
-- so a close camera never gets a huge name), falling linearly to scaleMin at scaleFar and beyond, rounded to
-- scaleStep (the controller sets it only on a change). Unknown distance = 1.
function Nameplate.scale(distance: number?, cfg: ScaleCfg?): number
	local c: ScaleCfg = cfg or Config.Nameplate :: any
	if distance == nil or distance ~= distance or distance <= c.scaleNear then
		return 1
	end
	local t = math.clamp((distance - c.scaleNear) / math.max(c.scaleFar - c.scaleNear, 1), 0, 1)
	local raw = 1 - t * (1 - c.scaleMin)
	local stepped = math.floor(raw / c.scaleStep + 0.5) * c.scaleStep
	return math.clamp(stepped, c.scaleMin, 1)
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
