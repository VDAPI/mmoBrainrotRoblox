--!strict
-- Resistance elixirs (DESIGN §10) next to the portrait: icon with the time left (real time, Util/Clock) and a
-- tooltip with the stat. The active blessing sits next to the character name since S29 (Hud/BlessingBadge).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BlessingBadge = require(script.Parent.BlessingBadge)
local Blessings = require(ReplicatedStorage.Shared.Data.Blessings)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SIZE = 48

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
		Visible = scope:Computed(function(use): boolean
			return use(left) > 0
		end),
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

	-- Rebuilt only when the set of elixirs changes; the clock just updates each countdown text.
	local icons = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		local t = Fusion.peek(now)
		local order = 0
		for stat, expiresAt in (use(elixirs) or {}) :: { [string]: number } do
			if expiresAt > t then
				order += 1
				local name = Text.get(use, `item.elixir_{stat}.name`)
				local tip = `{name}\n{BlessingBadge.statLine(use, stat, Blessings.ELIXIR_VALUE)}`
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
						tip
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
