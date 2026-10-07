--!strict
-- Contents of the world map cards (S25, DESIGN §23) as DetailCard specs: NPC (3D figure, role, greeting,
-- services, the shop's first items for the player's level, quests at this NPC, distance or route), portal
-- (target map, its levels and zone, the recommended area there), monster area (kinds as rows -> monster
-- sub-card), gathering node / fishing spot, party member and own mark; monsters, caves and dungeons live in
-- WorldMap/CreatureCards, shared helpers in WorldMap/CardKit. Actions: Guide, Walk (same map), Centre,
-- Show map, Profile, Remove.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local BossScaling = require(ReplicatedStorage.Shared.Logic.BossScaling)
local CardKit = require(script.Parent.CardKit)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local CreatureCards = require(script.Parent.CreatureCards)
local DetailCard = require(script.Parent.DetailCard)
local Fish = require(ReplicatedStorage.Shared.Data.Fish)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GatherNodes = require(ReplicatedStorage.Shared.Data.GatherNodes)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local MapMarks = require(ReplicatedStorage.Shared.Data.MapMarks)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local NavTarget = require(script.Parent.Parent.Parent.NavTarget)
local NpcMarks = require(ReplicatedStorage.Shared.Logic.NpcMarks)
local NpcQuests = require(script.Parent.Parent.Parent.NpcQuests)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Portals = require(ReplicatedStorage.Shared.Data.Portals)
local QuestText = require(script.Parent.Parent.Parent.QuestText)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local ShopPrice = require(ReplicatedStorage.Shared.Logic.ShopPrice)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local Shops = require(ReplicatedStorage.Shared.Data.Shops)
local Spawns = require(ReplicatedStorage.Shared.Data.Spawns)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

type Spec = DetailCard.Spec
type Section = DetailCard.Section
type Action = DetailCard.Action
type Target = NavTarget.Target

export type Context = CardKit.Context

local Cards = {}

local T = CardKit.T
local SHOP_PREVIEW = 6
local isOpen, mapName, levelsOf, bandColor = CardKit.isOpen, CardKit.mapName, CardKit.levelsOf, CardKit.bandColor
local whereLine, moveActions, centreAction = CardKit.whereLine, CardKit.moveActions, CardKit.centreAction
local kindRow, rarityWord = CardKit.kindRow, CardKit.rarityWord
local ZONE_COLORS = CardKit.ZONE_COLORS

local SERVICE_ICONS: { [string]: string } = {
	shop = "⚖",
	heal = "✚",
	deposit = "⛃",
	blacksmith = "⚒",
	backpacks = "▣",
	alchemy = "⚗",
	guild = "⚑",
	auction = "⚱",
	mail = "✉",
	quests = "✎",
	story = "❗",
}

local function previewItem(entry: Shops.Entry): Types.ItemInstance
	local item = ItemRoll.makeStack(entry.item, 1, `mapcard:{entry.key or entry.item}`)
	if entry.ilvl then
		item.ilvl = entry.ilvl
		item.rarity = Rarities.COMMON
		item.el = entry.el
	end
	return item
end

-- First entries of a shop the character can use now (the newest tiers first in class shops).
local function shopSection(shopId: string, level: number, class: string): Section?
	local shop = Shops.get(shopId)
	if not shop then
		return nil
	end
	local usable: { Shops.Entry } = {}
	for _, entry in shop.entries do
		local item = previewItem(entry)
		local need = entry.level or ItemRoll.requiredLevel(item)
		local classOk = entry.classes == nil or table.find(entry.classes, class) ~= nil
		if need <= level and classOk and Items.get(entry.item) then
			table.insert(usable, entry)
		end
	end
	if shop.classTabs then
		table.sort(usable, function(a, b)
			return (a.level or 0) > (b.level or 0)
		end)
	end
	if #usable == 0 then
		for i = 1, math.min(SHOP_PREVIEW, #shop.entries) do
			table.insert(usable, shop.entries[i])
		end
	end
	local discount = State.Get({ "derived", "values", "potionDiscount" }) or 0
	local items: { DetailCard.ItemRow } = {}
	for i = 1, math.min(SHOP_PREVIEW, #usable) do
		local entry = usable[i]
		local item = previewItem(entry)
		table.insert(items, {
			item = item,
			text = ItemText.name(entry.item, nil, entry.el),
			color = ItemText.rarityColor(item.rarity),
			sub = T("worldmap.card.price", { price = Format.number(ShopPrice.unit(entry, level, discount)) }),
		})
	end
	local lines: { DetailCard.Line } = {}
	local more = #usable - #items
	if more > 0 then
		table.insert(lines, { text = T("worldmap.card.shopMore", { n = more }), color = Theme.Colors.TextMuted })
	end
	return { title = T("worldmap.card.shop"), items = items, lines = lines }
end

-- Quests at an NPC --------------------------------------------------------------------------------------------

-- S29: the objective rows of a quest the character has taken (the same rows as the tracker and the journal):
-- finished objectives green, "Return to: <NPC>" when complete and handed in elsewhere.
local function objectiveLines(lines: { DetailCard.Line }, quests: any, row: NpcQuests.Row)
	local objectives: { Quests.Objective }, progress: any, turnIn: string
	if row.kind == "main" then
		local quest = Quests.Main.get(row.id)
		local main = quests.main
		if not quest or type(main) ~= "table" or main.id ~= quest.id then
			return
		end
		objectives, progress, turnIn = quest.objectives, main.progress, quest.turnIn
	else
		local quest = Quests.Side.get(row.id)
		local entry = SideQuests.activeOf(quests)[row.id]
		if not quest or type(entry) ~= "table" then
			return
		end
		objectives, progress, turnIn = quest.objectives, entry.progress, quest.turnIn
	end
	local list = QuestText.rows(Fusion.peek, objectives, progress, turnIn)
	for _, line in QuestText.richRows(Fusion.peek, list, row.mode == "active") do
		table.insert(lines, { text = `   {line}`, size = 13, color = Theme.Colors.Text })
	end
end

local function questSection(npcId: string, level: number): Section?
	local quests = State.Get({ "character", "quests" })
	if type(quests) ~= "table" then
		return nil
	end
	local lines: { DetailCard.Line } = {}
	-- S27: story and side quests of this NPC (UI/NpcQuests, the same list as the NPC dialog).
	local KEYS = {
		turnIn = "worldmap.card.questTurnIn",
		offer = "worldmap.card.questNew",
		active = "worldmap.card.questActive",
	}
	for _, row in NpcQuests.rows(quests, level, npcId) do
		local title = T(`quest.{row.id}.title`)
		if row.mode == "later" then
			table.insert(lines, {
				text = `{title} ({T("quest.fromLevel", { level = NpcQuests.minLevel(row) })})`,
				color = Theme.Colors.TextMuted,
			})
		else
			local strong = row.mode ~= "active"
			table.insert(lines, {
				text = T(KEYS[row.mode], { title = title }),
				color = if strong then Theme.Colors.GoldBright else Theme.Colors.TextMuted,
				bold = strong,
			})
			if row.mode ~= "offer" then
				objectiveLines(lines, quests, row)
			end
		end
	end
	if npcId == NpcMarks.BOARD and type(quests.daily) == "table" then
		local left, ready, total = 0, 0, 0
		for _, entry in quests.daily.list or {} do
			total += 1
			if not entry.claimed then
				if entry.progress >= entry.objective.n then
					ready += 1
				else
					left += 1
				end
			end
		end
		table.insert(lines, {
			text = T("worldmap.card.daily", { left = left, total = total }),
			color = Theme.Colors.Parchment,
		})
		if ready > 0 then
			table.insert(lines, {
				text = T("worldmap.card.dailyReady", { n = ready }),
				color = Theme.Colors.GoldBright,
				bold = true,
			})
		end
	end
	if #lines == 0 then
		return nil
	end
	return { title = T("worldmap.card.quests"), lines = lines }
end

-- Cards ----------------------------------------------------------------------------------------------------

function Cards.npc(ctx: Context, npcId: string): Spec?
	local def = Npcs.get(npcId)
	if not def then
		return nil
	end
	local map = Maps.get(def.map)
	local intro: { DetailCard.Line } = {
		{ text = `„{T(def.greetingKey)}”`, color = Theme.Colors.TextMuted, italic = true, size = 14 },
		whereLine(ctx, def.map, def.position.x, def.position.z),
	}
	local sections: { Section } = { { lines = intro } }
	local chips: { DetailCard.Chip } = {}
	for _, service in def.services do
		table.insert(chips, { icon = SERVICE_ICONS[service] or "•", text = T(`npc.service.{service}`) })
	end
	if #chips > 0 then
		table.insert(sections, { title = T("worldmap.card.services"), chips = chips })
	end
	local quests = questSection(def.id, ctx.level)
	if quests then
		table.insert(sections, quests)
	end
	if def.shop and table.find(def.services, "shop") then
		local shop = shopSection(def.shop, ctx.level, ctx.class)
		if shop then
			table.insert(sections, shop)
		end
	end
	local target: Target = {
		map = def.map,
		x = def.position.x,
		z = def.position.z,
		npc = def.id,
		kind = "npc",
		id = def.id,
		labelKey = def.nameKey,
	}
	return {
		icon = def.icon,
		title = T(def.nameKey),
		subtitle = `{T(`npc.{def.id}.role`)} · {mapName(def.map)}`,
		subtitleColor = Theme.Colors.Gold,
		accent = if map then ZONE_COLORS[map.zone] else nil,
		preview = if def.body == "board"
			then { kind = "glyph", id = def.id, glyph = def.icon, color = Theme.Colors.Parchment }
			else { kind = "npc", id = def.id, glyph = def.icon },
		sections = sections,
		actions = moveActions(ctx, target, { centreAction(ctx, def.map, def.position.x, def.position.z) }),
	}
end

function Cards.portal(ctx: Context, portalId: string): Spec?
	local portal = Portals.get(portalId)
	local target = portal and Maps.get(portal.target)
	if not portal or not target then
		return nil
	end
	local open = isOpen(target.id)
	local lines: { DetailCard.Line } = {}
	if open then
		if target.id ~= "city" then
			table.insert(lines, {
				text = T("worldmap.card.levels", { min = target.minLevel, max = target.maxLevel }),
				color = bandColor({ target.minLevel, target.maxLevel }, ctx.level),
				bold = true,
			})
		end
		table.insert(lines, { text = T(`zone.{target.zone}`), color = ZONE_COLORS[target.zone] })
		local best = if Areas.byMap[target.id] then AreaAdvice.best(ctx.level, target.id) else nil
		if best then
			table.insert(lines, {
				text = T("worldmap.card.recommended", {
					name = T(best.nameKey),
					min = best.lv[1],
					max = best.lv[2],
				}),
				color = bandColor(best.lv, ctx.level),
			})
		end
		table.insert(lines, whereLine(ctx, portal.map, portal.x, portal.z))
	else
		table.insert(lines, { text = T("worldmap.soon"), color = Theme.Colors.TextMuted, bold = true })
	end
	local walkTarget: Target = {
		map = portal.map,
		x = portal.x,
		z = portal.z,
		kind = "portal",
		id = portal.id,
		labelKey = target.nameKey,
	}
	local actions: { Action } = if open
		then moveActions(ctx, walkTarget, {
			{
				text = T("worldmap.action.showMap"),
				onClick = function()
					ctx.showMap(target.id)
				end,
			},
		})
		else {}
	return {
		icon = "◎",
		iconColor = Color3.fromHex("#B9A8FF"),
		title = T(target.nameKey),
		subtitle = if open then `{T("worldmap.card.portalTo")} · {levelsOf(target)}` else T("worldmap.soon"),
		accent = if open then ZONE_COLORS[target.zone] else Theme.Colors.Border,
		grey = not open,
		sections = { { lines = lines } },
		actions = actions,
	}
end

function Cards.area(ctx: Context, mapId: string, areaId: string): Spec?
	local data = Areas.byMap[mapId]
	local area: Areas.Area? = nil
	for _, candidate in (if data then data.areas else {}) :: { Areas.Area } do
		if candidate.id == areaId then
			area = candidate
		end
	end
	if not area then
		return nil
	end
	local found = area :: Areas.Area
	local rows: { DetailCard.Row } = {}
	for _, kind in found.kinds do
		table.insert(rows, kindRow(ctx, kind, found.lv, "normal", `area:{mapId}:{found.id}`))
	end
	local groups = 0
	for _, spawner in (Spawns.byMap[mapId] or {}) :: { Spawns.Spawner } do
		if spawner.areaId == found.id then
			groups += 1
		end
	end
	local lines: { DetailCard.Line } = {
		{ text = T("worldmap.groups", { n = groups }), color = Theme.Colors.TextMuted },
	}
	if AreaAdvice.isRecommended(found, ctx.level) then
		table.insert(lines, 1, { text = T("worldmap.card.forYou"), color = Theme.Colors.GoldBright, bold = true })
	end
	local x, z = AreaAdvice.centre(found)
	table.insert(lines, whereLine(ctx, mapId, x, z))
	local color = bandColor(found.lv, ctx.level)
	local target: Target = { map = mapId, x = x, z = z, kind = "area", id = found.id, labelKey = found.nameKey }
	return {
		icon = "⚔",
		iconColor = color,
		title = T(found.nameKey),
		subtitle = T("worldmap.card.levels", { min = found.lv[1], max = found.lv[2] }),
		subtitleColor = color,
		accent = color,
		sections = { { title = T("worldmap.card.monsters"), rows = rows }, { lines = lines } },
		actions = moveActions(ctx, target, { centreAction(ctx, mapId, x, z) }),
	}
end

-- "often / rarely / very rarely" instead of percentages (DESIGN shows no drop chances).
function Cards.node(ctx: Context, mapId: string, kindId: string, x: number, z: number): Spec?
	local kind = GatherNodes.get(kindId)
	if not kind then
		return nil
	end
	local lines: { DetailCard.Line } = {
		{ text = T(`gather.category.{kind.category}`), color = Theme.Colors.Gold, bold = true },
		{ text = T("worldmap.card.nodeLevel", { level = kind.level }), color = Theme.Colors.TextMuted },
	}
	if kind.tool then
		local owned = false
		for _, item in State.Get({ "character", "inventory" }) or {} do
			if type(item) == "table" and item.id == kind.tool then
				owned = true
			end
		end
		table.insert(lines, {
			text = T("worldmap.card.tool", { tool = ItemText.name(kind.tool) }),
			color = if owned then Theme.Colors.ZoneGreen else Theme.Colors.Warning,
		})
	end
	table.insert(lines, whereLine(ctx, mapId, x, z))
	local loot: { DetailCard.Line } = {}
	if kind.spot then
		local spot = Fish.get(kind.spot)
		local total = 0
		for _, fish in (if spot then spot.fish else {}) :: { Fish.FishEntry } do
			total += fish.weight
		end
		for _, fish in (if spot then spot.fish else {}) :: { Fish.FishEntry } do
			table.insert(loot, {
				text = `• {ItemText.name(fish.id)} — {rarityWord(fish.weight / math.max(1, total))}`,
				color = ItemText.rarityColor(fish.rarity),
				size = 14,
			})
		end
	else
		for _, entry in kind.loot do
			if Items.get(entry.id) then
				table.insert(loot, { text = `• {ItemText.name(entry.id)} — {rarityWord(entry.chance)}`, size = 14 })
			end
		end
	end
	local target: Target = { map = mapId, x = x, z = z, kind = "node", id = kindId, labelKey = kind.nameKey }
	return {
		icon = if kind.category == "fishing" then "≈" elseif kind.category == "herb" then "❀" else "⛏",
		iconColor = Color3.fromHex(kind.look.color),
		title = T(kind.nameKey),
		subtitle = mapName(mapId),
		accent = Color3.fromHex(kind.look.color),
		sections = { { lines = lines }, { title = T("worldmap.card.gives"), lines = loot } },
		actions = moveActions(ctx, target, { centreAction(ctx, mapId, x, z) }),
	}
end

function Cards.party(ctx: Context, userId: number): Spec?
	local party = State.Get({ "party" })
	if type(party) ~= "table" then
		return nil
	end
	for _, member in party.members do
		if member.id == userId then
			local map = Maps.get(member.map or "")
			local class = Classes.get(member.class)
			local lines: { DetailCard.Line } = {
				{
					text = T("worldmap.card.member", {
						class = if class then T(class.nameKey) else member.class,
						level = member.level,
					}),
					color = if class then Color3.fromHex(class.color) else Theme.Colors.Text,
					bold = true,
				},
				{
					text = T("worldmap.card.memberHp", {
						hp = Format.number(member.hp),
						maxHp = Format.number(member.maxHp),
						mana = Format.number(member.mana or 0),
						maxMana = Format.number(member.maxMana or 0),
					}),
					color = Theme.Colors.Parchment,
				},
			}
			if map then
				table.insert(lines, whereLine(ctx, map.id, member.x - map.offset.x, member.z - map.offset.z))
			end
			local actions: { Action } = {}
			if map then
				table.insert(actions, {
					text = T("worldmap.action.guide"),
					primary = true,
					onClick = function()
						ctx.guide({
							map = map.id,
							x = member.x - map.offset.x,
							z = member.z - map.offset.z,
							kind = "party",
							id = tostring(userId),
							label = member.name,
							follow = userId,
						})
					end,
				})
			end
			table.insert(actions, {
				text = T("worldmap.action.profile"),
				onClick = function()
					ctx.openProfile(userId)
				end,
			})
			return {
				icon = if class then class.icon else "●",
				iconColor = Theme.Colors.Accent,
				title = member.name,
				subtitle = if map then mapName(map.id) else "",
				accent = Theme.Colors.Accent,
				sections = { { lines = lines } },
				actions = actions,
			}
		end
	end
	return nil
end

-- Automatic name of an own mark: the nearest NPC within 60 studs, else the monster area, else the map.
function Cards.markName(mark: Types.MapMark): string
	local best, bestDistance = nil :: Npcs.NpcDef?, 60
	for _, npc in Npcs.list do
		if npc.map == mark.map and not npc.decoration then
			local d = math.sqrt((npc.position.x - mark.x) ^ 2 + (npc.position.z - mark.z) ^ 2)
			if d < bestDistance then
				best, bestDistance = npc, d
			end
		end
	end
	if best then
		return T("worldmap.mark.near", { name = T(best.nameKey) })
	end
	local area = Areas.areaAt(mark.map, mark.x, mark.z)
	if area then
		return T(area.nameKey)
	end
	return mapName(mark.map)
end

function Cards.mark(ctx: Context, index: number): Spec?
	local marks = State.Get({ "character", "mapMarks" })
	local mark = if type(marks) == "table" then marks[index] else nil
	if type(mark) ~= "table" then
		return nil
	end
	local icon = MapMarks.get(mark.icon)
	local name = Cards.markName(mark)
	local target: Target = { map = mark.map, x = mark.x, z = mark.z, kind = "mark", id = tostring(index), label = name }
	return {
		icon = if icon then icon.glyph else "⚑",
		iconColor = if icon then Color3.fromHex(icon.color) else Theme.Colors.GoldBright,
		title = name,
		subtitle = `{if icon then T(icon.nameKey) else ""} · {mapName(mark.map)}`,
		accent = if icon then Color3.fromHex(icon.color) else nil,
		sections = { { lines = { whereLine(ctx, mark.map, mark.x, mark.z) } } },
		actions = moveActions(ctx, target, {
			{
				text = T("worldmap.action.remove"),
				danger = true,
				onClick = function()
					ctx.removeMark(index)
				end,
			},
		}),
	}
end

-- Card spec for a kind, or nil when the thing does not exist (any more).
function Cards.build(ctx: Context, kind: string, id: string, extra: any?): Spec?
	if kind == "npc" then
		return Cards.npc(ctx, id)
	elseif kind == "portal" then
		return Cards.portal(ctx, id)
	elseif kind == "area" then
		local options = type(extra) == "table" and extra or {}
		return Cards.area(ctx, options.map or "", id)
	elseif kind == "monster" then
		return CreatureCards.monster(ctx, id, extra)
	elseif kind == "cave" then
		return CreatureCards.cave(ctx, id)
	elseif kind == "dungeon" then
		return CreatureCards.dungeon(ctx, id)
	elseif kind == "boss" then
		local boss = Bosses.get(id)
		return if boss then CreatureCards.dungeon(ctx, boss.region) else nil
	elseif kind == "node" then
		local options = type(extra) == "table" and extra or {}
		return Cards.node(ctx, options.map or "", id, options.x or 0, options.z or 0)
	elseif kind == "party" then
		return Cards.party(ctx, tonumber(id) or 0)
	elseif kind == "mark" then
		return Cards.mark(ctx, tonumber(id) or 0)
	end
	return nil
end

-- One line under the cursor (PC hover): name and the most useful fact.
function Cards.hint(kind: string, id: string, level: number, extra: any?): (string, string?)
	if kind == "npc" then
		local def = Npcs.get(id)
		return if def then T(def.nameKey) else id, if def then T(`npc.{def.id}.role`) else nil
	elseif kind == "portal" then
		local portal = Portals.get(id)
		local target = portal and Maps.get(portal.target)
		if target then
			return T(target.nameKey), if isOpen(target.id) then levelsOf(target) else T("worldmap.soon")
		end
	elseif kind == "cave" then
		local cave = Areas.caves.get(id)
		if cave then
			return T(cave.nameKey), `{cave.levels[1]}–{cave.levels[2]} · {T("zone.red")}`
		end
	elseif kind == "dungeon" then
		local boss = Bosses.forRegion(id)
		if boss then
			return T(boss.nameKey), T("worldmap.card.required", { level = BossScaling.requiredLevel(boss.level) })
		end
	elseif kind == "node" then
		local node = GatherNodes.get(id)
		if node then
			return T(node.nameKey), T(`gather.category.{node.category}`)
		end
	elseif kind == "area" then
		local options = type(extra) == "table" and extra or {}
		local data = Areas.byMap[options.map or ""]
		for _, area in (if data then data.areas else {}) :: { Areas.Area } do
			if area.id == id then
				local names = {}
				for _, k in area.kinds do
					local def = Monsters.get(k)
					table.insert(names, if def then T(def.nameKeys.normal) else k)
				end
				return `{T(area.nameKey)} · {area.lv[1]}–{area.lv[2]}`, table.concat(names, ", ")
			end
		end
	end
	local _ = level
	return id, nil
end

return Cards
