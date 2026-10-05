--!strict
-- Tracks the monster area under the player (S20, DESIGN §3.6) for the area banner and the minimap.
-- Hysteresis: an area is left only 10 studs outside its rectangle, and the same area's banner shows at most
-- once every 20 s, so walking along a border does not spam.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local AreaState = require(script.Parent.Parent.UI.AreaState)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local State = require(script.Parent.Parent.UI.State)

local AreaController = {
	Name = "AreaController",
}

local HYSTERESIS = 10
local BANNER_COOLDOWN = 20
local INTERVAL = 0.3

local lastBanner: { [string]: number } = {}
local token = 0

local function inside(area: Areas.Area, x: number, z: number, margin: number): boolean
	local r = area.rect
	return x >= r[1] - margin and x <= r[3] + margin and z >= r[2] - margin and z <= r[4] + margin
end

local function step()
	local mapId = State.Get({ "character", "location", "map" })
	local map = type(mapId) == "string" and Maps.get(mapId) or nil
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not map or not root or State.Get({ "session", "phase" }) ~= "playing" then
		if Fusion.peek(AreaState.Current) ~= nil then
			AreaState.Current:set(nil)
		end
		return
	end
	local x, z = root.Position.X - map.offset.x, root.Position.Z - map.offset.z
	local current = Fusion.peek(AreaState.Current)
	if current and (not Areas.byMap[map.id] or not inside(current, x, z, HYSTERESIS)) then
		current = nil
	end
	if current == nil then
		current = Areas.areaAt(map.id, x, z)
		if current then
			local now = os.clock()
			if now - (lastBanner[current.id] or -math.huge) >= BANNER_COOLDOWN then
				lastBanner[current.id] = now
				token += 1
				AreaState.Banner:set({ area = current, token = token })
			end
		end
	end
	if current ~= Fusion.peek(AreaState.Current) then
		AreaState.Current:set(current)
	end
end

function AreaController.Start()
	task.spawn(function()
		while true do
			pcall(step)
			task.wait(INTERVAL)
		end
	end)
end

return AreaController
