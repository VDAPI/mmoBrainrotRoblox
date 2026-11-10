--!strict
-- Backpack merchant (DESIGN §5.7): every backpack with capacity, level and price; "Buy and equip" puts the
-- old backpack into the new one. S121: with Merchant's Pockets each row adds "(n with Merchant's Pockets)".
-- Owner 2026-11-10 (UI plan L10): a row's text ran under its button on a narrow window. The icon, the two lines and
-- the button now stand where Logic/GearLayout.backpackShop puts them from the list's measured width (a narrower button
-- under 560 px), and both lines end before the button, cut at their end (the slot's tooltip has the rest).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Inventory = require(ReplicatedStorage.Shared.Logic.Inventory)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GearLayout = require(ReplicatedStorage.Shared.Logic.GearLayout)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Scale = require(script.Parent.Parent.Scale)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children, Out = Fusion.Children, Fusion.Out

type Scope = Fusion.Scope<typeof(Fusion)>

-- the list's size on PC (640 x 640) until it is measured
local AREA_PC = { w = 596, h = 544 }

local function BackpackShop(scope: Scope, npcId: Fusion.UsedAs<string?>): Fusion.Child
	local backpack = State.Value({ "character", "equipment", "backpack" })
	local level = State.Value({ "character", "level" })
	local gold = State.Value({ "character", "gold" })
	local pockets = State.Value({ "passes", "pockets" })

	local defs = {}
	for _, def in Items.byId do
		if def.category == "backpack" and (def.buyPrice or 0) > 0 then
			table.insert(defs, def)
		end
	end
	table.sort(defs, function(a, b)
		return (a.capacity or 0) < (b.capacity or 0)
	end)

	-- a row's parts (GearLayout.backpackShop) from the list's own size
	local absolute = scope:Value(Vector2.zero)
	local row = scope:Computed(function(use): GearLayout.ShopRow
		local size: Vector2 = use(absolute)
		local k: number = use(Scale.Value)
		return GearLayout.backpackShop(if size.Y > 0 and k > 0 then { w = size.X / k, h = size.Y / k } else AREA_PC)
	end)
	local function at(pick: (GearLayout.ShopRow) -> GearLayout.Rect, top: number?): Fusion.Computed<UDim2>
		return scope:Computed(function(use): UDim2
			local r = pick(use(row))
			return UDim2.fromOffset(r.left, top or r.top)
		end)
	end
	local function wide(pick: (GearLayout.ShopRow) -> GearLayout.Rect, height: number?): Fusion.Computed<UDim2>
		return scope:Computed(function(use): UDim2
			local r = pick(use(row))
			return UDim2.fromOffset(r.right - r.left, height or (r.bottom - r.top))
		end)
	end
	local function textRect(r: GearLayout.ShopRow): GearLayout.Rect
		return r.text
	end
	local function buttonRect(r: GearLayout.ShopRow): GearLayout.Rect
		return r.button
	end

	local rows = {}
	for i, def in defs do
		local isCurrent = scope:Computed(function(use): boolean
			local item = use(backpack)
			return item ~= nil and item.id == def.id
		end)
		table.insert(
			rows,
			scope:New("Frame")({
				Name = def.id,
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, GearLayout.SHOP_ROW.height),
				BackgroundColor3 = Theme.Paper.Raised,
				BackgroundTransparency = 0.4,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					ItemSlot(scope, {
						SlotId = `view:backpack:{def.id}`,
						Item = ItemRoll.makeStack(def.id, 1, `preview:{def.id}`),
						Size = GearLayout.SHOP_ROW.icon,
						Position = UDim2.fromOffset(7, 7),
						-- S31: "Price" in the tooltip = the row's price (ItemValue.buyPrice -> the backpack's buyPrice).
						TooltipCtx = { shopEntry = { item = def.id }, merchantOpen = false, hints = false },
					}),
					scope:New("TextLabel")({
						Position = at(textRect),
						Size = wide(textRect, 26),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return ItemText.get(use, def.id)
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Paper.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					scope:New("TextLabel")({
						Position = at(textRect, 34),
						Size = wide(textRect, 22),
						TextTruncate = Enum.TextTruncate.AtEnd,
						BackgroundTransparency = 1,
						RichText = true,
						Text = scope:Computed(function(use): string
							local parts = {
								Text.get(use, "backpacks.capacity", { capacity = def.capacity or 0 }),
								Text.get(use, "shop.price", { price = Format.number(def.buyPrice or 0) }),
							}
							if use(pockets) == true then
								parts[1] ..= " " .. Text.get(use, "backpacks.withPockets", {
									n = Inventory.capacityOf(def.id, true),
								})
							end
							if def.level > 1 then
								local ok = (use(level) or 1) >= def.level
								local text = Text.get(use, "tooltip.requiresLevel", { level = def.level })
								table.insert(
									parts,
									if ok then text else `<font color="{Theme.hex(Theme.Paper.Danger)}">{text}</font>`
								)
							end
							return table.concat(parts, " · ")
						end),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Button(scope, {
						Position = at(buttonRect),
						Size = wide(buttonRect),
						Variant = "primary",
						Text = scope:Computed(function(use): string
							return Text.get(use, if use(isCurrent) then "backpacks.current" else "backpacks.buy")
						end),
						Disabled = scope:Computed(function(use): boolean
							return use(isCurrent)
								or (use(level) or 1) < def.level
								or (use(gold) or 0) < (def.buyPrice or 0)
						end),
						OnClick = function()
							local id = Fusion.peek(npcId)
							if not id then
								return
							end
							task.spawn(function()
								local ok, err = Net.Invoke("BuyBackpack", id, def.id)
								if ok then
									Sounds.play("levelUp")
									Toast.push(Text.now("backpacks.bought"), "success")
								else
									Sounds.play("error")
									Toast.push(Text.now(err or "error.internal", { level = def.level }), "error")
								end
							end)
						end,
					}),
				},
			})
		)
	end

	return {
		scope:New("ScrollingFrame")({
			Size = UDim2.fromScale(1, 1),
			[Out("AbsoluteSize")] = absolute,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Paper.Rule,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, GearLayout.SHOP_ROW.scroll) }),
				rows :: any,
			},
		}),
	}
end

return BackpackShop
