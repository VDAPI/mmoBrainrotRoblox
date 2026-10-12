--!strict
-- Basic combat (DESIGN §4.5, §15, §24). Server-driven auto-attack: the client only selects a target
-- (SetTarget); the server attacks at the player's attack speed whenever the target is in range
-- (melee 7 / ranged 35 studs + lag tolerance). Fewer remotes and nothing to forge.
--
-- Also resolves monster attacks and Elite II abilities (MonsterService handlers), grants EXP/gold on kills,
-- and batches visual events (damage numbers, attack swings/projectiles, telegraphs) to nearby clients
-- through one "CombatFx" remote per frame.
--
-- Later systems: skills (S05) call CombatService.DealDamage; loot (S04) and quests (S11) listen to
-- MonsterKilled; parties (S09) extend ResolveKillCredit.
--
-- S64: the block (regular blows only, healing with Parry) and the counter (tryCounter) live in monsterHitsPlayer and
-- the PvP branch of DealDamage; melee / ranged protection is a reduction provider fed by `incoming`. Their caps
-- (blockCap, riposteCap, executionerCap, cdrCap, pvp.block / pvp.counter) are in Data/Combat.
--
-- S65: rhythm and player-state traits: Twin Cut and Full Draw in tryBasicAttack, Run Through and Elemental Spark after
-- a basic hit (Skills/Elements), Runic Seal polled in Heartbeat (BreakSeal on blinks, pushes and death), Frostbite and
-- the seal in offensiveMultiplier, Saving Blow at the end of DealDamage (Skills/Context.mostWounded / healFrom).
--
-- S72 (ROZWOJ 10.3, 10.4, 14.2): receivers of the Warrior's node hooks (all 0 until the S75 nodes or /hook): Fury
-- gain in DealDamage, furyDamage and damagePerEnemy in offensiveMultiplier, own reductions guardPerEnemy, furyGuard
-- and lastStand (also on intercepted parts), threat through MonsterService's threatMultiplier, bleedDamage in DotBonus,
-- block energy in onBlock (NodeHook), KillInfo.finisher for Carnage.
--
-- S76 (ROZWOJ 11.3, 11.4): no basic attacks while aiming (castTime, S80: and beams); every poison of a player goes through ApplyPoison
-- (poisonSlow), poisonDamage sits in DotBonus, poisonedGuard is an own reduction against an attacker the player has
-- poisoned, and a monster's death moves the rest of its poisons (poisonSpread) and marks (jump) to the nearest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local AreaProfiles = require(Shared.Data.AreaProfiles)
local AttackPose = require(Shared.Logic.AttackPose)
local Bonuses = require(Shared.Data.Bonuses)
local BuffCategories = require(Shared.Data.BuffCategories)
local Classes = require(Shared.Data.Classes)
local Context = require(script.Parent.Parent.Skills.Context)
local DamageText = require(Shared.Logic.DamageText)
local Combat = require(Shared.Data.Combat)
local Damage = require(Shared.Logic.Damage)
local EffectStack = require(Shared.Logic.EffectStack)
local Elements = require(script.Parent.Parent.Skills.Elements)
local Exp = require(Shared.Logic.Exp)
local ItemTraits = require(Shared.Data.ItemTraits)
local Items = require(Shared.Data.Items)
local Log = require(Shared.Util.Log)
local MonsterAbilities = require(Shared.Data.MonsterAbilities)
local MonsterStats = require(Shared.Logic.MonsterStats)
local Net = require(Shared.Net)
local Loot = require(Shared.Logic.Loot)
local Luck = require(Shared.Logic.Luck)
local PartyBonus = require(Shared.Logic.PartyBonus)
local PartyLoot = require(Shared.Logic.PartyLoot)
local Paths = require(Shared.Data.Paths)
local Push = require(script.Parent.Parent.Skills.Push)
local Rng = require(Shared.Logic.Rng)
local Signal = require(ReplicatedStorage.Packages.Signal)
local SkillData = require(Shared.Data.Skills)
local SkillGeom = require(Shared.Logic.SkillGeom)
local Traits = require(Shared.Logic.Traits)
local Types = require(Shared.Types)
local Vigilance = require(Shared.Logic.Vigilance)

local log = Log.new("CombatService")

local HOOK_RULES = Paths.HOOK_RULES

local CombatService = {
	Name = "CombatService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"EntityService",
		"MonsterService",
		"StatService",
		"ResourceService",
		"LevelService",
		"PvpService",
		"ZoneService",
		"EquipmentService",
		"StatusEffectService",
		"PartyService",
	},
	-- (info: KillInfo, credit: { Player }, killer: Player?) after a monster died.
	MonsterKilled = Signal.new(),
}

export type KillInfo = {
	monsterId: string,
	variant: string,
	level: number,
	position: Vector3,
	mapId: string?,
	entityId: string,
	boss: boolean?, -- dungeon bosses: DungeonService hands out the rewards
	noLoot: boolean?, -- boss helpers: no item drops
	areaId: string?, -- S27: named area of the monster's group (model attribute AreaId)
	dropLevel: number?, -- S32: base level for item drops (spawner level without the variant's levels)
	luck: Luck.MonsterLuck?, -- S60: luck of the credited group (nil for bosses)
	finisher: Player?, -- S72: the player who dealt the killing blow (Monster.killedBy); credit is unchanged
}

type FxEvent = { [string]: any }

type Entity = {
	id: string,
	kind: "player" | "monster",
	model: Model?,
	player: Player?,
	monster: any?,
}

local PlayerStateService: any
local CharacterService: any
local EntityService: any
local MonsterService: any
local StatService: any
local ResourceService: any
local LevelService: any
local PvpService: any
local ZoneService: any
local EquipmentService: any
local StatusEffectService: any
local PartyService: any
local Registry: any
local PathService: any

-- Lazy: PathService depends on DungeonService (NearAnyEntrance), which depends on this service, so a Deps entry here
-- would be a cycle. Never call during Init.
local function pathService(): any
	PathService = PathService or Registry.Get("PathService")
	return PathService
end

type Attacker = {
	target: string?,
	attack: boolean, -- false: target kept (skills, admin) but no auto-attack (the player walked away)
	nextAttack: number,
	damageOverride: number?,
	rejectedAt: number, -- last AttackRejected sent (rate limit)
	outOfRangeSince: number?, -- standing still out of range since (for the "too far" message)
	shockAt: { [string]: number }, -- S63: last Concussion stun (os.clock) per target entity id
	resourceAt: number?, -- S63: last resourceOnHit refund (os.clock)
	twinCount: number?, -- S65: Twin Cut: basic attacks counted since the last extra cut
	twinAt: number?, -- S65: Twin Cut: last counted basic attack (os.clock)
	seal: Traits.Seal?, -- S65: Runic Seal anchor (os.clock)
	-- S77 Weak Spot: the selected target the stacks belong to and how many (each +weakSpotPerStack % on it)
	weakTarget: string?,
	weakStacks: number?,
	-- S77 Vigilance / Warning: os.clock() of this Scout's last trigger of each kind (move, guard)
	vigilance: { [string]: number }?,
}

local REJECT_INTERVAL = 2
local TOO_FAR_AFTER = 1
local SEAL_POLL = 0.1 -- polling rate, not a balance number
local SEAL_MARKER = 3600 -- marker lives until the seal breaks

-- S65: services of Skills/Elements (set in Init).
local elementServices: Elements.Services

-- S65: a fixed number of a trait (Data/ItemTraits params); never a number in code.
local function traitParam(id: string, key: string): number
	local def = ItemTraits.get(id)
	local params = def and def.params
	local value = params and params[key]
	assert(value ~= nil, `ItemTraits: {id}.params.{key} is missing`)
	return value
end

-- S65: Elemental Spark's recipe (its params) with exact item ticks.
local sparkSpec: Traits.ElementSpec = {
	burnPct = traitParam("elementalSpark", "burnPct"),
	burnDuration = traitParam("elementalSpark", "burnDuration"),
	exactTicks = true,
	slowPct = traitParam("elementalSpark", "slowPct"),
	slowDuration = traitParam("elementalSpark", "slowDuration"),
	arcPct = traitParam("elementalSpark", "arcPct"),
	arcRadius = traitParam("elementalSpark", "arcRadius"),
	sameTargetPct = traitParam("elementalSpark", "sameTargetPct"),
}

local attackers: { [Player]: Attacker } = {}
local rng = Rng.new()
local fxQueue: { { position: Vector3, event: FxEvent } } = {}

-- S61: telegraphed areas until they resolve (see telegraph).
export type RedZone = { monster: any, ability: MonsterAbilities.Ability, area: CFrame, endsAt: number }
local redZones: { RedZone } = {}

-- S64: the facts of the hit a player is taking, set only around ResourceService.Damage ("monster" / "pvp") so the
-- protection provider (Init) knows the kind of blow.
local incoming: { [Player]: { delivery: string?, monster: any? } } = {}

local function attackerState(player: Player): Attacker
	local state = attackers[player]
	if not state then
		state = {
			target = nil,
			attack = false,
			nextAttack = 0,
			damageOverride = nil,
			rejectedAt = 0,
			shockAt = {},
			resourceAt = nil,
		}
		attackers[player] = state
	end
	return state
end

-- Visual events --------------------------------------------------------------------------------------

local function queueFx(position: Vector3?, event: FxEvent)
	if position then
		table.insert(fxQueue, { position = position, event = event })
	end
end

local function flushFx()
	if #fxQueue == 0 then
		return
	end
	local queue = fxQueue
	fxQueue = {}
	for _, player in Players:GetPlayers() do
		local model = player.Character
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local batch = {}
			for _, item in queue do
				if (item.position - root.Position).Magnitude <= Combat.fxRadius then
					table.insert(batch, item.event)
				end
			end
			if #batch > 0 then
				Net.Fire(player, "CombatFx", batch)
			end
		end
	end
end

-- Helpers ----------------------------------------------------------------------------------------------

local function rootOf(model: Model?): BasePart?
	return if model then model:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- S29: why a player took nothing from a hit that was not dodged: "im" (god mode, invulnerability, respawn
-- protection) or "ab" (shields / mana shield soaked all of it).
local function blockedFlag(player: Player): string
	if ResourceService.IsGod(player) then
		return "im"
	end
	local entity = EntityService.GetPlayerEntity(player)
	if entity and (StatusEffectService.Has(entity, "invuln") or StatusEffectService.Has(entity, "respawnShield")) then
		return "im"
	end
	return "ab"
end

-- S29: the damage event of a resolved hit on a player (every hit shows something).
local function playerHitEvent(
	target: Player,
	targetId: string,
	attackerId: string?,
	result: Damage.Result,
	taken: number
): FxEvent
	local event: FxEvent =
		{ k = "dmg", e = targetId, s = attackerId, a = math.floor(taken), c = result.crit, d = result.dodged }
	if result.missed then
		event.mi = true -- S61: the attacker missed (misfortune), "Miss"
	end
	if result.blocked then
		event.bl = true -- S64: the defender blocked, "Blocked" (d stays true)
	end
	if not result.dodged and taken <= 0 then
		event[blockedFlag(target)] = true
	end
	return event
end

local function flatDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function playerAlive(player: Player): boolean
	return PlayerStateService.GetPhase(player) == "playing"
		and player.Character ~= nil
		and not ResourceService.IsDead(player)
end

local function playerCombat(player: Player): (Damage.Attacker?, Damage.Defender?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local result = StatService.Get(player)
	if not character or not result then
		return nil, nil
	end
	return Damage.fromStats(character.level, result.values)
end

local function basicAttackProfile(player: Player): ("phys" | "magic", boolean, string)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local class = character and Classes.get(character.class)
	local derived = PlayerStateService.Get(player, { "derived" })
	local ranged = if derived and derived.weapon
		then derived.weapon.ranged == true
		elseif class then class.basicAttack.ranged
		else false
	local kind: "phys" | "magic" = if class then class.basicAttack.kind else "phys"
	local style: string = if class then class.basicAttack.style else "melee"
	if ranged and style == "melee" then
		style = "arrow"
	end
	return kind, ranged, style
end

-- Weapon type and element of a player's attack for the client's animation (S22: "atk" events carry them).
local function weaponFx(player: Player): (string?, string?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local item = character and (character.equipment :: any).weapon
	local def = item and Items.get(item.id)
	local derived = PlayerStateService.Get(player, { "derived" })
	local element = if derived and derived.weapon then derived.weapon.element else nil
	return if def then def.type else nil, element
end

local function entityRadius(entity: Entity): number
	local root = rootOf(entity.model)
	return if root then math.max(root.Size.X, root.Size.Z) / 2 else 1
end

-- Damage params of the player's basic attack: its kind and the weapon's element (S18: Mage weapons).
local function basicParams(player: Player): Damage.Params
	local kind = basicAttackProfile(player)
	local derived = PlayerStateService.Get(player, { "derived" })
	local element = if derived and derived.weapon then derived.weapon.element else nil
	return { kind = if kind == "magic" then "magic" else "phys", element = element }
end

-- True when `targetEntity` stands within the player's basic attack reach (weapon range + lag tolerance).
local function inBasicReach(player: Player, targetEntity: any, ranged: boolean): boolean
	local myRoot = rootOf(player.Character)
	local targetPosition = EntityService.Position(targetEntity)
	if not myRoot or not targetPosition then
		return false
	end
	local range = (if ranged then Combat.rangedRange else Combat.meleeRange) + Combat.rangeTolerance
	return flatDistance(myRoot.Position, targetPosition) - entityRadius(targetEntity) <= range
end

-- Legendary effects (Data/Bonuses hooks) ---------------------------------------------------------------

-- Other systems (skill passives) add hook values through providers.
local hookProviders: { (player: Player, id: string) -> number } = {}

function CombatService.RegisterHookProvider(provider: (player: Player, id: string) -> number)
	table.insert(hookProviders, provider)
end

local function hook(player: Player, id: string): number
	local total = EquipmentService.GetHook(player, id)
	for _, provider in hookProviders do
		total += provider(player, id)
	end
	return total
end

CombatService.Hook = hook

-- Hook values from providers only: path nodes and class passives (SkillService.PassiveHook) and the admin /hook,
-- without items. The block's energy (ROZWOJ 10.3) comes with block nodes, not with a shield's Parry.
function CombatService.NodeHook(player: Player, id: string): number
	local total = 0
	for _, provider in hookProviders do
		total += provider(player, id)
	end
	return total
end

-- S72: /hook values per player (admin, see Admin/Combat); a provider like the path nodes.
local adminHooks: { [Player]: { [string]: number } } = {}

function CombatService.SetAdminHook(player: Player, id: string, value: number?)
	local own = adminHooks[player]
	if not own then
		if value == nil then
			return
		end
		own = {}
		adminHooks[player] = own
	end
	local slots: { [string]: number? } = own
	slots[id] = value
	if next(own) == nil then
		adminHooks[player] = nil
	end
end

-- S63: +% damage of the player's damage over time of `kind` (bleed, poison, burn), items and skills alike.
-- One owner of DoT bonuses (the tick amount is set when the effect is applied): S72 added bleedDamage (Deep and Open
-- Wounds, ROZWOJ 10.4) for every bleed of the player, skills and items; S76 poisonDamage (Hunter's Venom, Basilisk
-- Venom, ROZWOJ 11.4) for every poison of the player: skills, items and Biting Arrows' poison field.
function CombatService.DotBonus(player: Player, kind: string): number
	if kind == "bleed" then
		return hook(player, "dotPower") + hook(player, "bleedDamage")
	elseif kind == "poison" then
		return hook(player, "dotPower") + hook(player, "poisonDamage")
	elseif kind == "burn" then
		return hook(player, "dotPower")
	end
	return 0
end

-- S76: every poison of a player (skill, item trait, spread copy) is applied here. tickAmount already holds DotBonus
-- (dotPower + poisonDamage); this adds poisonSlow (Numbing Venom: slowed while poisoned, enemySlow).
function CombatService.ApplyPoison(player: Player, entity: any, options: any): boolean
	local opts = table.clone(options)
	opts.source = player
	local applied = StatusEffectService.Apply(entity, "poison", opts)
	local slow = hook(player, "poisonSlow")
	if applied and slow > 0 then
		StatusEffectService.Apply(entity, "slow", {
			duration = opts.duration,
			value = slow,
			source = player,
			skillId = "poisonSlow",
			category = "enemySlow",
		})
	end
	return applied
end

-- S76 (ROZWOJ 11.4): Contagion (poisonSpread hook + the breakpoint's spread) and Wounded Trail (a vulnerability's
-- jump). `effects` is StatusEffectService.Snapshot of the dead monster, read before it was unregistered; monsters only.
local function spreadOnDeath(dead: any, position: Vector3, effects: { any })
	local t = Workspace:GetServerTimeNow()
	local function candidates(radius: number): { SkillGeom.Candidate }
		local list: { SkillGeom.Candidate } = {}
		for _, entity in EntityService.QueryMonsters(position, radius) do
			local p = EntityService.Position(entity)
			if entity ~= dead and p and entity.monster and entity.monster:IsAlive() then
				table.insert(list, { id = entity.id, x = p.X, z = p.Z })
			end
		end
		return list
	end
	for _, effect in effects do
		local source: Player? = effect.source
		local left = effect.expiresAt - t
		if not source or source.Parent == nil or left <= 0.1 then
			continue
		end
		if effect.kind == "poison" then
			local count = hook(source, "poisonSpread") + (effect.spread or 0)
			if count <= 0 then
				continue
			end
			local radius = SkillData.POISON_SPREAD_RADIUS
			local stacks = math.max(1, effect.stacks or 1)
			local unit = effect.unit or effect.value / stacks
			for _, id in SkillGeom.spreadTargets(position.X, position.Z, candidates(radius), count, radius) do
				local target = EntityService.Get(id)
				if target then
					CombatService.ApplyPoison(source, target, {
						duration = left,
						value = unit,
						tickAmount = if effect.tickAmount then effect.tickAmount / stacks else nil,
						stacks = stacks,
						maxStacks = stacks,
						skillId = effect.skillId,
						category = effect.category,
						spread = effect.spread,
					})
				end
			end
		elseif effect.kind == "vulnerability" and effect.jump and effect.jump > 0 then
			local radius = effect.jump
			local id = SkillGeom.spreadTargets(position.X, position.Z, candidates(radius), 1, radius)[1]
			local target = if id then EntityService.Get(id) else nil
			if target then
				StatusEffectService.Apply(target, "vulnerability", {
					duration = left,
					value = effect.value,
					source = source,
					skillId = effect.skillId,
					category = effect.category,
					jump = effect.jump,
				})
			end
		end
	end
end

-- Living monsters within HOOK_RULES.perEnemy.radius of the player, at most HOOK_RULES.perEnemy.max
-- (ROZWOJ 10.3: Front Line, Menace). Players never count, also in PvP.
local function enemiesNear(player: Player): number
	local entity = EntityService.GetPlayerEntity(player)
	local position = entity and EntityService.Position(entity)
	if not position then
		return 0
	end
	local rules = HOOK_RULES.perEnemy
	local count = 0
	for _, other in EntityService.QueryMonsters(position, rules.radius) do
		if other.monster and other.monster:IsAlive() then
			count += 1
			if count >= rules.max then
				break
			end
		end
	end
	return count
end

local function hpFraction(player: Player): number
	local hp = ResourceService.Get(player)
	local maxHp = math.max(1, StatService.GetValue(player, "maxHp"))
	return hp / maxHp
end

-- S67 (STATY 8): the attacker's vs_<target class> and the target's res_<attacker class>; 1 without both characters.
local function classLineMul(player: Player, target: Player): number
	local mine: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local theirs: Types.CharacterData? = PlayerStateService.GetCharacter(target)
	if not mine or not theirs then
		return 1
	end
	return Damage.classLineMul(
		hook(player, Bonuses.classLine("vs_", theirs.class :: string)),
		hook(target, Bonuses.classLine("res_", mine.class :: string))
	)
end

-- Damage multiplier from the attacker's legendary effects against this target.
local function offensiveMultiplier(player: Player, targetEntity: any): number
	local mult = 1
	local low, pvp = false, false
	if targetEntity.kind == "monster" then
		local monster = targetEntity.monster
		if monster.variant == "elite" or monster.variant == "elite2" then
			mult += hook(player, "eliteDamage") / 100
		elseif monster.variant == "boss" then
			mult += hook(player, "bossDamage") / 100
		end
		-- S67 (STATY 4): vs_<family> lines against monsters of that family (bosses and their adds too), no cap.
		local family = monster.def and monster.def.family
		if family then
			mult += hook(player, Bonuses.familyLine("vs_", family)) / 100
		end
		low = monster.hp / math.max(1, monster.stats.maxHp) < Combat.lowHpFraction
	elseif targetEntity.player then
		low = hpFraction(targetEntity.player) < Combat.lowHpFraction
		pvp = true
	end
	-- S64 (STATY 3, 5): executioner (legends, later the node) + Beheading, capped by Combat.executionerCap.
	if low then
		local traitPvp = if pvp then ItemTraits.pvpByHook.traitExecute else nil
		mult += Traits.executeBonus(hook(player, "executioner"), hook(player, "traitExecute"), traitPvp) / 100
	end
	-- S64: Easy Prey on slowed, rooted, frozen or stunned targets, whoever controlled them.
	local controlled = hook(player, "controlledDamage")
	if controlled > 0 then
		local traitPvp = if pvp then ItemTraits.pvpByHook.controlledDamage else nil
		mult += Traits.controlledBonus(controlled, StatusEffectService.SlowFactor(targetEntity), traitPvp) / 100
	end
	-- S65 (STATY 5): a glowing Runic Seal raises all the player's damage (ticks take dotBase after this).
	local state = attackers[player]
	local seal = state and state.seal
	if seal and seal.lit then
		local value = hook(player, "traitRuneSeal")
		mult += (if pvp then Traits.pvpValue(value, ItemTraits.pvpByHook.traitRuneSeal) else value) / 100
	end
	-- S65 (STATY 3): Frostbite on targets this player's ice slowed or froze.
	local frost = StatusEffectService.SourceValue(targetEntity, "frostbite", player)
	if frost > 0 then
		mult += (if pvp then frost * Combat.pvp.frostbite else frost) / 100
	end
	-- S72 Menace (ROZWOJ 10.3): +damagePerEnemy % per living monster within 10 studs, at most 5.
	local perEnemy = hook(player, "damagePerEnemy")
	if perEnemy > 0 then
		mult += perEnemy * enemiesNear(player) / 100
	end
	-- S72 Fury (ROZWOJ 10.4): +furyDamage % per stack.
	local stacks = StatusEffectService.FuryStacks(player)
	if stacks > 0 then
		local perStack = hook(player, "furyDamage")
		if perStack > 0 then
			mult += stacks * perStack / 100
		end
	end
	return mult
end

-- The defender's "last stand" is an own damage-reduction entry in StatusEffectService since S53 (the provider
-- registered in Init), under the shared multiplicative cap.

-- Kill credit and rewards ----------------------------------------------------------------------------

-- Players who get EXP/gold/loot for a monster (DESIGN §15.1, §17): the top damage dealer, or their party
-- members within PARTY_RANGE of the monster. The top damage dealer comes first.
local PARTY_RANGE = 80

function CombatService.ResolveKillCredit(monster: any): { Player }
	local top = monster:TopDamager()
	if not top then
		return {}
	end
	local credit = { top }
	for _, member in PartyService.MembersInRange(top, monster:Position(), PARTY_RANGE) do
		if member ~= top then
			table.insert(credit, member)
		end
	end
	return credit
end

-- EXP and gold for one credited player; `share` = number of credited players, `goldShare` = their gold (already
-- with the area's gold multiplier); `expMul` = the area profile's EXP multiplier (S33) times the class variety bonus
-- (S60), before the party split; `luckGold` = Fortune's gold % (S60), added to the player's own goldBonus.
local function reward(player: Player, monster: any, share: number, goldShare: number, expMul: number, luckGold: number)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return
	end
	local level = monster.stats.level
	-- S32: tougher kinds pay more EXP and gold (MonsterStats.kindReward); gold also drops for monsters far below.
	local kindReward = MonsterStats.kindReward(monster.def)
	local baseExp = PartyLoot.splitExp(Exp.monsterExp(level, monster.variant) * kindReward * expMul, share)
	local exp = math.floor(baseExp * Exp.levelDiffMultiplier(character.level, level) + 0.5)
	local goldBonus = StatService.GetValue(player, "goldBonus")
	local goldMul = MonsterStats.goldLevelMultiplier(character.level, level)
	local gold = math.floor(goldShare * goldMul * (1 + (goldBonus + luckGold) / 100) + 0.5)
	local expBonus = StatService.GetValue(player, "expBonus")
	LevelService.GiveExp(player, exp, "monster")
	local balance = PlayerStateService.Update(player, { "character", "gold" }, function(current: number)
		return current + gold
	end)
	Analytics.gold(player, gold, balance, "monster")
	-- killHeal: lines, legends and Reaping (S64, the axe's trait); monsters only, so never in PvP.
	local killHeal = hook(player, "killHeal")
	if killHeal > 0 then
		local healed = ResourceService.Heal(player, StatService.GetValue(player, "maxHp") * killHeal / 100)
		local entity = EntityService.GetPlayerEntity(player)
		if healed > 0 and entity then
			queueFx(
				EntityService.Position(entity),
				{ k = "heal", e = entity.id, s = entity.id, a = math.floor(healed) }
			)
		end
	end
	local shownExp = if character.level >= 100 then 0 else math.floor(exp * (1 + expBonus / 100))
	Net.Fire(player, "CombatFx", { { k = "reward", exp = shownExp, gold = gold } })
end

local function onMonsterDied(monster: any)
	-- S76: the dead monster's effects now, before MonsterService unregisters it (the move is deferred: a tick may be
	-- walking the effect table right now)
	local dead = monster.entity
	if dead then
		local effects = StatusEffectService.Snapshot(dead)
		local at = monster:Position()
		if #effects > 0 and at then
			task.defer(spreadOnDeath, dead, at, effects)
		end
	end
	for i = #redZones, 1, -1 do
		if redZones[i].monster == monster then
			table.remove(redZones, i)
		end
	end
	local credit = CombatService.ResolveKillCredit(monster)
	local areaId = monster.model:GetAttribute("AreaId") :: string?
	local luck: Luck.MonsterLuck? = nil
	if not monster.isBoss then
		-- S60: luck of the credited group (best dropBonus + Fortune, one cap) and the class variety bonus.
		local members: { Luck.Member } = {}
		local classes: { string } = {}
		for _, player in credit do
			local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
			table.insert(members, {
				name = if character then character.name else player.Name,
				dropBonus = StatService.GetValue(player, "dropBonus"),
				luck = pathService().GetLuck(player),
			})
			table.insert(classes, if character then character.class else "")
		end
		local groupLuck = Luck.monster(members)
		luck = groupLuck
		local varietyMul = PartyBonus.expMul(classes)
		-- S33: the area profile scales the kill's EXP and gold before the party split (quests are not affected).
		local mods = AreaProfiles.modsOf(areaId)
		-- Boss helpers (2026-10-10) give EXP but no gold.
		local total = if monster.summoned
			then 0
			else math.max(
				1,
				math.floor(
					MonsterStats.gold(monster.stats.level, monster.variant, rng:next())
							* MonsterStats.kindReward(monster.def)
							* mods.goldMul
						+ 0.5
				)
			)
		local shares = PartyLoot.splitGold(total, #credit, rng)
		for i, player in credit do
			reward(player, monster, #credit, shares[i], mods.expMul * varietyMul, groupLuck.gold)
		end
	end
	local position = monster:Position()
	local zone = ZoneService.ZoneAt(position, "city")
	local info: KillInfo = {
		monsterId = monster.def.id,
		variant = monster.variant,
		level = monster.stats.level,
		position = position,
		mapId = zone.map,
		entityId = if monster.entity then monster.entity.id else "",
		boss = monster.isBoss == true,
		noLoot = monster.summoned == true,
		areaId = areaId,
		dropLevel = Loot.dropBaseLevel(monster.stats.level, monster.variant, monster.levelCap),
		luck = luck,
		finisher = monster.killedBy,
	}
	CombatService.MonsterKilled:Fire(info, credit, credit[1])
	-- Clear player targets pointing at the corpse.
	for _, state in attackers do
		if state.target == info.entityId then
			state.target = nil
		end
	end
end

-- Damage pipeline --------------------------------------------------------------------------------------

-- S77 (ROZWOJ 11.5): Spotting. Basic attacks, Aimed Shot and the Royal Falcon's strikes leave a short vulnerability
-- (enemyWeak: the strongest counts, so it fills the gaps between Hunter's Marks). Nothing without the node.
function CombatService.Spot(player: Player, entity: any)
	local value = hook(player, "spotOnHit")
	if value <= 0 then
		return
	end
	value += hook(player, "spotBonus")
	StatusEffectService.Apply(entity, "vulnerability", {
		duration = HOOK_RULES.spot.duration,
		value = value,
		source = player,
		skillId = "scout_spotting",
		category = "enemyWeak",
	})
end

-- Deals damage from a player to an entity with the given params. Returns the Damage.Result or nil when the
-- hit was not allowed. Skills (S05) use this too.
export type DealOptions = {
	-- extra multiplier: skill passives (elementalist, divine wrath) x weapon speed normalisation (S54, Skills.speedFactor)
	multiplier: number?,
	consumeShot: boolean?, -- default true: consumes "nextShot" / "guaranteedCrit"
	skill: string?, -- S28: skill id shown with the damage number (bigger numbers, the name on the first hit)
	noProc: boolean?, -- S63: no on-hit effects: second hits, counters, splashes, arcs, pierce, pulses
	basic: boolean?, -- S63: basic attack: full on-hit chance; S62 basicDmg; S65 rhythm
	area: boolean?, -- S63: area skill hit: chance x Combat.areaProcShare per target
	delivery: ("melee" | "ranged")?, -- S64: kind of blow for the target's melee / ranged protection (PvP)
}

-- On-hit effects of item traits and lines (S63, STATY 5) -----------------------------------------------------

local function maxResourceOf(player: Player): (Types.ResourceId?, number)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local class = character and Classes.get(character.class)
	if not class then
		return nil, 0
	end
	local id = if class.resource == "mana" then "maxMana" else "maxEnergy"
	return class.resource, StatService.GetValue(player, id)
end

-- resourceOnHit (STATY 4, 6): at most Combat.resourceOnHitCap % of the maximum per hit, once per resourceOnHitGap.
-- The legendary manaOnHit stays separate.
local function refundResource(player: Player)
	local pct = hook(player, "resourceOnHit")
	if pct <= 0 then
		return
	end
	local state = attackerState(player)
	local resource, maxResource = maxResourceOf(player)
	local amount = Traits.resourceOnHit(pct, maxResource, state.resourceAt, os.clock())
	if resource and amount > 0 then
		ResourceService.Add(player, resource, amount)
		state.resourceAt = os.clock()
	end
end

-- Rolls `chance` % (no roll at 0).
local function roll(chance: number): boolean
	return chance > 0 and rng:chance(chance / 100)
end

-- Every-hit effects of an area skill still roll the area share.
local function everyHit(share: number): boolean
	return share >= 1 or rng:chance(share)
end

local function applyTraitEffect(
	player: Player,
	target: any,
	entry: ItemTraits.OnHitEntry,
	grown: number,
	line: number,
	share: number,
	hit: number,
	pvp: boolean
)
	local spec = entry.onHit
	local effect = spec.effect
	if effect == "bleed" or effect == "poison" then
		local chance = Traits.chance(if grown > 0 then spec.chance or 0 else 0, line, share)
		if not roll(chance) then
			return
		end
		-- The trait's grown % when the weapon carries it; the line alone gives its own %.
		local pct = if grown > 0 then grown else spec.linePct or 0
		local bonus = CombatService.DotBonus(player, effect)
		-- Wound from the line and from the axe share one key: 3 stacks together.
		local options = {
			duration = spec.duration,
			value = pct,
			source = player,
			tickAmount = Traits.dotTick(hit, pct, spec.duration, bonus),
			maxStacks = spec.maxStacks,
			skillId = EffectStack.ITEM,
			healCut = if pvp and grown > 0 then spec.healCut else nil,
			-- S65 (ROZWOJ 7.2): a refresh adds the unpaid rest, at most maxStacks sums of one hit.
			accumulate = true,
		}
		if effect == "poison" then
			CombatService.ApplyPoison(player, target, options) -- S76: poisonSlow
		else
			StatusEffectService.Apply(target, effect, options)
		end
		if grown > 0 and spec.attackSlow then
			StatusEffectService.Apply(target, "attackSlow", {
				duration = spec.duration,
				value = spec.attackSlow,
				source = player,
				skillId = EffectStack.ITEM,
				category = "enemyAttackSlow",
			})
		end
	elseif effect == "armorBreak" then
		if grown <= 0 or not everyHit(share) then
			return
		end
		StatusEffectService.Apply(target, "armorBreak", {
			duration = spec.duration,
			value = grown,
			source = player,
			maxStacks = if pvp then Combat.pvp.armorBreakStacks else spec.maxStacks,
			skillId = EffectStack.ITEM,
			category = "enemyArmor",
		})
	elseif effect == "weaken" then
		if grown <= 0 or not everyHit(share) then
			return
		end
		StatusEffectService.Apply(target, "weaken", {
			duration = spec.duration,
			value = if pvp then Traits.pvpValue(grown, entry.trait.pvp) else grown,
			source = player,
			skillId = EffectStack.ITEM,
			category = "enemyDamageDown",
		})
	elseif effect == "harass" then
		if not roll(Traits.chance(grown, 0, share)) then
			return
		end
		StatusEffectService.Apply(target, "slow", {
			duration = spec.duration,
			value = spec.slow,
			source = player,
			skillId = EffectStack.ITEM,
			category = "enemySlow",
		})
		StatusEffectService.Apply(target, "attackSlow", {
			duration = spec.duration,
			value = spec.attackSlow,
			source = player,
			skillId = EffectStack.ITEM,
			category = "enemyAttackSlow",
		})
	elseif effect == "shock" then
		local state = attackerState(player)
		local clock = os.clock()
		local gap = spec.gap or 0
		if
			StatusEffectService.IsBossLike(target)
			or not Traits.gapReady(state.shockAt[target.id], clock, gap)
			or not roll(Traits.chance(grown, 0, share))
		then
			return
		end
		local stunned = StatusEffectService.Apply(target, "stun", {
			duration = spec.duration,
			source = player,
			skillId = EffectStack.ITEM,
			notBoss = spec.notBoss,
		})
		if stunned then
			for id, at in state.shockAt do
				if clock - at >= gap then
					state.shockAt[id] = nil
				end
			end
			state.shockAt[target.id] = clock
			if target.kind == "monster" and target.monster then
				target.monster:DelayAttack(spec.duration, spec.delayShare or 0)
			end
		end
	end
end

-- S63 (STATY 5): on-hit effects of item traits and lines; `hit` is the hit before Combat.pvpModifier.
local function applyOnHit(player: Player, target: any, hit: number, options: DealOptions?, pvp: boolean)
	local share = Traits.procShare(options)
	if share <= 0 then
		return
	end
	for _, entry in ItemTraits.onHitList do
		local grown = hook(player, entry.trait.hook :: string) -- trait value x strength, 0 without the weapon
		local line = if entry.onHit.line then hook(player, entry.onHit.line) else 0
		if grown > 0 or line > 0 then
			applyTraitEffect(player, target, entry, grown, line, share, hit, pvp)
		end
	end
	refundResource(player)
end

-- Block and counter (S64) ----------------------------------------------------------------------------------

-- S64 (STATY 3): every block heals blockHeal % max HP (Parry trait, grown with rarity); half vs players. No heal
-- source, like lifesteal and killHeal: no PvP HealScale, not in the fight summary.
local function onBlock(player: Player, entity: any?, pvp: boolean)
	-- ROZWOJ 10.3: Block returns energy; only with block from path nodes (Parry alone gives none)
	if CombatService.NodeHook(player, "block") > 0 then
		ResourceService.Add(player, "energy", HOOK_RULES.blockEnergy)
	end
	local heal = hook(player, "blockHeal")
	if pvp then
		heal = Traits.pvpValue(heal, ItemTraits.pvpByHook.blockHeal)
	end
	if heal <= 0 then
		return
	end
	local healed = ResourceService.Heal(player, StatService.GetValue(player, "maxHp") * heal / 100)
	if healed > 0 and entity then
		queueFx(EntityService.Position(entity), { k = "heal", e = entity.id, s = entity.id, a = math.floor(healed) })
	end
end

-- Defined after DealDamage (it calls it); the PvP branch of DealDamage calls it too.
local tryCounter: (defender: Player, attackerEntity: any, pvp: boolean) -> ()

-- S65 (STATY 5): Saving Blow: `amount` x pct % heals the most wounded ally within the radius (heal multipliers of
-- Context.healFrom), or the bearer like lifesteal: no multipliers, only the room left under the lifesteal cap.
local function savingBlow(player: Player, selfEntity: any, attacker: Damage.Attacker, amount: number, pvp: boolean)
	local value = hook(player, "traitSavingBlow")
	local position = selfEntity and EntityService.Position(selfEntity)
	if value <= 0 or not position then
		return
	end
	local pct = if pvp then Traits.pvpValue(value, ItemTraits.pvpByHook.traitSavingBlow) else value
	local ally = Context.mostWounded(player, position, traitParam("savingBlow", "radius"), nil)
	if not ally then
		return
	end
	if ally ~= player then
		Context.healFrom(player, ally, amount * pct / 100)
		return
	end
	-- The same lifesteal Damage.computeDamage used for this hit (halved against players, S63).
	local lifesteal = (attacker.lifesteal or 0) * (if pvp then Combat.pvp.lifesteal else 1)
	local share = Traits.savingSelfShare(pct, lifesteal)
	local healed = ResourceService.Heal(player, math.floor(amount * share / 100))
	if healed > 0 then
		queueFx(position, { k = "heal", e = selfEntity.id, s = selfEntity.id, a = math.floor(healed) })
	end
end

function CombatService.DealDamage(
	player: Player,
	targetEntity: any,
	baseParams: Damage.Params,
	style: string?,
	options: DealOptions?
): Damage.Result?
	local attacker = playerCombat(player)
	if not attacker then
		return nil
	end
	-- Any attack ends the attacker's respawn protection (S22).
	StatusEffectService.BreakRespawnShield(player)
	local selfEntity = EntityService.GetPlayerEntity(player)
	local params = table.clone(baseParams)
	if options and options.basic then
		params.basic = true -- S62 basicDmg
	end
	local extra = if options and options.multiplier then options.multiplier else 1
	-- One-shot buffs from the Hunter tree.
	if selfEntity and not (options and options.consumeShot == false) then
		if StatusEffectService.Has(selfEntity, "guaranteedCrit") then
			params.forceCrit = true
			StatusEffectService.Remove(selfEntity, "guaranteedCrit")
		end
		local bonus = StatusEffectService.Consume(selfEntity, "nextShot")
		if bonus then
			extra *= 1 + bonus / 100
		end
	end
	-- S77: Draw a Bead, only the caster's hits (ROZWOJ 11.3).
	local sight = StatusEffectService.FromSource(targetEntity, "sighted", player)
	if sight and sight.stats then
		params.critAdd = sight.stats.critChance
		params.critDmgAdd = sight.stats.critDmg
	end
	-- Hunter's Mark and other vulnerabilities on the target.
	extra *= 1 + StatusEffectService.Max(targetEntity, "vulnerability") / 100
	-- S77: Weak Spot. Hits on the selected target build stacks (+1% each, up to the hook); a new target resets them.
	-- Hits on other enemies neither build nor reset; noProc hits (falcon, splash, a pierce's second target) do not count.
	local weakState: Attacker? = nil
	local maxStacks = hook(player, "weakSpot")
	if maxStacks > 0 and not (options and options.noProc) then
		local state = attackerState(player)
		if state.target == targetEntity.id then
			if state.weakTarget ~= targetEntity.id then
				state.weakTarget = targetEntity.id
				state.weakStacks = 0
			end
			extra *= 1 + (state.weakStacks or 0) * HOOK_RULES.weakSpotPerStack / 100
			weakState = state
		end
	end
	local targetPosition = EntityService.Position(targetEntity)
	local result: Damage.Result
	local pvpTarget: Player? = nil -- S64: the target player of the PvP branch (counter)
	local pvpRegular = false

	if targetEntity.kind == "monster" then
		local monster = targetEntity.monster
		if not monster or not monster:IsAlive() then
			return nil
		end
		local defender = MonsterStats.asDefender(monster.stats)
		-- S62: armour break goes to Damage.defenseOf (before pierce). S63: strongest skill + strongest item (<= 50).
		local monsterParams = table.clone(params)
		monsterParams.armorBreak = StatusEffectService.CategoryValue(targetEntity, "enemyArmor")
		-- S66 (STATY 6): monsters dodge only basic attacks (and their second hits and counters, all `basic`).
		monsterParams = Damage.paramsVsMonster(monsterParams, options ~= nil and options.basic == true)
		result = Damage.computeDamage(attacker, defender, monsterParams, rng)
		if not result.dodged then
			result.amount = math.max(1, math.floor(result.amount * offensiveMultiplier(player, targetEntity) * extra))
		end
		local override = attackerState(player).damageOverride
		if override and not result.dodged then
			result.amount = override
		end
		if monster.invulnerable then
			result.amount = 0
		end
		result.dotBase = if result.dodged then 0 else result.amount
		if style and selfEntity then
			local weaponType, element = weaponFx(player)
			queueFx(
				targetPosition,
				{ k = "atk", s = selfEntity.id, t = targetEntity.id, st = style, w = weaponType, el = element }
			)
		end
		-- S29: every resolved hit shows a number; an untouchable boss shows "Immune".
		queueFx(targetPosition, {
			k = "dmg",
			e = targetEntity.id,
			s = if selfEntity then selfEntity.id else nil,
			a = result.amount,
			c = result.crit,
			d = result.dodged,
			im = if monster.invulnerable and not result.dodged then true else nil,
			sk = options and options.skill,
		})
		if result.amount > 0 then
			monster:TakeDamage(result.amount, player)
		end
		if result.dodged and not monster.invulnerable then
			monster:AddThreat(player, 0) -- S66: a dodged hit still starts the fight and pulls the group
		end
	else
		local target = targetEntity.player :: Player
		local allowed = PvpService.CanAttack(player, target)
		if not allowed or not playerAlive(target) then
			return nil
		end
		local _, defender = playerCombat(target)
		if not defender then
			return nil
		end
		pvpTarget = target
		pvpRegular = params.canDodge ~= false
		local pvpParams = table.clone(params)
		pvpParams.pvp = true
		-- S63 (STATY 8): only the item part of armour break counts on players, at most 3 stacks.
		pvpParams.armorBreak = StatusEffectService.PvpArmorBreak(targetEntity)
		if params.canDodge ~= false and selfEntity then
			-- S61: misfortune on the attacking player, category cap first, then the PvP multiplier.
			local miss = math.min(StatusEffectService.Max(selfEntity, "misfortune"), BuffCategories.caps.enemyMiss)
			pvpParams.miss = miss * Combat.pvp.misfortune
		end
		if pvpRegular then
			-- S64 (STATY 8): the target's block, half after blockCap.
			-- path nodes (Block, Shield Master; S75) join this sum through SkillService.PassiveHook (ROZWOJ 10.3)
			pvpParams.block = Traits.blockChance(hook(target, "block"), true)
		end
		result = Damage.computeDamage(attacker, defender, pvpParams, rng)
		if result.blocked then
			onBlock(target, targetEntity, true)
		end
		if not result.dodged then
			-- S63: Bonebreaker on the attacker (from players only) counts in PvP alone; monsters take full hits.
			local weakenMul = 1
				- (if selfEntity then StatusEffectService.CategoryValue(selfEntity, "enemyDamageDown") else 0) / 100
			local mul = offensiveMultiplier(player, targetEntity) * extra * weakenMul
			-- S67 (STATY 8): class lines only here, after CanAttack (on top of the 0.6 of computeDamage). Ticks
			-- take dotBase from before the class lines (S63 keeps them on the bare hit).
			local dotBase = math.max(1, math.floor((result.dotBase or result.amount) * mul))
			result.amount = math.max(1, math.floor(result.amount * mul * classLineMul(player, target)))
			result.dotBase = dotBase
		else
			result.dotBase = 0
		end
		local override = attackerState(player).damageOverride
		if override and not result.dodged then
			result.amount = math.floor(override * Combat.pvpModifier)
			result.dotBase = override
		end
		if style and selfEntity then
			local weaponType, element = weaponFx(player)
			queueFx(
				targetPosition,
				{ k = "atk", s = selfEntity.id, t = targetEntity.id, st = style, w = weaponType, el = element }
			)
		end
		PvpService.MarkPvpCombat(player)
		PvpService.MarkPvpCombat(target)
		PvpService.RecordHit(player, target)
		local taken = 0
		if result.amount > 0 then
			incoming[target] = { delivery = options and options.delivery }
			local _, filtered = ResourceService.Damage(target, result.amount, "pvp", player)
			incoming[target] = nil
			taken = filtered
		end
		-- S29 (changes S22): a hit stopped in full by shields shows "Absorbed", by invulnerability "Immune".
		local event = playerHitEvent(target, targetEntity.id, if selfEntity then selfEntity.id else nil, result, taken)
		event.sk = options and options.skill
		queueFx(targetPosition, event)
	end

	ResourceService.MarkCombat(player)
	if weakState and not result.dodged then
		weakState.weakStacks = math.min(maxStacks, (weakState.weakStacks or 0) + 1)
	end
	-- S77: Spotting from basic attacks and Aimed Shot (HOOK_RULES.spot.skills); the falcon calls Spot itself.
	local skillId = options and options.skill
	if
		not result.dodged
		and result.amount > 0
		and ((options and options.basic) or (skillId and HOOK_RULES.spot.skills[skillId]))
	then
		CombatService.Spot(player, targetEntity)
	end
	-- S72 (ROZWOJ 10.4): every hit that dealt damage feeds Fury (ticks, thorns and Retribution never come here).
	if not result.dodged and result.amount > 0 then
		StatusEffectService.AddFury(player)
	end
	if not result.dodged and result.amount > 0 and not (options and options.noProc) then
		local alive = if targetEntity.kind == "monster"
			then targetEntity.monster ~= nil and targetEntity.monster:IsAlive()
			else targetEntity.player ~= nil and playerAlive(targetEntity.player)
		if alive then
			applyOnHit(player, targetEntity, result.dotBase or result.amount, options, targetEntity.kind == "player")
		end
	end
	local manaOnHit = hook(player, "manaOnHit")
	if manaOnHit > 0 and result.amount > 0 then
		ResourceService.Add(player, "mana", StatService.GetValue(player, "maxMana") * manaOnHit / 100)
	end
	if result.lifesteal > 0 then
		local healed = ResourceService.Heal(player, result.lifesteal)
		if healed > 0 and selfEntity then
			queueFx(
				EntityService.Position(selfEntity),
				{ k = "heal", e = selfEntity.id, s = selfEntity.id, a = math.floor(healed) }
			)
		end
	end
	if not result.dodged and result.amount > 0 and not (options and options.noProc) then
		savingBlow(player, selfEntity, attacker, result.amount, targetEntity.kind == "player")
	end
	-- S64 (STATY 6, 8): a regular PvP hit may be countered (never a counter, second hit or splash: noProc).
	if
		pvpTarget
		and pvpRegular
		and not (options and options.noProc)
		and selfEntity
		and playerAlive(player)
		and playerAlive(pvpTarget)
	then
		tryCounter(pvpTarget, selfEntity, true)
	end
	return result
end

-- S64 (STATY 3, 5): after a regular attack on `defender` (also blocked, missed or dodged; never a red zone):
-- min(riposte, riposteCap) % (x pvp.counter vs players) for an instant basic attack without on-hit effects, in the
-- reach of the defender's weapon and not while stunned or frozen.
tryCounter = function(defender: Player, attackerEntity: any, pvp: boolean)
	if not playerAlive(defender) then
		return
	end
	local chance = Traits.counterChance(hook(defender, "riposte"), pvp)
	if chance <= 0 or not rng:chance(chance / 100) then
		return
	end
	local selfEntity = EntityService.GetPlayerEntity(defender)
	if not selfEntity or StatusEffectService.IsDisabled(selfEntity) then
		return
	end
	local _, ranged, style = basicAttackProfile(defender)
	if not inBasicReach(defender, attackerEntity, ranged) then
		return
	end
	local bonus = hook(defender, "counterDamage")
	if pvp then
		bonus = Traits.pvpValue(bonus, ItemTraits.pvpByHook.counterDamage)
	end
	CombatService.DealDamage(defender, attackerEntity, basicParams(defender), style, {
		consumeShot = false,
		noProc = true,
		basic = true,
		multiplier = 1 + bonus / 100,
		delivery = if ranged then "ranged" else "melee",
	})
end

-- Tells the client why its auto-attack does nothing (at most once per REJECT_INTERVAL).
local function reject(player: Player, state: Attacker, now: number, reason: string)
	if now - state.rejectedAt < REJECT_INTERVAL then
		return
	end
	state.rejectedAt = now
	Net.Fire(player, "AttackRejected", reason)
end

-- True while a monster target lives (players: DealDamage checks them).
local function targetAlive(target: any): boolean
	return target.kind ~= "monster" or (target.monster ~= nil and target.monster:IsAlive())
end

-- Base speed of the main weapon (nil = unarmed), S54 derived stats.
local function weaponSpeed(player: Player): number?
	local weapon = PlayerStateService.Get(player, { "derived", "weapon" })
	return if type(weapon) == "table" and type(weapon.speed) == "number" then weapon.speed else nil
end

-- S65 (STATY 5): Run Through: the nearest enemy in the band behind the target takes value % of the blow as a
-- secondary basic hit (basicDmg counts, no on-hit effects); players only when attackable.
local function runThrough(player: Player, target: any, params: Damage.Params, delivery: "melee" | "ranged")
	local value = hook(player, "traitRunThrough")
	local myRoot = rootOf(player.Character)
	local at = EntityService.Position(target)
	if value <= 0 or not myRoot or not at then
		return
	end
	local width, depth = traitParam("runThrough", "width"), traitParam("runThrough", "depth")
	local radius = entityRadius(target)
	local reach = radius + depth + width
	local victims: { any } = {}
	local spots: { Traits.Spot } = {}
	local function consider(entity: any)
		local p = EntityService.Position(entity)
		if p then
			table.insert(victims, entity)
			table.insert(spots, { x = p.X, z = p.Z })
		end
	end
	for _, entity in EntityService.QueryMonsters(at, reach) do
		if entity ~= target and entity.monster and entity.monster:IsAlive() then
			consider(entity)
		end
	end
	for _, entity in EntityService.QueryPlayers(at, reach) do
		local other = entity.player
		if
			entity ~= target
			and other
			and other ~= player
			and playerAlive(other)
			and PvpService.CanAttack(player, other)
		then
			consider(entity)
		end
	end
	local me = myRoot.Position
	local index = Traits.behind({ x = me.X, z = me.Z }, { x = at.X, z = at.Z }, radius, spots, width, depth)
	if not index then
		return
	end
	local victim = victims[index]
	queueFx(at, { k = "trait", v = "runThrough", s = target.id, t = victim.id })
	CombatService.DealDamage(player, victim, params, nil, {
		basic = true,
		noProc = true,
		consumeShot = false,
		multiplier = value / 100,
		delivery = delivery,
	})
end

-- S65 (STATY 5): Elemental Spark: a chance (capped like on-hit effects) to wake the weapon's element on a basic hit.
local function spark(
	player: Player,
	target: any,
	params: Damage.Params,
	result: Damage.Result,
	delivery: "melee" | "ranged"
)
	local chance = Traits.chance(hook(player, "traitSpark"), 0, 1)
	if not params.element or not roll(chance) then
		return
	end
	Elements.apply(elementServices, {
		player = player,
		element = params.element,
		target = target,
		hit = result.dotBase or result.amount,
		spec = sparkSpec,
		skillId = EffectStack.ITEM,
		accumulate = true,
		players = true,
		jump = function(other: any, pct: number)
			CombatService.DealDamage(player, other, params, nil, {
				basic = true,
				noProc = true,
				consumeShot = false,
				multiplier = pct / 100,
				delivery = delivery,
			})
		end,
		fx = function(from: any, to: any)
			queueFx(EntityService.Position(from), { k = "trait", v = "arc", s = from.id, t = to.id })
		end,
	})
end

-- S65 (STATY 5): Full Draw: an offensive skill or a trap readies the next basic attack (a new skill refreshes it).
function CombatService.PrimeFullDraw(player: Player)
	local value = hook(player, "traitFullDraw")
	local entity = EntityService.GetPlayerEntity(player)
	if value <= 0 or not entity then
		return
	end
	StatusEffectService.Apply(
		entity,
		"nextBasic",
		{ duration = traitParam("fullDraw", "window"), value = value, source = player }
	)
end

-- S65: shows (value) or hides (nil) the glowing seal marker "runeSeal" (icon, rune under the Mage).
local function showSeal(player: Player, value: number?)
	local entity = EntityService.GetPlayerEntity(player)
	if not entity then
		return
	end
	if value then
		StatusEffectService.Apply(entity, "runeSeal", { duration = SEAL_MARKER, value = value, source = player })
	else
		StatusEffectService.Remove(entity, "runeSeal")
	end
end

-- S65: the Runic Seal breaks (blink, knockback / pull, death); any other move beyond the step is caught by pollSeal.
function CombatService.BreakSeal(player: Player)
	local state = attackers[player]
	local seal = state and state.seal
	if not state or not seal then
		return
	end
	state.seal = nil
	if seal.lit then
		showSeal(player, nil)
	end
end

local function pollSeal(player: Player, now: number)
	local value = hook(player, "traitRuneSeal")
	local root = rootOf(player.Character)
	if value <= 0 or not root or not playerAlive(player) then
		CombatService.BreakSeal(player)
		return
	end
	local state = attackerState(player)
	local wasLit = state.seal ~= nil and (state.seal :: Traits.Seal).lit
	local still, step = traitParam("runicSeal", "still"), traitParam("runicSeal", "step")
	local seal = Traits.sealStep(state.seal, root.Position.X, root.Position.Z, now, still, step)
	state.seal = seal
	if seal.lit ~= wasLit then
		showSeal(player, if seal.lit then value else nil)
	elseif seal.lit then
		-- The marker expired (SEAL_MARKER) while the seal stays lit: show it again.
		local entity = EntityService.GetPlayerEntity(player)
		if entity and not StatusEffectService.Has(entity, "runeSeal") then
			showSeal(player, value)
		end
	end
end

local function tryBasicAttack(player: Player, state: Attacker, now: number)
	local targetId = state.target
	if not targetId or not state.attack or now < state.nextAttack or not playerAlive(player) then
		return
	end
	-- S76: no basic attacks while aiming (castTime); Focus / Prayer channels keep them (ROZWOJ 14.3).
	-- S80: nor during a beam (the ray comes from the weapon; a swing would break the channel's animation loop).
	local channel = PlayerStateService.Get(player, { "skills", "channel" })
	if type(channel) == "table" and (channel.kind == "castTime" or channel.kind == "beam") then
		return
	end
	local target = EntityService.Get(targetId)
	if not target then
		state.target = nil
		return
	end
	if target.kind == "monster" and (not target.monster or not target.monster:IsAlive()) then
		state.target = nil
		return
	end
	local myRoot = rootOf(player.Character)
	local targetPosition = EntityService.Position(target)
	if not myRoot or not targetPosition then
		return
	end
	-- No fighting from inside a safe zone, or while stunned / frozen.
	if ZoneService.GetPvpZone(player) == "green" then
		reject(player, state, now, "combat.reject.safeZone")
		return
	end
	local selfEntity = EntityService.GetPlayerEntity(player)
	if selfEntity and StatusEffectService.IsDisabled(selfEntity) then
		reject(player, state, now, "combat.reject.stunned")
		return
	end
	local _, ranged, style = basicAttackProfile(player)
	if not inBasicReach(player, target, ranged) then
		-- Walking into range is normal; only complain when the player stands still out of range.
		local velocity = myRoot.AssemblyLinearVelocity
		if Vector3.new(velocity.X, 0, velocity.Z).Magnitude < 1 then
			state.outOfRangeSince = state.outOfRangeSince or now
			if now - (state.outOfRangeSince :: number) >= TOO_FAR_AFTER then
				reject(player, state, now, "combat.reject.tooFar")
			end
		else
			state.outOfRangeSince = nil
		end
		return
	end
	state.outOfRangeSince = nil
	local speed = math.max(0.2, StatService.GetValue(player, "atkSpeed"))
	state.nextAttack = now + 1 / speed
	local params = basicParams(player)
	local delivery: "melee" | "ranged" = if ranged then "ranged" else "melee"
	-- FIX 2026-10-09: the swing / shot starts now, the damage comes when the blow lands or the projectile
	-- arrives (AttackPose.hitDelay, the same timing the client animates); before, the HP dropped at once.
	local weaponType = weaponFx(player)
	local delay = AttackPose.hitDelay(weaponType, flatDistance(myRoot.Position, targetPosition), ranged)
	if selfEntity then
		local _, weaponElement = weaponFx(player)
		queueFx(
			targetPosition,
			{ k = "atk", s = selfEntity.id, t = target.id, st = style, w = weaponType, el = weaponElement }
		)
	end
	local double = hook(player, "doubleAttack")
	local twice = double > 0 and rng:chance(double / 100)
	-- S65 (STATY 5): Twin Cut counts every basic swing of a saber; the fifth one strikes again.
	local twinValue = hook(player, "traitTwinCut")
	local twin = false
	if twinValue > 0 then
		local every, reset = traitParam("twinCut", "every"), traitParam("twinCut", "reset")
		state.twinCount, twin = Traits.twinCut(state.twinCount or 0, state.twinAt, now, every, reset)
		state.twinAt = now
	end
	task.delay(delay, function()
		if not playerAlive(player) or not targetAlive(target) then
			return
		end
		local options: DealOptions = { basic = true, delivery = delivery }
		-- S65: Full Draw: the shot after an offensive skill, consumed by this attack even when it misses.
		local draw = if selfEntity then StatusEffectService.Consume(selfEntity, "nextBasic") else nil
		if draw and draw > 0 then
			local traitPvp = if target.kind == "player" then ItemTraits.pvpByHook.traitFullDraw else nil
			options.multiplier = 1 + Traits.drawBonus(draw, weaponSpeed(player), traitPvp) / 100
		end
		local result = CombatService.DealDamage(player, target, params, nil, options)
		if twice and targetAlive(target) then
			-- S63: the second hit keeps basicDmg but rolls no on-hit effects.
			CombatService.DealDamage(player, target, params, nil, { basic = true, noProc = true, delivery = delivery })
		end
		if twin and targetAlive(target) then
			-- S65: the extra cut of Twin Cut, also after a dodged main hit.
			CombatService.DealDamage(player, target, params, nil, {
				basic = true,
				noProc = true,
				consumeShot = false,
				multiplier = twinValue / 100,
				delivery = delivery,
			})
		end
		if result and not result.dodged and result.amount > 0 then
			runThrough(player, target, params, delivery)
			spark(player, target, params, result, delivery)
		end
	end)
end

-- Monster -> player ------------------------------------------------------------------------------------

-- `delivery`: kind of blow for melee / ranged protection (S64; nil for red zones).
local function monsterHitsPlayer(
	monster: any,
	player: Player,
	baseParams: Damage.Params,
	style: string?,
	delivery: string?
)
	if not playerAlive(player) then
		return
	end
	local _, defender = playerCombat(player)
	if not defender then
		return
	end
	local regular = baseParams.canDodge ~= false
	local params = table.clone(baseParams)
	if regular then
		if monster.entity then
			-- S61: misfortune on the monster (regular attacks only; red zones come with canDodge = false, never miss).
			params.miss = math.min(StatusEffectService.Max(monster.entity, "misfortune"), BuffCategories.caps.enemyMiss)
		end
		-- S64 (STATY 3, 5): the player's block (shield trait, lines, later nodes), regular blows only.
		-- path nodes (Block, Shield Master; S75) join this sum through SkillService.PassiveHook (ROZWOJ 10.3)
		params.block = Traits.blockChance(hook(player, "block"), false)
	end
	local result = Damage.computeDamage(MonsterStats.asAttacker(monster.stats), defender, params, rng)
	if not result.dodged and monster.entity then
		-- S63 (STATY 6): Bonebreaker on the monster; red zones and bosses come this way too.
		local weaken = StatusEffectService.CategoryValue(monster.entity, "enemyDamageDown")
		if weaken > 0 then
			result.amount = math.max(1, math.floor(result.amount * (1 - weaken / 100)))
		end
	end
	local playerEntity = EntityService.GetPlayerEntity(player)
	local position = EntityService.Position(playerEntity or { model = player.Character } :: any)
	if result.blocked then
		onBlock(player, playerEntity, false)
	end
	if style and monster.entity and playerEntity then
		queueFx(position, { k = "atk", s = monster.entity.id, t = playerEntity.id, st = style })
	end
	-- The number shown is the damage after shields and protection (S22); S29: a hit stopped in full shows
	-- "Absorbed" / "Immune" instead of nothing.
	local taken = 0
	if result.amount > 0 then
		-- S64: melee / ranged protection reads the blow's kind through `incoming` (reduction provider in Init).
		incoming[player] = { delivery = delivery, monster = monster }
		local _, filtered = ResourceService.Damage(player, result.amount, "monster", monster)
		incoming[player] = nil
		taken = filtered
	end
	if playerEntity then
		queueFx(
			position,
			playerHitEvent(player, playerEntity.id, if monster.entity then monster.entity.id else nil, result, taken)
		)
	end
	-- S64 (STATY 6): the counter answers every regular blow, also a blocked, missed or dodged one.
	if regular and monster:IsAlive() and monster.entity then
		tryCounter(player, monster.entity, false)
	end
	if taken > 0 then
		local thorns = hook(player, "thorns")
		if thorns > 0 and monster:IsAlive() then
			local reflected = math.max(1, math.floor(taken * thorns / 100))
			local dealt = monster:TakeDamage(reflected, player)
			if dealt > 0 and monster.entity then
				queueFx(monster:Position(), {
					k = "dmg",
					e = monster.entity.id,
					s = if playerEntity then playerEntity.id else nil,
					a = math.floor(dealt),
					c = false,
					d = false,
				})
			end
		end
	else
		ResourceService.MarkCombat(player)
	end
end

local function monsterBasicAttack(monster: any, player: Player)
	local style = if monster.def.attack == "ranged"
		then (if monster.def.damageKind == "magic" then "bolt" else "arrow")
		else "melee"
	monsterHitsPlayer(
		monster,
		player,
		{ kind = monster.stats.damageKind, element = monster.def.element },
		style,
		monster.def.attack
	)
end

local function insideArea(ability: MonsterAbilities.Ability, area: CFrame, position: Vector3): boolean
	local localPos = area:PointToObjectSpace(position)
	local flatLocal = Vector3.new(localPos.X, 0, localPos.Z)
	if math.abs(localPos.Y) > 12 then
		return false
	end
	if ability.shape == "circle" then
		return flatLocal.Magnitude <= (ability.radius or 8)
	elseif ability.shape == "cone" then
		local radius = ability.radius or 10
		if flatLocal.Magnitude > radius then
			return false
		end
		if flatLocal.Magnitude < 1 then
			return true
		end
		-- Forward is -Z in CFrame.lookAt space.
		local angle = math.deg(math.acos(math.clamp(flatLocal.Unit:Dot(Vector3.new(0, 0, -1)), -1, 1)))
		return angle <= (ability.angle or 90) / 2
	elseif ability.shape == "line" then
		local length, width = ability.length or 15, ability.width or 5
		return localPos.Z <= 0 and localPos.Z >= -length and math.abs(localPos.X) <= width / 2
	elseif ability.shape == "ring" then
		local distance = flatLocal.Magnitude
		return distance <= (ability.radius or 20) and distance > (ability.inner or 5)
	end
	return false
end

-- Red zones (S61, ROZWOJ 14.2): every telegraphed area until it resolves (the cover's target choice S74, vigilance S77
-- read it). A cast that never resolves (boss killed in the windup, Elite II stunned) drops out after its windup plus
-- Combat.redZoneGrace, or when its monster dies.
local function zoneAlive(zone: RedZone, now: number): boolean
	return zone.endsAt >= now and zone.monster ~= nil and zone.monster:IsAlive()
end

-- Drops expired zones and zones of dead monsters.
local function pruneZones()
	local now = os.clock()
	for i = #redZones, 1, -1 do
		if not zoneAlive(redZones[i], now) then
			table.remove(redZones, i)
		end
	end
end

-- S77 (ROZWOJ 11.5, 7.3): Vigilance (vigilanceMove, allyMove) and Warning (vigilanceGuard, allyGuard). A red zone
-- started by a monster within 30 studs of a Scout gives the Scout's party within 40 studs a short bonus for the
-- windup + 0.5 s; each kind has its own trigger, at most once per 8 s per Scout. Monsters only (no PvP zones).
local VIGILANCE = {
	{ hook = "vigilanceMove", key = "move" },
	{ hook = "vigilanceGuard", key = "guard" },
}

local function vigilance(monster: any, ability: MonsterAbilities.Ability)
	local at = if monster.entity then EntityService.Position(monster.entity) else nil
	if not at then
		return
	end
	local rules = HOOK_RULES.vigilance
	local windup = ability.windup or 0
	local duration = Vigilance.duration(windup)
	for _, entity in EntityService.QueryPlayers(at, rules.monsterRange) do
		local scout = entity.player :: Player?
		local position = EntityService.Position(entity)
		if not scout or not position or not playerAlive(scout) then
			continue
		end
		local zone: Vigilance.Zone = {
			windup = windup,
			monsterDistance = Vector3.new(position.X - at.X, 0, position.Z - at.Z).Magnitude,
		}
		local state = attackerState(scout)
		local now = os.clock()
		for _, kind in VIGILANCE do
			local value = hook(scout, kind.hook)
			local times = state.vigilance or {}
			if value <= 0 or not Vigilance.ready(times[kind.key], now, zone) then
				continue
			end
			times[kind.key] = now
			state.vigilance = times
			for _, member in PartyService.MembersInRange(scout, position, rules.partyRange) do
				local target = EntityService.GetPlayerEntity(member)
				if not target then
					continue
				end
				if kind.key == "move" then
					-- moveSpeed has base 0: points, not pct (S53)
					StatusEffectService.Apply(target, "statBuff", {
						duration = duration,
						stats = { moveSpeed = value },
						source = scout,
						skillId = "scout_vigilance",
						category = "allyMove",
					})
				else
					StatusEffectService.Apply(target, "damageReduction", {
						duration = duration,
						value = value,
						source = scout,
						skillId = "scout_warning",
						category = "allyGuard",
					})
				end
			end
		end
	end
end

local function telegraph(monster: any, ability: MonsterAbilities.Ability, area: CFrame)
	table.insert(redZones, {
		monster = monster,
		ability = ability,
		area = area,
		endsAt = os.clock() + ability.windup + Combat.redZoneGrace,
	})
	queueFx(area.Position, {
		k = "tele",
		e = if monster.entity then monster.entity.id else nil,
		sh = ability.shape,
		cf = area,
		r = ability.radius,
		ir = ability.inner,
		an = ability.angle,
		l = ability.length,
		w = ability.width,
		t = ability.windup,
		el = ability.element,
	})
	vigilance(monster, ability)
end

local function resolveAbility(monster: any, ability: MonsterAbilities.Ability, area: CFrame)
	local params: Damage.Params = {
		kind = ability.damageKind or monster.stats.damageKind,
		multiplier = ability.damage,
		element = ability.element,
		canDodge = false, -- telegraphed attacks are dodged by moving out of the area
	}
	local reach = (ability.radius or 0) + (ability.length or 0) + 10
	for _, entity in EntityService.QueryPlayers(area.Position, reach) do
		local player = entity.player :: Player
		local position = EntityService.Position(entity)
		if position and insideArea(ability, area, position) then
			monsterHitsPlayer(monster, player, params, nil, ability.delivery)
		end
	end
	for i, zone in redZones do
		if zone.monster == monster and zone.ability == ability and zone.area == area then
			table.remove(redZones, i)
			break
		end
	end
end

-- Active red zones (a copy).
function CombatService.RedZones(): { RedZone }
	pruneZones()
	return table.clone(redZones)
end

-- The first active red zone that holds `position`, or nil.
function CombatService.InRedZone(position: Vector3): RedZone?
	pruneZones()
	for _, zone in redZones do
		if insideArea(zone.ability, zone.area, position) then
			return zone
		end
	end
	return nil
end

-- Boss attacks (DungeonService): the same telegraph and area damage as Elite II abilities.
function CombatService.MonsterTelegraph(monster: any, ability: MonsterAbilities.Ability, area: CFrame)
	telegraph(monster, ability, area)
end

function CombatService.MonsterResolve(monster: any, ability: MonsterAbilities.Ability, area: CFrame)
	resolveAbility(monster, ability, area)
end

-- Lets skills draw damage numbers / heals / swings with the same batching.
function CombatService.QueueFx(position: Vector3?, event: { [string]: any })
	queueFx(position, event)
end

-- Admin and queries --------------------------------------------------------------------------------------

function CombatService.GetTarget(player: Player): any
	local state = attackers[player]
	return if state and state.target then EntityService.Get(state.target) else nil
end

function CombatService.SetDamageOverride(player: Player, amount: number?)
	attackerState(player).damageOverride = amount
end

-- Remote --------------------------------------------------------------------------------------------------

-- S77: Weak Spot stacks end with the selected target (a new one, none, death).
local function resetWeakSpot(state: Attacker)
	state.weakTarget = nil
	state.weakStacks = 0
end

local function onSetTarget(player: Player, entityId: string?, attack: boolean?)
	local state = attackerState(player)
	if state.target ~= entityId then
		resetWeakSpot(state)
	end
	if entityId == nil then
		state.target = nil
		state.attack = false
		return
	end
	state.attack = attack ~= false
	state.outOfRangeSince = nil
	local entity = EntityService.Get(entityId)
	if not entity or entity.player == player then
		state.target = nil
		return
	end
	-- Ignore targets far away (client sends what it sees; streaming radius is the natural bound).
	local myRoot = rootOf(player.Character)
	local position = EntityService.Position(entity)
	if not myRoot or not position or (position - myRoot.Position).Magnitude > 250 then
		state.target = nil
		return
	end
	if state.target ~= entityId then
		state.target = entityId
		-- Switching targets never makes the next swing come sooner.
		state.nextAttack = math.max(state.nextAttack, os.clock())
	end
end

function CombatService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	EntityService = registry.Get("EntityService")
	MonsterService = registry.Get("MonsterService")
	StatService = registry.Get("StatService")
	ResourceService = registry.Get("ResourceService")
	LevelService = registry.Get("LevelService")
	PvpService = registry.Get("PvpService")
	ZoneService = registry.Get("ZoneService")
	EquipmentService = registry.Get("EquipmentService")
	StatusEffectService = registry.Get("StatusEffectService")
	PartyService = registry.Get("PartyService")
	Registry = registry

	StatusEffectService.SetHookReader(hook)
	-- S72: /hook values (admin) count like path nodes (NodeHook too, so /hook block gives the block's energy).
	CombatService.RegisterHookProvider(function(player: Player, id: string): number
		local own = adminHooks[player]
		return if own then own[id] or 0 else 0
	end)

	-- Own damage-reduction entries for monster blows, PvP hits and intercepted parts (ROZWOJ 7.1, 14.2).
	local OWN_REDUCTION_SOURCES: { [string]: boolean } = { monster = true, pvp = true, intercept = true }
	StatusEffectService.RegisterReductionProvider(function(player: Player, source: string): number
		-- "Last stand" (items, Clenched Teeth from S75) as an own entry under the multiplicative cap (ROZWOJ 7.1);
		-- S72: also on the part a guard intercepts.
		if not OWN_REDUCTION_SOURCES[source] then
			return 0
		end
		local lastStand = hook(player, "lastStand")
		return if lastStand > 0 and hpFraction(player) < Combat.lowHpFraction then lastStand else 0
	end)
	-- S72 Front Line: guardPerEnemy % per living monster within 10 studs, at most 5.
	StatusEffectService.RegisterReductionProvider(function(player: Player, source: string): number
		if not OWN_REDUCTION_SOURCES[source] then
			return 0
		end
		local per = hook(player, "guardPerEnemy")
		return if per > 0 then per * enemiesNear(player) else 0
	end)
	-- S76 Toxicologist (poisonedGuard, ROZWOJ 11.4): less damage from an attacker the player has poisoned (own).
	StatusEffectService.RegisterReductionProvider(function(player: Player, source: string, attacker: any?): number
		local entity = if source == "monster" and attacker
			then attacker.entity
			elseif source == "pvp" and attacker then EntityService.GetPlayerEntity(attacker)
			else nil
		if not entity then
			return 0
		end
		local guard = hook(player, "poisonedGuard")
		return if guard > 0 and StatusEffectService.HasFrom(entity, "poison", player) then guard else 0
	end)
	-- S72 Relentless: furyGuard % while Fury is full.

	StatusEffectService.RegisterReductionProvider(function(player: Player, source: string): number
		if not OWN_REDUCTION_SOURCES[source] then
			return 0
		end
		local guard = hook(player, "furyGuard")
		local max = StatusEffectService.FuryMax(player)
		return if guard > 0 and max > 0 and StatusEffectService.FuryStacks(player) >= max then guard else 0
	end)

	-- S64 (STATY 6): melee / ranged protection is one more own entry of this hit. The hit's facts live in
	-- `incoming` only during ResourceService.Damage; S67 joins family resistance here the same way.
	StatusEffectService.RegisterReductionProvider(function(player: Player, source: string): number
		local hit = incoming[player]
		if not hit or (source ~= "monster" and source ~= "pvp") then
			return 0
		end
		return Damage.guard(
			hit.delivery,
			StatService.GetValue(player, "meleeGuard"),
			StatService.GetValue(player, "rangedGuard")
		)
	end)

	-- S67 (STATY 4, 6, 7): res_<family> lines against the family of the monster of this hit, capped at
	-- Combat.familyResCap; one more own entry under the 75 % damage reduction cap.
	StatusEffectService.RegisterReductionProvider(function(player: Player, source: string): number
		local hit = incoming[player]
		local monster = if source == "monster" and hit then hit.monster else nil
		local family = monster and monster.def and monster.def.family
		if not family then
			return 0
		end
		return (1 - Damage.familyResMul(hook(player, Bonuses.familyLine("res_", family)))) * 100
	end)

	elementServices = {
		StatusEffect = StatusEffectService,
		Entity = EntityService,
		Combat = CombatService,
		Pvp = PvpService,
		Resource = ResourceService,
	}
	-- S65: every knockback and pull breaks the Runic Seal of a moved player.
	Push.OnMoved(function(entity: any)
		if entity.kind == "player" and entity.player then
			CombatService.BreakSeal(entity.player)
		end
	end)

	MonsterService.SetCombatHandlers({
		basicAttack = monsterBasicAttack,
		telegraph = telegraph,
		resolveAbility = resolveAbility,
		died = onMonsterDied,
		-- S72 Menace (ROZWOJ 10.3): the threat hook raises the threat of every damage of the player (not the credit).
		threatMultiplier = function(_monster: any, player: Player): number
			local bonus = hook(player, "threat")
			return if bonus > 0 then 1 + bonus / 100 else 1
		end,
	})
end

function CombatService.Start()
	Net.On("SetTarget", onSetTarget)

	-- Bleed / poison / burn ticks show as small numbers in their element's colour, heal-over-time ticks as
	-- green "+N" (S29). `amount` is what the tick really did (after shields; healed HP).
	StatusEffectService.Ticked:Connect(function(entity, effect, amount: number?)
		local source = effect.source and EntityService.GetPlayerEntity(effect.source)
		local shown = math.floor(if amount then amount else effect.tickAmount or 0)
		local position = EntityService.Position(entity)
		if effect.kind == "hot" then
			if shown > 0 then
				queueFx(position, { k = "heal", e = entity.id, s = source and source.id, a = shown, hot = true })
			end
			return
		end
		local event: FxEvent = {
			k = "dmg",
			e = entity.id,
			s = source and source.id,
			a = shown,
			c = false,
			d = false,
			dot = true,
			el = effect.element or DamageText.dotElement(effect.kind), -- S70: a holy burn shows in light
		}
		if shown <= 0 then
			if entity.kind == "player" and entity.player then
				event[blockedFlag(entity.player)] = true
			elseif entity.kind == "monster" and entity.monster and entity.monster.invulnerable then
				event.im = true
			else
				return
			end
		end
		queueFx(position, event)
	end)

	-- S61: the part of a monster blow a guard took shows over the guard (the target's number is already without it).
	StatusEffectService.Intercepted:Connect(
		function(guard: Player, _target: Player, _moved: number, taken: number, attacker: any?, returned: number?)
			local guardEntity = EntityService.GetPlayerEntity(guard)
			if not guardEntity then
				return
			end
			-- S72 Retribution: the number over the monster that struck, like thorns.
			if returned and returned > 0 and type(attacker) == "table" and attacker.entity then
				queueFx(attacker:Position(), {
					k = "dmg",
					e = attacker.entity.id,
					s = guardEntity.id,
					a = math.floor(returned),
					c = false,
					d = false,
				})
			end
			local monsterEntity = if attacker and type(attacker) == "table" then attacker.entity else nil
			local event: FxEvent = {
				k = "dmg",
				e = guardEntity.id,
				s = if monsterEntity then monsterEntity.id else nil,
				a = math.floor(taken),
				c = false,
				d = false,
			}
			if taken <= 0 then
				event[blockedFlag(guard)] = true
			end
			queueFx(EntityService.Position(guardEntity), event)
		end
	)

	ResourceService.Died:Connect(function(player: Player)
		CombatService.BreakSeal(player)
		local state = attackers[player]
		if state then
			state.target = nil
			resetWeakSpot(state)
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		attackers[player] = nil
		incoming[player] = nil
		adminHooks[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		attackers[player] = nil
		incoming[player] = nil
		adminHooks[player] = nil
	end)

	local sealPolled = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		-- S65: Runic Seal of every player (attacks below still run only for states with a target).
		if now - sealPolled >= SEAL_POLL then
			sealPolled = now
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					pollSeal(player, now)
				end)
				if not ok then
					log:error("seal failed for %s: %s", player.Name, tostring(err))
				end
			end
		end
		for player, state in attackers do
			if state.target then
				local ok, err = pcall(function()
					tryBasicAttack(player, state, now)
				end)
				if not ok then
					log:error("attack failed for %s: %s", player.Name, tostring(err))
				end
			end
		end
		flushFx()
	end)
end

return CombatService
