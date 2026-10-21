--!strict
-- Achievements button (S151c, docs/DESIGN.md §20c): ✪ under the season pass button ❖ (right of the portrait), the same
-- on PC and touch, always shown (the owner did not find the entry in the HUD menu). The tooltip names the window, the
-- bestiary inside it and the key N; the "!" badge and a pulsing brass frame after an achievement or a bestiary tier
-- earned since the window was last open (AchievementButton.Unseen, set by AchievementController). Opens the
-- achievements window (the same toggle as the menu entry and N).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconButton = require(script.Parent.Parent.Parent.Components.IconButton)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Open: () -> (),
	Position: UDim2,
}

local SIZE = 44
local PULSE_SPEED = 3 -- rad/s
local GLYPH = "✪"

local stateScope = Fusion.scoped(Fusion)

local AchievementButton = {}

-- Something new waits in the window (AchievementController sets it on AchievementDone, clears it on opening).
AchievementButton.Unseen = stateScope:Value(false)

function AchievementButton.new(scope: Scope, props: Props): Instance
	local badge = AchievementButton.Unseen
	local pulse = scope:Value(0)
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			if Fusion.peek(badge) then
				pulse:set((math.sin(os.clock() * PULSE_SPEED) + 1) / 2)
			elseif Fusion.peek(pulse) ~= 0 then
				pulse:set(0)
			end
		end)
	)
	return scope:New("Frame")({
		Name = "Achievements",
		Position = props.Position,
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		[Children] = {
			IconButton(scope, {
				Name = "AchievementsButton",
				Icon = GLYPH,
				ArtKey = UiArt.menu("achievements"),
				Hotkey = "N",
				Size = UDim2.fromOffset(SIZE, SIZE),
				Tooltip = scope:Computed(function(use): string
					local lines = { Text.get(use, "hud.achButton") }
					if use(badge) then
						table.insert(lines, Text.get(use, "hud.achButton.new"))
					end
					return table.concat(lines, "\n")
				end),
				Badge = badge,
				OnClick = props.Open,
			}),
			scope:New("Frame")({
				Name = "Glow",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Active = false,
				ZIndex = 2,
				Visible = badge,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Theme.Brass.Bright,
						Thickness = Theme.Stroke.Thick,
						Transparency = scope:Computed(function(use): number
							return 0.6 * use(pulse)
						end),
					}),
				},
			}),
		},
	})
end

return AchievementButton
