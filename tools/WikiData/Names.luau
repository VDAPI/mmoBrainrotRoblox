--!strict
-- Game texts as { pl, en } (S34): through Util/Locale only, never whole locale tables. A key missing in a language
-- is recorded (Names.missing) so the session notes can list it; optional texts (descriptions) use Names.opt.

local ItemName = require("../../src/shared/Logic/ItemName")
local Locale = require("../../src/shared/Util/Locale")

local Names = {}

export type Name = { pl: string, en: string }

Names.LANGS = { "pl", "en" }

-- key -> true for keys asked with Names.of that are missing in a language.
Names.missing = {} :: { [string]: boolean }

function Names.reset()
	Names.missing = {}
end

function Names.has(key: string): boolean
	return Locale.has(key, "pl") and Locale.has(key, "en")
end

-- Text of `key` in both languages (with `args`); a missing key is recorded and falls back like the game.
function Names.of(key: string, args: { [string]: any }?): Name
	for _, lang in Names.LANGS do
		if not Locale.has(key, lang) then
			Names.missing[`{key} ({lang})`] = true
		end
	end
	return { pl = Locale.T(key, args, "pl"), en = Locale.T(key, args, "en") }
end

-- Text of `key` only when it exists in both languages.
function Names.opt(key: string?, args: { [string]: any }?): Name?
	if not key or not Names.has(key) then
		return nil
	end
	return Names.of(key, args)
end

-- Names built from two texts per language (a label with a localized argument).
function Names.combine(fn: (lang: string) -> string): Name
	return { pl = fn("pl"), en = fn("en") }
end

function Names.T(key: string, args: { [string]: any }?, lang: string): string
	if not Locale.has(key, lang) then
		Names.missing[`{key} ({lang})`] = true
	end
	return Locale.T(key, args, lang)
end

-- Item name as the game shows it (ItemName.get: tier prefix + base with Polish gender, uniques, elements).
function Names.item(id: string, element: string?): Name
	return { pl = ItemName.get("pl", id, nil, element), en = ItemName.get("en", id, nil, element) }
end

-- Sorted list of the missing keys.
function Names.missingList(): { string }
	local list = {}
	for key in Names.missing do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

return Names
