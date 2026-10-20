--!strict
-- Legendary reveal (DESIGN §5.5): the item in the middle, its name, then the bonuses appear one by one with
-- a sound and their roll quality. "Equip" equips it straight from the backpack, "OK" closes.
-- S134g: the skill effects of the item come after the lines.
-- S30: colours come from the item's rarity; a Mythic item gets the red variant: a darker red backdrop, a
-- rotating red-pink frame, a pulsing icon that grows bigger and a slower, heavier reveal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bonuses = require(ReplicatedStorage.Shared.Data.Bonuses)
local Button = require(script.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.Parent.IconState)
local ItemEffects = require(ReplicatedStorage.Shared.Logic.ItemEffects)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Item: Types.ItemInstance,
	TitleKey: string?, -- S155b: another title (the first valuable drop of a new character)
	OnEquip: (() -> ())?,
	Close: () -> (),
}

local REVEAL_STEP = 0.7
local MYTHIC_STEP = 0.9

local function LegendReveal(scope: Scope, props: Props): Instance
	local item = props.Item
	local def = Items.get(item.id)
	local rarity = Rarities.get(item.rarity)
	local mythic = rarity.id >= Rarities.MYTHIC
	local accent = rarity.color
	local accentText = rarity.textColor -- S136: the rarity's name colour on the parchment card
	local colors = rarity.frame.gradient or { accent, accent }
	local frameGradient = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors[1]),
		ColorSequenceKeypoint.new(0.5, colors[2]),
		ColorSequenceKeypoint.new(1, colors[1]),
	})
	local stats = ItemRoll.itemStats(item)
	local revealed = scope:Value(0)
	local glow = scope:Value(0)
	local animatedGlow = scope:Spring(glow, if mythic then 2.5 else 4, if mythic then 0.3 else 0.4)
	-- Frame rotation and the mythic pulse, only while this window is open.
	local spin = scope:Value(0)
	local pulse = scope:Value(0)
	local clock = 0
	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt: number)
			clock += dt
			spin:set((clock * (if mythic then 140 else 90)) % 360)
			if mythic then
				pulse:set(math.sin(clock * 5) * 0.5 + 0.5)
			end
		end)
	)

	-- S134g: the skill effects come last (Logic/ItemEffects; a named item shows the reader's class's pair)
	local effects = ItemEffects.ofItem(item, State.Get({ "character", "class" }))
	local steps = #stats.bonuses + #effects
	task.spawn(function()
		task.wait(if mythic then 1.0 else 0.6)
		glow:set(1)
		if mythic then
			Sounds.play("levelUp")
		end
		for i = 1, steps do
			task.wait(if mythic then MYTHIC_STEP else REVEAL_STEP)
			revealed:set(i)
			Sounds.play(if i == steps then "levelUp" else "open")
		end
	end)

	local rows = {}
	for i, bonus in stats.bonuses do
		local bonusDef = Bonuses.get(bonus.id)
		-- S62 (STATY 2C): row style from the line's tier.
		local mythic = bonusDef ~= nil and bonusDef.tier == "mythic"
		local legendary = bonusDef ~= nil and bonusDef.tier == "legendary"
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
					return `{text}  <font color="{Theme.hex(Theme.Paper.TextMuted)}">{quality}%</font>`
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = if mythic
					then Rarities.get(Rarities.MYTHIC).textColor
					elseif legendary then Rarities.get(Rarities.LEGENDARY).textColor
					else Theme.Paper.Text,
			})
		)
	end
	for k, effect in effects do
		local i = #stats.bonuses + k
		table.insert(
			rows,
			scope:New("TextLabel")({
				LayoutOrder = 10 + i,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(revealed) >= i
				end),
				RichText = true,
				TextWrapped = true,
				Text = scope:Computed(function(use): string
					local lang = use(Text.Lang)
					local title = Text.get(use, `tooltip.fx.{effect.tier}`, { name = Text.get(use, effect.nameKey) })
					return `<b>{title}</b>\n{ItemEffects.line(effect, lang)}`
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Rarities.get(if effect.tier == "mythic" then Rarities.MYTHIC else Rarities.LEGENDARY).textColor,
			})
		)
	end

	return scope:New("TextButton")({
		Name = "LegendReveal",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = if mythic then Theme.Announce.MythicVeil else Theme.Shade,
		BackgroundTransparency = if mythic then 0.25 else 0.35,
		[Children] = {
			scope:New("Frame")({
				Name = "Panel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(560, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Paper.Surface,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Large }),
					scope:New("UIStroke")({
						Thickness = scope:Computed(function(use): number
							return if mythic then 4 + use(pulse) * 2 else 3
						end),
						Color = Theme.Plain,
						Transparency = scope:Computed(function(use): number
							return 1 - use(animatedGlow) * 0.9
						end),
						[Children] = scope:New("UIGradient")({ Color = frameGradient, Rotation = spin }),
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
						Text = Text.T(
							scope,
							props.TitleKey or (if mythic then "reveal.titleMythic" else "reveal.title")
						),
						FontFace = Theme.Fonts.Display,
						TextSize = if mythic then Theme.TextSize.Title + 6 else Theme.TextSize.Title,
						TextColor3 = accentText,
					}),
					scope:New("Frame")({
						Name = "Icon",
						LayoutOrder = 2,
						Size = scope:Computed(function(use): UDim2
							local s = if mythic
								then 96 + use(animatedGlow) * 40 + use(pulse) * 6
								else 96 + use(animatedGlow) * 24
							return UDim2.fromOffset(s, s)
						end),
						-- S35: the picture sits on the dark panel; the coloured tile only behind the glyph.
						BackgroundColor3 = scope:Computed(function(use): Color3
							if not def or IconState.picture(use, def, ItemRoll.elementOf(item)) ~= nil then
								return Theme.Paper.Surface
							end
							return Theme.tint(def.icon.color)
						end),
						BackgroundTransparency = 0.3,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
							scope:New("UIStroke")({
								Thickness = if mythic then 4 else 3,
								Color = Theme.Plain,
								[Children] = scope:New("UIGradient")({ Color = frameGradient, Rotation = spin }),
							}),
							-- The atlas cell is 128 px: never drawn larger than the frame (<= 142 px).
							ItemIcon(scope, {
								Def = def,
								Element = ItemRoll.elementOf(item),
								Fallback = "?",
								Size = UDim2.fromScale(0.86, 0.86),
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
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Large + 2,
						TextColor3 = accentText,
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
