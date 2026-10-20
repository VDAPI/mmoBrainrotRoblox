--!strict
-- Player profile (S15): name, class, level, guild, PvP kills/deaths and duels won/lost, and the equipped
-- items with tooltips (inspect). Opened from the player menu (right click or the "⋯" button by the target).
-- S123: a 64 px portrait tile with the player's portrait frame (`frame` of the profile) and the class emblem, left of
-- the name and the level / class / title line.
-- S151b: the achievements section (points, earned / total, the three latest earned with their dates; the profile
-- carries nothing in progress) and, in the own profile, "All" opening the achievements window. The body scrolls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchData = require(ReplicatedStorage.Shared.Data.Achievements)
local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local PortraitFrame = require(script.Parent.Parent.Components.PortraitFrame)
local SectionLabel = require(script.Parent.Parent.Components.SectionLabel)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TitleText = require(script.Parent.Parent.TitleText)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SLOTS = { "weapon", "offhand", "helmet", "armor", "gloves", "boots", "necklace", "ring1", "ring2", "talisman" }
local TILE = 64

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

-- S151b: what the profile may open.
export type Props = { OpenAchievements: (() -> ())? }

local function num(value: any): number
	return if type(value) == "number" and value == value and value >= 0 then math.floor(value) else 0
end

-- S151b: the achievements section (from the profile's `ach`; nothing when it is missing).
local function achievements(s: Scope, use: Fusion.Use, p: any, order: number, props: Props?): { Instance }
	local ach = p.ach
	if type(ach) ~= "table" then
		return {}
	end
	local out: { Instance } = {}
	local function label(text: string, font: Font, color: Color3)
		table.insert(
			out,
			s:New("TextLabel")({
				LayoutOrder = order + #out,
				Size = UDim2.new(1, 0, 0, Theme.TextSize.Body + 8),
				BackgroundTransparency = 1,
				Text = text,
				FontFace = font,
				TextSize = Theme.TextSize.Body,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		)
	end
	table.insert(out, SectionLabel(s, { LayoutOrder = order, Text = Text.get(use, "profile.ach") }))
	label(
		Text.get(use, "profile.ach.points", { points = num(ach.points), done = num(ach.done), total = num(ach.total) }),
		Theme.Fonts.BodyBold,
		Theme.Paper.Heading
	)
	local any = false
	for _, entry in (if type(ach.recent) == "table" then ach.recent else {}) :: { any } do
		local def = if type(entry) == "table" and type(entry.id) == "string" then AchData.get(entry.id) else nil
		if def then
			any = true
			local date = if type(entry.at) == "number" then os.date("%d.%m.%Y", entry.at) :: string else ""
			label(`✪ {Text.get(use, `ach.{def.id}.name`)}  ·  {date}`, Theme.Fonts.BodyMedium, Theme.Paper.Text)
		end
	end
	if not any then
		label(Text.get(use, "profile.ach.none"), Theme.Fonts.Body, Theme.Paper.TextMuted)
	end
	local open = props and props.OpenAchievements
	if open and p.userId == Players.LocalPlayer.UserId then
		table.insert(
			out,
			Button(s, {
				LayoutOrder = order + #out,
				Size = UDim2.fromOffset(200, Theme.Size.MinTouch),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				Text = Text.get(use, "profile.ach.all"),
				OnClick = open,
			})
		)
	end
	return out
end

local function ProfileWindow(scope: Scope, data: Fusion.Value<any>, props: Props?): Fusion.Child
	local content = scope:Computed(function(use, s: Scope): Instance?
		local p = use(data)
		if type(p) ~= "table" then
			return s:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 60),
				BackgroundTransparency = 1,
				Text = Text.get(use, "auction.loading"),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.TextMuted,
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
				FontFace = if size then Theme.Fonts.Display else Theme.Fonts.BodyMedium,
				TextSize = size or Theme.TextSize.Body,
				TextColor3 = color or Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		end
		return s:New("ScrollingFrame")({
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Paper.Label,
			[Children] = {
				s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				s:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
				s:New("Frame")({
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, TILE),
					BackgroundTransparency = 1,
					[Children] = {
						PortraitFrame(s, {
							Name = "Portrait",
							Size = TILE,
							FrameId = if type(p.frame) == "string" then p.frame else nil,
							-- S135: on the dark portrait tile (PortraitFrame), so readable on iron
							ClassColor = if class then Theme.readable(class.color, "iron") else Theme.Iron.Heading,
							Content = ArtIcon(s, {
								Key = if class then UiArt.classEmblem(class.id) else nil,
								Glyph = if class then class.icon else "",
								GlyphColor = if class then Theme.readable(class.color, "iron") else Theme.Iron.Heading,
								ImageScale = 0.8,
								Size = UDim2.fromScale(1, 1),
								Label = { FontFace = Theme.Fonts.BodyBold, TextSize = Theme.TextSize.Title },
							}),
						}),
						s:New("Frame")({
							Position = UDim2.fromOffset(TILE + 12, 0),
							Size = UDim2.new(1, -(TILE + 12), 1, 0),
							BackgroundTransparency = 1,
							[Children] = {
								s:New("UIListLayout")({
									SortOrder = Enum.SortOrder.LayoutOrder,
									VerticalAlignment = Enum.VerticalAlignment.Center,
								}),
								line(1, p.name, Theme.Paper.Heading, Theme.TextSize.Large),
								line(
									2,
									`{Text.get(use, "hud.level", { level = p.level })}  ·  {if class
										then Text.get(use, class.nameKey)
										else p.class}{if p.title and TitleData.get(p.title)
										then "  ·  « " .. TitleText.get(
											use,
											TitleData.get(p.title) :: any,
											p.titleSeason
										) .. " »"
										else ""}`,
									Theme.Paper.Text
								),
							},
						}),
					},
				}),
				line(3, Text.get(use, "profile.guild", { guild = p.guild or Text.get(use, "profile.noGuild") })),
				line(
					4,
					Text.get(use, "profile.pvp", { kills = pvp.kills or 0, deaths = pvp.deaths or 0, ratio = ratio }),
					Theme.Paper.Danger
				),
				line(
					5,
					Text.get(use, "profile.duels", { won = pvp.duelsWon or 0, lost = pvp.duelsLost or 0 }),
					Theme.Paper.Warning
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
				achievements(s, use, p, 10, props) :: any,
			},
		})
	end)
	return content :: any
end

return ProfileWindow
