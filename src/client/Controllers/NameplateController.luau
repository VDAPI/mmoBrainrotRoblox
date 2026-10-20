--!strict
-- Title, name, level and class above every player character, plus an HP bar that appears while the player
-- is hurt (S16). Built client-side from model attributes set by the server (CharName, Level, ClassId,
-- GuildTag, Title) and Humanoid.Health (the HP percentage mirror), so each viewer sees their own language.
-- S29: a rarity-coloured ✶ right of the name while the character has an active blessing (attributes Blessing and
-- BlessingUntil, Logic/BlessingMark); it blinks during the last minute. Everyone sees it.
-- S135: other players' plates went missing (owner report). With StreamingEnabled a character outside the streaming
-- radius leaves the workspace and comes back without a new CharacterAdded, and the plate was cleaned up when the
-- model left the game and never rebuilt; it also gave up after 10 s without a Head. Now: one plate per model
-- (`plates`), built when the model appears (CharacterAdded, the Character property, any model with CharName added to
-- the workspace), waiting for its Head as long as the model lives, cleaned up only on Destroying, a new character or
-- the player leaving. Every plate stays on top (hair, helmets, trees and roofs hid it), the distance comes from
-- Config.Nameplate (the camera zooms out past the old 80 studs), and beyond `detailDistance` only the name stays
-- (Logic/Nameplate). Look: "Parchment and iron" (a light iron plate with a brass edge). The name of another player is
-- a button opening the S133 player menu (PartyController.OpenMenu).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArtIcon = require(script.Parent.Parent.UI.Components.ArtIcon)
local BlessingMark = require(ReplicatedStorage.Shared.Logic.BlessingMark)
local Blessings = require(ReplicatedStorage.Shared.Data.Blessings)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Nameplate = require(ReplicatedStorage.Shared.Logic.Nameplate)

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local TitleText = require(script.Parent.Parent.UI.TitleText)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PvpDot = require(script.Parent.Parent.UI.Components.PvpDot)
local PvpRules = require(ReplicatedStorage.Shared.Logic.PvpRules)
local PvpState = require(script.Parent.Parent.UI.PvpState)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
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
local VIP_ART = UiArt.hud("vip") -- S119
-- S135: name colours by role (Logic/Nameplate), readable on the iron plate
local NAME_COLORS: { [string]: Color3 } = {
	hostile = Theme.readable(UiPalette.zone.red, "iron"),
	own = Theme.Brass.Bright,
	vip = Theme.Brass.Bright,
	text = Theme.Iron.Text,
}
local TAG_HEX = Theme.readableHex(UiPalette.brass.bright, "iron")

local rootScope: Scope = Fusion.scoped(Fusion)
local folder: Folder
local PartyController: any
-- Shared by every nameplate: the real-time clock and the last-minute blink phase.
local clock = rootScope:Value(Clock.now())
local blinkOn = rootScope:Value(true)

-- S135: one plate per character model; `far` is updated by the shared distance check.
type Plate = {
	scope: Scope,
	head: Fusion.Value<Instance?>,
	far: Fusion.Value<number?>,
	isLocal: boolean,
	model: Model,
}
local plates: { [Model]: Plate } = {}

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

local function drop(model: Model)
	local plate = plates[model]
	if plate then
		plates[model] = nil
		Fusion.doCleanup(plate.scope)
	end
end

local function build(model: Model, owner: Player?)
	local scope = rootScope:innerScope()
	local isLocal = owner == Players.LocalPlayer
	local head = scope:Value(model:FindFirstChild("Head") :: Instance?)
	local far = scope:Value(nil :: number?)
	plates[model] = { scope = scope, head = head, far = far, isLocal = isLocal, model = model }
	-- Only a destroyed model ends the plate: a model streamed out (parent nil) keeps it and shows it again on return.
	table.insert(
		scope,
		model.Destroying:Connect(function()
			drop(model)
		end)
	)
	-- The plate follows a (replaced or late) Head: no time limit while the model lives.
	table.insert(
		scope,
		model.ChildAdded:Connect(function(child)
			if child.Name == "Head" and child:IsA("BasePart") then
				head:set(child)
			end
		end)
	)

	local charName = attributeValue(scope, model, "CharName")
	local guildTag = attributeValue(scope, model, "GuildTag")
	local level = attributeValue(scope, model, "Level")
	local classId = attributeValue(scope, model, "ClassId")
	local className = scope:Computed(function(use): string
		local class = Classes.get(use(classId) or "")
		return if class then Text.get(use, class.nameKey) else ""
	end)
	local vip = scope:Value(if owner then owner:GetAttribute("Vip") else nil)
	if owner then
		table.insert(
			scope,
			owner:GetAttributeChangedSignal("Vip"):Connect(function()
				vip:set(owner:GetAttribute("Vip"))
			end)
		)
	end
	-- PvP (S10): red name with a crossed-swords icon when PvP is on or the player stands in a red zone.
	local pvpEnabled = attributeValue(scope, model, "PvpEnabled")
	local pvpZone = attributeValue(scope, model, "PvpZone")
	local hostile = scope:Computed(function(use): boolean
		return use(pvpEnabled) == true or use(pvpZone) == "red"
	end)
	-- The local player's dot knows the countdown and the lock; others only the attributes.
	local pvpIndicator: Fusion.Computed<string> = if isLocal
		then PvpState.indicator(scope)
		else scope:Computed(function(use): string
			local zone = use(pvpZone)
			return PvpRules.indicator(
				use(pvpEnabled) == true,
				if type(zone) == "string" then zone :: any else nil,
				nil,
				nil,
				0
			)
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
	local function watchHumanoid(humanoid: Humanoid)
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
	else
		local waiting: RBXScriptConnection? = nil
		waiting = model.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") and waiting then
				waiting:Disconnect()
				waiting = nil
				watchHumanoid(child)
			end
		end)
		table.insert(scope, function()
			if waiting then
				waiting:Disconnect()
			end
		end)
	end
	local trail =
		scope:Tween(ratio, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.15))

	-- S135: what to show (Logic/Nameplate)
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
			distance = use(far),
		})
	end)

	-- `at` in InputObject coordinates, like the world right click and touch hold in PartyController
	local function openMenu(input: InputObject)
		if isLocal or not owner or not PartyController then
			return
		end
		PartyController.OpenMenu(owner, Vector2.new(input.Position.X, input.Position.Y))
	end

	scope:New("BillboardGui")({
		Name = `Nameplate_{model.Name}`,
		Parent = folder,
		Adornee = head,
		-- FIX 2026-10-09 / 2026-10-10 for your own plate, S135 for every plate: on top (hair, helmets, trees, roofs)
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = if isLocal then math.huge else CFG.maxDistance,
		Size = UDim2.fromOffset(CFG.width, CFG.height),
		ResetOnSpawn = false,
		Active = not isLocal, -- the name button (S133 menu); your own plate never catches clicks
		StudsOffsetWorldSpace = Vector3.new(0, CFG.offset, 0),
		Enabled = scope:Computed(function(use): boolean
			return use(charName) ~= nil
		end),
		[Children] = {
			-- S135: the light iron plate behind the text (readable on snow, sand and in caves)
			scope:New("Frame")({
				Name = "Plate",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Theme.Iron.Surface,
				BackgroundTransparency = CFG.plateTransparency,
				[Children] = {
					-- owner 2026-10-20: no plate and no frame any more, only the title and the name (outlined text)
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, Theme.Padding.Small),
						PaddingRight = UDim.new(0, Theme.Padding.Small),
						PaddingTop = UDim.new(0, 2),
						PaddingBottom = UDim.new(0, Theme.Padding.Tiny),
					}),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Bottom,
					}),
					scope:New("TextLabel")({
						Name = "Title",
						LayoutOrder = 0,
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(0, CFG.titleSize + 3),
						AutomaticSize = Enum.AutomaticSize.X,
						Visible = scope:Computed(function(use): boolean
							return use(view).showTitle
						end),
						Text = scope:Computed(function(use): string
							local def = use(titleDef)
							local season = use(titleSeason)
							return if def
								then `« {TitleText.get(use, def, if type(season) == "string" then season else nil)} »`
								else ""
						end),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = CFG.titleSize,
						TextColor3 = scope:Computed(function(use): Color3
							local hex = use(view).titleHex
							return if hex then Theme.readable(hex, "iron") else Theme.Iron.Text
						end),
						TextStrokeColor3 = Theme.Iron.Sunken,
						TextStrokeTransparency = 0,
					}),
					-- Name row (S18): PvP dot first, then the name.
					scope:New("Frame")({
						Name = "NameRow",
						LayoutOrder = 1,
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(0, CFG.nameSize + 6),
						AutomaticSize = Enum.AutomaticSize.X,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 5),
							}),
							PvpDot(scope, {
								State = pvpIndicator,
								LayoutOrder = 1,
								Size = 14,
								Tooltip = false,
							}),
							-- S135: another player's name is a button: the S133 player menu (left / right click, tap)
							scope:New("TextButton")({
								Name = "CharName",
								LayoutOrder = 2,
								RichText = true,
								AutoButtonColor = false,
								Active = not isLocal,
								Selectable = false,
								BackgroundTransparency = 1,
								AutomaticSize = Enum.AutomaticSize.X,
								Size = UDim2.fromScale(0, 1),
								Text = scope:Computed(function(use): string
									local v = use(view)
									local name = use(charName) or ""
									if v.guildTag then
										name = `<font color="{TAG_HEX}">[{v.guildTag}]</font> {name}`
									end
									return if v.swords then `⚔ {name}` else name
								end),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = CFG.nameSize,
								TextColor3 = scope:Computed(function(use): Color3
									return NAME_COLORS[use(view).nameRole] or Theme.Iron.Text
								end),
								TextStrokeColor3 = Theme.Iron.Sunken,
								TextStrokeTransparency = 0,
								[OnEvent("Activated")] = function(input: InputObject)
									openMenu(input)
								end,
								[OnEvent("InputBegan")] = function(input: InputObject)
									if input.UserInputType == Enum.UserInputType.MouseButton2 then
										openMenu(input)
									end
								end,
							}),
							scope:New("TextLabel")({
								Name = "Blessing",
								LayoutOrder = 3,
								BackgroundTransparency = 1,
								Size = UDim2.fromOffset(18, 22),
								Visible = scope:Computed(function(use): boolean
									return use(activeBlessing) ~= nil
								end),
								Text = "✶",
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = scope:Computed(function(use): Color3
									local def = Blessings.get(use(activeBlessing) or "")
									return if def then ItemText.rarityColor(def.rarity) else Theme.Brass.Bright
								end),
								TextTransparency = scope:Computed(function(use): number
									return if use(blessingEnding) and not use(blinkOn) then 0.85 else 0
								end),
								TextStrokeColor3 = Theme.Iron.Sunken,
								TextStrokeTransparency = 0,
							}),
							-- S119: the VIP crown silhouette before the badge once loaded.
							ArtIcon.Image(scope, {
								Name = "VipArt",
								Key = VIP_ART,
								Tint = Theme.Brass.Bright,
								Size = UDim2.fromOffset(18, 18),
								LayoutOrder = 4,
								Visible = scope:Computed(function(use): boolean
									return use(view).showVip
								end),
							}),
							-- VIP badge (FIX 2026-10-09): shown on every VIP's plate, your own included.
							scope:New("TextLabel")({
								Name = "Vip",
								LayoutOrder = 5,
								AutomaticSize = Enum.AutomaticSize.X,
								Size = UDim2.fromOffset(0, 18),
								Visible = scope:Computed(function(use): boolean
									return use(view).showVip
								end),
								Text = Text.T(scope, "nameplate.vip"),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Caption,
								TextColor3 = Theme.Brass.Bright,
								BackgroundColor3 = Theme.Iron.Raised,
								BackgroundTransparency = 0.1,
								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
									scope:New("UIStroke")({
										Color = Theme.Brass.Bright,
										Thickness = Theme.Stroke.Thin,
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									}),
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 5),
										PaddingRight = UDim.new(0, 5),
									}),
								},
							}),
						},
					}),
					scope:New("TextLabel")({
						Name = "LevelClass",
						LayoutOrder = 2,
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(0, CFG.levelSize + 4),
						AutomaticSize = Enum.AutomaticSize.X,
						-- owner 2026-10-20: only the title and the name above the head (the level and class are in the
						-- player menu and the target frame)
						Visible = false,
						Text = Text.T(scope, "nameplate.levelClass", { level = level, class = className }),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = CFG.levelSize,
						TextColor3 = Theme.Iron.Text,
						TextStrokeColor3 = Theme.Iron.Sunken,
						TextStrokeTransparency = 0,
					}),
					scope:New("Frame")({
						Name = "HpBar",
						LayoutOrder = 3,
						Size = UDim2.fromOffset(110, 8),
						BackgroundColor3 = Theme.Resource.Track,
						BackgroundTransparency = 0.15,
						Visible = scope:Computed(function(use): boolean
							return use(view).showHp
						end),
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
							scope:New("UIStroke")({ Color = Theme.Resource.Track, Thickness = Theme.Stroke.Thin }),
							scope:New("Frame")({
								Name = "Trail",
								BackgroundColor3 = Theme.Iron.Text,
								Size = scope:Computed(function(use): UDim2
									return UDim2.fromScale(math.max(use(trail), use(ratio)), 1)
								end),
								[Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }) },
							}),
							scope:New("Frame")({
								Name = "Fill",
								BackgroundColor3 = if isLocal then Theme.Iron.Success else Theme.Resource.Hp,
								Size = scope:Computed(function(use): UDim2
									return UDim2.fromScale(use(ratio), 1)
								end),
								[Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }) },
							}),
						},
					}),
				},
			}),
		},
	})
end

-- One plate per character model (no duplicates); a player's previous character loses its plate.
local byPlayer: { [Player]: Model } = {}
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
	end)
	player:GetPropertyChangedSignal("Character"):Connect(current)
end

-- The distance of every plate from the camera (details beyond Config.Nameplate.detailDistance).
local function checkDistances()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	for _, plate in plates do
		-- owner 2026-10-20: your own name went missing after a teleport: a Head replaced while the old one stayed in the
		-- Value (an applied look swaps the head) is found again here, for every plate
		local current = Fusion.peek(plate.head)
		if not current or current.Parent ~= plate.model then
			local fresh = plate.model:FindFirstChild("Head")
			if fresh and fresh ~= current then
				plate.head:set(fresh)
			end
		end
		if plate.isLocal then
			continue
		end
		local head = Fusion.peek(plate.head)
		local distance: number? = nil
		if head and head:IsA("BasePart") then
			distance = math.floor((head.Position - eye).Magnitude)
		end
		-- Only a crossing of detailDistance (or a Head appearing / leaving) changes what the plate shows.
		local old = Fusion.peek(plate.far)
		local wasFar = old ~= nil and old > CFG.detailDistance
		local isFar = distance ~= nil and distance > CFG.detailDistance
		if (old == nil) ~= (distance == nil) or wasFar ~= isFar then
			plate.far:set(distance)
		end
	end
end

function NameplateController.Init(registry: any)
	PartyController = registry.Get("PartyController")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_Nameplates"
	folder.Parent = playerGui
end

function NameplateController.Start()
	local accumulator = 0
	local distanceTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		distanceTimer += dt
		if accumulator >= CLOCK_TICK then
			accumulator = 0
			clock:set(Clock.now())
		end
		if distanceTimer >= CFG.checkEvery then
			distanceTimer = 0
			checkDistances()
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
end

return NameplateController
