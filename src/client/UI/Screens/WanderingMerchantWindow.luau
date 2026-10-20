--!strict
-- The wandering merchant's goods (S159w, docs/DESIGN.md §8b, Logic/WanderingMerchant): the visit on top (where he stands
-- and how long he stays, or when and where he comes next), the gold and the Hunter's Marks, a tab per group (gear,
-- materials, the caravan dye, consumables) and every offer of the visit's stock with its icon, name, price, the visit's
-- limit "n/max" and why it cannot be bought now (Logic/WanderingMerchant.canBuy: the server's own rule,
-- `wanderer.error.*`). Gear shows its slot and rarity: the base for the character's class and the bonus lines are rolled
-- on purchase (asked first). Buying works only next to him (the window opens from his dialog and closes when the player
-- walks away). Built like the Huntmaster's shop (S134k), scrolling on a phone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local ClockText = require(script.Parent.Parent.ClockText)
local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local CurrencyIcon = require(script.Parent.Parent.Components.CurrencyIcon)
local Data = require(ReplicatedStorage.Shared.Data.WanderingMerchant)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Modal = require(script.Parent.Parent.Components.Modal)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local WanderingMerchant = require(ReplicatedStorage.Shared.Logic.WanderingMerchant)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use
type Offer = WanderingMerchant.Offer
type Visit = WanderingMerchant.Visit

export type Props = {
	NpcId: Fusion.UsedAs<string?>, -- the NPC the player talks to (NpcController.Current)
	ShowModal: (spec: Modal.Spec) -> (),
}

local ICON = 48

local function slotKey(slot: string?): string
	return if slot == "ring" then "slot.ring1" else `slot.{slot or "weapon"}`
end

local function rarityKey(rarity: number?): string
	local def = Rarities.get(rarity or Rarities.UNIQUE)
	return def.nameKey
end

-- The shown name of an offer at a level ("Heroic: Helmet", "Large Healing Potion ×10", a dye's name).
local function offerName(use: Use, offer: Offer, level: number, classId: string): string
	if offer.kind == "gear" then
		return Text.get(
			use,
			"wanderer.gear",
			{ rarity = Text.get(use, rarityKey(offer.rarity)), slot = Text.get(use, slotKey(offer.slot)) }
		)
	elseif offer.kind == "dye" then
		local def = if offer.id then Cosmetics.get(offer.id) else nil
		return if def then Text.get(use, def.nameKey) else tostring(offer.id)
	end
	local grant = WanderingMerchant.grant(offer, level, classId)
	if not grant then
		return offer.key
	end
	local name = ItemText.get(use, grant.id)
	return if grant.n > 1 then Text.get(use, "huntshop.stack", { name = name, n = grant.n }) else name
end

local function offerIcon(s: Scope, offer: Offer, level: number, classId: string): Instance
	if offer.kind == "gear" then
		return s:New("TextLabel")({
			LayoutOrder = 1,
			Size = UDim2.fromOffset(ICON, ICON),
			BackgroundTransparency = 1,
			Text = "▣",
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Title,
			TextColor3 = ItemText.rarityName(offer.rarity or Rarities.UNIQUE, "paper"),
		})
	elseif offer.kind == "dye" then
		local def = if offer.id then Cosmetics.get(offer.id) else nil
		return ArtIcon(s, {
			Key = UiArt.cosmetic(offer.id or ""),
			Glyph = if def then def.icon else "◐",
			GlyphColor = if def then Theme.readable(def.color, "paper") else Theme.Paper.Text,
			Size = UDim2.fromOffset(ICON, ICON),
			LayoutOrder = 1,
		})
	end
	local grant = WanderingMerchant.grant(offer, level, classId)
	return ItemIcon(s, {
		Def = if grant then Items.get(grant.id) else nil,
		Size = UDim2.fromOffset(ICON, ICON),
		LayoutOrder = 1,
	})
end

local function label(s: Scope, order: number, text: any, size: number, color: Color3, font: Font?): Instance
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

local function placeText(use: Use, visit: Visit): string
	local map = Maps.get(visit.spot.map)
	return Text.get(use, "wanderer.place", {
		place = Text.get(use, `wanderer.spot.{visit.spot.id}`),
		map = if map then Text.get(use, map.nameKey) else visit.spot.map,
	})
end

local function WanderingMerchantWindow(scope: Scope, props: Props): Fusion.Child
	local contract = State.Value({ "character", "quests", "contract" })
	local level = State.Value({ "character", "level" })
	local class = State.Value({ "character", "class" })
	local gold = State.Value({ "character", "gold" })
	local bought = State.Value({ "character", "wanderer" })
	local owned = State.Value({ "account", "cosmetics", "owned" })
	local tab = scope:Value(Data.groups[1] :: string)
	local busy = scope:Value(false)
	local touch = Device.Touch
	-- a tick a second: the countdown, and the stock switching when a visit ends
	local tick = scope:Value(Clock.now())
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(1)
			if alive then
				tick:set(Clock.now())
			end
		end
	end)
	local visitIndex = scope:Computed(function(use): number?
		local visit = WanderingMerchant.current(use(tick))
		return if visit then visit.index else nil
	end)

	local function buy(offer: Offer, name: string, price: number, visit: Visit)
		if Fusion.peek(busy) then
			return
		end
		local function send(): (boolean, string?)
			busy:set(true)
			local ok, err = Net.Invoke("WanderingMerchantBuy", offer.key, 1)
			busy:set(false)
			if ok then
				Sounds.play("levelUp")
				Toast.push(Text.now("wanderer.bought", { name = name }), "success")
				return true, nil
			end
			Sounds.play("error")
			return false, Text.now(err or "error.internal")
		end
		if offer.kind == "gear" or offer.currency == "marks" then
			local lvl = Fusion.peek(level) or 1
			props.ShowModal({
				Title = Text.now(Npcs.WANDERER.nameKey),
				Message = Text.now(if offer.currency == "marks" then "wanderer.confirmMarks" else "wanderer.confirm", {
					name = name,
					price = price,
					level = WanderingMerchant.ilvlOf(visit.band, lvl),
				}),
				ConfirmText = Text.now("wanderer.buy"),
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

	local header = scope:Computed(function(use): string
		local now = use(tick)
		local visit = WanderingMerchant.current(now)
		if visit then
			return Text.get(use, "wanderer.window.here", {
				place = placeText(use, visit),
				time = Time.format(math.max(0, visit.endsAt - now)),
			})
		end
		local nextVisit = WanderingMerchant.nextVisit(now)
		return Text.get(use, "wanderer.window.gone", {
			place = placeText(use, nextVisit),
			time = ClockText.hhmm(nextVisit.startsAt),
		})
	end)

	local balance = scope:Computed(function(use): string
		local marks = Contracts.stateOf({ contract = use(contract) }).marks
		return Text.get(use, "wanderer.window.wallet", { gold = use(gold) or 0, marks = marks })
	end)

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local index = use(visitIndex)
		local lvl = use(level) or 1
		local classId = use(class) or "Warrior"
		local ownedMap = use(owned)
		local ownedSet: { [string]: boolean } = if type(ownedMap) == "table" then ownedMap else {}
		local here = use(props.NpcId) == Npcs.WANDERER.id
		local isTouch = use(touch)
		local group = use(tab)
		local out: { Instance } = {}
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		if index == nil then
			table.insert(
				out,
				label(s, nextOrder(), Text.get(use, "wanderer.error.gone"), Theme.TextSize.Small, Theme.Paper.Warning)
			)
			return out
		end
		local visit = WanderingMerchant.visit(index)
		if not here then
			table.insert(
				out,
				label(
					s,
					nextOrder(),
					Text.get(use, "wanderer.window.atMerchant"),
					Theme.TextSize.Small,
					Theme.Paper.Warning
				)
			)
		end
		local buyer: WanderingMerchant.Buyer = {
			level = lvl,
			gold = use(gold) or 0,
			marks = Contracts.stateOf({ contract = use(contract) }).marks,
			bought = use(bought),
			owned = ownedSet,
		}
		local buttonWidth = if isTouch then 96 else 120
		for _, offer in WanderingMerchant.stock(index) do
			if offer.group ~= group then
				continue
			end
			local price = WanderingMerchant.priceOf(offer, lvl, visit.band, classId)
			local name = offerName(use, offer, lvl, classId)
			local isOwned = offer.kind == "dye" and offer.id ~= nil and ownedSet[offer.id] == true
			local ok, err = WanderingMerchant.canBuy(offer, index, visit.band, buyer, classId, 1)
			local notes: { string } = {
				Text.get(use, "wanderer.limit", {
					n = WanderingMerchant.boughtAt(buyer.bought, index, offer.key),
					max = offer.limit,
				}),
			}
			if offer.kind == "gear" then
				table.insert(
					notes,
					Text.get(use, "wanderer.gearLevel", { level = WanderingMerchant.ilvlOf(visit.band, lvl) })
				)
			end
			if not ok and err and not isOwned then
				local key = if err == "wanderer.error.level" then "wanderer.fromLevel" else err
				table.insert(notes, Text.get(use, key, { level = offer.minLevel }))
			end
			local action: Instance
			if isOwned then
				action = label(s, 4, Text.get(use, "huntshop.owned"), Theme.TextSize.Small, Theme.Paper.Success)
			else
				action = Button(s, {
					LayoutOrder = 4,
					Size = UDim2.fromOffset(buttonWidth, Theme.Size.MinTouch),
					Variant = "primary",
					Disabled = not ok or not here or use(busy),
					Text = Text.get(use, "wanderer.buy"),
					OnClick = function()
						buy(offer, name, price, visit)
					end,
				})
			end
			table.insert(
				out,
				s:New("Frame")({
					LayoutOrder = nextOrder(),
					Size = UDim2.new(1, 0, 0, 64),
					BackgroundColor3 = Theme.Paper.Surface,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
						s:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0, 8),
						}),
						offerIcon(s, offer, lvl, classId),
						s:New("Frame")({
							LayoutOrder = 2,
							Size = UDim2.new(1, -(ICON + buttonWidth + 100 + 32), 1, 0),
							BackgroundTransparency = 1,
							[Children] = {
								s:New("UIListLayout")({
									SortOrder = Enum.SortOrder.LayoutOrder,
									VerticalAlignment = Enum.VerticalAlignment.Center,
								}),
								label(
									s,
									1,
									name,
									Theme.TextSize.Small,
									if offer.kind == "gear"
										then ItemText.rarityName(offer.rarity or Rarities.UNIQUE, "paper")
										else Theme.Paper.Text,
									Theme.Fonts.BodyBold
								),
								label(s, 2, table.concat(notes, " · "), Theme.TextSize.Small, Theme.Paper.TextMuted),
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
									TextColor3 = Theme.Paper.Text,
								}),
								CurrencyIcon(s, {
									Currency = if offer.currency == "marks" then "huntmarks" else "gold",
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
	for _, group in Data.groups do
		table.insert(tabList, { id = group, label = Text.T(scope, `wanderer.group.{group}`) })
	end

	local top = 52
	return {
		scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, top - 6),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
				label(scope, 1, header, Theme.TextSize.Small, Theme.Paper.Heading, Theme.Fonts.BodyBold),
				label(scope, 2, balance, Theme.TextSize.Small, Theme.Paper.TextMuted),
			},
		}),
		Tabs(scope, {
			Tabs = tabList,
			Selected = tab,
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
			Scroll = true,
		}),
		scope:New("ScrollingFrame")({
			Position = UDim2.fromOffset(0, top + 6 + Theme.Size.MinTouch),
			Size = UDim2.new(1, 0, 1, -(top + 6 + Theme.Size.MinTouch)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Paper.Rule,
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

return WanderingMerchantWindow
