--!strict
-- Loot comfort on the client (S20, DESIGN §5.9):
--   * "Better item!": when picked-up equipment beats what the character wears (Logic/ItemScore) a small card
--     with both names and an "Equip" button shows for 8 s (option "betterItem");
--   * the loot log window (last 50 items from character.lootLog), opened from the backpack.
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"; owner question 1):
-- the card is one of UI/Notify's cards: the PC corner's card slot (a tablet: under the toasts, a phone: one line of
-- its M zone with "Equip"), one card at a time; in combat it waits up to 30 s, then drops (the loot log keeps it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.UI.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemScore = require(ReplicatedStorage.Shared.Logic.ItemScore)
local ItemSlot = require(script.Parent.Parent.UI.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LootLog = require(script.Parent.Parent.UI.Screens.LootLog)
local Net = require(ReplicatedStorage.Shared.Net)
local Notify = require(script.Parent.Parent.UI.Notify)
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
local ItemController: any
local card: Notify.Handle? = nil

-- Item in the slot the candidate would replace (rings: the weaker one; S68: shared with the tooltip and /tooltip).
local function replaced(def: Items.ItemDef, ctx: ItemScore.Context): Types.ItemInstance?
	return ItemScore.replaced(def, State.Get({ "character", "equipment" }) or {}, ctx)
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
	if card then
		card.close()
		card = nil
	end
end

local function showCard(item: Types.ItemInstance, current: Types.ItemInstance?)
	closeCard()
	local instead = if current
		then Text.now("better.instead", { item = ItemText.name(current.id, current.up, current.el) })
		else Text.now("better.instead", { item = Text.now("better.empty") })
	local name = ItemText.name(item.id, item.up, item.el)
	local function equip()
		local index = inventoryIndex(item.uid)
		if index then
			ItemController.Equip(index, nil)
		end
	end
	card = Notify.card({
		class = "betterItem",
		title = Text.now("better.title"),
		line = name,
		note = instead, -- a phone's sheet (its card is one line)
		accent = ItemText.rarityName(item.rarity, "iron"),
		seconds = CARD_SECONDS,
		action = { text = Text.now("better.equip"), run = equip },
		-- PC and a tablet: the item's slot, both names and "Equip" (the tooltip of the slot shows the details)
		build = function(scope: Scope, live: Notify.Live): Instance
			return scope:New("Frame")({
				Name = "BetterItem",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Iron.Surface,
				BackgroundTransparency = 0.05,
				Active = true,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					scope:New("UIStroke")({ Color = Theme.Brass.Bright, Thickness = 2 }),
					ItemSlot(scope, {
						Surface = "iron",
						SlotId = `view:better:{item.uid}`,
						Item = item,
						Size = 64,
						Position = UDim2.fromOffset(12, 16),
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(86, 8),
						Size = UDim2.new(1, -(96 + Theme.Size.MinTouch), 0, 24),
						BackgroundTransparency = 1,
						Text = Text.T(scope, "better.title"),
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Brass.Bright,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(86, 32),
						Size = UDim2.new(1, -(96 + Theme.Size.MinTouch), 0, 20),
						BackgroundTransparency = 1,
						Text = name,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = ItemText.rarityName(item.rarity, "iron"),
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
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Iron.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Button(scope, {
						Surface = "iron", -- S135: on a dark HUD / overlay surface
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -10, 1, -6),
						Size = UDim2.fromOffset(96, Theme.Size.MinTouch),
						Variant = "primary",
						Text = Text.T(scope, "better.equip"),
						TextSize = Theme.TextSize.Small,
						OnClick = function()
							live.close()
							equip()
						end,
					}),
					Button(scope, {
						Name = "Close",
						Surface = "iron",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(Theme.Size.MinTouch, Theme.Size.MinTouch),
						Variant = "ghost",
						Text = "✕",
						OnClick = live.close,
					}),
				},
			})
		end,
	})
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
	-- S67: the score follows the class and the main path's item weights (S138: the leading direction and the equipped
	-- weapon's pool, ItemScore.contextFor)
	local ctx = ItemScore.contextFor(State.Get({ "character" }))
	local best: Types.ItemInstance? = nil
	local bestCurrent: Types.ItemInstance? = nil
	local bestGain = 0
	for _, item in items do
		local def = if type(item) == "table" then Items.get(item.id) else nil
		if def and def.slot then
			local current = replaced(def, ctx)
			if ItemScore.isUpgrade(item, current, ctx, level) then
				local gain = ItemScore.score(item, ctx) - (if current then ItemScore.score(current, ctx) else 0)
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

function LootComfortController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	ItemController = registry.Get("ItemController")
	WindowManager.Register({
		id = "lootlog",
		titleKey = "lootlog.title",
		size = Vector2.new(520, 560),
		build = function(scope: Scope)
			return LootLog(scope)
		end,
	})
end

function LootComfortController.Start()
	Net.On("LootPicked", onPicked)
	Players.LocalPlayer.CharacterRemoving:Connect(closeCard)
end

return LootComfortController
