--!strict
-- The name (and title) above every player character, plus a thin HP bar while another player is hurt (S16). Built
-- client-side from model attributes set by the server (CharName, GuildTag, Title, PvpEnabled, PvpZone) and
-- Humanoid.Health, so each viewer sees their own language.
-- S29: a rarity-coloured ✶ right of the name while the character has an active blessing (attributes Blessing and
-- BlessingUntil, Logic/BlessingMark); it blinks during the last minute. Everyone sees it.
-- S135: one plate per model (`plates`), built when the model appears (CharacterAdded, the Character property, any
-- model with CharName added to the workspace), cleaned up only on Destroying, a new character or the player leaving.
-- Every plate stays on top, the distance comes from Config.Nameplate, beyond `detailDistance` only the name stays
-- (Logic/Nameplate). The name of another player is a button opening the S133 player menu (PartyController.OpenMenu).
-- W28 (owner: "sometimes the nick over my head disappears, also after teleports; the plate is too visible and big,
-- with a frame"):
--   * Look: no plate, no frame, no level line, no VIP badge, no PvP dot. The name (thin dark stroke, PvP / own / VIP
--     colour, the guild tag small before it) with the title smaller above it, the blessing ✶ after it. A UIScale from
--     the camera distance (Logic/Nameplate.scale) shrinks far plates and never grows a near one.
--   * Robustness: the plate followed only a "Head" added later, so a Head replaced or streamed out without a fitting
--     ChildAdded (ApplyDescription of the class look, streaming, a model swap) left the BillboardGui adorning a dead
--     part and the name vanished for good; the S135 workspace fallback could also take a player's plate over to a
--     second model of the same name and keep `byPlayer` pointing at a destroyed model. Now the anchor (Head, else
--     HumanoidRootPart) is re-checked every `checkEvery`, and every `sweepEvery` (and right after CharacterAdded and a
--     map transition) each player's current character gets a live plate: a missing plate, a destroyed BillboardGui
--     or a lost folder in PlayerGui is rebuilt. Your own plate included.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BlessingMark = require(ReplicatedStorage.Shared.Logic.BlessingMark)
local Blessings = require(ReplicatedStorage.Shared.Data.Blessings)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local GraphicsLevel = require(ReplicatedStorage.Shared.Logic.GraphicsLevel)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Nameplate = require(ReplicatedStorage.Shared.Logic.Nameplate)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)

local TitleText = require(script.Parent.Parent.UI.TitleText)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.UI.Theme)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local NameplateController = {
	Name = "NameplateController",
	Deps = { "PartyController" },
}

local CFG = Config.Nameplate
local HP_LINGER = 4 -- seconds the bar stays after the last hit at full HP
local CLOCK_TICK = 0.25 -- seconds between blessing clock updates shared by all nameplates
-- W28: text straight over the world (no plate): light colours with a dark stroke ("hud" = readable on dark tiles)
local NAME_COLORS: { [string]: Color3 } = {
	hostile = Theme.readable(UiPalette.zone.red, "hud"),
	own = Theme.Brass.Bright,
	vip = Theme.Brass.Bright,
	text = Theme.Plain,
}
local TAG_HEX = Theme.readableHex(UiPalette.brass.line, "hud")
-- owner 2026-10-20 (837de9c8): a full dark outline
local STROKE = Theme.Iron.Sunken
local STROKE_ALPHA = 0

local rootScope: Scope = Fusion.scoped(Fusion)
local folder: Folder? = nil
local playerGui: Instance? = nil
local PartyController: any
-- Shared by every nameplate: the real-time clock and the last-minute blink phase.
local clock = rootScope:Value(Clock.now())
local blinkOn = rootScope:Value(true)

-- One plate per character model. `anchor` is the adornee (Head, else HumanoidRootPart), `lift` the extra studs for
-- the root fallback, `far` the camera distance for the detail cut, `scale` the UIScale factor.
-- (Fusion values typed `any`: the generic Value types made the loops "too complex to typecheck")
type Plate = {
	scope: any, -- Scope
	owner: Player,
	anchor: any, -- Fusion.Value<Instance?>
	lift: any, -- Fusion.Value<number>
	far: any, -- Fusion.Value<number?>
	scale: any, -- Fusion.Value<number>
	isLocal: boolean,
	gui: BillboardGui?,
}
local plates: { [Model]: Plate } = {}
local byPlayer: { [Player]: Model } = {}

local function attributeValue(scope: Scope, model: Model, name: string): Fusion.Value<any>
	local value = scope:Value(model:GetAttribute(name))
	table.insert(
		scope,
		model:GetAttributeChangedSignal(name):Connect(function()
			value:set(model:GetAttribute(name))
		end)
	)
	return value
end

-- The part a plate hangs on: the Head when the model has one, else the root (a Head still streaming in or being
-- replaced), with the extra lift for the root.
local function anchorOf(model: Model): (BasePart?, number)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head, 0
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root, CFG.rootLift
	end
	return nil, 0
end

local function refreshAnchor(model: Model, plate: Plate)
	local current = Fusion.peek(plate.anchor)
	if current and current.Parent == model and current.Name == "Head" then
		return
	end
	local part, lift = anchorOf(model)
	if part ~= current then
		plate.anchor:set(part)
	end
	if lift ~= Fusion.peek(plate.lift) then
		plate.lift:set(lift)
	end
end

local function drop(model: Model)
	local plate = plates[model]
	if plate then
		plates[model] = nil
		if byPlayer[plate.owner] == model then
			byPlayer[plate.owner] = nil
		end
		Fusion.doCleanup(plate.scope)
	end
end

local function build(model: Model, owner: Player)
	local parent = folder
	if not parent then
		return
	end
	local scope = rootScope:innerScope()
	local isLocal = owner == Players.LocalPlayer
	local plate: Plate = {
		scope = scope,
		owner = owner,
		anchor = scope:Value(nil :: Instance?),
		lift = scope:Value(0),
		far = scope:Value(nil :: number?),
		scale = scope:Value(1),
		isLocal = isLocal,
		gui = nil,
	}
	plates[model] = plate
	refreshAnchor(model, plate)
	-- Only a destroyed model ends the plate: a model streamed out (parent nil) keeps it and shows it again on return.
	table.insert(
		scope,
		model.Destroying:Connect(function()
			drop(model)
		end)
	)
	-- A Head (or root) added, replaced or removed moves the plate at once; the periodic check catches the rest.
	local function onChildren()
		if plates[model] == plate then
			refreshAnchor(model, plate)
		end
	end
	table.insert(scope, model.ChildAdded:Connect(onChildren))
	table.insert(scope, model.ChildRemoved:Connect(onChildren))

	local charName = attributeValue(scope, model, "CharName")
	local guildTag = attributeValue(scope, model, "GuildTag")
	local guildEmblem = attributeValue(scope, model, "GuildEmblem") -- S159g: the guild banner
	local guildColor = attributeValue(scope, model, "GuildColor")
	local vip = scope:Value(owner:GetAttribute("Vip"))
	table.insert(
		scope,
		owner:GetAttributeChangedSignal("Vip"):Connect(function()
			vip:set(owner:GetAttribute("Vip"))
		end)
	)
	-- PvP (S10): the name turns red when PvP is on or the player stands in a red zone (W28: the colour is the marker).
	local pvpEnabled = attributeValue(scope, model, "PvpEnabled")
	local pvpZone = attributeValue(scope, model, "PvpZone")
	local hostile = scope:Computed(function(use): boolean
		return use(pvpEnabled) == true or use(pvpZone) == "red"
	end)

	local title = attributeValue(scope, model, "Title")
	local titleSeason = attributeValue(scope, model, "TitleSeason") -- S128: the season of an arena title
	local titleDef = scope:Computed(function(use): any
		local id = use(title)
		return if type(id) == "string" then TitleData.get(id) else nil
	end)

	-- Blessing ✶ (S29): primitive Computeds, so the shared clock only touches what changes.
	local blessingId = attributeValue(scope, model, "Blessing")
	local blessingUntil = attributeValue(scope, model, "BlessingUntil")
	local blessingMark = function(use: Fusion.Use): BlessingMark.Mark?
		return BlessingMark.read(use(blessingId), use(blessingUntil), use(clock))
	end
	local activeBlessing = scope:Computed(function(use): string?
		local mark = blessingMark(use)
		return if mark then mark.def.id else nil
	end)
	local blessingEnding = scope:Computed(function(use): boolean
		local mark = blessingMark(use)
		return mark ~= nil and mark.lastMinute
	end)

	-- HP: visible while below full, and for a moment after a hit; hidden for dead characters.
	local ratio = scope:Value(1)
	local recentHit = scope:Value(false)
	local hitToken = 0
	local watched: Humanoid? = nil
	local function watchHumanoid(humanoid: Humanoid)
		if watched == humanoid then
			return
		end
		watched = humanoid
		local function refresh()
			local max = humanoid.MaxHealth
			local newRatio = if max > 0 then math.clamp(humanoid.Health / max, 0, 1) else 1
			if newRatio < Fusion.peek(ratio) - 0.001 then
				hitToken += 1
				local token = hitToken
				recentHit:set(true)
				task.delay(HP_LINGER, function()
					if token == hitToken then
						recentHit:set(false)
					end
				end)
			end
			ratio:set(newRatio)
		end
		refresh()
		table.insert(scope, humanoid.HealthChanged:Connect(refresh))
		table.insert(scope, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh))
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		watchHumanoid(humanoid)
	end
	table.insert(
		scope,
		model.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then
				watchHumanoid(child)
			end
		end)
	)

	local view = scope:Computed(function(use): Nameplate.View
		local def = use(titleDef)
		local r = use(ratio)
		local tag = use(guildTag)
		return Nameplate.view({
			isLocal = isLocal,
			hostile = use(hostile),
			vip = use(vip) == true,
			titleHex = if def then def.color else nil,
			guildTag = if type(tag) == "string" then tag else nil,
			hurt = r > 0.002 and (r < 0.999 or use(recentHit)),
			distance = use(plate.far),
		})
	end)

	-- `at` in InputObject coordinates, like the world right click and touch hold in PartyController
	local function openMenu(input: InputObject)
		if isLocal or not PartyController then
			return
		end
		PartyController.OpenMenu(owner, Vector2.new(input.Position.X, input.Position.Y))
	end

	local function stroked(props: { [any]: any }): { [any]: any }
		props.BackgroundTransparency = 1
		props.TextStrokeColor3 = STROKE
		props.TextStrokeTransparency = STROKE_ALPHA
		return props
	end

	plate.gui = scope:New("BillboardGui")({
		Name = `Nameplate_{model.Name}`,
		Parent = parent,
		Adornee = plate.anchor,
		-- FIX 2026-10-09 / 2026-10-10 for your own plate, S135 for every plate: on top (hair, helmets, trees, roofs)
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = if isLocal then math.huge else CFG.maxDistance,
		Size = UDim2.fromOffset(CFG.width, CFG.height),
		-- W28: the gui's bottom edge sits `offset` studs above the anchor, so the name hugs the head
		SizeOffset = Vector2.new(0, 0.5),
		ResetOnSpawn = false,
		Active = not isLocal, -- the name button (S133 menu); your own plate never catches clicks or camera drags
		StudsOffsetWorldSpace = scope:Computed(function(use): Vector3
			return Vector3.new(0, CFG.offset + use(plate.lift), 0)
		end),
		Enabled = scope:Computed(function(use): boolean
			return use(charName) ~= nil and use(plate.anchor) ~= nil
		end),
		[Children] = {
			scope:New("Frame")({
				Name = "Content",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIScale")({
						Scale = plate.scale,
					}),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Bottom,
					}),
					scope:New("TextLabel")(stroked({
						Name = "Title",
						LayoutOrder = 0,
						Size = UDim2.fromOffset(0, CFG.titleSize + 2),
						AutomaticSize = Enum.AutomaticSize.X,
						Visible = scope:Computed(function(use): boolean
							return use(view).showTitle
						end),
						Text = scope:Computed(function(use): string
							local def = use(titleDef)
							local season = use(titleSeason)
							return if def
								then TitleText.get(use, def, if type(season) == "string" then season else nil)
								else ""
						end),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = CFG.titleSize,
						TextColor3 = scope:Computed(function(use): Color3
							local hex = use(view).titleHex
							return if hex then Theme.readable(hex, "hud") else Theme.Plain
						end),
					})),
					scope:New("Frame")({
						Name = "NameRow",
						LayoutOrder = 1,
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(0, CFG.nameSize + 4),
						AutomaticSize = Enum.AutomaticSize.X,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 3),
							}),
							-- Another player's name is a button: the S133 player menu (left / right click, tap). Only
							-- the text's own width catches input, so monsters behind a player stay clickable.
							scope:New("TextButton")(stroked({
								Name = "CharName",
								LayoutOrder = 1,
								RichText = true,
								AutoButtonColor = false,
								Active = not isLocal,
								Selectable = false,
								AutomaticSize = Enum.AutomaticSize.X,
								Size = UDim2.fromScale(0, 1),
								Text = scope:Computed(function(use): string
									local v = use(view)
									local name = use(charName) or ""
									if v.guildTag then
										-- S159g: the banner's emblem and colour (readable on the HUD), brass before
										local hex = use(guildColor)
										local glyph = use(guildEmblem)
										local tagHex = if type(hex) == "string"
											then Theme.readableHex(hex, "hud")
											else TAG_HEX
										local emblem = if type(glyph) == "string" then glyph else ""
										return `<font size="{CFG.tagSize}" color="{tagHex}">[{emblem}{v.guildTag}]</font> {name}`
									end
									return name
								end),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = CFG.nameSize,
								TextColor3 = scope:Computed(function(use): Color3
									return NAME_COLORS[use(view).nameRole] or Theme.Plain
								end),
								[OnEvent("Activated")] = function(input: InputObject)
									openMenu(input)
								end,
								[OnEvent("InputBegan")] = function(input: InputObject)
									if input.UserInputType == Enum.UserInputType.MouseButton2 then
										openMenu(input)
									end
								end,
							})),
							scope:New("TextLabel")(stroked({
								Name = "Blessing",
								LayoutOrder = 2,
								Size = UDim2.fromOffset(CFG.nameSize - 2, CFG.nameSize),
								Visible = scope:Computed(function(use): boolean
									return use(activeBlessing) ~= nil
								end),
								Text = "✶",
								FontFace = Theme.Fonts.BodyBold,
								TextSize = CFG.nameSize - 2,
								TextColor3 = scope:Computed(function(use): Color3
									local def = Blessings.get(use(activeBlessing) or "")
									return if def then ItemText.rarityColor(def.rarity) else Theme.Brass.Bright
								end),
								TextTransparency = scope:Computed(function(use): number
									return if use(blessingEnding) and not use(blinkOn) then 0.85 else 0
								end),
							})),
						},
					}),
					-- A thin HP bar under another player's name while hurt (your own HP is in the HUD).
					scope:New("Frame")({
						Name = "HpBar",
						LayoutOrder = 2,
						Size = UDim2.fromOffset(CFG.hpWidth, 4),
						BackgroundColor3 = Theme.Resource.Track,
						BackgroundTransparency = 0.25,
						BorderSizePixel = 0,
						Visible = scope:Computed(function(use): boolean
							return use(view).showHp
						end),
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }),
							scope:New("Frame")({
								Name = "Fill",
								BorderSizePixel = 0,
								BackgroundColor3 = Theme.Resource.Hp,
								Size = scope:Computed(function(use): UDim2
									return UDim2.fromScale(use(ratio), 1)
								end),
								[Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }) },
							}),
						},
					}),
				},
			}),
		},
	}) :: BillboardGui
end

-- One plate per character model (no duplicates); a player's previous character loses its plate.
local function attach(model: Model, owner: Player?)
	if plates[model] then
		return
	end
	-- A character streamed back in may not be the player's Character reference yet: the model carries the
	-- player's name (Roblox names characters after their player).
	local player = owner or Players:GetPlayerFromCharacter(model)
	if not player then
		local byName = Players:FindFirstChild(model.Name)
		player = if byName and byName:IsA("Player") then byName else nil
		-- W28: a same-named model never takes the plate from the player's live character
		local live = player and player.Character
		if live and live ~= model and live.Parent ~= nil then
			return
		end
	end
	if not player then
		return
	end
	local previous = byPlayer[player]
	if previous and previous ~= model then
		drop(previous)
	end
	byPlayer[player] = model
	build(model, player)
end

-- W28: every player's current character has a live plate (folder in PlayerGui, BillboardGui not destroyed).
local function ensureFolder(): boolean
	local gui = playerGui
	if not gui then
		return false
	end
	local current = folder
	if current and current.Parent == gui then
		return true
	end
	-- The folder was removed (a PlayerGui reset): every plate inside went with it.
	for model in plates do
		drop(model)
	end
	local created = Instance.new("Folder")
	created.Name = "Vaelthorn_Nameplates"
	created.Parent = gui
	folder = created
	return true
end

local function sweep()
	if not ensureFolder() then
		return
	end
	for model, plate in plates do
		local gui = plate.gui
		if not gui or gui.Parent ~= folder then
			drop(model)
		end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			attach(character, player)
		end
	end
end

local sweepQueued = false
local function sweepSoon()
	if sweepQueued then
		return
	end
	sweepQueued = true
	task.defer(function()
		sweepQueued = false
		sweep()
	end)
end

local function watchPlayer(player: Player)
	local function current()
		local character = player.Character
		if character then
			attach(character, player)
		end
	end
	current()
	player.CharacterAdded:Connect(function(character)
		attach(character, player)
		sweepSoon()
	end)
	player:GetPropertyChangedSignal("Character"):Connect(current)
end

-- The anchor and the camera distance of one plate (details beyond detailDistance, the UIScale factor).
local function checkPlate(model: Model, plate: Plate, eye: Vector3?)
	refreshAnchor(model, plate)
	local anchor: any = Fusion.peek(plate.anchor)
	local distance: number? = nil
	if eye and anchor and anchor:IsA("BasePart") then
		distance = math.floor(((anchor :: BasePart).Position - eye).Magnitude)
	end
	local scale: number = Nameplate.scale(distance)
	if scale ~= Fusion.peek(plate.scale) then
		plate.scale:set(scale)
	end
	if plate.isLocal then
		return
	end
	-- Only a crossing of detailDistance (or an anchor appearing / leaving) changes what the plate shows.
	local old: number? = Fusion.peek(plate.far)
	local wasFar = old ~= nil and old > CFG.detailDistance
	local isFar = distance ~= nil and distance > CFG.detailDistance
	if (old == nil) ~= (distance == nil) or wasFar ~= isFar then
		plate.far:set(distance)
	end
end

local function checkPlates()
	local camera = Workspace.CurrentCamera
	local eye: Vector3? = if camera then camera.CFrame.Position else nil
	for model, plate in plates do
		checkPlate(model, plate, eye)
	end
end

function NameplateController.Init(registry: any)
	PartyController = registry.Get("PartyController")
	playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	ensureFolder()
end

function NameplateController.Start()
	local accumulator = 0
	local checkTimer = 0
	local sweepTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		checkTimer += dt
		sweepTimer += dt
		if accumulator >= CLOCK_TICK then
			accumulator = 0
			clock:set(Clock.now())
		end
		if sweepTimer >= CFG.sweepEvery then
			sweepTimer = 0
			sweep()
		end
		-- W29: a low graphics level checks the plates' distances half as often
		local every =
			math.max(CFG.checkEvery, GraphicsLevel.get(State.Get({ "account", "settings", "quality" })).plateEvery)
		if checkTimer >= every then
			checkTimer = 0
			checkPlates()
		end
		blinkOn:set(BlessingMark.blinkOn(os.clock()))
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local model = byPlayer[player]
		byPlayer[player] = nil
		if model then
			drop(model)
		end
	end)
	-- A character streamed back in (or replicated late) is a model with CharName added to the workspace.
	Workspace.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") and child:GetAttribute("CharName") ~= nil then
			attach(child :: Model, nil)
		end
	end)
	-- W28: a map change (teleport, respawn) re-checks every plate at its start and end.
	Net.On("MapTransition", function()
		sweepSoon()
	end)
end

return NameplateController
