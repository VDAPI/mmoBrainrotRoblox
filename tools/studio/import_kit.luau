--!strict
-- Studio helper (W02): builds ReplicatedStorage.Assets.Kit (the asset kit of Data/Kit) from the Creator Store
-- packs listed below. Copy this whole file into View -> Command Bar and press Enter (Edit mode, not Play); it loads
-- each pack once (game:GetObjects), copies the listed pieces under the kit names (`<folder>_<prefab>_<nr>` in
-- Assets.Kit.<folder>) and drops the rest. Running it again replaces models of the same name. Then save the place
-- (or right-click each Assets.Kit folder -> Save to File -> assets/Kit/<folder>.rbxm). Sources and licences:
-- docs/ASSETS.md "Zestaw (W02)". Scripts inside a pack are never copied.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type Pick = { name: string, path: { string }?, index: number? }
type Pack = { id: number, picks: { Pick } }

-- `path`: child names from the pack's root object; `index`: the n-th MeshPart among the pack's descendants (packs
-- whose pieces all share one name).
local PACKS: { Pack } = {
	{
		id = 79689531752352, -- Yasu's Stylized Tree Pack (mvyasu)
		picks = (function()
			local list: { Pick } = {}
			for _, n in { 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16, 19 } do
				local id = string.format("%02d", n)
				table.insert(list, { name = `grass_tree_{id}`, path = { "Models_Trees", "Models", `Tree_{id}` } })
			end
			for n = 1, 3 do
				table.insert(list, { name = `grass_bush_0{n}`, path = { "Models_Bushes", "Models", `Bush_0{n}` } })
			end
			return list
		end)(),
	},
	{
		id = 139056934028989, -- Stylized Rock Pack (nizendo)
		picks = {
			{ name = "common_rock_01", index = 2 },
			{ name = "common_rock_02", index = 3 },
			{ name = "common_rock_03", index = 4 },
			{ name = "common_rock_04", index = 6 },
			{ name = "common_rock_05", index = 7 },
			{ name = "common_rock_06", index = 15 },
		},
	},
}

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

local function find(root: Instance, pick: Pick): Instance?
	if pick.path then
		local at: Instance? = root
		for _, step in pick.path do
			at = at and at:FindFirstChild(step)
		end
		return at
	end
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("MeshPart") then
			n += 1
			if n == pick.index then
				return d
			end
		end
	end
	return nil
end

local recording = ChangeHistoryService:TryBeginRecording("Vaelthorn: import the asset kit")
local kit = folder(folder(ReplicatedStorage, "Assets"), "Kit")
local made, missing = 0, {}
for _, pack in PACKS do
	local objects = (game :: any):GetObjects(`rbxassetid://{pack.id}`)
	local root = Instance.new("Folder")
	for _, o in objects do
		o.Parent = root
	end
	for _, pick in pack.picks do
		local source = find(root, pick)
		if not source then
			table.insert(missing, pick.name)
			continue
		end
		local model: Model
		if source:IsA("Model") then
			model = source:Clone()
		else
			model = Instance.new("Model")
			source:Clone().Parent = model
		end
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		model.Name = pick.name
		local target = folder(kit, (string.split(pick.name, "_"))[1])
		local old = target:FindFirstChild(pick.name)
		if old then
			old:Destroy()
		end
		model.Parent = target
		made += 1
	end
	root:Destroy()
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(`[import_kit] {made} models in ReplicatedStorage.Assets.Kit; missing: {table.concat(missing, ", ")}`)
