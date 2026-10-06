--!strict
-- Grimrok, Goblin Warchief (DESIGN §16). The data drives the fight (Data/Bosses): phase 1 sweep (cone) and
-- leap on a random player; phase 2 (70 %) summons 4 goblins every 20 s; phase 3 (35 %) whirlwind around
-- himself (run!) and +25 % speed. The red war paint of phase 3 is in Data/MonsterLooks (phases), applied by
-- clients when the Phase attribute changes (S24).

local Grimrok = {}

return Grimrok
