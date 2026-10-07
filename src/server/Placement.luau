--!strict
-- Safe placement of a player's character (spawns, map changes, rescues). The client owns its character's physics
-- and only collides with the world it has streamed in: unanchoring the root one frame after the pivot (S18) let
-- a client that had not received the ground yet fall through the map (reported after S26, when the server has
-- far more to stream). Now the root stays anchored at the target until the client reports solid ground under it
-- ("GroundCheck" -> "GroundReady" with the same token) or HOLD_TIMEOUT passes. A plain module (CharacterService
-- and TravelService both place characters); CharacterService wires the remote in Start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Net = require(ReplicatedStorage.Shared.Net)

local log = Log.new("Placement")

local Placement = {}

Placement.HOLD_TIMEOUT = 10

local counter = 0
local pending: { [Player]: { token: number, ready: boolean } } = {}

-- Client answer (CharacterService wires Net.On("GroundReady")).
function Placement.OnReady(player: Player, token: number)
	local entry = pending[player]
	if entry and entry.token == token then
		entry.ready = true
	end
end

-- Whether a placement of this player's character is in progress.
function Placement.IsPlacing(player: Player): boolean
	return pending[player] ~= nil
end

function Placement.Forget(player: Player)
	pending[player] = nil
end

-- Anchors the root and pivots the model to `cframe` (yields a frame or two). Returns the token for `release`.
function Placement.place(player: Player, model: Model, cframe: CFrame): number
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	counter += 1
	local token = counter
	pending[player] = { token = token, ready = false }
	if root then
		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
	end
	model:PivotTo(cframe)
	task.wait()
	if root and (root.Position - cframe.Position).Magnitude > 20 then
		model:PivotTo(cframe)
		task.wait()
	end
	Net.Fire(player, "GroundCheck", token, cframe.Position)
	return token
end

-- Keeps the root anchored until the client has ground under it (or HOLD_TIMEOUT), then releases it at `cframe`.
-- Yields. Returns false when the model went away or another placement took over (that one releases it).
function Placement.release(player: Player, model: Model, cframe: CFrame, token: number): boolean
	local entry = pending[player]
	if not entry or entry.token ~= token then
		return false
	end
	local deadline = os.clock() + Placement.HOLD_TIMEOUT
	while not entry.ready and os.clock() < deadline do
		task.wait(0.05)
		if pending[player] ~= entry or model.Parent == nil or player.Parent == nil then
			return false
		end
	end
	if not entry.ready then
		log:warn("%s: no ground confirmation after %d s, releasing anyway", player.Name, Placement.HOLD_TIMEOUT)
	end
	pending[player] = nil
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and root.Parent then
		-- The client may have nudged the anchored root while loading: put it back exactly before releasing.
		if (root.Position - cframe.Position).Magnitude > 2 then
			model:PivotTo(cframe)
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = false
	end
	return true
end

-- place + release. Yields.
function Placement.hold(player: Player, model: Model, cframe: CFrame): boolean
	return Placement.release(player, model, cframe, Placement.place(player, model, cframe))
end

return Placement
