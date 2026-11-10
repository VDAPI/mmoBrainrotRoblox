--!strict
-- Phone details sheet of the skills window (S59, ROZWOJ 4): over the whole window content after a tap on a row or a
-- card: the scrolling details (or the 3D preview on demand) and the buttons of the selection (Buy, Refund, "+ rank",
-- "- rank", To bar, Preview / Details), every target at least 44 px. Missing actions are not shown; disabled ones have
-- their reason in the details.
-- S139: the sections of the window 2.0 (Details) and "+ rank" / "- rank" / "To bar".
-- Owner 2026-11-10 (UI plan L10, "niektóre rzeczy zasłaniają inne"): one bar instead of three. The sheet had a top bar
-- (back and the name), a pinned A / B row and an action bar, and the window's "Cancel" / "Confirm" bar under it: on an
-- 844x390 phone under Roblox's 58-px top bar the details kept about 110 px. Now (Logic/GearLayout.skillSheet, from
-- the sheet's measured size): the details from the top (the name is their first line), the breakpoint cards choose on
-- their own (Breakpoints, 44-px buttons) and one bar at the bottom: back, the selection's buttons, Preview and, while
-- ranks are reserved, "Cancel" / "Confirm (+N)" (the window's reservation bar steps aside while the sheet is open, see
-- Sheet.reserveHeight). The details keep at least 260 px on every phone (tests/gearlayout.spec). Each button takes the
-- bar's width in proportion to its text (Logic/TextCaps.width), so a long label does not squeeze a short one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Details = require(script.Parent.Details)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GearLayout = require(ReplicatedStorage.Shared.Logic.GearLayout)
local Preview = require(script.Parent.Preview)
local Scale = require(script.Parent.Parent.Parent.Scale)
local Text = require(script.Parent.Parent.Parent.Text)
local TextCaps = require(ReplicatedStorage.Shared.Logic.TextCaps)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent, Out = Fusion.Children, Fusion.OnEvent, Fusion.Out

type Scope = Fusion.Scope<typeof(Fusion)>

local GAP = 6

local Sheet = {}

-- The pinned reservation bar of the window (SkillsWindow init, touch).
Sheet.RESERVE_BAR = Theme.Size.MinTouch + 8

-- Ranks are reserved on a pool tab ("Cancel" / "Confirm (+N)" are needed).
function Sheet.reserving(use: Fusion.Use, ctx: Context.Ctx): boolean
	return use(ctx.onPools) and next(use(ctx.reserve)) ~= nil
end

-- The height the window's reservation bar takes: 0 while nothing is reserved, and while the sheet is open (its own
-- bar carries both buttons then).
function Sheet.reserveHeight(use: Fusion.Use, ctx: Context.Ctx): number
	return if Sheet.reserving(use, ctx) and not use(ctx.sheet) then Sheet.RESERVE_BAR else 0
end

type Item = { text: string, variant: Button.Variant, enabled: boolean, run: () -> () }

function Sheet.new(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions): Instance
	local skillId = scope:Computed(function(use): string?
		return Details.previewSkill(use, ctx)
	end)
	local previewFrame, play = Preview.new(scope, ctx.props.Preview, skillId, nil, false)

	-- the rects of the details and of the bar, from the sheet's own size (nil until it is measured)
	local absolute = scope:Value(Vector2.zero)
	local rects = scope:Computed(function(use): GearLayout.SkillSheet?
		local size: Vector2 = use(absolute)
		local k: number = use(Scale.Value)
		if size.Y <= 0 or k <= 0 then
			return nil
		end
		return GearLayout.skillSheet({ w = size.X / k, h = size.Y / k })
	end)
	local bodySize = scope:Computed(function(use): UDim2
		local r = use(rects)
		return if r then UDim2.new(1, 0, 0, r.body.bottom - r.body.top) else UDim2.new(1, 0, 1, -GearLayout.TOUCH)
	end)
	local bodyPosition = scope:Computed(function(use): UDim2
		local r = use(rects)
		return UDim2.fromOffset(0, if r then r.body.top else 0)
	end)

	local body = scope:Computed(function(use, s: Scope): { Instance }
		if not use(ctx.sheet) then
			return {}
		end
		return Details.lines(s, use, ctx, actions, true)
	end)

	local function close()
		ctx.sheet:set(false)
		ctx.previewOpen:set(false)
	end

	local bar = scope:Computed(function(use, s: Scope): { Instance }
		local items: { Item } = {
			{ text = `← {Text.get(use, "skills.back")}`, variant = "ghost", enabled = true, run = close },
		}
		for _, spec in Details.actions(use, ctx, actions) do
			table.insert(items, {
				text = spec.text,
				variant = if spec.secondary then "secondary" else "primary",
				enabled = spec.enabled,
				run = spec.run,
			})
		end
		if use(skillId) then
			table.insert(items, {
				text = Text.get(use, if use(ctx.previewOpen) then "skills.details" else "skills.preview"),
				variant = "secondary",
				enabled = true,
				run = function()
					local open = not Fusion.peek(ctx.previewOpen)
					ctx.previewOpen:set(open)
					if open then
						play()
					end
				end,
			})
		end
		if Sheet.reserving(use, ctx) then
			local view = use(ctx.poolView)
			table.insert(
				items,
				{ text = Text.get(use, "common.cancel"), variant = "ghost", enabled = true, run = actions.cancelRanks }
			)
			table.insert(items, {
				text = Text.get(use, "skills.points.confirmN", { n = if view then view.reserved else 0 }),
				variant = "primary",
				enabled = true,
				run = actions.confirmRanks,
			})
		end
		-- each button's share of the bar follows its text (at least a touch target); a label that still does not fit
		-- wraps onto a second line inside its 44 px
		local weights: { number } = {}
		local total = 0
		for i, item in items do
			weights[i] = math.max(
				Theme.Size.MinTouch,
				TextCaps.width(item.text, Theme.TextSize.Small) + 2 * Theme.Padding.Medium
			)
			total += weights[i]
		end
		local out: { Instance } = {}
		for i, item in items do
			table.insert(
				out,
				Button(s, {
					LayoutOrder = i,
					Size = UDim2.new(weights[i] / total, -GAP * (#items - 1) / #items, 1, 0),
					TextSize = Theme.TextSize.Small,
					Variant = item.variant,
					Text = item.text,
					Disabled = not item.enabled,
					OnClick = item.run,
				})
			)
		end
		return out
	end)

	return scope:New("TextButton")({
		Name = "Sheet",
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(1, 0, 1, -Sheet.reserveHeight(use, ctx))
		end),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Paper.Surface,
		Text = "",
		ZIndex = 10,
		Visible = ctx.sheet,
		[Out("AbsoluteSize")] = absolute,
		[Children] = {
			-- the details or the preview
			scope:New("ScrollingFrame")({
				Name = "Body",
				Position = bodyPosition,
				Size = bodySize,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Paper.Label,
				Visible = scope:Computed(function(use): boolean
					return not use(ctx.previewOpen)
				end),
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, GAP) }),
					body :: any,
				},
			}),
			scope:New("Frame")({
				Name = "PreviewArea",
				Position = bodyPosition,
				Size = bodySize,
				BackgroundTransparency = 1,
				Visible = ctx.previewOpen,
				[Children] = previewFrame,
			}),
			-- the one bar: back, the selection's buttons, Preview, and Cancel / Confirm while ranks are reserved
			scope:New("Frame")({
				Name = "Bar",
				Position = scope:Computed(function(use): UDim2
					local r = use(rects)
					return if r then UDim2.fromOffset(0, r.bar.top) else UDim2.new(0, 0, 1, -GearLayout.TOUCH)
				end),
				Size = scope:Computed(function(use): UDim2
					local r = use(rects)
					return UDim2.new(1, 0, 0, if r then r.bar.bottom - r.bar.top else GearLayout.TOUCH)
				end),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, GAP),
					}),
					bar :: any,
				},
			}),
		},
		[OnEvent("Activated")] = function() end,
	})
end

return Sheet
