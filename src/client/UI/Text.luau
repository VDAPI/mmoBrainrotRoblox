--!strict
-- Reactive localization for UI. Text.T(scope, "key", { name = someValue }) -> Computed<string> that
-- re-renders when the language or any argument state changes.

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Locale = require(ReplicatedStorage.Shared.Util.Locale)
local State = require(script.Parent.State)

local Text = {}

local moduleScope = Fusion.scoped(Fusion)
local savedLang = State.Value({ "account", "settings", "lang" })
-- Language picked before the profile arrived (or when the saved one is empty).
local fallbackLang = Locale.fromRobloxLocale(LocalizationService.RobloxLocaleId)
-- Language chosen in this session: applies instantly, before the server echoes the saved setting.
local preferredLang = moduleScope:Value(nil :: string?)

-- The effective UI language.
Text.Lang = moduleScope:Computed(function(use): string
	local preferred = use(preferredLang)
	if preferred then
		return preferred
	end
	local lang = use(savedLang)
	if type(lang) == "string" and Locale.isSupported(lang) then
		return lang
	end
	return fallbackLang
end)

moduleScope:Observer(Text.Lang):onBind(function()
	Locale.setLanguage(Fusion.peek(Text.Lang))
end)

function Text.setPreferred(lang: string)
	if Locale.isSupported(lang) then
		preferredLang:set(lang)
	end
end

export type ArgsIn = { [string]: any }

function Text.T(scope: Fusion.Scope<any>, key: Fusion.UsedAs<string>, args: ArgsIn?): Fusion.UsedAs<string>
	return scope:Computed(function(use): string
		local lang = use(Text.Lang)
		local resolved: { [string]: any }? = nil
		if args then
			local out = {}
			for name, value in args do
				out[name] = use(value :: any)
			end
			resolved = out
		end
		return Locale.T(use(key :: any), resolved, lang)
	end)
end

-- Lookup inside a Computed: subscribes to the language through `use` without creating new state objects.
function Text.get(use: Fusion.Use, key: string, args: { [string]: any }?): string
	return Locale.T(key, args, use(Text.Lang))
end

-- Non-reactive lookup in the current UI language (for one-off strings like system messages).
function Text.now(key: string, args: { [string]: any }?): string
	return Locale.T(key, args, Fusion.peek(Text.Lang))
end

return Text
