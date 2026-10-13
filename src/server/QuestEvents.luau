--!strict
-- Gameplay events that quests count (S11). A plain module, not a service: any service may fire events
-- without depending on QuestService (which depends on most of them).
--   kill     { monsterId, variant, level, mapId }      (CombatService credit, every credited player)
--   gather   { kind, category, itemId, n }               (GatherService)
--   fish     { fishId }                                  (FishingService)
--   upgrade  { to }                                      (BlacksmithService, successful upgrades)
--   boss     { bossId }                                  (DungeonService, every winner)
--   equip    { rarity }                                  (EquipmentService)
--   loot     {}                                          (LootService pickup)
--   stats    {}                                          (StatService allocation)
--   learn    { skillId }                                 (SkillService: SetHotbar, PutOnBar, auto-put on unlock)
--   potion   {}                                          (PotionService)
--   duel     { won }                                     (DuelService, both fighters)
--   event    { eventId, kind, success, map }    (WorldEventService, every rewarded participant; S98 template
--            "event" counts on the kind alone, S101)
--   escort   { npc, quest }                               (S101b CompanionService: the leading companion arrived
--            with the player)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local QuestEvents = {
	-- (player, kind, data)
	Fired = Signal.new(),
}

function QuestEvents.fire(player: Player, kind: string, data: { [string]: any }?)
	QuestEvents.Fired:Fire(player, kind, data or {})
end

return QuestEvents
