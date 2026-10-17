--!strict
-- Skills window (K), DESIGN §23, ROZWOJ 4 (S59; S56-S58 built the rules underneath). Header: build sets (S58), free
-- path points, the leading direction (S138; no main path). Tabs: "Base" and one per path of the class ("Paths soon" without paths). Base: a row
-- per skill (rank, next rank's level, breakpoint badges, "To bar"); a path tab: a short header and the tree of node
-- pictures (FIX 2026-10-14, PathTab). Details of the selection (a click): the skill, the node or the path's own
-- description, A / B breakpoint cards, the 3D preview (S28), Buy / Refund / To bar.
-- Two layouts: PC 920 x 640 (list 510 px on the left, details 354 px on the right); touch full screen (one column,
-- a tap opens the details sheet). A full bar opens the 2 x 5 slot picker. Data only from Logic/Paths,
-- Logic/PathView and UI/SkillInfo; the window computes nothing itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Actions)
local BarPicker = require(script.BarPicker)
local BaseList = require(script.BaseList)
local Button = require(script.Parent.Parent.Components.Button)
local Context = require(script.Context)
local Details = require(script.Details)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Header = require(script.Header)
local PathTab = require(script.PathTab)
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
local BOTTOM = Theme.Size.ButtonHeightSmall + 26 -- reason line + buttons

-- "Paths soon" (class without paths, ROZWOJ 2.6).
local function soon(scope: Scope, ctx: Context.Ctx): Fusion.Computed<any>
	return scope:Computed(function(use, s: Scope): { Instance }
		if use(ctx.activeTab) ~= "soon" then
			return {}
		end
		local function label(order: number, key: string, font: Font, size: number, color: Color3): Instance
			return s:New("TextLabel")({
				LayoutOrder = order,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = Text.get(use, key),
				TextWrapped = true,
				FontFace = font,
				TextSize = size,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		end
		return {
			label(1, "paths.soon", Theme.Fonts.Display, Theme.TextSize.Large, Theme.Paper.Heading),
			label(2, "paths.soon.body", Theme.Fonts.Body, Theme.TextSize.Small, Theme.Paper.Text),
		}
	end)
end

local function list(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions, touch: boolean): { any }
	return {
		scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		BaseList.new(scope, ctx, actions, touch),
		PathTab.new(scope, ctx, actions, touch),
		soon(scope, ctx),
	}
end

local function scroller(scope: Scope, name: string, position: UDim2, size: UDim2, children: { any }): Instance
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

-- PC: details panel with the preview, the lines and the buttons of the selection.
local function detailsPanel(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions): Instance
	local skillId = scope:Computed(function(use): string?
		return Details.previewSkill(use, ctx)
	end)
	local previewFrame = Preview.new(scope, ctx.props.Preview, skillId, PREVIEW_HEIGHT, true)
	local lines = scope:Computed(function(use, s: Scope): { Instance }
		return Details.lines(s, use, ctx, actions, false)
	end)
	local specs = scope:Computed(function(use): { Details.ActionSpec }
		return Details.actions(use, ctx, actions)
	end)
	local buttons = scope:Computed(function(use, s: Scope): { Instance }
		local out: { Instance } = {}
		local all = use(specs)
		for i, spec in all do
			local button = Button(s, {
				LayoutOrder = i,
				Size = UDim2.new(1 / #all, -6, 1, 0),
				Variant = if spec.key == "paths.node.refund" then "secondary" else "primary",
				TextSize = Theme.TextSize.Small,
				Text = Text.get(use, spec.key),
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
			previewFrame,
			scroller(
				scope,
				"Lines",
				UDim2.fromOffset(0, PREVIEW_HEIGHT + 8),
				UDim2.new(1, 0, 1, -(PREVIEW_HEIGHT + 8 + BOTTOM + 4)),
				{
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
					lines :: any,
				}
			),
			scope:New("TextLabel")({
				Name = "Reason",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -(Theme.Size.ButtonHeightSmall + 4)),
				Size = UDim2.new(1, 0, 0, 20),
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
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeightSmall),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
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
			Header.new(scope, ctx, false),
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

local function touchLayout(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions): Instance
	local top = Header.HEIGHT_TOUCH + 4 + TabBar.HEIGHT_TOUCH + 4
	return scope:New("Frame")({
		Name = "Touch",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			Header.new(scope, ctx, true),
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
				UDim2.new(1, 0, 1, -top),
				list(scope, ctx, actions, true)
			),
			Sheet.new(scope, ctx, actions),
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
