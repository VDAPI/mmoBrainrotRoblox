--!strict
-- Shared helpers of the world map cards (S25): the card context (what the window lends the cards), names,
-- band colours, the distance / route line, the Guide / Walk / Centre actions, monster rows and the words used
-- instead of drop percentages.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local DetailCard = require(script.Parent.DetailCard)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local MapRoute = require(ReplicatedStorage.Shared.Logic.MapRoute)
local MapSketch = require(script.Parent.Parent.Parent.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local NavTarget = require(script.Parent.Parent.Parent.NavTarget)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

type Action = DetailCard.Action
type Target = NavTarget.Target

export type Context = {
	here: string?, -- the player's map
	position: Vector3?, -- the player's world position
	level: number,
	class: string,
	guide: (target: Target) -> (),
	walk: (target: Target) -> (),
	center: (mapId: string, x: number, z: number) -> (),
	showMap: (mapId: string) -> (),
	open: (kind: string, id: string, extra: any?) -> (), -- opens another card (sub-cards get "back")
	back: (() -> ())?, -- set for sub-cards
	openProfile: (userId: number) -> (),
	removeMark: (index: number) -> (),
	refresh: () -> (),
}

local CardKit = {}

CardKit.T = Text.now
local T = CardKit.T

local ZONE_COLORS: { [string]: Color3 } = {
	green = Theme.Colors.ZoneGreen,
	yellow = Theme.Colors.ZoneYellow,
	red = Theme.Colors.ZoneRed,
}

local function isOpen(mapId: string): boolean
	return MapSketch.isBuilt(mapId)
end

local function mapName(mapId: string): string
	local map = Maps.get(mapId)
	return if map then T(map.nameKey) else mapId
end

local function levelsOf(map: Maps.MapDef): string
	return if map.id == "city" then "" else `{map.minLevel}–{map.maxLevel}`
end

local function bandColor(lv: { number }, level: number): Color3
	local range = { lv = lv } :: any
	return Color3.fromHex(LevelBand.COLORS[AreaAdvice.bandOf(range, level)])
end

-- "84 m" on this map, "Another map: Meadows → City" elsewhere, or "No way there yet".
local function whereLine(ctx: Context, mapId: string, x: number, z: number): DetailCard.Line
	if ctx.here == mapId and ctx.position then
		local map = Maps.get(mapId)
		if map then
			local dx = ctx.position.X - (map.offset.x + x)
			local dz = ctx.position.Z - (map.offset.z + z)
			return {
				text = T("worldmap.card.distance", { n = math.floor(math.sqrt(dx * dx + dz * dz)) }),
				color = Theme.Colors.Parchment,
				bold = true,
			}
		end
	end
	local route = if ctx.here then MapRoute.path(ctx.here, mapId, isOpen) else nil
	if not route then
		return { text = T("worldmap.card.noRoute"), color = Theme.Colors.TextMuted }
	end
	local names = {}
	for i = 2, #route do
		table.insert(names, mapName(route[i]))
	end
	return { text = T("worldmap.card.route", { route = table.concat(names, " → ") }), color = Theme.Colors.TextMuted }
end

-- Guide (always), Walk (only on the player's map) and optional extras.
local function moveActions(ctx: Context, target: Target, extra: { Action }?): { Action }
	local actions: { Action } = {
		{
			text = T("worldmap.action.guide"),
			primary = true,
			onClick = function()
				ctx.guide(target)
			end,
		},
	}
	if target.map == ctx.here then
		table.insert(actions, {
			text = T("worldmap.action.walk"),
			onClick = function()
				ctx.walk(target)
			end,
		})
	end
	for _, action in (extra or {}) :: { Action } do
		table.insert(actions, action)
	end
	return actions
end

local function centreAction(ctx: Context, mapId: string, x: number, z: number): Action
	return {
		text = T("worldmap.action.center"),
		onClick = function()
			ctx.center(mapId, x, z)
		end,
	}
end

-- Shop -------------------------------------------------------------------------------------------------------

local function kindRow(ctx: Context, kind: string, lv: { number }, variant: string, from: string): DetailCard.Row
	local def = Monsters.get(kind)
	local name = if def then T((def.nameKeys :: any)[variant] or def.nameKeys.normal) else kind
	local min = if def then math.max(lv[1], def.levels.min) else lv[1]
	local max = if def then math.min(lv[2], def.levels.max) else lv[2]
	return {
		text = `{name}  <font color="#{bandColor({ min, max }, ctx.level):ToHex()}">{min}–{max}</font>`,
		onClick = function()
			ctx.open("monster", kind, { variant = variant, from = from, lv = { min, max } })
		end,
	}
end

local function rarityWord(chance: number): string
	return T(
		if chance >= 0.5
			then "worldmap.card.often"
			elseif chance >= 0.15 then "worldmap.card.sometimes"
			elseif chance >= 0.04 then "worldmap.card.rarely"
			else "worldmap.card.veryRarely"
	)
end

-- Areas and caves where a kind lives.
CardKit.ZONE_COLORS = ZONE_COLORS
CardKit.isOpen = isOpen
CardKit.mapName = mapName
CardKit.levelsOf = levelsOf
CardKit.bandColor = bandColor
CardKit.whereLine = whereLine
CardKit.moveActions = moveActions
CardKit.centreAction = centreAction
CardKit.kindRow = kindRow
CardKit.rarityWord = rarityWord

return CardKit
