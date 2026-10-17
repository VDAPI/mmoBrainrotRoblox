--!strict
-- "Where to?" window (S22, DESIGN §3.6): the monster areas of a region map for a portal or the Map Stone.
-- Rows sorted by level: name, monster kinds, level range in the band colour relative to the player,
-- "Recommended" when the player's level fits, a lock with "from level X" when the area is still closed.
-- The lowest area is selected at first; a row click selects, "Set off" (or Enter) travels. Warnings of the
-- portal (red zone, map above your level) sit on top. Works with touch: tall rows in a scrolling list.
-- S33: a third line with the hunting ground profile ("⚡ Fast EXP — EXP ×1 · items ×0.6 · gold ×0.7"), the selected
-- area's profile described under the list, "Recommended" on the best area of every profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local AreaProfileText = require(script.Parent.Parent.AreaProfileText)
local AreaProfiles = require(ReplicatedStorage.Shared.Data.AreaProfiles)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Button = require(script.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	MapId: Fusion.UsedAs<string?>,
	Warnings: Fusion.UsedAs<{ string }>,
	Selected: Fusion.Value<string?>,
	Busy: Fusion.UsedAs<boolean>,
	OnGo: () -> (),
}

local ROW_HEIGHT = 66
local PROFILE_ROW_HEIGHT = 88

local CONTRACT_HEX = "#" .. Theme.Colors.GoldBright:ToHex()

-- The tag under an area's levels: "from level X" when locked, else S99 "◈ Contract" and "★ Recommended".
local function tagText(use: Fusion.Use, area: any, locked: boolean, recommended: boolean, contract: boolean): string
	if locked then
		return Text.get(use, "portal.choose.fromLevel", { level = area.lv[1] })
	end
	local parts: { string } = {}
	if contract then
		table.insert(parts, `<font color="{CONTRACT_HEX}">{Text.get(use, "portal.choose.contract")}</font>`)
	end
	if recommended then
		table.insert(parts, Text.get(use, "portal.choose.recommended"))
	end
	return table.concat(parts, "  ")
end

local function kindsText(use: Fusion.Use, kinds: { string }): string
	local names = {}
	for _, kind in kinds do
		local def = Monsters.get(kind)
		if def then
			table.insert(names, Text.get(use, def.nameKeys.normal))
		end
	end
	return table.concat(names, " · ")
end

local function AreaPicker(scope: Scope, props: Props): Fusion.Child
	local level = State.Value({ "character", "level" })
	-- S99: the hunting ground of the active hunting contract gets "◈ Contract" (the default choice stays, S22); S134k: of
	-- every active one
	local contractState = State.Value({ "character", "quests", "contract" })

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local mapId = use(props.MapId)
		local playerLevel = use(level) or 1
		local list = {}
		local best = AreaAdvice.bestByProfile(playerLevel, mapId or "")
		-- S134k: every hunting ground of an active, unfinished contract
		local contractAreas: { [string]: boolean } = {}
		for _, taken in Contracts.activeList(Contracts.stateOf({ contract = use(contractState) })) do
			if not Contracts.isTakenComplete(taken) then
				contractAreas[taken.contract.area] = true
			end
		end
		for i, area in AreaAdvice.sorted(mapId or "") do
			local locked = AreaAdvice.locked(area, playerLevel)
			local band = Color3.fromHex(LevelBand.COLORS[AreaAdvice.bandOf(area, playerLevel)])
			local recommended = best[area.profile or "none"] == area
			local profile = AreaProfiles.get(area.profile)
			local selected = s:Computed(function(use2): boolean
				return use2(props.Selected) == area.id
			end)
			table.insert(
				list,
				s:New("TextButton")({
					Name = area.id,
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, if profile then PROFILE_ROW_HEIGHT else ROW_HEIGHT),
					AutoButtonColor = false,
					Text = "",
					BackgroundColor3 = s:Computed(function(use2): Color3
						return if use2(selected) then Theme.Colors.PanelHover else Theme.Colors.PanelRaised
					end),
					BackgroundTransparency = if locked then 0.45 else 0,
					[Fusion.OnEvent("Activated")] = function()
						if not locked then
							props.Selected:set(area.id)
						end
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
						s:New("UIStroke")({
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Thickness = s:Computed(function(use2): number
								return if use2(selected) then 2 else 1
							end),
							Color = s:Computed(function(use2): Color3
								return if use2(selected) then Theme.Colors.GoldBright else Theme.Colors.Border
							end),
						}),
						-- band stripe
						s:New("Frame")({
							Size = UDim2.new(0, 6, 1, -12),
							Position = UDim2.fromOffset(6, 6),
							BackgroundColor3 = band,
							BorderSizePixel = 0,
						}),
						s:New("TextLabel")({
							Name = "Name",
							Position = UDim2.fromOffset(20, 8),
							Size = UDim2.new(1, -150, 0, 26),
							BackgroundTransparency = 1,
							Text = (if locked then "🔒 " else "") .. Text.get(use, area.nameKey),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = if locked then Theme.Colors.TextMuted else Theme.Colors.Text,
						}),
						s:New("TextLabel")({
							Name = "Kinds",
							Position = UDim2.fromOffset(20, 36),
							Size = UDim2.new(1, -150, 0, 20),
							BackgroundTransparency = 1,
							Text = kindsText(use, area.kinds),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Colors.TextMuted,
						}),
						if profile
							then s:New("TextLabel")({
								Name = "Profile",
								Position = UDim2.fromOffset(20, 60),
								Size = UDim2.new(1, -32, 0, 20),
								BackgroundTransparency = 1,
								Text = `{AreaProfileText.tag(use, profile)} — {AreaProfileText.mults(use, profile)}`,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Small,
								TextColor3 = AreaProfileText.color(profile),
								TextTransparency = if locked then 0.4 else 0,
							})
							else nil :: any,
						s:New("TextLabel")({
							Name = "Levels",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -12, 0, 6),
							Size = UDim2.fromOffset(120, 30),
							BackgroundTransparency = 1,
							Text = `{area.lv[1]}–{area.lv[2]}`,
							TextXAlignment = Enum.TextXAlignment.Right,
							FontFace = Theme.Fonts.Heading,
							TextSize = 28,
							TextColor3 = band,
							TextStrokeTransparency = 0.6,
						}),
						s:New("TextLabel")({
							Name = "Tag",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -12, 0, 38),
							Size = UDim2.fromOffset(220, 20),
							BackgroundTransparency = 1,
							RichText = true,
							Text = tagText(use, area, locked, recommended, contractAreas[area.id] == true),
							TextXAlignment = Enum.TextXAlignment.Right,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if locked then Theme.Colors.TextMuted else Theme.Colors.GoldBright,
						}),
					},
				})
			)
		end
		return list
	end)

	local warningText = scope:Computed(function(use): string
		return table.concat(use(props.Warnings) or {}, "\n")
	end)
	local hasWarnings = scope:Computed(function(use): boolean
		return #(use(props.Warnings) or {}) > 0
	end)
	-- What the selected area's profile feels like (touch: tap a row to read it).
	local detail = scope:Computed(function(use): string
		local area = Areas.areaById(use(props.Selected) or "")
		local profile = area and AreaProfiles.get(area.profile)
		if not profile then
			return ""
		end
		return `{AreaProfileText.tag(use, profile)}: {Text.get(use, profile.descKey)}`
	end)
	local hasDetail = scope:Computed(function(use): boolean
		return use(detail) ~= ""
	end)

	return {
		scope:New("Frame")({
			Name = "AreaPicker",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				scope:New("TextLabel")({
					Name = "Header",
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						local map = Maps.get(use(props.MapId) or "")
						return Text.get(use, "portal.choose.header", {
							map = if map then Text.get(use, map.nameKey) else "",
							level = use(level) or 1,
						})
					end),
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.Parchment,
				}),
				scope:New("TextLabel")({
					Name = "Warnings",
					LayoutOrder = 2,
					Visible = hasWarnings,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = warningText,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.Warning,
				}),
				scope:New("ScrollingFrame")({
					Name = "List",
					LayoutOrder = 3,
					Size = scope:Computed(function(use): UDim2
						return UDim2.new(
							1,
							0,
							1,
							(if use(hasWarnings) then -160 else -110) - (if use(hasDetail) then 44 else 0)
						)
					end),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 6,
					[Children] = {
						scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
						scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2) }),
						rows :: any,
					},
				}),
				scope:New("TextLabel")({
					Name = "Detail",
					LayoutOrder = 4,
					Visible = hasDetail,
					Size = UDim2.new(1, 0, 0, 36),
					BackgroundTransparency = 1,
					Text = detail,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.Parchment,
				}),
				Button(scope, {
					Name = "Go",
					LayoutOrder = 5,
					Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
					Variant = "primary",
					Disabled = scope:Computed(function(use): boolean
						return use(props.Busy) or use(props.Selected) == nil
					end),
					Text = Text.T(scope, "portal.choose.go"),
					OnClick = props.OnGo,
				}),
			},
		}),
	}
end

return AreaPicker
