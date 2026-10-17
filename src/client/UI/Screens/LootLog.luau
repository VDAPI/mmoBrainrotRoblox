--!strict
-- Loot log window (S20, DESIGN §5.9): the last 50 items from character.lootLog, opened from the backpack.
-- S136: moved out of LootComfortController so the window checklist (Data/UiWindows) sees the file; on parchment,
-- one ListRow per entry (item name in its rarity colour, time and source as the second line).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.ItemText)
local ListRow = require(script.Parent.Parent.Components.ListRow)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function timeAgo(at: number): string
	local seconds = math.max(0, os.time() - at)
	if seconds < 3600 then
		return `{math.floor(seconds / 60)} min`
	elseif seconds < 86400 then
		return `{math.floor(seconds / 3600)} h`
	end
	return `{math.floor(seconds / 86400)} d`
end

local function LootLog(scope: Scope): Fusion.Child
	local log = State.Value({ "character", "lootLog" })
	return scope:New("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Rule,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
			scope:Computed(function(use, s: Scope): { Instance }
				local list = use(log)
				local rows = {}
				if type(list) ~= "table" or #list == 0 then
					table.insert(
						rows,
						s:New("TextLabel")({
							Size = UDim2.new(1, 0, 0, Theme.Size.RowHeight),
							BackgroundTransparency = 1,
							Text = Text.get(use, "lootlog.empty"),
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Body,
							TextColor3 = Theme.Paper.TextMuted,
						})
					)
					return rows
				end
				for i, entry in list do
					local monster = entry.src and Monsters.get(entry.src)
					local map = entry.map and Maps.get(entry.map)
					local source = if monster then Text.get(use, monster.nameKeys.normal) else ""
					if map then
						source = if source ~= ""
							then `{source}, {Text.get(use, map.nameKey)}`
							else Text.get(use, map.nameKey)
					end
					local name = ItemText.get(use, entry.id, nil, entry.el)
					local colour = Theme.hex(ItemText.rarityName(entry.rarity or 1, "paper"))
					table.insert(
						rows,
						ListRow(s, {
							LayoutOrder = i,
							Index = i,
							Height = Theme.Size.RowHeight + 8,
							RichText = true,
							Text = `<font color="{colour}">{name}</font> ({entry.ilvl or 1})`,
							Sub = Text.get(use, "lootlog.sub", { time = timeAgo(entry.at or 0), source = source }),
						})
					)
				end
				return rows
			end) :: any,
		},
	})
end

return LootLog
