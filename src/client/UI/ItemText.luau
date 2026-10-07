--!strict
-- Item names and text helpers. Generated equipment names combine a tier prefix agreeing with the noun's
-- Polish gender ("Żelazny Miecz", "Żelazna Tarcza", "Żelazne Buty") with the base noun; upgrades add "+N".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemName = require(ReplicatedStorage.Shared.Logic.ItemName)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Text = require(script.Parent.Text)

local ItemText = {}

function ItemText.nameIn(lang: string, itemId: string, up: number?, element: string?): string
	return ItemName.get(lang, itemId, up, element)
end

-- Name in the current UI language (non-reactive).
function ItemText.name(itemId: string, up: number?, element: string?): string
	return ItemText.nameIn(Fusion.peek(Text.Lang), itemId, up, element)
end

-- Name inside a Computed (subscribes to the language).
function ItemText.get(use: Fusion.Use, itemId: string, up: number?, element: string?): string
	return ItemText.nameIn(use(Text.Lang), itemId, up, element)
end

-- Frame colour of a rarity (grey, yellow, blue, orange, red; S30).
function ItemText.rarityColor(rarity: number?): Color3
	return Rarities.get(rarity or Rarities.COMMON).color
end

-- Readable name colour of a rarity on light parchment (tooltips).
function ItemText.rarityTextColor(rarity: number?): Color3
	return Rarities.get(rarity or Rarities.COMMON).textColor
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
