--!strict
-- Skills window (K), DESIGN §23, ROZWOJ 4 (S59; S56-S58 built the rules underneath).
-- S139 (DESIGN-18 §12, the window 2.0): header (build sets; on a pool tab the pool's free skill points and the
-- reservation's "Confirm (+N)" / "Cancel", on the directions tab the free talent points, the leading direction and
-- the capstone); tabs: one per weapon pool (the worn one first) and "Directions"; a pool tab shows the pool tree
-- (PoolTree: tiles by the shared ladder, role columns), the directions tab a switch of directions and the tree of the
-- shown one (PathTab). Details of the selection (a click): fixed sections (Details), the 3D preview on demand
-- (S28), "+ rank" / "- rank" / "To bar" (Buy / Refund for a node).
-- Two layouts: PC 920 x 640 (the tree 510 px on the left, details on the right); touch full screen (one column, a tap
-- opens the details sheet, the reservation's "Cancel" / "Confirm" pinned to the bottom). A full bar opens the 2 x 4
-- slot picker. Data only from Logic/SkillPoints, Logic/SkillPools, Logic/Paths, Logic/PathView and UI/SkillInfo; the
-- window computes nothing itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Actions)
local BarPicker = require(script.BarPicker)
local Button = require(script.Parent.Parent.Components.Button)
local Context = require(script.Context)
local Details = require(script.Details)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Header = require(script.Header)
local PathTab = require(script.PathTab)
local PoolTree = require(script.PoolTree)
local Preview = require(script.Preview)
local Sheet = require(script.Sheet)
local TabBar = require(script.TabBar)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Components.Tooltip)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = Context.Props

local PREVIEW_HEIGHT = 150
local DETAILS_X = PathTab.LIST_WIDTH + 12
local GAP = 6
local REASON = 20 -- the reason line over the buttons

local function list(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions, touch: boolean): { any }
	return {
		scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
		PoolTree.new(scope, ctx, actions, touch),
		PathTab.new(scope, ctx, actions, touch),
	}
end

local function scroller(
	scope: Scope,
	name: string,
	position: UDim2,
	size: Fusion.UsedAs<UDim2>,
	children: { any }
): Instance
	return scope:New("ScrollingFrame")({
		Name = name,
		Position = position,
		Size = size,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Label,
		[Children] = children,
	})
end

-- PC: details panel with the preview on demand, the sections and the buttons of the selection (two per row).
local function detailsPanel(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions): Instance
	local skillId = scope:Computed(function(use): string?
		return Details.previewSkill(use, ctx)
	end)
	local previewFrame, play = Preview.new(scope, ctx.props.Preview, skillId, PREVIEW_HEIGHT, false)
	local showPreview = scope:Computed(function(use): boolean
		return use(ctx.previewOpen) and use(skillId) ~= nil
	end)
	local lines = scope:Computed(function(use, s: Scope): { Instance }
		return Details.lines(s, use, ctx, actions, false)
	end)
	-- the selection's buttons and "Preview" / "Details" for an active skill
	local specs = scope:Computed(function(use): { Details.ActionSpec }
		local out = table.clone(Details.actions(use, ctx, actions))
		if use(skillId) then
			local open = use(ctx.previewOpen)
			table.insert(out, {
				text = Text.get(use, if open then "skills.details" else "skills.preview"),
				enabled = true,
				run = function()
					local now = not Fusion.peek(ctx.previewOpen)
					ctx.previewOpen:set(now)
					if now then
						play()
					end
				end,
				secondary = true,
			})
		end
		return out
	end)
	local rows = scope:Computed(function(use): number
		return math.max(1, math.ceil(#use(specs) / 2))
	end)
	local bottom = scope:Computed(function(use): number
		local n = use(rows)
		return n * Theme.Size.ButtonHeightSmall + (n - 1) * GAP + REASON + 4
	end)
	local buttons = scope:Computed(function(use, s: Scope): { Instance }
		local out: { Instance } = {}
		for i, spec in use(specs) do
			local button = Button(s, {
				LayoutOrder = i,
				Variant = if spec.secondary then "secondary" else "primary",
				TextSize = Theme.TextSize.Small,
				Text = spec.text,
				Disabled = not spec.enabled,
				OnClick = spec.run,
			})
			-- every inactive button also carries its own reason (S59 rule 6), the line above may be truncated
			if not spec.enabled and spec.reason then
				Tooltip.attach(s, button :: GuiObject, spec.reason)
			end
			table.insert(out, button)
		end
		return out
	end)
	-- the reasons of every inactive button (S59 E6), each once
	local reason = scope:Computed(function(use): string
		local parts: { string } = {}
		for _, spec in use(specs) do
			if not spec.enabled and spec.reason and not table.find(parts, spec.reason) then
				table.insert(parts, spec.reason)
			end
		end
		return table.concat(parts, " · ")
	end)
	local top = scope:Computed(function(use): number
		return if use(showPreview) then PREVIEW_HEIGHT + 8 else 0
	end)
	return scope:New("Frame")({
		Name = "Details",
		Position = UDim2.fromOffset(DETAILS_X, 0),
		Size = UDim2.new(1, -DETAILS_X, 1, 0),
		BackgroundColor3 = Theme.Paper.Raised,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Paper.Border,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Padding.Medium),
				PaddingBottom = UDim.new(0, Theme.Padding.Medium),
				PaddingLeft = UDim.new(0, Theme.Padding.Medium),
				PaddingRight = UDim.new(0, Theme.Padding.Medium),
			}),
			scope:New("Frame")({
				Name = "PreviewArea",
				Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT),
				BackgroundTransparency = 1,
				Visible = showPreview,
				[Children] = previewFrame,
			}),
			scroller(
				scope,
				"Lines",
				scope:Computed(function(use): UDim2
					return UDim2.fromOffset(0, use(top))
				end) :: any,
				scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 1, -(use(top) + use(bottom) + 4))
				end),
				{
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
					lines :: any,
				}
			),
			scope:New("TextLabel")({
				Name = "Reason",
				AnchorPoint = Vector2.new(0, 1),
				Position = scope:Computed(function(use): UDim2
					return UDim2.new(0, 0, 1, -(use(bottom) - REASON))
				end),
				Size = UDim2.new(1, 0, 0, REASON),
				BackgroundTransparency = 1,
				Text = reason,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("Frame")({
				Name = "Buttons",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, use(bottom) - REASON - 4)
				end),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIGridLayout")({
						CellSize = UDim2.new(0.5, -GAP / 2, 0, Theme.Size.ButtonHeightSmall),
						CellPadding = UDim2.fromOffset(GAP, GAP),
						FillDirectionMaxCells = 2,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					buttons :: any,
				},
			}),
		},
	})
end

local function desktop(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions): Instance
	local top = Header.HEIGHT + 6 + TabBar.HEIGHT + 6
	return scope:New("Frame")({
		Name = "Desktop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			Header.new(scope, ctx, actions, false),
			scope:New("Frame")({
				Name = "TabRow",
				Position = UDim2.fromOffset(0, Header.HEIGHT + 6),
				Size = UDim2.new(1, 0, 0, TabBar.HEIGHT),
				BackgroundTransparency = 1,
				[Children] = TabBar.new(scope, ctx, false),
			}),
			scope:New("Frame")({
				Name = "Body",
				Position = UDim2.fromOffset(0, top),
				Size = UDim2.new(1, 0, 1, -top),
				BackgroundTransparency = 1,
				[Children] = {
					scroller(
						scope,
						"List",
						UDim2.new(),
						UDim2.new(0, PathTab.LIST_WIDTH, 1, 0),
						list(scope, ctx, actions, false)
					),
					detailsPanel(scope, ctx, actions),
				},
			}),
		},
	})
end

-- Phone: the reservation's "Cancel" / "Confirm (+N)" pinned to the bottom of the screen (also over the sheet).
local function reserveBar(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions): Instance
	local count = scope:Computed(function(use): number
		local view = use(ctx.poolView)
		return if view then view.reserved else 0
	end)
	return scope:New("Frame")({
		Name = "ReserveBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
		BackgroundTransparency = 1,
		ZIndex = 15,
		Visible = scope:Computed(function(use): boolean
			return Sheet.reserveHeight(use, ctx) > 0
		end),
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, GAP),
			}),
			Button(scope, {
				LayoutOrder = 1,
				Size = UDim2.new(0.35, -GAP, 1, 0),
				Variant = "ghost",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "common.cancel"),
				OnClick = actions.cancelRanks,
			}),
			Button(scope, {
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.65, 1),
				Variant = "primary",
				TextSize = Theme.TextSize.Small,
				Text = scope:Computed(function(use): string
					return Text.get(use, "skills.points.confirmN", { n = use(count) })
				end),
				OnClick = actions.confirmRanks,
			}),
		},
	})
end

local function touchLayout(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions): Instance
	local top = Header.HEIGHT_TOUCH + 4 + TabBar.HEIGHT_TOUCH + 4
	return scope:New("Frame")({
		Name = "Touch",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			Header.new(scope, ctx, actions, true),
			scope:New("Frame")({
				Name = "TabRow",
				Position = UDim2.fromOffset(0, Header.HEIGHT_TOUCH + 4),
				Size = UDim2.new(1, 0, 0, TabBar.HEIGHT_TOUCH),
				BackgroundTransparency = 1,
				[Children] = TabBar.new(scope, ctx, true),
			}),
			scroller(
				scope,
				"List",
				UDim2.fromOffset(0, top),
				scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 1, -(top + Sheet.reserveHeight(use, ctx)))
				end),
				list(scope, ctx, actions, true)
			),
			Sheet.new(scope, ctx, actions),
			reserveBar(scope, ctx, actions),
		},
	})
end

local function SkillsWindow(scope: Scope, props: Props): Fusion.Child
	local ctx = Context.new(scope, props)
	local actions = Actions.new(ctx)
	-- The layout follows the input device (touch = full-screen window, CharacterWindow pattern).
	local layout = scope:Computed(function(use, s: Scope): Instance
		if use(Device.Touch) then
			return touchLayout(s, ctx, actions)
		end
		return desktop(s, ctx, actions)
	end)
	return {
		layout :: any,
		BarPicker(scope, ctx, actions, Device.Touch),
	}
end

return SkillsWindow
