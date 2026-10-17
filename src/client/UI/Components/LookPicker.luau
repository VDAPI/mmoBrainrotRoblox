--!strict
-- Look picker (S132, DESIGN-17 §9a): face and hairstyle as "◀ name ▶", the skin as a row of colour tiles (two rows of
-- five on a narrow frame: the tiles wrap), "Random" (Logic/Rng) and "Default". It only sets props.Look; the creator
-- and the look window send it to the server. Every target is at least 44 px.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
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
	Size: Fusion.UsedAs<UDim2>?,
	Position: Fusion.UsedAs<UDim2>?,
	LayoutOrder: number?,
	Surface: Theme.SurfaceName?, -- S135: the background its buttons stand on (default "paper")
}

local TILE = Theme.Size.MinTouch
local LABEL = 96
local ROW = Theme.Size.MinTouch

local function indexOf(list: { any }, id: string): number
	for i, entry in list do
		if entry.id == id then
			return i
		end
	end
	return 1
end

local function with(look: Look, field: string, id: string): Look
	local out = table.clone(look) :: any
	out[field] = id
	return out
end

-- "◀ name ▶" over a list of ids.
local function stepper(
	scope: Scope,
	order: number,
	labelKey: string,
	props: Props,
	field: "face" | "hair",
	list: { any },
	prefix: string
): Instance
	local function step(delta: number)
		Sounds.play("click")
		local look = Fusion.peek(props.Look)
		local i = indexOf(list, (look :: any)[field])
		local n = #list
		props.Look:set(with(look, field, list[(i - 1 + delta) % n + 1].id))
	end
	return scope:New("Frame")({
		Name = field,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("TextLabel")({
				Size = UDim2.new(0, LABEL, 1, 0),
				BackgroundTransparency = 1,
				Text = Text.T(scope, labelKey),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Button(scope, {
				Position = UDim2.fromOffset(LABEL, 0),
				Size = UDim2.fromOffset(TILE, ROW),
				Variant = "secondary",
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
					return Text.get(use, `{prefix}.{(use(props.Look) :: any)[field]}`)
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
				Text = "▶",
				OnClick = function()
					step(1)
				end,
			}),
		},
	})
end

local function skinTiles(scope: Scope, props: Props): Instance
	local tiles: { any } = {
		scope:New("UIGridLayout")({
			CellSize = UDim2.fromOffset(TILE, TILE),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, skin in ClassLooks.SKINS do
		local tile = scope:New("TextButton")({
			Name = skin.id,
			LayoutOrder = i,
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Theme.tint(skin.color),
			[OnEvent("Activated")] = function()
				Sounds.play("click")
				props.Look:set(with(Fusion.peek(props.Look), "skin", skin.id))
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = scope:Computed(function(use): Color3
						return if use(props.Look).skin == skin.id then Theme.Brass.Frame else Theme.Paper.Rule
					end),
					Thickness = scope:Computed(function(use): number
						return if use(props.Look).skin == skin.id then Theme.Stroke.Thick else Theme.Stroke.Thin
					end),
				}),
			},
		}) :: GuiObject
		Tooltip.attach(scope, tile, Text.T(scope, "look.skin.n", { n = i }))
		table.insert(tiles, tile)
	end
	return scope:New("Frame")({
		Name = "Tiles",
		Position = UDim2.fromOffset(LABEL, 0),
		Size = UDim2.new(1, -LABEL, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = tiles :: any,
	})
end

local function LookPicker(scope: Scope, props: Props): Instance
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
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			stepper(scope, 1, "look.row.face", props, "face", ClassLooks.FACES, "look.face"),
			scope:New("Frame")({
				Name = "Skin",
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.fromOffset(LABEL, ROW),
						BackgroundTransparency = 1,
						Text = Text.T(scope, "look.row.skin"),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Paper.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					skinTiles(scope, props),
				},
			}),
			stepper(scope, 3, "look.row.hair", props, "hair", ClassLooks.HAIRS, "look.hair"),
			scope:New("Frame")({
				Name = "Buttons",
				LayoutOrder = 4,
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
							local rng = Rng.new(math.floor(os.clock() * 1000) % 2147483647)
							props.Look:set({
								face = rng:pick(ClassLooks.FACES).id,
								skin = rng:pick(ClassLooks.SKINS).id,
								hair = rng:pick(ClassLooks.HAIRS).id,
							})
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
							local d = ClassLooks.DEFAULT_LOOK
							props.Look:set({ face = d.face, skin = d.skin, hair = d.hair })
						end,
					}),
				},
			}),
		},
	})
end

return LookPicker
