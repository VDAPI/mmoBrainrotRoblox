--!strict
-- Item tooltip (DESIGN §23). The content comes from the pure Logic/TooltipModel (S31: header, stats or effect
-- of every category, requirements, comparison with the equipped item (green ↑ / red ↓), binding, value and the
-- context price); this module only draws the lines on a parchment panel that follows the mouse, with the S30
-- rarity border. On touch it appears for the selected slot.
--
-- Context: `attach(..., getCtx)` may pass a function returning TooltipModel.Ctx fields (`shop`, `shopEntry`,
-- `potionDiscount`, `merchantOpen`, `hints`); language, character level/class and the equipped item are filled
-- in here. `ItemTooltip.setMerchantOpen(true)` while a merchant window is open adds "Sells for" everywhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Device = require(script.Parent.Parent.Device)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.Parent.IconState)
local ItemIcon = require(script.Parent.ItemIcon)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Scale = require(script.Parent.Parent.Scale)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TooltipModel = require(ReplicatedStorage.Shared.Logic.TooltipModel)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type ItemInstance = Types.ItemInstance
type Scope = Fusion.Scope<typeof(Fusion)>

local ItemTooltip = {}

local WIDTH = 340
local OFFSET = Vector2.new(20, 20)
local ICON_SIZE = 44 -- S35: item picture next to the name (the atlas cell is 128 px)
local DARK = Theme.Colors.TextDark
local MUTED = Color3.fromHex("#6B5E48")
local GOOD = Color3.fromHex("#2E8B3E")
local BAD = Color3.fromHex("#B8423A")

local moduleScope = Fusion.scoped(Fusion)
local shown = moduleScope:Value(nil :: ItemInstance?)
local emptyText = moduleScope:Value(nil :: string?)
local position = moduleScope:Value(Vector2.zero)
local shownCtx = moduleScope:Value(nil :: TooltipModel.Ctx?)
local merchantOpen = moduleScope:Value(false)
local owner: GuiObject? = nil
local getters: { [string]: () -> ItemInstance? } = {}
local ctxGetters: { [string]: () -> TooltipModel.Ctx? } = {}

type CtxGetter = () -> TooltipModel.Ctx?

-- A merchant window is open: backpack tooltips add "Sells for: X gold" (shop windows call this).
function ItemTooltip.setMerchantOpen(open: boolean)
	merchantOpen:set(open == true)
end

-- Equipped item to compare with (same slot group; rings compare with ring1).
local function equippedFor(def: Items.ItemDef): ItemInstance?
	if not def.slot or def.slot == "backpack" then
		return nil
	end
	local equipment = State.Get({ "character", "equipment" })
	if type(equipment) ~= "table" then
		return nil
	end
	if def.slot == "ring" then
		return equipment.ring1 or equipment.ring2
	end
	return equipment[def.slot]
end

-- Content ---------------------------------------------------------------------------------------------------

local function line(s: Scope, order: number, text: string, color: Color3, size: number?, font: Font?): Instance
	return s:New("TextLabel")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		RichText = true,
		TextWrapped = true,
		FontFace = font or Theme.Fonts.BodyMedium,
		TextSize = size or Theme.TextSize.Small,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- Legendary bonus lines take the Legendary rarity's parchment text colour (S30: from data, not hard-coded).
local LEGENDARY_LINE = Rarities.get(Rarities.LEGENDARY).textColor

local function bonusRow(s: Scope, order: number, text: string, quality: number, legendary: boolean): Instance
	return s:New("Frame")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		[Children] = {
			s:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -54, 1, 0),
				Text = text,
				TextWrapped = true,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = if legendary then LEGENDARY_LINE else Color3.fromHex("#1F4E9A"),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			s:New("Frame")({
				Name = "Quality",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(46, 6),
				BackgroundColor3 = Color3.fromHex("#CDBF9C"),
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					s:New("Frame")({
						Size = UDim2.fromScale(math.clamp(quality, 0.05, 1), 1),
						BackgroundColor3 = if quality >= 0.9
							then LEGENDARY_LINE
							elseif quality >= 0.5 then GOOD
							else MUTED,
						[Children] = s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					}),
				},
			}),
		},
	})
end

local TONES: { [string]: Color3 } = {
	dark = DARK,
	muted = MUTED,
	good = GOOD,
	bad = BAD,
	bonus = Color3.fromHex("#1F4E9A"),
	legendary = LEGENDARY_LINE,
}
local SIZES: { [string]: number } = {
	large = Theme.TextSize.Large,
	body = Theme.TextSize.Body,
	small = Theme.TextSize.Small,
}
local FONTS: { [string]: Font } = {
	heading = Theme.Fonts.Heading,
	bold = Theme.Fonts.BodyBold,
	medium = Theme.Fonts.BodyMedium,
}

local function build(
	s: Scope,
	item: ItemInstance,
	lang: string,
	extra: TooltipModel.Ctx?,
	merchant: boolean
): { Instance }
	local def = Items.get(item.id)
	local ctx: TooltipModel.Ctx = {
		lang = lang,
		level = State.Get({ "character", "level" }) or 1,
		class = State.Get({ "character", "class" }),
		equipped = if def then equippedFor(def) else nil,
		merchantOpen = merchant,
	}
	if extra then
		for k, v in extra :: any do
			(ctx :: any)[k] = v
		end
	end
	local out: { Instance } = {}
	for order, entry in TooltipModel.build(item, def, ctx).lines do
		if entry.kind == "bonus" then
			table.insert(out, bonusRow(s, order, entry.text, entry.quality or 0, entry.legendary == true))
		else
			local color = if entry.hex then Color3.fromHex(entry.hex) else TONES[entry.tone] or DARK
			local size = if entry.size then SIZES[entry.size] else nil
			local font = if entry.font then FONTS[entry.font] else nil
			table.insert(out, line(s, order, entry.text, color, size, font))
		end
	end
	return out
end

-- Show / hide -----------------------------------------------------------------------------------------------

local function show(object: GuiObject, item: ItemInstance?, text: string?, at: Vector2, ctx: TooltipModel.Ctx?)
	owner = object
	shownCtx:set(ctx)
	shown:set(item)
	emptyText:set(if item then nil else text)
	position:set(at)
end

local function hide(object: GuiObject?)
	if object == nil or owner == object then
		owner = nil
		shown:set(nil)
		emptyText:set(nil)
	end
end

function ItemTooltip.hide()
	hide(nil)
end

function ItemTooltip.attach(
	scope: Scope,
	object: GuiObject,
	getItem: () -> ItemInstance?,
	empty: Fusion.UsedAs<string>?,
	slotId: string,
	getCtx: CtxGetter?
)
	table.insert(
		scope,
		object.MouseEnter:Connect(function(x, y)
			if UserInputService.MouseEnabled then
				local text = if empty then Fusion.peek(empty) else nil
				local item = getItem()
				if item or text then
					show(object, item, text, Scale.toVirtual(Vector2.new(x, y)), if getCtx then getCtx() else nil)
				end
			end
		end)
	)
	table.insert(
		scope,
		object.MouseMoved:Connect(function(x, y)
			if owner == object then
				position:set(Scale.toVirtual(Vector2.new(x, y)))
			end
		end)
	)
	table.insert(
		scope,
		object.MouseLeave:Connect(function()
			hide(object)
		end)
	)
	table.insert(scope, function()
		hide(object)
	end)
	-- Touch: the selected slot shows its tooltip (DragDrop.Selected).
	getters[slotId] = getItem
	if getCtx then
		ctxGetters[slotId] = getCtx
	end
	table.insert(scope, function()
		if getters[slotId] == getItem then
			getters[slotId] = nil
			ctxGetters[slotId] = nil
		end
	end)
	table.insert(
		scope,
		object:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			if owner == object and Fusion.peek(Device.Touch) then
				local p = Scale.toVirtual(object.AbsolutePosition)
				position:set(p)
			end
		end)
	)
end

-- Builds the floating panel inside `parent` (Tooltip layer root).
function ItemTooltip.mount(scope: Scope, parent: Instance)
	scope:Observer(DragDrop.Selected):onChange(function()
		if not Fusion.peek(Device.Touch) then
			return
		end
		local selected = Fusion.peek(DragDrop.Selected)
		local getter = selected and getters[selected]
		local item = getter and getter()
		if item then
			local screen = Fusion.peek(Scale.VirtualSize)
			owner = nil
			local ctxGetter = selected and ctxGetters[selected]
			shownCtx:set(if ctxGetter then ctxGetter() else nil)
			shown:set(item)
			emptyText:set(nil)
			position:set(Vector2.new(screen.X / 2 - WIDTH / 2 - OFFSET.X, 70))
		else
			hide(nil)
		end
	end)

	local shownDef = scope:Computed(function(use): Items.ItemDef?
		local item = use(shown)
		return if item then Items.get(item.id) else nil
	end)
	local showIcon = scope:Computed(function(use): boolean
		return use(IconState.Art) and use(shownDef) ~= nil
	end)
	scope:New("Frame")({
		Name = "ItemTooltip",
		Parent = parent,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Parchment,
		Visible = scope:Computed(function(use): boolean
			return (use(shown) ~= nil or use(emptyText) ~= nil) and use(DragDrop.Dragging) == nil
		end),
		ZIndex = 200,
		Position = scope:Computed(function(use): UDim2
			local p: Vector2 = use(position)
			local screen: Vector2 = use(Scale.VirtualSize)
			local x = p.X + OFFSET.X
			if x + WIDTH > screen.X - 8 then
				x = p.X - OFFSET.X - WIDTH
			end
			return UDim2.fromOffset(math.max(8, x), math.max(8, math.min(p.Y + OFFSET.Y, screen.Y - 200)))
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				Thickness = 2,
				Color = scope:Computed(function(use): Color3
					local item = use(shown)
					return if item then ItemText.rarityColor(item.rarity) else Theme.Colors.GoldDim
				end),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
			}),
			-- S35: the item's picture in the top right corner (only with the atlases; the glyph is not repeated here).
			scope:New("Frame")({
				Name = "IconHolder",
				LayoutOrder = 0,
				Size = UDim2.fromScale(1, 0),
				BackgroundTransparency = 1,
				[Children] = ItemIcon(scope, {
					Def = shownDef,
					Element = scope:Computed(function(use): string?
						local item = use(shown)
						return if item then ItemRoll.elementOf(item) else nil
					end),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
					Visible = showIcon,
				}),
			}),
			scope:Computed(function(use, s: Scope): { Instance }
				local item = use(shown)
				local lang = use(Text.Lang)
				if item then
					local lines = build(s, item, lang, use(shownCtx), use(merchantOpen))
					-- The name and the category line keep clear of the picture.
					if use(showIcon) then
						for i = 1, math.min(2, #lines) do
							s:New("UIPadding")({ PaddingRight = UDim.new(0, ICON_SIZE + 6), Parent = lines[i] })
						end
					end
					return lines
				end
				local text = use(emptyText)
				return if text then { line(s, 1, text, DARK) } else {}
			end) :: any,
		},
	})
end

return ItemTooltip
