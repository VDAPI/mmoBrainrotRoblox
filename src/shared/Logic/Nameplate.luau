--!strict
-- S135: what a player's nameplate shows (NameplateController draws it on iron, DESIGN §23). Pure (Lune test
-- tests/nameplate.spec).
--   Nameplate.view(input, cfg?) -> View
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

return Nameplate
