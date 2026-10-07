--!strict
-- Hunting ground profile texts (S33, DESIGN §3.6): "⚡ Fast EXP", the multipliers line, the icon as rich text.
-- Used by the portal's area picker, the world map (card, area pills, legend), the area banner and the minimap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaProfiles = require(ReplicatedStorage.Shared.Data.AreaProfiles)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Text)

local AreaProfileText = {}

-- Multiplier as text with the language's decimal separator: 1 -> "1", 0.6 -> "0,6" (pl), 1.25 -> "1.25" (en).
function AreaProfileText.mul(use: Fusion.Use, value: number): string
	local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
	return (text:gsub("%.", Text.get(use, "format.decimal")))
end

function AreaProfileText.color(profile: AreaProfiles.Profile): Color3
	return Color3.fromHex(profile.color)
end

-- "⚡ Fast EXP"
function AreaProfileText.tag(use: Fusion.Use, profile: AreaProfiles.Profile): string
	return `{profile.icon} {Text.get(use, profile.nameKey)}`
end

-- "EXP ×1 · items ×0,6 · gold ×0,7" (+ "rare ×2" when the top rarity is raised).
function AreaProfileText.mults(use: Fusion.Use, profile: AreaProfiles.Profile): string
	local line = Text.get(use, "area.profile.mults", {
		exp = AreaProfileText.mul(use, profile.expMul),
		drop = AreaProfileText.mul(use, profile.itemChanceMul),
		gold = AreaProfileText.mul(use, profile.goldMul),
	})
	if profile.topTierMul ~= 1 then
		line ..= " · " .. Text.get(use, "area.profile.rare", { mul = AreaProfileText.mul(use, profile.topTierMul) })
	end
	return line
end

-- The icon in its colour for a RichText label (" ⚡" after a name), "" for an area without a profile.
function AreaProfileText.iconRich(profileId: string?, before: string?): string
	local profile = AreaProfiles.get(profileId)
	if not profile then
		return ""
	end
	return `{before or ""}<font color="{profile.color}">{profile.icon}</font>`
end

-- Escapes text for a RichText label.
function AreaProfileText.escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

return AreaProfileText
