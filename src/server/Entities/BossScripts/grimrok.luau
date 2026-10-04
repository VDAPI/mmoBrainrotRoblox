--!strict
-- Grimrok, Goblin Warchief (DESIGN §16). The data drives the fight (Data/Bosses): phase 1 sweep (cone) and
-- leap on a random player; phase 2 (70 %) summons 4 goblins every 20 s; phase 3 (35 %) whirlwind around
-- himself (run!) and +25 % speed. The script only adds the war cry at phase changes.

local Grimrok = {}

function Grimrok.onPhase(boss: any, phase: number)
	if phase == 3 then
		-- Red war paint: the model glows while he whirls.
		for _, part in boss.monster.model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Crown" then
				part.Color = part.Color:Lerp(Color3.fromHex("#D64A3E"), 0.35)
			end
		end
	end
end

return Grimrok
