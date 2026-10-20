--!strict
-- W29: the phone HUD on the client (Logic/PhoneHud). `Compact` is true on a touch screen whose UI area is shorter than
-- PhoneHud.MAX_HEIGHT virtual pixels; the helpers give an element its phone place (position, anchor point, scale)
-- while it is, and its own one otherwise.

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

local function placeOf(name: string): PhoneHud.Place
	return assert(PhoneHud.place(name), `no phone place {name}`)
end

-- The position: the phone place while compact, `default` otherwise.
function PhoneLayout.Position(s: Scope, name: string, default: UsedAs<UDim2>): Fusion.Computed<UDim2>
	local place = placeOf(name)
	local xs, xo, ys, yo = PhoneHud.udim(place)
	local phone = UDim2.new(xs, xo, ys, yo)
	return s:Computed(function(use): UDim2
		return if use(PhoneLayout.Compact) then phone else use(default)
	end)
end

-- The anchor point that goes with Position.
function PhoneLayout.Anchor(s: Scope, name: string, default: UsedAs<Vector2>): Fusion.Computed<Vector2>
	local place = placeOf(name)
	local _, _, _, _, ax, ay = PhoneHud.udim(place)
	local phone = Vector2.new(ax, ay)
	return s:Computed(function(use): Vector2
		return if use(PhoneLayout.Compact) then phone else use(default)
	end)
end

-- The size: the place's own (w x h) while compact, `default` otherwise (a scaled place keeps `default`: its UIScale
-- shrinks it).
function PhoneLayout.Size(s: Scope, name: string, default: UsedAs<UDim2>): Fusion.Computed<UDim2>
	local place = placeOf(name)
	local phone = UDim2.fromOffset(place.w, place.h)
	return s:Computed(function(use): UDim2
		return if use(PhoneLayout.Compact) and not place.scale then phone else use(default)
	end)
end

-- A UIScale with the place's scale while compact (1 otherwise).
function PhoneLayout.UIScale(s: Scope, name: string): Instance
	local factor = placeOf(name).scale or 1
	return s:New("UIScale")({
		Scale = s:Computed(function(use): number
			return if use(PhoneLayout.Compact) then factor else 1
		end),
	})
end

-- `phone` while compact, `default` otherwise.
function PhoneLayout.Pick<T>(s: Scope, phone: T, default: UsedAs<T>): Fusion.Computed<T>
	return s:Computed(function(use): T
		return if use(PhoneLayout.Compact) then phone else use(default)
	end)
end

return PhoneLayout
