--!strict
-- Look picker (S132, DESIGN-17 §9a; W10: the character creator's tabs). Four tabs: Face (face, brows, facial hair),
-- Hair (hairstyle, hair colour), Body (skin, build), Paint (face paint, its colour); a list choice is "◀ name ▶", a
-- colour choice a grid of tiles (they wrap on a narrow frame). "Random" (Logic/CharacterLook.random) and "Default"
-- under the tabs. It only sets props.Look (and props.Tab, which the preview follows); the creator and the look window
-- send the look to the server. Every target is at least 44 px.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local CharacterLook = require(ReplicatedStorage.Shared.Logic.CharacterLook)
local ClassLooks = require(ReplicatedStorage.Shared.Data.ClassLooks)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Rng = require(ReplicatedStorage.Shared.Logic.Rng)
local Sounds = require(script.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>
export type Look = ClassLooks.Look

export type Props = {
	Look: Fusion.Value<Look>,
	-- W10: the open tab ("face" | "hair" | "body" | "paint"); the preview zooms on the face for "face" and "paint"
	Tab: Fusion.Value<string>?,
	Size: Fusion.UsedAs<UDim2>?,
	Position: Fusion.UsedAs<UDim2>?,
	LayoutOrder: number?,
	Surface: Theme.SurfaceName?, -- S135: the background its buttons stand on (default "paper")
}

local TILE = Theme.Size.MinTouch
local LABEL = 112
local ROW = Theme.Size.MinTouch

local TABS = { "face", "hair", "body", "paint" }

local function indexOf(list: { any }, id: string): number
	for i, entry in list do
		if entry.id == id then
			return i
		end
	end
	return 1
end

local function with(look: Look, field: string, id: string): Look
	local out = table.clone(CharacterLook.normalize(look)) :: any
	out[field] = id
	return out
end

local function label(scope: Scope, key: string): Instance
	return scope:New("TextLabel")({
		Name = "Label",
		Size = UDim2.fromOffset(LABEL, ROW),
		BackgroundTransparency = 1,
		Text = Text.T(scope, key),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Paper.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
end

-- "◀ name ▶" over a list of ids.
local function stepper(scope: Scope, order: number, props: Props, field: string, list: { any }): Instance
	local function step(delta: number)
		Sounds.play("click")
		local look = Fusion.peek(props.Look)
		local i = indexOf(list, (CharacterLook.normalize(look) :: any)[field])
		local n = #list
		props.Look:set(with(look, field, list[(i - 1 + delta) % n + 1].id))
	end
	return scope:New("Frame")({
		Name = field,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundTransparency = 1,
		[Children] = {
			label(scope, `look.row.{field}`),
			Button(scope, {
				Position = UDim2.fromOffset(LABEL, 0),
				Size = UDim2.fromOffset(TILE, ROW),
				Variant = "secondary",
				Surface = props.Surface,
				Text = "◀",
				OnClick = function()
					step(-1)
				end,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(LABEL + TILE + 4, 0),
				Size = UDim2.new(1, -(LABEL + 2 * TILE + 8), 1, 0),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local id = (CharacterLook.normalize(use(props.Look)) :: any)[field]
					return `{Text.get(use, `look.{field}.{id}`)}  {indexOf(list, id)}/{#list}`
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Heading,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(TILE, ROW),
				Variant = "secondary",
				Surface = props.Surface,
				Text = "▶",
				OnClick = function()
					step(1)
				end,
			}),
		},
	})
end

-- A grid of colour tiles over a list of { id, color }; the tooltip names the colour.
local function tiles(scope: Scope, order: number, props: Props, field: string, list: { any }): Instance
	local cells: { any } = {
		scope:New("UIGridLayout")({
			CellSize = UDim2.fromOffset(TILE, TILE),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, entry in list do
		local selected = scope:Computed(function(use): boolean
			return (CharacterLook.normalize(use(props.Look)) :: any)[field] == entry.id
		end)
		local tile = scope:New("TextButton")({
			Name = entry.id,
			LayoutOrder = i,
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Theme.tint(entry.color),
			[OnEvent("Activated")] = function()
				Sounds.play("click")
				props.Look:set(with(Fusion.peek(props.Look), field, entry.id))
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = scope:Computed(function(use): Color3
						return if use(selected) then Theme.Brass.Frame else Theme.Paper.Rule
					end),
					Thickness = scope:Computed(function(use): number
						return if use(selected) then Theme.Stroke.Thick else Theme.Stroke.Thin
					end),
				}),
			},
		}) :: GuiObject
		-- natural skin tones are numbered, every other colour has a name
		local name = if field == "skin" and i <= CharacterLook.NATURAL_SKINS
			then Text.T(scope, "look.skin.n", { n = i })
			else Text.T(scope, `look.{field}.{entry.id}`)
		Tooltip.attach(scope, tile, name)
		table.insert(cells, tile)
	end
	return scope:New("Frame")({
		Name = field,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			label(scope, `look.row.{field}`),
			scope:New("Frame")({
				Name = "Tiles",
				Position = UDim2.fromOffset(LABEL, 0),
				Size = UDim2.new(1, -LABEL, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = cells :: any,
			}),
		},
	})
end

local function page(scope: Scope, tab: Fusion.Value<string>, id: string, rows: { Instance }): Instance
	local children: { any } = {
		scope:New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, Theme.Padding.Small),
		}),
	}
	for _, row in rows do
		table.insert(children, row)
	end
	return scope:New("Frame")({
		Name = id,
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return use(tab) == id
		end),
		[Children] = children :: any,
	})
end

local function LookPicker(scope: Scope, props: Props): Instance
	local tab: Fusion.Value<string> = props.Tab or scope:Value("face")
	local tabButtons: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	}
	for i, id in TABS do
		table.insert(
			tabButtons,
			Button(scope, {
				LayoutOrder = i,
				Size = UDim2.new(1 / #TABS, -3, 1, 0),
				Variant = scope:Computed(function(use): Button.Variant
					return if use(tab) == id then "primary" else "secondary"
				end) :: any,
				Surface = props.Surface,
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, `look.tab.{id}`),
				OnClick = function()
					Sounds.play("click")
					tab:set(id)
				end,
			})
		)
	end
	return scope:New("Frame")({
		Name = "LookPicker",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size or UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Medium),
			}),
			scope:New("Frame")({
				Name = "Tabs",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, ROW),
				BackgroundTransparency = 1,
				[Children] = tabButtons :: any,
			}),
			page(scope, tab, "face", {
				stepper(scope, 1, props, "face", ClassLooks.FACES),
				stepper(scope, 2, props, "brows", ClassLooks.BROWS),
				stepper(scope, 3, props, "beard", ClassLooks.BEARDS),
			}),
			page(scope, tab, "hair", {
				stepper(scope, 1, props, "hair", ClassLooks.HAIRS),
				tiles(scope, 2, props, "hairColor", ClassLooks.HAIR_COLORS),
			}),
			page(scope, tab, "body", {
				tiles(scope, 1, props, "skin", ClassLooks.SKINS),
				stepper(scope, 2, props, "build", ClassLooks.BUILDS),
			}),
			page(scope, tab, "paint", {
				stepper(scope, 1, props, "paint", ClassLooks.PAINTS),
				tiles(scope, 2, props, "paintColor", ClassLooks.PAINT_COLORS),
			}),
			scope:New("Frame")({
				Name = "Buttons",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, ROW),
				BackgroundTransparency = 1,
				[Children] = {
					Button(scope, {
						Size = UDim2.new(0.5, -4, 1, 0),
						Variant = "secondary",
						Surface = props.Surface,
						TextSize = Theme.TextSize.Small,
						Text = Text.T(scope, "look.random"),
						OnClick = function()
							Sounds.play("click")
							local rng = Rng.new(math.floor(os.clock() * 1000) % 2147483647)
							props.Look:set(CharacterLook.random(function()
								return rng:next()
							end))
						end,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0.5, -4, 1, 0),
						Variant = "ghost",
						Surface = props.Surface,
						TextSize = Theme.TextSize.Small,
						Text = Text.T(scope, "look.default"),
						OnClick = function()
							props.Look:set(CharacterLook.normalize(ClassLooks.DEFAULT_LOOK))
						end,
					}),
				},
			}),
		},
	})
end

return LookPicker
