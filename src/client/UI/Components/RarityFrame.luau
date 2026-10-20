--!strict
-- W28: the one place that draws an item's rarity frame (owner: "ramki itemów uni itp. grubsze i bardziej widoczne").
-- Used by ItemSlot (every item cell: backpack, equipment, deposit, shop, loot, trade, mail, smith...), the item
-- tooltip border and the ground loot label. Geometry comes from Logic/RarityFrame (scaled to the slot size).
--   RarityFrame.color(id)                      full-saturation identity colour (Data/Rarities `color`)
--   RarityFrame.stroke(scope, props)           the slot's inner UIStroke (band); hint / selection override it
--   RarityFrame.back(scope, props)             background tint (under the icon): rarity light rising from the bottom
--   RarityFrame.front(scope, props)            over the icon's margin: dark keyline (parchment), inner glow (Heroic+),
--                                              corner studs (Unique+)
--   RarityFrame.panelStroke(scope, rarity)     a panel border (tooltip) in the rarity colour, thicker from Unique
-- Motion: Legendary frames get a light sweeping along the band (shimmer), Mythic a slow pulsing inner glow. One
-- RenderStepped connection (only while such a frame exists) drives them at ~30 Hz and skips frames that are not
-- shown (hidden window, disabled ScreenGui).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Geometry = require(ReplicatedStorage.Shared.Logic.RarityFrame)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type UsedAs<T> = Fusion.UsedAs<T>
type Scope = Fusion.Scope<typeof(Fusion)>

export type Override = { color: Color3, thickness: number }

local RarityFrame = {}

-- Motion ------------------------------------------------------------------------------------------------------------

local SHIMMER_SWEEP = 1.4 -- seconds the light takes across a Legendary frame
local SHIMMER_REST = 2.2 -- pause between sweeps
local SHIMMER_REACH = 0.75 -- gradient offset at which the light is out of the frame
local PULSE_PERIOD = 2.8 -- seconds of one Mythic glow breath
local PULSE_LOW, PULSE_HIGH = 0.82, 0.3 -- glow transparency at rest / at its peak
local STEP = 1 / 30
local VISIBILITY_EVERY = 0.4

type Anim = { kind: "shimmer" | "pulse", target: Instance, shown: boolean }

local anims: { [Instance]: Anim } = {}
local animCount = 0
local connection: RBXScriptConnection? = nil
local elapsed, sinceVisibility = 0, math.huge

-- Shown = every GuiObject above the animated instance up to its LayerCollector is Visible and the collector is
-- enabled and in the game.
local function isShown(target: Instance): boolean
	local node: Instance? = target
	while node do
		if node:IsA("GuiObject") then
			if not (node :: GuiObject).Visible then
				return false
			end
		elseif node:IsA("LayerCollector") then
			return (node :: LayerCollector).Enabled and node:IsDescendantOf(game)
		end
		node = node.Parent
	end
	return false
end

local function shimmerOffset(now: number): Vector2
	local t = now % (SHIMMER_SWEEP + SHIMMER_REST)
	if t >= SHIMMER_SWEEP then
		return Vector2.new(-SHIMMER_REACH, 0)
	end
	local p = t / SHIMMER_SWEEP
	p = p * p * (3 - 2 * p) -- ease in-out
	return Vector2.new(-SHIMMER_REACH + 2 * SHIMMER_REACH * p, 0)
end

local function pulseTransparency(now: number): number
	local wave = 0.5 - 0.5 * math.cos(now / PULSE_PERIOD * 2 * math.pi)
	return PULSE_LOW + (PULSE_HIGH - PULSE_LOW) * wave
end

local function step(dt: number)
	elapsed += dt
	sinceVisibility += dt
	if elapsed < STEP then
		return
	end
	elapsed = 0
	local recheck = sinceVisibility >= VISIBILITY_EVERY
	if recheck then
		sinceVisibility = 0
	end
	local now = os.clock()
	local offset = shimmerOffset(now)
	local glow = pulseTransparency(now)
	for _, anim in anims do
		if recheck then
			anim.shown = isShown(anim.target)
		end
		if anim.shown then
			if anim.kind == "shimmer" then
				(anim.target :: UIGradient).Offset = offset
			else
				(anim.target :: UIStroke).Transparency = glow
			end
		end
	end
end

local function animate(scope: Scope, kind: "shimmer" | "pulse", target: Instance)
	anims[target] = { kind = kind, target = target, shown = false }
	animCount += 1
	sinceVisibility = math.huge -- check the new frame's visibility on the next step
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
	table.insert(scope :: any, function()
		if anims[target] then
			anims[target] = nil
			animCount -= 1
		end
		if animCount <= 0 and connection then
			connection:Disconnect()
			connection = nil
		end
	end)
end

-- Colours -----------------------------------------------------------------------------------------------------------

-- The frame shows the rarity's identity colour at full saturation on every surface (parchment slots get a dark
-- keyline around it instead of a darkened colour, so Unique yellow stays yellow).
function RarityFrame.color(rarity: number): Color3
	return Rarities.get(rarity).color
end

-- Light accent of a rarity (corner studs, shimmer): the second gradient colour, otherwise the colour lightened.
local function accent(r: Rarities.RarityDef): Color3
	if r.frame.gradient then
		return r.frame.gradient[2]
	end
	return Theme.mix(r.color, Theme.Plain, 0.45)
end

-- Gradient of a frame (c1 -> c2 -> c1), cached per rarity.
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

-- Legendary: the base colour with one narrow band of light that the shimmer moves along.
local shimmers: { [number]: ColorSequence } = {}
local function shimmerOf(r: Rarities.RarityDef): ColorSequence
	local cached = shimmers[r.id]
	if cached then
		return cached
	end
	local light = Theme.mix(accent(r), Theme.Plain, 0.35)
	local sequence = ColorSequence.new({
		ColorSequenceKeypoint.new(0, r.color),
		ColorSequenceKeypoint.new(0.4, r.color),
		ColorSequenceKeypoint.new(0.5, light),
		ColorSequenceKeypoint.new(0.6, r.color),
		ColorSequenceKeypoint.new(1, r.color),
	})
	shimmers[r.id] = sequence
	return sequence
end

-- Slot stroke -------------------------------------------------------------------------------------------------------

export type StrokeProps = {
	Rarity: UsedAs<number?>, -- rarity id of the item, nil = empty slot
	Size: number, -- slot side (px)
	Override: UsedAs<Override?>, -- drop hint / selection outline (plain, no rarity look)
	EmptyColor: Color3,
	EmptyTransparency: number,
}

-- The slot's frame band: an inner stroke (never wider than the slot, so grids with 4 px gaps stay clean).
function RarityFrame.stroke(scope: Scope, props: StrokeProps): Instance
	return scope:New("UIStroke")({
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		Thickness = scope:Computed(function(use): number
			local o = use(props.Override)
			if o then
				return o.thickness
			end
			return Geometry.band(use(props.Rarity), props.Size)
		end),
		Color = scope:Computed(function(use): Color3
			local o = use(props.Override)
			if o then
				return o.color
			end
			local id = use(props.Rarity)
			if not id then
				return props.EmptyColor
			end
			local r = Rarities.get(id)
			return if r.frame.gradient then Theme.Plain else r.color -- the gradient carries the colour
		end),
		Transparency = scope:Computed(function(use): number
			return if use(props.Rarity) ~= nil or use(props.Override) ~= nil then 0 else props.EmptyTransparency
		end),
		[Children] = scope:Computed(function(use, s: Scope): Instance?
			local id = use(props.Rarity)
			if not id or use(props.Override) ~= nil then
				return nil
			end
			local r = Rarities.get(id)
			if not r.frame.gradient then
				return nil
			end
			if r.frame.spin and id < Rarities.MYTHIC then
				-- Legendary: the shimmer
				local gradient = s:New("UIGradient")({
					Color = shimmerOf(r),
					Rotation = 25,
					Offset = Vector2.new(-SHIMMER_REACH, 0),
				})
				animate(s, "shimmer", gradient)
				return gradient
			end
			return s:New("UIGradient")({ Color = gradientOf(r), Rotation = 45 })
		end) :: any,
	})
end

-- Slot back and front -----------------------------------------------------------------------------------------------

export type LayerProps = {
	Rarity: UsedAs<number?>,
	Size: number,
	Surface: string?, -- "paper" (default) gets the dark keyline; "iron" does not need it
	Visible: UsedAs<boolean>?, -- hidden while a drop hint / the selection replaces the frame
}

-- Background tint: the rarity colour rising from the bottom of the slot, gone by its middle (Unique and better).
-- ZIndex 0: under the icon (ItemIcon is ZIndex 1).
function RarityFrame.back(scope: Scope, props: LayerProps): Instance
	return scope:New("Frame")({
		Name = "RarityTint",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		BackgroundColor3 = scope:Computed(function(use): Color3
			local id = use(props.Rarity)
			return if id then Rarities.get(id).color else Theme.Plain
		end),
		BackgroundTransparency = scope:Computed(function(use): number
			local id = use(props.Rarity)
			return if id and Geometry.tint(id) < 1 then 0 else 1
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIGradient")({
				Rotation = 270, -- 0 = bottom of the slot
				Transparency = scope:Computed(function(use): NumberSequence
					local strength = Geometry.tint(use(props.Rarity))
					return NumberSequence.new({
						NumberSequenceKeypoint.new(0, strength),
						NumberSequenceKeypoint.new(0.55, 1 - (1 - strength) * 0.15),
						NumberSequenceKeypoint.new(1, 1),
					})
				end),
			}),
		},
	})
end

-- A diamond stud on one corner of the band.
local function stud(s: Scope, at: Vector2, inset: number, side: number, color: Color3): Instance
	return s:New("Frame")({
		Name = "Stud",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(at.X, if at.X > 0 then -inset else inset, at.Y, if at.Y > 0 then -inset else inset),
		Size = UDim2.fromOffset(side, side),
		Rotation = 45,
		BackgroundColor3 = color,
		ZIndex = 2,
		[Children] = s:New("UIStroke")({
			Color = Theme.Shade,
			Thickness = 1,
			Transparency = 0.25,
		}),
	})
end

local CORNERS = { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }

-- Over the icon's margin (ZIndex 2, under the count / "+N" plaques at 3): keyline, inner glow, corner studs.
-- Built again only when the rarity changes, nothing at all for an empty slot.
function RarityFrame.front(scope: Scope, props: LayerProps): Instance
	local surface = props.Surface or "paper"
	return scope:New("Frame")({
		Name = "RarityFrame",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Visible = props.Visible,
		[Children] = scope:Computed(function(use, s: Scope): { Instance }
			local id = use(props.Rarity)
			if not id then
				return {}
			end
			local r = Rarities.get(id)
			local size = props.Size
			local band = Geometry.band(id, size)
			local out: { Instance } = {}
			if surface ~= "iron" then
				-- dark outer edge: light colours (Unique yellow, Common grey) stand out on parchment
				table.insert(
					out,
					s:New("Frame")({
						Name = "Keyline",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							s:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								BorderStrokePosition = Enum.BorderStrokePosition.Inner,
								Thickness = Geometry.KEYLINE,
								Color = Theme.Shade,
								Transparency = 0.35,
							}),
						},
					})
				)
			end
			if r.frame.glow then
				-- soft inner glow just inside the band (Heroic+); Mythic breathes
				local mythic = id >= Rarities.MYTHIC
				local glowStroke = s:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					Thickness = Geometry.glow(id, size),
					Color = accent(r),
					Transparency = if mythic then PULSE_LOW elseif r.frame.spin then 0.62 else 0.7,
				})
				table.insert(
					out,
					s:New("Frame")({
						Name = "Glow",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						[Children] = { s:New("UICorner")({ CornerRadius = Theme.Corner.Small }), glowStroke },
					})
				)
				if mythic then
					animate(s, "pulse", glowStroke)
				end
			end
			local side = Geometry.stud(id, size)
			if side > 0 then
				local inset = 1.5 + band * 0.5
				for _, at in CORNERS do
					table.insert(out, stud(s, at, inset, side, accent(r)))
				end
			end
			return out
		end) :: any,
	})
end

-- Panel border (item tooltip): the identity colour, 2 px for Common and 3 px from Unique; Legendary / Mythic carry
-- their gradient.
function RarityFrame.panelStroke(scope: Scope, rarity: UsedAs<number?>, empty: Color3): Instance
	return scope:New("UIStroke")({
		Thickness = scope:Computed(function(use): number
			local id = use(rarity)
			return if id and id >= Rarities.UNIQUE then 3 else 2
		end),
		Color = scope:Computed(function(use): Color3
			local id = use(rarity)
			if not id then
				return empty
			end
			local r = Rarities.get(id)
			return if r.frame.gradient then Theme.Plain else r.color
		end),
		[Children] = scope:Computed(function(use, s: Scope): Instance?
			local id = use(rarity)
			local r = if id then Rarities.get(id) else nil
			if not r or not r.frame.gradient then
				return nil
			end
			return s:New("UIGradient")({ Color = gradientOf(r), Rotation = 30 })
		end) :: any,
	})
end

return RarityFrame
