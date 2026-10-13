--!strict
-- mounts.json (S97, DESIGN-15 §2 / §6): the riding numbers (Config.Mount), every published mount (start level, where
-- it comes from, the chance and kills of a boss mount, the swatch of its look), the levels 1..maxLevel (speed,
-- mounting, the upgrade cost from Data/Mounts.UPGRADE) and the mount skins (Data/Cosmetics kind "mountskin": shop,
-- boss or quest, never a price). Reads Data/Mounts, Config, Logic/Mounts, Data/Cosmetics, Data/Bosses and the quest
-- titles; NEVER Data/Products: a premium mount (source "premium") is left out always, like every `wiki == false` one.

local Config = require("../../src/shared/Config")
local Cosmetics = require("../../src/shared/Data/Cosmetics")
local MountData = require("../../src/shared/Data/Mounts")
local MountLogic = require("../../src/shared/Logic/Mounts")
local Names = require("./Names")
local Schema = require("./Schema")

local S = Schema
local arr, rec = S.arr, S.rec

local Mounts = {}

S.file(
	"mounts",
	rec("MountsFile", {
		config = rec("MountConfig", {
			minLevel = "int",
			maxLevel = "int",
			baseMul = "number",
			maxMul = "number",
			mountTime = "number",
			mountTimeFast = "number",
			fastFromLevel = "int",
		}),
		mounts = arr(rec("Mount", {
			id = "string",
			name = "name",
			["desc?"] = "name",
			startLevel = "int",
			source = "string",
			["boss?"] = "ref:bosses",
			["chance?"] = "number",
			["kills?"] = "int",
			color = "color",
			["color2?"] = "color",
		})),
		levels = arr(rec("MountLevel", {
			level = "int",
			speedMul = "number",
			mountTime = "number",
			["charLevel?"] = "int",
			["gold?"] = "int",
			["materials?"] = arr(rec("MountMaterial", { id = "ref:items", n = "int" })),
		})),
		skins = arr(rec("MountSkin", {
			id = "string",
			name = "name",
			source = "string",
			["boss?"] = "ref:bosses",
			["chance?"] = "number",
			["quest?"] = "name",
		})),
	})
)

local function round(n: number, digits: number): number
	local k = 10 ^ digits
	return math.floor(n * k + 0.5) / k
end

-- The boss that drops a mount skin and its chance (Data/Mounts.BOSS_DROPS).
local function skinDrop(id: string): (string?, number?)
	for bossId, drop in MountData.BOSS_DROPS do
		if drop.skin == id then
			return bossId, drop.skinChance
		end
	end
	return nil, nil
end

function Mounts.build(ctx: any): any
	local M = Config.Mount
	local mounts = {}
	for _, def in MountData.list do
		-- premium mounts never (whatever their product says), unpublished ones neither
		if def.source == "premium" or def.wiki == false or ctx.hidden[def.id] then
			continue
		end
		local drop = if def.source == "boss" and def.boss then MountData.BOSS_DROPS[def.boss] else nil
		local chance = if drop and drop.mount == def.id then drop.mountChance else nil
		table.insert(mounts, {
			id = def.id,
			name = Names.of(def.nameKey),
			desc = Names.opt(`mount.{def.id}.desc`),
			startLevel = def.startLevel,
			source = def.source,
			boss = if def.source == "boss" and def.boss and not ctx.hidden[def.boss] then def.boss else nil,
			chance = chance,
			kills = if chance then math.floor(MountLogic.expectedKills(chance) + 0.5) else nil,
			color = def.look.colors.base,
			color2 = def.look.colors.accent,
		})
	end
	local levels = {}
	for level = 1, M.maxLevel do
		local step = MountLogic.upgradeCost(level)
		local materials = nil
		if step then
			materials = {}
			for _, m in step.materials do
				table.insert(materials, { id = m.id, n = m.n })
			end
		end
		table.insert(levels, {
			level = level,
			speedMul = round(MountLogic.speedMul(level), 4),
			mountTime = MountLogic.mountTime(level),
			charLevel = if step then step.level else nil,
			gold = if step then step.gold else nil,
			materials = materials,
		})
	end
	local skins = {}
	for _, c in Cosmetics.list do
		if c.kind ~= "mountskin" or ctx.hidden[c.id] then
			continue
		end
		local obtain = c.obtain
		local bossId, chance = skinDrop(c.id)
		local source = if obtain and obtain.boss then "boss" elseif obtain and obtain.quest then "quest" else "shop"
		table.insert(skins, {
			id = c.id,
			name = Names.of(c.nameKey),
			source = source,
			boss = if source == "boss" then bossId or (obtain and obtain.boss) else nil,
			chance = if source == "boss" then chance else nil,
			quest = if source == "quest"
					and obtain
					and obtain.quest
				then Names.of(`quest.{obtain.quest}.title`)
				else nil,
		})
	end
	return {
		config = {
			minLevel = M.minLevel,
			maxLevel = M.maxLevel,
			baseMul = M.baseMul,
			maxMul = M.maxMul,
			mountTime = M.mountTime,
			mountTimeFast = M.mountTimeFast,
			fastFromLevel = M.fastFromLevel,
		},
		mounts = mounts,
		levels = levels,
		skins = skins,
	}
end

return Mounts
