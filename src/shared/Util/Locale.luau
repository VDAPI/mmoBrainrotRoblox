--!strict
-- Localization lookup. Locale.T("toast.enterWorld", { name = "Aria" }) -> text with {name} replaced.
-- Fallback: requested language -> English -> the key itself (so missing keys are visible, not blank).

local Config = require("../Config")
local en = require("../Data/Localization/en")
local pl = require("../Data/Localization/pl")

export type Args = { [string]: any }

local Locale = {}

local TABLES: { [string]: { [string]: string } } = {
	en = en,
	pl = pl,
}

local current = Config.DefaultLanguage

function Locale.isSupported(lang: string): boolean
	return TABLES[lang] ~= nil
end

function Locale.setLanguage(lang: string)
	if TABLES[lang] then
		current = lang
	end
end

function Locale.getLanguage(): string
	return current
end

-- Maps a Roblox locale id ("pl-pl", "en-us") to a supported language: pl -> pl, everything else -> en.
function Locale.fromRobloxLocale(localeId: string): string
	local prefix = string.lower(string.sub(localeId, 1, 2))
	return if TABLES[prefix] then prefix else Config.DefaultLanguage
end

function Locale.has(key: string, lang: string?): boolean
	local tbl = TABLES[lang or current]
	return tbl ~= nil and tbl[key] ~= nil
end

local function substitute(text: string, args: Args?): string
	if not args then
		return text
	end
	return (
		string.gsub(text, "{([%w_]+)}", function(name: string): string
			local value = args[name]
			if value == nil then
				return `{"{"}{name}{"}"}` -- keep the placeholder untouched
			end
			return tostring(value)
		end)
	)
end

function Locale.T(key: string, args: Args?, lang: string?): string
	local language = lang or current
	local text = (TABLES[language] or en)[key] or en[key]
	if text == nil then
		return key
	end
	return substitute(text, args)
end

-- Exposed for data-consistency tests.
function Locale.tables(): { [string]: { [string]: string } }
	return TABLES
end

return Locale
