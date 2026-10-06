--!strict
-- Quest marks of every NPC for the local character (S25, Logic/NpcMarks), recomputed when the quests or the
-- level change. Read by the world map, the minimap and the plates over the NPCs (QuestController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NpcMarks = require(ReplicatedStorage.Shared.Logic.NpcMarks)
local State = require(script.Parent.State)

local scope = Fusion.scoped(Fusion)

local quests = State.Value({ "character", "quests" })
local level = State.Value({ "character", "level" })

local NpcMarkState = {}

NpcMarkState.Marks = scope:Computed(function(use): { [string]: NpcMarks.Mark }
	return NpcMarks.all(use(quests), use(level) or 1)
end)

-- Glyph and colour of a mark (same look on the plates and the maps).
local STYLE: { [string]: { text: string, color: Color3 } } = {
	available = { text = "!", color = Color3.fromHex("#E8C25A") },
	turnIn = { text = "?", color = Color3.fromHex("#E8C25A") },
	active = { text = "?", color = Color3.fromHex("#9A9DA8") },
}

function NpcMarkState.style(mark: NpcMarks.Mark?): { text: string, color: Color3 }?
	return if mark then STYLE[mark] else nil
end

return NpcMarkState
