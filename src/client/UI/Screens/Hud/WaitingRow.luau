--!strict
-- UI plan phase 2 (owner 2026-10-31, "too much information and too many options on one screen"; plan §2: one place
-- for "something waits"): a row of small buttons under the minimap, right-aligned, each only while its thing waits:
-- the mail envelope with the number of parcels (Hud/MailButton), the login reward ✧ (Hud/LoginButton), the season
-- pass ❖ with a reward to claim (Hud/SeasonButton) and the Blood Moon ☾ while its results are still published after
-- the event (its panel shows the event itself). PC and tablet: in the menu's column under the minimap, or
-- under the guide bar while one shows; the quest tracker's column starts under it (UI/HudSlots.Waiting,
-- Logic/HudStack.WAITING). A phone in landscape keeps the drawer (☰) and the envelope by the skill arc.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BloodMoonView = require(script.Parent.Parent.Parent.BloodMoonView)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudCover = require(script.Parent.Parent.Parent.HudCover)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local IconButton = require(script.Parent.Parent.Parent.Components.IconButton)
local LoginButton = require(script.Parent.LoginButton)
local LoginReward = require(ReplicatedStorage.Shared.Logic.LoginReward)
local Mail = require(ReplicatedStorage.Shared.Logic.Mail)
local MailButton = require(script.Parent.MailButton)
local NavTarget = require(script.Parent.Parent.Parent.NavTarget)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local SeasonButton = require(script.Parent.SeasonButton)
local SeasonState = require(script.Parent.Parent.Parent.SeasonState)
local SeasonView = require(ReplicatedStorage.Shared.Logic.SeasonView)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	LayoutOrder: number,
	LoginStatus: Fusion.UsedAs<LoginReward.Status?>,
	LoginBadge: Fusion.UsedAs<boolean>,
	OpenLogin: () -> (),
	OpenWindow: (id: string) -> (),
	ShowWindow: (id: string) -> (),
	-- Studio check 2026-10-31: the menu's buttons above are under a window; the row goes with them (one group)
	Covered: Fusion.UsedAs<boolean>?,
}

local SIZE = HudStack.WAITING
-- Without the guide bar the row starts where Logic/HudStack.RIGHT_TOP says, RIGHT_TOP_GUIDE with the guide bar. UI plan
-- phase 4: the minimap's area line moved into its caption, so the row stands right under the minimap (0 here).
local UNDER_AREA_LINE = HudStack.RIGHT_TOP - (22 + 52 + 8 + 266) - 8

local function WaitingRow(scope: Scope, props: Props): Instance
	local mail = State.Value({ "mail" })
	local bloodMoonResults = scope:Computed(function(use): boolean
		return use(BloodMoonView.Phase) == "ended"
	end)
	local any = scope:Computed(function(use): boolean
		return (Mail.badge(use(mail))) > 0
			or use(props.LoginBadge) == true
			or SeasonView.claimCount(use(SeasonState.View)) > 0
			or use(bloodMoonResults)
	end)
	local shown = scope:Computed(function(use): boolean
		return use(any) and not use(PhoneLayout.Compact)
	end)
	-- the quest tracker's column starts under the row while it shows (one entry per row: a rebuilt row's cleanup
	-- never switches off the new one's)
	local owner = {}
	scope:Observer(shown):onBind(function()
		HudSlots.SetWaiting(owner, Fusion.peek(shown))
	end)
	table.insert(scope, function()
		HudSlots.SetWaiting(owner, nil)
	end)
	local pad = scope:Computed(function(use): number
		return if use(NavTarget.Target) ~= nil then 0 else UNDER_AREA_LINE
	end)

	local login: any = LoginButton(scope, {
		Status = props.LoginStatus,
		Badge = props.LoginBadge,
		Open = props.OpenLogin,
		Position = UDim2.new(),
	})
	login.LayoutOrder = 2
	local season: any = SeasonButton(scope, {
		Open = function()
			props.OpenWindow("season")
		end,
		Position = UDim2.new(),
	})
	season.LayoutOrder = 3

	local buttons = scope:New("Frame")({
		Name = "Buttons",
		Size = UDim2.fromOffset(0, SIZE),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			MailButton(scope, {
				InRow = true,
				Open = function()
					props.ShowWindow("mail")
				end,
			}),
			login,
			season,
			IconButton(scope, {
				Name = "BloodMoonResults",
				LayoutOrder = 4,
				Icon = "☾",
				ArtKey = UiArt.menu("bloodmoon"),
				Size = UDim2.fromOffset(SIZE, SIZE),
				Tooltip = Text.T(scope, "hud.waiting.bloodmoon"),
				Badge = bloodMoonResults,
				Visible = bloodMoonResults,
				OnClick = function()
					props.OpenWindow("bloodmoon")
				end,
			}),
		},
	}) :: Frame
	-- UI plan phase 2: out of sight while an open window covers it (UI/HudCover); the row keeps its height, so the
	-- minimap and the guide bar above never move
	local own = HudCover.covered(scope, buttons)
	local covered = scope:Computed(function(use): boolean
		return use(own) or use(props.Covered or false) == true
	end)
	scope:Observer(covered):onBind(function()
		buttons.Visible = not Fusion.peek(covered)
	end)

	return scope:New("Frame")({
		Name = "Waiting",
		LayoutOrder = props.LayoutOrder,
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(0, SIZE + use(pad))
		end),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Visible = shown,
		[Children] = {
			scope:New("UIPadding")({
				PaddingTop = scope:Computed(function(use): UDim
					return UDim.new(0, use(pad))
				end),
			}),
			scope:New("UIListLayout")({
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			buttons,
		},
	})
end

return WaitingRow
