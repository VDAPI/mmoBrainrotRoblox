--!strict
-- Wardrobe → Weapon looks (S154, docs/DESIGN.md §6b): the account's collection of item looks (Logic/Transmog) to look
-- through. The total, then per held type "{type}: n/all" with the looks as icons (owned bright, the rest dimmed), then
-- the rare boss looks with the boss that drops them. Looks are put on at the blacksmith (Appearance tab): "Guide me to
-- the blacksmith". Weapon effects (particles, the cosmetic kind `weapon`) stay on their own tab and work on any look.
-- 2026-10-21 (owner: too many detailed descriptions): the hint is one short line, how the collection grows and that
-- weapon effects work on every look behind its "i".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Button = require(script.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local ItemText = require(script.Parent.Parent.ItemText)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Transmog = require(ReplicatedStorage.Shared.Logic.Transmog)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Visible: Fusion.UsedAs<boolean>,
	Position: Fusion.UsedAs<UDim2>,
	Size: Fusion.UsedAs<UDim2>,
	GuideToSmith: (() -> ())?,
}

local ICON = 48
local BOSS_ROW = 60

local function text(scope: Scope, order: number, value: Fusion.UsedAs<string>, color: Color3, bold: boolean?): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		RichText = true,
		TextWrapped = true,
		Text = value,
		FontFace = if bold then Theme.Fonts.BodyBold else Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- 2026-10-21: a short line with an "i" right after it holding the full text.
local function infoText(
	scope: Scope,
	order: number,
	value: Fusion.UsedAs<string>,
	info: Fusion.UsedAs<string>
): Instance
	local line = text(scope, 1, value, Theme.Paper.TextMuted) :: TextLabel
	line.Size = UDim2.new()
	line.AutomaticSize = Enum.AutomaticSize.XY
	scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink, Parent = line })
	return scope:New("Frame")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			line,
			InfoTip.new(scope, { Text = info, LayoutOrder = 2 }),
		},
	})
end

-- A look as an icon tile: bright when owned, dimmed when not (`at` places it outside a grid).
local function iconTile(scope: Scope, order: number, key: string, owned: boolean, at: UDim2?): Instance
	return scope:New("Frame")({
		Name = key,
		LayoutOrder = order,
		Position = at,
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundColor3 = if owned then Theme.Paper.Raised else Theme.Paper.Sunken,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				Color = if owned then Theme.Paper.Border else Theme.Paper.Rule,
				Thickness = Theme.Stroke.Thin,
			}),
			ItemIcon(scope, {
				Def = Transmog.lookDef(key),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0.9),
				Transparency = if owned then 0 else 0.65,
			}),
		},
	})
end

local function WardrobeTransmog(scope: Scope, props: Props): Instance
	local collection = State.Value({ "account", "transmog" })
	local looks = scope:Computed(function(use): { [string]: boolean }
		return Transmog.sanitize(use(collection)).looks
	end)

	local totalText = scope:Computed(function(use): string
		local owned = use(looks)
		local n, all = 0, 0
		for _, entry in Transmog.catalogue() do
			for _, list in { entry.base, entry.boss } do
				for _, key in list do
					all += 1
					if owned[key] then
						n += 1
					end
				end
			end
		end
		return Text.get(use, "wardrobe.transmog.total", { n = n, all = all })
	end)

	local sections = scope:Computed(function(use, s: Scope): { Instance }
		local owned = use(looks)
		local out: { Instance } = {}
		local order = 0
		local function add(instance: Instance)
			order += 1
			(instance :: any).LayoutOrder = order
			table.insert(out, instance)
		end
		-- every held type: "{type}: n/all" and its looks
		for _, entry in Transmog.catalogue() do
			if #entry.base > 0 then
				local n, all = Transmog.count(entry.type, owned)
				add(text(
					s,
					0,
					Text.get(use, "wardrobe.transmog.count", {
						type = Text.get(use, `itemBase.{entry.type}`),
						n = n,
						all = all,
					}),
					Theme.Paper.Heading,
					true
				))
				local tiles: { Instance } = {}
				for i, key in entry.base do
					table.insert(tiles, iconTile(s, i, key, owned[key] == true))
				end
				add(s:New("Frame")({
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = {
						s:New("UIGridLayout")({
							CellSize = UDim2.fromOffset(ICON, ICON),
							CellPadding = UDim2.fromOffset(4, 4),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						tiles :: any,
					},
				}))
			end
		end
		-- the rare boss looks: the item, the boss, owned or not
		add(text(s, 0, Text.get(use, "wardrobe.transmog.boss"), Theme.Paper.Heading, true))
		for _, entry in Transmog.catalogue() do
			for _, key in entry.boss do
				local def = Transmog.lookDef(key)
				local boss = def and def.bossId and Bosses.get(def.bossId)
				local has = owned[key] == true
				add(s:New("Frame")({
					Size = UDim2.new(1, 0, 0, BOSS_ROW),
					BackgroundColor3 = if has then Theme.Paper.Raised else Theme.Paper.Sunken,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						iconTile(s, 0, key, has, UDim2.fromOffset(6, (BOSS_ROW - ICON) / 2)),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(ICON + 16, 4),
							Size = UDim2.new(1, -(ICON + 24), 1, -8),
							BackgroundTransparency = 1,
							RichText = true,
							TextWrapped = true,
							Text = `<b>♛ {if def then ItemText.get(use, def.id) else key}</b>\n{Text.get(
								use,
								if has then "wardrobe.transmog.bossOwned" else "wardrobe.transmog.bossMissing",
								{ boss = if boss then Text.get(use, boss.nameKey) else "" }
							)}`,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if has then Theme.Paper.Text else Theme.Paper.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Center,
						}),
					},
				}))
			end
		end
		return out
	end)

	return scope:New("Frame")({
		Name = "TransmogCollection",
		Position = props.Position,
		Size = props.Size,
		Visible = props.Visible,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			text(scope, 1, totalText, Theme.Paper.Heading, true),
			infoText(scope, 2, Text.T(scope, "wardrobe.transmog.hint.short"), Text.T(scope, "wardrobe.transmog.hint")),
			Button(scope, {
				LayoutOrder = 3,
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(240, if use(Device.Touch) then Theme.Size.MinTouch else 36)
				end),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "wardrobe.transmog.guide"),
				Visible = props.GuideToSmith ~= nil,
				OnClick = function()
					local guide = props.GuideToSmith
					if guide then
						guide()
					end
				end,
			}),
			scope:New("ScrollingFrame")({
				LayoutOrder = 4,
				Size = scope:Computed(function(use): UDim2
					local touch = use(Device.Touch)
					return UDim2.new(1, 0, 1, -(if touch then 130 else 116)) -- total, the one-line hint, the button
				end),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Paper.Rule,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
					sections :: any,
				},
			}),
		},
	})
end

return WardrobeTransmog
