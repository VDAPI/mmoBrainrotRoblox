--!strict
-- Gathering and fishing on the client (DESIGN §12): prompts on nodes tagged "GatherNode" ("Mine" / "Pick" /
-- "Fish" [E], hidden while the node is depleted), a placeholder pickaxe swinging while mining (state
-- `gather`), the bobber on the water and the fishing minigame (state `fishing` + FishingBite event). Also
-- owns the stone destination picker window.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FishingGame = require(script.Parent.Parent.UI.Screens.FishingGame)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GatherNodes = require(ReplicatedStorage.Shared.Data.GatherNodes)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local StonePicker = require(script.Parent.Parent.UI.Screens.StonePicker)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local GatherController = {
	Name = "GatherController",
	Deps = { "UIController", "WindowManager", "WorldController" },
}

local TAG = "GatherNode"
local FISH_ACTION = "VaelthornFishingPress"

local scope = Fusion.scoped(Fusion)
local WindowManager: any

local fishingPhase = scope:Value(nil :: string?)
local fishingParams = scope:Value(nil :: FishingGame.Params?)
local fishingRound = scope:Value(0)
local currentSession: string? = nil
local pressSignal: { press: (() -> ())? } = {}
local bobber: BasePart? = nil

local stoneIndex = scope:Value(nil :: number?)
local stoneKind = scope:Value("map")

local function toastError(err: string?)
	Sounds.play("error")
	Toast.push(Text.now(err or "error.internal"), "error")
end

-- Bobber ------------------------------------------------------------------------------------------

local function removeBobber()
	if bobber then
		bobber:Destroy()
		bobber = nil
	end
end

local function placeBobber(nodeUid: string)
	removeBobber()
	local model: Model? = nil
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:GetAttribute("Uid") == nodeUid and instance:IsA("Model") then
			model = instance
		end
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not model or not root then
		return
	end
	local centre = model:GetPivot().Position
	-- Land a few studs out from the player towards the middle of the pond.
	local toward = (centre - root.Position) * Vector3.new(1, 0, 1)
	local spot = if toward.Magnitude > 1 then root.Position + toward.Unit * math.min(toward.Magnitude, 8) else centre
	local part = Instance.new("Part")
	part.Name = "VaelthornBobber"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.9, 0.9, 0.9)
	part.Color = Color3.fromHex("#D64A3E")
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Position = Vector3.new(spot.X, centre.Y + 0.6, spot.Z)
	part.Parent = workspace
	TweenService:Create(
		part,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = part.Position + Vector3.new(0, 0.25, 0) }
	):Play()
	bobber = part
end

local function bite()
	if not bobber then
		return
	end
	local origin = bobber.Position
	TweenService:Create(bobber, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 3, true), {
		Position = origin - Vector3.new(0, 0.6, 0),
	}):Play()
end

-- Pickaxe placeholder --------------------------------------------------------------------------------

local swingToken = 0

local function startSwing(category: string)
	swingToken += 1
	local token = swingToken
	local character = Players.LocalPlayer.Character
	local hand = character
		and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if not hand then
		return
	end
	local tool: Part? = nil
	local weld: Weld? = nil
	if category == "ore" then
		local p = Instance.new("Part")
		p.Name = "VaelthornPickaxe"
		p.Size = Vector3.new(0.3, 2.6, 0.3)
		p.Color = Color3.fromHex("#8A6B4A")
		p.CanCollide = false
		p.Massless = true
		local head = Instance.new("Part")
		head.Size = Vector3.new(2, 0.35, 0.35)
		head.Color = Color3.fromHex("#8E8E93")
		head.CanCollide = false
		head.Massless = true
		local headWeld = Instance.new("Weld")
		headWeld.Part0 = p
		headWeld.Part1 = head
		headWeld.C0 = CFrame.new(0, 1.2, 0)
		headWeld.Parent = head
		head.Parent = p
		local w = Instance.new("Weld")
		w.Part0 = hand
		w.Part1 = p
		w.C0 = CFrame.new(0, -0.4, -0.6) * CFrame.Angles(math.rad(-90), 0, 0)
		w.Parent = p
		p.Parent = character
		tool, weld = p, w
	end
	task.spawn(function()
		local up = true
		while swingToken == token do
			if weld then
				local angle = if up then -40 else 30
				TweenService:Create(weld, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
					C0 = CFrame.new(0, -0.4, -0.6) * CFrame.Angles(math.rad(-90 + angle), 0, 0),
				}):Play()
				if not up then
					Sounds.play("hit")
				end
			end
			up = not up
			task.wait(0.28)
		end
		if tool then
			tool:Destroy()
		end
	end)
end

local function stopSwing()
	swingToken += 1
end

-- Prompts ----------------------------------------------------------------------------------------

local function decorate(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local kindId = model:GetAttribute("Kind")
	local kind = if type(kindId) == "string" then GatherNodes.get(kindId) else nil
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not kind or not anchor or anchor:FindFirstChild("VaelthornGather") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VaelthornGather"
	Keybinds.bindPrompt(prompt, "interact")
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = GatherNodes.RANGE + (if kind.category == "fishing" then 12 else 0)
	local function refresh()
		prompt.ActionText = Text.now(`gather.action.{kind.category}`)
		prompt.ObjectText = Text.now(kind.nameKey)
		prompt.Enabled = model:GetAttribute("Available") ~= false
	end
	refresh()
	model:GetAttributeChangedSignal("Available"):Connect(refresh)
	scope:Observer(Text.Lang):onChange(refresh)
	prompt.Parent = anchor
	prompt.Triggered:Connect(function()
		local uid = model:GetAttribute("Uid")
		if type(uid) ~= "string" then
			return
		end
		task.spawn(function()
			if kind.category == "fishing" then
				local ok, err, sessionId = Net.Invoke("StartFishing", uid)
				if ok then
					currentSession = sessionId
					Sounds.play("click")
				else
					toastError(err)
				end
			else
				local ok, err = Net.Invoke("StartGather", uid)
				if not ok then
					toastError(err)
				end
			end
		end)
	end)
end

-- Fishing ----------------------------------------------------------------------------------------

local function bindPress(enabled: boolean)
	if enabled then
		ContextActionService:BindActionAtPriority(FISH_ACTION, function(_, inputState)
			if inputState == Enum.UserInputState.Begin and pressSignal.press then
				pressSignal.press()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	else
		ContextActionService:UnbindAction(FISH_ACTION)
	end
end

local function onFinish(hits: number)
	local sessionId = currentSession
	bindPress(false)
	if not sessionId then
		return
	end
	currentSession = nil
	task.spawn(function()
		local ok, err, result = Net.Invoke("FishingResult", sessionId, hits)
		if ok and result then
			Sounds.play("levelUp")
			Toast.push(Text.now("fish.caught", { name = ItemText.name(result.fish) }), "success", 4)
			if result.chest then
				Toast.push(Text.now("fish.chest", { gold = result.gold or 0 }), "success", 5)
			end
		else
			toastError(err)
		end
	end)
end

local function onCancel()
	bindPress(false)
	currentSession = nil
	Net.Send("CancelFishing")
end

function GatherController.OpenStonePicker(index: number, kind: string)
	stoneIndex:set(index)
	stoneKind:set(kind)
	WindowManager.Open("stonepicker")
end

function GatherController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	local WorldController = registry.Get("WorldController")
	local UIController = registry.Get("UIController")
	FishingGame(scope, {
		Phase = fishingPhase,
		Params = fishingParams,
		Round = fishingRound,
		OnFinish = onFinish,
		OnCancel = onCancel,
		PressSignal = pressSignal,
	}).Parent =
		UIController.GetLayer("Windows")

	WindowManager.Register({
		id = "stonepicker",
		titleKey = "window.stonepicker.title",
		size = Vector2.new(520, 460),
		build = function(s)
			return StonePicker(s, {
				Index = stoneIndex,
				Kind = stoneKind,
				Close = function()
					WindowManager.Close("stonepicker")
				end,
				-- S22: a region map asks for the monster area (same window as portals).
				PickArea = function(mapId: string, index: number): boolean
					if not WorldController.HasAreaChoice(mapId, nil) then
						return false
					end
					WindowManager.Close("stonepicker")
					WorldController.OpenAreaPicker(mapId, {}, function(areaId: string): (boolean, string?)
						return Net.Invoke("UseMapStone", index, mapId, areaId)
					end)
					return true
				end,
			})
		end,
	})
end

function GatherController.Start()
	for _, instance in CollectionService:GetTagged(TAG) do
		task.spawn(decorate, instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
		task.defer(decorate, instance)
	end)

	-- Mining / picking animation follows state `gather`.
	scope:Observer(State.Value({ "gather" })):onChange(function()
		local gather = State.Get({ "gather" })
		if type(gather) == "table" then
			startSwing(gather.category or "herb")
		else
			stopSwing()
		end
	end)

	-- Fishing state: waiting (bobber) -> bite (minigame) -> cleared.
	scope:Observer(State.Value({ "fishing" })):onChange(function()
		local fishing = State.Get({ "fishing" })
		if type(fishing) ~= "table" then
			removeBobber()
			fishingPhase:set(nil)
			bindPress(false)
			return
		end
		currentSession = fishing.sessionId
		if fishing.phase == "waiting" then
			fishingPhase:set("waiting")
			if not bobber and type(fishing.node) == "string" then
				placeBobber(fishing.node)
			end
		end
	end)

	Net.On("FishingBite", function(sessionId: string, params: FishingGame.Params)
		if sessionId ~= currentSession then
			return
		end
		Sounds.play("levelUp")
		bite()
		fishingParams:set(params)
		fishingPhase:set("bite")
		fishingRound:set(Fusion.peek(fishingRound) + 1)
		bindPress(true)
	end)
end

return GatherController
