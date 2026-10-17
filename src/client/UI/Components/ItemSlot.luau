--!strict
-- Item slot (DESIGN §23): item icon (S35: atlas picture, or the glyph on the item colour before the upload), rarity frame from the rarity's
-- `frame` data (S30: grey, yellow, blue with a glow, orange / red with a rotating gradient), stack count, "+N" upgrade, lock when bound, red tint when the
-- character cannot use it. Interaction (select, drag & drop, double-click, tap) comes from UI/DragDrop;
-- the rich tooltip from ItemTooltip.
-- S135: drawn for its `Surface` (default "paper"): raised slot with an iron-brown edge, the rarity frame in its
-- parchment variant (Rarities.paperHex, >= 3:1 on the slot), count and "+N" on a small dark iron plaque.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArtIcon = require(script.Parent.ArtIcon)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemIcon = require(script.Parent.ItemIcon)
local ItemTooltip = require(script.Parent.ItemTooltip)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local SameRef = require(script.Parent.Parent.SameRef)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local TooltipModel = require(ReplicatedStorage.Shared.Logic.TooltipModel)
local Types = require(ReplicatedStorage.Shared.Types)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children = Fusion.Children

type UsedAs<T> = Fusion.UsedAs<T>
type ItemInstance = Types.ItemInstance

export type Props = {
	SlotId: string,
	Item: UsedAs<ItemInstance?>,
	Size: number?,
	Placeholder: string?, -- glyph shown when empty (equipment slots)
	PlaceholderArt: string?, -- S119: its interface picture key (Logic/UiArt.slot)
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
	Surface: Theme.SurfaceName?, -- S135 (default "paper"; HUD "iron")
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

-- Selected slot: an ink outline on parchment (iron: the parchment text colour) and the selected background (not gold:
-- it would read as a Unique frame).
local SELECTED = { paper = Theme.Paper.Heading, iron = Theme.Iron.Text }

-- Frame colour of a rarity on a surface (ItemText.rarityFrame: the parchment variant on paper, identity on iron).
local function frameColor(r: Rarities.RarityDef, surface: string): Color3
	return ItemText.rarityFrame(r.id, surface)
end

-- Gradient of a frame (c1 → c2 → c1), cached per rarity and surface. On parchment the light second colour would
-- vanish, so it runs from the parchment frame colour to a darker shade of it.
local gradients: { [string]: ColorSequence } = {}
local function gradientOf(r: Rarities.RarityDef, surface: string): ColorSequence
	local key = `{r.id}|{surface}`
	local cached = gradients[key]
	if cached then
		return cached
	end
	local colors = r.frame.gradient or { r.color, r.color }
	if surface ~= "iron" then
		colors = { r.paperColor, Theme.mix(r.paperColor, Theme.Shade, 0.35) }
	end
	local sequence = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors[1]),
		ColorSequenceKeypoint.new(0.5, colors[2]),
		ColorSequenceKeypoint.new(1, colors[1]),
	})
	gradients[key] = sequence
	return sequence
end

-- S135: a small dark plaque with a number (stack count, "+N"); hidden while empty.
local function plaque(
	scope: Fusion.Scope<typeof(Fusion)>,
	props: {
		Name: string,
		AnchorPoint: Vector2,
		Position: UDim2,
		Color: Color3,
		Text: Fusion.UsedAs<string>,
	}
): Instance
	return scope:New("TextLabel")({
		Name = props.Name,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = UDim2.fromOffset(0, 17),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = 0.15,
		Visible = scope:Computed(function(use): boolean
			return use(props.Text) ~= ""
		end),
		Text = props.Text,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Caption,
		TextColor3 = props.Color,
		ZIndex = 3,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }),
		},
	})
end

local function ItemSlot(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local size = props.Size or Theme.Size.SlotSize
	local surface = props.Surface or "paper"
	local roles = Theme.surface(surface)
	local unusableBg = Theme.mix(roles.Raised, roles.Danger, 0.3)
	local level = State.Value({ "character", "level" })
	local classId = State.Value({ "character", "class" })

	-- S134f: the slot recomputes only when its item table (or the item id) really changes, not on every
	-- inventory refresh (SameRef: Fusion never treats an unfrozen table as unchanged).
	local item: Fusion.UsedAs<ItemInstance?> = SameRef.of(scope, props.Item)
	local itemId = scope:Computed(function(use): string?
		local i = use(item)
		return if i then i.id else nil
	end)
	local def = SameRef.of(
		scope,
		scope:Computed(function(use): Items.ItemDef?
			local id = use(itemId)
			return if id then Items.get(id) else nil
		end)
	)
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
	-- FIX 2026-10-15: marked for selling in an open shop (DragDrop.Marked).
	local marked = scope:Computed(function(use): boolean
		return use(DragDrop.Marked)[props.SlotId] ~= nil
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
				return roles.Selected
			end
			return if use(usable) then roles.Raised else unusableBg
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
						return roles.Success
					elseif h == "bad" then
						return roles.Danger
					elseif use(selected) then
						return SELECTED[surface] or SELECTED.paper
					end
					local r = use(rarity)
					if r and r.frame.gradient then
						return Theme.Plain -- the gradient carries the colour
					end
					return if r then frameColor(r, surface) else roles.Border
				end),
				Transparency = scope:Computed(function(use): number
					return if use(item) or use(selected) or use(hint) ~= nil then 0 else 0.2
				end),
				[Children] = scope:Computed(function(use, s: Fusion.Scope<typeof(Fusion)>): Instance?
					local r = use(rarity)
					if not r or not r.frame.gradient or use(hint) ~= nil or use(selected) then
						return nil
					end
					return s:New("UIGradient")({
						Color = gradientOf(r, surface),
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
							Color = frameColor(r, surface),
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
			-- Icon (S35): atlas layers while loaded, otherwise the glyph on its tile; mage weapons get their element.
			ItemIcon(scope, {
				Def = def,
				Element = scope:Computed(function(use): string?
					local current = use(item)
					return if current then ItemRoll.elementOf(current) else nil
				end),
				Fallback = props.Placeholder,
				FallbackArt = props.PlaceholderArt,
				Transparency = scope:Computed(function(use): number
					return if use(dragging) then 0.7 else 0
				end),
			}),
			-- Stack count (S135: on a dark iron plaque, readable on every icon)
			plaque(scope, {
				Name = "Count",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -2, 1, -2),
				Color = Theme.Iron.Text,
				Text = scope:Computed(function(use): string
					local i = use(item)
					return if i and i.n > 1 then tostring(i.n) else ""
				end),
			}),
			-- Upgrade level
			plaque(scope, {
				Name = "Upgrade",
				AnchorPoint = Vector2.zero,
				Position = UDim2.fromOffset(2, 2),
				Color = Theme.Brass.Bright,
				Text = scope:Computed(function(use): string
					local i = use(item)
					return if i and i.up > 0 then `+{i.up}` else ""
				end),
			}),
			-- Padlock (S20): protected from selling, dismantling and trading
			-- S119: both marks as silhouettes in the glyph colour once loaded.
			ArtIcon(scope, {
				Name = "Locked",
				Key = UiArt.hud("lock"),
				Glyph = "🔒",
				GlyphColor = roles.Heading,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -2, 0, 1),
				Size = UDim2.fromOffset(14, 14),
				Visible = scope:Computed(function(use): boolean
					local i = use(item)
					return i ~= nil and i.locked == true
				end),
				ZIndex = 3,
				Label = { TextScaled = true },
			}),
			-- Marked for selling (FIX 2026-10-15): gold veil, outline and a check mark, as in SelectableSlot.
			scope:New("Frame")({
				Name = "SellMark",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Brass.Bright,
				BackgroundTransparency = 0.7,
				Visible = marked,
				ZIndex = 4,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({ Color = Theme.Brass.Frame, Thickness = Theme.Stroke.Thick }),
					scope:New("TextLabel")({
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -2, 0, 0),
						Size = UDim2.fromOffset(20, 20),
						BackgroundTransparency = 1,
						Text = "✔",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Brass.Bright,
						TextStrokeColor3 = Theme.Iron.Surface,
						TextStrokeTransparency = 0,
						ZIndex = 5,
					}),
				},
			}),
			-- Bound lock
			ArtIcon(scope, {
				Name = "Bound",
				Key = UiArt.hud("bound"),
				Glyph = "⚿",
				GlyphColor = roles.TextMuted,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 3, 1, -1),
				Size = UDim2.fromOffset(14, 14),
				Visible = scope:Computed(function(use): boolean
					local i = use(item)
					local d = use(def)
					return i ~= nil and i.bound and d ~= nil and d.category == "equipment"
				end),
				Label = { FontFace = Theme.Fonts.BodyBold, TextScaled = true },
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
