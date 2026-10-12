--!strict
-- War Banner objects (ROZWOJ 10.5, 14.2): one replicated model per banner in Workspace.Vaelthorn_Banners. The model
-- is an invisible anchor with attributes; clients draw the pole, the cloth and the circle (VfxController,
-- Vfx/Library.banner). Lifetime belongs to the PartyAuraService zone (expiry, death, leaving, a new banner).

local Workspace = game:GetService("Workspace")

local Banner = {}

local FOLDER = "Vaelthorn_Banners"

function Banner.folder(): Folder
	local existing = Workspace:FindFirstChild(FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = Workspace
	return folder
end

-- A banner of `owner` standing at `at` (a point on the ground). Attributes: Owner (UserId), SkillId, Radius, EndsAt
-- (server time).
function Banner.spawn(owner: Player, skillId: string, at: Vector3, radius: number, duration: number): Model
	local model = Instance.new("Model")
	model.Name = `Banner_{owner.UserId}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the anchor arrives with the model
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.new(0.4, 0.4, 0.4)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false -- Charge's clearPath and clicks pass through
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = model
	model.PrimaryPart = anchor
	model:SetAttribute("Owner", owner.UserId)
	model:SetAttribute("SkillId", skillId)
	model:SetAttribute("Radius", radius)
	model:SetAttribute("EndsAt", Workspace:GetServerTimeNow() + duration)
	model.Parent = Banner.folder()
	return model
end

-- Removes a banner; nil and an already removed model are fine.
function Banner.remove(model: Model?)
	if model and model.Parent ~= nil then
		model:Destroy()
	end
end

return Banner
