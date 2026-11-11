--!strict
-- The arena on the HUD (S126, DESIGN-17 §6), from `arenaLive`:
--   * in the queue (no match): a small pill "1v1 queue · 0:42 · 3 waiting" with ✕ to leave (44 px on a phone); owner
--     2026-10-21: the first of the HUD column (UI/HudSlots), it stood over the PvP toggle and the skill arc;
--   * in a match: a panel at the top centre with the names of the sides and the round score, "Round 2 / 3", the time
--     of the round (server clock), the match potions left and the phase. The countdown and the round results come as
--     BossAnnounce (the panel does not repeat them).
-- S127: on an arena server after the result "Returning in 8 s" with "Return now" (`arenaLive.returnAt`, ArenaReturnNow);
-- while a teleport between servers runs (`arenaLive.transfer`) a full-screen veil "Travelling to the arena…" /
-- "Returning to the world…". The global queue's pill shows the rating window instead of the number waiting.
-- S128: after the match a result line: the team result of a 3v3 match ("Team victory" / "Team defeat" / "Draw") and
-- the Arena Tokens of the match with their reason (`arenaLive.match.tokens` / `tokensReason`). The 3v3 team panel is
-- UI/Screens/Hud/ArenaTeams.
-- Owner 2026-11-10 (UI plan package A, "things covering each other"): on PC and a tablet the match panel and the return
-- panel stand at the zone map's arena place (Logic/HudZones `arenaPanel`, 172..240 at 1080p: under the target frame
-- and its effects, over the message zone; they stood at 70 and 160, over the target frame); while the return panel
-- shows, the match panel steps aside and the return panel carries the match's result. On a phone they join the stack
-- as "arena" (Logic/PhoneHud) with a header line (Hud/PanelHeader: the score and the round's time), folded by default
-- (Section.state "hudArena", Data/Folds/Hud), and the column folds them to that line while it has no room.
-- Owner 2026-11-10 ("too much text"; UI plan package A, a HUD line at most 32 characters): the pill says
-- "⌛ 1 na 1 · 0:42" (the mode's name, final UI review 2026-11-10) and its tooltip the players waiting (or the global
-- queue's rating window); the 3v3 result line reads its three keys by name (the toast and the banner of the result are
-- the message band's).
-- Package A review (owner 2026-11-10, "things covering each other"): on PC and a tablet both panels take the arena
-- place's size (68 tall; the return panel grew to 140 and its button stood in the message zone under the band, where
-- the result's toast shows): after the match the result line stands in the round line's place, and the return panel is
-- one row of short lines beside its button. The tokens' reason (which the server toasts too) is the details of the
-- result's tooltip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local PanelHeader = require(script.Parent.PanelHeader)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local Section = require(script.Parent.Parent.Parent.Components.Section)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = { Leave: () -> (), ReturnNow: () -> () }

local PILL_WIDTH = HudStack.ARENA_PILL
-- the match panel's rows (on a phone under the header, Hud/PanelHeader); on PC and a tablet with its paddings (6 and
-- 8) and the gap (2) as tall as the zone's arena place (tests/hudzones.spec)
local SCORE = 30
local ROUND = 22
-- a phone's return panel in the stack: the result on two lines and "Returning in N s"
local RESULT = 36
local RETURN = 24
-- PC and a tablet: the return panel's lines (three at most: the 3v3 result, the tokens, the countdown) beside its
-- button, MinTouch tall
local LINE = 18
local BACK_BUTTON = 140
-- the team result of a 3v3 match
local RESULT3: { [string]: string } =
	{ win = "arena.result3.win", loss = "arena.result3.loss", draw = "arena.result3.draw" }

-- The queue's mode by its name ("1 na 1", as the arena window says it), never its id ("1v1"; final UI review
-- 2026-11-10, known item 2).
local function modeName(use: Fusion.Use, id: any): string
	return Text.get(use, `arena.mode.{id}`)
end

local function ArenaPanel(scope: Scope, props: Props): Instance
	local live = State.Value({ "arenaLive" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local acc = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc >= 0.5 then
				acc = 0
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)
	local match = scope:Computed(function(use): any
		local value = use(live)
		local m = if type(value) == "table" then value.match else nil
		return if type(m) == "table" then m else nil
	end)
	local queue = scope:Computed(function(use): any
		local value = use(live)
		local q = if type(value) == "table" then value.queue else nil
		return if type(q) == "table" and use(match) == nil then q else nil
	end)

	local pillHeight = scope:Computed(function(use): number
		return if use(Device.Touch) then Theme.Size.MinTouch else 36
	end)
	local queued = scope:Computed(function(use): boolean
		return use(queue) ~= nil
	end)
	-- package A review (owner 2026-11-10): on a phone a line of the stack, PhoneHud.PANEL_WIDTH wide, beside the
	-- stack's '+N' chip (at 280 it met the chip and the stack's edge, and its ✕ went out of reach behind '+N')
	local pillWidth = scope:Computed(function(use): number
		return if use(PhoneLayout.Compact) then PhoneHud.PANEL_WIDTH else PILL_WIDTH
	end)
	local slot = HudSlots.join(
		scope,
		"arena",
		scope:Computed(function(use): HudSlots.Box
			local h = use(pillHeight)
			return { shown = use(queued), w = use(pillWidth), h = h, line = h }
		end)
	)
	local pill = scope:New("Frame")({
		Name = "ArenaQueue",
		AnchorPoint = Vector2.zero,
		Position = HudSlots.position(scope, slot),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(use(pillWidth), use(pillHeight))
		end),
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		-- package A: not while it waits behind the column's '+N' chip
		Visible = HudSlots.visible(scope, slot, queued),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -(14 + 44), 1, 0),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local q = use(queue)
					if not q then
						return ""
					end
					local t = use(now)
					local time = Time.format(t - (tonumber(q.since) or t))
					return Text.get(use, "arena.panel.queue", { mode = modeName(use, q.mode), time = time })
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextButton")({
				Name = "Leave",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -2, 0.5, 0),
				Size = UDim2.fromOffset(Theme.Size.MinTouch, Theme.Size.MinTouch),
				BackgroundTransparency = 1,
				Text = "✕",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Iron.TextMuted,
				[OnEvent("Activated")] = function()
					props.Leave()
				end,
			}),
		},
	})

	Tooltip.attach(
		scope,
		pill :: GuiObject,
		scope:Computed(function(use): string
			local q = use(queue)
			if not q then
				return ""
			end
			if q.waiting == nil and tonumber(q.window) then
				-- S127: the global queue: the rating window it searches now
				return Text.get(use, "arena.panel.window", { mode = modeName(use, q.mode), n = tonumber(q.window) })
			end
			return Text.get(use, "arena.panel.waiting", { mode = modeName(use, q.mode), n = tonumber(q.waiting) or 0 })
		end)
	)

	-- S127: the way back from an arena server (its panel takes the match panel's place, with the match's result)
	local returnAt = scope:Computed(function(use): number?
		local value = use(live)
		return if type(value) == "table" then tonumber(value.returnAt) else nil
	end)
	local returning = scope:Computed(function(use): boolean
		return use(returnAt) ~= nil
	end)
	local compact = PhoneLayout.Compact
	local open = Section.state(scope, "hudArena")
	local forced = HudSlots.forced(scope, "arena")
	local header = PanelHeader.Height(scope)
	-- a phone's panels show their rows while open (the player's choice, and room in the stack)
	local rows = scope:Computed(function(use): boolean
		return not use(compact) or (use(open) and not use(forced))
	end)
	local function toggle()
		if Fusion.peek(forced) then
			HudSlots.bring("arena")
			Section.set("hudArena", true)
			return
		end
		Section.set("hudArena", not Fusion.peek(open))
	end
	-- S128: the result and the tokens of the match, the parts of the result line (package A review: the tokens' reason
	-- is no part of it, see `reasonText`)
	local resultParts = scope:Computed(function(use): { string }
		local m = use(match)
		if not m or m.phase ~= "done" then
			return {}
		end
		local bits = {}
		if m.mode == "3v3" and type(m.score) == "table" then
			local key: string
			local winner = tonumber(m.winner)
			if winner then
				-- the decided match (a forfeit win keeps the score 0:0)
				key = if winner == 0 then "draw" elseif winner == m.side then "win" else "loss"
			else
				local mine = tonumber(m.score[m.side]) or 0
				local other = 0
				for side, n in m.score do
					if side ~= m.side then
						other = math.max(other, tonumber(n) or 0)
					end
				end
				key = if mine > other then "win" elseif mine < other then "loss" else "draw"
			end
			table.insert(bits, Text.get(use, RESULT3[key]))
		end
		if type(m.tokens) == "number" then
			table.insert(bits, Text.get(use, "arena.tokens.match", { n = m.tokens }))
		end
		return bits
	end)
	local resultText = scope:Computed(function(use): string
		return table.concat(use(resultParts), "  ·  ")
	end)
	local hasResult = scope:Computed(function(use): boolean
		return use(resultText) ~= ""
	end)
	-- the reason of the tokens (a sentence up to 67 characters, which the server toasts with them): the details of the
	-- result's tooltip, whose text is the whole result line (a phone's panel wraps it, and a cut part reads there)
	local reasonText = scope:Computed(function(use): string?
		local m = use(match)
		if not m or m.phase ~= "done" or type(m.tokensReason) ~= "string" then
			return nil
		end
		return Text.get(use, m.tokensReason)
	end)
	local function resultTip(label: Instance)
		Tooltip.attach(scope, label :: GuiObject, resultText, reasonText)
	end
	-- the phone header: the score and the round's time
	local scoreLine = scope:Computed(function(use): string
		local m = use(match)
		if not m or type(m.score) ~= "table" then
			return "⚔"
		end
		return `⚔ {m.score[1] or 0} : {m.score[2] or 0}`
	end)
	local timeValue = scope:Computed(function(use): string
		local m = use(match)
		local endsAt = if m then tonumber(m.endsAt) else nil
		if m and m.phase == "fight" and endsAt then
			return Time.format(math.max(0, endsAt - use(now)))
		end
		local at = use(returnAt)
		return if at then `{math.max(0, math.ceil(at - use(now)))} s` else ""
	end)
	local matchShown = scope:Computed(function(use): boolean
		return use(match) ~= nil and not use(returning)
	end)
	-- the place: the zone map's arena place on PC and a tablet; a phone's stack ("arena")
	local zone = HudSlots.at(scope, "arenaPanel")
	local zoneSize = HudSlots.sizeOf(scope, "arenaPanel")
	-- package A review (owner 2026-11-10): a box hears the player's own fold only (`open`, not `rows`): the column
	-- folds a box to its line itself, and a box built from its fold fed the column back (a Fusion loop)
	local function phoneSlot(shown: Fusion.Computed<boolean>, extra: Fusion.Computed<number>)
		return HudSlots.join(
			scope,
			"arena",
			scope:Computed(function(use): HudSlots.Box
				local line = use(header)
				local h = if use(open) then line + use(extra) else line
				return { shown = use(compact) and use(shown), w = PhoneHud.PANEL_WIDTH, h = h, line = line }
			end)
		)
	end
	local matchSlot = phoneSlot(
		matchShown,
		scope:Computed(function(use): number
			return 6 + SCORE + 2 + ROUND + (if use(hasResult) then 2 + RESULT else 0) + 8
		end)
	)
	local returnSlot = phoneSlot(
		returning,
		scope:Computed(function(use): number
			return 8 + (if use(hasResult) then RESULT + 6 else 0) + RETURN + 6 + Theme.Size.ButtonHeight + 8
		end)
	)
	local function placeOf(phone: Fusion.Computed<HudStack.Rect?>): Fusion.Computed<UDim2>
		local last = HudSlots.position(scope, phone)
		return scope:Computed(function(use): UDim2
			return if use(compact) then use(last) else use(zone)
		end)
	end
	local function sizeOf(phone: Fusion.Computed<HudStack.Rect?>): Fusion.Computed<UDim2>
		return scope:Computed(function(use): UDim2
			if not use(compact) then
				return use(zoneSize)
			end
			local at = use(phone)
			return UDim2.fromOffset(PhoneHud.PANEL_WIDTH, if at then at.bottom - at.top else use(header))
		end)
	end
	local function shownOn(phone: Fusion.Computed<HudStack.Rect?>, shown: Fusion.Computed<boolean>)
		return scope:Computed(function(use): boolean
			if not use(shown) then
				return false
			end
			return not use(compact) or use(phone) ~= nil
		end)
	end
	local function phoneHeader(order: number): Instance
		return PanelHeader.new(scope, {
			LayoutOrder = order,
			Title = scoreLine,
			Value = timeValue,
			Open = rows,
			OnClick = toggle,
			Visible = compact,
		})
	end

	-- S128: the result and the tokens of the match. Package A review: on PC and a tablet one line in the round line's
	-- place (the panel keeps the place's 68 px), on a phone two lines under it
	local matchResult = scope:New("TextLabel")({
		LayoutOrder = 3,
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(1, 0, 0, if use(compact) then RESULT else ROUND)
		end),
		BackgroundTransparency = 1,
		TextWrapped = compact,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = scope:Computed(function(use): boolean
			return use(hasResult) and use(rows)
		end),
		Text = resultText,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Brass.Bright,
	})
	resultTip(matchResult)
	local panel = scope:New("Frame")({
		Name = "ArenaMatch",
		Position = placeOf(matchSlot),
		Size = sizeOf(matchSlot),
		ClipsDescendants = compact,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Visible = shownOn(matchSlot, matchShown),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingTop = PhoneLayout.Pick(scope, UDim.new(0, 0), UDim.new(0, 6)),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 2),
			}),
			phoneHeader(0),
			-- "Aria  1 : 0  Borg" (own side first in gold)
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Visible = rows,
				Size = UDim2.new(1, 0, 0, SCORE),
				BackgroundTransparency = 1,
				RichText = true,
				Text = scope:Computed(function(use): string
					local m = use(match)
					if not m or type(m.names) ~= "table" or type(m.score) ~= "table" then
						return ""
					end
					local parts = {}
					for side, names in m.names do
						local text = string.gsub(table.concat(names, ", "), "[<>&]", "")
						if side == m.side then
							text = `<font color="#{Theme.Brass.Bright:ToHex()}">{text}</font>`
						end
						parts[side] = text
					end
					local a, b = parts[1] or "", parts[2] or ""
					return `{a}   <b>{m.score[1] or 0} : {m.score[2] or 0}</b>   {b}`
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Iron.Text,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				LayoutOrder = 2,
				-- PC and a tablet: the result line takes its place after the match
				Visible = scope:Computed(function(use): boolean
					return use(rows) and (use(compact) or not use(hasResult))
				end),
				Size = UDim2.new(1, 0, 0, ROUND),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local m = use(match)
					if not m then
						return ""
					end
					local bits = {}
					if m.phase == "waiting" then
						table.insert(bits, Text.get(use, "arena.phase.waiting", { n = tonumber(m.queued) or 1 }))
					else
						if (tonumber(m.round) or 0) > 0 then
							table.insert(bits, Text.get(use, "arena.panel.round", { n = m.round, of = m.maxRounds }))
						end
						table.insert(bits, Text.get(use, `arena.phase.{m.phase}`))
						local endsAt = tonumber(m.endsAt)
						if m.phase == "fight" and endsAt then
							table.insert(bits, Time.format(endsAt - use(now)))
						end
					end
					table.insert(bits, Text.get(use, "arena.panel.potions", { n = tonumber(m.potionsLeft) or 0 }))
					return table.concat(bits, "  ·  ")
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			matchResult,
		},
	})

	local returnText = scope:Computed(function(use): string
		local at = use(returnAt)
		local left = if at then math.max(0, math.ceil(at - use(now))) else 0
		return Text.get(use, "arena.net.returnIn", { s = left })
	end)
	-- a phone's return panel: a list under its header line in the stack
	local stackResult = scope:New("TextLabel")({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, RESULT),
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = scope:Computed(function(use): boolean
			return use(hasResult) and use(rows)
		end),
		Text = resultText,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Brass.Bright,
	})
	resultTip(stackResult)
	local backStack = scope:New("Frame")({
		Name = "ArenaReturnStack",
		Position = placeOf(returnSlot),
		Size = sizeOf(returnSlot),
		ClipsDescendants = true,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Visible = scope:Computed(function(use): boolean
			return use(compact) and use(returning) and use(returnSlot) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 6),
			}),
			phoneHeader(-1),
			-- the match's result (the match panel steps aside for this one)
			stackResult,
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Visible = rows,
				Size = UDim2.new(1, 0, 0, RETURN),
				BackgroundTransparency = 1,
				Text = returnText,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Iron.Text,
			}),
			Button(scope, {
				Surface = "iron", -- S135: on a dark HUD / overlay surface
				LayoutOrder = 2,
				Visible = rows,
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
				Variant = "primary",
				Text = Text.T(scope, "arena.net.returnNow"),
				OnClick = props.ReturnNow,
			}),
		},
	})

	-- PC and a tablet: the return panel in the zone's arena place, one row: the result's parts and the countdown, each a
	-- short line of its own (at most three, 18 px), beside "Return now", MinTouch tall for a tablet's finger
	local function backLine(order: number, text: Fusion.Computed<string>, color: Color3): Instance
		return scope:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, LINE),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return use(text) ~= ""
			end),
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	local lines: { Instance } = {}
	for i = 1, 2 do
		local line = backLine(
			i,
			scope:Computed(function(use): string
				return use(resultParts)[i] or ""
			end),
			Theme.Brass.Bright
		)
		resultTip(line)
		table.insert(lines, line)
	end
	table.insert(lines, backLine(3, returnText, Theme.Iron.Text))
	local back = scope:New("Frame")({
		Name = "ArenaReturn",
		Position = zone,
		Size = zoneSize,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Visible = scope:Computed(function(use): boolean
			return use(returning) and not use(compact)
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			scope:New("Frame")({
				Name = "Lines",
				Size = UDim2.new(1, -(BACK_BUTTON + 8), 1, 0),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					lines :: any,
				},
			}),
			Button(scope, {
				Surface = "iron",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(BACK_BUTTON, Theme.Size.MinTouch),
				TextSize = Theme.TextSize.Small,
				Variant = "primary",
				Text = Text.T(scope, "arena.net.returnNow"),
				OnClick = props.ReturnNow,
			}),
		},
	})

	-- S127: the veil of a teleport between servers
	local transfer = scope:Computed(function(use): string?
		local value = use(live)
		local t = if type(value) == "table" then value.transfer else nil
		return if type(t) == "string" then t else nil
	end)
	local veil = scope:New("Frame")({
		Name = "ArenaTransfer",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Iron.Sunken,
		BackgroundTransparency = 0.1,
		Active = true,
		ZIndex = 50,
		Visible = scope:Computed(function(use): boolean
			return use(transfer) ~= nil
		end),
		[Children] = {
			scope:New("TextLabel")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -40, 0, 60),
				BackgroundTransparency = 1,
				ZIndex = 51,
				Text = scope:Computed(function(use): string
					return Text.get(
						use,
						if use(transfer) == "home" then "arena.net.returning" else "arena.net.teleporting"
					)
				end),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Iron.Heading,
				TextWrapped = true,
			}),
		},
	})

	return scope:New("Frame")({
		Name = "ArenaHud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = { pill, panel, back, backStack, veil },
	})
end

return ArenaPanel
