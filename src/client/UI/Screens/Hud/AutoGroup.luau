--!strict
-- UI plan phase 2 (owner 2026-10-31, "too much information and too many options on one screen"): the Cloak of Luring
-- (S122), Auto Hunt and Auto Potions (S134d) behind one "Auto" button right of the portrait (Logic/HudStack.EXTRAS)
-- instead of three buttons in a row. It shows while the account has any of them (each of the three still shows only
-- while it has time or is owned, never a dead button); a click opens the three under it as they were (state, time
-- left, tooltip, Auto Potions' own panel), a second click closes them. Its frame is gold while any of them runs.
-- Owner 2026-11-10 ("things covering each other"; UI plan package A): the three open right of the button, top-aligned
-- with it (the zone map's `autoPopover`, Logic/HudZones; under it they covered the effects row), and a phone has the
-- same one button at the start of the row under its portrait (Logic/PhoneHud `auto`) instead of three of its own; its
-- popover opens right of it over the effects row (an overlay the player opens).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutoGrindButton = require(script.Parent.AutoGrindButton)
local AutoPotionButton = require(script.Parent.AutoPotionButton)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local IconButton = require(script.Parent.Parent.Parent.Components.IconButton)
local LureButton = require(script.Parent.LureButton)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function AutoGroup(scope: Scope): { Instance }
	local open = scope:Value(false)
	local parts: { GuiObject } = {
		LureButton(scope, UDim2.new()) :: GuiObject,
		AutoGrindButton(scope, UDim2.new()) :: GuiObject,
		AutoPotionButton(scope, UDim2.new()) :: GuiObject,
	}
	-- how many of the three the account has now (each part's own Visible)
	local count = scope:Value(0)
	local function recount()
		local n = 0
		for _, part in parts do
			if part.Visible then
				n += 1
			end
		end
		count:set(n)
		if n == 0 then
			open:set(false)
		end
	end
	for index, part in parts do
		part.LayoutOrder = index
		table.insert(scope, part:GetPropertyChangedSignal("Visible"):Connect(recount))
	end
	task.defer(recount)

	-- any of them runs: the cloak on, a hunt going or the potions on
	local lure = State.Value({ "account", "lure" })
	local grind = State.Value({ "autoGrind" })
	local potion = State.Value({ "account", "autoPotion" })
	local running = scope:Computed(function(use): boolean
		local l, g, p = use(lure), use(grind), use(potion)
		return (type(l) == "table" and l.on == true)
			or (type(g) == "table" and g.active == true)
			or (type(p) == "table" and p.on == true)
	end)
	local shown = scope:Computed(function(use): boolean
		return use(count) > 0
	end)
	-- a phone's popover: right of its Auto button, top-aligned with it
	local phonePopover = scope:Computed(function(use): UDim2
		local auto = use(PhoneLayout.Places).auto
		return UDim2.fromOffset(auto.x + auto.w + Theme.Padding.Small, auto.y)
	end)

	return {
		IconButton(scope, {
			Name = "AutoButton",
			Icon = "⚙",
			Position = PhoneLayout.Position(scope, "auto", HudSlots.at(scope, "auto")),
			Size = PhoneLayout.Size(scope, "auto", HudSlots.sizeOf(scope, "auto")),
			Tooltip = Text.T(scope, "hud.auto"),
			Active = scope:Computed(function(use): boolean
				return use(open) or use(running)
			end),
			Visible = shown,
			OnClick = function()
				open:set(not Fusion.peek(open))
			end,
		}),
		scope:New("Frame")({
			Name = "AutoPanel",
			Position = PhoneLayout.Pick(scope, phonePopover, HudSlots.at(scope, "autoPopover")),
			Size = scope:Computed(function(use): UDim2
				return if use(PhoneLayout.Compact)
					then UDim2.fromOffset(PhoneHud.AUTO_POPOVER.w, PhoneHud.AUTO_POPOVER.h)
					else UDim2.fromOffset(0, 0)
			end),
			AutomaticSize = PhoneLayout.Pick(scope, Enum.AutomaticSize.None, Enum.AutomaticSize.XY),
			BackgroundColor3 = Theme.Iron.Surface,
			BackgroundTransparency = Theme.HudAlpha,
			ZIndex = 4,
			Visible = scope:Computed(function(use): boolean
				return use(shown) and use(open)
			end),
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, Theme.Padding.Small),
					PaddingBottom = UDim.new(0, Theme.Padding.Tiny),
					PaddingLeft = UDim.new(0, Theme.Padding.Medium),
					PaddingRight = UDim.new(0, Theme.Padding.Medium),
				}),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, Theme.Padding.Medium),
				}),
				parts :: any,
			},
		}),
	}
end

return AutoGroup
