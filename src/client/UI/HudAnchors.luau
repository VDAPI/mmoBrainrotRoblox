--!strict
-- S155: the HUD elements the tutorial hint points at (Logic/Tutorial anchors) and the pulsing outline over the one it
-- points at. An anchor is looked up by the element's Name in a layer's Root (the HUD rebuilds on every character
-- entry, so nothing is cached past its parent), and only while the element and every ancestor are visible; on a phone
-- the Roblox thumbstick has no element: "joystick" is the lower left part of the screen where it appears. Rectangles
-- are in the layer's virtual pixels (UI/Scale), so a window resize or a phone rotation moves the hint with the HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Rect = { x: number, y: number, w: number, h: number }

local HudAnchors = {}

-- Anchor -> element Name on PC / on a phone (nil: no element on that device).
HudAnchors.NAMES = table.freeze({
	questTracker = { pc = "QuestTracker", touch = "QuestTracker" },
	backpackButton = { pc = "inventory", touch = "inventory" }, -- the menu button of the backpack window (Hud menu)
	potionBar = { pc = "PotionBar", touch = "PotionBar" },
	attackButton = { touch = "AttackButton" },
	skillBar = { pc = "Skill1", touch = "MobileSkill1" },
} :: { [string]: { pc: string?, touch: string? } })

-- The thumbstick zone of a phone as shares of the layer (left, top, width, height).
local JOYSTICK = { x = 0.04, y = 0.58, w = 0.26, h = 0.34 }

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
		return { x = size.X * JOYSTICK.x, y = size.Y * JOYSTICK.y, w = size.X * JOYSTICK.w, h = size.Y * JOYSTICK.h }
	end
	local names = HudAnchors.NAMES[anchor]
	local name = names and (if touch then names.touch else names.pc)
	if not name then
		return nil
	end
	local object = root:FindFirstChild(name, true)
	if not object or not object:IsA("GuiObject") or not shown(object, root) then
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
