--!strict
-- Mounts (S96, docs/DESIGN-15.md §2): mounting with a short channel, riding and dismounting, server-side.
--   * SetMounted(true): Logic/Mounts.canMount (level, owned mount, alive, out of combat, allowed place, not busy),
--     then a Mounts.mountTime(lvl) channel standing still (state branch `mountCast`); moving more than
--     Config.Mount.moveLimit studs, taking damage or using a skill interrupts it. SetMounted(false) dismounts.
--   * riding: the mount model (Util/MountLook) is welded under the rider's HumanoidRootPart, HipHeight is raised to
--     the saddle, the character model gets the attribute Mount = id (clients pose the rider), character.mounts.riding
--     = true and the walk speed follows the mount rule (StatService.SetMountProvider -> Logic/Mounts.walkSpeed).
--   * dismounting: a skill that is cast (SkillService), a forbidden place (zone change, teleport to a cave or
--     dungeon), death, respawn, gathering / fishing / quest interactions, the client in water, logout and switching
--     characters. Riding never survives entering the world.
-- Other services call Interrupt / Dismount / IsRiding; quests give mounts through Grant; admins use Ride / SetLevel /
-- Take (/mount).
-- S97: upgrades at the stablemaster (MountUpgrade: Logic/Mounts.canUpgrade, gold and parts taken in one step), the
-- active mount (MountSetActive), the boss roll of every winner (RollBossDrop, DungeonService), the account's mount
-- skin on the ridden model (RefreshLook after CosmeticService equips one) and the premium mounts (a product handler
-- per Data/Products.mounts entry; sold only while enabled).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Bosses = require(Shared.Data.Bosses)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local MountData = require(Shared.Data.Mounts)
local MountLook = require(Shared.Util.MountLook)
local Mounts = require(Shared.Logic.Mounts)
local Net = require(Shared.Net)
local Products = require(Shared.Data.Products)
local Rng = require(Shared.Logic.Rng)
local Types = require(Shared.Types)
local UseGuards = require(script.Parent.Parent.UseGuards)

local log = Log.new("MountService")

local MountService = {
	Name = "MountService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"StatService",
		"ResourceService",
		"ZoneService",
		-- S97: none of these depends on this service, directly or further on (CosmeticService takes it lazily)
		"DataService",
		"InventoryService",
		"NpcService",
		"CosmeticService",
		"MonetizationService",
		"AnnounceService",
	},
}

local PlayerStateService: any
local CharacterService: any
local StatService: any
local ResourceService: any
local ZoneService: any
local DataService: any
local InventoryService: any
local NpcService: any
local CosmeticService: any
local MonetizationService: any
local AnnounceService: any

type Casting = { token: number, start: Vector3 }
type Riding = { model: Model, hipHeight: number, id: string, humanoid: Humanoid }

local casting: { [Player]: Casting } = {}
local riding: { [Player]: Riding } = {}
local counter = 0
local busyRequest: { [Player]: boolean } = {} -- S97: one upgrade / choice at a time

local CHECK_EVERY = 0.1
-- State branches of channels that keep the character busy (no mounting meanwhile).
local BUSY_BRANCHES: { { string } } = {
	{ "travel" },
	{ "gather" },
	{ "fishing" },
	{ "questUse" },
	{ "skills", "channel" },
}

local function stateOf(player: Player): Types.MountState?
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	return if character then character.mounts else nil
end

local function setRidingFlag(player: Player, on: boolean)
	if not PlayerStateService.HasState(player) or not PlayerStateService.GetCharacter(player) then
		return
	end
	local state = stateOf(player)
	if state and state.riding ~= on then
		PlayerStateService.Set(player, { "character", "mounts", "riding" }, on)
	end
end

local function rootOf(player: Player): BasePart?
	local model = player.Character
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function busy(player: Player): boolean
	for _, path in BUSY_BRANCHES do
		if PlayerStateService.Get(player, path) ~= nil then
			return true
		end
	end
	return false
end

-- Map and zone name the character is in now (ZoneService; without a zone the saved map).
local function placeOf(player: Player, character: Types.CharacterData): (string, string?)
	local zone = ZoneService.GetZone(player)
	if zone then
		return zone.map, zone.nameKey
	end
	return character.location.map, nil
end

local function check(player: Player): Mounts.Reason?
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return "none"
	end
	local mapId, zoneKey = placeOf(player, character)
	return Mounts.canMount({
		level = character.level,
		mounts = character.mounts,
		dead = ResourceService.IsDead(player),
		inCombat = ResourceService.InCombat(player),
		mapId = mapId,
		zoneKey = zoneKey,
		busy = busy(player),
	})
end

local function clearCast(player: Player)
	casting[player] = nil
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "mountCast" }, nil)
	end
end

-- Stops mounting (no message; callers that want one send it).
function MountService.Interrupt(player: Player)
	if casting[player] then
		counter += 1
		clearCast(player)
	end
end

local function interruptLoud(player: Player)
	if casting[player] then
		MountService.Interrupt(player)
		Net.Fire(player, "Toast", "mount.interrupted", nil, "warning")
	end
end

function MountService.IsRiding(player: Player): boolean
	return riding[player] ~= nil
end

-- Level of the mount ridden now (StatService walk speed), nil on foot.
local function ridingLevel(player: Player): number?
	local ride = riding[player]
	if not ride then
		return nil
	end
	local state = stateOf(player)
	local entry = state and state.owned[ride.id]
	return if entry then math.clamp(entry.lvl, 1, Config.Mount.maxLevel) else 1
end

-- Removes the mount model and restores the rider (quiet unless reason == "place").
function MountService.Dismount(player: Player, reason: string?)
	local ride = riding[player]
	if not ride then
		return
	end
	riding[player] = nil
	if ride.model.Parent then
		ride.model:Destroy()
	end
	if ride.humanoid.Parent then
		ride.humanoid.HipHeight = ride.hipHeight
	end
	local model = player.Character
	if model then
		model:SetAttribute("Mount", nil)
	end
	setRidingFlag(player, false)
	StatService.RefreshWalkSpeed(player)
	if reason == "place" then
		Net.Fire(player, "Toast", "mount.dismount.place", nil, "warning")
	end
end

-- Mounts at once (after the channel; `force`: an admin, without level and combat checks; the place still counts).
function MountService.Ride(player: Player, force: boolean?): (boolean, string?)
	if riding[player] then
		return true, nil
	end
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local id = Mounts.activeOf(if character then character.mounts else nil)
	if not character or not id then
		return false, "mount.error.none"
	end
	local mapId, zoneKey = placeOf(player, character)
	if not Mounts.allowedAt(mapId, zoneKey) then
		return false, "mount.error.place"
	end
	if not force then
		local reason = check(player)
		if reason and reason ~= "riding" then
			return false, `mount.error.{reason}`
		end
	elseif ResourceService.IsDead(player) then
		return false, "mount.error.dead"
	end
	local model = player.Character
	local root = rootOf(player)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not model or not root or not humanoid then
		return false, "error.wrongPhase"
	end
	-- R6 measures HipHeight from the bottom of the legs (2 studs below the root's bottom).
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0
	local account: Types.AccountData? = DataService.GetData(player)
	local skin = if account then account.cosmetics.equipped.mountskin else nil
	local mount, seat = MountLook.build(id, root.Size.Y / 2 + legs, { skin = skin })
	if not mount or not seat then
		return false, "mount.error.none"
	end
	MountService.Interrupt(player)
	local primary = mount.PrimaryPart :: BasePart
	local offset = CFrame.new(seat.offset[1], seat.offset[2], seat.offset[3])
	mount:PivotTo(root.CFrame * offset)
	if mount:GetAttribute("MountRig") == "static" then
		-- A static real model may be loose parts: hold them on its primary part.
		for _, part in mount:GetDescendants() do
			if part:IsA("BasePart") and part ~= primary then
				local hold = Instance.new("WeldConstraint")
				hold.Part0 = primary
				hold.Part1 = part
				hold.Parent = part
			end
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "MountWeld"
	weld.Part0 = root
	weld.Part1 = primary
	weld.C0 = root.CFrame:ToObjectSpace(primary.CFrame)
	weld.Parent = mount
	mount.Parent = model
	riding[player] = { model = mount, hipHeight = humanoid.HipHeight, id = id, humanoid = humanoid }
	humanoid.HipHeight = seat.hipHeight
	model:SetAttribute("Mount", id)
	setRidingFlag(player, true)
	StatService.SetSprint(player, false)
	StatService.RefreshWalkSpeed(player)
	return true, nil
end

-- SetMounted remote: true starts mounting (a channel), false dismounts or stops mounting.
function MountService.Request(player: Player, on: boolean): (boolean, string?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.wrongPhase"
	end
	if not on then
		MountService.Interrupt(player)
		MountService.Dismount(player, "manual")
		return true, nil
	end
	if riding[player] or casting[player] then
		return true, nil
	end
	local reason = check(player)
	if reason == "riding" then
		return true, nil
	elseif reason then
		return false, `mount.error.{reason}`
	end
	local root = rootOf(player)
	if not root then
		return false, "error.wrongPhase"
	end
	local _, lvl = Mounts.activeOf(character.mounts)
	local duration = Mounts.mountTime(lvl)
	counter += 1
	local token = counter
	casting[player] = { token = token, start = root.Position }
	PlayerStateService.Set(player, { "mountCast" }, {
		endsAt = Workspace:GetServerTimeNow() + duration,
		duration = duration,
		label = "mount.casting",
	})
	StatService.SetSprint(player, false)
	task.spawn(function()
		local finishAt = os.clock() + duration
		while os.clock() < finishAt do
			task.wait(CHECK_EVERY)
			local current = casting[player]
			if not current or current.token ~= token then
				return
			end
			local now = rootOf(player)
			if
				not now
				or ResourceService.IsDead(player)
				or ((now.Position - current.start) * Vector3.new(1, 0, 1)).Magnitude > Config.Mount.moveLimit
			then
				interruptLoud(player)
				return
			end
		end
		local current = casting[player]
		if not current or current.token ~= token then
			return
		end
		clearCast(player)
		-- Combat and the place may have changed during the channel (a basic attack meanwhile is combat).
		local ok, err = MountService.Ride(player, false)
		if not ok and err then
			Net.Fire(player, "Toast", err, { level = Config.Mount.minLevel }, "warning")
		end
	end)
	return true, nil
end

-- Gives a mount to the active character (quest reward, admin). False when unknown or already owned.
function MountService.Grant(player: Player, id: string, source: string): boolean
	local state = stateOf(player)
	if not state then
		return false
	end
	local copy: Mounts.MountState = {
		owned = table.clone(state.owned or {}),
		active = state.active,
		riding = state.riding == true,
	}
	if not Mounts.grant(copy, id) then
		return false
	end
	PlayerStateService.Set(player, { "character", "mounts" }, copy)
	local def = MountData.get(id)
	if def then
		Net.Fire(player, "Toast", "mount.got", { name = `@{def.nameKey}` }, "success")
	end
	Analytics.custom(player, "MountGot_" .. source, 1)
	DataService.Save(player)
	log:info("%s got mount %s (%s)", player.Name, id, source)
	return true
end

-- Admin: sets the level of an owned mount (1..maxLevel). False when not owned.
function MountService.SetLevel(player: Player, id: string, lvl: number): boolean
	local state = stateOf(player)
	if not state or not state.owned[id] then
		return false
	end
	local level = math.clamp(math.floor(lvl), 1, Config.Mount.maxLevel)
	PlayerStateService.Set(player, { "character", "mounts", "owned", id }, { lvl = level })
	StatService.RefreshWalkSpeed(player)
	return true
end

-- Admin: takes an owned mount away (dismounts when it is ridden; another owned mount becomes active).
function MountService.Take(player: Player, id: string): boolean
	local state = stateOf(player)
	if not state or not state.owned[id] then
		return false
	end
	local ride = riding[player]
	if ride and ride.id == id then
		MountService.Dismount(player, "admin")
	end
	MountService.Interrupt(player)
	local owned = table.clone(state.owned)
	owned[id] = nil
	local copy: Mounts.MountState = { owned = owned, active = nil, riding = riding[player] ~= nil }
	if state.active ~= id then
		copy.active = state.active
	end
	copy.active = Mounts.activeOf(copy)
	PlayerStateService.Set(player, { "character", "mounts" }, copy)
	return true
end

-- S97 ---------------------------------------------------------------------------------------------------------------

-- MountUpgrade: raises an owned mount by one level at the stablemaster. The check (Logic/Mounts.canUpgrade) and the
-- payment (gold, parts) happen in one step without yielding.
local function upgrade(player: Player, mountId: string): (boolean, string?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.wrongPhase"
	end
	if not NpcService.NearService(player, "mounts") then
		return false, "mount.error.notNear"
	end
	local entry = character.mounts and character.mounts.owned[mountId]
	local nextStep = if entry then Mounts.upgradeCost(entry.lvl + 1) else nil
	local inv: { [string]: number } = {}
	if nextStep then
		for _, m in nextStep.materials do
			inv[m.id] = InventoryService.Count(player, m.id)
		end
	end
	local ok, err, step = Mounts.canUpgrade(character, mountId, inv)
	if not ok or not step or not entry then
		return false, err
	end
	local balance = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return gold - step.gold
	end)
	Analytics.gold(player, -step.gold, balance, "mount")
	for _, m in step.materials do
		InventoryService.Remove(player, m.id, m.n)
	end
	local lvl = math.clamp(entry.lvl + 1, 1, Config.Mount.maxLevel)
	-- SetLevel refreshes the walk speed (StatService asks Logic/Mounts.walkSpeed through the mount provider).
	MountService.SetLevel(player, mountId, lvl)
	local def = MountData.get(mountId)
	Net.Fire(
		player,
		"Toast",
		"mount.upgraded",
		{ mount = if def then `@{def.nameKey}` else mountId, lvl = lvl },
		"success"
	)
	Analytics.custom(player, "MountUpgrade", lvl)
	DataService.Save(player)
	return true, nil
end

-- MountSetActive: picks the owned mount used for riding (out of combat; while riding it dismounts first, the next
-- mounting takes the new mount's time).
local function setActive(player: Player, mountId: string): (boolean, string?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.wrongPhase"
	end
	local state = character.mounts
	if not state or not state.owned[mountId] or not MountData.get(mountId) then
		return false, "mount.error.notOwned"
	end
	if state.active == mountId then
		return true, nil
	end
	if ResourceService.InCombat(player) then
		return false, "mount.error.combat"
	end
	MountService.Interrupt(player)
	MountService.Dismount(player, "manual")
	PlayerStateService.Set(player, { "character", "mounts", "active" }, mountId)
	return true, nil
end

local function lockedRequest(fn: (Player, string) -> (boolean, string?)): (Player, string) -> (boolean, string?)
	return function(player: Player, arg: string)
		if busyRequest[player] then
			return false, "error.busy"
		end
		busyRequest[player] = true
		local ok, result, err = pcall(fn, player, arg)
		busyRequest[player] = nil
		if not ok then
			log:error("mount request failed for %s: %s", player.Name, tostring(result))
			return false, "error.internal"
		end
		return result, err
	end
end

-- The personal mount roll of a boss winner (DungeonService, after every item roll). Grants what dropped: the mount to
-- the character (with a server and cross-server announcement), the skin to the account (a toast). Returns the result
-- for the reward card.
function MountService.RollBossDrop(player: Player, bossId: string, rng: Rng.Rng): Mounts.BossRoll
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local account: Types.AccountData? = DataService.GetData(player)
	if not character or not account then
		return {}
	end
	local owned: { [string]: any } = if character.mounts then character.mounts.owned else {}
	local result = Mounts.rollBossDrop(bossId, owned, account.cosmetics.owned, rng)
	local out: Mounts.BossRoll = {}
	if result.mount and MountService.Grant(player, result.mount, "boss") then
		out.mount = result.mount
		local def = MountData.get(result.mount)
		local boss = Bosses.get(bossId)
		AnnounceService.Global("loot.announceMount", "loot.announceMountGlobal", {
			player = character.name,
			mount = if def then `@{def.nameKey}` else result.mount,
			boss = if boss then `@{boss.nameKey}` else bossId,
		})
	end
	if result.skin and CosmeticService.Grant(player, result.skin) then
		out.skin = result.skin
	end
	return out
end

-- Rebuilds the ridden mount's model (the account's mount skin changed): dismounts quietly and mounts again at once
-- (the place was allowed a moment ago). Nothing on foot.
function MountService.RefreshLook(player: Player)
	if not riding[player] then
		return
	end
	MountService.Dismount(player, "skin")
	MountService.Ride(player, true)
end

-- Forgets the riding state without touching a model that is gone (respawn, leaving).
local function reset(player: Player)
	if casting[player] then
		counter += 1
		clearCast(player)
	end
	local ride = riding[player]
	riding[player] = nil
	if ride and ride.model.Parent then
		ride.model:Destroy()
	end
	setRidingFlag(player, false)
end

function MountService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	StatService = registry.Get("StatService")
	ResourceService = registry.Get("ResourceService")
	ZoneService = registry.Get("ZoneService")
	DataService = registry.Get("DataService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
	CosmeticService = registry.Get("CosmeticService")
	MonetizationService = registry.Get("MonetizationService")
	AnnounceService = registry.Get("AnnounceService")
	StatService.SetMountProvider(ridingLevel)
end

function MountService.Start()
	UseGuards.register("mounted", MountService.IsRiding, "MountService") -- S122 Logic/UseBlocks
	Net.Handle("SetMounted", MountService.Request)
	Net.Handle("MountUpgrade", lockedRequest(upgrade))
	Net.Handle("MountSetActive", lockedRequest(setActive))
	-- S97: premium mounts. Registering never puts one on sale: MonetizationService sells a mount product only while
	-- it is enabled (Logic/Premium.canBuyMount). Without an active character Grant is false, so the receipt waits
	-- (NotProcessedYet) until the player enters the world with a character.
	for _, entry in Products.mounts do
		MonetizationService.RegisterProduct(entry.key, function(player: Player): boolean
			return MountService.Grant(player, entry.mount, "premium")
		end)
	end

	ResourceService.Damaged:Connect(function(player: Player, amount: number)
		if amount > 0 then
			interruptLoud(player)
		end
	end)
	ResourceService.Died:Connect(function(player: Player)
		MountService.Interrupt(player)
		MountService.Dismount(player, "death")
	end)
	ZoneService.ZoneChanged:Connect(function(player: Player, zone: Types.ZoneState)
		if (riding[player] or casting[player]) and not Mounts.allowedAt(zone.map, zone.nameKey) then
			MountService.Interrupt(player)
			MountService.Dismount(player, "place")
		end
	end)
	CharacterService.ModelSpawned:Connect(function(player: Player)
		reset(player)
		StatService.RefreshWalkSpeed(player)
	end)
	CharacterService.CharacterEntered:Connect(reset)
	CharacterService.CharacterLeaving:Connect(reset)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.defer(function()
			casting[player] = nil
			riding[player] = nil
			busyRequest[player] = nil
		end)
	end)
end

return MountService
