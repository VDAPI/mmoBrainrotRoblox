--!strict
-- S143 (DESIGN-18 §6.2): the rules of the Warrior's shield school (Sword and Shield). Pure. Vindicate counts the
-- blocks of the last Data/Skills.BLOCK.window seconds (the server keeps the times per player, CombatService; the
-- block itself comes from Fortitude, the Guardian's Block and Shield Master nodes and the shield's Parry); Shield Sweep
-- hits harder with a shield on the arm. Times are os.clock() seconds; nothing here changes its input.

local Block = {}

-- The block times still inside the window ending at `now` (oldest first) with `now` added: what the server keeps.
function Block.record(times: { number }, now: number, window: number): { number }
	local out: { number } = {}
	for _, t in times do
		if now - t < window then
			table.insert(out, t)
		end
	end
	table.insert(out, now)
	return out
end

-- Blocks inside the window ending at `now`, at most `max`.
function Block.count(times: { number }?, now: number, window: number, max: number): number
	local n = 0
	local list: { number } = times or {}
	for _, t in list do
		if now - t < window and t <= now then
			n += 1
		end
	end
	return math.min(n, max)
end

-- Vindicate's multiplier: +perBlock % for each counted block.
function Block.vindicateMul(count: number, perBlock: number): number
	return 1 + math.max(0, count) * math.max(0, perBlock) / 100
end

-- Is the off-hand a shield (the type from Logic/Paths.weaponTypesOf)?
function Block.hasShield(offhand: string?): boolean
	return offhand == "shield"
end

-- Shield Sweep's multiplier: +pct % with a shield, x1 without.
function Block.shieldMul(hasShield: boolean, pct: number): number
	return if hasShield then 1 + math.max(0, pct) / 100 else 1
end

return table.freeze(Block)
