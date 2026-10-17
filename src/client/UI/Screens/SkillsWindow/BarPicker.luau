--!strict
-- Slot picker for a full bar (S56, moved in S59): 2 x 5 cells with the key and the skill on it over the whole window
-- content (also over the phone sheet); the chosen slot is replaced (PutOnBar with a slot). On touch the cancel button
-- is MinTouch high (S59 F).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local CELL = 64
local GAP = 8

local function BarPicker(
	scope: Scope,
	ctx: Context.Ctx,
	actions: Actions.Actions,
	touch: Fusion.UsedAs<boolean>
): Instance
	local cancelHeight = scope:Computed(function(use): number
		return if use(touch) then Theme.Size.MinTouch else Theme.Size.ButtonHeightSmall
	end)
	local cells: { Instance } = {}
	for index = 1, SkillData.HOTBAR_SLOTS do
		local key = if index == 10 then "0" else tostring(index)
		local glyph = scope:Computed(function(use): string
			local bar = use(ctx.hotbar)
			local id = if type(bar) == "table" then bar[tostring(index)] else nil
			local skill = id and SkillData.get(id)
			return if skill then skill.glyph else ""
		end)
		-- S119: the picture of the skill on that slot once loaded (the glyph otherwise).
		local artKey = scope:Computed(function(use): string?
			local bar = use(ctx.hotbar)
			local id = if type(bar) == "table" then bar[tostring(index)] else nil
			return if id and SkillData.get(id) then UiArt.skill(id) else nil
		end)
		local artShown = ArtIcon.Shown(scope, artKey)
		table.insert(
			cells,
			scope:New("TextButton")({
				Name = `Slot{index}`,
				LayoutOrder = index,
				AutoButtonColor = true,
				BackgroundColor3 = Theme.Paper.Raised,
				Text = "",
				[OnEvent("Activated")] = function()
					actions.place(index)
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = 2,
						Color = Theme.Paper.Rule,
					}),
					ArtIcon.Image(scope, {
						Key = artKey,
						Size = UDim2.fromScale(0.8, 0.8),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Corner = Theme.Corner.Small,
					}),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = scope:Computed(function(use): string
							return if use(artShown) then "" else use(glyph)
						end),
						TextScaled = true,
						FontFace = Theme.Fonts.BodyBold,
						TextColor3 = Theme.Paper.Text,
						[Children] = scope:New("UIPadding")({
							PaddingTop = UDim.new(0.2, 0),
							PaddingBottom = UDim.new(0.2, 0),
							PaddingLeft = UDim.new(0.2, 0),
							PaddingRight = UDim.new(0.2, 0),
						}),
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(4, 2),
						Size = UDim2.fromOffset(20, 18),
						BackgroundTransparency = 1,
						Text = key,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Caption,
						TextColor3 = Theme.Paper.Heading,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			})
		)
	end
	local gridWidth = 5 * CELL + 4 * GAP
	return scope:New("TextButton")({
		Name = "Picker",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Paper.Sunken,
		BackgroundTransparency = 0.25,
		Text = "",
		ZIndex = 20,
		Visible = scope:Computed(function(use): boolean
			return use(ctx.picking) ~= nil
		end),
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(gridWidth + 32, 2 * CELL + GAP + 40 + use(cancelHeight) + 48)
				end),
				BackgroundColor3 = Theme.Paper.Raised,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					scope:New("UIStroke")({ Color = Theme.Paper.Rule, Thickness = 2 }),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(16, 12),
						Size = UDim2.new(1, -32, 0, 32),
						BackgroundTransparency = 1,
						Text = Text.T(scope, "skills.pick.title"),
						TextWrapped = true,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Heading,
					}),
					scope:New("Frame")({
						Position = UDim2.fromOffset(16, 52),
						Size = UDim2.fromOffset(gridWidth, 2 * CELL + GAP),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIGridLayout")({
								CellSize = UDim2.fromOffset(CELL, CELL),
								CellPadding = UDim2.fromOffset(GAP, GAP),
								FillDirectionMaxCells = 5,
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							cells :: any,
						},
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.new(0.5, 0, 1, -12),
						Size = scope:Computed(function(use): UDim2
							return UDim2.fromOffset(160, use(cancelHeight))
						end),
						Variant = "ghost",
						TextSize = Theme.TextSize.Small,
						Text = Text.T(scope, "common.cancel"),
						OnClick = function()
							ctx.picking:set(nil)
						end,
					}),
				},
			}),
		},
	})
end

return BarPicker
