--!strict
-- Item slot (DESIGN §23): placeholder icon (glyph on the item colour), rarity frame from the rarity's
-- `frame` data (S30: grey, yellow, blue with a glow, orange / red with a rotating gradient), stack count, "+N" upgrade, lock when bound, red tint when the
-- character cannot use it. Interaction (select, drag & drop, double-click, tap) comes from UI/DragDrop;
-- the rich tooltip from ItemTooltip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DragDrop = require(script.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemTooltip = require(script.Parent.ItemTooltip)
local Elements = require(ReplicatedStorage.Shared.Data.Elements)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local TooltipModel = require(ReplicatedStorage.Shared.Logic.TooltipModel)
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
	-- S29: drop highlight while an item is dragged / selected: "ok" (green) or "bad" (red), nil = none.
	DropHint: UsedAs<string?>?,
	-- S31: extra tooltip context (shop / shopEntry / merchantOpen / hints, see Logic/TooltipModel), a table or a
	-- function returning one when it is read (the tooltip opens).
	TooltipCtx: (TooltipModel.Ctx | () -> TooltipModel.Ctx?)?,
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

-- One rotation angle shared by every spinning frame (legendary, mythic): a single RenderStepped connection
-- for the whole UI, not one per slot.
local spinScope = Fusion.scoped(Fusion)
local spin = spinScope:Value(0)
RunService.RenderStepped:Connect(function(dt: number)
	spin:set((Fusion.peek(spin) + dt * 90) % 360)
end)

-- Selected slot: white outline and a lighter background (not gold: it would read as a Unique frame).
local SELECTED = Color3.new(1, 1, 1)
local SELECTED_BG = Theme.Colors.PanelHover:Lerp(Color3.new(1, 1, 1), 0.12)

-- Gradient of a frame (c1 → c2 → c1), cached per rarity.
local gradients: { [number]: ColorSequence } = {}
local function gradientOf(r: Rarities.RarityDef): ColorSequence
	local cached = gradients[r.id]
	if cached then
		return cached
	end
	local colors = r.frame.gradient or { r.color, r.color }
	local sequence = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors[1]),
		ColorSequenceKeypoint.new(0.5, colors[2]),
		ColorSequenceKeypoint.new(1, colors[1]),
	})
	gradients[r.id] = sequence
	return sequence
end

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
	local rarity = scope:Computed(function(use): Rarities.RarityDef?
		local i = use(item)
		return if i then Rarities.get(i.rarity) else nil
	end)
	local selected = scope:Computed(function(use): boolean
		return use(DragDrop.Selected) == props.SlotId
	end)
	local dragging = scope:Computed(function(use): boolean
		return use(DragDrop.Dragging) == props.SlotId
	end)
	local hint = scope:Computed(function(use): string?
		return if props.DropHint ~= nil then use(props.DropHint) else nil
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
				return SELECTED_BG
			end
			return if use(usable) then Theme.Colors.Background else Color3.fromHex("#3A1A18")
		end),
		Active = true,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			-- Rarity frame (S30): thickness / gradient / glow / spin from Rarities.get(r).frame. Drop hints (S29) and
			-- the selection replace it with a plain green / red / white outline so they never read as a rarity.
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = scope:Computed(function(use): number
					if use(selected) or use(hint) ~= nil then
						return 3
					end
					local r = use(rarity)
					return if r then r.frame.thickness else 1.5
				end),
				Color = scope:Computed(function(use): Color3
					local h = use(hint)
					if h == "ok" then
						return Theme.Colors.Success
					elseif h == "bad" then
						return Theme.Colors.DangerHover
					elseif use(selected) then
						return SELECTED
					end
					local r = use(rarity)
					if r and r.frame.gradient then
						return Color3.new(1, 1, 1) -- the gradient carries the colour
					end
					return if r then r.color else Theme.Colors.Border
				end),
				Transparency = scope:Computed(function(use): number
					return if use(item) or use(selected) or use(hint) ~= nil then 0 else 0.4
				end),
				[Children] = scope:Computed(function(use, s: Fusion.Scope<typeof(Fusion)>): Instance?
					local r = use(rarity)
					if not r or not r.frame.gradient or use(hint) ~= nil or use(selected) then
						return nil
					end
					return s:New("UIGradient")({
						Color = gradientOf(r),
						Rotation = if r.frame.spin then spin else 45,
					})
				end) :: any,
			}),
			-- Glow outside the frame (heroic and better; stronger with a thicker frame).
			scope:Computed(function(use, s: Fusion.Scope<typeof(Fusion)>): Instance?
				local r = use(rarity)
				if not r or not r.frame.glow or use(hint) ~= nil or use(selected) then
					return nil
				end
				local width = math.max(2, (r.frame.thickness - 1) * 2.5)
				return s:New("Frame")({
					Name = "Glow",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, math.ceil(r.frame.thickness * 2), 1, math.ceil(r.frame.thickness * 2)),
					BackgroundTransparency = 1,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
						s:New("UIStroke")({
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Thickness = width,
							Color = r.color,
							Transparency = if r.frame.spin then 0.45 else 0.6,
							[Children] = s:New("UIGradient")({
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.5, 0.5),
									NumberSequenceKeypoint.new(1, 0),
								}),
								Rotation = if r.frame.spin then spin else 90,
							}),
						}),
					},
				})
			end) :: any,
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
			-- Padlock (S20): protected from selling, dismantling and trading
			scope:New("TextLabel")({
				Name = "Locked",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -2, 0, 1),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					local i = use(item)
					return i ~= nil and i.locked == true
				end),
				Text = "🔒",
				TextScaled = true,
				TextColor3 = Theme.Colors.GoldBright,
				ZIndex = 3,
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

	local function getItem(): ItemInstance?
		return Fusion.peek(item)
	end
	DragDrop.register(scope, frame :: GuiObject, props.SlotId, getItem)
	local ctx = props.TooltipCtx
	local getCtx: (() -> TooltipModel.Ctx?)? = nil
	if type(ctx) == "function" then
		getCtx = ctx
	elseif ctx ~= nil then
		local fixed = ctx :: TooltipModel.Ctx
		getCtx = function(): TooltipModel.Ctx?
			return fixed
		end
	elseif string.sub(props.SlotId, 1, 5) == "view:" then
		-- Look-only slots cannot be equipped / used from here: no "double click" hint.
		getCtx = function(): TooltipModel.Ctx?
			return { hints = false }
		end
	end
	ItemTooltip.attach(scope, frame :: GuiObject, getItem, props.EmptyTooltip, props.SlotId, getCtx)
	return frame
end

return ItemSlot
