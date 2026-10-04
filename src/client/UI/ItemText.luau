--!strict
-- Item names and text helpers. Generated equipment names combine a tier prefix agreeing with the noun's
-- Polish gender ("Żelazny Miecz", "Żelazna Tarcza", "Żelazne Buty") with the base noun; upgrades add "+N".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Locale = require(ReplicatedStorage.Shared.Util.Locale)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Text = require(script.Parent.Text)

local ItemText = {}

function ItemText.nameIn(lang: string, itemId: string, up: number?): string
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

-- Name in the current UI language (non-reactive).
function ItemText.name(itemId: string, up: number?): string
	return ItemText.nameIn(Fusion.peek(Text.Lang), itemId, up)
end

-- Name inside a Computed (subscribes to the language).
function ItemText.get(use: Fusion.Use, itemId: string, up: number?): string
	return ItemText.nameIn(use(Text.Lang), itemId, up)
end

function ItemText.rarityColor(rarity: number): Color3
	local def = Rarities.get(rarity)
	return Color3.fromHex(if def then def.color else "#C9CED6")
end

-- Resolves "#item:<id>:<up>" message arguments (announcements) into a localized item name.
function ItemText.resolveArg(value: string): string?
	local id, up = string.match(value, "^#item:([%w_]+):?(%d*)$")
	if not id then
		return nil
	end
	return ItemText.name(id, tonumber(up))
end

return ItemText
