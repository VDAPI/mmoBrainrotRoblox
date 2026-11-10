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
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): both are prompts
-- (Components/Prompt in UI/Notify's queue, the band under the target): the offer's one line ("Opponent found!", the
-- 3v3 one, then "Waiting for the opponent…") with ✓ (greyed in a fight) and ✕ (declines) and the bar; where the match
-- is played, the opponent or the teams, the unrated warning and the cost of declining wait under 'Więcej ▸'. The
-- tournament's line with ✓ and ✕ (hides it, as before); its "Decline" waits under 'Więcej ▸'.
-- Review 2026-11-10: the offer goes before the other prompts (`penalty`, Logic/NoticeQueue): a party invitation
-- answered in silence held the place for its 30 s while the offer's 15 s ran out, and a silent offer costs 5 min out
-- of the queue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Notify = require(script.Parent.Parent.Notify)
local Prompt = require(script.Parent.Parent.Components.Prompt)
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

local ArenaOffer = {}

local OFFER_MORE = 132 -- the height of the offer's 'Więcej ▸'
local TOURNEY_MORE = 56

local live = State.Value({ "arenaLive" })
local tourneyState = State.Value({ "tourney" })

-- The match offer now (nil: none).
local function offerOf(use: Fusion.Use): any
	local value = use(live)
	local o = if type(value) == "table" then value.offer else nil
	return if type(o) == "table" then o else nil
end

local function line(s: Scope, order: number, text: Fusion.UsedAs<string>, color: Color3, phone: boolean): Instance
	return s:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextWrapped = true,
		FontFace = Theme.Fonts.Body,
		TextSize = if phone then Theme.TextSize.Caption else Theme.TextSize.Small,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- 'Więcej ▸' of the offer: where it is played, the opponent or both teams, the unrated warning, the cost of declining.
local function offerDetails(s: Scope, phone: boolean): Instance
	return s:New("Frame")({
		Name = "Offer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			s:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.Padding.Medium),
				PaddingRight = UDim.new(0, Theme.Padding.Small),
			}),
			s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
			-- S127: where the match is played (another server of all worlds, or this one)
			line(
				s,
				1,
				s:Computed(function(use): string
					local o = offerOf(use)
					return Text.get(use, if o and o.scope == "global" then "arena.scope.global" else "arena.net.local")
				end),
				Theme.Iron.TextMuted,
				phone
			),
			line(
				s,
				2,
				s:Computed(function(use): string
					local o = offerOf(use)
					if not o or type(o.opp) ~= "table" then
						return ""
					end
					-- S128: a team match lists both teams
					if type(o.mine) == "table" and type(o.them) == "table" then
						local team = Text.get(use, "arena.offer.team", { names = table.concat(o.mine, ", ") })
						local them = Text.get(use, "arena.offer.them", { names = table.concat(o.them, ", ") })
						return team .. "\n" .. them
					end
					-- UI plan package B: the opponent, then the rating on a line of its own (a prompt line is at most 60)
					local opp = o.opp
					local who = Text.get(use, "arena.offer.opp", {
						name = opp.name,
						class = Text.get(use, `class.{opp.class}.name`),
						level = opp.level,
					})
					local rating = Text.get(use, "arena.offer.oppRating", {
						rating = opp.rating,
						tier = Text.get(use, `arena.tier.{ArenaRules.tierOf(tonumber(opp.rating) or 0)}`),
					})
					return who .. "\n" .. rating
				end),
				Theme.Iron.Text,
				phone
			),
			line(
				s,
				3,
				s:Computed(function(use): string
					local o = offerOf(use)
					if not o or o.unrated ~= true then
						return ""
					end
					return Text.get(use, "arena.offer.unrated", { n = tonumber(o.vs) or 0 })
				end),
				Theme.Iron.Warning,
				phone
			),
			-- S127: in a fight "finish it first"; a fallback offer costs nothing to decline
			line(
				s,
				4,
				s:Computed(function(use): string
					local o = offerOf(use)
					if o and o.combat == true then
						return Text.get(use, "arena.net.combatBlock")
					elseif o and o.fallback == true then
						return Text.get(use, "arena.net.localDecline")
					end
					return Text.get(use, "arena.offer.penaltyHint", { time = Time.format(Arena.QUEUE.declinePenalty) })
				end),
				Theme.Iron.TextMuted,
				phone
			),
		},
	})
end

-- Shows the offer and the tournament invitation as prompts while they exist (ArenaController calls it once).
function ArenaOffer.watch(scope: Scope, props: Props)
	local offerHandle: Notify.Handle? = nil
	local offerId: any = nil
	local inviteHandle: Notify.Handle? = nil
	local inviteAt: number? = nil

	local function closeOffer()
		if offerHandle then
			offerHandle.close()
			offerHandle = nil
		end
	end
	local function closeInvite()
		if inviteHandle then
			inviteHandle.close()
			inviteHandle = nil
		end
	end

	local function syncOffer()
		local o = offerOf(Fusion.peek)
		local id = if o then o.id else nil
		if id == nil then
			closeOffer()
			offerId = nil
			return
		end
		if id == offerId then
			return -- the same offer: the prompt follows its state
		end
		closeOffer()
		offerId = id
		local left = (tonumber(o.expiresAt) or 0) - Workspace:GetServerTimeNow()
		offerHandle = Prompt.push({
			class = "arenaOffer",
			icon = "⚔",
			seconds = math.max(1, left),
			total = Arena.QUEUE.acceptSeconds,
			keep = true, -- accepted: it waits for the opponent; the offer's end closes it
			penalty = true, -- no answer costs Arena.QUEUE.declinePenalty out of the queue (ArenaService)
			line = function(use: Fusion.Use, _left: number): string
				local now = offerOf(use)
				if now and now.accepted == true then
					return Text.get(use, "arena.offer.waiting")
				end
				return Text.get(use, if now and now.mode == "3v3" then "arena.match.found3" else "arena.offer.title")
			end,
			accept = function()
				props.Respond(true)
			end,
			decline = function()
				props.Respond(false)
				closeOffer()
			end,
			-- S127: the server marks an offer whose player is in a fight (Accept waits; no answer then costs nothing)
			canAccept = function(use: Fusion.Use): boolean
				local now = offerOf(use)
				return not (now and now.combat == true)
			end,
			answered = function(use: Fusion.Use): boolean
				local now = offerOf(use)
				return now ~= nil and now.accepted == true
			end,
			more = offerDetails,
			moreHeight = OFFER_MORE,
		})
	end

	-- S130: the tournament invitation, while no match offer waits and it is not hidden
	local function syncInvite()
		local tourney = props.Tourney
		local t = Fusion.peek(tourneyState)
		local invite = if type(t) == "table" and type(t.invite) == "table" then t.invite else nil
		local at = if invite then tonumber(invite.expiresAt) else nil
		if not tourney or not at or Fusion.peek(tourney.Hidden) or offerOf(Fusion.peek) ~= nil then
			closeInvite()
			if not at then
				inviteAt = nil
			end
			return
		end
		if inviteHandle and inviteHandle.alive() and inviteAt == at then
			return
		end
		closeInvite()
		inviteAt = at
		local range = invite.range
		inviteHandle = Prompt.push({
			class = "arenaOffer",
			icon = "♛",
			seconds = math.max(1, at - Clock.now()),
			total = Arena.TOURNEY.window.invite,
			line = function(use: Fusion.Use, left: number): string
				return Text.get(use, "tourney.invite", { range = range, s = left })
			end,
			accept = function()
				tourney.Respond(true)
			end,
			-- ✕ only hides it (not a refusal): the HUD panel's "Show" brings it back
			decline = function()
				tourney.Hidden:set(true)
			end,
			more = function(s: Scope, _phone: boolean): Instance
				return s:New("Frame")({
					Name = "Tourney",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					[Children] = Button(s, {
						Surface = "iron",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -Theme.Padding.Small, 0.5, 0),
						Size = UDim2.fromOffset(150, Theme.Size.MinTouch),
						Variant = "danger",
						Text = Text.T(s, "tourney.decline"),
						TextSize = Theme.TextSize.Small,
						OnClick = function()
							closeInvite()
							tourney.Respond(false)
						end,
					}),
				})
			end,
			moreHeight = TOURNEY_MORE,
		})
	end

	scope:Observer(live):onBind(function()
		syncOffer()
		syncInvite()
	end)
	scope:Observer(tourneyState):onBind(syncInvite)
	if props.Tourney then
		scope:Observer(props.Tourney.Hidden):onChange(syncInvite)
	end
	table.insert(scope, function()
		closeOffer()
		closeInvite()
	end)
end

return ArenaOffer
