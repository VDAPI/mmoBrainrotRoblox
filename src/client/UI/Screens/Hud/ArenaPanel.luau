--!strict
-- The arena on the HUD (S126, DESIGN-17 §6), from `arenaLive`:
--   * in the queue (no match): a small pill above the Elite II timers (bottom right) "1v1 queue · 0:42 · 3 waiting"
--     with ✕ to leave (44 px on a phone);
--   * in a match: a panel at the top centre with the names of the sides and the round score, "Round 2 / 3", the time
--     of the round (server clock), the match potions left and the phase. The countdown and the round results come as
--     BossAnnounce (the panel does not repeat them).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = { Leave: () -> () }

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
					return Text.get(use, "arena.panel.queue", {
						mode = q.mode,
						time = Time.format(t - (tonumber(q.since) or t)),
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
		},
	})

	return scope:New("Frame")({
		Name = "ArenaHud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = { pill, panel },
	})
end

return ArenaPanel
