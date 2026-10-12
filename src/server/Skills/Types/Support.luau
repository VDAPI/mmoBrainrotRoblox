--!strict
-- Support skill types: buff, debuff, heal (Purify also cleanses), hot, shield, resurrect, groupBuff,
-- groupHeal. Channel skills (Evocation, Prayer) are handled by SkillService because they span time and can
-- be interrupted. Healing and buffs only affect the caster and party members (PartyService).
-- S28 breakpoints: a second wounded ally (secondTarget), overheal into a shield, cleanse, extra effects on allies
-- (skill.allyEffects, S55).
-- S69 (ROZWOJ 7.5, 9.2): heals and shields from each target's own max HP plus a magic part (ctx.healAmount, per
-- target); the heal jumps to more wounded allies (chainHeal), Circle of Light leaves a healing field (healZone),
-- the shield and groupBuff cleanse too.
-- S70 (ROZWOJ 9.3–9.5): Sanctuary is the healZone type (a field at a point); groupBuff rolls Fortune's dice
-- (skill.roll, ctx.rollDice); Purify 5B bursts light around the healed ally (burst).
-- S71: heals over time and shields take Context.healFactor (heal bonuses, healPower, the healCrit roll) per target;
-- Shattering Shield (shieldBurst) heals allies around the bearer when the shield breaks or expires.
-- S73 (ROZWOJ 7.3, 14.2): buff spends Fury first (furyConsume), gives its party copies (allyEffects, effects on
-- "allies", allyHeal, allyShield) to allies within Skills.allyRadius, the caster included (allyPass), and behindEffect
-- to allies behind the caster at the cast (Paths.inAura "behind", PartyAuraService.BehindAnchor); shields go through
-- ctx.shield.
-- S74 (ROZWOJ 10.3, 10.5, 14.2): shout works around the caster: allies within radius (the caster too; never an
-- intercept on the caster), enemies within hitRadius (damage only with values.dmg), cleanse and pull breakpoints.
-- S77 (ROZWOJ 11.5): companion is the Falcon (Skills/Companion); Hunter's Mark sends a Royal Falcon diving.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companion = require(script.Parent.Parent.Companion)
local Context = require(script.Parent.Parent.Context)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)

local NO_EFFECTS: { SkillData.SkillEffect } = {}

type Ctx = Context.Ctx
type Handler = (ctx: Ctx) -> (boolean, string?)

local Support: { [string]: Handler } = {}

local RANGE_TOLERANCE = 6

-- The ally to help: the selected player when allied and within the skill's range, otherwise the caster.
local function allyTarget(ctx: Ctx): (Player, any)
	local target = ctx.target
	if
		target
		and target.kind == "player"
		and target.player
		and ctx.services.Party.AreAllies(ctx.player, target.player)
	then
		local model = target.player.Character
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local range = (ctx.skill :: any).range or 30
		if root and (root.Position - ctx.root.Position).Magnitude <= range + RANGE_TOLERANCE then
			return target.player, target
		end
	end
	return ctx.player, ctx.caster
end

-- S73: the buff's party copies on every living ally within Skills.allyRadius, the caster included (solo: the caster
-- alone, like groupBuff). The copy on the caster has its own ally category and adds to its own effect (ROZWOJ 7.2).
-- Returns the entity ids of the allies other than the caster (fx `al`).
local function allyPass(ctx: Ctx): { string }
	local ids: { string } = {}
	if not Skills.hasAllyPass(ctx.skill, ctx.bp) then
		return ids
	end
	local Entity = ctx.services.Entity
	local allyEffects: { SkillData.SkillEffect } = ctx.skill.allyEffects or NO_EFFECTS
	local heal, shield = ctx.bp.allyHeal, ctx.bp.allyShield
	for _, ally in ctx.alliesInCircle(ctx.root.Position, Skills.allyRadius(ctx.skill)) do
		local entity = Entity.GetPlayerEntity(ally)
		if not entity then
			continue
		end
		ctx.applyEffects(entity, "allies")
		for _, effect in allyEffects do
			ctx.applyEffect(entity, effect)
		end
		local maxHp = ctx.services.Stat.GetValue(ally, "maxHp")
		if heal then
			ctx.heal(ally, maxHp * ctx.resolve(heal.hpPct) / 100)
		end
		if shield then
			ctx.shield(entity, maxHp * ctx.resolve(shield.hpPct) / 100, shield.duration)
		end
		if ally ~= ctx.player then
			table.insert(ids, entity.id)
		end
	end
	return ids
end

local function flatOf(position: Vector3): Paths.Flat
	return { x = position.X, z = position.Z }
end

-- S73 behindEffect (Party Bastion, S75): allies other than the caster standing behind it at the cast, the same
-- geometry as a "behind" aura (S61). Without a monster as the anchor nobody gets it.
local function behind(ctx: Ctx)
	local effect = ctx.bp.behindEffect
	if not effect then
		return
	end
	local Entity = ctx.services.Entity
	local threat, monsters = ctx.services.PartyAura.BehindAnchor(ctx.player)
	if threat == nil and #monsters == 0 then
		return
	end
	local owner = flatOf(ctx.root.Position)
	for _, ally in ctx.alliesInCircle(ctx.root.Position, PathData.AURA.behindRadius) do
		local entity = if ally ~= ctx.player then Entity.GetPlayerEntity(ally) else nil
		local at = entity and Entity.Position(entity)
		if entity and at and Paths.inAura({ shape = "behind" }, owner, flatOf(at), threat, monsters) then
			ctx.applyEffect(entity, effect)
		end
	end
end

Support.buff = function(ctx)
	if ctx.skill.furyConsume then
		ctx.consumeFury() -- before the effects: Carnage's stats read the stacks (S74)
	end
	ctx.applyEffects(ctx.caster, "self")
	local allies = allyPass(ctx)
	behind(ctx)
	ctx.fx({ t = ctx.caster.id, d = ctx.scaled(ctx.skill.duration), al = if #allies > 0 then allies else nil })
	-- Camouflage: monsters forget the hunter.
	if ctx.skill.id == "camouflage" then
		for _, entity in ctx.services.Entity.QueryMonsters(ctx.root.Position, 120) do
			local monster = entity.monster
			if monster and monster.threat[ctx.player] then
				monster.threat[ctx.player] = nil
			end
		end
	end
	return true, nil
end

Support.debuff = function(ctx)
	local target = ctx.target
	if not target then
		return false, "cast.error.noTarget"
	end
	ctx.fx({ t = target.id })
	ctx.applyEffects(target, "enemy")
	-- S76 (Hunter's Mark 5B, add.radius): the enemy effects also land on enemies within the radius of the target
	local radius = ctx.skill.radius or 0
	local at = if radius > 0 then ctx.services.Entity.Position(target) else nil
	if at then
		for _, other in ctx.enemiesInCircle(at, radius) do
			if other ~= target then
				ctx.applyEffects(other, "enemy")
			end
		end
		ctx.fx({ v = "splash", p = at, r = radius })
	end
	-- S77: Royal Falcon dives on the marked target (ROZWOJ 11.5); nothing without an active falcon and the keystone.
	if ctx.skill.id == "huntersMark" then
		Companion.dive(ctx.player, target)
	end

	-- Marking a monster draws its attention like a hit would.
	if target.kind == "monster" and target.monster then
		target.monster:AddThreat(ctx.player, 1)
	end
	return true, nil
end

-- companion (S77, ROZWOJ 11.5 / 14.3): the Falcon. Not a character: a damage loop on the server (Skills/Companion)
-- and a bird drawn by the clients. It cannot be hit, has no HP and draws no attention by itself.
Support.companion = function(ctx)
	Companion.start(ctx)
	return true, nil
end

-- Heals one target; with the breakpoint the overflow becomes an absorb shield.
local function healOne(ctx: Ctx, player: Player, entity: any, amount: number)
	if ctx.skill.id == "purify" or ctx.bp.cleanse then
		ctx.services.StatusEffect.Cleanse(entity)
	end
	local healed, attempted = ctx.heal(player, amount)
	if ctx.bp.overhealShield then
		-- S61: from the amount after the PvP scale, so the cut part never turns into a shield.
		local overflow = attempted - healed
		if overflow > 1 then
			-- not ctx.shield: the overflow already carries the heal bonuses (S71)
			ctx.services.StatusEffect.Apply(
				entity,
				"shield",
				{ duration = 8, value = overflow, source = ctx.player, skillId = ctx.skill.id }
			)
		end
	end
end

-- The breakpoint's second target: the most wounded other party member in range (nil when none).
local function second(ctx: Ctx, first: Player): (Player?, any)
	if not ctx.bp.secondTarget then
		return nil, nil
	end
	local range = (ctx.skill :: any).range or 30
	local other = ctx.wounded(ctx.root.Position, range + RANGE_TOLERANCE, first)
	if not other then
		return nil, nil
	end
	return other, ctx.services.Entity.GetPlayerEntity(other)
end

-- S69 (Heal 10B): the heal jumps to more wounded allies in range, each once per cast.
local function chainHeal(ctx: Ctx, chain: { jumps: number, pct: number }, healed: { [Player]: boolean })
	local range = (ctx.skill :: any).range or 30
	local pool: { Player }, fractions: { number } = {}, {}
	for _, ally in ctx.alliesInCircle(ctx.root.Position, range + RANGE_TOLERANCE) do
		if not healed[ally] then
			local maxHp = ctx.services.Stat.GetValue(ally, "maxHp")
			table.insert(pool, ally)
			table.insert(fractions, if maxHp > 0 then ctx.services.Resource.Get(ally) / maxHp else 1)
		end
	end
	for k, index in Skills.chainOrder(fractions, chain.jumps) do
		local ally = pool[index]
		local entity = ctx.services.Entity.GetPlayerEntity(ally)
		if entity then
			ctx.fx({ t = entity.id, n = k + 1 })
			healOne(ctx, ally, entity, ctx.healAmount(ally, "heal") * Skills.chainShare(chain.pct, k))
		end
	end
end

Support.heal = function(ctx)
	local player, entity = allyTarget(ctx)
	ctx.fx({ t = entity.id })
	healOne(ctx, player, entity, ctx.healAmount(player, "heal"))
	local healed: { [Player]: boolean } = { [player] = true }
	local other, otherEntity = second(ctx, player)
	if other and otherEntity then
		ctx.fx({ t = otherEntity.id, n = 2 })
		healOne(ctx, other, otherEntity, ctx.healAmount(other, "heal") * (ctx.bp.secondTarget or 0) / 100)
		healed[other] = true
	end
	-- S70 (Purify 5B): light bursts around the healed ally and hurts enemies near them (first target only).
	local burst = ctx.bp.burst
	if burst then
		local at = ctx.services.Entity.Position(entity)
		if at then
			ctx.fx({ v = "splash", p = at, r = burst.radius })
			for _, enemy in ctx.enemiesInCircle(at, burst.radius) do
				ctx.damage(enemy, burst.pct, { plain = true, consumeShot = false, holy = true })
			end
		end
	end
	local chain = ctx.bp.chainHeal
	if chain then
		chainHeal(ctx, chain, healed)
	end
	return true, nil
end

local function hotOn(ctx: Ctx, entity: any, total: number, duration: number)
	if ctx.bp.cleanse then
		ctx.services.StatusEffect.Cleanse(entity)
	end
	ctx.services.StatusEffect.Apply(entity, "hot", {
		duration = duration,
		source = ctx.player,
		tickAmount = total / math.max(1, duration),
		skillId = ctx.skill.id,
	})
end

Support.hot = function(ctx)
	local player, entity = allyTarget(ctx)
	local duration = ctx.scaled(ctx.skill.duration)
	ctx.fx({ t = entity.id, d = duration })
	-- the sum at the cast: heal bonuses, healPower and one crit roll per target (S71)
	local mul = Context.healFactor(ctx.player, player, false)
	hotOn(ctx, entity, ctx.healAmount(player, "heal") * mul, duration)
	local other, otherEntity = second(ctx, player)
	if other and otherEntity then
		ctx.fx({ t = otherEntity.id, d = duration, n = 2 })
		local otherMul = Context.healFactor(ctx.player, other, false)
		hotOn(ctx, otherEntity, ctx.healAmount(other, "heal") * otherMul * (ctx.bp.secondTarget or 0) / 100, duration)
	end
	return true, nil
end

-- S71 Shattering Shield (shieldBurst): when the shield breaks or expires, allies within the radius of the bearer (the
-- bearer too) heal values.shieldBurst % of its starting value through the caster's heal. StatusEffectService calls
-- it once per shield, never on a refresh, cleanse, clear or the bearer's death; the caster must still be in game.
local function burstOnEnd(ctx: Ctx): ((bearer: any, initial: number) -> ())?
	local burst = ctx.bp.shieldBurst
	if not burst then
		return nil
	end
	local share = ctx.value("shieldBurst")
	return function(bearer: any, initial: number)
		if ctx.player.Parent == nil or share <= 0 or initial <= 0 then
			return
		end
		local at = ctx.services.Entity.Position(bearer)
		if not at then
			return
		end
		ctx.fx({ v = "splash", p = at, r = burst.radius })
		for _, ally in ctx.alliesInCircle(at, burst.radius) do
			ctx.heal(ally, initial * share / 100)
		end
	end
end

-- One shield; Shield of Faith 5B cleanses first (S69). S71: x Context.healFactor (healPower, crit), S73: through
-- ctx.shield.
local function shieldOn(ctx: Ctx, entity: any, value: number, duration: number)
	if ctx.bp.cleanse then
		ctx.services.StatusEffect.Cleanse(entity)
	end
	ctx.shield(entity, value, duration, { onEnd = burstOnEnd(ctx) })
end

Support.shield = function(ctx)
	local player, entity = allyTarget(ctx)
	local duration = ctx.scaled(ctx.skill.duration)
	ctx.fx({ t = entity.id, d = duration })
	shieldOn(ctx, entity, ctx.healAmount(player, "shield"), duration)
	local other, otherEntity = second(ctx, player)
	if other and otherEntity then
		ctx.fx({ t = otherEntity.id, d = duration, n = 2 })
		local value = ctx.healAmount(other, "shield") * (ctx.bp.secondTarget or 0) / 100
		shieldOn(ctx, otherEntity, value, duration)
	end
	return true, nil
end

Support.resurrect = function(ctx)
	local Entity = ctx.services.Entity
	local range = ctx.skill.range or 30
	-- A dead party member close to the caster (the selected one first).
	local candidates: { Player } = {}
	local target = ctx.target
	if target and target.kind == "player" and target.player then
		table.insert(candidates, target.player)
	end
	for _, member in ctx.services.Party.Members(ctx.player) do
		table.insert(candidates, member)
	end
	for _, member in candidates do
		if
			member ~= ctx.player
			and ctx.services.Party.AreAllies(ctx.player, member)
			and ctx.services.Resource.IsDead(member)
		then
			local entity = Entity.GetPlayerEntity(member)
			local position = entity and Entity.Position(entity)
			if position and (position - ctx.root.Position).Magnitude <= range + 4 then
				ctx.fx({ t = entity.id })
				ctx.services.Death.Revive(member, ctx.value("hp"))
				-- S28 breakpoint: the revived ally is protected for a moment.
				local extras = ctx.skill.allyEffects
				if extras then
					task.defer(function()
						local revived = Entity.GetPlayerEntity(member)
						if revived then
							for _, effect in extras do
								ctx.applyEffect(revived, effect)
							end
						end
					end)
				end
				return true, nil
			end
		end
	end
	return false, "cast.error.noDeadAlly"
end

Support.groupBuff = function(ctx)
	local radius = ctx.skill.radius or 30
	local allies = ctx.alliesInCircle(ctx.root.Position, radius)
	ctx.fx({ p = ctx.root.Position, r = radius })
	local Entity = ctx.services.Entity
	for _, ally in allies do
		local entity = Entity.GetPlayerEntity(ally)
		if entity then
			-- S69 (Divine Intervention 5B): cleanse before the effects land
			if ctx.bp.cleanse then
				ctx.services.StatusEffect.Cleanse(entity)
			end
			ctx.applyEffects(entity, "allies")
			for _, effect in ctx.skill.allyEffects or NO_EFFECTS do
				ctx.applyEffect(entity, effect)
			end
		end
	end
	-- Own effects of the skill stay on the caster alone (S53; the party copy above is a separate entry).
	ctx.applyEffects(ctx.caster, "self")
	-- S70: Roll of the Dice and Wheel of Fortune
	if ctx.skill.roll then
		ctx.rollDice()
	end
	-- Divine Intervention also heals a share of maximum health.
	if ctx.skill.id == "divineIntervention" then
		for _, ally in allies do
			local maxHp = ctx.services.Stat.GetValue(ally, "maxHp")
			ctx.heal(ally, maxHp * ctx.value("heal") / 100)
		end
	end
	return true, nil
end

-- S70 Sanctuary (ROZWOJ 9.3): a consecrated circle at the point. Every second allies inside heal their own
-- heal of this skill (ctx.healZone, share 100) and get the allyEffects (Sanctuary 10B: damage reduction,
-- refreshed each tick). Cleanse (5B) once, when the field is placed.
Support.healZone = function(ctx)
	local center = ctx.ground(ctx.point or ctx.root.Position)
	local radius = ctx.skill.radius or 10
	local duration = ctx.scaled(ctx.skill.duration)
	ctx.fx({ p = center, r = radius, d = duration })
	if ctx.bp.cleanse then
		for _, ally in ctx.alliesInCircle(center, radius) do
			local entity = ctx.services.Entity.GetPlayerEntity(ally)
			if entity then
				ctx.services.StatusEffect.Cleanse(entity)
			end
		end
	end
	local extras = ctx.skill.allyEffects
	local onTick = if extras and #extras > 0
		then function(_ally: Player, entity: any)
			for _, effect in extras do
				ctx.applyEffect(entity, effect)
			end
		end
		else nil
	ctx.healZone(center, radius, duration, 100, onTick)
	return true, nil
end

Support.groupHeal = function(ctx)
	local radius = ctx.skill.radius or 14
	ctx.fx({ p = ctx.root.Position, r = radius })
	for _, ally in ctx.alliesInCircle(ctx.root.Position, radius) do
		ctx.heal(ally, ctx.healAmount(ally, "heal"))
		local entity = ctx.services.Entity.GetPlayerEntity(ally)
		if entity then
			if ctx.bp.cleanse then
				ctx.services.StatusEffect.Cleanse(entity)
			end
			for _, effect in ctx.skill.allyEffects or NO_EFFECTS do
				ctx.applyEffect(entity, effect)
			end
		end
	end
	-- S69 (Circle of Light 10B): a healing field stays where the circle was cast
	local zone = ctx.bp.healZone
	if zone then
		ctx.healZone(ctx.root.Position, radius, zone.duration, zone.pct)
	end
	return true, nil
end

-- S74 shout (Shield Wall, Order to Advance): pull (5B), allies' cleanse and effects, the caster's own effects, then
-- the enemies within hitRadius: damage with values.dmg, the enemy effects on a hit (without damage: on everyone, the
-- taunt of Shield Wall works on bosses too). selfEffect and selfHeal come from SkillService after the handler.
Support.shout = function(ctx)
	local center = ctx.root.Position
	local radius = ctx.skill.radius or 15
	local hitRadius = ctx.skill.hitRadius or radius
	local Entity = ctx.services.Entity
	ctx.pull(center) -- S76: the one pull (Skills/Context)
	local allyEffects: { SkillData.SkillEffect } = ctx.skill.allyEffects or NO_EFFECTS
	local effects: { SkillData.SkillEffect } = ctx.skill.effects or NO_EFFECTS
	local shown = 0
	local ids: { string } = {}
	for _, ally in ctx.alliesInCircle(center, radius) do
		local entity = Entity.GetPlayerEntity(ally)
		if not entity then
			continue
		end
		local isCaster = ally == ctx.player
		if ctx.bp.cleanse then
			ctx.services.StatusEffect.Cleanse(entity)
		end
		for _, effect in effects do
			-- intercepting oneself means nothing (S61's filter skips it too) and the icon would mislead
			if Skills.effectSide(ctx.skill, effect) == "allies" and not (isCaster and effect.kind == "intercept") then
				ctx.applyEffect(entity, effect)
				shown = math.max(shown, ctx.scaled(effect.duration))
			end
		end
		for _, effect in allyEffects do
			ctx.applyEffect(entity, effect)
			shown = math.max(shown, ctx.scaled(effect.duration))
		end
		if not isCaster then
			table.insert(ids, entity.id)
		end
	end
	ctx.applyEffects(ctx.caster, "self")
	for _, effect in effects do
		if Skills.effectSide(ctx.skill, effect) == "self" then
			shown = math.max(shown, ctx.scaled(effect.duration))
		end
	end
	local hasDamage = ctx.skill.values.dmg ~= nil
	for _, entity in ctx.enemiesInCircle(center, hitRadius) do
		if hasDamage then
			local result = ctx.damage(entity, ctx.value("dmg"), { from = center })
			if result and not result.dodged then
				ctx.applyEffects(entity, "enemy")
			end
		else
			ctx.applyEffects(entity, "enemy")
		end
	end
	ctx.fx({
		p = center,
		r = hitRadius,
		d = if shown > 0 then shown else ctx.scaled(ctx.skill.duration),
		al = if #ids > 0 then ids else nil,
	})
	return true, nil
end

return Support
