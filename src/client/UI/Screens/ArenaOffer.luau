--!strict
-- The match offer card (S126, DESIGN-17 §6): shown while `arenaLive.offer` exists. The opponent (name, class, level,
-- rating, tier sign), a bar of the time left to answer, Accept / Decline (44 px and more, at the bottom centre; on a
-- phone above the combat buttons, clear of the joystick), the warning of a match that will not change the rating and
-- the cost of declining. After accepting: "Waiting for the opponent…". S127 extends this card (it does not make
-- another one). S128: a 3v3 offer says "3 vs 3 match found" and lists both teams (offer.mine / offer.them).
-- S130: the Champion's Tournament invitation on the same card (state branch `tourney.invite`, while no match offer
-- waits): "Champion's Tournament (20–39): your place awaits. Accept within 97 s", the bar of Data/Arena.TOURNEY.window
-- .invite, Accept / Decline (TourneyRespond) and ✕ that only hides the card (the invitation lives until it expires; the
-- HUD panel's "Show" opens it again).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Respond: (accept: boolean) -> (),
	-- S130: the tournament invitation (Hidden = closed with ✕, not answered)
	Tourney: { Respond: (accept: boolean) -> (), Hidden: Fusion.Value<boolean> }?,
}

local WIDTH = 460

local function ArenaOffer(scope: Scope, props: Props): Instance
	local live = State.Value({ "arenaLive" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local acc = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc >= 0.1 then
				acc = 0
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)
	local offer = scope:Computed(function(use): any
		local value = use(live)
		local o = if type(value) == "table" then value.offer else nil
		return if type(o) == "table" then o else nil
	end)
	local accepted = scope:Computed(function(use): boolean
		local o = use(offer)
		return o ~= nil and o.accepted == true
	end)
	-- S130: the tournament invitation, shown while no match offer waits and the card is not hidden
	local tourneyState = State.Value({ "tourney" })
	local clockNow = scope:Value(Clock.now())
	local invite = scope:Computed(function(use): any
		if use(offer) ~= nil or not props.Tourney or use(props.Tourney.Hidden) then
			return nil
		end
		local t = use(tourneyState)
		local inv = if type(t) == "table" then t.invite else nil
		return if type(inv) == "table" then inv else nil
	end)
	local isInvite = scope:Computed(function(use): boolean
		return use(invite) ~= nil
	end)
	local inviteLeft = scope:Computed(function(use): number
		local inv = use(invite)
		return if inv then math.max(0, (tonumber(inv.expiresAt) or 0) - use(clockNow)) else 0
	end)
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			if Fusion.peek(isInvite) then
				clockNow:set(Clock.now())
			end
		end)
	)
	local function answer(accept: boolean)
		if Fusion.peek(isInvite) and props.Tourney then
			props.Tourney.Respond(accept)
		else
			props.Respond(accept)
		end
	end
	-- S127: the server marks an offer whose player is in a fight (Accept waits; no answer then costs nothing)
	local combat = scope:Computed(function(use): boolean
		local o = use(offer)
		return o ~= nil and o.combat == true
	end)

	return scope:New("Frame")({
		Name = "ArenaOffer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = scope:Computed(function(use): UDim2
			-- PC: over the skill bar; phone: higher, over the attack and skill buttons
			return UDim2.new(0.5, 0, 1, if use(Device.Touch) then -300 else -170)
		end),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Paper.Surface,
		Visible = scope:Computed(function(use): boolean
			return use(offer) ~= nil or use(isInvite)
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Paper.Border, Thickness = 1.5 }),
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(WIDTH, math.huge) }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				-- S130: hide the invitation card (not a refusal), in the title's corner
				[Children] = Button(scope, {
					Name = "Hide",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 6, 0.5, 0),
					Size = UDim2.fromOffset(Theme.Size.MinTouch, Theme.Size.MinTouch),
					Variant = "ghost",
					Text = "✕",
					Visible = isInvite,
					OnClick = function()
						if props.Tourney then
							props.Tourney.Hidden:set(true)
						end
					end,
				}),
				Text = scope:Computed(function(use): string
					if use(isInvite) then
						return Text.get(use, "tourney.title")
					end
					local o = use(offer)
					return Text.get(use, if o and o.mode == "3v3" then "arena.match.found3" else "arena.offer.title")
				end),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Paper.Heading,
			}),
			-- S127: where the match is played (another server of all worlds, or this one)
			scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local inv = use(invite)
					if inv then
						return Text.get(use, "tourney.invite", { range = inv.range, s = math.ceil(use(inviteLeft)) })
					end
					local o = use(offer)
					return Text.get(use, if o and o.scope == "global" then "arena.scope.global" else "arena.net.local")
				end),
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Text,
			}),
			scope:New("TextLabel")({
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextWrapped = true,
				Visible = scope:Computed(function(use): boolean
					return use(offer) ~= nil
				end),
				Text = scope:Computed(function(use): string
					local o = use(offer)
					if not o or type(o.opp) ~= "table" then
						return ""
					end
					-- S128: a team match lists both teams
					if type(o.mine) == "table" and type(o.them) == "table" then
						local team = Text.get(use, "arena.offer.team", { names = table.concat(o.mine, ", ") })
						local them = Text.get(use, "arena.offer.them", { names = table.concat(o.them, ", ") })
						return team .. "\n" .. them
					end
					local opp = o.opp
					return Text.get(use, "arena.offer.opp", {
						name = opp.name,
						class = Text.get(use, `class.{opp.class}.name`),
						level = opp.level,
						rating = opp.rating,
						tier = Text.get(use, `arena.tier.{ArenaRules.tierOf(tonumber(opp.rating) or 0)}`),
					})
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Text,
			}),
			-- the time left to answer
			scope:New("Frame")({
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 6),
				BackgroundColor3 = Theme.Paper.Sunken,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					scope:New("Frame")({
						BackgroundColor3 = Theme.Brass.Frame,
						Size = scope:Computed(function(use): UDim2
							if use(isInvite) then
								return UDim2.fromScale(
									math.clamp(use(inviteLeft) / Arena.TOURNEY.window.invite, 0, 1),
									1
								)
							end
							local o = use(offer)
							if not o then
								return UDim2.fromScale(0, 1)
							end
							local left = (tonumber(o.expiresAt) or 0) - use(now)
							return UDim2.fromScale(math.clamp(left / Arena.QUEUE.acceptSeconds, 0, 1), 1)
						end),
						[Children] = { scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }) },
					}),
				},
			}),
			scope:New("TextLabel")({
				LayoutOrder = 5,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextWrapped = true,
				Visible = scope:Computed(function(use): boolean
					local o = use(offer)
					return o ~= nil and o.unrated == true
				end),
				Text = scope:Computed(function(use): string
					local o = use(offer)
					return Text.get(use, "arena.offer.unrated", { n = if o then tonumber(o.vs) or 0 else 0 })
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Warning,
			}),
			scope:New("TextLabel")({
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Visible = accepted,
				Text = Text.T(scope, "arena.offer.waiting"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Success,
			}),
			scope:New("Frame")({
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(accepted)
				end),
				[Children] = {
					Button(scope, {
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.new(0.5, -6, 1, 0),
						Variant = "primary",
						Disabled = combat,
						Text = scope:Computed(function(use): string
							return Text.get(use, if use(isInvite) then "tourney.accept" else "arena.offer.accept")
						end),
						OnClick = function()
							answer(true)
						end,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0.5, -6, 1, 0),
						Variant = "danger",
						Text = scope:Computed(function(use): string
							return Text.get(use, if use(isInvite) then "tourney.decline" else "arena.offer.decline")
						end),
						OnClick = function()
							answer(false)
						end,
					}),
				},
			}),
			scope:New("TextLabel")({
				LayoutOrder = 8,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(accepted) and not use(isInvite)
				end),
				-- S127: in a fight "finish it first"; a fallback offer costs nothing to decline
				Text = scope:Computed(function(use): string
					local o = use(offer)
					if use(combat) then
						return Text.get(use, "arena.net.combatBlock")
					elseif o and o.fallback == true then
						return Text.get(use, "arena.net.localDecline")
					end
					return Text.get(use, "arena.offer.penaltyHint", { time = Time.format(Arena.QUEUE.declinePenalty) })
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
			}),
		},
	})
end

return ArenaOffer
