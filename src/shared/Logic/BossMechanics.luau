--!strict
-- Boss mechanics 2.0 (S134, DESIGN §16): big blows to dodge (`avoid`) and the three party mechanics of Data/Bosses
-- (`split`, `mark`, `channel`). Pure: the server (Entities/Boss, CombatService.MonsterResolve) and the balance model
-- (tests/Balance.bossFight) read the same rules. No data requires, no Roblox API.
--
--   split    the blow lands on the area; everyone inside shares it (damage / inside each); nobody inside = every
--            fighter takes `missAll` of the full damage
--   mark     a random fighter is marked for `seconds`; then a circle around the marked one's position at that moment:
--            the others inside take `damage`, the marked one `damage x self` (walk away from the party). S149: `count`
--            fighters at once (without repeats, default 1); each circle blasts on its own, so a marked one standing in
--            another marked one's circle takes its own `self` share and the other's full blow
--   channel  the boss stands and channels for `seconds`; the fighters break it by dealing `breakPct` of its max HP
--            in that time (it is staggered for `stagger` s), otherwise the spell hits every fighter

local BossMechanics = {}

export type SplitSpec = { missAll: number }
export type MarkSpec = { seconds: number, self: number, count: number? }
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

-- S149: how many fighters one mark brands at once (default 1).
function BossMechanics.markCount(spec: MarkSpec): number
	return math.max(1, math.floor(spec.count or 1))
end

-- S149: indexes of the branded fighters among `fighters` (min(count, fighters) of them, without repeats, in the order
-- picked); `roll(lo, hi)` is the caller's random integer (the server's Random, a test's Rng).
function BossMechanics.pickMarked(fighters: number, count: number, roll: (lo: number, hi: number) -> number): { number }
	local pool: { number } = {}
	for i = 1, fighters do
		table.insert(pool, i)
	end
	local out: { number } = {}
	for _ = 1, math.min(math.max(1, count), fighters) do
		table.insert(out, table.remove(pool, roll(1, #pool)) :: number)
	end
	return out
end

-- S149: the damage multiplier one player takes from the blasts of one mark cast: `selfMarked` = the player is branded
-- (its own circle: damage x self), `othersInside` = how many other branded players' circles hold it (full damage each).
function BossMechanics.markTaken(selfMarked: boolean, othersInside: number, damage: number, spec: MarkSpec): number
	local own = if selfMarked then BossMechanics.markDamage(true, damage, spec) else 0
	return own + math.max(0, othersInside) * BossMechanics.markDamage(false, damage, spec)
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
