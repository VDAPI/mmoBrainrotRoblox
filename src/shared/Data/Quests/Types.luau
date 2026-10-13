--!strict
-- Quest shapes (DESIGN §20). Objective types:
--   talk     talk to `npc`
--   kill     kill `n` of `monster` (any kind when nil), `variant` ("normal" / "elite" = elite or Elite II /
--            S98: "elite2" = Elite II only), `region` (1–4, any kind of that region when `monster` is nil)
--   collect  quest items dropped by `monster` with `chance` while the quest is active (virtual, `item` key)
--   gather   gather `n` from nodes of `node` (kind id) or `category` ("ore" / "herb")
--   fish     catch `n` fish
--   reach    enter `map` (and come within `radius` of x/z when given)
--   boss     defeat `boss`
--   upgrade  upgrade any item to +`up` or higher
--   equip    equip an item of rarity >= `rarity` (any when nil)
--   level    reach character level `level`
--   loot / stats / learn / potion   tutorial actions (pick up loot, spend a stat point, put a skill on the bar
--            (SkillService: SetHotbar, PutOnBar, auto-put on unlock), drink a potion)
--   duel     finish `n` duels
--   use      (S27) hold an interaction at the quest anchor `anchor` (one) or every one of `anchors` (progress =
--            distinct anchors done); `action` = locale key of the prompt, `hold` seconds, `fx` = what the player
--            sees change at the anchor afterwards (client only)
--   deliver  (S27) carry the virtual quest item `item` (given on accept, shown in the journal) and talk to `npc`
--            (the quest's turn-in NPC when nil)
--   event    (S98) take part in `n` world events; counted from S101 through QuestEvents.fire(player, "event", ...)
--            (S101 decides the event data; the objective matches on the kind alone, QuestLogic.amount `t == kind`)
-- S27: `kill` and `collect` take `area` (a monster area id): only monsters of groups from that area count.

-- S98 (docs/DESIGN-15.md §3.1): quest categories in journal-tab order (Data/Quests.CATEGORIES). The stable arc of
-- S96 is "side" (no separate "mount" category).
export type Category = "main" | "side" | "contract" | "boss" | "daily" | "weekly"

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
	mount: string?, -- S96: a Data/Mounts id given on hand-in (once per character)
	cosmetic: string?, -- S97: account cosmetic granted on turn-in; nothing when already owned
}

export type MainQuest = {
	id: string,
	level: number, -- recommended level; can be accepted from level - 2
	giver: string, -- NPC id
	turnIn: string, -- NPC id
	objectives: { Objective },
	reward: Reward,
	category: Category?, -- S98: "main" (set by Main.luau's q)
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
	minLevel: number?, -- S96: never offered below this character level, whatever levelSlack says
	wiki: boolean?, -- S96: false = left out of the wiki (released in S97)
	category: Category?, -- S98: "side" (Side.luau) or "boss" (Boss.luau); set by the builders, never nil in data
}

export type DailyTemplate = {
	id: string,
	minLevel: number,
	-- Builds the objective for a character level (region and amounts scale with level).
	objective: (level: number) -> Objective,
	hidden: boolean?, -- S98: in the data but never picked (Daily and Weekly templates)
}

-- S98 (docs/DESIGN-15.md §3.3): a hunting contract of Data/Quests/Contracts (filled by S99), one per level 1-99, id
-- `contract_<level>`; `map` is the region of the hunting ground (its scout is `scout_<map>`). No giver / turnIn: the
-- NPCs that hand it out (the questboard and the scout) come from S99's Logic/Contracts.giversOf.
export type ContractQuest = {
	id: string,
	level: number,
	category: "contract",
	map: string,
	area: string,
	objectives: { Objective },
	reward: Reward,
}

return nil
