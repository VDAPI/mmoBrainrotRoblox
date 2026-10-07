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
--   use      (S27) hold an interaction at the quest anchor `anchor` (one) or every one of `anchors` (progress =
--            distinct anchors done); `action` = locale key of the prompt, `hold` seconds, `fx` = what the player
--            sees change at the anchor afterwards (client only)
--   deliver  (S27) carry the virtual quest item `item` (given on accept, shown in the journal) and talk to `npc`
--            (the quest's turn-in NPC when nil)
-- S27: `kill` and `collect` take `area` (a monster area id): only monsters of groups from that area count.

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
	area: string?, -- S27
	anchor: string?, -- S27 use
	anchors: { string }?, -- S27 use
	action: string?, -- S27 use: locale key of the prompt ("quest.use.fence")
	hold: number?, -- S27 use: seconds
	fx: string?, -- S27 use: client effect at the anchor once done (Data/Quests/Side FX list)
	place: string?, -- S27 reach with x/z: locale key of the place ("place.stonecircle")
}

export type Reward = {
	exp: number,
	gold: number,
	items: { { id: string, n: number } }?,
	-- S27: one item of N to choose, rolled for the character's class when the quest is complete; "final" uses the
	-- higher rarity of an arc's last quest (Config.SideQuest.choiceRarity).
	choice: ("normal" | "final")?,
}

export type MainQuest = {
	id: string,
	level: number, -- recommended level; can be accepted from level - 2
	giver: string, -- NPC id
	turnIn: string, -- NPC id
	objectives: { Objective },
	reward: Reward,
}

-- S27: side quest (Data/Quests/Side). Several may be active at once (Config.SideQuest.maxActive); taken from
-- `level - Config.SideQuest.levelSlack` once every `requires` quest (side or main) is done. `arc` groups them in
-- the journal; `pages` = number of story pages (quest.<id>.p1..pN); `where` hints the tracker when no objective
-- points anywhere better.
export type SideQuest = {
	id: string,
	level: number,
	giver: string,
	turnIn: string,
	arc: string,
	pages: number,
	requires: { string }?,
	objectives: { Objective },
	reward: Reward,
	where: { map: string, area: string?, x: number?, z: number? }?,
}

export type DailyTemplate = {
	id: string,
	minLevel: number,
	-- Builds the objective for a character level (region and amounts scale with level).
	objective: (level: number) -> Objective,
}

return nil
