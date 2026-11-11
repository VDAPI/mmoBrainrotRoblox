--!strict
-- W29: the phone HUD on the client (Logic/PhoneHud). `Compact` is true on a touch screen whose UI area is shorter than
-- PhoneHud.MAX_HEIGHT virtual pixels; the helpers give an element its phone place (position, anchor point, scale)
-- while it is, and its own one otherwise.
-- Owner 2026-11-10 (UI plan package A, the phone grid): a place follows the HUD layer's size (Scale.HudSize: the
-- minimap shrinks to 0.5 under 420 high, the drawer and PvP buttons and the M zone move with it), so every helper
-- reads `Places`, the places of the layer as it is now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local Scale = require(script.Parent.Scale)
local State = require(script.Parent.State)

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

local PhoneLayout = {}

local scope = Fusion.scoped(Fusion)

PhoneLayout.Compact = scope:Computed(function(use): boolean
	return PhoneHud.compact(use(Device.Touch) == true, use(Scale.VirtualSize).Y)
end)

-- Party members besides the player (the party frames above the stack).
local partyState = State.Value({ "party" })
PhoneLayout.Others = scope:Computed(function(use): number
	local party = use(partyState)
	local others = 0
	if type(party) == "table" and type(party.members) == "table" then
		for _, member in party.members do
			if type(member) == "table" and member.id ~= Players.LocalPlayer.UserId then
				others += 1
			end
		end
	end
	return others
end)

-- The phone places of the layer as it is now (Logic/PhoneHud.places of Scale.HudSize).
PhoneLayout.Places = scope:Computed(function(use): { [string]: PhoneHud.Place }
	local size: Vector2 = use(Scale.HudSize)
	return PhoneHud.places(size.X, size.Y)
end)

-- The place `name` of the layer now (the reference phone's while the layer has no place of that name: the guide bar
-- of a layer whose M zone is too short, which then stands in the stack).
local function placeOf(use: Fusion.Use, name: string): PhoneHud.Place
	local place = use(PhoneLayout.Places)[name] or PhoneHud.place(name)
	return assert(place, `no phone place {name}`)
end

-- The position: the phone place while compact, `default` otherwise.
function PhoneLayout.Position(s: Scope, name: string, default: UsedAs<UDim2>): Fusion.Computed<UDim2>
	return s:Computed(function(use): UDim2
		if not use(PhoneLayout.Compact) then
			return use(default)
		end
		local xs, xo, ys, yo = PhoneHud.udim(placeOf(use, name))
		return UDim2.new(xs, xo, ys, yo)
	end)
end

-- The anchor point that goes with Position.
function PhoneLayout.Anchor(s: Scope, name: string, default: UsedAs<Vector2>): Fusion.Computed<Vector2>
	return s:Computed(function(use): Vector2
		if not use(PhoneLayout.Compact) then
			return use(default)
		end
		local _, _, _, _, ax, ay = PhoneHud.udim(placeOf(use, name))
		return Vector2.new(ax, ay)
	end)
end

-- The size: the place's own (w x h) while compact, `default` otherwise (a scaled place keeps `default`: its UIScale
-- shrinks it).
function PhoneLayout.Size(s: Scope, name: string, default: UsedAs<UDim2>): Fusion.Computed<UDim2>
	return s:Computed(function(use): UDim2
		if not use(PhoneLayout.Compact) then
			return use(default)
		end
		local place = placeOf(use, name)
		return if place.scale then use(default) else UDim2.fromOffset(place.w, place.h)
	end)
end

-- A UIScale with the place's scale while compact (1 otherwise).
function PhoneLayout.UIScale(s: Scope, name: string): Instance
	return s:New("UIScale")({
		Scale = s:Computed(function(use): number
			return if use(PhoneLayout.Compact) then placeOf(use, name).scale or 1 else 1
		end),
	})
end

-- Whether the layer has place `name` now (the guide bar has one in the M zone only while M reaches 218).
function PhoneLayout.Has(s: Scope, name: string): Fusion.Computed<boolean>
	return s:Computed(function(use): boolean
		return use(PhoneLayout.Compact) and use(PhoneLayout.Places)[name] ~= nil
	end)
end

-- `phone` while compact, `default` otherwise (either may be a state).
function PhoneLayout.Pick<T>(s: Scope, phone: UsedAs<T>, default: UsedAs<T>): Fusion.Computed<T>
	return s:Computed(function(use): T
		return if use(PhoneLayout.Compact) then use(phone) else use(default)
	end)
end

return PhoneLayout
