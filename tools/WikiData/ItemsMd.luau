--!strict
-- docs/PRZEDMIOTY.md (S34): every item from the same data as items.json, in Polish: the rarity legend with the
-- caps of every drop source, equipment by slot and base (every tier: name, level, Common +0 stats, value, shop
-- price), the bosses' named Mythics with their bonuses, materials (value, where from, what for), consumables and
-- backpacks. Generated: never edit by hand.

local Clean = require("./Clean")

local ItemsMd = {}

local SOURCE_NAMES: { [string]: string } = {
	normal = "zwykłe potwory",
	elite = "Elity",
	elite2 = "Elity II",
	boss = "bossowie (wspólny łup)",
}

local function fmt(n: number): string
	if n == math.floor(n) then
		return string.format("%d", n)
	end
	local text = string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
	return (text:gsub("%.", ","))
end

local function pct(x: number): string
	return fmt(math.floor(x * 1000 + 0.5) / 10) .. "%"
end

local function statName(statsById: { [string]: any }, key: string): string
	local id, isPct = string.match(key, "^(.+)Pct$"), false
	if id then
		isPct = true
	else
		id = key
	end
	local stat = statsById[id :: string]
	local name = if stat then stat.name.pl else key
	return if isPct then `{name} %` else name
end

local function statLine(statsById: { [string]: any }, s: any): string
	local parts = {}
	if s.weapon then
		table.insert(parts, `obr. {s.weapon.dmg[1]}`)
		if s.weapon.mdmg[1] > 0 then
			table.insert(parts, `obr. mag. {s.weapon.mdmg[1]}`)
		end
		table.insert(parts, `szybkość {fmt(s.weapon.speed)}`)
	end
	for _, key in Clean.keys(s.base) do
		table.insert(parts, `{statName(statsById, key)} {fmt(s.base[key][1])}`)
	end
	return if #parts > 0 then table.concat(parts, ", ") else "—"
end

function ItemsMd.generate(ctx: any): string
	local d = ctx.data
	local items: { any } = d.items and d.items.items or {}
	local statsById: { [string]: any } = {}
	for _, s in (d.stats and d.stats.stats or {}) do
		statsById[s.id] = s
	end
	local bonusById: { [string]: any } = {}
	for _, b in (d.bonuses and d.bonuses.bonuses or {}) do
		bonusById[b.id] = b
	end
	local monsterName: { [string]: string } = {}
	for _, m in (d.monsters and d.monsters.monsters or {}) do
		monsterName[m.id] = m.name.pl
	end
	local bossName: { [string]: string } = {}
	for _, b in (d.bosses and d.bosses.bosses or {}) do
		bossName[b.id] = b.name.pl
	end
	local itemName: { [string]: string } = {}
	for _, item in items do
		itemName[item.id] = item.name.pl
	end

	local out = {
		"# Vaelthorn: przedmioty",
		"",
		"> Plik generowany: `lune run tools/wikidump.luau` (dane gry, te same co wiki). Nie edytuj ręcznie.",
		"> Odcisk danych " .. (d.meta and d.meta.dataHash or "?") .. " (`wiki/src/data/meta.json`).",
		"",
		"## Rzadkości",
		"",
		"| Rzadkość | Kolor | Bonusy | Linie legendarne | Mnożnik statystyk | Mnożnik wartości |",
		"|---|---|---|---|---|---|",
	}
	for _, r in (d.rarities and d.rarities.rarities or {}) do
		local bonuses = if r.bonusMin == r.bonusMax then `{r.bonusMin}` else `{r.bonusMin}–{r.bonusMax}`
		table.insert(
			out,
			`| {r.name.pl} | \`{r.color}\` | {bonuses} | {r.legendaryLines} | ×{fmt(r.baseMul)} | ×{fmt(r.sellMul)} |`
		)
	end
	table.insert(out, "")
	table.insert(out, "Źródła dropu: szansa przedmiotu na zabicie, liczba i najwyższa możliwa rzadkość (sufit).")
	table.insert(out, "")
	table.insert(out, "| Źródło | Szansa | Liczba | Sufit | Udział rzadkości |")
	table.insert(out, "|---|---|---|---|---|")
	local rarityName: { [string]: string } = {}
	for _, r in (d.rarities and d.rarities.rarities or {}) do
		rarityName[r.key] = r.name.pl
	end
	for _, key in Clean.keys(d.rarities and d.rarities.sources or {}) do
		local s = d.rarities.sources[key]
		local shares = {}
		for _, rk in Clean.keys(s.weights) do
			table.insert(shares, `{rarityName[rk] or rk} {pct(s.weights[rk])}`)
		end
		local count = if s.min == s.max then `{s.min}` else `{s.min}–{s.max}`
		table.insert(
			out,
			`| {SOURCE_NAMES[key] or key} | {pct(s.chance)} | {count} | {rarityName[s.cap] or s.cap} | {table.concat(
				shares,
				", "
			)} |`
		)
	end
	table.insert(out, "")
	table.insert(
		out,
		"Legendarne i Mityczne przedmioty dają też osobiste rzuty bossów (S30), a nazwane Mityki tylko bossowie."
	)
	table.insert(out, "")

	-- Equipment by slot and base.
	table.insert(out, "## Ekwipunek")
	local slots = d.items and d.items.slots or {}
	local bases = d.items and d.items.bases or {}
	local shopPrice: { [string]: number } = {}
	for _, shop in (d.shops and d.shops.shops or {}) do
		for _, e in shop.entries do
			if not shopPrice[e.item] or e.gold < shopPrice[e.item] then
				shopPrice[e.item] = e.gold
			end
		end
	end
	local bySlot: { [string]: { string } } = {}
	for _, baseType in Clean.keys(bases) do
		local slot = bases[baseType].slot
		bySlot[slot] = bySlot[slot] or {}
		table.insert(bySlot[slot], baseType)
	end
	local classNames: { [string]: string } = {}
	for _, c in (d.classes and d.classes.classes or {}) do
		classNames[c.id] = c.name.pl
	end
	for _, slot in Clean.keys(bySlot) do
		table.insert(out, "")
		table.insert(out, `### {slots[slot] and slots[slot].name.pl or slot}`)
		for _, baseType in bySlot[slot] do
			local base = bases[baseType]
			local classes = {}
			for _, c in base.classes or {} do
				table.insert(classes, classNames[c] or c)
			end
			table.insert(out, "")
			table.insert(
				out,
				`#### {base.name.pl} (\`{baseType}\`) · {if #classes > 0
					then table.concat(classes, ", ")
					else "każda klasa"}`
			)
			table.insert(out, "")
			table.insert(out, "| Przedmiot | Poziom | Statystyki (Zwykły +0) | Wartość | Cena u handlarza |")
			table.insert(out, "|---|---|---|---|---|")
			local rows = {}
			for _, item in items do
				if item.type == baseType and item.tier and not item.fixedBonuses then
					table.insert(rows, item)
				end
			end
			table.sort(rows, function(a, b)
				return a.tier < b.tier
			end)
			for _, item in rows do
				local common = item.stats and item.stats.common
				local stats = if common then statLine(statsById, common) else "—"
				local value = item.value.common and item.value.common[1] or 0
				local price = if shopPrice[item.id] then `{shopPrice[item.id]}` else "—"
				table.insert(out, `| {item.name.pl} | {item.requiredLevel} | {stats} | {value} | {price} |`)
			end
		end
	end

	-- Named Mythics.
	table.insert(out, "")
	table.insert(out, "## Mityki bossów (nazwane)")
	table.insert(out, "")
	table.insert(out, "| Przedmiot | Boss | Poziom | Statystyki | Bonusy stałe |")
	table.insert(out, "|---|---|---|---|---|")
	for _, item in items do
		if item.fixedBonuses then
			local key = item.rarities[1]
			local stats = item.stats and item.stats[key] and statLine(statsById, item.stats[key]) or "—"
			local bonuses = {}
			for _, b in item.fixedBonuses do
				local def = bonusById[b.stat]
				local suffix = if def and def.percent then "%" else ""
				table.insert(bonuses, `{def and def.name.pl or b.stat} +{fmt(b.v)}{suffix}`)
			end
			table.insert(
				out,
				`| {item.name.pl} | {bossName[item.boss or ""] or "—"} | {item.requiredLevel} | {stats} | {table.concat(
					bonuses,
					", "
				)} |`
			)
		end
	end

	-- Materials.
	table.insert(out, "")
	table.insert(out, "## Materiały")
	table.insert(out, "")
	table.insert(out, "| Materiał | Wartość | Skąd | Do czego |")
	table.insert(out, "|---|---|---|---|")
	for _, item in items do
		if item.category == "material" then
			local from = {}
			local src = item.sources
			local monsters: { [string]: boolean } = {}
			for _, m in src.monsters do
				monsters[monsterName[m.monster] or m.monster] = true
			end
			for _, name in Clean.keys(monsters) do
				table.insert(from, name)
			end
			for _, b in src.bosses do
				table.insert(from, bossName[b.boss] or b.boss)
			end
			if #src.gathering > 0 then
				table.insert(from, "zbieractwo")
			end
			if src.fishingChest then
				table.insert(from, "skrzynia rybacka")
			end
			if src.dismantle then
				table.insert(from, "rozbijanie")
			end
			if #src.alchemy > 0 then
				table.insert(from, "alchemik")
			end
			if #src.shops > 0 then
				table.insert(from, "sklep")
			end
			local uses = {}
			if item.usedFor then
				if #item.usedFor.upgrade > 0 then
					table.insert(
						uses,
						`ulepszanie +{item.usedFor.upgrade[1]}…+{item.usedFor.upgrade[#item.usedFor.upgrade]}`
					)
				end
				if item.usedFor.crafting > 0 then
					table.insert(uses, `kowal ({item.usedFor.crafting} przepisów)`)
				end
				if #item.usedFor.alchemy > 0 then
					table.insert(uses, `alchemik ({#item.usedFor.alchemy} receptur)`)
				end
			end
			local value = 0
			for _, list in item.value do
				value = list[1]
			end
			table.insert(
				out,
				`| {item.name.pl} | {value} | {if #from > 0 then table.concat(from, ", ") else "—"} | {if #uses
						> 0
					then table.concat(uses, ", ")
					else "—"} |`
			)
		end
	end

	-- Consumables, scrolls, stones, tools and backpacks.
	table.insert(out, "")
	table.insert(out, "## Przedmioty użytkowe i plecaki")
	table.insert(out, "")
	table.insert(out, "| Przedmiot | Rodzaj | Poziom | Działanie | Cena u handlarza | Wartość |")
	table.insert(out, "|---|---|---|---|---|---|")
	for _, item in items do
		if item.category ~= "equipment" and item.category ~= "material" then
			local effect = "—"
			if item.capacity then
				effect = `{item.capacity} miejsc`
			elseif item.desc then
				effect = string.gsub(item.desc.pl, "\n", " ")
			end
			local value = 0
			for _, list in item.value do
				value = list[1]
			end
			local category = d.items.categories[item.category]
			table.insert(
				out,
				`| {item.name.pl} | {category and category.name.pl or item.category} | {item.level} | {effect} | {if shopPrice[item.id]
					then tostring(shopPrice[item.id])
					else "—"} | {value} |`
			)
		end
	end
	table.insert(out, "")
	return table.concat(out, "\n")
end

return ItemsMd
