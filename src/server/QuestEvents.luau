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
-- S151 (achievements, Logic/Achievements.COUNTER_EVENTS; QuestService ignores these kinds: no objective type matches):
--   boss     + party (the winners present)                (DungeonService)
--   duel     + arena = true                               (ArenaService: a ranked match)
--   worldboss { occId, bossId }                           (WorldBossService, every rewarded fighter)
--   bloodmoon { id }                                      (BloodMoonService, the first points of an occurrence)
--   pvpkill  {}                                           (PvpService, the killer; the same kill as pvp.kills)
--   craft    { recipeId, n }  dismantle { n }  reroll {}  (BlacksmithService)
--   brew     { n }                                        (AlchemyService, collected orders)
--   trade    {}                                           (TradeService, both sides of a trade that moved something)
--   mail     {}                                           (MailService, a letter to a player)
--   visit    { mapId }                                    (TravelService.MarkVisited, the first visit)
--   quest    { kind = "main", index } | { kind = "side", questId } | { kind = "contract", n }
--            (QuestService / SideQuestService (first hand-in) / ContractService)
--   dodge    { n }                                        (FightLogService.End: dodged telegraphed blows)
--   social   { friends } | { guild = true }               (SocialService list writes, Guild/Runtime joining)
--   cosmetic { id }                                       (CosmeticService.Grant)
-- S151c (the bestiary only, Logic/Bestiary):
--   drop     { monsterId, ids }                           (LootService: the materials of a kill, every credited player;
--            DungeonService / WorldBossService: the boss bag's item ids)
-- Kills and levels reach the achievements through CombatService.MonsterKilled (+ lair) and LevelService.LevelChanged
-- (QuestService already handles both signals; a QuestEvents copy would count quests twice).

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
