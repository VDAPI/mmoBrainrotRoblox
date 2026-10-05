--!strict
-- Scroll of Unbinding: pick one of your bound items (backpack or equipped) to unbind it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local SelectableSlot = require(script.Parent.Parent.Components.SelectableSlot)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function UnbindPicker(scope: Scope, close: () -> ()): Fusion.Child
	local inventory = State.Value({ "character", "inventory" })
	local equipment = State.Value({ "character", "equipment" })

	local slots = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		local order = 0
		local function add(location: string, key: string, item: Types.ItemInstance)
			order += 1
			table.insert(
				list,
				SelectableSlot(s, {
					Id = `unbind:{location}:{key}`,
					LayoutOrder = order,
					Item = item,
					Selected = false,
					OnToggle = function()
						task.spawn(function()
							local ok, err = Net.Invoke("UnbindItem", location, key)
							if ok then
								Sounds.play("levelUp")
								Toast.push(
									Text.now("scroll.unbind.done", { name = ItemText.name(item.id, item.up, item.el) }),
									"success"
								)
								close()
							else
								Toast.push(Text.now(err or "error.internal"), "error")
							end
						end)
					end,
				})
			)
		end
		for slot, item in use(equipment) or {} do
			local def = Items.get(item.id)
			if item.bound and slot ~= "backpack" and def and def.category == "equipment" then
				add("eq", slot, item)
			end
		end
		for key, item in use(inventory) or {} do
			local def = Items.get(item.id)
			if item.bound and def and def.category == "equipment" then
				add("inv", key, item)
			end
		end
		if #list == 0 then
			table.insert(
				list,
				s:New("TextLabel")({
					Size = UDim2.fromOffset(400, 30),
					BackgroundTransparency = 1,
					Text = Text.get(use, "scroll.unbind.none"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.TextMuted,
				})
			)
		end
		return list
	end)

	return {
		scope:New("TextLabel")({
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = Text.T(scope, "scroll.unbind.pick"),
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Colors.Parchment,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("ScrollingFrame")({
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 1, -40),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIGridLayout")({
					CellSize = UDim2.fromOffset(64, 64),
					CellPadding = UDim2.fromOffset(6, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				slots :: any,
			},
		}),
	}
end

return UnbindPicker
