--!strict
-- Loot bags in the world (DESIGN §5.5), visible only to their owner: a small bag glowing in the colour of the
-- best item inside with its name above it. Pick up with F (prompt), E, or a click. Legendary drops add an
-- orange pillar of light, a sound and a screen flash; picking one up opens the reveal window.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local LegendReveal = require(script.Parent.Parent.UI.Screens.LegendReveal)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)

type ItemInstance = Types.ItemInstance

local LootController = {
	Name = "LootController",
	Deps = { "UIController", "ItemController" },
}

type BagView = {
	id: string,
	model: Model,
	label: TextLabel,
	position: Vector3,
	items: { ItemInstance },
}

local UIController: any
local ItemController: any
local folder: Folder
local bags: { [string]: BagView } = {}
local busy: { [string]: boolean } = {}

local PILLAR_HEIGHT = 60
local LEGEND = Color3.fromHex("#FF9F1C")

local function bestOf(items: { ItemInstance }): ItemInstance?
	local best: ItemInstance? = nil
	for _, item in items do
		if best == nil or item.rarity > best.rarity then
			best = item
		end
	end
	return best
end

local function labelText(items: { ItemInstance }): string
	local best = bestOf(items)
	if not best then
		return ""
	end
	local name = ItemText.name(best.id, best.up)
	if best.n > 1 then
		name ..= ` x{best.n}`
	end
	if #items > 1 then
		return Text.now("loot.bagItems", { name = name, more = #items - 1 })
	end
	return name
end

local function pickup(id: string)
	if busy[id] then
		return
	end
	busy[id] = true
	task.spawn(function()
		local ok, err = Net.Invoke("PickupLoot", id)
		busy[id] = nil
		if not ok and err then
			Sounds.play("error")
			Toast.push(Text.now(err), if err == "loot.partial" then "warning" else "error")
		end
	end)
end

local function flashScreen()
	local layer = UIController.GetLayer("Toasts")
	local flash = Instance.new("Frame")
	flash.Name = "LegendFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromHex("#FFE7A0")
	flash.BackgroundTransparency = 0.25
	flash.ZIndex = 100
	flash.Parent = layer
	TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	Debris:AddItem(flash, 0.8)
end

local function pillar(model: Model, at: Vector3)
	local beam = Instance.new("Part")
	beam.Name = "LegendPillar"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = LEGEND
	beam.Transparency = 0.35
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(PILLAR_HEIGHT, 2.2, 2.2)
	beam.CFrame = CFrame.new(at + Vector3.new(0, PILLAR_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = model
	TweenService:Create(
		beam,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.6, Size = Vector3.new(PILLAR_HEIGHT, 3, 3) }
	):Play()
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(LEGEND)
	sparks.LightEmission = 1
	sparks.Rate = 25
	sparks.Lifetime = NumberRange.new(1.5, 2.5)
	sparks.Speed = NumberRange.new(4, 10)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.EmissionDirection = Enum.NormalId.Right -- cylinder axis is X
	sparks.Parent = beam
end

local function spawnBag(data: { [string]: any })
	if bags[data.id] then
		return
	end
	local items = data.items :: { ItemInstance }
	local best = bestOf(items)
	local color = if best then ItemText.rarityColor(best.rarity) else Theme.Colors.Gold
	local position = data.position :: Vector3

	local model = Instance.new("Model")
	model.Name = `Loot_{data.id}`

	local bag = Instance.new("Part")
	bag.Name = "Bag"
	bag.Shape = Enum.PartType.Ball
	bag.Size = Vector3.new(1.8, 1.8, 1.8)
	bag.Anchored = true
	bag.CanCollide = false
	bag.Color = Color3.fromHex("#8A6B4A")
	bag.Material = Enum.Material.Fabric
	bag.CFrame = CFrame.new(position + Vector3.new(0, 0.9, 0))
	bag.Parent = model
	model.PrimaryPart = bag

	local knot = Instance.new("Part")
	knot.Name = "Knot"
	knot.Size = Vector3.new(0.6, 0.5, 0.6)
	knot.Anchored = true
	knot.CanCollide = false
	knot.Color = color
	knot.Material = Enum.Material.Neon
	knot.CFrame = bag.CFrame * CFrame.new(0, 1, 0)
	knot.Parent = model

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if best and best.rarity >= Rarities.EPIC then 14 else 8
	light.Brightness = 2
	light.Parent = bag

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(260, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	gui.Adornee = bag
	gui.Parent = model
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.Fonts.BodyBold
	label.TextSize = 18
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = labelText(items)
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Text.now("loot.pickup")
	prompt.ObjectText = ""
	Keybinds.bindPrompt(prompt, "pickup")
	prompt.MaxActivationDistance = Config.LootPickupRange
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = bag
	prompt.Triggered:Connect(function()
		pickup(data.id)
	end)

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = Config.LootPickupRange + 2
	click.Parent = bag
	click.MouseClick:Connect(function()
		pickup(data.id)
	end)

	if data.legendary then
		pillar(model, position)
		Sounds.play("levelUp")
		flashScreen()
	end

	model.Parent = folder
	bags[data.id] = { id = data.id, model = model, label = label, position = position, items = items }
end

local function removeBag(id: string)
	local view = bags[id]
	if view then
		bags[id] = nil
		view.model:Destroy()
	end
end

local function openReveal(item: ItemInstance)
	local scope = UIController.Scope:innerScope()
	local function close()
		Fusion.doCleanup(scope)
	end
	LegendReveal(scope, {
		Item = item,
		OnEquip = function()
			for key, owned in State.Get({ "character", "inventory" }) or {} do
				if owned.uid == item.uid then
					ItemController.Equip(tonumber(key) :: number, nil)
					return
				end
			end
		end,
		Close = close,
	}).Parent =
		UIController.GetLayer("Modals")
end

local function onPicked(items: { ItemInstance })
	local shown = 0
	for _, item in items do
		if shown < 4 then
			shown += 1
			Toast.push(
				`<font color="#{ItemText.rarityColor(item.rarity):ToHex()}">{Text.now("loot.picked", {
					n = item.n,
					name = ItemText.name(item.id, item.up),
				})}</font>`,
				"info",
				2.5
			)
		end
	end
	for _, item in items do
		if item.rarity == Rarities.LEGENDARY then
			openReveal(item)
			break
		end
	end
end

-- Nearest bag within pickup range (E key).
local function nearestBag(): string?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best: string? = nil
	local bestDistance = Config.LootPickupRange
	for id, view in bags do
		local distance = (view.position - root.Position).Magnitude
		if distance <= bestDistance then
			best = id
			bestDistance = distance
		end
	end
	return best
end

function LootController.Init(registry)
	UIController = registry.Get("UIController")
	ItemController = registry.Get("ItemController")
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_Loot"
	folder.Parent = Workspace
end

function LootController.Start()
	Net.On("LootSpawn", spawnBag)
	Net.On("LootRemove", removeBag)
	Net.On("LootUpdate", function(id: string, items: { ItemInstance })
		local view = bags[id]
		if view then
			view.items = items
			view.label.Text = labelText(items)
		end
	end)
	Net.On("LootPicked", onPicked)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and Keybinds.is(input.KeyCode, "interact") then
			local id = nearestBag()
			if id then
				pickup(id)
			end
		end
	end)

	-- Leaving the world hides the bags (the server forgets them after Config.LootLifetime).
	State.Changed:Connect(function()
		if State.Get({ "session", "phase" }) ~= "playing" then
			for id in bags do
				removeBag(id)
			end
		end
	end)
end

return LootController
