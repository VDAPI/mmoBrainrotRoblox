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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Parent.Context)
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

Support.buff = function(ctx)
	ctx.fx({ t = ctx.caster.id, d = ctx.scaled(ctx.skill.duration) })
	ctx.applyEffects(ctx.caster, "self")
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
	-- Marking a monster draws its attention like a hit would.
	if target.kind == "monster" and target.monster then
		target.monster:AddThreat(ctx.player, 1)
	end
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

-- One shield; Shield of Faith 5B cleanses first (S69). S71: x Context.healFactor (healPower, crit).
local function shieldOn(ctx: Ctx, player: Player, entity: any, value: number, duration: number)
	if ctx.bp.cleanse then
		ctx.services.StatusEffect.Cleanse(entity)
	end
	local mul = Context.healFactor(ctx.player, player, true)
	ctx.services.StatusEffect.Apply(entity, "shield", {
		duration = duration,
		value = value * mul,
		source = ctx.player,
		skillId = ctx.skill.id,
		onEnd = burstOnEnd(ctx),
	})
end

Support.shield = function(ctx)
	local player, entity = allyTarget(ctx)
	local duration = ctx.scaled(ctx.skill.duration)
	ctx.fx({ t = entity.id, d = duration })
	shieldOn(ctx, player, entity, ctx.healAmount(player, "shield"), duration)
	local other, otherEntity = second(ctx, player)
	if other and otherEntity then
		ctx.fx({ t = otherEntity.id, d = duration, n = 2 })
		local value = ctx.healAmount(other, "shield") * (ctx.bp.secondTarget or 0) / 100
		shieldOn(ctx, other, otherEntity, value, duration)
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

return Support
