--!strict
-- Owner 2026-11-10 ("they may block, but no climbing"): every monster model holds its invisible "Blocker" column
-- (Data/BodyGroups, from the root's bottom to at least BLOCK_TOP studs over the feet), and Model:GetBoundingBox counts
-- every part, seen or not, so a wolf's box ran up the whole column: an Elite's cast bar floated far over its name plate,
-- the gather orb hung over its back and grew, and a click in the empty air over it picked it. Whatever measures a
-- monster's body measures its look here instead: the full "Look" MonsterViewController builds inside the model, else
-- its "LookFar" silhouette, else (before either is built) the root extended down to the feet (Data/BodyGroups.bodyBox).
-- A model without a blocker (a player, an NPC, a mount, an AnimLab or mobviz preview) keeps its bounding box. The
-- blocker stays in the model (streamed and removed with it); only the measuring leaves it out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BodyGroups = require(ReplicatedStorage.Shared.Data.BodyGroups)

local MonsterBox = {}

-- The looks MonsterViewController builds in a monster model, the full one first.
local LOOKS = { "Look", "LookFar" }

-- The box of `model`'s body, like Model:GetBoundingBox (its centre frame and size): a monster's look, any other model's
-- bounding box.
function MonsterBox.of(model: Model): (CFrame, Vector3)
	if not model:FindFirstChild(BodyGroups.BLOCKER) then
		return model:GetBoundingBox()
	end
	for _, name in LOOKS do
		local look = model:FindFirstChild(name)
		if look and look:IsA("Model") and look:FindFirstChildWhichIsA("BasePart", true) then
			return look:GetBoundingBox()
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local s = root.Size
		local size, y = BodyGroups.bodyBox({ s.X, s.Y, s.Z }, if humanoid then humanoid.HipHeight else 0)
		return root.CFrame * CFrame.new(0, y, 0), Vector3.new(size[1], size[2], size[3])
	end
	return model:GetBoundingBox()
end

return MonsterBox
