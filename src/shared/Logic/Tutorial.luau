--!strict
-- The hands-on tutorial of a new character (S155, docs/DESIGN.md §20 "Samouczek"; pure). Six action steps in a fixed
-- order, each finished by doing it, never by a "Next" button: move, talk to the captain and take the first quest, open
-- the backpack, drink a potion, attack a monster, use a skill. A closing "done" hint follows. It runs alongside the
-- story quests (Data/Quests/Main, unchanged) and can be skipped at any time.
--   server steps  the server sees them (quest, potion, attack, skill): TutorialService.Event
--   client steps  only the client sees them (move, backpack): the TutorialEvent remote, whitelisted by clientAllowed
-- An event of a later step counts ahead (state.pending), so nobody repeats what they already did; an event of an
-- earlier step is ignored. The save is character.tutorial (State); characters made before S155 have done = true and
-- reward = true (AccountSchema), CharacterFactory starts new ones at step 1.
-- The onboarding funnel (one per game in Roblox: LogOnboardingFunnelStepEvent): the action steps 1-6, then the first
-- ten story quests as 7-16, then level 5 as 17; funnelStep is the only source of these numbers.

local Elements = require("../Data/Elements")
local ItemRoll = require("./ItemRoll")
local Items = require("../Data/Items")
local Keybinds = require("./Keybinds")
local Quests = require("../Data/Quests")
local Rng = require("./Rng")
local TutorialData = require("../Data/Tutorial")
local Types = require("../Types")

local Tutorial = {}

export type Kind = "server" | "client"
-- `keys`: placeholder in the PC text -> Data/Keybinds action (the player's own key goes in, Tutorial.keyArgs).
-- `anchor`: the HUD element the hint points at (UI/HudAnchors); nil = no element (the hint stands in its default place).
-- `travel`: the step waits for a hunting ground; away from one the hint says "follow the golden arrow" (`.travel`
-- text; the arrow is the world guide, Tutorial.guide).
export type Step = {
	id: string,
	kind: Kind,
	textKey: string,
	anchor: string?,
	keys: { [string]: string },
	travel: boolean?,
}
export type State = {
	step: number,
	done: boolean,
	skipped: boolean,
	reward: boolean,
	drop: boolean, -- S155b: the first valuable drop was picked up (Data/Tutorial.FIRST_DROP; audit 2026-10-21: not on spawn)
	pending: { [string]: boolean }?, -- later steps already done (counted when their turn comes)
}
export type FunnelKind = "tutorial" | "quest" | "level"
export type FunnelEntry = { kind: FunnelKind, key: string }

local function step(id: string, kind: Kind, anchor: string?, keys: { [string]: string }?, travel: boolean?): Step
	return table.freeze({
		id = id,
		kind = kind,
		textKey = `tutorial.{id}`,
		anchor = anchor,
		keys = table.freeze(keys or {}),
		travel = travel,
	})
end

-- Fixed order. The last entry, `done`, is never an event: the server finishes the tutorial after `skill` and the client
-- shows the closing hint for Data/Tutorial.DONE_SECONDS.
Tutorial.STEPS = table.freeze({
	step("move", "client", "joystick"),
	step("quest", "server", "questTracker", { interact = "interact" }),
	step("backpack", "client", "backpackButton", { key = "win_inventory" }),
	step("potion", "server", "potionBar", { key = "potion_hp" }),
	step("attack", "server", "attackButton", { target = "target_next" }, true),
	step("skill", "server", "skillBar", { key = "skill_1" }),
	step("done", "server", nil),
} :: { Step })

-- Number of steps finished by an action (every step but `done`).
Tutorial.ACTIONS = #Tutorial.STEPS - 1

local indexOf: { [string]: number } = {}
for i, s in Tutorial.STEPS do
	indexOf[s.id] = i
end
Tutorial.indexOf = table.freeze(indexOf)

-- The funnel key of the reward level ("level5").
Tutorial.LEVEL_KEY = `level{TutorialData.REWARD_LEVEL}`

-- The story quests in the funnel (the first ten of Data/Quests/Main, in order).
Tutorial.FUNNEL_QUESTS = 10

local function entry(kind: FunnelKind, key: string): FunnelEntry
	return table.freeze({ kind = kind, key = key })
end

local funnel: { FunnelEntry } = {}
for i = 1, Tutorial.ACTIONS do
	table.insert(funnel, entry("tutorial", Tutorial.STEPS[i].id))
end
for i = 1, math.min(Tutorial.FUNNEL_QUESTS, #Quests.Main.list) do
	table.insert(funnel, entry("quest", Quests.Main.list[i].id))
end
table.insert(funnel, entry("level", Tutorial.LEVEL_KEY))
Tutorial.FUNNEL = table.freeze(funnel)

-- The funnel step of `kind` + `key` (1 = the first), nil when it is not in the funnel.
function Tutorial.funnelStep(kind: FunnelKind, key: string): number?
	for i, entry in Tutorial.FUNNEL do
		if entry.kind == kind and entry.key == key then
			return i
		end
	end
	return nil
end

-- A new character's state (CharacterFactory).
function Tutorial.newState(): State
	return { step = 1, done = false, skipped = false, reward = false, drop = false }
end

-- A clean copy of a saved state (bad or missing fields: a finished tutorial with the reward taken, like the
-- characters made before S155). S155b: a save without `drop` gets the first drop only while its level reward still
-- waits (a character of S155 below level 5); every older one counts as given.
function Tutorial.sanitize(raw: any): State
	if type(raw) ~= "table" then
		return { step = 1, done = true, skipped = false, reward = true, drop = true }
	end
	local n = tonumber(raw.step) or 1
	local state: State = {
		step = math.clamp(math.floor(n), 1, #Tutorial.STEPS),
		done = raw.done == true,
		skipped = raw.skipped == true,
		reward = raw.reward ~= false,
		drop = if raw.drop == nil then raw.reward ~= false else raw.drop == true,
	}
	if type(raw.pending) == "table" then
		local pending: { [string]: boolean } = {}
		for id, value in raw.pending do
			local i = if type(id) == "string" then indexOf[id] else nil
			if value == true and i and i <= Tutorial.ACTIONS then
				pending[id] = true
			end
		end
		if next(pending) ~= nil then
			state.pending = pending
		end
	end
	return state
end

local function copy(state: State): State
	local out: State =
		{ step = state.step, done = state.done, skipped = state.skipped, reward = state.reward, drop = state.drop }
	if state.pending then
		out.pending = table.clone(state.pending)
	end
	return out
end

-- The step shown now, nil once the tutorial is finished or skipped.
function Tutorial.current(state: State): Step?
	if state.done then
		return nil
	end
	return Tutorial.STEPS[state.step]
end

-- The closing hint of a tutorial finished by doing it (not skipped), nil otherwise.
function Tutorial.finale(state: State): Step?
	if state.done and not state.skipped and state.step == #Tutorial.STEPS then
		return Tutorial.STEPS[#Tutorial.STEPS]
	end
	return nil
end

-- Counts `event` (a step id): the current step moves on (and through every later step already done), a later step
-- waits in `pending`, an earlier step, an unknown name and anything after the end change nothing. Returns the new state
-- and whether the event counted.
function Tutorial.advance(state: State, event: string): (State, boolean)
	local index = indexOf[event]
	if state.done or not index or index > Tutorial.ACTIONS or index < state.step then
		return state, false
	end
	local out = copy(state)
	if index > out.step then
		local pending = out.pending or {}
		if pending[event] then
			return state, false
		end
		pending[event] = true
		out.pending = pending
		return out, true
	end
	out.step += 1
	local pending = out.pending
	while pending and out.step <= Tutorial.ACTIONS and pending[Tutorial.STEPS[out.step].id] do
		pending[Tutorial.STEPS[out.step].id] = nil
		out.step += 1
	end
	if pending and next(pending) == nil then
		out.pending = nil
	end
	if out.step > Tutorial.ACTIONS then
		out.step = #Tutorial.STEPS
		out.done = true
		out.pending = nil
	end
	return out, true
end

-- Skips the rest (at any step); a finished tutorial stays as it is. The reward does not depend on it.
function Tutorial.skip(state: State): State
	if state.done then
		return state
	end
	local out = copy(state)
	out.skipped = true
	out.done = true
	out.pending = nil
	return out
end

-- Whether the client may report `event` (only the steps the server cannot see).
function Tutorial.clientAllowed(event: string): boolean
	local index = indexOf[event]
	return index ~= nil and Tutorial.STEPS[index].kind == "client"
end

-- The text key of a step: `.touch` on a phone, `.pc` otherwise; `.travel` while a travel step waits for a hunting
-- ground (`away`).
function Tutorial.text(s: Step, touch: boolean, away: boolean?): string
	if away and s.travel then
		return `{s.textKey}.travel`
	end
	return `{s.textKey}.{if touch then "touch" else "pc"}`
end

-- The anchor of a step now: none while a travel step waits for a hunting ground (W28: the hint stands in its default
-- place and the golden guide arrow, UI/GuidePointer, leads the way; it used to point at the tracker's tiny arrow).
function Tutorial.anchorOf(s: Step, away: boolean?): string?
	if away and s.travel then
		return nil
	end
	return s.anchor
end

-- W28: what the world guide (golden arrow, ground chevrons, marker over the target, screen-edge arrow:
-- Controllers/GuidePointerController) points at during a step. "npc": that NPC (Data/Npcs id); "quest": the tracked
-- quest's target (QuestTrack.Target, through the portals of the route); "monster": the player's target or the nearest
-- living monster (the quest's target when none is near). Steps done in the HUD (move, backpack, potion, skill, done)
-- have no world target.
export type Guide = { kind: "npc" | "quest" | "monster", id: string? }

-- The NPC who gives the first story quest (the "quest" step).
Tutorial.CAPTAIN = "captain"

-- The guide of step `s` (nil = none). `away`: a travel step waiting for a hunting ground (the starting map);
-- `mainTaken`: a story quest is taken (the captain's step then follows the quest instead).
function Tutorial.guide(s: Step?, away: boolean?, mainTaken: boolean?): Guide?
	if not s then
		return nil
	end
	if s.id == "quest" then
		return if mainTaken then { kind = "quest" } else { kind = "npc", id = Tutorial.CAPTAIN }
	elseif s.id == "attack" then
		return if away then { kind = "quest" } else { kind = "monster" }
	end
	return nil
end

-- The key labels of a step's PC text from the player's bindings (account.settings.keys).
function Tutorial.keyArgs(s: Step, binds: Keybinds.Overrides?): { [string]: string }
	local args: { [string]: string } = {}
	for placeholder, action in s.keys do
		args[placeholder] = Keybinds.label(Keybinds.key(binds, action))
	end
	return args
end

-- Whether the level reward is due: Data/Tutorial.REWARD_LEVEL reached and not taken yet. Skipping does not matter: the
-- reward is for reaching the level, not for clicking through.
function Tutorial.rewardDue(state: State, level: number): boolean
	return level >= TutorialData.REWARD_LEVEL and not state.reward
end

-- S155b: whether the first valuable drop is still due (Data/Tutorial.FIRST_DROP; skipping does not matter). Audit
-- 2026-10-21: `drop` is set on pickup, so while its bag still lies on the ground (`bagOut`) no second one comes.
function Tutorial.firstDropDue(state: State, bagOut: boolean?): boolean
	return not state.drop and not bagOut
end

-- S155b: the first valuable drop (Data/Tutorial.FIRST_DROP) for a character of `classId` at `level` wielding
-- `weapon`: the same weapon definition (a named boss item or none: the class's starting weapon) at FIRST_DROP.rarity,
-- with the wielded weapon's element (a Mage keeps the school of the skill pool), bound (no mule farming with fresh
-- characters). nil when the class has no weapon.
function Tutorial.firstDrop(
	classId: string,
	level: number,
	weapon: Types.ItemInstance?,
	rng: Rng.Rng,
	uid: string
): Types.ItemInstance?
	local defId: string? = nil
	local wielded = weapon and Items.get(weapon.id)
	if weapon and wielded and wielded.slot == "weapon" and wielded.fixedBonuses == nil then
		defId = weapon.id
	else
		local gear: { string } = Items.startingGear[classId] or {}
		for _, id in gear do
			local def = Items.get(id)
			if def and def.slot == "weapon" then
				defId = id
				break
			end
		end
	end
	local def = defId and Items.get(defId)
	if not defId or not def then
		return nil
	end
	local item = ItemRoll.rollItem(defId, math.max(1, level), TutorialData.FIRST_DROP.rarity, rng, uid, classId)
	if def.elemental then
		item.el = if weapon and weapon.el then weapon.el else Elements.DEFAULT
	end
	item.bound = true
	return item
end

-- S155b: the state with the first drop given.
function Tutorial.withDrop(state: State): State
	local out = copy(state)
	out.drop = true
	return out
end

-- S155b: whether the account already knows the game: another character (slot summaries, Logic/CharacterFactory)
-- reached Data/Tutorial.REWARD_LEVEL. The hint then offers "I know the game, skip" more plainly.
function Tutorial.veteran(slots: any): boolean
	if type(slots) ~= "table" then
		return false
	end
	for _, summary in slots do
		if type(summary) == "table" and (tonumber(summary.level) or 0) >= TutorialData.REWARD_LEVEL then
			return true
		end
	end
	return false
end

-- Whether the potion step is the current one: then an ordinary potion is drunk even at full (a new character stands in
-- the city at full HP; PotionService.AddFullDrink).
function Tutorial.wantsPotion(state: State): boolean
	local s = Tutorial.current(state)
	return s ~= nil and s.id == "potion"
end

-- Studs walked after one more sample: `walked` plus the ground distance (dx, dz; y ignored) while the player steers
-- (`steering`: Humanoid.MoveDirection non-zero); a jump longer than Data/Tutorial.MAX_STEP (a spawn pivot, a
-- teleport) never counts.
function Tutorial.walk(walked: number, dx: number, dz: number, steering: boolean): number
	local d = math.sqrt(dx * dx + dz * dz)
	if not steering or d > TutorialData.MAX_STEP then
		return walked
	end
	return walked + d
end

-- Whether the character walked far enough (studs the player steered, Tutorial.walk) to finish the "move" step.
function Tutorial.moved(walked: number): boolean
	return walked >= TutorialData.MOVE_STUDS
end

return Tutorial
