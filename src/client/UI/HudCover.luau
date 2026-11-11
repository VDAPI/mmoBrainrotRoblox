--!strict
-- UI plan phase 2 (Studio audit 2026-10-31: "windows never hide or dim the HUD: the auction, the shop, the mail, the
-- blacksmith and the alchemist overlap the tracker and the icon grid"): the HUD parts an open window covers step out of
-- sight until it closes. WindowManager reports the open windows (overlays such as the dev panel do not count); a HUD
-- part asks `covered` for its own rectangle and hides itself while any of them covers it by more than MARGIN
-- (Logic/HudStack.covers). Used by the quest tracker (any open window hides it, `Open`), the menu bar, the minimap's
-- caption and the row of "something waits" buttons; never by the action bar, the portrait's bars or the chat. A hidden part keeps the rectangle where it
-- last showed, so hiding it never changes the answer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local PhoneLayout = require(script.Parent.PhoneLayout)
local Scale = require(script.Parent.Scale)
local Theme = require(script.Parent.Theme)

type Scope = Fusion.Scope<typeof(Fusion)>

local HudCover = {}

local MARGIN = 4 -- screen pixels

local scope = Fusion.scoped(Fusion)
local windows = scope:Value({} :: { GuiObject })
local moved = scope:Value(0) -- bumped whenever an open window moves or resizes
local links: { RBXScriptConnection } = {}

local function rectOf(item: GuiObject): HudStack.Rect
	local at, size = item.AbsolutePosition, item.AbsoluteSize
	return { left = at.X, top = at.Y, right = at.X + size.X, bottom = at.Y + size.Y }
end

-- WindowManager: the roots of the open normal windows, after every opening and closing.
function HudCover.SetWindows(list: { GuiObject })
	for _, link in links do
		link:Disconnect()
	end
	table.clear(links)
	local function bump()
		moved:set(Fusion.peek(moved) + 1)
	end
	for _, root in list do
		for _, property in { "AbsolutePosition", "AbsoluteSize" } do
			table.insert(links, root:GetPropertyChangedSignal(property):Connect(bump))
		end
	end
	windows:set(table.clone(list))
end

-- The lowest bottom edge of the open windows' title bars (screen pixels), nil with no window open (Logic/TopBand
-- .underHeader). UI package C (2026-11-10) gave a phone's window (UI/PhoneLayout.Compact) a 44-px title bar, so the
-- edge follows it there; the band's messages measure each window themselves (HudCover.Rects, UI/Notify).
HudCover.HeaderBottom = scope:Computed(function(use): number?
	use(moved)
	local header = if use(PhoneLayout.Compact) then Theme.Size.WindowHeaderCompact else Theme.Size.WindowHeader
	local bottom: number? = nil
	for _, root in use(windows) do
		if root.Parent ~= nil then
			local edge = root.AbsolutePosition.Y + header * Scale.get()
			bottom = if bottom then math.max(bottom, edge) else edge
		end
	end
	return bottom
end)

-- UI plan package B (owner 2026-11-10: "things covering each other"): the open windows' rectangles in screen pixels
-- (as AbsolutePosition), so a message of the Toasts layer stands over a window where it fits and under its title bar
-- otherwise, never on it (UI/Notify, Logic/TopBand.slots; owner 2026-10-31, question UI 8).
HudCover.Rects = scope:Computed(function(use): { HudStack.Rect }
	use(moved)
	local out: { HudStack.Rect } = {}
	for _, root in use(windows) do
		if root.Parent ~= nil then
			table.insert(out, rectOf(root))
		end
	end
	return out
end)

-- Review 2026-11-10 of package B: the open modal dialog. WindowManager hands over its overlay when it shows one; the
-- Modals layer stands under the Toasts layer, so a message that met the dialog covered its question or its buttons:
-- UI/Notify keeps the band's messages off it (Logic/TopBand.slots, `modals`).
local modal = scope:Value(nil :: GuiObject?)
local modalLinks: { RBXScriptConnection } = {}

-- The dialog's own frame in a modal's overlay (Components/Modal: "Dialog"), else the overlay.
local function dialogOf(overlay: GuiObject): GuiObject
	local dialog = overlay:FindFirstChild("Dialog", true)
	return if dialog and dialog:IsA("GuiObject") then dialog else overlay
end

function HudCover.SetModal(overlay: GuiObject?)
	for _, link in modalLinks do
		link:Disconnect()
	end
	table.clear(modalLinks)
	if overlay then
		local function bump()
			moved:set(Fusion.peek(moved) + 1)
		end
		local dialog = dialogOf(overlay)
		for _, property in { "AbsolutePosition", "AbsoluteSize" } do
			table.insert(modalLinks, dialog:GetPropertyChangedSignal(property):Connect(bump))
		end
		-- it closes by leaving the layer
		table.insert(modalLinks, overlay.AncestryChanged:Connect(bump))
	end
	modal:set(overlay)
end

-- The open modal dialog's rectangle in screen pixels (as AbsolutePosition); none while no dialog shows.
HudCover.Modals = scope:Computed(function(use): { HudStack.Rect }
	use(moved)
	local overlay = use(modal)
	if overlay == nil or overlay.Parent == nil then
		return {}
	end
	return { rectOf(dialogOf(overlay)) }
end)

-- Final UI review 2026-11-10 (the band's alert line, its toasts and a phone's M line stood on the death screen's title
-- and countdown: the screen stands in the Screens layer, the band in the Toasts layer over it): the death screen's
-- content while the player is dead. Hud/DeathScreen hands it over; UI/Notify keeps the band's messages off it as off a
-- modal dialog (Logic/TopBand.slots, `modals`) and holds what waits until it closes (Logic/NoticeQueue, `paused`).
-- Its own slot: WindowManager's one dialog (SetModal) would clear it.
local death = scope:Value(nil :: GuiObject?)
local deathLinks: { RBXScriptConnection } = {}

function HudCover.SetDeath(content: GuiObject?)
	for _, link in deathLinks do
		link:Disconnect()
	end
	table.clear(deathLinks)
	if content then
		local function bump()
			moved:set(Fusion.peek(moved) + 1)
		end
		for _, property in { "AbsolutePosition", "AbsoluteSize" } do
			table.insert(deathLinks, content:GetPropertyChangedSignal(property):Connect(bump))
		end
	end
	death:set(content)
end

-- Takes `content` out only while it is the one handed over (a rebuilt HUD's new screen may have taken its place).
function HudCover.ClearDeath(content: GuiObject)
	if Fusion.peek(death) == content then
		HudCover.SetDeath(nil)
	end
end

-- Whether the death screen shows.
HudCover.Dead = scope:Computed(function(use): boolean
	local content = use(death)
	return content ~= nil and content.Parent ~= nil
end)

-- The death screen's content in screen pixels (as AbsolutePosition); none while the player lives.
HudCover.Death = scope:Computed(function(use): { HudStack.Rect }
	use(moved)
	local content = use(death)
	if content == nil or content.Parent == nil then
		return {}
	end
	return { rectOf(content) }
end)

-- Studio check 2026-10-31 (the quest tracker stayed beside the backpack window): a normal window is open. The quest
-- tracker steps out of sight under any of them, wherever it stands; the other parts only when one covers them.
HudCover.Open = scope:Computed(function(use): boolean
	use(moved)
	for _, root in use(windows) do
		if root.Parent ~= nil then
			return true
		end
	end
	return false
end)

-- Whether an open window covers `item` now (for the life of `s`). Bind the item's Visible to `not covered`.
function HudCover.covered(s: Scope, item: GuiObject): Fusion.Computed<boolean>
	local last = s:Value(nil :: HudStack.Rect?)
	local function measure()
		local size = item.AbsoluteSize
		if item.Visible and size.X > 0 and size.Y > 0 then
			last:set(rectOf(item))
		end
	end
	for _, property in { "AbsolutePosition", "AbsoluteSize" } do
		table.insert(s, item:GetPropertyChangedSignal(property):Connect(measure))
	end
	task.defer(measure)
	return s:Computed(function(use): boolean
		use(moved)
		local rect = use(last)
		if not rect then
			return false
		end
		for _, root in use(windows) do
			if root.Parent ~= nil and HudStack.covers(rect, rectOf(root), MARGIN) then
				return true
			end
		end
		return false
	end)
end

return HudCover
