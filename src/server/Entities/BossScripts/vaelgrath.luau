--!strict
-- Vaelgrath, the Frost Dragon (boss 100). Data (Data/Bosses): frost breath (cone), wing buffet around
-- itself, tail swipe (line); phase 2 (70 %) blizzard bolts at everyone and dragonspawn; phase 3 (35 %)
-- glacial ring. The script adds:
--   * phase 2: the dragon takes to the air for 12 s (cannot be hit, raised above the arena) while bolts fall,
--   * phase 3: a freezing storm — every 3 s everyone farther than 9 studs from a brazier is frozen.
-- Brazier positions match World/Layouts/dungeon_frostpeak (relative to the arena centre at 0, -10).

local Vaelgrath = {}

local BRAZIERS = { Vector3.new(-32, 0, -22), Vector3.new(32, 0, -22), Vector3.new(-32, 0, 38), Vector3.new(32, 0, 38) }
local WARM_RADIUS = 9
local STORM_TICK = 3
local FLIGHT_SECONDS = 12

local function warm(boss: any, position: Vector3): boolean
	local centre = boss.centre.Position
	for _, offset in BRAZIERS do
		local brazier = centre + offset
		if (Vector3.new(position.X, 0, position.Z) - Vector3.new(brazier.X, 0, brazier.Z)).Magnitude <= WARM_RADIUS then
			return true
		end
	end
	return false
end

function Vaelgrath.onPhase(boss: any, phase: number)
	local monster = boss.monster
	if phase == 2 then
		monster.invulnerable = true
		monster.model:SetAttribute("Flying", true)
		local humanoid = monster.humanoid :: Humanoid
		local hip = humanoid.HipHeight
		humanoid.HipHeight = hip + 14
		task.delay(FLIGHT_SECONDS, function()
			if monster:IsAlive() then
				humanoid.HipHeight = hip
				monster.model:SetAttribute("Flying", nil)
				-- Shield summons (none for Vaelgrath) would keep it invulnerable; flying ends it.
				monster.invulnerable = false
				boss.services.announce("boss.vaelgrath.landed", nil)
			end
		end)
	elseif phase == 3 then
		boss.storm = { nextTick = os.clock() + STORM_TICK }
	end
end

function Vaelgrath.onTick(boss: any, now: number)
	local storm = boss.storm
	if not storm or now < storm.nextTick then
		return
	end
	storm.nextTick = now + STORM_TICK
	for _, player in boss.services.fighters() do
		local position = boss.services.position(player)
		if position and not warm(boss, position) then
			boss:Hazard({
				id = "freezingStorm",
				shape = "circle",
				origin = "self",
				radius = 2,
				windup = 0,
				damage = 1.4,
				cooldown = STORM_TICK,
				element = "ice",
				damageKind = "magic",
			}, CFrame.new(position - Vector3.new(0, 3, 0)))
		end
	end
end

return Vaelgrath
