--!strict
-- The group's Fortune on bosses (S60, ROZWOJ 6.4): in a party the server's `party.luck` (counts the player too),
-- solo the player's own Logic/Luck.boss from Paths.luck. Feeds Loot.bossChances on the dungeon window, the world
-- map card and the reward card, and the "Party luck" line (only when the multiplier is above 1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Luck = require(ReplicatedStorage.Shared.Logic.Luck)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local AreaProfileText = require(script.Parent.AreaProfileText)
local State = require(script.Parent.State)
local Text = require(script.Parent.Text)

local GroupLuck = {}

local function compose(
	leader: any,
	partyLuck: any,
	name: any,
	class: any,
	level: any,
	path: any,
	equipment: any
): Luck.BossLuck
	if leader ~= nil then
		if type(partyLuck) == "table" and type(partyLuck.legendaryMul) == "number" then
			return {
				legendaryMul = partyLuck.legendaryMul,
				upgrade = tonumber(partyLuck.upgrade) or 0,
				extra = tonumber(partyLuck.extra) or 0,
				from = if type(partyLuck.from) == "string" then partyLuck.from else nil,
			}
		end
		return Luck.NONE_BOSS
	end
	if type(class) ~= "string" or type(level) ~= "number" then
		return Luck.NONE_BOSS
	end
	local char = { class = class, level = level, path = path }
	local luck = Paths.luck(char, Paths.weaponTypesOf(equipment))
	return Luck.boss({ { name = if type(name) == "string" then name else "", luck = luck } })
end

function GroupLuck.now(): Luck.BossLuck
	return compose(
		State.Get({ "party", "leader" }),
		State.Get({ "party", "luck" }),
		State.Get({ "character", "name" }),
		State.Get({ "character", "class" }),
		State.Get({ "character", "level" }),
		State.Get({ "character", "path" }),
		State.Get({ "character", "equipment" })
	)
end

-- Narrow state branches only: `party` changes every 0.5 s (positions), `character` with every HP change.
function GroupLuck.use(use: Fusion.Use): Luck.BossLuck
	return compose(
		use(State.Value({ "party", "leader" })),
		use(State.Value({ "party", "luck" })),
		use(State.Value({ "character", "name" })),
		use(State.Value({ "character", "class" })),
		use(State.Value({ "character", "level" })),
		use(State.Value({ "character", "path" })),
		use(State.Value({ "character", "equipment" }))
	)
end

-- "Party luck: Ava (Legendary ×1,13)", nil without a multiplier.
function GroupLuck.line(use: Fusion.Use?, luck: Luck.BossLuck?): string?
	if not luck or luck.legendaryMul <= 1 then
		return nil
	end
	local name = luck.from or "-"
	if use then
		return Text.get(use, "luck.party", { name = name, mul = AreaProfileText.mul(use, luck.legendaryMul) })
	end
	local mul = string.format("%.2f", luck.legendaryMul):gsub("0+$", ""):gsub("%.$", "")
	mul = mul:gsub("%.", Text.now("format.decimal"))
	return Text.now("luck.party", { name = name, mul = mul })
end

return GroupLuck
