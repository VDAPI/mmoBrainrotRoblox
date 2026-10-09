--!strict
-- Title, name, level and class above every player character, plus an HP bar that appears while the player
-- is hurt (S16). Built client-side from model attributes set by the server (CharName, Level, ClassId,
-- GuildTag, Title) and Humanoid.Health (the HP percentage mirror), so each viewer sees their own language.
-- S29: a rarity-coloured ✶ right of the name while the character has an active blessing (attributes Blessing and
-- BlessingUntil, Logic/BlessingMark); it blinks during the last minute. Everyone sees it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BlessingMark = require(ReplicatedStorage.Shared.Logic.BlessingMark)
local Blessings = require(ReplicatedStorage.Shared.Data.Blessings)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local ItemText = require(script.Parent.Parent.UI.ItemText)

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PvpDot = require(script.Parent.Parent.UI.Components.PvpDot)
local PvpRules = require(ReplicatedStorage.Shared.Logic.PvpRules)
local PvpState = require(script.Parent.Parent.UI.PvpState)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local NameplateController = {
	Name = "NameplateController",
}

local MAX_DISTANCE = 80
local HP_LINGER = 4 -- seconds the bar stays after the last hit at full HP
local CLOCK_TICK = 0.25 -- seconds between blessing clock updates shared by all nameplates
local rootScope: Scope = Fusion.scoped(Fusion)
local folder: Folder
-- Shared by every nameplate: the real-time clock and the last-minute blink phase.
local clock = rootScope:Value(Clock.now())
local blinkOn = rootScope:Value(true)

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

local function build(model: Model)
	local scope = rootScope:innerScope()
	table.insert(
		scope,
		model.Destroying:Connect(function()
			Fusion.doCleanup(scope)
		end)
	)
	table.insert(
		scope,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(game) then
				Fusion.doCleanup(scope)
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
	local isLocal = model == Players.LocalPlayer.Character
	local owner = Players:GetPlayerFromCharacter(model)
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

	local head = model:WaitForChild("Head", 10)
	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
	if not head or not model:IsDescendantOf(game) then
		Fusion.doCleanup(scope)
		return
	end

	-- HP: visible while below full, and for a moment after a hit; hidden for dead characters.
	local ratio = scope:Value(1)
	local recentHit = scope:Value(false)
	local hitToken = 0
	if humanoid and humanoid:IsA("Humanoid") then
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
	local showHp = scope:Computed(function(use): boolean
		local r = use(ratio)
		return r > 0.002 and (r < 0.999 or use(recentHit))
	end)
	local trail =
		scope:Tween(ratio, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.15))
	-- The plate follows a replaced Head (avatar rebuilds, cosmetics) instead of vanishing with the old one.
	local adornee = scope:Value(head :: Instance?)
	table.insert(
		scope,
		model.ChildAdded:Connect(function(child)
			if child.Name == "Head" and child:IsA("BasePart") then
				adornee:set(child)
			end
		end)
	)

	scope:New("BillboardGui")({
		Name = `Nameplate_{model.Name}`,
		Parent = folder,
		Adornee = adornee,
		-- FIX 2026-10-09: your own plate stays on top (hair and hats hid it); 2026-10-10: and has no distance limit
		-- (the camera zooms out further than MAX_DISTANCE, which hid it).
		AlwaysOnTop = isLocal,
		LightInfluence = 0,
		MaxDistance = if isLocal then math.huge else MAX_DISTANCE,
		Size = UDim2.fromOffset(260, 92),
		ResetOnSpawn = false,
		StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0),
		Enabled = scope:Computed(function(use): boolean
			return use(charName) ~= nil
		end),
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
			scope:New("TextLabel")({
				Name = "Title",
				LayoutOrder = 0,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				Visible = scope:Computed(function(use): boolean
					return use(titleDef) ~= nil
				end),
				Text = scope:Computed(function(use): string
					local def = use(titleDef)
					return if def then `« {Text.get(use, def.nameKey)} »` else ""
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = 15,
				TextColor3 = scope:Computed(function(use): Color3
					local def = use(titleDef)
					return if def then Color3.fromHex(def.color) else Theme.Colors.Parchment
				end),
				TextStrokeTransparency = 0.4,
			}),
			-- Name row (S18): PvP dot first, then the name.
			scope:New("Frame")({
				Name = "NameRow",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 28),
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
					scope:New("TextLabel")({
						Name = "CharName",
						LayoutOrder = 2,
						RichText = true,
						BackgroundTransparency = 1,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromScale(0, 1),
						Text = scope:Computed(function(use): string
							local name = use(charName) or ""
							local tag = use(guildTag)
							if type(tag) == "string" and tag ~= "" then
								name = `<font color="#{Theme.Colors.Gold:ToHex()}">[{tag}]</font> {name}`
							end
							return if use(hostile) then `⚔ {name}` else name
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 22,
						TextColor3 = scope:Computed(function(use): Color3
							if use(hostile) then
								return Theme.Colors.ZoneRed
							end
							if use(vip) == true then
								return Theme.Colors.GoldBright -- VIP pass: coloured name (DESIGN §21)
							end
							return if isLocal then Theme.Colors.GoldBright else Theme.Colors.Text
						end),
						TextStrokeTransparency = 0.35,
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
						TextSize = 20,
						TextColor3 = scope:Computed(function(use): Color3
							local def = Blessings.get(use(activeBlessing) or "")
							return if def then ItemText.rarityColor(def.rarity) else Theme.Colors.Gold
						end),
						TextTransparency = scope:Computed(function(use): number
							return if use(blessingEnding) and not use(blinkOn) then 0.85 else 0
						end),
						TextStrokeTransparency = 0.35,
					}),
					-- VIP badge (FIX 2026-10-09): shown on every VIP's plate, your own included.
					scope:New("TextLabel")({
						Name = "Vip",
						LayoutOrder = 4,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 18),
						Visible = scope:Computed(function(use): boolean
							return use(vip) == true
						end),
						Text = Text.T(scope, "nameplate.vip"),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 13,
						TextColor3 = Theme.Colors.GoldBright,
						BackgroundColor3 = Color3.fromRGB(40, 28, 10),
						BackgroundTransparency = 0.2,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
							scope:New("UIStroke")({
								Color = Theme.Colors.GoldBright,
								Thickness = 1,
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
				Size = UDim2.new(1, 0, 0, 22),
				Text = Text.T(scope, "nameplate.levelClass", { level = level, class = className }),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = 17,
				TextColor3 = Theme.Colors.Parchment,
				TextStrokeTransparency = 0.45,
			}),
			scope:New("Frame")({
				Name = "HpBar",
				LayoutOrder = 3,
				Size = UDim2.fromOffset(110, 8),
				BackgroundColor3 = Theme.Colors.Background,
				BackgroundTransparency = 0.15,
				Visible = showHp,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
					scope:New("UIStroke")({ Color = Theme.Colors.Background, Thickness = 1 }),
					scope:New("Frame")({
						Name = "Trail",
						BackgroundColor3 = Color3.fromHex("#F2E6C9"),
						Size = scope:Computed(function(use): UDim2
							return UDim2.fromScale(math.max(use(trail), use(ratio)), 1)
						end),
						[Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }) },
					}),
					scope:New("Frame")({
						Name = "Fill",
						BackgroundColor3 = if isLocal then Theme.Colors.Success else Theme.Colors.Hp,
						Size = scope:Computed(function(use): UDim2
							return UDim2.fromScale(use(ratio), 1)
						end),
						[Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }) },
					}),
				},
			}),
		},
	})
end

local function watchPlayer(player: Player)
	if player.Character then
		task.spawn(build, player.Character)
	end
	player.CharacterAdded:Connect(build)
end

function NameplateController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_Nameplates"
	folder.Parent = playerGui
end

function NameplateController.Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= CLOCK_TICK then
			accumulator = 0
			clock:set(Clock.now())
		end
		blinkOn:set(BlessingMark.blinkOn(os.clock()))
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return NameplateController
