--!strict
-- S155: the HUD elements the tutorial hint points at (Logic/Tutorial anchors) and the pulsing outline over the one it
-- points at. An anchor is looked up by the element's Name in a layer's Root (the HUD rebuilds on every character
-- entry, so nothing is cached past its parent), and only while the element and every ancestor are visible; on a phone
-- the Roblox thumbstick has no element: "joystick" is the lower left part of the screen where it appears. Rectangles
-- are in the layer's virtual pixels (UI/Scale), so a window resize or a phone rotation moves the hint with the HUD.
-- Owner 2026-11-10 ("things covering each other"; UI plan package A, the HUD's rework): the names live in
-- Logic/Tutorial.ANCHOR_NAMES (frozen; tests/tutorial.spec checks that Screens/Hud still builds each of them) and the
-- thumbstick's zone is Logic/HudZones.thumb, the one the phone's stack keeps clear of, so the pointers cannot drift
-- from the elements they point at.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudZones = require(ReplicatedStorage.Shared.Logic.HudZones)
local Theme = require(script.Parent.Theme)
local Tutorial = require(ReplicatedStorage.Shared.Logic.Tutorial)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Rect = { x: number, y: number, w: number, h: number }

local HudAnchors = {}

-- Anchor -> element Name on PC / on a touch screen (nil: no element on that device): Logic/Tutorial's frozen list.
HudAnchors.NAMES = Tutorial.ANCHOR_NAMES

local PULSE_SPEED = 4 -- rad/s
local OUTLINE_PAD = 6 -- virtual px around the element

local function shown(object: Instance, root: Instance): boolean
	local node: Instance? = object
	while node and node ~= root do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("LayerCollector") and not node.Enabled then
			return false
		end
		node = node.Parent
	end
	return node == root
end

-- The rectangle of `anchor` inside `root` (virtual px at `scale`), nil when it has no visible element now.
function HudAnchors.find(root: GuiObject, anchor: string?, touch: boolean, scale: number): Rect?
	if anchor == nil or scale <= 0 then
		return nil
	end
	local size = root.AbsoluteSize / scale
	if anchor == "joystick" then
		if not touch then
			return nil
		end
		local zone = HudZones.thumb(size.X, size.Y)
		return { x = zone.left, y = zone.top, w = zone.right - zone.left, h = zone.bottom - zone.top }
	end
	local names = HudAnchors.NAMES[anchor]
	local name = names and (if touch then names.touch else names.pc)
	if not name then
		return nil
	end
	-- W29: the first shown element of that name (the menu buttons exist twice: over the minimap and in the phone
	-- drawer); a menu button in the closed drawer points at the drawer's button
	local object: Instance? = nil
	for _, candidate in root:GetDescendants() do
		if candidate.Name == name and candidate:IsA("GuiObject") and shown(candidate, root) then
			object = candidate
			break
		end
	end
	if not object and names and names.drawer then
		local toggle = root:FindFirstChild(Tutorial.DRAWER, true)
		object = if toggle and toggle:IsA("GuiObject") and shown(toggle, root) then toggle else nil
	end
	if not object or not object:IsA("GuiObject") then
		return nil
	end
	local at = (object.AbsolutePosition - root.AbsolutePosition) / scale
	local extent = object.AbsoluteSize / scale
	if extent.X <= 0 or extent.Y <= 0 then
		return nil
	end
	return { x = at.X, y = at.Y, w = extent.X, h = extent.Y }
end

-- A pulsing brass outline over `rect` (nil hides it); never takes a click.
function HudAnchors.outline(scope: Scope, rect: Fusion.UsedAs<Rect?>): Instance
	local pulse = scope:Value(0)
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			pulse:set((math.sin(os.clock() * PULSE_SPEED) + 1) / 2)
		end)
	)
	return scope:New("Frame")({
		Name = "TutorialOutline",
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 50,
		Visible = scope:Computed(function(use): boolean
			return use(rect) ~= nil
		end),
		Position = scope:Computed(function(use): UDim2
			local r: Rect? = use(rect)
			return if r then UDim2.fromOffset(r.x - OUTLINE_PAD, r.y - OUTLINE_PAD) else UDim2.new()
		end),
		Size = scope:Computed(function(use): UDim2
			local r: Rect? = use(rect)
			return if r then UDim2.fromOffset(r.w + 2 * OUTLINE_PAD, r.h + 2 * OUTLINE_PAD) else UDim2.new()
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Brass.Bright,
				Thickness = Theme.Stroke.Thick,
				Transparency = scope:Computed(function(use): number
					return 0.7 * use(pulse)
				end),
			}),
		},
	})
end

return HudAnchors
