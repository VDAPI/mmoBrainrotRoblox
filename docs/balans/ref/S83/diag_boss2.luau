--!strict
-- Boss sustained damage with the real attack cadence (Entities/Boss.Step) and potions, current data vs the
-- proposal of tools/diag_proposals (2a), and the scripted hazards (BossScripts azgor lava, vaelgrath storm).
local B = require("../tests/Balance")
local Bosses = require("../src/shared/Data/Bosses")
local BossScaling = require("../src/shared/Logic/BossScaling")
local Combat = require("../src/shared/Data/Combat")
local Config = require("../src/shared/Config")
local FightSim = require("../src/shared/Logic/FightSim")
local Items = require("../src/shared/Data/Items")

local function pct(v: number): string
	return string.format("%d%%", math.floor(v * 100 + 0.5))
end
local function f1(v: number): string
	return string.format("%.1f", v)
end
local function row(cells: { string })
	print("| " .. table.concat(cells, " | ") .. " |")
end

local GLOBAL_GAP = 2.2
local function cadence(def: any, phase: number): ({ [string]: number }, number)
	local next, counts = {}, {}
	for _, a in def.attacks do
		next[a.id] = 5
		counts[a.id] = 0
	end
	local global, t, T, casting = 4, 0, 1200, 0
	while t < T do
		if t >= global then
			for _, a in def.attacks do
				if table.find(a.phases, phase) and t >= next[a.id] then
					next[a.id] = t + a.cooldown
					global = t + a.windup + GLOBAL_GAP
					counts[a.id] += 1
					casting += a.windup
					break
				end
			end
		end
		t += 0.05
	end
	local out = {}
	for id, n in counts do
		out[id] = n / (T / 60)
	end
	return out, casting / T
end

local function bossStats(def: any, n: number): any
	return B.monster({
		hpMul = BossScaling.hpMultiplier(n) * (def.hpMul or 1),
		atkMul = def.atkMul,
		defMul = def.defMul,
		speed = def.speed,
		attack = def.attack,
		damageKind = def.damageKind,
	}, def.level, "boss")
end

-- Proposal 2a (tools/diag_proposals): atkMul, attack multipliers, hpMul; Azgor's inferno moved first.
local PROPOSAL: { [string]: any } = {
	morvane = { hpMul = 1.76, atkMul = 0.35, attacks = { shadowBolt = 3.6, shadowBoltFast = 3.8, curseField = 4.8, deathRing = 7 } },
	azgor = { hpMul = 2.16, atkMul = 0.34, attacks = { fireWave = 5.3, flameCleave = 4.9, meteor = 5.7, inferno = 7.5 }, first = "inferno" },
	vaelgrath = { hpMul = 2.68, atkMul = 0.38, attacks = { frostBreath = 5.1, wingBuffet = 4.3, tailSwipe = 4.7, blizzard = 5.1, glacialRing = 7 } },
}

local function proposed(def: any): any
	local p = PROPOSAL[def.id]
	if not p then
		return def
	end
	local out = table.clone(def)
	out.hpMul = p.hpMul
	out.atkMul = p.atkMul
	out.attacks = {}
	for _, a in def.attacks do
		local c = table.clone(a)
		c.damage = p.attacks[a.id] or a.damage
		if p.first == a.id then
			table.insert(out.attacks, 1, c)
		else
			table.insert(out.attacks, c)
		end
	end
	return out
end

local GREAT = (Items.get("potion_hp_4") :: any)
local MIGHTY = (Items.get("potion_hp_5") :: any)

local function sustained(def: any, title: string)
	print(title)
	print("")
	row({ "boss", "phase", "casting share", "tank HP/min", "tank Great potions/min", "Mage HP/min (4 pl.)", "Mage biggest cast hit", "fight min (4 pl., L-1)", "tank potions per fight", "potion gold per fight (tank)" })
	row({ "---", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:", "--:" })
	for _, d in Bosses.list do
		local def = if def then def(d) else d
		local L = math.min(100, def.level)
		local tank, mage = B.player("Warrior", L), B.player("Mage", L)
		local m = bossStats(def, 4)
		local team = { B.player("Warrior", def.level - 1), B.player("Mage", def.level - 1), B.player("Hunter", def.level - 1), B.player("Cleric", def.level - 1) }
		local dps = 0
		for _, p in team do
			dps += B.dps(p, m) * B.BOSS_UPTIME
		end
		local fightMin = m.maxHp / dps / 60
		local totalPotions = 0
		for phase = 1, 3 do
			local cad, casting = cadence(def, phase)
			local haste = if phase == 3 then ((def.haste or {})[3] or 1) else 1
			local tankMin = FightSim.hit(m, tank, 1, def.damageKind) * 60 / m.attackInterval * haste * (1 - casting)
			local mageMin, biggest = 0, 0
			for _, a in def.attacks do
				local uses = cad[a.id] or 0
				if uses > 0 then
					local kind = a.damageKind or def.damageKind
					if a.target == "threat" then
						tankMin += FightSim.hit(m, tank, a.damage, kind, false) * B.SPECIAL_HIT * uses
					end
					local share = if a.target == "all" then 1 elseif a.target == "random" then math.min(1, (a.count or 1) / 4) else 0
					mageMin += FightSim.hit(m, mage, a.damage, kind, false) * B.SPECIAL_HIT * share * uses
					biggest = math.max(biggest, FightSim.hit(m, mage, a.damage, kind, false) * Combat.randomMax / mage.values.maxHp)
				end
			end
			-- phases by HP: 30 % / 35 % / 35 % of the fight
			local share = if phase == 1 then 0.3 else 0.35
			local potions = tankMin / GREAT.use.amount
			totalPotions += potions * fightMin * share
			row({
				def.id,
				tostring(phase),
				pct(casting),
				pct(tankMin / tank.values.maxHp),
				f1(potions),
				pct(mageMin / mage.values.maxHp),
				pct(biggest),
				f1(fightMin),
				"",
				"",
			})
		end
		row({ def.id, "all", "", "", "", "", "", f1(fightMin), f1(totalPotions), tostring(math.floor(totalPotions * GREAT.buyPrice + 0.5)) })
	end
	print("")
end

print(`Potions: Great {GREAT.use.amount} HP for {GREAT.buyPrice} gold, Mighty {MIGHTY.use.amount} HP for {MIGHTY.buyPrice}; Config.PotionCooldown = {Config.PotionCooldown} s (per kind).`)
print("")
sustained(nil :: any, "## Current data")
sustained(proposed, "## Proposal 2a (current base curve)")

print("## Scripted hazards (current data), per tick on a Mage of the boss level")
print("")
row({ "boss", "hazard", "x attack", "every s", "Mage HP per tick", "Mage HP per tick (proposal atkMul)" })
row({ "---", "--:", "--:", "--:", "--:", "--:" })
for _, spec in { { "azgor", "lava (ph3, outside the shrinking safe circle)", 0.7, 1 }, { "vaelgrath", "freezing storm (ph3, > 9 studs from a brazier)", 1.4, 3 } } do
	local def = Bosses.byId[spec[1]] :: any
	local mage = B.player("Mage", math.min(100, def.level))
	local m = bossStats(def, 4)
	local mp = bossStats(proposed(def), 4)
	local v = FightSim.hit(m, mage, spec[3] :: number, "magic", false) / mage.values.maxHp
	local vp = FightSim.hit(mp, mage, spec[3] :: number, "magic", false) / mage.values.maxHp
	row({ def.id, spec[2] :: string, tostring(spec[3]), tostring(spec[4]), pct(v), pct(vp) })
end
print("")
