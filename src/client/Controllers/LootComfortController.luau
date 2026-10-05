--!strict
-- Loot comfort on the client (S20, DESIGN §5.9):
--   * "Better item!": when picked-up equipment beats what the character wears (Logic/ItemScore) a small card
--     with both names and an "Equip" button shows for 8 s (option "betterItem");
--   * the loot log window (last 50 items from character.lootLog), opened from the backpack.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.UI.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemScore = require(ReplicatedStorage.Shared.Logic.ItemScore)
local ItemSlot = require(script.Parent.Parent.UI.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local LootComfortController = {
	Name = "LootComfortController",
	Deps = { "WindowManager", "UIController", "ItemController" },
}

local CARD_SECONDS = 8

local WindowManager: any
local UIController: any
local ItemController: any
local cardScope: Scope? = nil
local cardToken = 0

-- Item in the slot the candidate would replace (rings: the weaker one).
local function replaced(def: Items.ItemDef, classId: string): Types.ItemInstance?
	local equipment = State.Get({ "character", "equipment" }) or {}
	if def.slot == "ring" then
		local a, b = equipment.ring1, equipment.ring2
		if not a or not b then
			return nil
		end
		return if ItemScore.score(a, classId) <= ItemScore.score(b, classId) then a else b
	end
	return equipment[def.slot or ""]
end

local function inventoryIndex(uid: string): number?
	for key, item in State.Get({ "character", "inventory" }) or {} do
		if item.uid == uid then
			return tonumber(key)
		end
	end
	return nil
end

local function closeCard()
	if cardScope then
		Fusion.doCleanup(cardScope)
		cardScope = nil
	end
end

local function showCard(item: Types.ItemInstance, current: Types.ItemInstance?)
	closeCard()
	cardToken += 1
	local token = cardToken
	local scope = UIController.Scope:innerScope()
	cardScope = scope
	local instead = if current
		then Text.now("better.instead", { item = ItemText.name(current.id, current.up, current.el) })
		else Text.now("better.instead", { item = Text.now("better.empty") })
	scope:New("Frame")({
		Name = "BetterItem",
		Parent = UIController.GetLayer("Toasts"),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -230),
		Size = UDim2.fromOffset(330, 96),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldBright, Thickness = 2 }),
			ItemSlot(scope, {
				SlotId = `view:better:{item.uid}`,
				Item = item,
				Size = 64,
				Position = UDim2.fromOffset(12, 16),
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(86, 8),
				Size = UDim2.new(1, -96, 0, 24),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "better.title"),
				FontFace = Theme.Fonts.Heading,
				TextSize = 20,
				TextColor3 = Theme.Colors.GoldBright,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(86, 32),
				Size = UDim2.new(1, -96, 0, 20),
				BackgroundTransparency = 1,
				Text = ItemText.name(item.id, item.up, item.el),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 15,
				TextColor3 = ItemText.rarityColor(item.rarity),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(86, 52),
				Size = UDim2.new(1, -196, 0, 34),
				BackgroundTransparency = 1,
				Text = instead,
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = 13,
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -10, 1, -10),
				Size = UDim2.fromOffset(96, 36),
				Variant = "primary",
				Text = Text.T(scope, "better.equip"),
				TextSize = Theme.TextSize.Small,
				OnClick = function()
					local index = inventoryIndex(item.uid)
					closeCard()
					if index then
						ItemController.Equip(index, nil)
					end
				end,
			}),
		},
	})
	task.delay(CARD_SECONDS, function()
		if token == cardToken then
			closeCard()
		end
	end)
end

local function onPicked(items: any)
	if type(items) ~= "table" or State.Get({ "account", "settings", "betterItem" }) == false then
		return
	end
	local classId = State.Get({ "character", "class" })
	local level = State.Get({ "character", "level" }) or 1
	if type(classId) ~= "string" then
		return
	end
	local best: Types.ItemInstance? = nil
	local bestCurrent: Types.ItemInstance? = nil
	local bestGain = 0
	for _, item in items do
		local def = if type(item) == "table" then Items.get(item.id) else nil
		if def and def.slot then
			local current = replaced(def, classId)
			if ItemScore.isUpgrade(item, current, classId, level) then
				local gain = ItemScore.score(item, classId) - (if current then ItemScore.score(current, classId) else 0)
				if gain > bestGain then
					best, bestCurrent, bestGain = item, current, gain
				end
			end
		end
	end
	if best then
		Sounds.play("open")
		showCard(best, bestCurrent)
	end
end

-- Loot log window ----------------------------------------------------------------------------------------

local function timeAgo(at: number): string
	local seconds = math.max(0, os.time() - at)
	if seconds < 3600 then
		return `{math.floor(seconds / 60)} min`
	elseif seconds < 86400 then
		return `{math.floor(seconds / 3600)} h`
	end
	return `{math.floor(seconds / 86400)} d`
end

local function LootLogWindow(scope: Scope): Fusion.Child
	local log = State.Value({ "character", "lootLog" })
	return scope:New("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.GoldDim,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
			scope:Computed(function(use, s: Scope): { Instance }
				local list = use(log)
				local rows = {}
				if type(list) ~= "table" or #list == 0 then
					table.insert(
						rows,
						s:New("TextLabel")({
							Size = UDim2.new(1, 0, 0, 30),
							BackgroundTransparency = 1,
							Text = Text.get(use, "lootlog.empty"),
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Body,
							TextColor3 = Theme.Colors.TextMuted,
						})
					)
					return rows
				end
				for i, entry in list do
					local monster = entry.src and Monsters.get(entry.src)
					local map = entry.map and Maps.get(entry.map)
					local source = if monster then Text.get(use, monster.nameKeys.normal) else ""
					if map then
						source = if source ~= ""
							then `{source}, {Text.get(use, map.nameKey)}`
							else Text.get(use, map.nameKey)
					end
					table.insert(
						rows,
						s:New("TextLabel")({
							LayoutOrder = i,
							Size = UDim2.new(1, -8, 0, 26),
							BackgroundColor3 = Theme.Colors.PanelRaised,
							BackgroundTransparency = 0.5,
							RichText = true,
							Text = Text.get(use, "lootlog.entry", {
								time = timeAgo(entry.at or 0),
								item = `<font color="#{ItemText.rarityColor(entry.rarity or 1):ToHex()}">{ItemText.get(
									use,
									entry.id,
									nil,
									entry.el
								)}</font> ({entry.ilvl or 1})`,
								source = source,
							}),
							FontFace = Theme.Fonts.Body,
							TextSize = 15,
							TextColor3 = Theme.Colors.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							[Children] = s:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
						})
					)
				end
				return rows
			end) :: any,
		},
	})
end

function LootComfortController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	UIController = registry.Get("UIController")
	ItemController = registry.Get("ItemController")
	WindowManager.Register({
		id = "lootlog",
		titleKey = "lootlog.title",
		size = Vector2.new(520, 560),
		build = function(scope: Scope)
			return LootLogWindow(scope)
		end,
	})
end

function LootComfortController.Start()
	Net.On("LootPicked", onPicked)
	Players.LocalPlayer.CharacterRemoving:Connect(closeCard)
end

return LootComfortController
