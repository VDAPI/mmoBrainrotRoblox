--!strict
-- Party member frames (DESIGN §17, left side under the portrait): name, class glyph, level, HP and mana,
-- leader crown, "far" when on another map or beyond 80 studs. Clicking a frame targets the member (heals).
-- Owner 2026-11-10 ("things covering each other"; UI plan package A): on a phone the party is one line of the stack
-- ("party", UI/HudSlots, Logic/PhoneHud): at most TILES tiles of 52 px (the class sign over an HP strip; a tap targets
-- the member, as on PC), then "+N" for the rest; the four rows of 58 px ran into the stack's panels.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudSlots = require(script.Parent.Parent.HudSlots)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local PathBadge = require(script.Parent.Parent.Components.PathBadge)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.UiArtState)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local FAR = 80
local WIDTH = 260
local HEIGHT = 58
-- a phone's strip: tiles of one stack line, 6 apart, and the "+N" tile
local TILES = 3
local TILE = PhoneHud.LINE
local TILE_GAP = 6
local STRIP = TILES * TILE + TILES * TILE_GAP + 44

local LEADER_ART = UiArt.hud("party_leader") -- S119
local DEAD_ART = UiArt.hud("dead")

local function PartyFrames(scope: Scope, onSelect: (userId: number) -> ()): Instance
	local party = State.Value({ "party" })
	local myMap = State.Value({ "character", "location", "map" })
	local me = Players.LocalPlayer

	local frames = scope:Computed(function(use, s: Scope): { Instance }
		local p = use(party)
		local list = {}
		if type(p) ~= "table" then
			return list
		end
		local myRoot = me.Character and me.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if use(PhoneLayout.Compact) then
			-- package A: a phone's strip of tiles and "+N"
			local shown = 0
			local more = 0
			for _, member in p.members do
				if member.id == me.UserId then
					continue
				end
				if shown >= TILES then
					more += 1
					continue
				end
				shown += 1
				local class = Classes.get(member.class)
				local hpRatio = math.clamp(member.hp / math.max(1, member.maxHp), 0, 1)
				table.insert(
					list,
					s:New("TextButton")({
						Name = member.name,
						LayoutOrder = shown,
						Size = UDim2.fromOffset(TILE, TILE),
						BackgroundColor3 = Theme.Iron.Surface,
						BackgroundTransparency = Theme.HudAlpha,
						AutoButtonColor = true,
						Text = if class then class.icon else "◆",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = if class then Theme.tint(class.color) else Theme.Iron.Text,
						[OnEvent("Activated")] = function()
							onSelect(member.id)
						end,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							s:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = if member.id == p.leader then Theme.Brass.Bright else Theme.Brass.Line,
								Thickness = Theme.Stroke.Thin,
							}),
							s:New("Frame")({
								Name = "Hp",
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.new(0, 4, 1, -4),
								Size = UDim2.new(hpRatio, -8 * hpRatio, 0, 5),
								BackgroundColor3 = Theme.Resource.Hp,
								BorderSizePixel = 0,
							}),
						},
					})
				)
			end
			if more > 0 then
				table.insert(
					list,
					s:New("TextLabel")({
						Name = "More",
						LayoutOrder = TILES + 1,
						Size = UDim2.fromOffset(44, TILE),
						BackgroundColor3 = Theme.Iron.Raised,
						BackgroundTransparency = Theme.HudAlpha,
						Text = `+{more}`,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Iron.Text,
						[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					})
				)
			end
			return list
		end
		local leaderArt = UiArtState.ready(use, LEADER_ART)
		local deadArt = UiArtState.ready(use, DEAD_ART)
		local order = 0
		for _, member in p.members do
			if member.id ~= me.UserId then
				order += 1
				local class = Classes.get(member.class)
				local far = member.map ~= use(myMap)
					or (
						myRoot ~= nil
						and Vector2.new(member.x - myRoot.Position.X, member.z - myRoot.Position.Z).Magnitude > FAR
					)
				local hpRatio = math.clamp(member.hp / math.max(1, member.maxHp), 0, 1)
				local manaRatio = math.clamp(member.mana / math.max(1, member.maxMana), 0, 1)
				table.insert(
					list,
					s:New("TextButton")({
						Name = member.name,
						LayoutOrder = order,
						Size = UDim2.fromOffset(WIDTH, HEIGHT),
						BackgroundColor3 = Theme.Iron.Surface,
						BackgroundTransparency = if far then 0.45 else Theme.HudAlpha,
						AutoButtonColor = true,
						Text = "",
						[OnEvent("Activated")] = function()
							onSelect(member.id)
						end,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							s:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = if member.id == p.leader then Theme.Brass.Bright else Theme.Brass.Line,
								Thickness = Theme.Stroke.Thin,
							}),
							-- S119: class emblem once loaded (glyph otherwise).
							ArtIcon(s, {
								Key = if class then UiArt.classEmblem(class.id) else nil,
								Glyph = if class then class.icon else "?",
								GlyphColor = Theme.Brass.Bright,
								Position = UDim2.fromOffset(6, 6),
								Size = UDim2.fromOffset(28, 28),
								Label = { TextScaled = true, FontFace = Theme.Fonts.BodyBold },
							}),
							PathBadge.new(s, use, member.path, 14, UDim2.fromOffset(22, 22)) :: any,
							-- S119: leader crown and death skull as badges on the class emblem once loaded (out of the
							-- name line, which then keeps its place; the bars do not move).
							if member.id == p.leader and leaderArt
								then ArtIcon.Image(s, {
									Key = LEADER_ART,
									Tint = Theme.Brass.Bright,
									Size = UDim2.fromOffset(14, 14),
									Position = UDim2.fromOffset(2, 2),
									ZIndex = 3,
								}) :: any
								else nil,
							if member.dead and deadArt
								then ArtIcon.Image(s, {
									Key = DEAD_ART,
									Tint = Theme.Iron.Danger,
									Size = UDim2.fromOffset(22, 22),
									Position = UDim2.fromOffset(9, 9),
									ZIndex = 3,
								}) :: any
								else nil,
							s:New("TextLabel")({
								Position = UDim2.fromOffset(40, 4),
								Size = UDim2.new(1, -46, 0, 20),
								BackgroundTransparency = 1,
								Text = `{if member.id == p.leader and not leaderArt then "♛ " else ""}{member.name} · {member.level}{if member.dead
									then (if deadArt then "" else " ☠")
									elseif far then ` · {Text.get(use, "party.far")}`
									else ""}`,
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Small,
								TextColor3 = if member.dead then Theme.Iron.Danger else Theme.Iron.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),
							s:New("Frame")({
								Position = UDim2.fromOffset(40, 28),
								Size = UDim2.new(1, -48, 0, 12),
								BackgroundColor3 = Theme.Iron.Sunken,
								[Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
									s:New("Frame")({
										Size = UDim2.fromScale(hpRatio, 1),
										BackgroundColor3 = Theme.Resource.Hp,
										[Children] = s:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
									}),
								},
							}),
							s:New("Frame")({
								Position = UDim2.fromOffset(40, 43),
								Size = UDim2.new(1, -48, 0, 8),
								BackgroundColor3 = Theme.Iron.Sunken,
								[Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
									s:New("Frame")({
										Size = UDim2.fromScale(manaRatio, 1),
										BackgroundColor3 = Theme.Resource.Mana,
										[Children] = s:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
									}),
								},
							}),
						},
					})
				)
			end
		end
		return list
	end)

	-- package A: a phone's strip is the first line of the stack
	local others = PhoneLayout.Others
	local slot = HudSlots.join(
		scope,
		"party",
		scope:Computed(function(use): HudSlots.Box
			return { shown = use(PhoneLayout.Compact) and use(others) > 0, w = STRIP, h = TILE, line = TILE }
		end)
	)
	local stripAt = HudSlots.position(scope, slot)
	return scope:New("Frame")({
		Name = "PartyFrames",
		Position = PhoneLayout.Pick(
			scope,
			stripAt,
			-- UI plan phase 4: where Logic/HudStack's touch column makes room for them, under the portrait's effects
			UDim2.fromOffset(HudStack.MARGIN, HudStack.PARTY_TOP)
		),
		Size = PhoneLayout.Pick(scope, UDim2.fromOffset(STRIP, TILE), UDim2.fromOffset(WIDTH, 4 * (HEIGHT + 6))),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return not use(PhoneLayout.Compact) or use(slot) ~= nil
		end),
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = PhoneLayout.Pick(scope, Enum.FillDirection.Horizontal, Enum.FillDirection.Vertical),
				Padding = UDim.new(0, 6),
			}),
			frames :: any,
		},
	})
end

return PartyFrames
