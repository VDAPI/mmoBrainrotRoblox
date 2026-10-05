--!strict
-- Auction window, "Sell" tab: pick an unbound backpack item (click or tap), set the price and 24/48 h; the
-- deposit, the fee and what reaches the mail are computed live, with the average market price of the item.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Auction = require(ReplicatedStorage.Shared.Logic.Auction)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Market = require(ReplicatedStorage.Shared.Data.Market)
local Net = require(ReplicatedStorage.Shared.Net)
local SelectableSlot = require(script.Parent.Parent.Parent.Components.SelectableSlot)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SLOT = 56

local function Sell(scope: Scope): Instance
	local inventory = State.Value({ "character", "inventory" })
	local gold = State.Value({ "character", "gold" })
	local selected = scope:Value(nil :: string?)
	local priceText = scope:Value("")
	local hours = scope:Value(Market.Auction.durations[1])
	local average = scope:Value(nil :: number?)
	local busy = scope:Value(false)

	local item = scope:Computed(function(use): any
		local key = use(selected)
		local inv = use(inventory)
		return if key and type(inv) == "table" then inv[key] else nil
	end)
	local price = scope:Computed(function(use): number?
		local n = tonumber(use(priceText))
		return if n and Auction.validPrice(n) then n else nil
	end)

	local function pick(key: string)
		selected:set(if Fusion.peek(selected) == key then nil else key)
		average:set(nil)
		local current = Fusion.peek(item)
		if current then
			task.spawn(function()
				local ok, value = Net.Invoke("AuctionPrice", current.id)
				if ok and Fusion.peek(item) == current then
					average:set(value)
				end
			end)
		end
	end

	local slots = scope:Computed(function(use, s: Scope): { Instance }
		local inv = use(inventory)
		local list = {}
		if type(inv) ~= "table" then
			return list
		end
		local keys = {}
		for key, entry in inv do
			if not entry.bound then
				table.insert(keys, key)
			end
		end
		table.sort(keys, function(a, b)
			return (tonumber(a) or 0) < (tonumber(b) or 0)
		end)
		for i, key in keys do
			table.insert(
				list,
				SelectableSlot(s, {
					Id = `auc:{key}`,
					Item = inv[key],
					Size = SLOT,
					LayoutOrder = i,
					Selected = s:Computed(function(use2): boolean
						return use2(selected) == key
					end),
					OnToggle = function()
						pick(key)
					end,
				})
			)
		end
		return list
	end)

	local function line(order: number, text: Fusion.UsedAs<string>, color: Color3?): Instance
		return scope:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Text = text,
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Body,
			TextColor3 = color or Theme.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end

	local function submit()
		local key = Fusion.peek(selected)
		local p = Fusion.peek(price)
		if not key or not p then
			Sounds.play("error")
			Toast.push(Text.now(if key then "auction.error.price" else "auction.error.noItem"), "error")
			return
		end
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("AuctionList", tonumber(key), p, Fusion.peek(hours))
			busy:set(false)
			if ok then
				Sounds.play("levelUp")
				Toast.push(Text.now("auction.listed"), "success")
				selected:set(nil)
				priceText:set("")
			else
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	local durationButtons = {}
	for i, h in Market.Auction.durations do
		table.insert(
			durationButtons,
			Button(scope, {
				LayoutOrder = i,
				Size = UDim2.new(0.5, -4, 0, 44),
				Variant = scope:Computed(function(use): any
					return if use(hours) == h then "primary" else "secondary"
				end),
				Text = Text.T(scope, "auction.hours", { hours = h }),
				OnClick = function()
					hours:set(h)
				end,
			})
		)
	end

	return scope:New("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("ScrollingFrame")({
				Size = UDim2.new(0.5, -8, 1, 0),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				[Children] = {
					scope:New("UIGridLayout")({
						CellSize = UDim2.fromOffset(SLOT, SLOT),
						CellPadding = UDim2.fromOffset(5, 5),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }),
					slots :: any,
				},
			}),
			scope:New("Frame")({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.5, -8, 1, 0),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
					line(
						1,
						scope:Computed(function(use): string
							local current = use(item)
							if not current then
								return Text.get(use, "auction.sell.pick")
							end
							local name = ItemText.get(use, current.id, current.up, current.el)
							return if current.n > 1 then `{name} x{current.n}` else name
						end),
						Theme.Colors.GoldBright
					),
					TextInput(scope, {
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 48),
						Text = priceText,
						MaxLength = 10,
						Placeholder = Text.T(scope, "auction.sell.price"),
					}),
					scope:New("Frame")({
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 44),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 8),
							}),
							durationButtons :: any,
						},
					}),
					line(
						4,
						scope:Computed(function(use): string
							local p = use(price)
							return Text.get(use, "auction.sell.deposit", {
								gold = if p then Format.number(Auction.deposit(p)) else "-",
							})
						end),
						Theme.Colors.TextMuted
					),
					line(
						5,
						scope:Computed(function(use): string
							local p = use(price)
							return Text.get(use, "auction.sell.fee", {
								pct = Market.Auction.feePct,
								gold = if p then Format.number(Auction.fee(p)) else "-",
							})
						end),
						Theme.Colors.TextMuted
					),
					line(
						6,
						scope:Computed(function(use): string
							local p = use(price)
							return Text.get(use, "auction.sell.payout", {
								gold = if p then Format.number(Auction.payout(p, Auction.deposit(p))) else "-",
							})
						end),
						Theme.Colors.Success
					),
					line(
						7,
						scope:Computed(function(use): string
							local avg = use(average)
							local current = use(item)
							if not current then
								return ""
							end
							if not avg then
								return Text.get(use, "auction.sell.noAverage")
							end
							return Text.get(use, "auction.sell.average", {
								gold = Format.number(avg),
								total = Format.number(avg * current.n),
							})
						end),
						Theme.Colors.Accent
					),
					line(
						8,
						scope:Computed(function(use): string
							local p = use(price)
							if p and (use(gold) or 0) < Auction.deposit(p) then
								return Text.get(use, "auction.error.deposit")
							end
							return ""
						end),
						Theme.Colors.Danger
					),
					Button(scope, {
						LayoutOrder = 9,
						Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
						Variant = "primary",
						Text = Text.T(scope, "auction.sell.button"),
						Disabled = scope:Computed(function(use): boolean
							return use(busy) or use(item) == nil or use(price) == nil
						end),
						OnClick = submit,
					}),
					scope:New("TextLabel")({
						LayoutOrder = 10,
						Size = UDim2.new(1, 0, 0, 60),
						BackgroundTransparency = 1,
						Text = Text.T(scope, "auction.sell.rules", {
							max = Market.Auction.maxListings,
							deposit = Market.Auction.depositPct,
							fee = Market.Auction.feePct,
						}),
						TextWrapped = true,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
				},
			}),
		},
	})
end

return Sell
