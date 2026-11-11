--!strict
-- Item tooltip (DESIGN §23). The content comes from the pure Logic/TooltipModel (S31; S134g: name, the head line
-- "Kind · Category · Level N · Classes", the rarity in small type, the main value, the statistics in small type in
-- fixed groups with thin gaps, trait, skill effects, description, "Replaces", binding, value and the context price);
-- this module only draws the lines on a parchment panel that follows the mouse, with the S30 rarity border. On touch
-- it appears for the selected slot.
--
-- Context: `attach(..., getCtx)` may pass a function returning TooltipModel.Ctx fields (`shop`, `shopEntry`,
-- `potionDiscount`, `merchantOpen`, `hints`); language, character level/class, the equipped item and the comparison
-- are filled in here. `ItemTooltip.setMerchantOpen(true)` while a merchant window is open adds "Sells for" everywhere.
-- Owner 2026-10-31 (replaces the FIX 2026-10-09 second panel with the worn item): the hovered item's own tooltip
-- shows the change of each number against what equipping it takes off (Logic/ItemCompare: rings the weaker one, a
-- two-hander also the off-hand; only items the character can equip now, never a worn one), in every window and on
-- touch. The worn item's own tooltip shows when its equipment slot is pointed at.
-- S68 (STATY 11): every bonus line and the trait section open a details panel (TooltipModel.details). Touch: a tap
-- on the line or its "i" icon in the open tooltip (holding a slot stays the action menu; DragDrop.SetBlocker keeps
-- taps on the panels away from the slots below). PC: holding the "item_details" key (default Alt) pins the tooltip,
-- then pointing at a line opens its details next to it.
-- 2026-10-21 (owner: descriptions too long): the tooltip opens compact (TooltipModel view "compact": name, head, rarity,
-- main value, the first stat rows, trait and effects in one line each, a price only where it matters). Holding the
-- details key shows the full tooltip (and pins it, as above); on touch the "More ▸" / "Less ▾" row switches, and every
-- new item starts compact again.
-- Owner 2026-11-10 ("things covering each other"), UI package C: the tooltip stands where Logic/Popover puts it, from
-- its measured height. PC: 20 right of and 20 under the cursor (Popover.ITEM), left of it at the right edge, rising at
-- the bottom, always 8 inside the safe area (it was placed for a 200-px tooltip and ran off the bottom). Touch: on the
-- half of the screen away from the tapped slot (Popover.away; it stood at a fixed place left of the middle, over the
-- slots of a window there), off the rectangle a window registers with ItemTooltip.avoid (its Załóż / Użyj buttons).
-- Review 2026-11-10: on touch it stands at the top of its half, under the full-screen window's title bar, and keeps
-- off the window's action strip at the bottom (WindowFrame.rect's footer: the backpack's Załóż / Użyj / Podziel bar, a
-- pinned Footer) as well as what windows register; it had followed the slot's height down over that bar. The S68
-- details panel stands where Popover.place puts it in the same safe area (it was kept in the whole viewport, under the
-- top bar and the home indicator), and its touch "×" is a 44-px target.
-- Review 2026-11-11: the panel is never taller than its room (Popover.awayRoom on touch: under the title bar, over the
-- action strip; the safe area on PC): its lines scroll and on touch "Więcej ▸" / "Mniej ▾" stays pinned under them
-- (the full view of a mythic item ran 100-400 px off a phone's bottom with "Mniej ▾"). Scrolling the lines closes an
-- open details panel, which stands at its row's place; a new item or view starts at the top.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ArtIcon = require(script.Parent.ArtIcon)
local Device = require(script.Parent.Parent.Device)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.Parent.IconState)
local ItemCompare = require(ReplicatedStorage.Shared.Logic.ItemCompare)
local ItemIcon = require(script.Parent.ItemIcon)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemScore = require(ReplicatedStorage.Shared.Logic.ItemScore)
local ItemTraits = require(ReplicatedStorage.Shared.Data.ItemTraits)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Keybinds = require(script.Parent.Parent.Keybinds)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local Popover = require(ReplicatedStorage.Shared.Logic.Popover)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local RarityFrame = require(script.Parent.RarityFrame)
local Scale = require(script.Parent.Parent.Scale)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Tooltip)
local TooltipModel = require(ReplicatedStorage.Shared.Logic.TooltipModel)
local Types = require(ReplicatedStorage.Shared.Types)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.UiArtState)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)
local WindowFrame = require(ReplicatedStorage.Shared.Logic.WindowFrame)

local Children, OnChange, OnEvent, Out = Fusion.Children, Fusion.OnChange, Fusion.OnEvent, Fusion.Out

type ItemInstance = Types.ItemInstance
type Scope = Fusion.Scope<typeof(Fusion)>

local ItemTooltip = {}

local WIDTH = Theme.Size.TooltipWidth
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
-- 2026-10-31: the comparison's changes (TooltipModel.DELTA_HEX, parchment roles) in the iron roles of the same name.
for _, role in { "success", "danger", "textMuted" } do
	NIGHT_OF[string.upper((UiPalette.paper :: any)[role])] = (UiPalette.iron :: any)[role]
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
-- What the tooltip stands next to (layer virtual pixels): the cursor (Popover.cursor) or, on touch, the tapped slot.
local anchorRect = moduleScope:Value(Popover.cursor(0, 0, 0))
local onTouch = moduleScope:Value(false)
-- Touch: the slot objects by slot id (the tapped one is the anchor) and the rectangles windows ask the tooltip to keep
-- off (ItemTooltip.avoid), in the order they were registered.
local slotObjects: { [string]: GuiObject } = {}
local avoided: { GuiObject } = {}
local shownCtx = moduleScope:Value(nil :: TooltipModel.Ctx?)
local merchantOpen = moduleScope:Value(false)
local GAP = 8
local GROUP_GAP = 4 -- S134g: the thin space between two stat groups (role "gap")
-- The panel's padding (10 over and under its lines) and its list's gap (3): with the pinned "More ▸" / "Less ▾" row
-- (touch) what stays around the scrolling lines.
local PADDING_Y = 2 * 10
local LIST_GAP = 3
local TOGGLE_ORDER = 2
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
-- 2026-10-21: the full view: the details key held (PC) or "More ▸" tapped (touch; back to compact for a new item).
local detailsHeld = moduleScope:Value(false)
local touchFull = moduleScope:Value(false)
local fullView = moduleScope:Computed(function(use): boolean
	return use(detailsHeld) or use(touchFull)
end)
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

-- Equipped item the item would replace, for "Replaces: <name>" (S68: ItemScore.replaced, rings the weaker one, the
-- same as the "Better item" card; nil while a ring slot is free).
local function equippedFor(def: Items.ItemDef): ItemInstance?
	local equipment = State.Get({ "character", "equipment" })
	if type(equipment) ~= "table" then
		return nil
	end
	return ItemScore.replaced(def, equipment, scoreContext())
end

-- 2026-10-31: what equipping the item takes off, to compare its numbers with (nil = no changes shown).
local function compareFor(item: ItemInstance): { ItemInstance }?
	local equipment = State.Get({ "character", "equipment" })
	if type(equipment) ~= "table" then
		return nil
	end
	return ItemCompare.replaced(item, equipment, scoreContext())
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
	-- 2026-10-31: a line with the comparison's change may wrap, so the row grows (the bar and "i" stay by line one)
	return s:New("Frame")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		[Children] = {
			icon,
			s:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, if icon then -54 - ICON - 4 else -54, 0, 20),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = nightText(text), -- the comparison's change is rich text
				RichText = true,
				TextWrapped = true,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = if mythic then MYTHIC_LINE elseif legendary then LEGENDARY_LINE else BONUS,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			s:New("Frame")({
				Name = "Quality",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0, 10),
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

-- The tooltip panel ("Item") a row belongs to.
local function panelOf(object: GuiObject): GuiObject?
	local node: Instance? = object
	while node do
		if node:IsA("GuiObject") and node.Name == "Item" then
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

-- "More ▸" / "Less ▾" on touch: a row that switches the view (PC: the same line is a plain hint). Pinned under the
-- scrolling lines (TOGGLE_ORDER in the panel), so it stays on the screen.
local function viewToggle(s: Scope, order: number, text: string): Instance
	return s:New("TextButton")({
		Name = "ViewToggle",
		LayoutOrder = order,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
		Text = text,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = BONUS,
		TextXAlignment = Enum.TextXAlignment.Left,
		[OnEvent("Activated")] = function()
			closeDetail()
			touchFull:set(not Fusion.peek(touchFull))
		end,
	})
end

-- The tooltip's rows, and on touch the view switch ("More ▸" / "Less ▾") kept apart, pinned under the rows.
local function build(
	s: Scope,
	item: ItemInstance,
	lang: string,
	extra: TooltipModel.Ctx?,
	merchant: boolean,
	full: boolean
): ({ Instance }, Instance?)
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
		compare = if worn then nil else compareFor(item),
		merchantOpen = merchant,
		pathId = scoreContext().pathId,
		nodes = State.Get({ "character", "path", "nodes" }),
		mainHand = gear.weapon,
		offhand = gear.offhand,
		input = if touch then "touch" else "mouse",
		detailsKey = Keybinds.label("item_details"),
		view = if full then "full" else "compact",
		now = Workspace:GetServerTimeNow(), -- owner 2026-11-01: an everlasting stone's rest
	}
	if extra then
		for k, v in extra :: any do
			(ctx :: any)[k] = v
		end
	end
	local out: { Instance } = {}
	local toggle: Instance? = nil
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
		elseif entry.role == "moreHint" or entry.role == "lessHint" then
			-- touch gets the switch (pinned under the rows), PC the plain hint
			if touch then
				toggle = viewToggle(s, TOGGLE_ORDER, entry.text)
			else
				table.insert(out, line(s, order, entry.text, MUTED))
			end
			continue
		end
		local ref = entry.detail
		local bonus = entry.kind == "bonus"
		local icon: Instance? = nil
		if ref and touch then
			icon = if bonus
				then infoIcon(s, Vector2.new(1, 0.5), UDim2.new(1, -52, 0, 10))
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
	return out, toggle
end

-- Show / hide -----------------------------------------------------------------------------------------------

-- The cursor at screen point (x, y) as the tooltip's anchor.
local function cursor(x: number, y: number): Popover.Rect
	local at = Scale.toVirtual(Vector2.new(x, y))
	return Popover.cursor(at.X, at.Y, Popover.ITEM.drop)
end

local function show(object: GuiObject, item: ItemInstance?, text: string?, at: Popover.Rect, ctx: TooltipModel.Ctx?)
	owner = object
	shownCtx:set(ctx)
	shown:set(item)
	emptyText:set(if item then nil else text)
	anchorRect:set(at)
	onTouch:set(false)
end

-- The registered rectangles to keep off that are on the screen now (layer virtual pixels).
local function avoidRects(): { Popover.Rect }
	local out: { Popover.Rect } = {}
	for _, object in avoided do
		if object.Visible and object:IsDescendantOf(game) and object.AbsoluteSize.X > 0 then
			table.insert(out, Tooltip.rectOf(object))
		end
	end
	return out
end

-- UI package C: while `object` is on the screen, the touch tooltip keeps off it when there is room (a window's action
-- buttons for the selected item: Załóż, Użyj, ...). Until `scope` is cleaned up.
function ItemTooltip.avoid(scope: Scope, object: GuiObject)
	table.insert(avoided, object)
	table.insert(scope, function()
		local index = table.find(avoided, object)
		if index then
			table.remove(avoided, index)
		end
	end)
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
					show(object, item, text, cursor(x, y), if getCtx then getCtx() else nil)
					overOwner = true
				end
			end
		end)
	)
	table.insert(
		scope,
		object.MouseMoved:Connect(function(x, y)
			if owner == object and not Fusion.peek(pinned) then
				anchorRect:set(cursor(x, y))
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
	slotObjects[slotId] = object
	if getCtx then
		ctxGetters[slotId] = getCtx
	end
	table.insert(scope, function()
		if getters[slotId] == getItem then
			getters[slotId] = nil
			ctxGetters[slotId] = nil
		end
		if slotObjects[slotId] == object then
			slotObjects[slotId] = nil
		end
	end)
	-- Touch: the tooltip follows its slot while the list under it scrolls.
	table.insert(
		scope,
		object:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			if Fusion.peek(onTouch) and slotObjects[Fusion.peek(DragDrop.Selected) or ""] == object then
				anchorRect:set(Tooltip.rectOf(object))
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
			owner = nil
			local ctxGetter = selected and ctxGetters[selected]
			shownCtx:set(if ctxGetter then ctxGetter() else nil)
			shown:set(item)
			emptyText:set(nil)
			-- the tapped slot (unknown: the top of the screen's left half, so the tooltip takes the right one)
			local slot = selected and slotObjects[selected]
			local safe = Fusion.peek(Tooltip.SafeArea)
			anchorRect:set(
				if slot
					then Tooltip.rectOf(slot)
					else { left = safe.left, top = safe.top, right = safe.left, bottom = safe.top }
			)
			onTouch:set(true)
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
	-- the rows (the scroll's content) and, on touch, the view switch pinned under them
	type Built = { lines: { Instance }, toggle: Instance? }
	local built = scope:Computed(function(use, s: Scope): Built
		local item = use(shown)
		local lang = use(Text.Lang)
		if item then
			local lines, toggle = build(s, item, lang, use(shownCtx), use(merchantOpen), use(fullView))
			-- The name, the head line and the rarity line keep clear of the picture.
			if use(showIcon) then
				for i = 1, math.min(3, #lines) do
					s:New("UIPadding")({ PaddingRight = UDim.new(0, ICON_SIZE + 6), Parent = lines[i] })
				end
			end
			return { lines = lines, toggle = toggle }
		end
		local text = use(emptyText)
		return { lines = if text then { line(s, 1, text, DARK) } else {}, toggle = nil }
	end)
	-- Review 2026-11-11: the room the panel has (Popover.awayRoom on touch, under the full-screen window's title bar
	-- and over its action strip, where Popover.away puts it; the safe area less its margins on PC) and the height its
	-- scrolling rows show in it (Popover.capped: whole while they fit).
	local contentSize = scope:Value(Vector2.zero)
	local room = scope:Computed(function(use): number
		local safe = use(Tooltip.SafeArea)
		if use(onTouch) then
			local layer = { w = safe.right, h = safe.bottom }
			local window = WindowFrame.rect(layer, layer, nil, true, safe.top, use(PhoneLayout.Compact))
			return Popover.awayRoom(safe, { top = window.header.bottom, avoid = window.footer })
		end
		return Popover.awayRoom(safe)
	end)
	local linesHeight = scope:Computed(function(use): number
		local fixed = PADDING_Y + (if use(built).toggle then LIST_GAP + Theme.Size.MinTouch else 0)
		local _, shownHeight = Popover.capped(use(contentSize).Y / use(Scale.Value), fixed, use(room))
		return shownHeight
	end)
	local lines = scope:New("ScrollingFrame")({
		Name = "Lines",
		LayoutOrder = 1,
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(1, 0, 0, use(linesHeight))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = MUTED,
		ZIndex = 200,
		-- a details panel stands at its row's place: scrolling the rows closes it
		[OnChange("CanvasPosition")] = function()
			if Fusion.peek(detail) then
				closeDetail()
			end
		end,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, LIST_GAP),
				[Out("AbsoluteContentSize")] = contentSize,
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
			scope:Computed(function(use): { Instance }
				return use(built).lines
			end) :: any,
		},
	}) :: ScrollingFrame
	local mainPanel = scope:New("Frame")({
		Name = "Item",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Iron.Surface,
		ZIndex = 200,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			-- W28: the rarity border (3 px from Unique, gradient for Legendary / Mythic)
			RarityFrame.panelStroke(
				scope,
				scope:Computed(function(use): number?
					local item = use(shown)
					return if item then Rarities.get(item.rarity).id else nil
				end),
				Theme.Brass.Line
			),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, PADDING_Y / 2),
				PaddingBottom = UDim.new(0, PADDING_Y / 2),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, LIST_GAP),
			}),
			lines,
			scope:Computed(function(use): Instance?
				return use(built).toggle
			end) :: any,
		},
	})
	local rootSize = scope:Value(Vector2.zero)
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
		-- Logic/Popover from the measured size: beside the cursor on PC, the half away from the slot on touch
		Position = scope:Computed(function(use): UDim2
			local own = use(rootSize) / use(Scale.Value)
			local size = { w = math.max(own.X, WIDTH), h = own.Y }
			local safe = use(Tooltip.SafeArea)
			local rect: Popover.Rect
			if use(onTouch) then
				-- every touch window is full screen in this layer, under the top bar (Components/Window): its title bar
				-- at the top, its actions in the footer strip at the bottom, others where the window registers them
				local layer = { w = safe.right, h = safe.bottom }
				local window = WindowFrame.rect(layer, layer, nil, true, safe.top, use(PhoneLayout.Compact))
				rect = Popover.away(use(anchorRect), size, safe, {
					top = window.header.bottom,
					avoid = window.footer,
					keepOff = avoidRects(),
				})
			else
				rect = Popover.place(
					use(anchorRect),
					size,
					safe,
					{ prefer = "right" :: Popover.Side, gap = Popover.ITEM.gap }
				)
			end
			return UDim2.fromOffset(rect.left, rect.top)
		end),
		[Out("AbsoluteSize")] = rootSize,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				Padding = UDim.new(0, GAP),
			}),
			mainPanel,
		},
	})

	-- S68: details panel ------------------------------------------------------------------------------------------
	scope:Observer(shown):onChange(function()
		closeDetail()
		touchFull:set(false) -- 2026-10-21: every new item opens compact
		lines.CanvasPosition = Vector2.zero
	end)
	-- review 2026-11-11: the other view starts at its top too
	scope:Observer(fullView):onChange(function()
		lines.CanvasPosition = Vector2.zero
	end)
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
		-- Logic/Popover in the tooltip's safe area: PC right of the tooltip panels (left of them at the right edge), at
		-- its row's height; touch under its row (over it at the bottom), on the panel holding the row
		Position = scope:Computed(function(use): UDim2
			local open = use(detail)
			if not open then
				return UDim2.fromOffset(0, 0)
			end
			local size = { w = WIDTH, h = use(detailSize).Y / use(Scale.Value) }
			local row = { top = open.at.Y, bottom = open.at.Y + open.size.Y }
			local anchor: Popover.Rect = if open.side == "right"
				then { left = open.left, top = row.top, right = open.edge, bottom = row.bottom }
				else { left = open.edge - WIDTH, top = row.top, right = open.edge, bottom = row.bottom }
			local rect = Popover.place(
				anchor,
				size,
				use(Tooltip.SafeArea),
				{ prefer = open.side :: Popover.Side, gap = DETAIL_GAP }
			)
			return UDim2.fromOffset(rect.left, rect.top)
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
					-- Touch: "×" in the title row closes the panel: a MinTouch target in the panel's top right corner
					-- (over its 10 / 12 padding), the title's text kept 4 px clear of it.
					local hit = Theme.Size.MinTouch
					s:New("UIPadding")({ PaddingRight = UDim.new(0, hit - 12 + 4), Parent = title })
					s:New("TextButton")({
						Name = "Close",
						Parent = title,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, hit + 4, 0, -10),
						Size = UDim2.fromOffset(hit, hit),
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

	-- PC: holding the details key shows the full view (2026-10-21) and pins the tooltip (it stops following the mouse);
	-- releasing it goes back to compact and unpins.
	table.insert(
		scope,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local key = Keybinds.is(input.KeyCode, "item_details")
					and UserInputService:GetFocusedTextBox() == nil
					and not Fusion.peek(Device.Touch)
				if key then
					detailsHeld:set(true)
				end
				if key and Fusion.peek(shown) ~= nil then
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
			if input.UserInputType == Enum.UserInputType.Keyboard and Keybinds.is(input.KeyCode, "item_details") then
				detailsHeld:set(false)
			end
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
