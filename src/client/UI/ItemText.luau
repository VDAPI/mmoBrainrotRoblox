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

-- S135: the rarity frame on a surface: the parchment variant (Rarities.paperHex, >= 3:1 on a slot) or the identity
-- colour on iron.
function ItemText.rarityFrame(rarity: number?, surface: string?): Color3
	local r = Rarities.get(rarity or Rarities.COMMON)
	return if surface == "iron" then r.color else r.paperColor
end

-- S135: the rarity's name colour on a surface: textHex on parchment, nightHex on iron (both >= 4.5:1).
function ItemText.rarityName(rarity: number?, surface: string?): Color3
	local r = Rarities.get(rarity or Rarities.COMMON)
	return if surface == "iron" then r.nightColor else r.textColor
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
