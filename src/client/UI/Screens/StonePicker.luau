--!strict
-- Destination picker for the Map Stone (visited maps) and the generic Dungeon Stone (boss dungeons).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Index: Fusion.UsedAs<number?>,
	Kind: Fusion.UsedAs<string>, -- "map" | "dungeon"
	Close: () -> (),
	-- S22: region maps hand over to the area picker; returns true when it took over.
	PickArea: ((mapId: string, index: number) -> boolean)?,
}

type Choice = { id: string, label: string, sub: string }

local function StonePicker(scope: Scope, props: Props): Fusion.Child
	local visited = State.Value({ "character", "visitedMaps" })
	local currentMap = State.Value({ "character", "location", "map" })

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local choices: { Choice } = {}
		if use(props.Kind) == "dungeon" then
			for _, dungeon in Recipes.dungeons do
				table.insert(choices, {
					id = dungeon.region,
					label = Text.get(use, `dungeon.{dungeon.region}`),
					sub = Text.get(use, "tooltip.requiresLevel", { level = dungeon.level - 5 }),
				})
			end
		else
			for mapId in (use(visited) or {}) :: { [string]: boolean } do
				local map = Maps.get(mapId)
				if map then
					table.insert(choices, {
						id = mapId,
						label = Text.get(use, map.nameKey),
						sub = if mapId == use(currentMap)
							then Text.get(use, "teleport.here")
							else `{map.minLevel}–{map.maxLevel}`,
					})
				end
			end
			table.sort(choices, function(a, b)
				return a.label < b.label
			end)
		end
		local list = {}
		for i, choice in choices do
			table.insert(
				list,
				Button(s, {
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 56),
					Text = `{choice.label}   ·   {choice.sub}`,
					OnClick = function()
						local index = Fusion.peek(props.Index)
						if not index then
							return
						end
						if Fusion.peek(props.Kind) == "map" and props.PickArea and props.PickArea(choice.id, index) then
							return
						end
						task.spawn(function()
							local ok, err = Net.Invoke("UseMapStone", index, choice.id)
							if ok then
								Sounds.play("click")
								props.Close()
							else
								Sounds.play("error")
								Toast.push(Text.now(err or "error.internal"), "error")
							end
						end)
					end,
				})
			)
		end
		if #list == 0 then
			table.insert(
				list,
				s:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 40),
					BackgroundTransparency = 1,
					Text = Text.get(use, "teleport.noMaps"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.TextMuted,
				})
			)
		end
		return list
	end)

	return {
		scope:New("ScrollingFrame")({
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
				rows :: any,
			},
		}),
	}
end

return StonePicker
