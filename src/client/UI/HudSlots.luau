--!strict
-- Owner 2026-10-21 (Studio: "the world boss panel covers the tracker's first line, the mail button touches the
-- tracker"): the client side of Logic/HudStack. The column's elements (the event panels, the Elite II timers and the
-- quest tracker) tell it whether they show, their size and the place the player moved them to (UI/HudDrag), and read
-- back their built-in place: top down in HudSlots.ORDER, round every moved element and the bottom-right corner's
-- buttons, so nothing covers anything. Replaces the S101 / S149b offsets the panels passed each other.
-- Owner 2026-11-10 ("things covering each other, nothing folds"; UI plan package A): nothing of the column passes its
-- floor (Logic/HudStack.place): a panel the column has no room for shows its header line (`forced`), and what has no
-- room even then waits behind the '+N' chip (`Hidden`, `Chip`, Hud/StackChip), whose list brings one back first
-- (`bring`). Several elements may join one id (the arena's queue pill, its team list and, on a phone, its match and
-- return panels share "arena"): the column places their shown ones as one item, one under another in the order they
-- joined, and while it folds that item only the first one shows its line. `Zones` are the PC zone map's places
-- (Logic/HudZones) the HUD's elements of HudZones.ELEMENTS stand in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local HudZones = require(ReplicatedStorage.Shared.Logic.HudZones)
local NavTarget = require(script.Parent.NavTarget)
local PhoneLayout = require(script.Parent.PhoneLayout)
local Scale = require(script.Parent.Scale)
local State = require(script.Parent.State)

type Scope = Fusion.Scope<typeof(Fusion)>

local HudSlots = {}

-- What an element tells the column (Logic/HudStack.Box): shown, its size and the place the player moved it to.
export type Box = HudStack.Box

-- The order of the stack, top down (Logic/HudStack.ORDER).
HudSlots.ORDER = HudStack.ORDER

local scope = Fusion.scoped(Fusion)
-- id -> joiner -> its box and the order it joined in (HudSlots.join)
type Joiner = { order: number, box: Box }
local joined = scope:Value({} :: { [string]: { [any]: Joiner } })
local joins = 0

-- The shown joiners of one id in the order they joined.
local function shownOf(by: { [any]: Joiner }): { Joiner }
	local list: { Joiner } = {}
	for _, joiner in by do
		if joiner.box.shown then
			table.insert(list, joiner)
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

-- id -> the one box the column places: the shown joiner's, several shown ones as one (their heights one under another,
-- the first one's line), else any of them (not shown)
local boxes = scope:Computed(function(use): { [string]: Box }
	local out: { [string]: Box } = {}
	for id, by in use(joined) do
		local list = shownOf(by)
		if #list == 1 then
			out[id] = list[1].box
		elseif #list > 1 then
			local first = list[1].box
			local w, h = 0, -HudStack.GAP
			for _, joiner in list do
				w = math.max(w, joiner.box.w)
				h += joiner.box.h + HudStack.GAP
			end
			out[id] = { shown = true, w = w, h = h, line = first.line or first.h, custom = first.custom }
		else
			for _, joiner in by do
				out[id] = joiner.box
				break
			end
		end
	end
	return out
end)
-- The element the player picked from the '+N' list (Hud/StackChip): it folds and hides after the others.
HudSlots.Front = scope:Value(nil :: string?)

-- Owner 2026-10-22 (Studio 1462 x 793: the tracker still ran 22 px into the PvP toggle; the layer's height from the
-- formula did not match the screen): the corner's buttons as they really stand. Each one joins with `corner`; its
-- AbsolutePosition and AbsoluteSize, in the virtual pixels of the frame the column's panels live in (`SetHost`,
-- UI/HudGate), are measured again whenever they, the frame or the UI scale change, and HudStack.layout keeps the
-- column's floor (and the PC Elite II timers, Hud/Elite2Timer) above them.
local host: GuiObject? = nil
local watched: { [GuiObject]: boolean } = {}
local measured = scope:Value({} :: { HudStack.Rect })
HudSlots.Measured = measured

-- UI plan phase 2: the row of "something waits" buttons under the minimap shows (Hud/WaitingRow sets it); on PC the
-- column starts under it (Logic/HudStack.WAITING).
HudSlots.Waiting = scope:Value(false)
-- Studio check 2026-10-31 (the row stood in the tracker: the column had not stepped down): the menu over the minimap's
-- real bottom edge (virtual pixels of the host), measured on screen; the PC column never starts above it
-- (HudStack.column `menuBottom`). 0 while unknown.
HudSlots.MenuBottom = scope:Value(0)
-- Studio check 2026-10-31 (a tracker the player had moved stood under the row): the menu's whole rectangle (virtual
-- pixels of the host), nil while unknown; an element the player moved never stands in it (UI/HudDrag,
-- Logic/HudStack.belowMenu).
HudSlots.Menu = scope:Value(nil :: HudStack.Rect?)
local menuFrame: GuiObject? = nil
-- Which rows say "something waits" (HudSlots.SetWaiting), so a rebuilt row's cleanup cannot switch off a new one.
local waitingBy: { [any]: boolean } = {}

local function same(a: { HudStack.Rect }, b: { HudStack.Rect }): boolean
	if #a ~= #b then
		return false
	end
	for i, r in a do
		local o = b[i]
		if
			math.abs(r.left - o.left) > 0.5
			or math.abs(r.top - o.top) > 0.5
			or math.abs(r.right - o.right) > 0.5
			or math.abs(r.bottom - o.bottom) > 0.5
		then
			return false
		end
	end
	return true
end

local function measure()
	local frame = host
	local k = Scale.get()
	if not frame or k <= 0 then
		return
	end
	local origin = frame.AbsolutePosition
	local out: { HudStack.Rect } = {}
	for item in watched do
		local at, size = item.AbsolutePosition, item.AbsoluteSize
		if item.Visible and item:IsDescendantOf(game) and size.X > 0 and size.Y > 0 then
			table.insert(out, HudStack.fromScreen(at.X, at.Y, size.X, size.Y, origin.X, origin.Y, k))
		end
	end
	table.sort(out, function(a, b)
		return if a.top == b.top then a.left < b.left else a.top < b.top
	end)
	if not same(out, Fusion.peek(measured)) then
		measured:set(out)
	end
end

local function measureMenu()
	local frame, root = menuFrame, host
	local k = Scale.get()
	if not frame or not root or k <= 0 or not frame:IsDescendantOf(game) then
		return
	end
	local at, size, origin = frame.AbsolutePosition, frame.AbsoluteSize, root.AbsolutePosition
	local rect = HudStack.fromScreen(at.X, at.Y, size.X, size.Y, origin.X, origin.Y, k)
	if math.abs(rect.bottom - Fusion.peek(HudSlots.MenuBottom)) > 0.5 then
		HudSlots.MenuBottom:set(rect.bottom)
	end
	local last = Fusion.peek(HudSlots.Menu)
	if not last or not same({ last }, { rect }) then
		HudSlots.Menu:set(rect)
	end
end

scope:Observer(Scale.Value):onChange(function()
	task.defer(measure)
	task.defer(measureMenu)
end)

-- The menu over the minimap (PC) for the life of `s`: HudSlots.MenuBottom follows its bottom edge.
function HudSlots.SetMenu(s: Scope, frame: GuiObject)
	menuFrame = frame
	for _, property in { "AbsolutePosition", "AbsoluteSize" } do
		table.insert(s, frame:GetPropertyChangedSignal(property):Connect(measureMenu))
	end
	table.insert(s, function()
		if menuFrame == frame then
			menuFrame = nil
			HudSlots.MenuBottom:set(0)
			HudSlots.Menu:set(nil)
		end
	end)
	task.defer(measureMenu)
end

-- The row of "something waits" buttons shows (`on`) or not, for its `owner` (nil: gone).
function HudSlots.SetWaiting(owner: any, on: boolean?)
	if on then
		waitingBy[owner] = true
	else
		waitingBy[owner] = nil
	end
	HudSlots.Waiting:set(next(waitingBy) ~= nil)
end

-- The frame the column's panels are placed in (UI/HudGate's): the origin of the measured rectangles.
function HudSlots.SetHost(frame: GuiObject)
	if host == frame then
		return
	end
	host = frame
	for _, property in { "AbsolutePosition", "AbsoluteSize" } do
		table.insert(scope, frame:GetPropertyChangedSignal(property):Connect(measure))
		table.insert(scope, frame:GetPropertyChangedSignal(property):Connect(measureMenu))
	end
	task.defer(measure)
	task.defer(measureMenu)
end

-- A button of the bottom-right corner (the PvP toggle, its badge, the mail) for the life of `s`: the column stays
-- above where it really stands.
function HudSlots.corner(s: Scope, item: GuiObject)
	watched[item] = true
	for _, property in { "AbsolutePosition", "AbsoluteSize", "Visible" } do
		table.insert(s, item:GetPropertyChangedSignal(property):Connect(measure))
	end
	table.insert(s, function()
		watched[item] = nil
		measure()
	end)
	task.defer(measure)
end

-- The corner's buttons a moved element stops above (HudStack.floorUnder): computed and measured; none on a phone
-- (Logic/PhoneHud keeps its places apart).
HudSlots.Corner = scope:Computed(function(use): { HudStack.Rect }
	if use(PhoneLayout.Compact) then
		return {}
	end
	local screen: Vector2 = use(Scale.HudSize)
	local out: { HudStack.Rect } = table.clone(use(measured))
	for _, rect in HudStack.fixed(use(Device.Touch) == true, screen.X, screen.Y) do
		table.insert(out, rect)
	end
	return out
end)

-- UI plan package A: the HUD's state as Logic/HudZones reads it (`Zones` below). Every optional place is asked for (a
-- player target, the Auto popover, the arena panel), so an element finds its place whenever it shows; the dungeon's
-- boss bar (state `boss`, DungeonController) moves the target frame under it (`addFrame`) and the band down.
local boss = State.Value({ "boss" })
local function zoneState(use: Fusion.Use): HudZones.State
	local bossBar = type(use(boss)) == "table"
	return {
		touch = use(Device.Touch) == true,
		party = use(PhoneLayout.Others),
		guide = use(NavTarget.Target) ~= nil,
		autoPopover = true,
		target = "player",
		bossBar = bossBar,
		add = bossBar,
		arena = "match",
	}
end

-- Where the column stands now (Logic/HudStack.arrange): every shown element without a place of its own, by id, its
-- folded and hidden ids and the '+N' chip. UI plan phase 1: on PC the column starts under the guide bar while one shows
-- (Hud/NavBar), else right under the minimap's area line; phase 2: under the row of "something waits" buttons while it
-- shows.
HudSlots.Arranged = scope:Computed(function(use): HudStack.Placed
	local screen: Vector2 = use(Scale.HudSize)
	local front = use(HudSlots.Front)
	local now: { [string]: Box } = use(boxes)
	if front and now[front] then
		now = table.clone(now)
		local kept = table.clone(now[front])
		kept.keep = true
		now[front] = kept
	end
	return HudStack.arrange(
		use(Device.Touch) == true,
		use(PhoneLayout.Compact),
		screen.X,
		screen.Y,
		use(PhoneLayout.Others),
		now,
		use(measured),
		use(NavTarget.Target) ~= nil,
		use(HudSlots.Waiting),
		use(HudSlots.MenuBottom),
		HudZones.targetBand(screen.X, zoneState(use)).bottom
	)
end)

-- The built-in place of every shown element that has none of its own, by id (a folded one its line).
HudSlots.Places = scope:Computed(function(use): { [string]: HudStack.Rect }
	return use(HudSlots.Arranged).rects
end)

-- The ids behind the '+N' chip (top down) and the chip (nil while nothing is hidden).
HudSlots.Hidden = scope:Computed(function(use): { string }
	return use(HudSlots.Arranged).hidden
end)
HudSlots.Chip = scope:Computed(function(use): HudStack.Rect?
	return use(HudSlots.Arranged).chip
end)

-- The player picked `id` from the '+N' list: it stands in the column first (the others fold and hide before it).
function HudSlots.bring(id: string?)
	HudSlots.Front:set(id)
end

-- Joins element `id` (HudSlots.ORDER) to the column for the life of `s`; its built-in place (nil while hidden or
-- moved by the player, or while it waits behind the '+N' chip; a later joiner of the same id under the earlier shown
-- ones, nil while the column folds the id to its line).
-- Package A review (owner 2026-11-10): `box` never reads the column (`forced`, `Arranged`, a slot): it tells the
-- element's height as the player folded it, and the column folds it to its `line` itself. `put` sets `joined` while
-- the Observer runs, so a box that read the column fed the column back: Fusion stopped that loop ("infinite loop")
-- before the column saw the new height (tests/hudslots.spec).
function HudSlots.join(s: Scope, id: string, box: Fusion.UsedAs<Box>): Fusion.Computed<HudStack.Rect?>
	local token = {}
	joins += 1
	local order = joins
	local function put(value: Box?)
		local now: { [string]: { [any]: Joiner } } = table.clone(Fusion.peek(joined))
		local by: { [any]: Joiner } = table.clone(now[id] or {})
		if value then
			by[token] = { order = order, box = value }
		else
			by[token] = nil
		end
		if next(by) then
			now[id] = by
		else
			now[id] = nil
		end
		joined:set(now)
	end
	local current = s:Computed(function(use): Box
		return use(box)
	end)
	s:Observer(current):onBind(function()
		put(Fusion.peek(current))
	end)
	table.insert(s, function()
		put(nil)
	end)
	return s:Computed(function(use): HudStack.Rect?
		local rect = use(HudSlots.Places)[id]
		local by = use(joined)[id]
		if not rect or not by then
			return nil
		end
		local list = shownOf(by)
		if #list <= 1 then
			return if by[token] and by[token].box.shown then rect else nil
		end
		local folded = table.find(use(HudSlots.Arranged).folded, id) ~= nil
		local top = rect.top
		for i, joiner in list do
			if joiner.order == order then
				if folded then
					-- the first one shows the id's line (a box keeps its open height while the column folds it)
					return if i == 1 then rect else nil
				end
				return { left = rect.left, top = top, right = rect.left + joiner.box.w, bottom = top + joiner.box.h }
			end
			top += joiner.box.h + HudStack.GAP
		end
		return nil
	end)
end

-- Whether an element that joined the column shows: shown, and at a place (its built-in one, or one the player moved it
-- to: `moved`); an element waiting behind the '+N' chip has none.
function HudSlots.visible(
	s: Scope,
	slot: Fusion.Computed<HudStack.Rect?>,
	shown: Fusion.UsedAs<boolean>,
	moved: Fusion.UsedAs<any>?
): Fusion.Computed<boolean>
	return s:Computed(function(use): boolean
		if not use(shown) then
			return false
		end
		return use(slot) ~= nil or (moved ~= nil and use(moved) ~= nil)
	end)
end

-- Whether the column folded element `id` to its line now (no room for it open; the player's own fold stays as saved).
function HudSlots.forced(s: Scope, id: string): Fusion.Computed<boolean>
	return s:Computed(function(use): boolean
		return table.find(use(HudSlots.Arranged).folded, id) ~= nil
	end)
end

-- UI plan package A: the PC zone map of the layer as it is now (Logic/HudZones.pc of `zoneState`), for the elements of
-- HudZones.ELEMENTS: they stand at a place of it (`at`, `point`) and take its size (`sizeOf`).
HudSlots.Zones = scope:Computed(function(use): HudZones.Zones
	local screen: Vector2 = use(Scale.HudSize)
	return HudZones.pc(screen.X, screen.Y, zoneState(use))
end)

-- The top-left corner of zone place `name` as a position (anchor point 0, 0).
function HudSlots.at(s: Scope, name: string): Fusion.Computed<UDim2>
	return s:Computed(function(use): UDim2
		local rect: HudStack.Rect? = (use(HudSlots.Zones) :: any)[name]
		return if rect then UDim2.fromOffset(rect.left, rect.top) else UDim2.new()
	end)
end

-- The point of zone place `name` at fractions `ax`, `ay` of its width and height (0.5, 1: its bottom centre), for an
-- element with that anchor point.
function HudSlots.point(s: Scope, name: string, ax: number, ay: number): Fusion.Computed<UDim2>
	return s:Computed(function(use): UDim2
		local rect: HudStack.Rect? = (use(HudSlots.Zones) :: any)[name]
		if not rect then
			return UDim2.new()
		end
		return UDim2.fromOffset(rect.left + (rect.right - rect.left) * ax, rect.top + (rect.bottom - rect.top) * ay)
	end)
end

-- The size of zone place `name`.
function HudSlots.sizeOf(s: Scope, name: string): Fusion.Computed<UDim2>
	return s:Computed(function(use): UDim2
		local rect: HudStack.Rect? = (use(HudSlots.Zones) :: any)[name]
		return if rect then UDim2.fromOffset(rect.right - rect.left, rect.bottom - rect.top) else UDim2.new()
	end)
end

-- The top-left corner of a slot as a position (anchor point 0, 0); a hidden element keeps its last one.
function HudSlots.position(s: Scope, slot: Fusion.Computed<HudStack.Rect?>): Fusion.Computed<UDim2>
	local last = UDim2.new()
	return s:Computed(function(use): UDim2
		local at = use(slot)
		if at then
			last = UDim2.fromOffset(at.left, at.top)
		end
		return last
	end)
end

-- The rectangle (virtual pixels) of an element the player moved: its corner and its size times its scale; nil at its
-- built-in place.
function HudSlots.moved(corner: Vector2?, w: number, h: number, scale: number): HudStack.Rect?
	if not corner then
		return nil
	end
	return { left = corner.X, top = corner.Y, right = corner.X + w * scale, bottom = corner.Y + h * scale }
end

return HudSlots
