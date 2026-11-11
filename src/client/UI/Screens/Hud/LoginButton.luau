--!strict
-- Login reward button (S100, docs/DESIGN-15.md §5): ✧ right of the portrait, aligned to its bottom (below the elixir
-- icons, above the effect icons), the same on PC and touch; a phone in landscape has it in the menu drawer. UI plan
-- phase 1 (owner 2026-10-31, too much on one screen): shown only while a reward waits, with the "!" badge and a slowly
-- pulsing gold frame; the tooltip names the streak day. Opens the login window (LoginRewardController); the game
-- menu's tile opens it at any time.
-- Owner 2026-11-10 ("too much text"; UI plan package A, a HUD line at most 32 characters): "Daily reward: day 3/7".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconButton = require(script.Parent.Parent.Parent.Components.IconButton)
local LoginReward = require(ReplicatedStorage.Shared.Logic.LoginReward)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Status: Fusion.UsedAs<LoginReward.Status?>,
	Badge: Fusion.UsedAs<boolean>,
	Open: () -> (),
	Position: UDim2,
}

local SIZE = 44
local PULSE_SPEED = 3 -- rad/s

local function LoginButton(scope: Scope, props: Props): Instance
	local pulse = scope:Value(0)
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			if Fusion.peek(props.Badge) == true then
				pulse:set((math.sin(os.clock() * PULSE_SPEED) + 1) / 2)
			elseif Fusion.peek(pulse) ~= 0 then
				pulse:set(0)
			end
		end)
	)
	local tooltip = scope:Computed(function(use): string
		local status = use(props.Status)
		if not status then
			return Text.get(use, "login.title")
		end
		return Text.get(use, if status.claimedToday then "login.buttonDone" else "login.button", { n = status.day })
	end)
	return scope:New("Frame")({
		Name = "LoginReward",
		Position = props.Position,
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		Visible = props.Badge,
		[Children] = {
			IconButton(scope, {
				Name = "LoginRewardButton",
				Icon = "✧",
				Size = UDim2.fromOffset(SIZE, SIZE),
				Tooltip = tooltip,
				Badge = props.Badge,
				OnClick = props.Open,
			}),
			scope:New("Frame")({
				Name = "Glow",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Active = false,
				ZIndex = 2,
				Visible = props.Badge,
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

return LoginButton
