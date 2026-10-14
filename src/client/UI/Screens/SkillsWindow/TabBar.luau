--!strict
-- Tabs of the skills window (S59, ROZWOJ 4): "Base" with the class glyph, then one tab per path of the class (the
-- path weapon's icon, the name and the state: main / beginnings / closed, Logic/PathView.tabState) or a single "Paths
-- soon" for a class without paths. A red dot marks a tab with something to do (PathView.attention). Scrolls
-- sideways when the tabs do not fit (phone).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemIcon = require(script.Parent.Parent.Parent.Components.ItemIcon)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local TabBar = {}

TabBar.HEIGHT = 40
TabBar.HEIGHT_TOUCH = 44

local STATE_COLOR: { [string]: Color3 } = {
	main = Theme.Colors.GoldBright,
	dip = Theme.Colors.Parchment,
	closed = Theme.Colors.TextMuted,
}

type Entry = { id: string, name: string, state: string?, stateColor: Color3?, icon: Instance }

function TabBar.new(scope: Scope, ctx: Context.Ctx, touch: boolean): Instance
	local height = if touch then TabBar.HEIGHT_TOUCH else TabBar.HEIGHT

	-- S119: with `key` the picture (class emblem) replaces the glyph once loaded.
	local function glyph(s: Scope, text: string, color: Color3, key: string?): Instance
		if key then
			return ArtIcon(s, {
				Key = key,
				Glyph = text,
				GlyphColor = color,
				Size = UDim2.fromOffset(24, 24),
				Label = { TextScaled = true, FontFace = Theme.Fonts.BodyBold },
			})
		end
		return s:New("TextLabel")({
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(24, 24),
			Text = text,
			TextScaled = true,
			FontFace = Theme.Fonts.BodyBold,
			TextColor3 = color,
		})
	end

	local function tabButton(s: Scope, order: number, entry: Entry): Instance
		local selected = s:Computed(function(use): boolean
			return use(ctx.activeTab) == entry.id
		end)
		local marked = s:Computed(function(use): boolean
			local attention = use(ctx.attention)
			if not attention then
				return false
			end
			return if entry.id == "base" then attention.base else attention.paths[entry.id] == true
		end)
		return s:New("TextButton")({
			Name = entry.id,
			LayoutOrder = order,
			Size = UDim2.fromOffset(0, height),
			AutomaticSize = Enum.AutomaticSize.X,
			AutoButtonColor = false,
			BackgroundColor3 = s:Computed(function(use): Color3
				return if use(selected) then Theme.Colors.PanelRaised else Theme.Colors.Panel
			end),
			BackgroundTransparency = s:Computed(function(use): number
				return if use(selected) then 0 else 0.4
			end),
			Text = "",
			[OnEvent("Activated")] = function()
				ctx.tab:set(entry.id)
			end,
			[Children] = {
				s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				s:New("UISizeConstraint")({ MinSize = Vector2.new(150, height) }),
				s:New("Frame")({
					Name = "Content",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(0, height),
					AutomaticSize = Enum.AutomaticSize.X,
					[Children] = {
						s:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 18) }),
						s:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 8),
						}),
						entry.icon,
						s:New("Frame")({
							LayoutOrder = 2,
							BackgroundTransparency = 1,
							Size = UDim2.fromOffset(0, height - 6),
							AutomaticSize = Enum.AutomaticSize.X,
							[Children] = {
								s:New("UIListLayout")({
									VerticalAlignment = Enum.VerticalAlignment.Center,
									SortOrder = Enum.SortOrder.LayoutOrder,
								}),
								s:New("TextLabel")({
									LayoutOrder = 1,
									BackgroundTransparency = 1,
									Size = UDim2.fromOffset(0, 17),
									AutomaticSize = Enum.AutomaticSize.X,
									Text = entry.name,
									FontFace = Theme.Fonts.BodyBold,
									TextSize = 15,
									TextColor3 = Theme.Colors.Parchment,
									TextXAlignment = Enum.TextXAlignment.Left,
								}),
								if entry.state
									then s:New("TextLabel")({
										LayoutOrder = 2,
										BackgroundTransparency = 1,
										Size = UDim2.fromOffset(0, 15),
										AutomaticSize = Enum.AutomaticSize.X,
										Text = entry.state,
										FontFace = Theme.Fonts.Body,
										TextSize = 13,
										TextColor3 = entry.stateColor or Theme.Colors.TextMuted,
										TextXAlignment = Enum.TextXAlignment.Left,
									}) :: any
									else nil,
							},
						}),
					},
				}),
				-- the gold underline of the selected tab
				s:New("Frame")({
					Name = "Underline",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 2),
					BackgroundColor3 = Theme.Colors.Gold,
					BorderSizePixel = 0,
					Visible = selected,
				}),
				s:New("Frame")({
					Name = "Dot",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -3, 0, 3),
					Size = UDim2.fromOffset(14, 14),
					BackgroundColor3 = Theme.Colors.Danger,
					Visible = marked,
					[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
				}),
			},
		})
	end

	local tabs = scope:Computed(function(use, s: Scope): { Instance }
		local character = use(ctx.character)
		if not character then
			return {}
		end
		local class = Classes.get(character.class)
		local classGlyph = if class then class.icon else "✦"
		local classColor = if class then Color3.fromHex(class.color) else Theme.Colors.Gold
		local emblem = if class then UiArt.classEmblem(class.id) else nil
		local entries: { Entry } = {
			{ id = "base", name = Text.get(use, "paths.tab.base"), icon = glyph(s, classGlyph, classColor, emblem) },
		}
		local paths = use(ctx.paths)
		if #paths == 0 then
			table.insert(entries, {
				id = "soon",
				name = Text.get(use, "paths.tab.soon"),
				icon = glyph(s, "…", Theme.Colors.TextMuted),
			})
		end
		for _, def in paths do
			local state = PathView.tabState(character, def.id)
			local weaponType = Paths.iconWeapon(def)
			local item = if weaponType then Items.get(`{weaponType}_1`) else nil
			local icon = if item
				then ItemIcon(s, { Def = item, Size = UDim2.fromOffset(24, 24) })
				else glyph(s, classGlyph, classColor, emblem)
			table.insert(entries, {
				id = def.id,
				name = Text.get(use, def.nameKey),
				state = Text.get(use, `paths.tab.{state}`),
				stateColor = STATE_COLOR[state],
				icon = icon,
			})
		end
		local out: { Instance } = {}
		for i, entry in entries do
			(entry.icon :: any).LayoutOrder = 1
			table.insert(out, tabButton(s, i, entry))
		end
		return out
	end)

	return scope:New("ScrollingFrame")({
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, height),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			tabs :: any,
		},
	})
end

return TabBar
