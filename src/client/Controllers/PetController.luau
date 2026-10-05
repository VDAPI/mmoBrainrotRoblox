--!strict
-- Pets (DESIGN §22): the server spawns anchored pet models in Workspace.VaelthornPets (attribute OwnerId)
-- and never moves them; every client moves every pet locally each frame, so following is smooth for the
-- owner and for everyone else. Flying pets (owl, dragon, wisp) hover higher and bob.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetController = {
	Name = "PetController",
}

local FOLLOW_OFFSET = Vector3.new(2.6, 0, 2.4)
local TELEPORT_DISTANCE = 60
local SPEED = 8 -- lerp factor per second
local FLYERS = { pet_owl = true, pet_dragon = true, pet_wisp = true }

function PetController.Start()
	local folder = Workspace:WaitForChild("VaelthornPets", 60)
	if not folder then
		return
	end
	local clock = 0
	local hops: { [Instance]: number } = {}
	folder.ChildRemoved:Connect(function(pet)
		hops[pet] = nil
	end)
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		for _, pet in folder:GetChildren() do
			if not pet:IsA("Model") then
				continue
			end
			local owner = Players:GetPlayerByUserId(pet:GetAttribute("OwnerId") :: number? or 0)
			local character = owner and owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local petId = pet:GetAttribute("PetId")
			local flying = type(petId) == "string" and FLYERS[petId] == true
			local height = if flying then 2.5 + math.sin(clock * 2.5 + (owner :: Player).UserId) * 0.35 else -2.4
			local goal = root.CFrame * CFrame.new(FOLLOW_OFFSET + Vector3.new(0, height, 0))
			local current = pet:GetPivot()
			if (current.Position - goal.Position).Magnitude > TELEPORT_DISTANCE then
				hops[pet] = nil
				pet:PivotTo(goal)
				continue
			end
			-- The hop drawn last frame is not part of the follow position.
			local base = current.Position - Vector3.new(0, hops[pet] or 0, 0)
			local position = base:Lerp(goal.Position, math.min(1, dt * SPEED))
			-- Walkers hop while catching up (procedural, no animation assets).
			local lag = Vector3.new(goal.Position.X - position.X, 0, goal.Position.Z - position.Z).Magnitude
			local hop = if not flying and lag > 0.4
				then math.abs(math.sin(clock * 11)) * math.min(0.35, lag * 0.2)
				else 0
			hops[pet] = hop
			position += Vector3.new(0, hop, 0)
			local flat = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
			local look = if flat.Magnitude > 0.5
				then CFrame.lookAt(position, position + flat)
				else CFrame.new(position) * current.Rotation
			pet:PivotTo(look)
		end
	end)
end

return PetController
