--!strict
-- Season pass button (S152b, docs/DESIGN.md §21b): ❖ under the login reward button ✧ (right of the portrait), the same
-- on PC and touch; a phone in landscape has it in the menu drawer. UI plan phase 1 (owner 2026-10-31, too much on one
-- screen): shown only while a reward waits (Logic/SeasonView.claimCount, also in an ended season's grace days), with
-- the "!" badge and a slowly pulsing brass frame; the tooltip names the tier with the points of the current tier. Opens
-- the season pass window (SeasonController); C and the game menu's tile open it at any time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconButton = require(script.Parent.Parent.Parent.Components.IconButton)
local SeasonState = require(script.Parent.Parent.Parent.SeasonState)
local SeasonView = require(ReplicatedStorage.Shared.Logic.SeasonView)
local Seasons = require(ReplicatedStorage.Shared.Data.Seasons)
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
local GLYPH = "❖"

local function SeasonButton(scope: Scope, props: Props): Instance
	local view = SeasonState.View
	local badge = scope:Computed(function(use): boolean
		return SeasonView.claimCount(use(view)) > 0
	end)
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
	local tooltip = scope:Computed(function(use): string
		local v = use(view)
		local def = v.def
		if not def then
			return Text.get(use, "season.window.title")
		end
		local lines = {
			Text.get(use, "season.button", { season = Text.get(use, def.nameKey), tier = v.tier, tiers = def.tiers }),
		}
		if v.mode == "running" and not v.maxed then
			table.insert(
				lines,
				Text.get(use, "season.button.points", {
					points = Format.number(v.progress),
					tier = Format.number(Seasons.TIER_POINTS),
				})
			)
		end
		local n = SeasonView.claimCount(v)
		if n > 0 then
			table.insert(lines, Text.get(use, "season.button.claim", { n = n }))
		end
		return table.concat(lines, "\n")
	end)
	return scope:New("Frame")({
		Name = "SeasonPass",
		Position = props.Position,
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		Visible = badge,
		[Children] = {
			IconButton(scope, {
				Name = "SeasonPassButton",
				Icon = GLYPH,
				ArtKey = UiArt.hud("season"),
				Size = UDim2.fromOffset(SIZE, SIZE),
				Tooltip = tooltip,
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

return SeasonButton
