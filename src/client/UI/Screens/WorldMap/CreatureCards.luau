--!strict
-- Monster, cave and dungeon cards of the world map (S25): a monster in three variants with a 3D preview, its
-- levels, HP and attack in the middle of the range, element, where it lives and interesting loot (no
-- percentages) and the best rarity the variant can drop (S30); a cave with its kinds, elites, Elite II (timer,
-- 3D) and rooms; a boss dungeon with the boss in 3D, the required level, today's runs ("Dziś: 1/3") with the
-- time to the UTC reset, the current personal Legendary / Mythic chances (growing with the pity counters), the
-- party rule and the boss's named mythic items (item tooltips).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local AreaSpawns = require(ReplicatedStorage.Shared.Logic.AreaSpawns)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local BossScaling = require(ReplicatedStorage.Shared.Logic.BossScaling)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local DetailCard = require(script.Parent.DetailCard)
local Elements = require(ReplicatedStorage.Shared.Data.Elements)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Loot = require(ReplicatedStorage.Shared.Logic.Loot)
local LootTables = require(ReplicatedStorage.Shared.Data.LootTables)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local MonsterStats = require(ReplicatedStorage.Shared.Logic.MonsterStats)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local Portals = require(ReplicatedStorage.Shared.Data.Portals)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local CardKit = require(script.Parent.CardKit)

type Spec = DetailCard.Spec
type Section = DetailCard.Section
type Action = DetailCard.Action
type Context = CardKit.Context

local CreatureCards = {}

local T = CardKit.T
local mapName, bandColor, whereLine, moveActions =
	CardKit.mapName, CardKit.bandColor, CardKit.whereLine, CardKit.moveActions
local kindRow, rarityWord = CardKit.kindRow, CardKit.rarityWord

local function homes(kind: string): { string }
	local out = {}
	for _, mapId in { "meadows", "duskwood", "ashen", "frostpeak" } do
		for _, area in AreaAdvice.sorted(mapId) do
			if table.find(area.kinds, kind) then
				table.insert(out, `{T(area.nameKey)} ({mapName(mapId)}) {area.lv[1]}–{area.lv[2]}`)
			end
		end
	end
	for _, cave in Areas.caves.list do
		local where: { string } = {}
		if table.find(cave.normal, kind) then
			table.insert(where, T("variant.normal"))
		end
		if table.find(cave.elites, kind) then
			table.insert(where, T("variant.elite"))
		end
		if table.find(cave.elite2, kind) then
			table.insert(where, T("variant.elite2"))
		end
		if #where > 0 then
			table.insert(out, `{T(cave.nameKey)} ({table.concat(where, ", ")})`)
		end
	end
	return out
end

function CreatureCards.monster(ctx: Context, kind: string, extra: any?): Spec?
	local def = Monsters.get(kind)
	if not def then
		return nil
	end
	local options = type(extra) == "table" and extra or {}
	local variant: string = options.variant or "normal"
	if not def.elites then
		variant = "normal"
	end
	local lv: { number } = options.lv or { def.levels.min, def.levels.max }
	local mid = math.floor((lv[1] + lv[2]) / 2 + 0.5)
	local stats = MonsterStats.compute(def :: any, mid, variant :: any)
	local color = bandColor({ lv[1], lv[2] }, ctx.level)
	local sections: { Section } = {}
	if def.elites then
		table.insert(sections, {
			choice = {
				options = {
					{ id = "normal", text = T("variant.normal") },
					{ id = "elite", text = T("variant.elite") },
					{ id = "elite2", text = T("variant.elite2") },
				},
				selected = variant,
				onSelect = function(id: string)
					local copy = table.clone(options)
					copy.variant = id
					ctx.open("monster", kind, copy)
				end,
			},
		})
	end
	local statLines: { DetailCard.Line } = {
		{
			text = T("worldmap.card.monsterStats", {
				level = stats.level,
				hp = Format.number(stats.maxHp),
				atk = Format.number(math.floor(stats.attack + 0.5)),
			}),
			color = Theme.Colors.Parchment,
			bold = true,
		},
		{
			text = T(if def.attack == "ranged" then "worldmap.card.ranged" else "worldmap.card.melee"),
			color = Theme.Colors.TextMuted,
		},
	}
	if def.element then
		table.insert(statLines, {
			text = T("worldmap.card.element", { element = T(Elements.nameKey(def.element)) }),
			color = Color3.fromHex(Elements.COLORS[def.element] or "#FFFFFF"),
		})
	end
	if def.passive then
		table.insert(statLines, { text = T("worldmap.card.passive"), color = Theme.Colors.ZoneGreen })
	end
	table.insert(sections, { lines = statLines })
	local where: { DetailCard.Line } = {}
	for _, line in homes(kind) do
		table.insert(where, { text = `• {line}`, size = 14 })
	end
	if #where > 0 then
		table.insert(sections, { title = T("worldmap.card.where"), lines = where })
	end
	-- Interesting loot: the best rarity of the variant (S30 source cap), materials of its table (and the
	-- variant's).
	local cap = Rarities.get(Rarities.cap[variant] or Rarities.UNIQUE)
	local loot: { DetailCard.Line } = {
		{ text = T("worldmap.card.rarityCap", { rarity = T(cap.nameKey) }), color = cap.color, bold = true },
	}
	local tableDef = LootTables.get(def.lootTable)
	if tableDef then
		local drops = table.clone(tableDef.materials)
		for _, drop in (tableDef.variantMaterials[variant] or {}) :: { LootTables.MaterialDrop } do
			table.insert(drops, drop)
		end
		local seen: { [string]: boolean } = {}
		for _, drop in drops do
			if not seen[drop.id] and Items.get(drop.id) then
				seen[drop.id] = true
				table.insert(loot, {
					text = `• {ItemText.name(drop.id)} — {rarityWord(drop.chance)}`,
					size = 14,
				})
			end
		end
	end
	if #loot > 0 then
		table.insert(sections, { title = T("worldmap.card.loot"), lines = loot })
	end
	-- Guide to where we came from (an area or a cave), else to its home.
	local actions: { Action } = {}
	local from: string? = options.from
	local mapId, x, z
	if from then
		local kindOf, a, b = string.match(from, "^(%a+):([%w_]+):?([%w_]*)$")
		if kindOf == "area" and a and b then
			local data = Areas.byMap[a]
			for _, area in (if data then data.areas else {}) :: { Areas.Area } do
				if area.id == b then
					mapId = a
					x, z = AreaAdvice.centre(area)
				end
			end
		elseif kindOf == "cave" and a then
			local entrance = Areas.entranceOf(a)
			local cave = Areas.caves.get(a)
			if entrance and cave then
				mapId, x, z = cave.region, entrance.x, entrance.z
			end
		end
	end
	if not mapId then
		local area, home = AreaAdvice.forKind(kind, ctx.level)
		if area and home then
			mapId = home
			x, z = AreaAdvice.centre(area)
		end
	end
	if mapId and x and z then
		actions = moveActions(ctx, {
			map = mapId,
			x = x,
			z = z,
			kind = "monster",
			id = kind,
			labelKey = def.nameKeys.normal,
		})
	end
	return {
		icon = if variant == "elite2" then "♛" elseif variant == "elite" then "★" else "⚔",
		iconColor = if variant == "normal" then color else Theme.Colors.GoldBright,
		title = T((def.nameKeys :: any)[variant] or def.nameKeys.normal),
		subtitle = T("worldmap.card.levels", { min = lv[1], max = lv[2] }),
		subtitleColor = color,
		accent = color,
		back = ctx.back,
		preview = { kind = "monster", id = kind, variant = variant, glyph = "⚔" },
		sections = sections,
		actions = actions,
	}
end

function CreatureCards.cave(ctx: Context, caveId: string): Spec?
	local cave = Areas.caves.get(caveId)
	local map = Maps.get(caveId)
	if not cave or not map then
		return nil
	end
	local from = `cave:{caveId}`
	local normal: { DetailCard.Row } = {}
	for _, kind in cave.normal do
		table.insert(normal, kindRow(ctx, kind, cave.levels, "normal", from))
	end
	local elites: { DetailCard.Row } = {}
	for _, kind in cave.elites do
		table.insert(elites, kindRow(ctx, kind, cave.levels, "elite", from))
	end
	local elite2: { DetailCard.Row } = {}
	for _, kind in cave.elite2 do
		table.insert(elite2, kindRow(ctx, kind, cave.levels, "elite2", from))
	end
	local info: { DetailCard.Line } = {}
	local now = workspace:GetServerTimeNow()
	for _, timer in State.Get({ "character", "e2timers" }) or {} do
		if timer.map == cave.id and timer.job == game.JobId then
			local state = if now < timer.from
				then T("e2timer.window", {
					from = math.ceil((timer.from - now) / 60) .. " min",
					to = math.ceil((timer.to - now) / 60) .. " min",
				})
				else T("e2timer.any")
			table.insert(info, { text = `⏱ {state}`, color = Color3.fromHex("#C77BFF") })
		end
	end
	table.insert(
		info,
		{ text = T("worldmap.rooms", { n = #AreaSpawns.caveRooms(cave) }), color = Theme.Colors.TextMuted }
	)
	local entrance = Areas.entranceOf(caveId)
	local sections: { Section } = {
		{ title = T("worldmap.card.monsters"), rows = normal },
		{ title = T("worldmap.elites"), rows = elites },
		{ title = T("worldmap.elite2"), rows = elite2, lines = info },
	}
	local actions: { Action } = {}
	if entrance then
		table.insert(sections, 1, { lines = { whereLine(ctx, cave.region, entrance.x, entrance.z) } })
		actions = moveActions(ctx, {
			map = cave.region,
			x = entrance.x,
			z = entrance.z,
			kind = "cave",
			id = cave.id,
			labelKey = cave.nameKey,
		})
	end
	if ctx.here ~= cave.id then
		table.insert(actions, {
			text = T("worldmap.action.showMap"),
			onClick = function()
				ctx.showMap(cave.id)
			end,
		})
	end
	local color = bandColor(cave.levels, ctx.level)
	return {
		icon = "⛰",
		iconColor = Theme.Colors.ZoneRed,
		title = T(cave.nameKey),
		subtitle = `{T("worldmap.card.levels", { min = cave.levels[1], max = cave.levels[2] })} · {T("zone.red")}`,
		subtitleColor = color,
		accent = Theme.Colors.ZoneRed,
		back = ctx.back,
		preview = if cave.elite2[1]
			then { kind = "monster", id = cave.elite2[1], variant = "elite2", glyph = "♛" }
			else nil,
		sections = sections,
		actions = actions,
	}
end

function CreatureCards.dungeon(ctx: Context, region: string): Spec?
	local boss = Bosses.forRegion(region)
	local gate = Portals.get(`dungeon_{region}`)
	if not boss or not gate then
		return nil
	end
	local required = BossScaling.requiredLevel(boss.level)
	local now = Clock.now()
	local runs = State.Get({ "character", "bossRuns" })
	local done = BossScaling.runsToday(if type(runs) == "table" then runs else nil, boss.id, now)
	local limit = Config.Boss.dailyRuns
	local pity = State.Get({ "character", "bossPity" })
	local chances = Loot.bossChances(boss.id, if type(pity) == "table" then pity[boss.id] else nil)
	local lines: { DetailCard.Line } = {
		{
			text = T("worldmap.card.required", { level = required }),
			color = if ctx.level >= required then Theme.Colors.ZoneGreen else Theme.Colors.ZoneRed,
			bold = true,
		},
		{
			text = T("worldmap.card.runsToday", {
				n = done,
				limit = limit,
				time = Time.format(BossScaling.untilReset(now)),
			}),
			color = if done >= limit then Theme.Colors.Warning else Theme.Colors.ZoneGreen,
		},
		{
			text = T("worldmap.card.bossChances", {
				leg = math.floor(chances.legendary * 100 + 0.5),
				myth = math.floor(chances.mythic * 100 + 0.5),
			}),
			color = Rarities.get(Rarities.MYTHIC).color:Lerp(Rarities.get(Rarities.LEGENDARY).color, 0.5),
			bold = true,
		},
		{ text = T("worldmap.card.group"), color = Theme.Colors.TextMuted },
		whereLine(ctx, gate.map, gate.x, gate.z),
	}
	local items: { DetailCard.ItemRow } = {}
	local bossTable = LootTables.bosses[boss.id]
	for i, unique in (if bossTable then bossTable.named else {}) :: { string } do
		local def = Items.get(unique)
		if def then
			local item = ItemRoll.makeStack(unique, 1, `mapcard:unique:{i}`)
			table.insert(items, {
				item = item,
				text = ItemText.name(unique),
				color = ItemText.rarityColor(item.rarity),
			})
		end
	end
	local sections: { Section } = { { lines = lines } }
	if #items > 0 then
		table.insert(sections, { title = T("worldmap.card.uniques"), items = items })
	end
	local actions = moveActions(ctx, {
		map = gate.map,
		x = gate.x,
		z = gate.z,
		kind = "dungeon",
		id = region,
		labelKey = boss.nameKey,
	})
	if ctx.here ~= gate.map then
		table.insert(actions, {
			text = T("worldmap.action.showMap"),
			onClick = function()
				ctx.showMap(gate.map)
			end,
		})
	end
	return {
		icon = "☠",
		iconColor = Theme.Colors.Danger,
		title = T(boss.nameKey),
		subtitle = `{T(`map.dungeon_{region}.name`)} · {T("worldmap.card.bossLevel", { level = boss.level })}`,
		subtitleColor = Theme.Colors.DangerHover,
		accent = Theme.Colors.Danger,
		preview = { kind = "boss", id = boss.id, glyph = "☠", color = Theme.Colors.Danger },
		sections = sections,
		actions = actions,
	}
end

return CreatureCards
