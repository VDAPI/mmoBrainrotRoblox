--!strict
-- The 3v3 team panel on the HUD (S128, DESIGN-17 §6), only in a team match (`arenaLive.match.teams`, refreshed by the
-- server at most 4 times a second): two columns, the own team on the left (green-gold) and the opponents on the right
-- (red); a row = the class sign, the name and an HP bar, a knocked out fighter greyed with "defeated". On a phone the
-- panel folds to two rows of dots (3 + 3) coloured by HP and opens with a tap (44 px). The match timer and the potions
-- stay in UI/Screens/Hud/ArenaPanel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {}

local WIDTH = 360
local ROW = 30
local ALLY = Color3.fromHex("#B8C85A")
local ENEMY = Color3.fromHex("#C2352E")

local function hpColor(pct: number): Color3
	if pct > 0.5 then
		return Theme.Colors.Success
	elseif pct > 0.2 then
		return Theme.Colors.Warning
	end
	return Theme.Colors.Hp
end

local function row(s: Scope, order: number, f: any, accent: Color3): Instance
	local out = f.out == true
	local maxHp = math.max(1, tonumber(f.maxHp) or 1)
	local pct = math.clamp((tonumber(f.hp) or 0) / maxHp, 0, 1)
	local class = Classes.get(f.class)
	return s:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundTransparency = 1,
		[Children] = {
			ArtIcon(s, {
				Key = UiArt.classEmblem(f.class),
				Glyph = if class then class.icon else "◆",
				GlyphColor = if out then Theme.Colors.TextMuted else accent,
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.fromOffset(0, 4),
				Transparency = if out then 0.5 else 0,
			}) :: any,
			s:New("TextLabel")({
				Position = UDim2.fromOffset(26, 0),
				Size = UDim2.new(1, -26, 0, 16),
				BackgroundTransparency = 1,
				Text = if out then `{f.name} · {Text.now("arena.team.outMark")}` else f.name,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = if out then Theme.Colors.TextMuted else Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			s:New("Frame")({
				Position = UDim2.fromOffset(26, 19),
				Size = UDim2.new(1, -26, 0, 7),
				BackgroundColor3 = Theme.Colors.PanelRaised,
				[Children] = {
					s:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					s:New("Frame")({
						Size = UDim2.fromScale(if out then 0 else pct, 1),
						BackgroundColor3 = hpColor(pct),
						[Children] = { s:New("UICorner")({ CornerRadius = Theme.Corner.Round }) },
					}),
				},
			}),
		} :: any,
	})
end

local function column(s: Scope, order: number, titleKey: string, list: { any }, accent: Color3): Instance
	local children: { any } = {
		s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
		s:New("TextLabel")({
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = Text.now(titleKey),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	}
	for i, f in list do
		table.insert(children, row(s, i, f, accent))
	end
	return s:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.new(0.5, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = children,
	})
end

local function ArenaTeams(scope: Scope, _props: Props): Instance
	local live = State.Value({ "arenaLive" })
	local open = scope:Value(false) -- the phone's folded panel
	local teams = scope:Computed(function(use): any
		local value = use(live)
		local m = if type(value) == "table" then value.match else nil
		if type(m) ~= "table" or type(m.teams) ~= "table" or m.phase == "done" then
			return nil
		end
		return m
	end)
	local body = scope:Computed(function(use, s: Scope): any
		local m = use(teams)
		if not m then
			return {}
		end
		use(Text.Lang)
		local mine = tonumber(m.myTeam) or 1
		local other = if mine == 1 then 2 else 1
		local ours = m.teams[mine] or {}
		local theirs = m.teams[other] or {}
		if use(Device.Touch) and not use(open) then
			-- folded: two rows of dots by HP
			local dots: { any } = {
				s:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 6),
				}),
			}
			local n = 0
			for side, list in { ours, theirs } do
				for _, f in list do
					n += 1
					local pct = math.clamp((tonumber(f.hp) or 0) / math.max(1, tonumber(f.maxHp) or 1), 0, 1)
					table.insert(
						dots,
						s:New("Frame")({
							LayoutOrder = n + (side - 1) * 10,
							Size = UDim2.fromOffset(14, 14),
							BackgroundColor3 = if f.out then Theme.Colors.TextMuted else hpColor(pct),
							[Children] = {
								s:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
								s:New("UIStroke")({ Color = if side == 1 then ALLY else ENEMY, Thickness = 2 }),
							},
						})
					)
				end
				if side == 1 then
					table.insert(
						dots,
						s:New("TextLabel")({
							LayoutOrder = 9,
							Size = UDim2.fromOffset(16, 14),
							BackgroundTransparency = 1,
							Text = "⚔",
							TextColor3 = Theme.Colors.Gold,
							TextSize = Theme.TextSize.Small,
						})
					)
				end
			end
			return dots
		end
		return {
			s:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 12),
			}),
			column(s, 1, "arena.team.ally", ours, ALLY),
			column(s, 2, "arena.team.enemy", theirs, ENEMY),
		}
	end)

	return scope:New("TextButton")({
		Name = "ArenaTeams",
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 150),
		Size = scope:Computed(function(use): UDim2
			return if use(Device.Touch) and not use(open)
				then UDim2.fromOffset(150, Theme.Size.MinTouch)
				else UDim2.fromOffset(WIDTH, 0)
		end),
		AutomaticSize = scope:Computed(function(use): Enum.AutomaticSize
			return if use(Device.Touch) and not use(open) then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
		end),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = scope:Computed(function(use): boolean
			return use(teams) ~= nil
		end),
		[OnEvent("Activated")] = function()
			if Fusion.peek(Device.Touch) then
				open:set(not Fusion.peek(open))
			end
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 1 }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("Frame")({
				Name = "Body",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = body :: any,
			}),
		},
	})
end

return ArenaTeams
