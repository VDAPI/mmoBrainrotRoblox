--!strict
-- Quest marks of every NPC for the local character (S25, Logic/NpcMarks), recomputed when the quests or the
-- level change. Read by the world map, the minimap and the plates over the NPCs (QuestController). S104: which NPCs
-- the character does not see yet (`Hidden`, NpcController and the maps).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NpcMarks = require(ReplicatedStorage.Shared.Logic.NpcMarks)
local NpcVisibility = require(ReplicatedStorage.Shared.Logic.NpcVisibility)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local scope = Fusion.scoped(Fusion)

local quests = State.Value({ "character", "quests" })
local level = State.Value({ "character", "level" })

local NpcMarkState = {}

NpcMarkState.Marks = scope:Computed(function(use): { [string]: NpcMarks.Mark }
	return NpcMarks.all(use(quests), use(level) or 1)
end)

-- S104: NPCs hidden from the character (NpcDef.showFrom, Logic/NpcVisibility): no figure, map icon or card.
NpcMarkState.Hidden = scope:Computed(function(use): { [string]: boolean }
	return NpcVisibility.hiddenIds(use(quests))
end)

function NpcMarkState.isHidden(npcId: string): boolean
	return Fusion.peek(NpcMarkState.Hidden)[npcId] == true
end

-- Glyph and colour of a mark (same look on the plates and the maps; S98: the only style table, QuestController's
-- plates read it too).
local STYLE: { [string]: { text: string, color: Color3 } } = {
	-- S136: colours from Data/UiPalette.mark (contrast-tested on the HUD tile)
	available = { text = "!", color = Theme.Mark.Available },
	availableLow = { text = "!", color = Theme.Mark.Low }, -- S98: an offer more than greyGap levels below
	turnIn = { text = "?", color = Theme.Mark.TurnIn },
	active = { text = "?", color = Theme.Mark.Active },
}

function NpcMarkState.style(mark: NpcMarks.Mark?): { text: string, color: Color3 }?
	return if mark then STYLE[mark] else nil
end

return NpcMarkState
