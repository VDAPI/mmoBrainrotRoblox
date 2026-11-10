--!strict
-- Resistance elixirs (DESIGN §10) next to the portrait: icon with the time left (real time, Util/Clock) and a
-- tooltip with the stat. The active blessing sits next to the character name since S29 (Hud/BlessingBadge).
-- S153: the returning bonus first in the row (»: minutes of play left from account.returning, counted down by the
-- server only in the world, so the caption is whole minutes, not a clock).
-- UI plan phase 2 (one row of effects): PC and tablet show them in the effects row under the portrait (Hud/init), at
-- the effect icons' size; a phone keeps them at their own place.
-- Owner 2026-11-10 ("too much text"; UI plan package A, a HUD tooltip at most 48 characters): the returning bonus's
-- tooltip says the bonus; its minutes are the caption under the icon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BlessingBadge = require(script.Parent.BlessingBadge)
local Blessings = require(ReplicatedStorage.Shared.Data.Blessings)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.Parent.Parent.IconState)
local ItemIcon = require(script.Parent.Parent.Parent.Components.ItemIcon)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Returning = require(ReplicatedStorage.Shared.Logic.Returning)
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
	size: number,
	order: number,
	glyph: string,
	color: Color3,
	left: Fusion.UsedAs<number>,
	tooltip: Fusion.UsedAs<string>,
	itemId: string?,
	caption: Fusion.UsedAs<string>?
): Instance
	-- S35: the item's picture (elixir bottle) while the atlases are loaded, otherwise the glyph.
	local def = if itemId then Items.get(itemId) else nil
	local art = scope:Computed(function(use): boolean
		return IconState.picture(use, def) ~= nil
	end)
	local frame = scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.fromOffset(size, size + 16),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return use(left) > 0
		end),
		[Children] = {
			scope:New("TextLabel")({
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = Theme.Iron.Surface,
				BackgroundTransparency = Theme.HudAlpha,
				Text = scope:Computed(function(use): string
					return if use(art) then "" else glyph
				end),
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = color,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({ Color = color, Thickness = Theme.Stroke.Normal }),
					ItemIcon(scope, { Def = def, Size = UDim2.fromScale(1, 1), Visible = art }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 6),
						PaddingBottom = UDim.new(0, 6),
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
					}),
				},
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(-8, size),
				Size = UDim2.fromOffset(size + 16, 16),
				BackgroundTransparency = 1,
				Text = caption or scope:Computed(function(use): string
					return Time.format(use(left))
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = Theme.Iron.Text,
				TextStrokeTransparency = 0.3,
			}),
		},
	})
	Tooltip.attach(scope, frame :: GuiObject, tooltip)
	return frame
end

-- `size`: the icons' side (default SIZE; UI plan phase 2: the effects row under the portrait passes its own icons'
-- size, Hud/init).
local function BlessingIcon(scope: Scope, position: Fusion.UsedAs<UDim2>, size: number?): Instance
	local side = size or SIZE
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

	-- S153: the returning bonus (seconds of play left; the server writes them every 30 s)
	local returning = State.Value({ "account", "returning" })
	local bonusLeft = scope:Computed(function(use): number
		local raw = use(returning)
		return if raw == nil then 0 else Returning.sanitize(raw).left
	end)
	local bonusMinutes = scope:Computed(function(use): number
		return math.ceil(use(bonusLeft) / 60)
	end)
	local bonus = icon(
		scope,
		side,
		0,
		"»",
		Theme.Brass.Bright,
		bonusLeft,
		scope:Computed(function(use): string
			return Text.get(use, "returning.tooltip", { pct = Config.Returning.expBonus })
		end),
		nil,
		scope:Computed(function(use): string
			return Text.get(use, "returning.minutes", { min = use(bonusMinutes) })
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
						side,
						order,
						"⚱",
						Theme.Iron.Link,
						s:Computed(function(use2): number
							return Time.remaining(expiresAt, use2(now))
						end),
						tip,
						`elixir_{stat}`
					)
				)
			end
		end
		return list
	end)

	return scope:New("Frame")({
		Name = "Blessings",
		Position = position,
		Size = UDim2.fromOffset(0, side + 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			bonus,
			icons :: any,
		},
	})
end

return BlessingIcon
