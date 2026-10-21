--!strict
-- Owner 2026-10-21 (Studio: the quest tracker's header "≡ Cele" showed over "Loading your character…"): the HUD's
-- panels that controllers mount outside Screens/Hud (the column of UI/HudSlots, the party frames, the dungeon boss
-- bar, the kill feed) go into one frame of the Screens layer that shows only while the character plays (session
-- phase "playing", the moment ScreenController swaps the loading / select screen for the HUD).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.State)

local HudGate = {}

local scope = Fusion.scoped(Fusion)
local phase = State.Value({ "session", "phase" })

-- Whether the HUD shows: the character is in the world.
HudGate.Playing = scope:Computed(function(use): boolean
	return use(phase) == "playing"
end)

local frames: { [Instance]: Frame } = {}

-- The gated frame inside `layer` (UIController.GetLayer("Screens")), made once: full size, transparent, so the
-- panels keep their places.
function HudGate.Layer(layer: Instance): Frame
	local frame = frames[layer]
	if frame then
		return frame
	end
	local made = scope:New("Frame")({
		Name = "HudPanels",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = HudGate.Playing,
		Parent = layer,
	}) :: Frame
	frames[layer] = made
	return made
end

return HudGate
