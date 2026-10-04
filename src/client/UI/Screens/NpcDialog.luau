--!strict
-- NPC conversation window: portrait (placeholder icon), name, greeting and one button per service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	NpcId: Fusion.UsedAs<string?>,
	OnService: (service: string) -> (),
}

local function NpcDialog(scope: Scope, props: Props): Fusion.Child
	local def = scope:Computed(function(use): Npcs.NpcDef?
		local id = use(props.NpcId)
		return if id then Npcs.get(id) else nil
	end)

	return {
		scope:New("Frame")({
			Name = "Portrait",
			Size = UDim2.fromOffset(110, 110),
			BackgroundColor3 = scope:Computed(function(use): Color3
				local d = use(def)
				return if d then Color3.fromHex(d.colors.body) else Theme.Colors.Panel
			end),
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Large }),
				scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 3 }),
				scope:New("TextLabel")({
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = scope:Computed(function(use): string
						local d = use(def)
						return if d then d.icon else ""
					end),
					TextScaled = true,
					FontFace = Theme.Fonts.BodyBold,
					TextColor3 = Theme.Colors.Text,
					[Children] = scope:New("UIPadding")({
						PaddingTop = UDim.new(0.2, 0),
						PaddingBottom = UDim.new(0.2, 0),
						PaddingLeft = UDim.new(0.2, 0),
						PaddingRight = UDim.new(0.2, 0),
					}),
				}),
			},
		}),
		scope:New("TextLabel")({
			Name = "Name",
			Position = UDim2.fromOffset(126, 0),
			Size = UDim2.new(1, -126, 0, 34),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local d = use(def)
				return if d then Text.get(use, d.nameKey) else ""
			end),
			FontFace = Theme.Fonts.Heading,
			TextSize = Theme.TextSize.Title,
			TextColor3 = Theme.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("TextLabel")({
			Name = "Greeting",
			Position = UDim2.fromOffset(126, 40),
			Size = UDim2.new(1, -126, 0, 70),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local d = use(def)
				return if d then `“{Text.get(use, d.greetingKey)}”` else ""
			end),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Colors.Parchment,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		scope:New("Frame")({
			Name = "Services",
			Position = UDim2.fromOffset(0, 130),
			Size = UDim2.new(1, 0, 1, -130),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, Theme.Padding.Small),
				}),
				scope:Computed(function(use, s: Scope): { Instance }
					local d = use(def)
					local list = {}
					if d then
						for i, service in d.services do
							table.insert(
								list,
								Button(s, {
									LayoutOrder = i,
									Text = Text.T(s, `npc.service.{service}`),
									Variant = if i == 1 then "primary" else "secondary",
									Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
									OnClick = function()
										props.OnService(service)
									end,
								})
							)
						end
					end
					return list
				end) :: any,
			},
		}),
	}
end

return NpcDialog
