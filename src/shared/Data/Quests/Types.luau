--!strict
-- Quest shapes (DESIGN §20). Objective types:
--   talk     talk to `npc`
--   kill     kill `n` of `monster` (any kind when nil), `variant` ("normal" / "elite" = elite or Elite II),
--            `region` (1–4, any kind of that region when `monster` is nil)
--   collect  quest items dropped by `monster` with `chance` while the quest is active (virtual, `item` key)
--   gather   gather `n` from nodes of `node` (kind id) or `category` ("ore" / "herb")
--   fish     catch `n` fish
--   reach    enter `map` (and come within `radius` of x/z when given)
--   boss     defeat `boss`
--   upgrade  upgrade any item to +`up` or higher
--   equip    equip an item of rarity >= `rarity` (any when nil)
--   level    reach character level `level`
--   loot / stats / learn / potion   tutorial actions (pick up loot, spend a stat point, learn a skill,
--            drink a potion)
--   duel     finish `n` duels

export type Objective = {
	type: string,
	n: number,
	npc: string?,
	monster: string?,
	variant: string?,
	region: number?,
	item: string?,
	chance: number?,
	node: string?,
	category: string?,
	map: string?,
	x: number?,
	z: number?,
	radius: number?,
	boss: string?,
	up: number?,
	rarity: number?,
	level: number?,
}

export type Reward = {
	exp: number,
	gold: number,
	items: { { id: string, n: number } }?,
}

export type MainQuest = {
	id: string,
	level: number, -- recommended level; can be accepted from level - 2
	giver: string, -- NPC id
	turnIn: string, -- NPC id
	objectives: { Objective },
	reward: Reward,
}

export type DailyTemplate = {
	id: string,
	minLevel: number,
	-- Builds the objective for a character level (region and amounts scale with level).
	objective: (level: number) -> Objective,
}

return nil
