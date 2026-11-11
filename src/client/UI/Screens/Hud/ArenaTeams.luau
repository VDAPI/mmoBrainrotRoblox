--!strict
-- The 3v3 team panel on the HUD (S128, DESIGN-17 §6), only in a team match (`arenaLive.match.teams`, refreshed by the
-- server at most 4 times a second): two columns, the own team on the left (green-gold) and the opponents on the right
-- (red); a row = the class sign, the name and an HP bar, a knocked out fighter greyed with "defeated". On a phone the
-- panel folds to two rows of dots (3 + 3) coloured by HP and opens with a tap (44 px). The match timer and the potions
-- stay in UI/Screens/Hud/ArenaPanel.
-- Owner 2026-11-10 (UI plan package A): the panel joins the HUD column as "arena" (Logic/HudStack: it stood at a fixed
-- place over the column's panels), and on every device it folds to its line of dots (Hud/PanelHeader's height) with a
-- click: the account's fold "hudArena" (Data/Folds/Hud: open on PC, folded on a phone; it replaced the touch screens'
-- own fold), or the column's while it has no room (UI/HudSlots.forced).
-- Final UI review 2026-11-10: out of sight while an open window covers it (UI/HudCover.bind), keeping its slot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudCover = require(script.Parent.Parent.Parent.HudCover)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local PanelHeader = require(script.Parent.PanelHeader)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local Section = require(script.Parent.Parent.Parent.Components.Section)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {}

local WIDTH = 360
local ROW = 30
local TITLE = 18 -- a column's title over its rows (4 apart)
local PAD = 6
local ALLY = Theme.Glyph.Ally
local ENEMY = Theme.Glyph.Enemy

local function hpColor(pct: number): Color3
	if pct > 0.5 then
		return Theme.Iron.Success
	elseif pct > 0.2 then
		return Theme.Iron.Warning
	end
	return Theme.Resource.Hp
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
				GlyphColor = if out then Theme.Iron.TextMuted else accent,
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
				TextColor3 = if out then Theme.Iron.TextMuted else Theme.Iron.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			s:New("Frame")({
				Position = UDim2.fromOffset(26, 19),
				Size = UDim2.new(1, -26, 0, 7),
				BackgroundColor3 = Theme.Iron.Raised,
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
			TextColor3 = Theme.readable(Theme.hex(accent), "hud"),
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
	-- folded by the player (on the account) or by the column (no room)
	local open = Section.state(scope, "hudArena")
	local forced = HudSlots.forced(scope, "arena")
	local folded = scope:Computed(function(use): boolean
		return not use(open) or use(forced)
	end)
	local header = PanelHeader.Height(scope)
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
		if use(folded) then
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
							BackgroundColor3 = if f.out then Theme.Iron.Rule else hpColor(pct),
							[Children] = {
								s:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
								s:New("UIStroke")({
									Color = if side == 1 then ALLY else ENEMY,
									Thickness = Theme.Stroke.Normal,
								}),
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
							TextColor3 = Theme.Iron.Heading,
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

	-- the column's box: one line of dots folded, both columns open (a title and up to three rows each)
	local width = scope:Computed(function(use): number
		return if use(PhoneLayout.Compact) then PhoneHud.PANEL_WIDTH else WIDTH
	end)
	-- Package A review (owner 2026-11-10): the column hears the player's own fold only (`open`; it folds a box to its
	-- line itself, and a box built from its fold fed the column back: a Fusion loop that left it with an old height);
	-- what is drawn folds with the column too (`folded`).
	local function heightOf(use: Fusion.Use, shut: boolean): number
		if shut then
			return use(header)
		end
		local m = use(teams)
		local n = 0
		if m then
			for _, list in m.teams do
				n = math.max(n, #list)
			end
		end
		return PAD * 2 + TITLE + n * (ROW + 4)
	end
	local height = scope:Computed(function(use): number
		return heightOf(use, use(folded))
	end)
	local shown = scope:Computed(function(use): boolean
		return use(teams) ~= nil
	end)
	local slot = HudSlots.join(
		scope,
		"arena",
		scope:Computed(function(use): HudSlots.Box
			return { shown = use(shown), w = use(width), h = heightOf(use, not use(open)), line = use(header) }
		end)
	)

	local root = scope:New("TextButton")({
		Name = "ArenaTeams",
		AutoButtonColor = false,
		Text = "",
		Position = HudSlots.position(scope, slot),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(use(width), use(height))
		end),
		ClipsDescendants = true,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		[OnEvent("Activated")] = function()
			if Fusion.peek(forced) then
				-- the column folded it: it stays open in the column before the others
				HudSlots.bring("arena")
				Section.set("hudArena", true)
				return
			end
			Section.set("hudArena", not Fusion.peek(open))
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, PAD),
				PaddingBottom = UDim.new(0, PAD),
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
	}) :: TextButton
	-- package A: not while it waits behind the column's '+N' chip; final UI review 2026-11-10: nor while an open window
	-- covers it
	HudCover.bind(scope, root, HudSlots.visible(scope, slot, shown))
	return root
end

return ArenaTeams
