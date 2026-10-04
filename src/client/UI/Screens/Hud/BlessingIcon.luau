--!strict
-- Active blessing (DESIGN §11) and resistance elixirs next to the portrait: rarity-coloured icon with the
-- time left (real time, Util/Clock) and a tooltip with the stats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Blessings = require(ReplicatedStorage.Shared.Data.Blessings)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local State = require(script.Parent.Parent.Parent.State)
local Stats = require(ReplicatedStorage.Shared.Data.Stats)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SIZE = 48

local function statLine(use: Fusion.Use, stat: string, value: number): string
	local def = Stats.get(stat)
	local suffix = if def and def.format == "pct" or stat == "atkSpeed" then "%" else ""
	return `+{value}{suffix} {Text.get(use, `stat.{stat}`)}`
end

local function icon(
	scope: Scope,
	order: number,
	glyph: string,
	color: Color3,
	left: Fusion.UsedAs<number>,
	tooltip: Fusion.UsedAs<string>
): Instance
	local frame = scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.fromOffset(SIZE, SIZE + 16),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("TextLabel")({
				Size = UDim2.fromOffset(SIZE, SIZE),
				BackgroundColor3 = Theme.Colors.Panel,
				BackgroundTransparency = 0.1,
				Text = glyph,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = color,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({ Color = color, Thickness = 2 }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 6),
						PaddingBottom = UDim.new(0, 6),
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
					}),
				},
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(-8, SIZE),
				Size = UDim2.fromOffset(SIZE + 16, 16),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return Time.format(use(left))
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 13,
				TextColor3 = Theme.Colors.Text,
				TextStrokeTransparency = 0.3,
			}),
		},
	})
	Tooltip.attach(scope, frame :: GuiObject, tooltip)
	return frame
end

local function BlessingIcon(scope: Scope, position: UDim2): Instance
	local blessing = State.Value({ "character", "blessing" })
	local elixirs = State.Value({ "character", "elixirs" })
	local now = scope:Value(Clock.now())
	local accumulator = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			accumulator += dt
			if accumulator >= 0.5 then
				accumulator = 0
				now:set(Clock.now())
			end
		end)
	)

	local icons = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		local t = use(now)
		local active = use(blessing)
		local def = if type(active) == "table" and active.expiresAt > t then Blessings.get(active.id) else nil
		if def and active then
			local rarity = Rarities.get(def.rarity)
			local color = ItemText.rarityColor(def.rarity)
			local lines = {
				`{Text.get(use, def.nameKey)} ({if rarity then Text.get(use, rarity.nameKey) else ""})`,
			}
			local keys = {}
			for stat in def.stats do
				table.insert(keys, stat)
			end
			table.sort(keys)
			for _, stat in keys do
				table.insert(lines, statLine(use, stat, def.stats[stat]))
			end
			local expiresAt = active.expiresAt
			table.insert(
				list,
				icon(
					s,
					1,
					"✶",
					color,
					s:Computed(function(use2): number
						return Time.remaining(expiresAt, use2(now))
					end),
					table.concat(lines, "\n")
				)
			)
		end
		local order = 1
		for stat, expiresAt in (use(elixirs) or {}) :: { [string]: number } do
			if expiresAt > t then
				order += 1
				table.insert(
					list,
					icon(
						s,
						order,
						"⚱",
						Theme.Colors.Accent,
						s:Computed(function(use2): number
							return Time.remaining(expiresAt, use2(now))
						end),
						`{Text.get(use, `item.elixir_{stat}.name`)}\n{statLine(use, stat, Blessings.ELIXIR_VALUE)}`
					)
				)
			end
		end
		return list
	end)

	return scope:New("Frame")({
		Name = "Blessings",
		Position = position,
		Size = UDim2.fromOffset(SIZE * 5 + 40, SIZE + 16),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			icons :: any,
		},
	})
end

return BlessingIcon
