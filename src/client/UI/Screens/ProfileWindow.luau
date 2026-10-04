--!strict
-- Player profile (S15): name, class, level, guild, PvP kills/deaths and duels won/lost, and the equipped
-- items with tooltips (inspect). Opened from the player menu (right click or the "⋯" button by the target).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SLOTS = { "weapon", "offhand", "helmet", "armor", "gloves", "boots", "necklace", "ring1", "ring2", "talisman" }
local GLYPHS: { [string]: string } = {
	weapon = "⚔",
	offhand = "⛨",
	helmet = "⛑",
	armor = "♜",
	gloves = "✋",
	boots = "⛸",
	necklace = "◎",
	ring1 = "○",
	ring2 = "○",
	talisman = "✧",
}

local function ProfileWindow(scope: Scope, data: Fusion.Value<any>): Fusion.Child
	local content = scope:Computed(function(use, s: Scope): Instance?
		local p = use(data)
		if type(p) ~= "table" then
			return s:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 60),
				BackgroundTransparency = 1,
				Text = Text.get(use, "auction.loading"),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.TextMuted,
			})
		end
		local class = Classes.get(p.class)
		local pvp = p.pvp or {}
		local ratio = if (pvp.deaths or 0) > 0
			then string.format("%.2f", (pvp.kills or 0) / pvp.deaths)
			else tostring(pvp.kills or 0)
		local slots = {}
		for i, slot in SLOTS do
			table.insert(
				slots,
				ItemSlot(s, {
					SlotId = `view:profile:{slot}`,
					Item = p.equipment[slot],
					Size = 64,
					LayoutOrder = i,
					Placeholder = GLYPHS[slot],
					EmptyTooltip = Text.get(use, `slot.{slot}`),
				})
			)
		end
		local function line(order: number, text: string, color: Color3?, size: number?): Instance
			return s:New("TextLabel")({
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, (size or Theme.TextSize.Body) + 10),
				BackgroundTransparency = 1,
				Text = text,
				FontFace = if size then Theme.Fonts.Heading else Theme.Fonts.BodyMedium,
				TextSize = size or Theme.TextSize.Body,
				TextColor3 = color or Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		end
		return s:New("Frame")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			[Children] = {
				s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				line(
					1,
					`{if class then class.icon .. " " else ""}{p.name}`,
					Theme.Colors.GoldBright,
					Theme.TextSize.Title
				),
				line(
					2,
					`{Text.get(use, "hud.level", { level = p.level })}  ·  {if class
						then Text.get(use, class.nameKey)
						else p.class}`,
					Theme.Colors.Parchment
				),
				line(3, Text.get(use, "profile.guild", { guild = p.guild or Text.get(use, "profile.noGuild") })),
				line(
					4,
					Text.get(use, "profile.pvp", { kills = pvp.kills or 0, deaths = pvp.deaths or 0, ratio = ratio }),
					Theme.Colors.ZoneRed
				),
				line(
					5,
					Text.get(use, "profile.duels", { won = pvp.duelsWon or 0, lost = pvp.duelsLost or 0 }),
					Theme.Colors.Warning
				),
				s:New("Frame")({
					LayoutOrder = 6,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = {
						s:New("UIGridLayout")({
							CellSize = UDim2.fromOffset(64, 64),
							CellPadding = UDim2.fromOffset(8, 8),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						slots :: any,
					},
				}),
			},
		})
	end)
	return content :: any
end

return ProfileWindow
