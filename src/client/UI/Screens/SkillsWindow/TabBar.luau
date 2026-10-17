--!strict
-- Tabs of the skills window (S59, ROZWOJ 4). S139 (DESIGN-18 §12): one tab per weapon pool of the class, the pool of the
-- equipped weapon first (the weapon's icon, the pool name, "N pts to spend"), the other pools with "wear: <weapon>"
-- (their ranks are reserved and confirmed the same way, they work once that weapon is worn), then "Directions" (the
-- leading direction's name or the free talent points). A red dot marks a tab with something to do
-- (PathView.attention: pools / directions). Scrolls sideways when the tabs do not fit (phone).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemIcon = require(script.Parent.Parent.Parent.Components.ItemIcon)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillPoints = require(ReplicatedStorage.Shared.Logic.SkillPoints)
local SkillPools = require(ReplicatedStorage.Shared.Logic.SkillPools)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local TabBar = {}

-- S135: parchment cards like the Tabs component (two lines: the name and the path state)
TabBar.HEIGHT = 46
TabBar.HEIGHT_TOUCH = 50

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
			if entry.id == Context.DIRECTIONS then
				return attention.directions
			end
			local poolId = Context.poolOfTab(entry.id)
			return poolId ~= nil and attention.pools[poolId] == true
		end)
		return s:New("TextButton")({
			Name = entry.id,
			LayoutOrder = order,
			Size = UDim2.fromOffset(0, height),
			AutomaticSize = Enum.AutomaticSize.X,
			AutoButtonColor = false,
			BackgroundColor3 = s:Computed(function(use): Color3
				return if use(selected) then Theme.Paper.Surface else Theme.Paper.Sunken
			end),
			Text = "",
			[OnEvent("Activated")] = function()
				ctx.tab:set(entry.id)
			end,
			[Children] = {
				s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				s:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = Theme.Stroke.Normal,
					Color = Theme.Brass.Frame,
					Enabled = selected,
				}),
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
									Size = UDim2.fromOffset(0, Theme.TextSize.Small + 2),
									AutomaticSize = Enum.AutomaticSize.X,
									Text = entry.name,
									FontFace = Theme.Fonts.BodyBold,
									TextSize = Theme.TextSize.Small,
									TextColor3 = s:Computed(function(use): Color3
										return if use(selected) then Theme.Paper.Heading else Theme.Paper.Text
									end),
									TextXAlignment = Enum.TextXAlignment.Left,
								}),
								if entry.state
									then s:New("TextLabel")({
										LayoutOrder = 2,
										BackgroundTransparency = 1,
										Size = UDim2.fromOffset(0, Theme.TextSize.Caption + 1),
										AutomaticSize = Enum.AutomaticSize.X,
										Text = entry.state,
										FontFace = Theme.Fonts.BodyMedium,
										TextSize = Theme.TextSize.Caption,
										TextColor3 = entry.stateColor or Theme.Paper.TextMuted,
										TextXAlignment = Enum.TextXAlignment.Left,
									}) :: any
									else nil,
							},
						}),
					},
				}),
				-- the open bottom of the selected card (joins the page under it)
				s:New("Frame")({
					Name = "Join",
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.new(0, 0, 1, -Theme.Stroke.Normal),
					Size = UDim2.new(1, 0, 0, Theme.Stroke.Normal * 2 + 1),
					BackgroundColor3 = Theme.Paper.Surface,
					BorderSizePixel = 0,
					ZIndex = 2,
					Visible = selected,
				}),
				s:New("Frame")({
					Name = "Dot",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -3, 0, 3),
					Size = UDim2.fromOffset(14, 14),
					BackgroundColor3 = Theme.Paper.Danger,
					Visible = marked,
					[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
				}),
			},
		})
	end

	local tabs = scope:Computed(function(use, s: Scope): { Instance }
		local character: any = use(ctx.character)
		if not character then
			return {}
		end
		local class = Classes.get(character.class)
		local classGlyph = if class then class.icon else "✦"
		local classColor = if class then Theme.readable(class.color, "paper") else Theme.Paper.Heading
		local emblem = if class then UiArt.classEmblem(class.id) else nil
		local active = use(ctx.activePool)
		local entries: { Entry } = {}
		-- the pools: the worn one first
		local order = SkillPools.ids(character.class)
		if active then
			local at = table.find(order, active)
			if at then
				table.remove(order, at)
				table.insert(order, 1, active)
			end
		end
		local equipment = use(ctx.equipment)
		local worn = if type(equipment) == "table" then equipment.weapon else nil
		local wornDef = if type(worn) == "table" and type(worn.id) == "string" then Items.get(worn.id) else nil
		for _, poolId in order do
			local def = SkillPools.def(character.class, poolId)
			if def then
				local isActive = poolId == active
				local itemDef = if isActive and wornDef then wornDef else Items.get(`{def.weapon.main[1]}_1`)
				local icon = if def.weapon.element
					then glyph(s, def.glyph, classColor)
					elseif itemDef then ItemIcon(s, { Def = itemDef, Size = UDim2.fromOffset(24, 24) })
					else glyph(s, def.glyph, classColor)
				local state: string
				local stateColor = Theme.Paper.TextMuted
				if isActive then
					local free = math.max(0, SkillPoints.free(character, poolId))
					state = Text.get(use, "skills.tab.free", { n = free })
					if free > 0 then
						stateColor = Theme.Paper.Success
					end
				elseif def.weapon.element then
					state = Text.get(
						use,
						"skills.tab.wearElement",
						{ element = Text.get(use, `element.{def.weapon.element}`) }
					)
				else
					state =
						Text.get(use, "skills.tab.wear", { weapon = Text.get(use, `itemBase.{def.weapon.main[1]}`) })
				end
				table.insert(entries, {
					id = Context.poolTab(poolId),
					name = Text.get(use, def.nameKey),
					state = state,
					stateColor = stateColor,
					icon = icon,
				})
			end
		end
		-- the directions
		local leading = Paths.mainOf(character)
		local leadingDef = if leading then PathData.get(leading) else nil
		local talents = math.max(0, Paths.free(character))
		table.insert(entries, {
			id = Context.DIRECTIONS,
			name = Text.get(use, "skills.tab.directions"),
			state = if talents > 0
				then Text.get(use, "skills.tab.talents", { n = talents })
				elseif leadingDef then Text.get(use, leadingDef.nameKey)
				else Text.get(use, "skills.tab.talents", { n = 0 }),
			stateColor = if talents > 0 then Theme.Paper.Success else Theme.Paper.TextMuted,
			icon = glyph(s, classGlyph, classColor, emblem),
		})
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
