--!strict
-- Studio helper (S52): after File / Home -> Import 3D of the files assets/Weapons/*.glb (all at once), copy this whole
-- file into View -> Command Bar and press Enter (Edit mode, not Play). Every imported model in Workspace whose name
-- is a model of WeaponLooks.assets (e.g. "sword1h_5") gives its MeshPart to ReplicatedStorage.Assets.Weapons.<PACK>,
-- renamed to that model name; the empty import Model is removed. Running it again replaces parts of the same name.
-- Then right-click the <PACK> folder -> Save to File -> assets/Weapons/<PACK>.rbxm (docs/ASSETS.md, "Broń").

local PACK = "Meadows" -- folder (and file) name of this batch of models

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponLooks = (require :: any)(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild(
	"WeaponLooks"
))

local function folder(parent: Instance, name: string): Instance
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

local names: { [string]: boolean } = {}
for _, asset in WeaponLooks.assets do
	names[asset.model] = true
end

local recording = ChangeHistoryService:TryBeginRecording("Vaelthorn: import weapon models")
local pack = folder(folder(folder(ReplicatedStorage, "Assets"), "Weapons"), PACK)
local moved, missing = 0, {}
for _, inst in workspace:GetChildren() do
	if names[inst.Name] then
		local part: BasePart? = if inst:IsA("BasePart")
			then inst
			else (inst:FindFirstChildWhichIsA("MeshPart", true) or inst:FindFirstChildWhichIsA("BasePart", true)) :: any
		if part then
			local old = pack:FindFirstChild(inst.Name)
			if old then
				old:Destroy()
			end
			local name = inst.Name
			part.Anchored = true
			part.Parent = pack
			part.Name = name
			if inst ~= part then
				inst:Destroy()
			end
			moved += 1
		end
	end
end
for name in names do
	if not pack:FindFirstChild(name) then
		table.insert(missing, name)
	end
end
table.sort(missing)
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(`[Vaelthorn] moved {moved} weapon models to ReplicatedStorage.Assets.Weapons.{PACK}`)
if #missing > 0 then
	print(`[Vaelthorn] still without a model ({#missing}): {table.concat(missing, ", ")}`)
end
