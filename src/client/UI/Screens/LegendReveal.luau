--!strict
-- Legendary reveal (DESIGN §5.5): the item in the middle, its name, then the bonuses appear one by one with
-- a sound and their roll quality. "Equip" equips it straight from the backpack, "OK" closes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bonuses = require(ReplicatedStorage.Shared.Data.Bonuses)
local Button = require(script.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Sounds = require(script.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Item: Types.ItemInstance,
	OnEquip: (() -> ())?,
	Close: () -> (),
}

local REVEAL_STEP = 0.7
local LEGEND = Color3.fromHex("#FF9F1C")

local function LegendReveal(scope: Scope, props: Props): Instance
	local item = props.Item
	local def = Items.get(item.id)
	local stats = ItemRoll.itemStats(item)
	local revealed = scope:Value(0)
	local glow = scope:Value(0)
	local animatedGlow = scope:Spring(glow, 4, 0.4)

	task.spawn(function()
		task.wait(0.6)
		glow:set(1)
		for i = 1, #stats.bonuses do
			task.wait(REVEAL_STEP)
			revealed:set(i)
			Sounds.play(if i == #stats.bonuses then "levelUp" else "open")
		end
	end)

	local rows = {}
	for i, bonus in stats.bonuses do
		local bonusDef = Bonuses.get(bonus.id)
		local legendary = bonusDef ~= nil and (bonusDef.hook ~= nil or string.sub(bonus.id, 1, 4) == "leg_")
		table.insert(
			rows,
			scope:New("TextLabel")({
				LayoutOrder = 10 + i,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(revealed) >= i
				end),
				RichText = true,
				Text = scope:Computed(function(use): string
					local decimals = if bonusDef then bonusDef.decimals else 0
					local v = if decimals == 0
						then tostring(math.floor(bonus.v + 0.5))
						else string.format(`%.{decimals}f`, bonus.v)
					local text = Text.get(use, `bonus.{bonus.id}`, { v = v })
					local quality = math.floor(bonus.quality * 100 + 0.5)
					return `{text}  <font color="#9A9DA8">{quality}%</font>`
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = if legendary then LEGEND else Theme.Colors.Text,
			})
		)
	end

	return scope:New("TextButton")({
		Name = "LegendReveal",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		[Children] = {
			scope:New("Frame")({
				Name = "Panel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(560, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Panel,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Large }),
					scope:New("UIStroke")({
						Thickness = 3,
						Color = LEGEND,
						Transparency = scope:Computed(function(use): number
							return 1 - use(animatedGlow) * 0.9
						end),
					}),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, Theme.Padding.Large),
						PaddingBottom = UDim.new(0, Theme.Padding.Large),
						PaddingLeft = UDim.new(0, Theme.Padding.Large),
						PaddingRight = UDim.new(0, Theme.Padding.Large),
					}),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, Theme.Padding.Small),
					}),
					scope:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundTransparency = 1,
						Text = Text.T(scope, "reveal.title"),
						FontFace = Theme.Fonts.Heading,
						TextSize = Theme.TextSize.Title,
						TextColor3 = LEGEND,
					}),
					scope:New("Frame")({
						Name = "Icon",
						LayoutOrder = 2,
						Size = scope:Computed(function(use): UDim2
							local s = 96 + use(animatedGlow) * 24
							return UDim2.fromOffset(s, s)
						end),
						BackgroundColor3 = if def then Color3.fromHex(def.icon.color) else Theme.Colors.Panel,
						BackgroundTransparency = 0.3,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
							scope:New("UIStroke")({ Thickness = 3, Color = LEGEND }),
							scope:New("TextLabel")({
								BackgroundTransparency = 1,
								Size = UDim2.fromScale(1, 1),
								Text = if def then def.icon.glyph else "?",
								TextScaled = true,
								FontFace = Theme.Fonts.BodyBold,
								TextColor3 = Theme.Colors.Text,
							}),
						},
					}),
					scope:New("TextLabel")({
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return ItemText.get(use, item.id, item.up)
						end),
						FontFace = Theme.Fonts.Heading,
						TextSize = Theme.TextSize.Large + 2,
						TextColor3 = LEGEND,
					}),
					rows :: any,
					scope:New("Frame")({
						Name = "Buttons",
						LayoutOrder = 100,
						Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
						BackgroundTransparency = 1,
						Visible = scope:Computed(function(use): boolean
							return use(revealed) >= #stats.bonuses
						end),
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, Theme.Padding.Medium),
							}),
							if props.OnEquip
								then Button(scope, {
									Text = Text.T(scope, "reveal.equip"),
									Variant = "primary",
									Size = UDim2.fromOffset(200, Theme.Size.ButtonHeight),
									OnClick = function()
										local equip = props.OnEquip :: () -> ()
										props.Close()
										equip()
									end,
								}) :: any
								else nil,
							Button(scope, {
								Text = Text.T(scope, "reveal.ok"),
								Variant = "secondary",
								Size = UDim2.fromOffset(160, Theme.Size.ButtonHeight),
								OnClick = props.Close,
							}),
						},
					}),
				},
			}),
		},
	})
end

return LegendReveal
