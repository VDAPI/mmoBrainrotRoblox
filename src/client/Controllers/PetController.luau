--!strict
-- Pets (DESIGN §22): the server spawns anchored pet models in Workspace.VaelthornPets (attribute OwnerId)
-- and never moves them; every client moves every pet locally each frame, so following is smooth for the
-- owner and for everyone else. Flying pets (attribute Flies, from Data/Cosmetics) hover higher and bob.
-- S24: pets are anchored Anatomy looks (Util/CosmeticLook.buildPet); parts with a Role attribute move by CFrame
-- around their Pivot: "flap" wings beat, "orbit" sparks circle, "tail" wags. PetLift keeps walkers on the
-- ground.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetController = {
	Name = "PetController",
}

local FOLLOW_OFFSET = Vector3.new(2.6, 0, 2.4)
local TELEPORT_DISTANCE = 60
local SPEED = 8 -- lerp factor per second
local ANIMATED = { flap = true, orbit = true, tail = true }

type Moving = { part: BasePart, rest: CFrame, pivot: Vector3, role: string, side: number, phase: number, amp: number }

function PetController.Start()
	local folder = Workspace:WaitForChild("VaelthornPets", 60)
	if not folder then
		return
	end
	local clock = 0
	local hops: { [Instance]: number } = {}
	-- Rest offsets of the animated parts from the pet's pivot, captured before the first frame.
	local moving: { [Instance]: { Moving } } = {}
	folder.ChildRemoved:Connect(function(pet)
		hops[pet] = nil
		moving[pet] = nil
	end)
	local function movingOf(pet: Model): { Moving }
		local list = moving[pet]
		if list then
			return list
		end
		local found: { Moving } = {}
		local pivot = pet:GetPivot()
		for _, part in pet:GetDescendants() do
			local role = part:GetAttribute("Role")
			if part:IsA("BasePart") and type(role) == "string" and ANIMATED[role] then
				local at = part:GetAttribute("Pivot")
				table.insert(found, {
					part = part,
					rest = pivot:ToObjectSpace(part.CFrame),
					pivot = if typeof(at) == "Vector3" then at else pivot:PointToObjectSpace(part.Position),
					role = role,
					side = (part:GetAttribute("Side") :: number?) or 0,
					phase = (part:GetAttribute("Phase") :: number?) or 0,
					amp = (part:GetAttribute("Amp") :: number?) or 1,
				})
			end
		end
		moving[pet] = found
		return found
	end
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
			local flying = pet:GetAttribute("Flies") == true
			local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
			local ground = root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 2)
			local lift = pet:GetAttribute("PetLift")
			local height = if flying
				then 2.5 + math.sin(clock * 2.5 + (owner :: Player).UserId) * 0.35
				else -ground + (if type(lift) == "number" then lift else 0.6)
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
			local parts = movingOf(pet)
			pet:PivotTo(look)
			for _, m in parts do
				local turn: CFrame
				if m.role == "flap" then
					turn = CFrame.Angles(0, 0, m.side * math.sin(clock * 9 + m.phase * math.pi * 2) * 0.5 * m.amp)
				elseif m.role == "orbit" then
					turn = CFrame.Angles(0, (clock * 1.2 * m.amp) % (math.pi * 2), 0)
				else
					turn = CFrame.Angles(0, math.sin(clock * 5 + m.phase * math.pi * 2) * 0.35 * m.amp, 0)
				end
				m.part.CFrame = look * CFrame.new(m.pivot) * turn * CFrame.new(-m.pivot) * m.rest
			end
		end
	end)
end

return PetController
