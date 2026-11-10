--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, nothing folds"; UI plan package B): every invitation
-- in one style: an icon, one line (at most 60), ✓ on the right, ✕, a bar of the time left, every target at least
-- MinTouch tall. It serves the party invitation (PartyController), the duel, trade, guild and friend invitations
-- (SocialController), the arena's match offer and the tournament invitation (Screens/ArenaOffer) and the dungeon's
-- ready check (Screens/ReadyCheck: the members under 'Więcej ▸'). Prompt.push puts one into UI/Notify's queue: on PC
-- and a tablet under the toasts in the band under the target, on a phone the pane of its M zone; it stays until it is
-- answered or its time runs out (a higher prompt takes its place for a while, Logic/NoticeQueue).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NoticeQueue = require(ReplicatedStorage.Shared.Logic.NoticeQueue)
local Notify = require(script.Parent.Parent.Notify)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TopBand = require(ReplicatedStorage.Shared.Logic.TopBand)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Prompt = {}

export type Spec = {
	class: NoticeQueue.Class, -- partyInvite | invite | arenaOffer | readyCheck
	icon: string, -- a glyph before the line
	-- the one line (at most 60), live: `left` is the whole seconds left to answer
	line: (use: Fusion.Use, left: number) -> string,
	seconds: number?, -- the time to answer (the bar); nil: until closed
	total: number?, -- the bar's full length when the time began before the push (the arena's offer), else `seconds`
	accept: (() -> ())?, -- ✓
	decline: (() -> ())?, -- ✕
	keep: boolean?, -- an answer leaves it on the screen (the caller's state closes it: the ready check, the offer)
	canAccept: ((use: Fusion.Use) -> boolean)?, -- ✓ greyed while false (a match offer during a fight)
	answered: ((use: Fusion.Use) -> boolean)?, -- ✓ and ✕ go (accepted, waiting for the others)
	more: ((s: Scope, phone: boolean) -> Instance)?, -- 'Więcej ▸': what opens under the line
	moreHeight: number?,
	penalty: boolean?, -- its silence costs something (the arena's offer): first among the prompts (Logic/NoticeQueue)
	gone: (() -> ())?,
}

-- The row's height (the PC band's prompt, a phone's HUD line) and the countdown bar's.
Prompt.HEIGHT = TopBand.PROMPT.h
Prompt.PHONE_HEIGHT = Theme.Size.HudLine
local BAR = 4
local MORE_W = 96

local function view(spec: Spec, ends: number?, open: Fusion.Value<boolean>): (Scope, Notify.Live) -> Instance
	return function(s: Scope, live: Notify.Live): Instance
		local phone = live.phone
		local touch = Theme.Size.MinTouch
		local now = s:Value(os.clock())
		local clock = 0
		table.insert(
			s,
			RunService.Heartbeat:Connect(function(dt: number)
				clock += dt
				if clock >= 0.1 then
					clock = 0
					now:set(os.clock())
				end
			end)
		)
		local left = s:Computed(function(use): number
			return if ends then math.max(0, ends - use(now)) else 0
		end)
		local answered = s:Computed(function(use): boolean
			return spec.answered ~= nil and spec.answered(use)
		end)
		local function answer(run: (() -> ())?)
			if run then
				run()
			end
			if not spec.keep then
				live.close()
			end
		end
		local more = spec.more
		local rowHeight = if phone then Prompt.PHONE_HEIGHT else Prompt.HEIGHT
		local moreWidth = if more then (if phone then touch else MORE_W) else 0
		local buttons = 2 * touch + 8
		local parts: { Instance } = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Brass.Line,
				Thickness = Theme.Stroke.Normal,
			}),
			s:New("TextLabel")({
				Name = "Icon",
				Size = UDim2.fromOffset(if phone then 32 else 44, rowHeight),
				BackgroundTransparency = 1,
				Text = spec.icon,
				FontFace = Theme.Fonts.Display,
				TextSize = if phone then Theme.TextSize.Body else Theme.TextSize.Large,
				TextColor3 = Theme.Brass.Bright,
			}),
			s:New("TextLabel")({
				Name = "Line",
				Position = UDim2.fromOffset(if phone then 34 else 46, 0),
				Size = UDim2.new(1, -((if phone then 34 else 46) + moreWidth + buttons + 8), 0, rowHeight - BAR),
				BackgroundTransparency = 1,
				Text = s:Computed(function(use): string
					return spec.line(use, math.ceil(use(left)))
				end),
				RichText = true,
				TextWrapped = true,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = if phone then Theme.TextSize.Caption else Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			s:New("Frame")({
				Name = "Answers",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, (rowHeight - BAR - touch) / 2),
				Size = UDim2.fromOffset(buttons + moreWidth, touch),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					(if more
						then Button(s, {
							Name = "More",
							Surface = "iron",
							LayoutOrder = 1,
							Size = UDim2.fromOffset(moreWidth, touch),
							Variant = "ghost",
							TextSize = Theme.TextSize.Caption,
							Text = s:Computed(function(use): string
								if phone then
									return if use(open) then "▾" else "▸"
								end
								return Text.get(use, if use(open) then "ui.details.less" else "ui.details.more")
							end),
							OnClick = function()
								open:set(not Fusion.peek(open))
								live.relayout()
							end,
						})
						else nil) :: any,
					Button(s, {
						Name = "Accept",
						Surface = "iron",
						LayoutOrder = 2,
						Size = UDim2.fromOffset(touch, touch),
						Variant = "primary",
						Text = "✓",
						Visible = s:Computed(function(use): boolean
							return spec.accept ~= nil and not use(answered)
						end),
						Disabled = s:Computed(function(use): boolean
							return spec.canAccept ~= nil and not spec.canAccept(use)
						end),
						OnClick = function()
							answer(spec.accept)
						end,
					}),
					Button(s, {
						Name = "Decline",
						Surface = "iron",
						LayoutOrder = 3,
						Size = UDim2.fromOffset(touch, touch),
						Variant = "secondary",
						Text = "✕",
						Visible = s:Computed(function(use): boolean
							return not use(answered)
						end),
						OnClick = function()
							answer(spec.decline)
						end,
					}),
				},
			}),
		}
		local seconds = spec.total or spec.seconds
		if ends and seconds and seconds > 0 then
			-- the time left: a thin bar along the bottom of the row
			table.insert(
				parts,
				s:New("Frame")({
					Name = "Time",
					Position = UDim2.fromOffset(4, rowHeight - BAR - 2),
					Size = s:Computed(function(use): UDim2
						return UDim2.new(math.clamp(use(left) / seconds, 0, 1), -8, 0, BAR)
					end),
					BackgroundColor3 = Theme.Brass.Frame,
					BorderSizePixel = 0,
				})
			)
		end
		if more then
			table.insert(
				parts,
				s:New("Frame")({
					Name = "Details",
					Position = UDim2.fromOffset(0, rowHeight),
					Size = UDim2.new(1, 0, 1, -rowHeight),
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Visible = open,
					[Children] = more(s, phone),
				})
			)
		end
		return s:New("Frame")({
			Name = "Prompt",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Iron.Surface,
			BackgroundTransparency = Theme.HudAlpha,
			Active = true,
			[Children] = parts,
		})
	end
end

-- Puts a prompt into UI/Notify's queue. Returns its handle (close it when the invitation is gone), nil if it dropped.
function Prompt.push(spec: Spec): Notify.Handle?
	local own = Fusion.scoped(Fusion)
	local open = own:Value(false)
	local ends = if spec.seconds then os.clock() + spec.seconds else nil
	local gone = spec.gone
	return Notify.push({
		class = spec.class,
		deadline = spec.seconds,
		penalty = spec.penalty,
		w = TopBand.PROMPT.w,
		height = function(phone: boolean): number
			local base = if phone then Prompt.PHONE_HEIGHT else Prompt.HEIGHT
			return base + (if Fusion.peek(open) then spec.moreHeight or 0 else 0)
		end,
		build = view(spec, ends, open),
		gone = function()
			Fusion.doCleanup(own)
			if gone then
				gone()
			end
		end,
	})
end

return Prompt
