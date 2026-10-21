--!strict
-- The Champion's Tournament on the HUD (S130, DESIGN-17 §8), from the runtime branch `tourney` and the level only:
--   * a world server, the signups open, level 20+: "Champion's Tournament: signups until 18:50" with "Signups" (the
--     arena window's tournament tab), or "Signed up (20–39)"; an invitation: "Tournament invitation: 97 s" with
--     "Show" (the card again); other phases: nothing;
--   * the server of a bracket (`tourney.live`): the title and the bracket, the round, the player's state (waiting,
--     the field of the match, out with the place, champion), "Bracket", and "Return to the world" (a tournament server,
--     or out of a local bracket; while still in the bracket it asks first: a walkover) with "Stay and watch" for the
--     out; after the final "Returning in 52 s".
-- PC: the right column over the quest tracker (under the world event / Blood Moon panel, `Above`), the tracker moves
-- down by `Offset`. Touch: the left column under the portrait (under a world event panel), folded to one line, a tap
-- unfolds it (buttons 44 px); it leaves the match panel (top centre) and the skill buttons free.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local ClockText = require(script.Parent.Parent.Parent.ClockText)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudDrag = require(script.Parent.Parent.Parent.HudDrag)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tourney = require(ReplicatedStorage.Shared.Logic.Tourney)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use

export type Props = {
	OpenTab: () -> (),
	ShowInvite: () -> (),
	Leave: () -> (),
	-- PC: set to the pixels the quest tracker moves down for this panel (0 while hidden or on touch)
	Offset: Fusion.Value<number>?,
	-- PC: the height of the panels above this one (world event, Blood Moon)
	Above: Fusion.UsedAs<number>?,
}

local GOLD = Theme.Brass.Bright
local WIDTH_PC = 280
local WIDTH_TOUCH = 240
local PAD = 8
local GAP = 3
local TITLE = 22
local LINE = 20
local BUTTON_PC = 34
local BUTTON_TOUCH = 44
-- the anchors of Hud/WorldEventPanel and Hud/BloodMoonPanel
local TOUCH_TOP = Theme.Padding.Large + 136 + 6 + 44
local TOUCH_EVENT = 150 -- a world event panel above on touch (its largest height + a gap)
local PARTY_TOP = Theme.Padding.Large + 136 + 70
local PARTY_ROW = 58 + 6

local function TourneyPanel(scope: Scope, props: Props): Instance
	local tourney = State.Value({ "tourney" })
	local level = State.Value({ "character", "level" })
	local party = State.Value({ "party" })
	local worldEvent = State.Value({ "worldEvent" })
	local touch = Device.Touch
	local now = scope:Value(Clock.now())
	local expanded = scope:Value(false)
	local staying = scope:Value(false)
	local acc = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc >= 0.5 then
				acc = 0
				now:set(Clock.now())
			end
		end)
	)

	-- "signup" | "signed" | "invite" | "live" | nil
	local kind = scope:Computed(function(use): string?
		local t = use(tourney)
		if type(t) ~= "table" then
			return nil
		end
		if type(t.live) == "table" then
			return "live"
		end
		if type(t.invite) == "table" then
			return "invite"
		end
		if t.server ~= "world" or t.phase ~= "signup" then
			return nil
		end
		if Tourney.bracketOf(tonumber(use(level)) or 0) == nil then
			return nil
		end
		return if type(t.signed) == "table" then "signed" else "signup"
	end)
	local shown = scope:Computed(function(use): boolean
		return use(kind) ~= nil
	end)
	local live = scope:Computed(function(use): any
		local t = use(tourney)
		return if type(t) == "table" and type(t.live) == "table" then t.live else nil
	end)
	local me = scope:Computed(function(use): any
		local l = use(live)
		return if l and type(l.me) == "table" then l.me else nil
	end)

	local function roundText(use: Use, l: any): string
		local view = l.view
		if type(view) ~= "table" or type(view.matches) ~= "table" then
			return ""
		end
		-- the earliest round with a match still to fight
		local round = view.rounds
		for _, m in view.matches do
			if m.winner == nil and m.round < round then
				round = m.round
			end
		end
		local key = Tourney.roundKey(round, view.rounds)
		if key then
			return Text.get(use, key)
		end
		return Text.get(use, "tourney.round", { r = round, total = view.rounds })
	end

	local headline = scope:Computed(function(use): string
		if use(kind) == "live" then
			local l = use(live)
			return `⚜ {Text.get(use, "tourney.title")} · {l.range}`
		end
		return `⚜ {Text.get(use, "tourney.title")}`
	end)
	local line1 = scope:Computed(function(use): string
		local k = use(kind)
		local t = use(tourney)
		if type(t) ~= "table" then
			return ""
		end
		if k == "signup" then
			local close = Tourney.times(tonumber(t.startAt) or 0).close
			return Text.get(use, "tourney.hud.signup", { time = ClockText.hhmm(close) })
		elseif k == "signed" then
			return Text.get(use, "tourney.hud.signed", { range = Tourney.rangeOf(t.signed.bracket) })
		elseif k == "invite" then
			local left = math.max(0, (tonumber(t.invite.expiresAt) or 0) - use(now))
			return Text.get(use, "tourney.hud.invite", { s = math.ceil(left) })
		elseif k == "live" then
			local l = use(live)
			local ends = tonumber(l.endsAt)
			if ends then
				return Text.get(use, "tourney.ending", { s = math.max(0, math.ceil(ends - use(now))) })
			end
			return roundText(use, l)
		end
		return ""
	end)
	local line2 = scope:Computed(function(use): string
		if use(kind) ~= "live" then
			return ""
		end
		local m = use(me)
		if not m then
			return ""
		end
		if m.state == "fighting" then
			return Text.get(use, "tourney.called", { field = m.field or 1 })
		elseif m.state == "waiting" then
			return Text.get(use, "tourney.waiting")
		elseif m.state == "out" then
			local key, args = Tourney.placeKey(m.place or 0)
			return Text.get(use, "tourney.out", { place = Text.get(use, key, args) })
		elseif m.state == "champion" then
			return Text.get(use, "tourney.youChampion")
		end
		return Text.get(use, "tourney.spectating")
	end)
	local isOut = scope:Computed(function(use): boolean
		local m = use(me)
		return m ~= nil and (m.state == "out" or m.state == "champion" or m.state == "spectator")
	end)
	local canLeave = scope:Computed(function(use): boolean
		local t = use(tourney)
		if use(kind) ~= "live" or type(t) ~= "table" then
			return false
		end
		if t.server == "tournament" then
			return not use(staying) or not use(isOut)
		end
		-- a local bracket: leaving = withdrawing while still in it
		return not use(isOut)
	end)
	local showStay = scope:Computed(function(use): boolean
		local t = use(tourney)
		return use(kind) == "live"
			and use(isOut)
			and not use(staying)
			and type(t) == "table"
			and t.server == "tournament"
	end)
	-- touch: one line until tapped
	local folded = scope:Computed(function(use): boolean
		return use(touch) and not use(expanded)
	end)

	local buttonH = scope:Computed(function(use): number
		return if use(touch) then BUTTON_TOUCH else BUTTON_PC
	end)
	local height = scope:Computed(function(use): number
		if use(folded) then
			return PAD * 2 + BUTTON_TOUCH
		end
		local k = use(kind)
		local h = PAD * 2 + TITLE + LINE + GAP
		if k == "live" then
			h += LINE + GAP + use(buttonH) + GAP
			if use(showStay) then
				h += use(buttonH) + GAP
			end
		elseif k ~= "signed" then
			h += use(buttonH) + GAP
		end
		return h
	end)
	local touchTop = scope:Computed(function(use): number
		local p = use(party)
		local others = 0
		if type(p) == "table" and type(p.members) == "table" then
			for _, member in p.members do
				if member.id ~= Players.LocalPlayer.UserId then
					others += 1
				end
			end
		end
		if use(PhoneLayout.Compact) then
			-- W29: the phone stack (Logic/PhoneHud), under the panels above it as on PC
			return PhoneHud.stackTop(others) + (if props.Above then use(props.Above) else 0)
		end
		local top = if others > 0 then PARTY_TOP + others * PARTY_ROW else TOUCH_TOP
		if use(worldEvent) ~= nil then
			top += TOUCH_EVENT
		end
		return top
	end)
	-- owner 2026-10-21: moved by its tab, scaled by its corner (UI/HudDrag); a moved panel leaves the column
	local handle = HudDrag.new(scope, "tourney", function(use)
		return if use(touch) then WIDTH_TOUCH else WIDTH_PC
	end)
	if props.Offset then
		local offset = props.Offset
		local pushed = scope:Computed(function(use): number
			-- W29: on a phone in landscape the tracker stacks under the panel as on PC
			if not use(shown) or (use(touch) and not use(PhoneLayout.Compact)) or use(handle.corner) then
				return 0
			end
			return use(height) + 8
		end)
		scope:Observer(pushed):onBind(function()
			offset:set(Fusion.peek(pushed))
		end)
	end

	local function label(order: number, h: number, text: any, color: any, size: number, font: Font, visible: any?)
		return scope:New("TextLabel")({
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, h),
			Text = text,
			TextColor3 = color,
			TextSize = size,
			FontFace = font,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Visible = visible,
		})
	end

	local function button(order: number, key: string, variant: string, visible: any, onClick: () -> ()): Instance
		return Button(scope, {
			Surface = "iron", -- S135: on a dark HUD / overlay surface
			LayoutOrder = order,
			Text = Text.T(scope, key),
			Variant = variant :: any,
			TextSize = Theme.TextSize.Small,
			Visible = visible,
			Size = scope:Computed(function(use): UDim2
				return UDim2.new(1, 0, 0, use(buttonH))
			end),
			OnClick = onClick,
		})
	end

	local notFolded = scope:Computed(function(use): boolean
		return not use(folded)
	end)

	local body = scope:New("Frame")({
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, PAD),
				PaddingBottom = UDim.new(0, PAD),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
			-- touch: the folded line (tap = unfold)
			scope:New("TextButton")({
				Name = "Fold",
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, BUTTON_TOUCH),
				BackgroundTransparency = 1,
				Visible = folded,
				Text = scope:Computed(function(use): string
					return `{use(headline)} · {use(line1)}`
				end),
				TextColor3 = GOLD,
				TextSize = Theme.TextSize.Small,
				FontFace = Theme.Fonts.BodyBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				[OnEvent("Activated")] = function()
					expanded:set(true)
				end,
			}),
			scope:New("TextButton")({
				Name = "Title",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, TITLE),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Visible = notFolded,
				Text = headline,
				TextColor3 = GOLD,
				TextSize = Theme.TextSize.Small,
				FontFace = Theme.Fonts.BodyBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				[OnEvent("Activated")] = function()
					if Fusion.peek(touch) then
						expanded:set(false)
					end
				end,
			}),
			label(2, LINE, line1, Theme.Iron.Text, Theme.TextSize.Small, Theme.Fonts.BodyMedium, notFolded),
			label(
				3,
				LINE,
				line2,
				Theme.Iron.Text,
				Theme.TextSize.Small,
				Theme.Fonts.Body,
				scope:Computed(function(use): boolean
					return not use(folded) and use(kind) == "live"
				end)
			),
			button(
				4,
				"tourney.hud.open",
				"secondary",
				scope:Computed(function(use): boolean
					return not use(folded) and use(kind) == "signup"
				end),
				props.OpenTab
			),
			button(
				5,
				"tourney.hud.show",
				"primary",
				scope:Computed(function(use): boolean
					return not use(folded) and use(kind) == "invite"
				end),
				props.ShowInvite
			),
			button(
				6,
				"tourney.bracketView",
				"secondary",
				scope:Computed(function(use): boolean
					return not use(folded) and use(kind) == "live" and not use(canLeave)
				end),
				props.OpenTab
			),
			-- the bracket and the way out side by side when both are offered
			scope:New("Frame")({
				Name = "Row",
				LayoutOrder = 7,
				BackgroundTransparency = 1,
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, use(buttonH))
				end),
				Visible = scope:Computed(function(use): boolean
					return not use(folded) and use(canLeave)
				end),
				[Children] = {
					Button(scope, {
						Surface = "iron", -- S135: on a dark HUD / overlay surface
						Size = UDim2.new(0.5, -3, 1, 0),
						Text = Text.T(scope, "tourney.bracketView"),
						Variant = "secondary",
						TextSize = Theme.TextSize.Small,
						OnClick = props.OpenTab,
					}),
					Button(scope, {
						Surface = "iron", -- S135: on a dark HUD / overlay surface
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0.5, -3, 1, 0),
						Text = Text.T(scope, "tourney.leave"),
						Variant = "danger",
						TextSize = Theme.TextSize.Small,
						OnClick = props.Leave,
					}),
				},
			}),
			button(8, "tourney.stay", "secondary", showStay, function()
				staying:set(true)
			end),
		},
	})
	return HudDrag.frame(scope, handle, {
		Name = "TourneyPanel",
		AnchorPoint = scope:Computed(function(use): Vector2
			return if use(touch) then Vector2.new(0, 0) else Vector2.new(1, 0)
		end),
		Position = scope:Computed(function(use): UDim2
			if use(touch) then
				return UDim2.fromOffset(Theme.Padding.Large, use(touchTop))
			end
			local above = if props.Above then use(props.Above) else 0
			return UDim2.new(1, -Theme.Padding.Large, 0, HudDrag.RIGHT_TOP + above)
		end),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(if use(touch) then WIDTH_TOUCH else WIDTH_PC, use(height))
		end),
		Visible = shown,
		Content = body,
	})
end

return TourneyPanel
