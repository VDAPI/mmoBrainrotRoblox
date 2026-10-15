--!strict
-- The match offer card (S126, DESIGN-17 §6): shown while `arenaLive.offer` exists. The opponent (name, class, level,
-- rating, tier sign), a bar of the time left to answer, Accept / Decline (44 px and more, at the bottom centre; on a
-- phone above the combat buttons, clear of the joystick), the warning of a match that will not change the rating and
-- the cost of declining. After accepting: "Waiting for the opponent…". S127 extends this card (it does not make
-- another one).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Button = require(script.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = { Respond: (accept: boolean) -> () }

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

	return scope:New("Frame")({
		Name = "ArenaOffer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = scope:Computed(function(use): UDim2
			-- PC: over the skill bar; phone: higher, over the attack and skill buttons
			return UDim2.new(0.5, 0, 1, if use(Device.Touch) then -300 else -170)
		end),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = scope:Computed(function(use): boolean
			return use(offer) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 1.5 }),
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
				Text = Text.T(scope, "arena.offer.title"),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.GoldBright,
			}),
			scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextWrapped = true,
				Text = scope:Computed(function(use): string
					local o = use(offer)
					if not o or type(o.opp) ~= "table" then
						return ""
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
				TextColor3 = Theme.Colors.Text,
			}),
			-- the time left to answer
			scope:New("Frame")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 6),
				BackgroundColor3 = Theme.Colors.PanelRaised,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					scope:New("Frame")({
						BackgroundColor3 = Theme.Colors.Gold,
						Size = scope:Computed(function(use): UDim2
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
				LayoutOrder = 4,
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
				TextColor3 = Theme.Colors.Warning,
			}),
			scope:New("TextLabel")({
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Visible = accepted,
				Text = Text.T(scope, "arena.offer.waiting"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Success,
			}),
			scope:New("Frame")({
				LayoutOrder = 6,
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
						Text = Text.T(scope, "arena.offer.accept"),
						OnClick = function()
							props.Respond(true)
						end,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0.5, -6, 1, 0),
						Variant = "danger",
						Text = Text.T(scope, "arena.offer.decline"),
						OnClick = function()
							props.Respond(false)
						end,
					}),
				},
			}),
			scope:New("TextLabel")({
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(accepted)
				end),
				Text = Text.T(scope, "arena.offer.penaltyHint", { time = Time.format(Arena.QUEUE.declinePenalty) }),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.TextMuted,
			}),
		},
	})
end

return ArenaOffer
