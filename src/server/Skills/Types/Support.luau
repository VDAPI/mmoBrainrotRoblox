--!strict
-- Support skill types: buff, debuff, heal (Purify also cleanses), hot, shield, resurrect, groupBuff,
-- groupHeal. Channel skills (Evocation, Prayer) are handled by SkillService because they span time and can
-- be interrupted. Healing and buffs only affect the caster and party members (PartyService).
-- S28 breakpoints: a second wounded ally (secondTarget), overheal into a shield, cleanse, extra effects on allies.

local Context = require(script.Parent.Parent.Context)

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
	local healed = ctx.heal(player, amount)
	if ctx.bp.overhealShield then
		local bonus = ctx.services.PassiveHook(ctx.player, "healBonus")
		local overflow = amount * (1 + bonus / 100) - healed
		if overflow > 1 then
			ctx.services.StatusEffect.Apply(entity, "shield", { duration = 8, value = overflow, source = ctx.player })
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

Support.heal = function(ctx)
	local player, entity = allyTarget(ctx)
	ctx.fx({ t = entity.id })
	local amount = ctx.magAtk() * ctx.value("heal") / 100
	healOne(ctx, player, entity, amount)
	local other, otherEntity = second(ctx, player)
	if other and otherEntity then
		ctx.fx({ t = otherEntity.id, n = 2 })
		healOne(ctx, other, otherEntity, amount * (ctx.bp.secondTarget or 0) / 100)
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
	})
end

Support.hot = function(ctx)
	local player, entity = allyTarget(ctx)
	local duration = ctx.scaled(ctx.skill.duration)
	local bonus = ctx.services.PassiveHook(ctx.player, "healBonus")
	local total = ctx.magAtk() * ctx.value("heal") / 100 * (1 + bonus / 100)
	ctx.fx({ t = entity.id, d = duration })
	hotOn(ctx, entity, total, duration)
	local other, otherEntity = second(ctx, player)
	if other and otherEntity then
		ctx.fx({ t = otherEntity.id, d = duration, n = 2 })
		hotOn(ctx, otherEntity, total * (ctx.bp.secondTarget or 0) / 100, duration)
	end
	return true, nil
end

Support.shield = function(ctx)
	local player, entity = allyTarget(ctx)
	local duration = ctx.scaled(ctx.skill.duration)
	local value = ctx.magAtk() * ctx.value("shield") / 100
	ctx.fx({ t = entity.id, d = duration })
	ctx.services.StatusEffect.Apply(entity, "shield", { duration = duration, value = value, source = ctx.player })
	local other, otherEntity = second(ctx, player)
	if other and otherEntity then
		ctx.fx({ t = otherEntity.id, d = duration, n = 2 })
		ctx.services.StatusEffect.Apply(otherEntity, "shield", {
			duration = duration,
			value = value * (ctx.bp.secondTarget or 0) / 100,
			source = ctx.player,
		})
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
				local extra = ctx.bp.allyEffect
				if extra then
					task.defer(function()
						local revived = Entity.GetPlayerEntity(member)
						if revived then
							ctx.applyEffect(revived, extra)
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
			ctx.applyEffects(entity, "allies")
			if ctx.bp.allyEffect then
				ctx.applyEffect(entity, ctx.bp.allyEffect)
			end
		end
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

Support.groupHeal = function(ctx)
	local radius = ctx.skill.radius or 14
	ctx.fx({ p = ctx.root.Position, r = radius })
	local amount = ctx.magAtk() * ctx.value("heal") / 100
	for _, ally in ctx.alliesInCircle(ctx.root.Position, radius) do
		ctx.heal(ally, amount)
		local entity = ctx.services.Entity.GetPlayerEntity(ally)
		if entity then
			if ctx.bp.cleanse then
				ctx.services.StatusEffect.Cleanse(entity)
			end
			if ctx.bp.allyEffect then
				ctx.applyEffect(entity, ctx.bp.allyEffect)
			end
		end
	end
	return true, nil
end

return Support
