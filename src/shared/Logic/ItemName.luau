--!strict
-- Item display names in a given language (pure; shared by the client UI and the auction search index).
-- Generated equipment combines a tier prefix agreeing with the noun's Polish gender with the base noun;
-- upgrades add "+N".

local Items = require("../Data/Items")
local Locale = require("../Util/Locale")
local NameRules = require("./NameRules")

local ItemName = {}

function ItemName.get(lang: string, itemId: string, up: number?): string
	local def = Items.get(itemId)
	if not def then
		return Locale.T("item.unknown", nil, lang)
	end
	local name
	if def.nameKey then
		name = Locale.T(def.nameKey, nil, lang)
	else
		local prefix = Locale.T(`{def.namePrefix}.{def.gender or "m"}`, nil, lang)
		name = `{prefix} {Locale.T(def.nameBase or "", nil, lang)}`
	end
	if up and up > 0 then
		name ..= ` +{up}`
	end
	return name
end

-- Lower-case text for case-insensitive search (Polish letters included).
function ItemName.fold(text: string): string
	local ok, length = pcall(utf8.len, text)
	if not ok or length == nil then
		return string.lower(text)
	end
	return NameRules.normalize(text)
end

-- Search text of an item: its names in every language, folded.
function ItemName.searchText(itemId: string): string
	local parts = {}
	for lang in Locale.tables() do
		table.insert(parts, ItemName.fold(ItemName.get(lang, itemId, nil)))
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

return ItemName
