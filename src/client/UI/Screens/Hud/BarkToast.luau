--!strict
-- S101b (DESIGN-15 §3.5): the box of an NPC comment at the left edge of the screen (layer Toasts), used when the
-- speaker is not near enough for a bubble: a portrait (one shared Preview; the NPC's glyph when its model is not
-- streamed in), the name and the line (up to two rows). It slides in, and goes after Config.Barks.toastSeconds or on a
-- click / touch. PC: 380 x 76 at 42% of the height; phone (Device.Touch): 300 x 68 at 30%, above the joystick and away
-- from the skill buttons. BarkController shows one comment at a time.
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): the box is one of
-- UI/Notify's messages (BarkController pushes it): on PC in HudZones.barkSlot (the left edge, clear of the HUD), on a
-- tablet in the band under the target, on a phone one line of its M zone; in combat it waits up to 30 s, then drops.
-- This file keeps its look; each box has its own portrait (the scope of the message cleans it up).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Notify = require(script.Parent.Parent.Parent.Notify)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Preview = require(script.Parent.Parent.WorldMap.Preview)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local PORTRAIT = 56
local PORTRAIT_PHONE = 40

local BarkToast = {}

-- Its size on PC and on a touch screen (a phone: the M zone's width, PHONE_H high).
BarkToast.SIZE = table.freeze({ pc = Vector2.new(380, 76), touch = Vector2.new(300, 68) })
BarkToast.PHONE_H = 56

-- The look of `npcId` saying `line` in the place UI/Notify gives it.
function BarkToast.build(npcId: string, line: string): (Scope, Notify.Live) -> Instance
	return function(scope: Scope, live: Notify.Live): Instance
		local portrait = if live.phone then PORTRAIT_PHONE else PORTRAIT
		local preview = Preview.new(scope, nil, { portrait = true })
		local def = Npcs.get(npcId)
		preview.show(
			if def
				then { kind = "npc", id = def.id, glyph = def.icon }
				else { kind = "glyph", id = "", glyph = "?", color = Theme.Iron.Text }
		)
		local nameHeight = 18 -- review 2026-11-10: Small on a phone too (Caption is for capitals only)
		return scope:New("Frame")({
			Name = "BarkToast",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Iron.Surface,
			BackgroundTransparency = Theme.HudAlpha,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
				scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
				scope:New("Frame")({
					Name = "Portrait",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 8, 0.5, 0),
					Size = UDim2.fromOffset(portrait, portrait),
					BackgroundColor3 = Theme.Iron.Sunken,
					ClipsDescendants = true,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
						preview.frame,
					},
				}),
				scope:New("TextLabel")({
					Name = "Name",
					Position = UDim2.fromOffset(portrait + 18, 4),
					Size = UDim2.new(1, -(portrait + 26), 0, nameHeight),
					BackgroundTransparency = 1,
					Text = if def then Text.now(def.nameKey) else "",
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Iron.Heading,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				scope:New("TextLabel")({
					Name = "Line",
					Position = UDim2.fromOffset(portrait + 18, nameHeight + 6),
					Size = UDim2.new(1, -(portrait + 26), 1, -(nameHeight + 8)),
					BackgroundTransparency = 1,
					Text = line,
					TextWrapped = true,
					TextScaled = false,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Iron.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				scope:New("TextButton")({
					Name = "Dismiss",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 5,
					[OnEvent("Activated")] = live.close,
				}),
			},
		})
	end
end

return BarkToast
