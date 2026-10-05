--!strict
-- The monster area the player stands in (S20, DESIGN §3.6), kept by AreaController and read by the HUD
-- (banner, minimap line).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

local AreaState = {}

-- Current area (nil outside every area).
AreaState.Current = scope:Value(nil :: Areas.Area?)
-- Last area entered with its banner (changes only when a banner should show).
AreaState.Banner = scope:Value(nil :: { area: Areas.Area, token: number }?)

return AreaState
