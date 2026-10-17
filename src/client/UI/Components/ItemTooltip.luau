--!strict
-- Item tooltip (DESIGN §23). The content comes from the pure Logic/TooltipModel (S31; S134g: name, the head line
-- "Kind · Category · Level N · Classes", the rarity in small type, the main value, the statistics in small type in
-- fixed groups with thin gaps, trait, skill effects, description, "Replaces", binding, value and the context price);
-- this module only draws the lines on a parchment panel that follows the mouse, with the S30 rarity border. On touch
-- it appears for the selected slot. S134g: no comparison numbers; the comparison is the second panel below.
--
-- Context: `attach(..., getCtx)` may pass a function returning TooltipModel.Ctx fields (`shop`, `shopEntry`,
-- `potionDiscount`, `merchantOpen`, `hints`); language, character level/class and the equipped item are filled
-- in here. `ItemTooltip.setMerchantOpen(true)` while a merchant window is open adds "Sells for" everywhere.
-- FIX 2026-10-09: any slot except the equipment itself also shows the equipped item of that slot in a second
-- panel next to the first one, so the stats can be compared side by side.
-- S68 (STATY 11): every bonus line and the trait section open a details panel (TooltipModel.details). Touch: a tap
-- on the line or its "i" icon in the open tooltip (holding a slot stays the action menu; DragDrop.SetBlocker keeps
-- taps on the panels away from the slots below). PC: holding the "item_details" key (default Alt) pins the tooltip,
-- then pointing at a line opens its details next to it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ArtIcon = require(script.Parent.ArtIcon)
local Device = require(script.Parent.Parent.Device)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.Parent.IconState)
local ItemIcon = require(script.Parent.ItemIcon)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemScore = require(ReplicatedStorage.Shared.Logic.ItemScore)
local ItemTraits = require(ReplicatedStorage.Shared.Data.ItemTraits)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Keybinds = require(script.Parent.Parent.Keybinds)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Scale = require(script.Parent.Parent.Scale)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TooltipModel = require(ReplicatedStorage.Shared.Logic.TooltipModel)
local Types = require(ReplicatedStorage.Shared.Types)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.UiArtState)

local Children, OnEvent, Out = Fusion.Children, Fusion.OnEvent, Fusion.Out

type ItemInstance = Types.ItemInstance
type Scope = Fusion.Scope<typeof(Fusion)>

local ItemTooltip = {}

local WIDTH = 340
local OFFSET = Vector2.new(20, 20)
local ICON_SIZE = 44 -- S35: item picture next to the name (the atlas cell is 128 px)
-- S135: the tooltip is on iron (dark surface, parchment-coloured text, brass edge); colours from the roles.
local DARK = Theme.Iron.Text
local MUTED = Theme.Iron.TextMuted
local GOOD = Theme.Iron.Success
local BAD = Theme.Iron.Danger
local BONUS = Theme.Iron.Link

-- A colour from game data or TooltipModel (made for parchment) as text on the iron tooltip: a rarity's parchment name
-- colour becomes its night colour (Rarities.nightHex), anything else is lightened to 4.5:1 (Theme.readable).
local NIGHT_OF: { [string]: string } = {}
for _, r in Rarities.list do
	NIGHT_OF[string.upper(r.textHex)] = r.nightHex
	NIGHT_OF[string.upper(r.hex)] = r.nightHex
end
local function nightHex(hex: string): string
	return NIGHT_OF[string.upper(hex)] or Theme.readableHex(hex, "iron")
end
local function night(hex: string): Color3
	return Theme.readable(nightHex(hex), "iron")
end
-- RichText from TooltipModel carries parchment colours (`<font color="#…">`): the same mapping for each.
local function nightText(text: string): string
	return (
		string.gsub(text, 'color="(#%x%x%x%x%x%x)"', function(hex: string): string
			return `color="{nightHex(hex)}"`
		end)
	)
end

local moduleScope = Fusion.scoped(Fusion)
local shown = moduleScope:Value(nil :: ItemInstance?)
local emptyText = moduleScope:Value(nil :: string?)
local position = moduleScope:Value(Vector2.zero)
local shownCtx = moduleScope:Value(nil :: TooltipModel.Ctx?)
local merchantOpen = moduleScope:Value(false)
local shownSlot = moduleScope:Value(nil :: string?)
local GAP = 8
local GROUP_GAP = 4 -- S134g: the thin space between two stat groups (role "gap")
local owner: GuiObject? = nil
local getters: { [string]: () -> ItemInstance? } = {}
-- Root of the layer the tooltip is mounted in (FIX 2026-10-14: GUI points are measured from it, Scale.toLayer).
local layerRoot: GuiObject? = nil
local ctxGetters: { [string]: () -> TooltipModel.Ctx? } = {}
-- FIX 2026-10-15: while a modal is open (e.g. "bind and equip?") no item tooltip is shown; slots under the
-- modal still get MouseEnter and the panel covered the question.
local blocked = false

-- S68: the open details panel and the PC pin.
type OpenDetail = {
	ref: TooltipModel.DetailRef,
	item: ItemInstance,
	ctx: TooltipModel.Ctx,
	anchor: GuiObject,
	side: "right" | "below",
	at: Vector2, -- virtual pixels: top left of the anchor row
	size: Vector2, -- virtual pixels: anchor row size
	edge: number, -- virtual x of the right edge of the tooltip panel holding the row
	left: number, -- virtual x of the left edge of the whole panel group
}
local detail = moduleScope:Value(nil :: OpenDetail?)
local pinned = moduleScope:Value(false)
local overOwner = false
local DETAIL_GAP = 6
local ICON = 18 -- "i" icon on touch

type CtxGetter = () -> TooltipModel.Ctx?

-- A merchant window is open: backpack tooltips add "Sells for: X gold" (shop windows call this).
function ItemTooltip.setMerchantOpen(open: boolean)
	merchantOpen:set(open == true)
end

-- S138: the leading direction and the equipped weapon's pool (ItemScore.contextFor).
local function scoreContext(): ItemScore.Context
	return ItemScore.contextFor(State.Get({ "character" }))
end

-- Equipped item to compare with: the one the item would replace (S68: ItemScore.replaced, rings the weaker one, the
-- same as the "Better item" card; nil while a ring slot is free).
local function equippedFor(def: Items.ItemDef): ItemInstance?
	local equipment = State.Get({ "character", "equipment" })
	if type(equipment) ~= "table" then
		return nil
	end
	return ItemScore.replaced(def, equipment, scoreContext())
end

-- Content ---------------------------------------------------------------------------------------------------

local function line(s: Scope, order: number, text: string, color: Color3, size: number?, font: Font?): Instance
	return s:New("TextLabel")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = nightText(text),
		RichText = true,
		TextWrapped = true,
		FontFace = font or Theme.Fonts.BodyMedium,
		TextSize = size or Theme.TextSize.Small,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- Legendary bonus lines take the Legendary rarity's parchment text colour (S30: from data, not hard-coded).
local LEGENDARY_LINE = Rarities.get(Rarities.LEGENDARY).nightColor
local MYTHIC_LINE = Rarities.get(Rarities.MYTHIC).nightColor

local function bonusRow(
	s: Scope,
	order: number,
	text: string,
	quality: number,
	legendary: boolean,
	mythic: boolean,
	icon: Instance?
): Instance
	return s:New("Frame")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		[Children] = {
			icon,
			s:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, if icon then -54 - ICON - 4 else -54, 1, 0),
				Text = text,
				TextWrapped = true,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = if mythic then MYTHIC_LINE elseif legendary then LEGENDARY_LINE else BONUS,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			s:New("Frame")({
				Name = "Quality",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(46, 6),
				BackgroundColor3 = Theme.Iron.Raised,
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
	bonus = BONUS,
	legendary = LEGENDARY_LINE,
	trait = night(ItemTraits.COLOR), -- S62 trait section
}
local SIZES: { [string]: number } = {
	large = Theme.TextSize.Large,
	body = Theme.TextSize.Body,
	small = Theme.TextSize.Small,
}
local FONTS: { [string]: Font } = {
	heading = Theme.Fonts.Display,
	bold = Theme.Fonts.BodyBold,
	medium = Theme.Fonts.BodyMedium,
}

-- "i" icon of a row with details (touch only): a gold circle with the letter drawn as text.
local function infoIcon(s: Scope, anchor: Vector2, position: UDim2): Instance
	return s:New("Frame")({
		Name = "Info",
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundColor3 = Theme.Brass.Bright,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			s:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "i",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Surface,
			}),
		},
	})
end

-- The tooltip panel ("Item" or "Equipped") a row belongs to.
local function panelOf(object: GuiObject): GuiObject?
	local node: Instance? = object
	while node do
		if node:IsA("GuiObject") and (node.Name == "Item" or node.Name == "Equipped") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function closeDetail()
	detail:set(nil)
end

-- Opens the details of `ref` next to (PC) or below (touch) its row.
local function openDetail(ref: TooltipModel.DetailRef, item: ItemInstance, ctx: TooltipModel.Ctx, anchor: GuiObject)
	local panel = panelOf(anchor)
	local group = panel and panel.Parent
	local root = layerRoot
	local function toLayer(point: Vector2): Vector2
		return if root then Scale.toLayer(point, root) else Scale.toVirtual(point)
	end
	local edge = if panel then toLayer(panel.AbsolutePosition + panel.AbsoluteSize).X else 0
	local left = if group and group:IsA("GuiObject") then toLayer(group.AbsolutePosition).X else 0
	detail:set({
		ref = ref,
		item = item,
		ctx = ctx,
		anchor = anchor,
		side = if Fusion.peek(Device.Touch) then "below" else "right",
		at = toLayer(anchor.AbsolutePosition),
		size = Scale.toVirtual(anchor.AbsoluteSize),
		edge = edge,
		left = left,
	})
end

-- A tooltip row that opens its details: a tap / click toggles them, pointing at it while pinned opens them.
local function detailRow(
	s: Scope,
	order: number,
	children: { Instance },
	ref: TooltipModel.DetailRef,
	item: ItemInstance,
	ctx: TooltipModel.Ctx
): Instance
	local button: GuiObject? = nil
	button = s:New("TextButton")({
		Name = "DetailRow",
		LayoutOrder = order,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		[OnEvent("Activated")] = function()
			local open = Fusion.peek(detail)
			if open and open.anchor == button then
				closeDetail()
			elseif button then
				openDetail(ref, item, ctx, button)
			end
		end,
		[OnEvent("MouseEnter")] = function()
			if button and Fusion.peek(pinned) and not Fusion.peek(Device.Touch) then
				openDetail(ref, item, ctx, button)
			end
		end,
		[OnEvent("MouseLeave")] = function()
			local open = Fusion.peek(detail)
			if open and open.anchor == button and not Fusion.peek(Device.Touch) then
				closeDetail()
			end
		end,
		[Children] = children :: any,
	}) :: any
	return button :: GuiObject
end

local function build(
	s: Scope,
	item: ItemInstance,
	lang: string,
	extra: TooltipModel.Ctx?,
	merchant: boolean
): { Instance }
	local def = Items.get(item.id)
	local equipment = State.Get({ "character", "equipment" })
	local gear: { [string]: any } = if type(equipment) == "table" then equipment else {}
	local touch = Fusion.peek(Device.Touch)
	-- A worn item is not compared against anything (e.g. the other ring).
	local worn = false
	for _, other in gear do
		if type(other) == "table" and other.uid == item.uid then
			worn = true
		end
	end
	local ctx: TooltipModel.Ctx = {
		lang = lang,
		level = State.Get({ "character", "level" }) or 1,
		class = State.Get({ "character", "class" }),
		equipped = if def and not worn then equippedFor(def) else nil,
		merchantOpen = merchant,
		pathId = scoreContext().pathId,
		nodes = State.Get({ "character", "path", "nodes" }),
		mainHand = gear.weapon,
		offhand = gear.offhand,
		input = if touch then "touch" else "mouse",
		detailsKey = Keybinds.label("item_details"),
	}
	if extra then
		for k, v in extra :: any do
			(ctx :: any)[k] = v
		end
	end
	local out: { Instance } = {}
	for order, entry in TooltipModel.build(item, def, ctx).lines do
		if entry.role == "gap" then
			-- S134g: a thin space between two stat groups
			table.insert(
				out,
				s:New("Frame")({
					Name = "Gap",
					LayoutOrder = order,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, GROUP_GAP),
				})
			)
			continue
		end
		local ref = entry.detail
		local bonus = entry.kind == "bonus"
		local icon: Instance? = nil
		if ref and touch then
			icon = if bonus
				then infoIcon(s, Vector2.new(1, 0.5), UDim2.new(1, -52, 0.5, 0))
				else infoIcon(s, Vector2.new(1, 0), UDim2.fromScale(1, 0))
		end
		local row: Instance
		if bonus then
			-- S134j: the locked reroll line carries the reroll mark, no new colour
			local text = if entry.rerolled then `{entry.text} {TooltipModel.REROLL_MARK}` else entry.text
			row = bonusRow(s, order, text, entry.quality or 0, entry.legendary == true, entry.mythic == true, icon)
		else
			local color = if entry.hex then night(entry.hex) else TONES[entry.tone] or DARK
			local size = if entry.size then SIZES[entry.size] else nil
			local font = if entry.font then FONTS[entry.font] else nil
			local label = line(s, order, entry.text, color, size, font) :: TextLabel
			if icon then
				label.Size = UDim2.new(1, -(ICON + 4), 0, 0)
			end
			-- S119: the element's tile in front of the "Element:" line once loaded.
			local element = if entry.role == "element" and item then ItemRoll.elementOf(item) else nil
			if element and UiArtState.lookNow(UiArt.element(element)) then
				local padding = Instance.new("UIPadding")
				padding.PaddingLeft = UDim.new(0, 22)
				padding.Parent = label
				local art = ArtIcon.Image(s, {
					Key = UiArt.element(element),
					Size = UDim2.fromOffset(16, 16),
					Position = UDim2.new(0, -21, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Corner = UDim.new(0, 3),
				})
				art.Parent = label
			end
			row = label
		end
		if ref then
			local children: { Instance } = { row }
			if icon and not bonus then
				table.insert(children, icon)
			end
			table.insert(out, detailRow(s, order, children, ref, item, ctx))
		else
			table.insert(out, row)
		end
	end
	return out
end

-- Show / hide -----------------------------------------------------------------------------------------------

local function show(
	object: GuiObject,
	item: ItemInstance?,
	text: string?,
	at: Vector2,
	ctx: TooltipModel.Ctx?,
	slotId: string
)
	owner = object
	shownSlot:set(slotId)
	shownCtx:set(ctx)
	shown:set(item)
	emptyText:set(if item then nil else text)
	position:set(at)
end

local function hide(object: GuiObject?)
	if object == nil or owner == object then
		owner = nil
		overOwner = false
		pinned:set(false)
		detail:set(nil)
		shown:set(nil)
		emptyText:set(nil)
	end
end

function ItemTooltip.hide()
	hide(nil)
end

-- WindowManager: true while a modal is visible (hides the tooltip and keeps it hidden).
function ItemTooltip.setBlocked(value: boolean)
	blocked = value
	if value then
		hide(nil)
	end
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
			if owner == object then
				overOwner = true
			end
			-- S68: a pinned tooltip stays on its item while the mouse travels to its lines.
			if UserInputService.MouseEnabled and not Fusion.peek(pinned) and not blocked then
				local text = if empty then Fusion.peek(empty) else nil
				local item = getItem()
				if item or text then
					local at = Scale.toVirtual(Vector2.new(x, y))
					show(object, item, text, at, if getCtx then getCtx() else nil, slotId)
					overOwner = true
				end
			end
		end)
	)
	table.insert(
		scope,
		object.MouseMoved:Connect(function(x, y)
			if owner == object and not Fusion.peek(pinned) then
				position:set(Scale.toVirtual(Vector2.new(x, y)))
			end
		end)
	)
	table.insert(
		scope,
		object.MouseLeave:Connect(function()
			if owner == object then
				overOwner = false
			end
			if not Fusion.peek(pinned) then
				hide(object)
			end
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
				local root = layerRoot
				position:set(
					if root
						then Scale.toLayer(object.AbsolutePosition, root)
						else Scale.toVirtual(object.AbsolutePosition)
				)
			end
		end)
	)
end

-- Builds the floating panel inside `parent` (Tooltip layer root).
function ItemTooltip.mount(scope: Scope, parent: Instance)
	layerRoot = if parent:IsA("GuiObject") then parent else nil
	scope:Observer(DragDrop.Selected):onChange(function()
		if not Fusion.peek(Device.Touch) then
			return
		end
		local selected = Fusion.peek(DragDrop.Selected)
		local getter = selected and getters[selected]
		local item = getter and getter()
		if item and not blocked then
			local screen = Fusion.peek(Scale.VirtualSize)
			owner = nil
			shownSlot:set(selected)
			local ctxGetter = selected and ctxGetters[selected]
			shownCtx:set(if ctxGetter then ctxGetter() else nil)
			shown:set(item)
			emptyText:set(nil)
			position:set(Vector2.new(screen.X / 2 - WIDTH - OFFSET.X, 70))
		else
			hide(nil)
		end
	end)

	local shownDef = scope:Computed(function(use): Items.ItemDef?
		local item = use(shown)
		return if item then Items.get(item.id) else nil
	end)
	local showIcon = scope:Computed(function(use): boolean
		local item = use(shown)
		return IconState.picture(use, use(shownDef), if item then ItemRoll.elementOf(item) else nil) ~= nil
	end)
	-- The equipped item of the hovered item's slot (not for the equipment slots themselves).
	local compared = scope:Computed(function(use): ItemInstance?
		local item = use(shown)
		local def = use(shownDef)
		local slot = use(shownSlot)
		if not item or not def or (slot and string.sub(slot, 1, 3) == "eq:") then
			return nil
		end
		local equipped = equippedFor(def)
		return if equipped and equipped.uid ~= item.uid then equipped else nil
	end)
	local mainPanel = scope:New("Frame")({
		Name = "Item",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Iron.Surface,
		ZIndex = 200,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				Thickness = 2,
				Color = scope:Computed(function(use): Color3
					local item = use(shown)
					return if item then ItemText.rarityColor(item.rarity) else Theme.Brass.Line
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
					-- The name, the head line and the rarity line keep clear of the picture.
					if use(showIcon) then
						for i = 1, math.min(3, #lines) do
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
	local comparePanel = scope:New("Frame")({
		Name = "Equipped",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Iron.Surface,
		ZIndex = 200,
		Visible = scope:Computed(function(use): boolean
			return use(compared) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				Thickness = 2,
				Color = scope:Computed(function(use): Color3
					local item = use(compared)
					return if item then ItemText.rarityColor(item.rarity) else Theme.Brass.Line
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
			scope:Computed(function(use, s: Scope): { Instance }
				local item = use(compared)
				if not item then
					return {}
				end
				local lang = use(Text.Lang)
				local lines = build(s, item, lang, { hints = false }, use(merchantOpen))
				table.insert(lines, 1, line(s, 0, Text.get(use, "tooltip.equipped"), MUTED, nil, Theme.Fonts.BodyBold))
				return lines
			end) :: any,
		},
	})
	local root = scope:New("Frame")({
		Name = "ItemTooltip",
		Parent = parent,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Visible = scope:Computed(function(use): boolean
			return (use(shown) ~= nil or use(emptyText) ~= nil) and use(DragDrop.Dragging) == nil
		end),
		ZIndex = 200,
		Position = scope:Computed(function(use): UDim2
			local p: Vector2 = use(position)
			local screen: Vector2 = use(Scale.VirtualSize)
			local width = if use(compared) then 2 * WIDTH + GAP else WIDTH
			local x = p.X + OFFSET.X
			if x + width > screen.X - 8 then
				x = p.X - OFFSET.X - width
			end
			return UDim2.fromOffset(math.max(8, x), math.max(8, math.min(p.Y + OFFSET.Y, screen.Y - 200)))
		end),
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				Padding = UDim.new(0, GAP),
			}),
			comparePanel,
			mainPanel,
		},
	})

	-- S68: details panel ------------------------------------------------------------------------------------------
	scope:Observer(shown):onChange(closeDetail)
	local detailSize = scope:Value(Vector2.zero)
	local model = scope:Computed(function(use): TooltipModel.Details?
		local open = use(detail)
		if not open then
			return nil
		end
		local ctx = table.clone(open.ctx)
		ctx.lang = use(Text.Lang)
		return TooltipModel.details(open.item, open.ref, ctx)
	end)
	local detailPanel = scope:New("Frame")({
		Name = "ItemDetail",
		Parent = parent,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Iron.Surface,
		ZIndex = 210,
		Visible = scope:Computed(function(use): boolean
			return use(model) ~= nil and use(shown) ~= nil and use(DragDrop.Dragging) == nil
		end),
		Position = scope:Computed(function(use): UDim2
			local open = use(detail)
			local screen: Vector2 = use(Scale.VirtualSize)
			local height = use(detailSize).Y / use(Scale.Value)
			if not open then
				return UDim2.fromOffset(0, 0)
			end
			local x, y
			if open.side == "right" then
				x = open.edge + DETAIL_GAP
				if x + WIDTH > screen.X - 8 then
					x = open.left - DETAIL_GAP - WIDTH
				end
				y = open.at.Y
			else
				x = open.edge - WIDTH
				y = open.at.Y + open.size.Y + 4
				if y + height > screen.Y - 8 then
					y = open.at.Y - 4 - height
				end
			end
			return UDim2.fromOffset(math.max(8, x), math.clamp(y, 8, math.max(8, screen.Y - 8 - height)))
		end),
		[Out("AbsoluteSize")] = detailSize,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				Thickness = 2,
				Color = scope:Computed(function(use): Color3
					local m = use(model)
					local tier = if m then m.tier else "regular"
					return if tier == "trait"
						then TONES.trait
						elseif tier == "mythic" then MYTHIC_LINE
						elseif tier == "legendary" then LEGENDARY_LINE
						else TONES.bonus
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
				Padding = UDim.new(0, 4),
			}),
			scope:Computed(function(use, s: Scope): { Instance }
				local m = use(model)
				if not m then
					return {}
				end
				local title = line(s, 1, m.title, DARK, Theme.TextSize.Body, Theme.Fonts.BodyBold)
				if use(Device.Touch) then
					-- Touch: "×" in the title row closes the panel.
					s:New("UIPadding")({ PaddingRight = UDim.new(0, 26), Parent = title })
					s:New("TextButton")({
						Name = "Close",
						Parent = title,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 28, 0, -6),
						Size = UDim2.fromOffset(28, 28),
						BackgroundTransparency = 1,
						Text = "×",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = MUTED,
						[OnEvent("Activated")] = closeDetail,
					})
				end
				local out: { Instance } = { title }
				for i, row in m.rows do
					local color = if row.role == "does"
							or row.role == "growth"
							or row.role == "nodes"
							or row.role == "weapon"
						then DARK
						else MUTED
					local font = if row.role == "growth" then Theme.Fonts.BodyBold else nil
					table.insert(out, line(s, i + 1, row.text, color, Theme.TextSize.Small, font))
				end
				return out
			end) :: any,
		},
	})

	-- PC: holding the details key pins the tooltip (it stops following the mouse); releasing it unpins.
	table.insert(
		scope,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if
					Keybinds.is(input.KeyCode, "item_details")
					and UserInputService:GetFocusedTextBox() == nil
					and not Fusion.peek(Device.Touch)
					and Fusion.peek(shown) ~= nil
				then
					pinned:set(true)
				end
			elseif input.UserInputType == Enum.UserInputType.Touch then
				-- A tap outside the details panel and its row closes it (deferred: a tap on another row opens that one).
				local open = Fusion.peek(detail)
				if open then
					local point = Vector2.new(input.Position.X, input.Position.Y)
					task.defer(function()
						if Fusion.peek(detail) ~= open then
							return
						end
						local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
						if not playerGui then
							return
						end
						for _, object in playerGui:GetGuiObjectsAtPosition(point.X, point.Y) do
							if
								object == detailPanel
								or object:IsDescendantOf(detailPanel)
								or object == open.anchor
								or object:IsDescendantOf(open.anchor)
							then
								return
							end
						end
						closeDetail()
					end)
				end
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Keyboard and Fusion.peek(pinned) then
				if Keybinds.is(input.KeyCode, "item_details") then
					pinned:set(false)
					closeDetail()
					if not overOwner then
						hide(nil)
					end
				end
			end
		end)
	)

	-- Touch: taps on the open tooltip panels never reach the slots below them.
	DragDrop.SetBlocker(function(point: Vector2): boolean
		if Fusion.peek(shown) == nil then
			return false
		end
		local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return false
		end
		for _, object in playerGui:GetGuiObjectsAtPosition(point.X, point.Y) do
			if object == detailPanel or object:IsDescendantOf(detailPanel) or object:IsDescendantOf(root) then
				return true
			end
		end
		return false
	end)
	table.insert(scope, function()
		DragDrop.SetBlocker(nil)
	end)
end

return ItemTooltip
