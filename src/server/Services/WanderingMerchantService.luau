--!strict
-- The wandering merchant (S159w, owner 2026-10-20, docs/DESIGN.md §8b, Data/WanderingMerchant, Logic/WanderingMerchant).
-- Every world server reads the visit from the clock (no messages between servers): while a visit runs, Radoslav's
-- figure (NpcService.PlaceAt, Data/Npcs.WANDERER) and his caravan (a covered wagon and a pack mule, procedural; a model
-- ReplicatedStorage.Assets.Npcs.wanderer_caravan replaces it when the owner adds one) stand on the visit's spot; the
-- chat and the banner announce him 10 and 1 min before, on arrival, 5 min before he leaves and when he is gone. The
-- map and the window compute the same visit themselves. One purchase: the visit runs, near him, Logic.canBuy (the
-- window's rule), room in the backpack; then, without a yield, the gold or the marks and the visit's counter go and the
-- goods come. Everything is bound and never sold back (`ns`), a dye goes to the account's wardrobe.
--   WanderingMerchantBuy(key, amount) -> (ok, errorKey?)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local ServerMode = require(script.Parent.Parent.Arena.ServerMode)

local Clock = require(Shared.Util.Clock)
local Contracts = require(Shared.Logic.Contracts)
local Cosmetics = require(Shared.Data.Cosmetics)
local Data = require(Shared.Data.WanderingMerchant)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Npcs = require(Shared.Data.Npcs)
local Rng = require(Shared.Logic.Rng)
local Types = require(Shared.Types)
local WanderingMerchant = require(Shared.Logic.WanderingMerchant)

local log = Log.new("WanderingMerchantService")

local WanderingMerchantService = {
	Name = "WanderingMerchantService",
	Deps = {
		"PlayerStateService",
		"InventoryService",
		"NpcService",
		"WorldService",
		"CosmeticService",
		"DataService",
		"AnnounceService",
	},
}

local PlayerStateService: any
local InventoryService: any
local NpcService: any
local WorldService: any
local CosmeticService: any
local DataService: any
local AnnounceService: any

local rng = Rng.new()
local busy: { [Player]: boolean } = {}
local shownIndex: number? = nil -- the visit whose figure stands now (or is being placed)
local caravan: Model? = nil

local LOOK = Data.look

-- The caravan in its own frame (the wagon's centre on the ground at the origin, its long side facing -Z like the
-- merchant): { name, class, size, position, colour key / hex, material, shape?, rotation? }.
type PartSpec = {
	name: string,
	size: Vector3,
	at: Vector3,
	color: string,
	material: Enum.Material,
	shape: Enum.PartType?,
	rot: Vector3?, -- degrees
	collide: boolean?,
}

local function wood(name: string, size: Vector3, at: Vector3): PartSpec
	return { name = name, size = size, at = at, color = LOOK.wood, material = Enum.Material.WoodPlanks, collide = true }
end

local function caravanSpec(): { PartSpec }
	local list: { PartSpec } = {
		wood("Bed", Vector3.new(10, 0.6, 5), Vector3.new(0, 2.2, 0)),
		wood("SideFront", Vector3.new(10, 1.2, 0.3), Vector3.new(0, 3.1, -2.35)),
		wood("SideBack", Vector3.new(10, 1.2, 0.3), Vector3.new(0, 3.1, 2.35)),
		wood("EndLeft", Vector3.new(0.3, 1.2, 5), Vector3.new(-4.85, 3.1, 0)),
		wood("EndRight", Vector3.new(0.3, 1.2, 5), Vector3.new(4.85, 3.1, 0)),
		-- the covered top: a block over the bed and a cylinder for the round canvas, two bands in the second colour
		{
			name = "Canvas",
			size = Vector3.new(9.4, 2.2, 4.8),
			at = Vector3.new(0, 4.8, 0),
			color = LOOK.canvas,
			material = Enum.Material.Fabric,
			collide = true,
		},
		{
			name = "CanvasTop",
			size = Vector3.new(9.4, 4.8, 4.8),
			at = Vector3.new(0, 5.9, 0),
			color = LOOK.canvas,
			material = Enum.Material.Fabric,
			shape = Enum.PartType.Cylinder,
		},
		{
			name = "Band1",
			size = Vector3.new(0.4, 5, 5),
			at = Vector3.new(-2.6, 5.9, 0),
			color = LOOK.canvas2,
			material = Enum.Material.Fabric,
			shape = Enum.PartType.Cylinder,
		},
		{
			name = "Band2",
			size = Vector3.new(0.4, 5, 5),
			at = Vector3.new(2.6, 5.9, 0),
			color = LOOK.canvas2,
			material = Enum.Material.Fabric,
			shape = Enum.PartType.Cylinder,
		},
		-- the open counter on the front side: a board under a short awning
		wood("Counter", Vector3.new(5, 0.3, 1.4), Vector3.new(0, 3.6, -3.1)),
		{
			name = "Awning",
			size = Vector3.new(6, 0.2, 2),
			at = Vector3.new(0, 6.2, -3.2),
			color = LOOK.canvas2,
			material = Enum.Material.Fabric,
			rot = Vector3.new(-15, 0, 0),
		},
		-- crates, a barrel, the lantern and the pennant
		wood("Crate1", Vector3.new(1.6, 1.6, 1.6), Vector3.new(-6.1, 0.8, -1)),
		wood("Crate2", Vector3.new(1.4, 1.4, 1.4), Vector3.new(-6.0, 2.3, -1.1)),
		{
			name = "Barrel",
			size = Vector3.new(2, 1.6, 1.6),
			at = Vector3.new(-6.2, 1, 1.2),
			color = "#6B4A2B",
			material = Enum.Material.Wood,
			shape = Enum.PartType.Cylinder,
			rot = Vector3.new(0, 0, 90),
			collide = true,
		},
		wood("LanternPole", Vector3.new(0.2, 3.2, 0.2), Vector3.new(4.6, 5.0, -2.6)),
		{
			name = "Lantern",
			size = Vector3.new(0.6, 0.8, 0.6),
			at = Vector3.new(4.6, 6.9, -2.6),
			color = "#FFC86A",
			material = Enum.Material.Neon,
		},
		wood("FlagPole", Vector3.new(0.2, 3.4, 0.2), Vector3.new(-4.4, 9.2, 0)),
		{
			name = "Pennant",
			size = Vector3.new(0.1, 1, 1.8),
			at = Vector3.new(-4.4, 10.3, 0.95),
			color = LOOK.canvas2,
			material = Enum.Material.Fabric,
		},
		-- the shafts and the pack mule at the right end of the wagon
		wood("ShaftFront", Vector3.new(4.2, 0.2, 0.2), Vector3.new(6.9, 2.3, -0.9)),
		wood("ShaftBack", Vector3.new(4.2, 0.2, 0.2), Vector3.new(6.9, 2.3, 0.9)),
		{
			name = "MuleBody",
			size = Vector3.new(3.4, 1.6, 1.4),
			at = Vector3.new(8.4, 2.7, 0),
			color = LOOK.mule,
			material = Enum.Material.SmoothPlastic,
			collide = true,
		},
		{
			name = "MuleNeck",
			size = Vector3.new(0.8, 1.6, 0.7),
			at = Vector3.new(10.1, 3.6, 0),
			color = LOOK.mule,
			material = Enum.Material.SmoothPlastic,
			rot = Vector3.new(0, 0, -30),
		},
		{
			name = "MuleHead",
			size = Vector3.new(1.5, 0.8, 0.7),
			at = Vector3.new(10.9, 4.3, 0),
			color = LOOK.mule,
			material = Enum.Material.SmoothPlastic,
		},
		{
			name = "MuleEarL",
			size = Vector3.new(0.2, 0.7, 0.2),
			at = Vector3.new(10.5, 5.0, -0.2),
			color = LOOK.mule,
			material = Enum.Material.SmoothPlastic,
		},
		{
			name = "MuleEarR",
			size = Vector3.new(0.2, 0.7, 0.2),
			at = Vector3.new(10.5, 5.0, 0.2),
			color = LOOK.mule,
			material = Enum.Material.SmoothPlastic,
		},
		{
			name = "MulePack",
			size = Vector3.new(1.6, 0.9, 1.8),
			at = Vector3.new(8.2, 3.8, 0),
			color = LOOK.canvas2,
			material = Enum.Material.Fabric,
		},
	}
	-- the wheels (axis along Z) and the mule's legs
	for i, p in
		{
			Vector3.new(-3.2, 1.3, -2.65),
			Vector3.new(3.2, 1.3, -2.65),
			Vector3.new(-3.2, 1.3, 2.65),
			Vector3.new(3.2, 1.3, 2.65),
		}
	do
		table.insert(list, {
			name = `Wheel{i}`,
			size = Vector3.new(0.4, 2.6, 2.6),
			at = p,
			color = "#3A2A1A",
			material = Enum.Material.Wood,
			shape = Enum.PartType.Cylinder,
			rot = Vector3.new(0, 90, 0),
			collide = true,
		})
	end
	for i, p in
		{
			Vector3.new(7.2, 0.95, -0.45),
			Vector3.new(7.2, 0.95, 0.45),
			Vector3.new(9.6, 0.95, -0.45),
			Vector3.new(9.6, 0.95, 0.45),
		}
	do
		table.insert(list, {
			name = `MuleLeg{i}`,
			size = Vector3.new(0.4, 1.9, 0.4),
			at = p,
			color = "#4A3E34",
			material = Enum.Material.SmoothPlastic,
		})
	end
	return list
end

-- The caravan model at `base` (the ground point of the wagon's centre, turned like the merchant).
local function buildCaravan(base: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "WandererCaravan"
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local npcAssets = assets and assets:FindFirstChild("Npcs")
	local custom = npcAssets and npcAssets:FindFirstChild("wanderer_caravan")
	if custom and custom:IsA("Model") then
		-- the owner's model: its pivot at the bottom centre of the wagon, its front toward -Z
		local clone = custom:Clone()
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		clone:PivotTo(base)
		clone.Parent = model
		return model
	end
	for _, spec in caravanSpec() do
		local part = Instance.new("Part")
		part.Name = spec.name
		part.Shape = spec.shape or Enum.PartType.Block
		part.Size = spec.size
		part.Color = Color3.fromHex(spec.color)
		part.Material = spec.material
		part.Anchored = true
		part.CanCollide = spec.collide == true
		part.CanTouch = false
		local rot = spec.rot or Vector3.zero
		part.CFrame = base * CFrame.new(spec.at) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		part.Parent = model
		if spec.name == "Lantern" then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromHex("#FFC86A")
			light.Range = 14
			light.Brightness = 1.2
			light.Shadows = false
			light.Parent = part
		end
	end
	model.PrimaryPart = model:FindFirstChild("Bed") :: BasePart?
	return model
end

local function leave()
	NpcService.Remove(Npcs.WANDERER.id)
	if caravan then
		caravan:Destroy()
		caravan = nil
	end
end

-- Places the figure and the caravan of `visit` (waits for a map built in the background).
local function arrive(visit: WanderingMerchant.Visit)
	local spot = visit.spot
	if WorldService.IsBuilding(spot.map) and not WorldService.WaitBuilt(spot.map, 900) then
		log:warn("map %s not built, placing the wandering merchant anyway", spot.map)
	end
	if shownIndex ~= visit.index then
		return -- the visit ended (or another started) while the map was building
	end
	leave()
	local _, ground = NpcService.PlaceAt(Npcs.WANDERER, spot.map, spot.x, spot.z, spot.facing)
	local yaw = math.rad(spot.facing)
	-- behind his back: the opposite of the front (-sin, -cos)
	local cx = spot.x + math.sin(yaw) * LOOK.behind
	local cz = spot.z + math.cos(yaw) * LOOK.behind
	local fromY = if ground then ground.Y + 6 else nil
	local floor = WorldService.FloorAt(spot.map, cx, cz, fromY)
	local model = buildCaravan(CFrame.new(floor) * CFrame.Angles(0, yaw, 0))
	model:SetAttribute("Visit", visit.index)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local world = Workspace:FindFirstChild("World") or Workspace
	model.Parent = world
	caravan = model
	log:info("visit %d at %s (%s)", visit.index, spot.id, spot.map)
end

local function placeArg(visit: WanderingMerchant.Visit): string
	return `@wanderer.spot.{visit.spot.id}`
end

local function mapArg(visit: WanderingMerchant.Visit): string
	local map = Maps.get(visit.spot.map)
	return if map then "@" .. map.nameKey else visit.spot.map
end

local function announce(crossing: WanderingMerchant.Crossing)
	local visit = crossing.visit
	local args = {
		place = placeArg(visit),
		map = mapArg(visit),
		min = math.floor((crossing.before or 0) / 60),
		stay = math.floor(Data.schedule.duration / 60),
		left = math.floor(Data.schedule.leaving / 60),
	}
	AnnounceService.Server(`wanderer.announce.{crossing.kind}`, args)
end

local function maxStack(id: string): number
	local def = Items.get(id)
	return if def and def.stackable then def.maxStack or 1 else 1
end

local function buy(player: Player, key: string, amount: number): (boolean, string?)
	local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local now = Clock.now()
	local visit = WanderingMerchant.current(now)
	if not visit or shownIndex ~= visit.index then
		return false, "wanderer.error.gone"
	end
	if not NpcService.Near(player, Npcs.WANDERER.id) then
		return false, "wanderer.error.tooFar"
	end
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local offer = WanderingMerchant.offerOf(visit.index, key)
	local marksState = Contracts.stateOf(char.quests)
	local account = PlayerStateService.Get(player, { "account" })
	local owned = if type(account) == "table" and type(account.cosmetics) == "table"
		then account.cosmetics.owned
		else {}
	local buyer: WanderingMerchant.Buyer = {
		level = char.level,
		gold = char.gold,
		marks = marksState.marks,
		bought = char.wanderer,
		owned = owned,
	}
	local ok, err = WanderingMerchant.canBuy(offer, visit.index, visit.band, buyer, char.class, amount)
	if not ok or not offer then
		return false, err
	end
	local items: { Types.ItemInstance } = {}
	local grant = WanderingMerchant.grant(offer, char.level, char.class)
	if grant then
		local total = grant.n * amount
		if not Items.get(grant.id) or total > maxStack(grant.id) then
			return false, "error.badRequest"
		end
		local stack = ItemRoll.makeStack(grant.id, total, InventoryService.NewUid())
		stack.bound = true -- bought goods never turn into gold through trade or the auction house
		stack.ns = true -- nor through a merchant (ItemValue.canSell)
		table.insert(items, stack)
	elseif offer.kind == "gear" then
		local ilvl = WanderingMerchant.ilvlOf(visit.band, char.level)
		local defId = WanderingMerchant.pickGear(offer, ilvl, char.class, rng)
		if not defId then
			log:warn("no gear of slot %s at ilvl %d for %s", tostring(offer.slot), ilvl, char.class)
			return false, "wanderer.error.unavailable"
		end
		local item = ItemRoll.rollItem(defId, ilvl, offer.rarity or 2, rng, InventoryService.NewUid(), char.class)
		item.bound = true
		item.ns = true
		table.insert(items, item)
	elseif offer.kind ~= "dye" or not offer.id or not Cosmetics.get(offer.id) then
		return false, "error.badRequest"
	end
	if #items > 0 and not InventoryService.CanFit(player, items) then
		return false, "inventory.full"
	end
	-- no yield from here: the price and the visit's counter, then the goods
	local cost = WanderingMerchant.priceOf(offer, char.level, visit.band, char.class) * amount
	if offer.currency == "marks" then
		PlayerStateService.Set(player, { "character", "quests", "contract", "marks" }, marksState.marks - cost)
	else
		local balance = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
			return math.max(0, gold - cost)
		end)
		Analytics.gold(player, -cost, balance, "wanderer")
	end
	PlayerStateService.Set(
		player,
		{ "character", "wanderer" },
		WanderingMerchant.counted(char.wanderer, visit.index, offer.key, amount)
	)
	for _, item in items do
		local left = InventoryService.AddItem(player, item)
		if left > 0 then
			log:warn("%s: %d x %s did not fit after CanFit", player.Name, left, item.id)
		end
	end
	if offer.kind == "dye" and offer.id then
		CosmeticService.Grant(player, offer.id)
	end
	Analytics.custom(player, `Wanderer_{offer.group}`, cost) -- a bounded name (S131)
	if offer.kind == "gear" then
		Net.Fire(player, "Toast", "wanderer.gotGear", { item = `#item:{items[1].id}:{items[1].up}` }, "success")
	end
	DataService.Save(player)
	return true, nil
end

function WanderingMerchantService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
	WorldService = registry.Get("WorldService")
	CosmeticService = registry.Get("CosmeticService")
	DataService = registry.Get("DataService")
	AnnounceService = registry.Get("AnnounceService")
end

function WanderingMerchantService.Start()
	Net.Handle("WanderingMerchantBuy", function(player: Player, key: string, amount: number): (boolean, string?)
		if busy[player] then
			return false, "wanderer.error.busy"
		end
		busy[player] = true
		local ok, result, err = pcall(buy, player, key, amount)
		busy[player] = nil
		if not ok then
			log:error("wandering merchant purchase failed for %s: %s", player.Name, tostring(result))
			return false, "error.internal"
		end
		return result, err
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
	if not ServerMode.isWorld() then
		return -- no merchant on arena / tournament servers
	end
	task.spawn(function()
		local last = Clock.now()
		while true do
			local now = Clock.now()
			for _, crossing in WanderingMerchant.crossed(last, now) do
				announce(crossing)
			end
			last = now
			local visit = WanderingMerchant.current(now)
			if visit and shownIndex ~= visit.index then
				shownIndex = visit.index
				task.spawn(arrive, visit)
			elseif not visit and shownIndex ~= nil then
				shownIndex = nil
				leave()
			end
			task.wait(1)
		end
	end)
end

return WanderingMerchantService
