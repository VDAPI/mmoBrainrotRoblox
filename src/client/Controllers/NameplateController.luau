--!strict
-- Name, level and class above every player character. Built client-side from model attributes set by the
-- server (CharName, Level, ClassId, GuildTag), so each viewer sees it in their own language.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local NameplateController = {
	Name = "NameplateController",
}

local MAX_DISTANCE = 80
local rootScope: Scope = Fusion.scoped(Fusion)
local folder: Folder

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

	local head = model:WaitForChild("Head", 10)
	if not head or not model:IsDescendantOf(game) then
		Fusion.doCleanup(scope)
		return
	end

	scope:New("BillboardGui")({
		Name = `Nameplate_{model.Name}`,
		Parent = folder,
		Adornee = head,
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = MAX_DISTANCE,
		Size = UDim2.fromOffset(240, 56),
		StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
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
				Name = "CharName",
				LayoutOrder = 1,
				RichText = true,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 28),
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
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return NameplateController
