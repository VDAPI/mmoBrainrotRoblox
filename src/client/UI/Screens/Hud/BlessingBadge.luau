--!strict
-- Own active blessing next to the character name on the HUD portrait (S29, DESIGN §11): a rarity-coloured ✶ with
-- an "mm:ss" countdown, pulsing during the last minute; hover (PC) or long press (touch) shows the effects and
-- the time left. Built once: the clock only changes texts and the pulse, nothing is rebuilt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BlessingMark = require(ReplicatedStorage.Shared.Logic.BlessingMark)
local Blessings = require(ReplicatedStorage.Shared.Data.Blessings)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local State = require(script.Parent.Parent.Parent.State)
local Stats = require(ReplicatedStorage.Shared.Data.Stats)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local TICK = 0.25 -- countdown refresh (text only)
local PULSE_SPEED = 6 -- rad/s of the last-minute pulse

local BlessingBadge = {}

-- "+12 Strength" / "+3% Critical chance" (also used by the elixir icons).
function BlessingBadge.statLine(use: Fusion.Use, stat: string, value: number): string
	local def = Stats.get(stat)
	local suffix = if def and def.format == "pct" or stat == "atkSpeed" then "%" else ""
	return `+{value}{suffix} {Text.get(use, `stat.{stat}`)}`
end

-- Tooltip lines of a blessing: name (rarity) and its stats, sorted by stat id.
function BlessingBadge.describe(use: Fusion.Use, def: Blessings.BlessingDef): { string }
	local rarity = Rarities.get(def.rarity)
	local lines = { `{Text.get(use, def.nameKey)} ({if rarity then Text.get(use, rarity.nameKey) else ""})` }
	local keys = {}
	for stat in def.stats do
		table.insert(keys, stat)
	end
	table.sort(keys)
	for _, stat in keys do
		table.insert(lines, BlessingBadge.statLine(use, stat, def.stats[stat]))
	end
	return lines
end

function BlessingBadge.new(scope: Scope, layoutOrder: number): Instance
	local blessing = State.Value({ "character", "blessing" })
	local now = scope:Value(Clock.now())
	local pulse = scope:Value(0)

	local function mark(use: Fusion.Use): BlessingMark.Mark?
		local saved = use(blessing)
		if type(saved) ~= "table" then
			return nil
		end
		return BlessingMark.read(saved.id, saved.expiresAt, use(now))
	end
	-- Primitive Computeds so the clock only touches what really changes.
	local activeId = scope:Computed(function(use): string?
		local m = mark(use)
		return if m then m.def.id else nil
	end)
	local lastMinute = scope:Computed(function(use): boolean
		local m = mark(use)
		return m ~= nil and m.lastMinute
	end)
	local color = scope:Computed(function(use): Color3
		local def = Blessings.get(use(activeId) or "")
		return if def then ItemText.rarityColor(def.rarity) else Theme.Colors.Gold
	end)

	local accumulator = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			accumulator += dt
			if accumulator >= TICK then
				accumulator = 0
				now:set(Clock.now())
			end
			if Fusion.peek(lastMinute) then
				pulse:set((math.sin(os.clock() * PULSE_SPEED) + 1) / 2)
			elseif Fusion.peek(pulse) ~= 0 then
				pulse:set(0)
			end
		end)
	)

	local badge = scope:New("Frame")({
		Name = "Blessing",
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.35,
		Active = true,
		Visible = scope:Computed(function(use): boolean
			return use(activeId) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = color,
				Thickness = 1,
				Transparency = scope:Computed(function(use): number
					return 0.5 - 0.5 * use(pulse)
				end),
			}),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 6) }),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
			}),
			scope:New("TextLabel")({
				Name = "Star",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(20, 24),
				BackgroundTransparency = 1,
				Text = "✶",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = scope:Computed(function(use): number
					return 20 + 4 * use(pulse)
				end),
				TextColor3 = color,
				TextStrokeTransparency = 0.4,
			}),
			scope:New("TextLabel")({
				Name = "Countdown",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, 24),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local m = mark(use)
					return if m then BlessingMark.countdown(m.left) else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(lastMinute) then Theme.Colors.ZoneRed else Theme.Colors.Text
				end),
				TextStrokeTransparency = 0.4,
			}),
		},
	})

	local tooltip = scope:Computed(function(use): string
		local m = mark(use)
		if not m then
			return ""
		end
		local lines = BlessingBadge.describe(use, m.def)
		table.insert(lines, Text.get(use, "blessing.hud.left", { time = BlessingMark.countdown(m.left) }))
		return table.concat(lines, "\n")
	end)
	Tooltip.attach(scope, badge :: GuiObject, tooltip)
	return badge
end

return BlessingBadge
