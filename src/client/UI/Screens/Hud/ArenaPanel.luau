--!strict
-- The arena on the HUD (S126, DESIGN-17 §6), from `arenaLive`:
--   * in the queue (no match): a small pill above the Elite II timers (bottom right) "1v1 queue · 0:42 · 3 waiting"
--     with ✕ to leave (44 px on a phone);
--   * in a match: a panel at the top centre with the names of the sides and the round score, "Round 2 / 3", the time
--     of the round (server clock), the match potions left and the phase. The countdown and the round results come as
--     BossAnnounce (the panel does not repeat them).
-- S127: on an arena server after the result "Returning in 8 s" with "Return now" (`arenaLive.returnAt`, ArenaReturnNow);
-- while a teleport between servers runs (`arenaLive.transfer`) a full-screen veil "Travelling to the arena…" /
-- "Returning to the world…". The global queue's pill shows the rating window instead of the number waiting.
-- S128: after the match a result line: the team result of a 3v3 match ("Team victory" / "Team defeat" / "Draw") and
-- the Arena Tokens of the match with their reason (`arenaLive.match.tokens` / `tokensReason`). The 3v3 team panel is
-- UI/Screens/Hud/ArenaTeams.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = { Leave: () -> (), ReturnNow: () -> () }

local PILL_WIDTH = 280
local PANEL_WIDTH = 420

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

	local pill = scope:New("Frame")({
		Name = "ArenaQueue",
		AnchorPoint = Vector2.new(1, 1),
		Position = scope:Computed(function(use): UDim2
			-- over the Elite II timers (Hud/Elite2Timer: -290 on a phone, -130 on a PC)
			return UDim2.new(1, -Theme.Padding.Large, 1, if use(Device.Touch) then -340 else -180)
		end),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(PILL_WIDTH, if use(Device.Touch) then Theme.Size.MinTouch else 36)
		end),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.2,
		Visible = scope:Computed(function(use): boolean
			return use(queue) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 1 }),
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
					if q.waiting == nil and tonumber(q.window) then
						-- S127: the global queue: the rating window it searches now
						return `{Text.get(use, "arena.inQueue", { mode = q.mode, time = time })} · ±{q.window}`
					end
					return Text.get(use, "arena.panel.queue", {
						mode = q.mode,
						time = time,
						n = tonumber(q.waiting) or 0,
					})
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Parchment,
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
				TextColor3 = Theme.Colors.TextMuted,
				[OnEvent("Activated")] = function()
					props.Leave()
				end,
			}),
		},
	})

	local panel = scope:New("Frame")({
		Name = "ArenaMatch",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = scope:Computed(function(use): boolean
			return use(match) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 1 }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 2),
			}),
			-- "Aria  1 : 0  Borg" (own side first in gold)
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 30),
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
							text = `<font color="#{Theme.Colors.GoldBright:ToHex()}">{text}</font>`
						end
						parts[side] = text
					end
					local a, b = parts[1] or "", parts[2] or ""
					return `{a}   <b>{m.score[1] or 0} : {m.score[2] or 0}</b>   {b}`
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Text,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 22),
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
				TextColor3 = Theme.Colors.Parchment,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			-- S128: the result and the tokens of the match
			scope:New("TextLabel")({
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextWrapped = true,
				Visible = scope:Computed(function(use): boolean
					local m = use(match)
					return m ~= nil and m.phase == "done"
				end),
				Text = scope:Computed(function(use): string
					local m = use(match)
					if not m or m.phase ~= "done" then
						return ""
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
						table.insert(bits, Text.get(use, `arena.result3.{key}`))
					end
					if type(m.tokens) == "number" then
						table.insert(bits, Text.get(use, "arena.tokens.match", { n = m.tokens }))
					end
					if type(m.tokensReason) == "string" then
						table.insert(bits, Text.get(use, m.tokensReason))
					end
					return table.concat(bits, "  ·  ")
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.GoldBright,
			}),
		},
	})

	-- S127: the way back from an arena server
	local returnAt = scope:Computed(function(use): number?
		local value = use(live)
		return if type(value) == "table" then tonumber(value.returnAt) else nil
	end)
	local back = scope:New("Frame")({
		Name = "ArenaReturn",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = scope:Computed(function(use): boolean
			return use(returnAt) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 1 }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 6),
			}),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local at = use(returnAt)
					local left = if at then math.max(0, math.ceil(at - use(now))) else 0
					return Text.get(use, "arena.net.returnIn", { s = left })
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Parchment,
			}),
			Button(scope, {
				Surface = "iron", -- S135: on a dark HUD / overlay surface
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
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
		BackgroundColor3 = Theme.Colors.Background,
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
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.Gold,
				TextWrapped = true,
			}),
		},
	})

	return scope:New("Frame")({
		Name = "ArenaHud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = { pill, panel, back, veil },
	})
end

return ArenaPanel
