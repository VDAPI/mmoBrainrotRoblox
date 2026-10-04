--!strict
-- Trade window (DESIGN §18): you on the left, the partner on the right. Each side: 12 slots, gold, accept
-- state (green frame). Drag items from the backpack onto your side (or double-click them), click an item
-- on your side to take it back. After both accept: 3 s countdown, then both press Confirm. Warnings for an
-- empty partner side and a big difference in value (sum of sell prices).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local SLOTS = 12
local SLOT = 60

local function invoke(name: string, ...: any): boolean
	local ok, err = Net.Invoke(name, ...)
	if not ok then
		Sounds.play("error")
		Toast.push(Text.now(err or "error.internal"), "error")
	end
	return ok
end

local function value(side: any): number
	if type(side) ~= "table" then
		return 0
	end
	local total = side.gold or 0
	for _, item in side.items or {} do
		total += ItemRoll.sellPrice(item)
	end
	return total
end

local function grid(scope: Scope, sideKey: string, editable: boolean): Instance
	local trade = State.Value({ "trade" })
	local slots = {}
	for i = 1, SLOTS do
		local item = scope:Computed(function(use): Types.ItemInstance?
			local t = use(trade)
			local side = if type(t) == "table" then t[sideKey] else nil
			return if side and side.items then side.items[i] else nil
		end)
		local slot = ItemSlot(scope, {
			SlotId = if editable then `trade:{i}` else `view:trade:{sideKey}:{i}`,
			Size = SLOT,
			LayoutOrder = i,
			Item = item,
		})
		if editable then
			scope:New("TextButton")({
				Name = "Take",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 5,
				Parent = slot,
				Visible = scope:Computed(function(use): boolean
					return use(item) ~= nil
				end),
				[OnEvent("Activated")] = function()
					local current = Fusion.peek(item)
					if current then
						task.spawn(invoke, "TradeRemoveItem", current.uid)
					end
				end,
			})
		end
		table.insert(slots, slot)
	end
	return scope:New("Frame")({
		Name = "Grid",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.fromOffset(4 * (SLOT + 6), 3 * (SLOT + 6)),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIGridLayout")({
				CellSize = UDim2.fromOffset(SLOT, SLOT),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			slots :: any,
		},
	})
end

local function column(
	scope: Scope,
	sideKey: string,
	title: Fusion.UsedAs<string>,
	position: UDim2,
	editable: boolean
): Instance
	local trade = State.Value({ "trade" })
	local gold = scope:Value("0")
	local accepted = scope:Computed(function(use): boolean
		local t = use(trade)
		return type(t) == "table" and t[sideKey] ~= nil and t[sideKey].accepted == true
	end)
	return scope:New("Frame")({
		Name = sideKey,
		Position = position,
		Size = UDim2.fromOffset(4 * (SLOT + 6) + 16, 330),
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.4,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({
				Thickness = 3,
				Color = scope:Computed(function(use): Color3
					return if use(accepted) then Theme.Colors.Success else Theme.Colors.Border
				end),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundTransparency = 1,
				Text = title,
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.Gold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			grid(scope, sideKey, editable),
			if editable
				then TextInput(scope, {
					Position = UDim2.fromOffset(0, 250),
					Size = UDim2.new(1, -90, 0, 40),
					Text = gold,
					Placeholder = Text.T(scope, "trade.gold"),
					OnSubmit = function(text: string)
						local amount = tonumber(text)
						if amount then
							task.spawn(invoke, "TradeSetGold", math.max(0, math.floor(amount)))
						end
					end,
				})
				else scope:New("TextLabel")({
					Position = UDim2.fromOffset(0, 250),
					Size = UDim2.new(1, 0, 0, 40),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						local t = use(trade)
						local side = if type(t) == "table" then t[sideKey] else nil
						return `◉ {Format.number(if side then side.gold else 0)}`
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.GoldBright,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			if editable
				then Button(scope, {
					Position = UDim2.new(1, -84, 0, 250),
					Size = UDim2.fromOffset(84, 40),
					TextSize = Theme.TextSize.Small,
					Text = Text.T(scope, "trade.setGold"),
					OnClick = function()
						local amount = tonumber(Fusion.peek(gold))
						if amount then
							task.spawn(invoke, "TradeSetGold", math.max(0, math.floor(amount)))
						end
					end,
				}) :: any
				else nil :: any,
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(0, 292),
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local t = use(trade)
					local side = if type(t) == "table" then t[sideKey] else nil
					local mark = if side and side.confirmed
						then Text.get(use, "trade.confirmedMark")
						elseif side and side.accepted then Text.get(use, "trade.acceptedMark")
						else ""
					return `{Text.get(use, "trade.value", { value = Format.number(value(side)) })}  {mark}`
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Parchment,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
end

local function TradeWindow(scope: Scope): Fusion.Child
	local trade = State.Value({ "trade" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			now:set(Workspace:GetServerTimeNow())
		end)
	)
	local phase = scope:Computed(function(use): string
		local t = use(trade)
		return if type(t) == "table" then t.phase else "edit"
	end)
	local myAccepted = scope:Computed(function(use): boolean
		local t = use(trade)
		return type(t) == "table" and t.mine.accepted == true
	end)

	local width = 4 * (SLOT + 6) + 16
	return {
		column(scope, "mine", Text.T(scope, "trade.you"), UDim2.fromOffset(0, 0), true),
		column(
			scope,
			"theirs",
			scope:Computed(function(use): string
				local t = use(trade)
				return if type(t) == "table" then t.partner else ""
			end),
			UDim2.fromOffset(width + 24, 0),
			false
		),
		scope:New("TextLabel")({
			Name = "Warning",
			Position = UDim2.fromOffset(0, 340),
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			TextWrapped = true,
			Text = scope:Computed(function(use): string
				local t = use(trade)
				if type(t) ~= "table" then
					return ""
				end
				if t.preview then
					return Text.get(use, "trade.preview")
				end
				local mine, theirs = value(t.mine), value(t.theirs)
				if #(t.theirs.items or {}) == 0 and (t.theirs.gold or 0) == 0 then
					return Text.get(use, "trade.warnEmpty")
				end
				if mine > 0 and theirs < mine * 0.5 then
					return Text.get(use, "trade.warnValue")
				end
				return ""
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.Warning,
		}),
		scope:New("Frame")({
			Name = "Actions",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 12),
				}),
				Button(scope, {
					LayoutOrder = 1,
					Size = UDim2.fromOffset(200, 54),
					Variant = scope:Computed(function(use): any
						return if use(myAccepted) then "secondary" else "primary"
					end),
					Text = scope:Computed(function(use): string
						return Text.get(use, if use(myAccepted) then "trade.unaccept" else "trade.accept")
					end),
					OnClick = function()
						task.spawn(invoke, "TradeAccept", not Fusion.peek(myAccepted))
					end,
				}),
				Button(scope, {
					LayoutOrder = 2,
					Size = UDim2.fromOffset(220, 54),
					Variant = "primary",
					Text = scope:Computed(function(use): string
						local t = use(trade)
						if use(phase) == "countdown" and type(t) == "table" and t.confirmAt then
							return Text.get(use, "trade.wait", { n = math.max(0, math.ceil(t.confirmAt - use(now))) })
						end
						return Text.get(use, "trade.confirm")
					end),
					Disabled = scope:Computed(function(use): boolean
						return use(phase) ~= "confirm"
					end),
					OnClick = function()
						task.spawn(invoke, "TradeConfirm")
					end,
				}),
			},
		}),
	}
end

return TradeWindow
