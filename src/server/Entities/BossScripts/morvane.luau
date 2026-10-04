--!strict
-- Morvane, Queen of the Crypts. Data (Data/Bosses): phase 1 shadow bolts at 3 random players and a curse
-- field under the nearest one; phase 2 (70 %) raises two skeleton guards and cannot be hurt while they
-- stand; phase 3 (35 %) a ring of death with a safe centre every 15 s and faster bolts. The script adds the
-- visual of the shield (a ghostly glow while the guards live).

local Morvane = {}

local function setGlow(boss: any, on: boolean)
	local root = boss.monster.root :: BasePart
	local existing = root:FindFirstChild("MorvaneShield")
	if on and not existing then
		local shield = Instance.new("SelectionSphere")
		shield.Name = "MorvaneShield"
		shield.Adornee = root
		shield.Color3 = Color3.fromHex("#9FE0C9")
		shield.SurfaceTransparency = 0.7
		shield.Transparency = 0.4
		shield.Parent = root
	elseif not on and existing then
		existing:Destroy()
	end
end

function Morvane.onPhase(boss: any, phase: number)
	if phase == 2 then
		setGlow(boss, true)
		task.spawn(function()
			while boss.monster:IsAlive() and boss.monster.invulnerable do
				task.wait(0.5)
			end
			setGlow(boss, false)
		end)
	end
end

return Morvane
