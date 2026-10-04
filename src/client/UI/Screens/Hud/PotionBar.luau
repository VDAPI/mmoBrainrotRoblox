--!strict
-- Potion bar (DESIGN §9): three slots (health Z, mana X, energy V) showing the assigned potion, how many
-- are left and the cooldown. Click / tap drinks; drop a potion from the backpack to assign it; right-click
-- (or long-press on touch) opens a picker with the qualities you carry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local DragDrop = require(script.Parent.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	LayoutOrder: number?,
	Use: (kind: string) -> (),
	Assign: (kind: string, itemId: string?) -> (),
}

local SIZE = 56
local ROMAN = { "I", "II", "III", "IV", "V" }
local LONG_PRESS = 0.5

local KINDS: { { kind: string, key: string, color: Color3 } } = {
	{ kind = "hp", key = "Z", color = Theme.Colors.Hp },
	{ kind = "mana", key = "X", color = Theme.Colors.Mana },
	{ kind = "energy", key = "V", color = Theme.Colors.Energy },
}

local function PotionBar(scope: Scope, props: Props): Instance
	local inventory = State.Value({ "character", "inventory" })
	local potionBar = State.Value({ "character", "potionBar" })
	local cooldowns = State.Value({ "potions" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local picker = scope:Value(nil :: string?)

	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			if Fusion.peek(cooldowns) ~= nil then
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)

	local function count(inv: any, itemId: string?): number
		if not itemId or type(inv) ~= "table" then
			return 0
		end
		local n = 0
		for _, item in inv do
			if item.id == itemId then
				n += item.n
			end
		end
		return n
	end

	local slots = {}
	for index, entry in KINDS do
		local assigned = scope:Computed(function(use): string?
			local bar = use(potionBar)
			return if type(bar) == "table" then bar[entry.kind] else nil
		end)
		local amount = scope:Computed(function(use): number
			return count(use(inventory), use(assigned))
		end)
		local cooldown = scope:Computed(function(use): number
			local c = use(cooldowns)
			local ready = if type(c) == "table" then c[entry.kind] else nil
			if not ready then
				return 0
			end
			return math.clamp((ready - use(now)) / Config.PotionCooldown, 0, 1)
		end)
		local pressToken = 0

		local slot = scope:New("TextButton")({
			Name = `Potion_{entry.kind}`,
			LayoutOrder = index,
			Size = UDim2.fromOffset(SIZE, SIZE),
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.2,
			Text = "",
			[OnEvent("Activated")] = function()
				if os.clock() - DragDrop.LastDropAt < 0.3 then
					return
				end
				props.Use(entry.kind)
			end,
			[OnEvent("MouseButton2Click")] = function()
				picker:set(if Fusion.peek(picker) == entry.kind then nil else entry.kind)
			end,
			[OnEvent("InputBegan")] = function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.Touch then
					pressToken += 1
					local token = pressToken
					task.delay(LONG_PRESS, function()
						if token == pressToken then
							picker:set(entry.kind)
						end
					end)
				end
			end,
			[OnEvent("InputEnded")] = function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.Touch then
					pressToken += 1
				end
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = Theme.Stroke.Normal,
					Color = entry.color,
					Transparency = 0.3,
				}),
				scope:New("TextLabel")({
					Name = "Icon",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = "⚗",
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 30,
					TextColor3 = entry.color,
					TextTransparency = scope:Computed(function(use): number
						return if use(amount) > 0 then 0 else 0.7
					end),
				}),
				scope:New("TextLabel")({
					Name = "Quality",
					Position = UDim2.fromOffset(4, 2),
					Size = UDim2.fromOffset(20, 14),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						local id = use(assigned)
						local def = id and Items.get(id)
						return if def and def.tier then ROMAN[def.tier] or "" else ""
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 11,
					TextColor3 = Theme.Colors.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				scope:New("TextLabel")({
					Name = "Count",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -3, 1, -1),
					Size = UDim2.fromOffset(40, 16),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return tostring(use(amount))
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 14,
					TextColor3 = Theme.Colors.Text,
					TextStrokeTransparency = 0.2,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				scope:New("TextLabel")({
					Name = "Key",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -4, 0, 2),
					Size = UDim2.fromOffset(16, 14),
					BackgroundTransparency = 1,
					Text = entry.key,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 12,
					TextColor3 = Theme.Colors.TextMuted,
				}),
				-- Cooldown sweep (fills from the bottom)
				scope:New("Frame")({
					Name = "Cooldown",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = scope:Computed(function(use): UDim2
						return UDim2.fromScale(1, use(cooldown))
					end),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.45,
					ZIndex = 3,
					[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				}),
			},
		})
		DragDrop.register(scope, slot :: GuiObject, `pot:{entry.kind}`)
		Tooltip.attach(
			scope,
			slot :: GuiObject,
			scope:Computed(function(use): string
				local id = use(assigned)
				local head = Text.get(use, `potion.slot.{entry.kind}`)
				return if id then `{ItemText.get(use, id)}\n{head}` else head
			end)
		)
		table.insert(slots, slot)
	end

	-- Picker: the potion qualities of the opened kind found in the backpack.
	local pickerList = scope:Computed(function(use, s: Scope): { Instance }
		local kind = use(picker)
		if not kind then
			return {}
		end
		local inv = use(inventory) or {}
		local found: { [string]: number } = {}
		for _, item in inv do
			local def = Items.get(item.id)
			if def and def.use and def.use.kind == "potion" and def.use.resource == kind then
				found[item.id] = (found[item.id] or 0) + item.n
			end
		end
		local ids = {}
		for id in found do
			table.insert(ids, id)
		end
		table.sort(ids)
		local list: { Instance } = {}
		if #ids == 0 then
			table.insert(
				list,
				s:New("TextLabel")({
					Size = UDim2.fromOffset(240, 32),
					BackgroundTransparency = 1,
					Text = Text.get(use, "potion.pick.empty"),
					TextWrapped = true,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.Text,
				})
			)
		end
		for i, id in ids do
			table.insert(
				list,
				s:New("TextButton")({
					LayoutOrder = i,
					Size = UDim2.fromOffset(240, 34),
					AutoButtonColor = true,
					BackgroundColor3 = Theme.Colors.PanelRaised,
					Text = `{ItemText.get(use, id)} ({found[id]})`,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.Text,
					[OnEvent("Activated")] = function()
						picker:set(nil)
						props.Assign(kind, id)
					end,
					[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				})
			)
		end
		return list
	end)

	return scope:New("Frame")({
		Name = "PotionBar",
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(SIZE * 3 + 12, SIZE),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("Frame")({
				Name = "Slots",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					slots :: any,
				},
			}),
			scope:New("Frame")({
				Name = "Picker",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -8),
				Size = UDim2.fromOffset(252, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Panel,
				Visible = scope:Computed(function(use): boolean
					return use(picker) ~= nil
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 1 }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 6),
						PaddingBottom = UDim.new(0, 6),
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
					}),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					pickerList :: any,
				},
			}),
		},
	})
end

return PotionBar
