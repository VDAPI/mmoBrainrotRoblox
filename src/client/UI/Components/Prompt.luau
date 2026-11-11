--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, nothing folds"; UI plan package B): every invitation
-- in one style: an icon, one line (at most 60), ✓ on the right, ✕, a bar of the time left, every target at least
-- MinTouch tall. It serves the party invitation (PartyController), the duel, trade, guild and friend invitations
-- (SocialController), the arena's match offer and the tournament invitation (Screens/ArenaOffer) and the dungeon's
-- ready check (Screens/ReadyCheck: the members under 'Więcej ▸'). Prompt.push puts one into UI/Notify's queue: on PC
-- and a tablet under the toasts in the band under the target, on a phone the pane of its M zone; it stays until it is
-- answered or its time runs out (a higher prompt takes its place for a while, Logic/NoticeQueue).
-- Review 2026-11-10: the line is Small (Caption is for capitals only; UI-ZASADY §8) and the PC prompt as wide as a
-- toast, so a line with 'Więcej ▸' keeps two lines; a phone's prompt stays one HUD line: a tap on its line opens the
-- whole line, what 'Więcej' holds and ✓ ✕ in a sheet (UI/Notify.details). Opening under the line, it grew past M
-- onto the mail button and the skill arc.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NoticeQueue = require(ReplicatedStorage.Shared.Logic.NoticeQueue)
local Notify = require(script.Parent.Parent.Notify)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TopBand = require(ReplicatedStorage.Shared.Logic.TopBand)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

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
	more: ((s: Scope, phone: boolean) -> Instance)?, -- 'Więcej ▸': what opens under the line (a phone: in the sheet)
	moreHeight: number?,
	penalty: boolean?, -- its silence costs something (the arena's offer): first among the prompts (Logic/NoticeQueue)
	gone: (() -> ())?,
}

-- The row's height (the PC band's prompt, a phone's HUD line) and the countdown bar's.
Prompt.HEIGHT = TopBand.PROMPT.h
Prompt.PHONE_HEIGHT = Theme.Size.HudLine
local BAR = 4
local MORE_W = 112 -- 'Więcej ▸' at Small
local OPEN_MARK = 16 -- the ▸ at the end of a phone's line

-- The seconds left to answer, live (nil `ends`: 0).
local function countdown(s: Scope, ends: number?): Fusion.Computed<number>
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
	return s:Computed(function(use): number
		return if ends then math.max(0, ends - use(now)) else 0
	end)
end

-- ✓ and ✕ (✓ greyed while it cannot be accepted, both gone once answered).
local function answerButtons(
	s: Scope,
	spec: Spec,
	answered: Fusion.Computed<boolean>,
	accept: () -> (),
	decline: () -> ()
): { Instance }
	local touch = Theme.Size.MinTouch
	return {
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
			OnClick = accept,
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
			OnClick = decline,
		}),
	}
end

-- A phone's sheet of the prompt (UI/Notify.details): the whole line, what 'Więcej' holds and ✓ ✕.
local function sheetOf(
	spec: Spec,
	ends: number?,
	answer: (run: (() -> ())?) -> ()
): (Scope, () -> (), boolean) -> Instance
	return function(s: Scope, close: () -> (), full: boolean): Instance
		local left = countdown(s, ends)
		local answered = s:Computed(function(use): boolean
			return spec.answered ~= nil and spec.answered(use)
		end)
		local parts: { Instance } = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			s:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Normal }),
			s:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Padding.Medium),
				PaddingBottom = UDim.new(0, Theme.Padding.Medium),
				PaddingLeft = UDim.new(0, Theme.Padding.Medium),
				PaddingRight = UDim.new(0, Theme.Padding.Medium),
			}),
			s:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			s:New("TextLabel")({
				Name = "Line",
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = s:Computed(function(use): string
					return `{spec.icon}  {spec.line(use, math.ceil(use(left)))}`
				end),
				RichText = true,
				TextWrapped = true,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Iron.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}
		local more = spec.more
		if more then
			table.insert(
				parts,
				s:New("Frame")({
					Name = "Details",
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, spec.moreHeight or 0),
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					[Children] = more(s, true),
				})
			)
		end
		table.insert(
			parts,
			s:New("Frame")({
				Name = "Answers",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Padding.Small),
					}),
					answerButtons(s, spec, answered, function()
						close()
						answer(spec.accept)
					end, function()
						close()
						answer(spec.decline)
					end) :: any,
				},
			})
		)
		return s:New("Frame")({
			Name = "PromptSheet",
			AnchorPoint = if full then Vector2.zero else Vector2.new(0.5, 0.5),
			Position = if full then UDim2.new() else UDim2.fromScale(0.5, 0.5),
			Size = if full then UDim2.fromScale(1, 0) else UDim2.fromOffset(TopBand.PROMPT.w, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Iron.Surface,
			Active = true,
			[Children] = parts,
		})
	end
end

local function view(spec: Spec, ends: number?, open: Fusion.Value<boolean>): (Scope, Notify.Live) -> Instance
	return function(s: Scope, live: Notify.Live): Instance
		local phone = live.phone
		local touch = Theme.Size.MinTouch
		local left = countdown(s, ends)
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
		-- a phone's sheet goes with the prompt
		local closeSheet: (() -> ())? = nil
		table.insert(s, function()
			if closeSheet then
				closeSheet()
			end
		end)
		local more = if phone then nil else spec.more
		local rowHeight = if phone then Prompt.PHONE_HEIGHT else Prompt.HEIGHT
		local moreWidth = if more then MORE_W else 0
		local buttons = 2 * touch + 8
		local lineText = s:Computed(function(use): string
			return spec.line(use, math.ceil(use(left)))
		end)
		local lineLeft = if phone then 34 else 46
		local lineSize = UDim2.new(1, -(lineLeft + moreWidth + buttons + 8), 0, rowHeight - BAR)
		local function lineLabel(size: UDim2): Instance
			return s:New("TextLabel")({
				Name = "Line",
				Size = size,
				BackgroundTransparency = 1,
				Text = lineText,
				RichText = true,
				TextWrapped = true,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		end
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
			if phone
				then s:New("TextButton")({
					Name = "Open",
					Position = UDim2.fromOffset(lineLeft, 0),
					Size = lineSize,
					BackgroundTransparency = 1,
					AutoButtonColor = false,
					Text = "",
					[OnEvent("Activated")] = function()
						closeSheet = Notify.details(sheetOf(spec, ends, answer))
					end,
					[Children] = {
						lineLabel(UDim2.new(1, -OPEN_MARK, 1, 0)),
						s:New("TextLabel")({
							Name = "Mark",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							Size = UDim2.new(0, OPEN_MARK, 1, 0),
							BackgroundTransparency = 1,
							Text = "▸",
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = Theme.Brass.Bright,
						}),
					},
				})
				else s:New("Frame")({
					Name = "Text",
					Position = UDim2.fromOffset(lineLeft, 0),
					Size = lineSize,
					BackgroundTransparency = 1,
					[Children] = lineLabel(UDim2.fromScale(1, 1)),
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
							TextSize = Theme.TextSize.Small,
							Text = s:Computed(function(use): string
								return Text.get(use, if use(open) then "ui.details.less" else "ui.details.more")
							end),
							OnClick = function()
								open:set(not Fusion.peek(open))
								live.relayout()
							end,
						})
						else nil) :: any,
					answerButtons(s, spec, answered, function()
						answer(spec.accept)
					end, function()
						answer(spec.decline)
					end) :: any,
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
			if phone then
				return Prompt.PHONE_HEIGHT -- 'Więcej' opens in the sheet
			end
			return Prompt.HEIGHT + (if Fusion.peek(open) then spec.moreHeight or 0 else 0)
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
