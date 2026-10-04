--!strict
-- Forge → Dismantling (DESIGN §7): select backpack equipment, see the materials you will get, "Dismantle";
-- quick buttons for all Common / Common + Uncommon. Epic and better ask for confirmation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Dismantle = require(ReplicatedStorage.Shared.Logic.Dismantle)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local SelectableSlot = require(script.Parent.Parent.Parent.Components.SelectableSlot)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function describe(list: any): string
	local parts = {}
	for _, material in list or {} do
		table.insert(parts, `{ItemText.name(material.id)} x{material.n}`)
	end
	return table.concat(parts, ", ")
end

local function Dismantle_(scope: Scope, showModal: (spec: any) -> ()): Instance
	local inventory = State.Value({ "character", "inventory" })
	local selected = scope:Value({} :: { [string]: boolean })

	local function run(name: string, arg: any)
		task.spawn(function()
			local ok, err, gained = Net.Invoke(name, arg)
			if ok then
				selected:set({})
				Sounds.play("levelUp")
				Toast.push(Text.now("smith.dismantle.done", { list = describe(gained) }), "success", 5)
			else
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	local function dismantleSelected()
		local inv = Fusion.peek(inventory) or {}
		local indices = {}
		local valuable = false
		for key in Fusion.peek(selected) do
			local item = inv[key]
			if item then
				table.insert(indices, tonumber(key))
				if item.rarity >= Rarities.EPIC then
					valuable = true
				end
			end
		end
		if #indices == 0 then
			Toast.push(Text.now("shop.error.nothing"), "warning")
			return
		end
		if valuable then
			showModal({
				Title = Text.now("smith.dismantle.confirm.title"),
				Message = Text.now("smith.dismantle.confirm.message"),
				ConfirmText = Text.now("smith.dismantle.button"),
				CancelText = Text.now("common.cancel"),
				Variant = "danger",
				OnConfirm = function(): (boolean, string?)
					run("Dismantle", indices)
					return true, nil
				end,
			})
		else
			run("Dismantle", indices)
		end
	end

	local grid = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		local keys = {}
		for key, item in use(inventory) or {} do
			if Dismantle.canDismantle(item) then
				table.insert(keys, tonumber(key) :: number)
			end
		end
		table.sort(keys)
		for _, index in keys do
			local key = tostring(index)
			table.insert(
				list,
				SelectableSlot(s, {
					Id = `dismantle:{key}`,
					LayoutOrder = index,
					Item = s:Computed(function(use2): Types.ItemInstance?
						local inv = use2(inventory)
						return if inv then inv[key] else nil
					end),
					Selected = s:Computed(function(use2): boolean
						return use2(selected)[key] == true
					end),
					OnToggle = function()
						local copy = table.clone(Fusion.peek(selected))
						copy[key] = if copy[key] then nil :: any else true
						selected:set(copy)
					end,
				})
			)
		end
		return list
	end)

	local preview = scope:Computed(function(use): string
		local inv = use(inventory) or {}
		local totals: { [string]: { min: number, max: number } } = {}
		for key in use(selected) do
			local item = inv[key]
			if item then
				for _, range in Dismantle.preview(item) do
					local entry = totals[range.id] or { min = 0, max = 0 }
					entry.min += range.min
					entry.max += range.max
					totals[range.id] = entry
				end
			end
		end
		local parts = {}
		for id, range in totals do
			local amount = if range.min == range.max then tostring(range.min) else `{range.min}–{range.max}`
			table.insert(parts, `{ItemText.get(use, id)} {amount}`)
		end
		table.sort(parts)
		return if #parts > 0 then `{Text.get(use, "smith.dismantle.preview")} {table.concat(parts, ", ")}` else ""
	end)

	return scope:New("Frame")({
		Name = "Dismantle",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("ScrollingFrame")({
				Size = UDim2.new(1, 0, 1, -110),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Colors.GoldDim,
				[Children] = {
					scope:New("UIGridLayout")({
						CellSize = UDim2.fromOffset(64, 64),
						CellPadding = UDim2.fromOffset(6, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					grid :: any,
				},
			}),
			scope:New("TextLabel")({
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -60),
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				Text = preview,
				TextWrapped = true,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Parchment,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
					}),
					Button(scope, {
						Size = UDim2.fromOffset(220, 50),
						Variant = "danger",
						Text = Text.T(scope, "smith.dismantle.button"),
						Disabled = scope:Computed(function(use): boolean
							return next(use(selected)) == nil
						end),
						OnClick = dismantleSelected,
					}),
					Button(scope, {
						Size = UDim2.fromOffset(190, 50),
						TextSize = Theme.TextSize.Small,
						Text = Text.T(scope, "smith.dismantle.common"),
						OnClick = function()
							run("DismantleAll", Rarities.COMMON)
						end,
					}),
					Button(scope, {
						Size = UDim2.fromOffset(220, 50),
						TextSize = Theme.TextSize.Small,
						Text = Text.T(scope, "smith.dismantle.uncommon"),
						OnClick = function()
							run("DismantleAll", Rarities.UNCOMMON)
						end,
					}),
				},
			}),
		},
	})
end

return Dismantle_
