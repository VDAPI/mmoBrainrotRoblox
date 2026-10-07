--!strict
-- Backpack merchant (DESIGN §5.7): every backpack with capacity, level and price; "Buy and equip" puts the
-- old backpack into the new one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function BackpackShop(scope: Scope, npcId: Fusion.UsedAs<string?>): Fusion.Child
	local backpack = State.Value({ "character", "equipment", "backpack" })
	local level = State.Value({ "character", "level" })
	local gold = State.Value({ "character", "gold" })

	local defs = {}
	for _, def in Items.byId do
		if def.category == "backpack" and (def.buyPrice or 0) > 0 then
			table.insert(defs, def)
		end
	end
	table.sort(defs, function(a, b)
		return (a.capacity or 0) < (b.capacity or 0)
	end)

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
				Size = UDim2.new(1, 0, 0, 70),
				BackgroundColor3 = Theme.Colors.PanelRaised,
				BackgroundTransparency = 0.4,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					ItemSlot(scope, {
						SlotId = `view:backpack:{def.id}`,
						Item = ItemRoll.makeStack(def.id, 1, `preview:{def.id}`),
						Size = 56,
						Position = UDim2.fromOffset(7, 7),
						-- S31: "Price" in the tooltip = the row's price (ItemValue.buyPrice -> the backpack's buyPrice).
						TooltipCtx = { shopEntry = { item = def.id }, merchantOpen = false, hints = false },
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(74, 6),
						Size = UDim2.new(1, -260, 0, 26),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return ItemText.get(use, def.id)
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(74, 34),
						Size = UDim2.new(1, -260, 0, 22),
						BackgroundTransparency = 1,
						RichText = true,
						Text = scope:Computed(function(use): string
							local parts = {
								Text.get(use, "backpacks.capacity", { capacity = def.capacity or 0 }),
								Text.get(use, "shop.price", { price = Format.number(def.buyPrice or 0) }),
							}
							if def.level > 1 then
								local ok = (use(level) or 1) >= def.level
								local text = Text.get(use, "tooltip.requiresLevel", { level = def.level })
								table.insert(parts, if ok then text else `<font color="#CC5248">{text}</font>`)
							end
							return table.concat(parts, " · ")
						end),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.Parchment,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.fromOffset(170, 48),
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
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Colors.GoldDim,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
				rows :: any,
			},
		}),
	}
end

return BackpackShop
