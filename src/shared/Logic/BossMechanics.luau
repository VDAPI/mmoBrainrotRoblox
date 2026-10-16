--!strict
-- Boss mechanics 2.0 (S134, DESIGN §16): big blows to dodge (`avoid`) and the three party mechanics of Data/Bosses
-- (`split`, `mark`, `channel`). Pure: the server (Entities/Boss, CombatService.MonsterResolve) and the balance model
-- (tests/Balance.bossFight) read the same rules. No data requires, no Roblox API.
--
--   split    the blow lands on the area; everyone inside shares it (damage / inside each); nobody inside = every
--            fighter takes `missAll` of the full damage
--   mark     a random fighter is marked for `seconds`; then a circle around the marked one's position at that moment:
--            the others inside take `damage`, the marked one `damage x self` (walk away from the party)
--   channel  the boss stands and channels for `seconds`; the fighters break it by dealing `breakPct` of its max HP
--            in that time (it is staggered for `stagger` s), otherwise the spell hits every fighter

local BossMechanics = {}

export type SplitSpec = { missAll: number }
export type MarkSpec = { seconds: number, self: number }
export type ChannelSpec = { seconds: number, breakPct: number, stagger: number }
export type Mechanic = "split" | "mark" | "channel"

-- The fields of a Data/Bosses attack this module reads.
export type Attack = {
	avoid: boolean?,
	mechanic: Mechanic?,
	split: SplitSpec?,
	mark: MarkSpec?,
	channel: ChannelSpec?,
}

-- Damage multiplier for each player standing in a `split` area: `total` shared by `inside` players; nobody inside =
-- `total x missAll` for every fighter.
function BossMechanics.splitShare(total: number, inside: number, missAll: number): number
	if inside <= 0 then
		return total * missAll
	end
	return total / inside
end

-- Damage multiplier of a `mark` blast on one player inside it: the marked one takes `damage x self`, the others
-- the whole `damage`.
function BossMechanics.markDamage(isMarked: boolean, damage: number, spec: MarkSpec): number
	return if isMarked then damage * spec.self else damage
end

-- Share of the boss's max HP the fighters took off since the channel began (healing the boss counts against it).
function BossMechanics.channelDone(hpAtStart: number, hpNow: number, maxHp: number): number
	return math.max(0, hpAtStart - hpNow) / math.max(1, maxHp)
end

-- Whether a channel is broken: at least `breakPct` of the max HP taken off since it began.
function BossMechanics.channelBroken(hpAtStart: number, hpNow: number, maxHp: number, breakPct: number): boolean
	return BossMechanics.channelDone(hpAtStart, hpNow, maxHp) >= breakPct
end

-- Seconds a party with `dps` on the boss needs to break a channel of `breakPct` on a boss of `maxHp`.
function BossMechanics.breakSeconds(breakPct: number, maxHp: number, dps: number): number
	return breakPct * maxHp / math.max(1e-9, dps)
end

-- Whether an attack is a big blow to dodge (a mechanic never is: it is played, not dodged).
function BossMechanics.isAvoidable(attack: Attack): boolean
	return attack.avoid == true and attack.mechanic == nil
end

return BossMechanics
