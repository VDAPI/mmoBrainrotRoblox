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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local AreaProfiles = require(Shared.Data.AreaProfiles)
local Classes = require(Shared.Data.Classes)
local DamageText = require(Shared.Logic.DamageText)
local Combat = require(Shared.Data.Combat)
local Damage = require(Shared.Logic.Damage)
local Exp = require(Shared.Logic.Exp)
local Items = require(Shared.Data.Items)
local Log = require(Shared.Util.Log)
local MonsterAbilities = require(Shared.Data.MonsterAbilities)
local MonsterStats = require(Shared.Logic.MonsterStats)
local Net = require(Shared.Net)
local Loot = require(Shared.Logic.Loot)
local PartyLoot = require(Shared.Logic.PartyLoot)
local Rng = require(Shared.Logic.Rng)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)

local log = Log.new("CombatService")

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
	areaId: string?, -- S27: named area of the monster's group (model attribute AreaId)
	dropLevel: number?, -- S32: base level for item drops (spawner level without the variant's levels)
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

type Attacker = {
	target: string?,
	attack: boolean, -- false: target kept (skills, admin) but no auto-attack (the player walked away)
	nextAttack: number,
	damageOverride: number?,
	rejectedAt: number, -- last AttackRejected sent (rate limit)
	outOfRangeSince: number?, -- standing still out of range since (for the "too far" message)
}

local REJECT_INTERVAL = 2
local TOO_FAR_AFTER = 1

local attackers: { [Player]: Attacker } = {}
local rng = Rng.new()
local fxQueue: { { position: Vector3, event: FxEvent } } = {}

local function attackerState(player: Player): Attacker
	local state = attackers[player]
	if not state then
		state = { target = nil, attack = false, nextAttack = 0, damageOverride = nil, rejectedAt = 0 }
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

local function hpFraction(player: Player): number
	local hp = ResourceService.Get(player)
	local maxHp = math.max(1, StatService.GetValue(player, "maxHp"))
	return hp / maxHp
end

-- Damage multiplier from the attacker's legendary effects against this target.
local function offensiveMultiplier(player: Player, targetEntity: any): number
	local mult = 1
	if targetEntity.kind == "monster" then
		local monster = targetEntity.monster
		if monster.variant == "elite" or monster.variant == "elite2" then
			mult += hook(player, "eliteDamage") / 100
		elseif monster.variant == "boss" then
			mult += hook(player, "bossDamage") / 100
		end
		if monster.hp / math.max(1, monster.stats.maxHp) < 0.3 then
			mult += hook(player, "executioner") / 100
		end
	elseif targetEntity.player and hpFraction(targetEntity.player) < 0.3 then
		mult += hook(player, "executioner") / 100
	end
	return mult
end

-- Damage taken after the defender's "last stand" effect.
local function defensiveAmount(player: Player, amount: number): number
	local lastStand = hook(player, "lastStand")
	if lastStand > 0 and hpFraction(player) < 0.3 then
		return math.max(1, math.floor(amount * (1 - math.min(lastStand, 80) / 100)))
	end
	return amount
end

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
-- with the area's gold multiplier); `expMul` = the area profile's EXP multiplier (S33, before the party split).
local function reward(player: Player, monster: any, share: number, goldShare: number, expMul: number)
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
	local gold = math.floor(goldShare * goldMul * (1 + goldBonus / 100) + 0.5)
	local expBonus = StatService.GetValue(player, "expBonus")
	LevelService.GiveExp(player, exp, "monster")
	local balance = PlayerStateService.Update(player, { "character", "gold" }, function(current: number)
		return current + gold
	end)
	Analytics.gold(player, gold, balance, "monster")
	local killHeal = hook(player, "killHeal")
	if killHeal > 0 then
		ResourceService.Heal(player, StatService.GetValue(player, "maxHp") * killHeal / 100)
	end
	local shownExp = if character.level >= 100 then 0 else math.floor(exp * (1 + expBonus / 100))
	Net.Fire(player, "CombatFx", { { k = "reward", exp = shownExp, gold = gold } })
end

local function onMonsterDied(monster: any)
	local credit = CombatService.ResolveKillCredit(monster)
	local areaId = monster.model:GetAttribute("AreaId") :: string?
	if not monster.isBoss then
		-- S33: the area profile scales the kill's EXP and gold before the party split (quests are not affected).
		local mods = AreaProfiles.modsOf(areaId)
		local total = math.max(
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
			reward(player, monster, #credit, shares[i], mods.expMul)
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
		areaId = areaId,
		dropLevel = Loot.dropBaseLevel(monster.stats.level, monster.variant, monster.levelCap),
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

-- Deals damage from a player to an entity with the given params. Returns the Damage.Result or nil when the
-- hit was not allowed. Skills (S05) use this too.
export type DealOptions = {
	multiplier: number?, -- extra multiplier (skill passives: elementalist, divine wrath)
	consumeShot: boolean?, -- default true: consumes "nextShot" / "guaranteedCrit"
	skill: string?, -- S28: skill id shown with the damage number (bigger numbers, the name on the first hit)
}

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
	-- Hunter's Mark and other vulnerabilities on the target.
	extra *= 1 + StatusEffectService.Max(targetEntity, "vulnerability") / 100
	local targetPosition = EntityService.Position(targetEntity)
	local result: Damage.Result

	if targetEntity.kind == "monster" then
		local monster = targetEntity.monster
		if not monster or not monster:IsAlive() then
			return nil
		end
		local defender = MonsterStats.asDefender(monster.stats)
		local armorBreak = StatusEffectService.Max(targetEntity, "armorBreak")
		if armorBreak > 0 then
			defender.armor *= 1 - math.clamp(armorBreak, 0, 90) / 100
		end
		result = Damage.computeDamage(attacker, defender, params, rng)
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
		local pvpParams = table.clone(params)
		pvpParams.pvp = true
		result = Damage.computeDamage(attacker, defender, pvpParams, rng)
		if not result.dodged then
			local amount = math.floor(result.amount * offensiveMultiplier(player, targetEntity) * extra)
			result.amount = defensiveAmount(target, math.max(1, amount))
		end
		local override = attackerState(player).damageOverride
		if override and not result.dodged then
			result.amount = math.floor(override * Combat.pvpModifier)
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
			local _, filtered = ResourceService.Damage(target, result.amount, "pvp")
			taken = filtered
		end
		-- S29 (changes S22): a hit stopped in full by shields shows "Absorbed", by invulnerability "Immune".
		local event = playerHitEvent(target, targetEntity.id, if selfEntity then selfEntity.id else nil, result, taken)
		event.sk = options and options.skill
		queueFx(targetPosition, event)
	end

	ResourceService.MarkCombat(player)
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
	return result
end

-- Tells the client why its auto-attack does nothing (at most once per REJECT_INTERVAL).
local function reject(player: Player, state: Attacker, now: number, reason: string)
	if now - state.rejectedAt < REJECT_INTERVAL then
		return
	end
	state.rejectedAt = now
	Net.Fire(player, "AttackRejected", reason)
end

local function tryBasicAttack(player: Player, state: Attacker, now: number)
	local targetId = state.target
	if not targetId or not state.attack or now < state.nextAttack or not playerAlive(player) then
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
	local kind, ranged, style = basicAttackProfile(player)
	local range = (if ranged then Combat.rangedRange else Combat.meleeRange) + Combat.rangeTolerance
	if flatDistance(myRoot.Position, targetPosition) - entityRadius(target) > range then
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
	-- Mage weapons hit with their element (S18).
	local derived = PlayerStateService.Get(player, { "derived" })
	local element = if derived and derived.weapon then derived.weapon.element else nil
	local params: Damage.Params = { kind = if kind == "magic" then "magic" else "phys", element = element }
	CombatService.DealDamage(player, target, params, style)
	local double = hook(player, "doubleAttack")
	if double > 0 and rng:chance(double / 100) then
		if target.kind ~= "monster" or (target.monster and target.monster:IsAlive()) then
			CombatService.DealDamage(player, target, params, style)
		end
	end
end

-- Monster -> player ------------------------------------------------------------------------------------

local function monsterHitsPlayer(monster: any, player: Player, params: Damage.Params, style: string?)
	if not playerAlive(player) then
		return
	end
	local _, defender = playerCombat(player)
	if not defender then
		return
	end
	local result = Damage.computeDamage(MonsterStats.asAttacker(monster.stats), defender, params, rng)
	if not result.dodged then
		result.amount = defensiveAmount(player, result.amount)
	end
	local playerEntity = EntityService.GetPlayerEntity(player)
	local position = EntityService.Position(playerEntity or { model = player.Character } :: any)
	if style and monster.entity and playerEntity then
		queueFx(position, { k = "atk", s = monster.entity.id, t = playerEntity.id, st = style })
	end
	-- The number shown is the damage after shields and protection (S22); S29: a hit stopped in full shows
	-- "Absorbed" / "Immune" instead of nothing.
	local taken = 0
	if result.amount > 0 then
		local _, filtered = ResourceService.Damage(player, result.amount, "monster")
		taken = filtered
	end
	if playerEntity then
		queueFx(
			position,
			playerHitEvent(player, playerEntity.id, if monster.entity then monster.entity.id else nil, result, taken)
		)
	end
	if taken > 0 then
		local riposte = hook(player, "riposte")
		if riposte > 0 and monster:IsAlive() and monster.entity and rng:chance(riposte / 100) then
			CombatService.DealDamage(player, monster.entity, { kind = "phys" }, "melee", { consumeShot = false })
		end
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
	monsterHitsPlayer(monster, player, { kind = monster.stats.damageKind, element = monster.def.element }, style)
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

local function telegraph(monster: any, ability: MonsterAbilities.Ability, area: CFrame)
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
			monsterHitsPlayer(monster, player, params, nil)
		end
	end
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

local function onSetTarget(player: Player, entityId: string?, attack: boolean?)
	local state = attackerState(player)
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

	MonsterService.SetCombatHandlers({
		basicAttack = monsterBasicAttack,
		telegraph = telegraph,
		resolveAbility = resolveAbility,
		died = onMonsterDied,
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
			el = DamageText.dotElement(effect.kind),
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

	ResourceService.Died:Connect(function(player: Player)
		local state = attackers[player]
		if state then
			state.target = nil
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		attackers[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		attackers[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
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
