--!strict
-- The Huntmaster's shop (S134k, docs/DESIGN-15.md §3.3, Data/HuntShop): the Hunter's Marks on top, a tab per group
-- (potions and stones, essence, chests, cosmetics), every entry with its icon, name, price, the weekly limit "n/max"
-- and why it cannot be bought now (Logic/HuntShop.canBuy: the server's own rule, `huntshop.error.*`). Buying works
-- only at the Huntmaster (the window opens from his dialog and closes when the player walks away); a chest asks first.
-- Everything bought here is bound to the character. Built like the arena shop tab (S128), scrolling on a phone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local CurrencyIcon = require(script.Parent.Parent.Components.CurrencyIcon)
local Data = require(ReplicatedStorage.Shared.Data.HuntShop)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HuntShop = require(ReplicatedStorage.Shared.Logic.HuntShop)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Modal = require(script.Parent.Parent.Components.Modal)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use

export type Props = {
	NpcId: Fusion.UsedAs<string?>, -- the NPC the player talks to (NpcController.Current)
	ShowModal: (spec: Modal.Spec) -> (),
}

local ICON = 48

-- The shown name of an entry at a level ("Large Healing Potion ×5", "Hunter's Chest", a cosmetic's name).
local function entryName(use: Use, entry: Data.Entry, level: number, classId: string): string
	local grant = HuntShop.grant(entry, level, classId)
	if grant then
		local name = ItemText.get(use, grant.id)
		return if grant.n > 1 then Text.get(use, "huntshop.stack", { name = name, n = grant.n }) else name
	elseif entry.kind == "chest" then
		return Text.get(use, `item.{entry.key}.name`)
	end
	local def = Cosmetics.get(entry.id)
	return if def then Text.get(use, def.nameKey) else entry.id
end

local function entryIcon(s: Scope, entry: Data.Entry, level: number, classId: string): Instance
	local grant = HuntShop.grant(entry, level, classId)
	if grant then
		return ItemIcon(s, { Def = Items.get(grant.id), Size = UDim2.fromOffset(ICON, ICON), LayoutOrder = 1 })
	elseif entry.kind == "chest" then
		local rarity = HuntShop.chestRarity(entry) or Rarities.UNIQUE
		return s:New("TextLabel")({
			LayoutOrder = 1,
			Size = UDim2.fromOffset(ICON, ICON),
			BackgroundTransparency = 1,
			Text = "▣",
			FontFace = Theme.Fonts.BodyBold,
			TextSize = 36,
			TextColor3 = ItemText.rarityColor(rarity),
		})
	end
	local def = Cosmetics.get(entry.id)
	return ArtIcon(s, {
		Key = UiArt.cosmetic(entry.id),
		Glyph = if def then def.icon else "?",
		GlyphColor = if def then Color3.fromHex(def.color) else Theme.Colors.Text,
		Size = UDim2.fromOffset(ICON, ICON),
		LayoutOrder = 1,
	})
end

local function label(s: Scope, order: number, text: string, size: number, color: Color3, font: Font?): Instance
	return s:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		RichText = true,
		TextWrapped = true,
		Text = text,
		FontFace = font or Theme.Fonts.Body,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function HuntShopWindow(scope: Scope, props: Props): Fusion.Child
	local contract = State.Value({ "character", "quests", "contract" })
	local level = State.Value({ "character", "level" })
	local class = State.Value({ "character", "class" })
	local owned = State.Value({ "account", "cosmetics", "owned" })
	local tab = scope:Value(Data.GROUPS[1] :: string)
	local busy = scope:Value(false)
	local touch = Device.Touch

	local function buy(entry: Data.Entry, name: string, price: number)
		local npcId = Fusion.peek(props.NpcId)
		if not npcId or Fusion.peek(busy) then
			return
		end
		local function send(): (boolean, string?)
			busy:set(true)
			local ok, err = Net.Invoke("HuntShopBuy", npcId, entry.key, 1)
			busy:set(false)
			if ok then
				Sounds.play("levelUp")
				Toast.push(Text.now("huntshop.bought", { name = name }), "success")
				return true, nil
			end
			Sounds.play("error")
			return false, Text.now(err or "error.internal")
		end
		if entry.kind == "chest" then
			local marks = Contracts.stateOf({ contract = Fusion.peek(contract) }).marks
			props.ShowModal({
				Title = Text.now("huntshop.title"),
				Message = Text.now("huntshop.confirm", { name = name, price = price, left = marks - price })
					.. "\n"
					.. Text.now(`item.{entry.key}.desc`),
				ConfirmText = Text.now("huntshop.buy"),
				CancelText = Text.now("quest.back"),
				OnConfirm = function(): (boolean, string?)
					return send()
				end,
			})
			return
		end
		task.spawn(function()
			local ok, err = send()
			if not ok then
				Toast.push(err or Text.now("error.internal"), "error")
			end
		end)
	end

	local balance = scope:Computed(function(use): string
		local state = Contracts.stateOf({ contract = use(contract) })
		return Text.get(use, "contract.marks", { n = state.marks })
	end)

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local state = Contracts.stateOf({ contract = use(contract) })
		local lvl = use(level) or 1
		local classId = use(class) or "Warrior"
		local ownedMap = use(owned)
		local ownedSet: { [string]: boolean } = if type(ownedMap) == "table" then ownedMap else {}
		local here = use(props.NpcId) == Contracts.HUNTMASTER
		local isTouch = use(touch)
		local week = Time.weekNumber(Clock.now())
		local group = use(tab)
		local out: { Instance } = {}
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		if not here then
			table.insert(
				out,
				label(
					s,
					nextOrder(),
					Text.get(use, "huntshop.atHuntmaster"),
					Theme.TextSize.Small,
					Theme.Colors.Warning
				)
			)
		end
		local buttonWidth = if isTouch then 96 else 120
		for _, entry in Data.ENTRIES do
			if entry.group ~= group or not HuntShop.offered(entry, lvl) then
				continue
			end
			local price = HuntShop.priceAt(entry, lvl)
			local name = entryName(use, entry, lvl, classId)
			local isOwned = entry.kind == "cosmetic" and ownedSet[entry.id] == true
			local ok, err = HuntShop.canBuy(entry, state, lvl, week, 1, ownedSet)
			local notes: { string } = {}
			if entry.weeklyLimit then
				table.insert(
					notes,
					Text.get(use, "huntshop.weekly", {
						n = HuntShop.boughtThisWeek(entry, state, week),
						max = entry.weeklyLimit,
					})
				)
			end
			if not ok and err and not isOwned then
				local key = if err == "huntshop.error.level" then "huntshop.fromLevel" else err
				table.insert(notes, Text.get(use, key, { level = entry.minLevel or 1 }))
			end
			local action: Instance
			if isOwned then
				action = label(s, 4, Text.get(use, "huntshop.owned"), Theme.TextSize.Small, Theme.Colors.Success)
			else
				action = Button(s, {
					LayoutOrder = 4,
					Size = UDim2.fromOffset(buttonWidth, Theme.Size.MinTouch),
					Variant = "primary",
					Disabled = not ok or not here or use(busy),
					Text = Text.get(use, "huntshop.buy"),
					OnClick = function()
						buy(entry, name, price)
					end,
				})
			end
			table.insert(
				out,
				s:New("Frame")({
					LayoutOrder = nextOrder(),
					Size = UDim2.new(1, 0, 0, 64),
					BackgroundColor3 = Theme.Colors.Panel,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
						s:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0, 8),
						}),
						entryIcon(s, entry, lvl, classId),
						s:New("Frame")({
							LayoutOrder = 2,
							Size = UDim2.new(1, -(ICON + buttonWidth + 100 + 32), 1, 0),
							BackgroundTransparency = 1,
							[Children] = {
								s:New("UIListLayout")({
									SortOrder = Enum.SortOrder.LayoutOrder,
									VerticalAlignment = Enum.VerticalAlignment.Center,
								}),
								label(s, 1, name, Theme.TextSize.Small, Theme.Colors.Text, Theme.Fonts.BodyBold),
								if #notes > 0
									then label(
										s,
										2,
										table.concat(notes, " · "),
										Theme.TextSize.Small,
										Theme.Colors.TextMuted
									)
									else nil :: any,
							} :: any,
						}),
						s:New("Frame")({
							LayoutOrder = 3,
							Size = UDim2.fromOffset(100, 40),
							BackgroundTransparency = 1,
							[Children] = {
								s:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Horizontal,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									HorizontalAlignment = Enum.HorizontalAlignment.Right,
									Padding = UDim.new(0, 4),
								}),
								s:New("TextLabel")({
									LayoutOrder = 1,
									Size = UDim2.fromOffset(0, 24),
									AutomaticSize = Enum.AutomaticSize.X,
									BackgroundTransparency = 1,
									Text = tostring(price),
									FontFace = Theme.Fonts.BodyBold,
									TextSize = Theme.TextSize.Body,
									TextColor3 = Theme.Colors.Parchment,
								}),
								CurrencyIcon(s, {
									Currency = "huntmarks",
									Size = UDim2.fromOffset(20, 20),
									LayoutOrder = 2,
								}),
							},
						}),
						action,
					},
				})
			)
		end
		return out
	end)

	local tabList = {}
	for _, group in Data.GROUPS do
		table.insert(tabList, { id = group, label = Text.T(scope, `huntshop.group.{group}`) })
	end

	return {
		scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 6),
				}),
				CurrencyIcon(scope, { Currency = "huntmarks", Size = UDim2.fromOffset(22, 22), LayoutOrder = 1 }),
				scope:New("TextLabel")({
					LayoutOrder = 2,
					Size = UDim2.fromOffset(0, 28),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Text = balance,
					FontFace = Theme.Fonts.Heading,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.Gold,
				}),
			},
		}),
		Tabs(scope, {
			Tabs = tabList,
			Selected = tab,
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
			Scroll = true,
		}),
		scope:New("ScrollingFrame")({
			Position = UDim2.fromOffset(0, 40 + Theme.Size.MinTouch),
			Size = UDim2.new(1, 0, 1, -(40 + Theme.Size.MinTouch)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Colors.Border,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
				rows :: any,
			},
		}),
	}
end

return HuntShopWindow
