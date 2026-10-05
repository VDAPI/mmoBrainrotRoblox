--!strict
-- Item slot (DESIGN §23): placeholder icon (glyph on the item colour), rarity frame (glowing from Epic,
-- animated for Legendary, ornate for Unique), stack count, "+N" upgrade, lock when bound, red tint when the
-- character cannot use it. Interaction (select, drag & drop, double-click, tap) comes from UI/DragDrop;
-- the rich tooltip from ItemTooltip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DragDrop = require(script.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.ItemText)
local ItemTooltip = require(script.Parent.ItemTooltip)
local Elements = require(ReplicatedStorage.Shared.Data.Elements)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type UsedAs<T> = Fusion.UsedAs<T>
type ItemInstance = Types.ItemInstance

export type Props = {
	SlotId: string,
	Item: UsedAs<ItemInstance?>,
	Size: number?,
	Placeholder: string?, -- glyph shown when empty (equipment slots)
	LayoutOrder: UsedAs<number>?,
	Position: UsedAs<UDim2>?,
	Visible: UsedAs<boolean>?,
	Name: string?,
	-- Text shown on hover when the slot is empty.
	EmptyTooltip: UsedAs<string>?,
}

local function canUse(item: ItemInstance, level: number?, classId: string?): boolean
	local def = Items.get(item.id)
	if not def then
		return true
	end
	if level and ItemRoll.requiredLevel(item) > level then
		return false
	end
	if def.classes and classId and not table.find(def.classes, classId) then
		return false
	end
	return true
end

-- Rotating gradient shared by every legendary frame.
local spinScope = Fusion.scoped(Fusion)
local spin = spinScope:Value(0)
RunService.RenderStepped:Connect(function(dt: number)
	spin:set((Fusion.peek(spin) + dt * 90) % 360)
end)

local function ItemSlot(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local size = props.Size or 64
	local level = State.Value({ "character", "level" })
	local classId = State.Value({ "character", "class" })

	local item = scope:Computed(function(use): ItemInstance?
		return use(props.Item)
	end)
	local def = scope:Computed(function(use): Items.ItemDef?
		local i = use(item)
		return if i then Items.get(i.id) else nil
	end)
	local rarityColor = scope:Computed(function(use): Color3
		local i = use(item)
		return if i then ItemText.rarityColor(i.rarity) else Theme.Colors.Border
	end)
	local selected = scope:Computed(function(use): boolean
		return use(DragDrop.Selected) == props.SlotId
	end)
	local dragging = scope:Computed(function(use): boolean
		return use(DragDrop.Dragging) == props.SlotId
	end)
	local usable = scope:Computed(function(use): boolean
		local i = use(item)
		return i == nil or canUse(i, use(level), use(classId))
	end)

	local frame = scope:New("Frame")({
		Name = props.Name or props.SlotId,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Visible = props.Visible,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = scope:Computed(function(use): Color3
			if use(selected) then
				return Theme.Colors.PanelHover
			end
			return if use(usable) then Theme.Colors.Background else Color3.fromHex("#3A1A18")
		end),
		Active = true,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = scope:Computed(function(use): number
					local i = use(item)
					if use(selected) then
						return 3
					end
					return if i and i.rarity >= Rarities.EPIC then 2.5 else 1.5
				end),
				Color = scope:Computed(function(use): Color3
					return if use(selected) then Theme.Colors.GoldBright else use(rarityColor)
				end),
				Transparency = scope:Computed(function(use): number
					return if use(item) or use(selected) then 0 else 0.4
				end),
				[Children] = scope:Computed(function(use, s: Fusion.Scope<typeof(Fusion)>): Instance?
					local i = use(item)
					if not i or i.rarity ~= Rarities.LEGENDARY then
						return nil
					end
					return s:New("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromHex("#FF9F1C")),
							ColorSequenceKeypoint.new(0.5, Color3.fromHex("#FFE7A0")),
							ColorSequenceKeypoint.new(1, Color3.fromHex("#FF9F1C")),
						}),
						Rotation = spin,
					})
				end) :: any,
			}),
			-- Icon
			scope:New("Frame")({
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.78, 0.78),
				BackgroundColor3 = scope:Computed(function(use): Color3
					local d = use(def)
					-- Mage weapons take the colour of their element (S18).
					local current = use(item)
					local element = if current then ItemRoll.elementOf(current) else nil
					if element then
						return Color3.fromHex(Elements.COLORS[element])
					end
					return if d then Color3.fromHex(d.icon.color) else Theme.Colors.Background
				end),
				BackgroundTransparency = scope:Computed(function(use): number
					if use(dragging) then
						return 0.85
					end
					return if use(def) then 0.55 else 1
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIGradient")({
						Rotation = 90,
						Transparency = NumberSequence.new(0, 0.5),
					}),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = scope:Computed(function(use): string
							local d = use(def)
							return if d then d.icon.glyph else (props.Placeholder or "")
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextScaled = true,
						TextColor3 = scope:Computed(function(use): Color3
							return if use(def) then Theme.Colors.Text else Theme.Colors.Border
						end),
						TextTransparency = scope:Computed(function(use): number
							return if use(dragging) then 0.7 else 0
						end),
						[Children] = scope:New("UIPadding")({
							PaddingTop = UDim.new(0.12, 0),
							PaddingBottom = UDim.new(0.12, 0),
							PaddingLeft = UDim.new(0.12, 0),
							PaddingRight = UDim.new(0.12, 0),
						}),
					}),
				},
			}),
			-- Stack count
			scope:New("TextLabel")({
				Name = "Count",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -3, 1, -1),
				Size = UDim2.fromOffset(size - 6, 16),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local i = use(item)
					return if i and i.n > 1 then tostring(i.n) else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 14,
				TextColor3 = Theme.Colors.Text,
				TextStrokeTransparency = 0.2,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			-- Upgrade level
			scope:New("TextLabel")({
				Name = "Upgrade",
				Position = UDim2.fromOffset(3, 1),
				Size = UDim2.fromOffset(30, 16),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local i = use(item)
					return if i and i.up > 0 then `+{i.up}` else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 14,
				TextColor3 = Theme.Colors.GoldBright,
				TextStrokeTransparency = 0.2,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			-- Bound lock
			scope:New("TextLabel")({
				Name = "Bound",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 3, 1, -1),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					local i = use(item)
					local d = use(def)
					return i ~= nil and i.bound and d ~= nil and d.category == "equipment"
				end),
				Text = "⚿",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 13,
				TextColor3 = Theme.Colors.TextMuted,
			}),
		},
	})

	DragDrop.register(scope, frame :: GuiObject, props.SlotId)
	ItemTooltip.attach(scope, frame :: GuiObject, function(): ItemInstance?
		return Fusion.peek(item)
	end, props.EmptyTooltip, props.SlotId)
	return frame
end

return ItemSlot
