--!strict
-- Derived statistics grouped as Offense / Defense / Resources / Other, with a tooltip explaining where
-- each value comes from. While stat points are pending, values are previewed with Logic/StatCalc and the
-- difference is shown in green.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local StatCalc = require(ReplicatedStorage.Shared.Logic.StatCalc)
local State = require(script.Parent.Parent.Parent.State)
local Stats = require(ReplicatedStorage.Shared.Data.Stats)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Pending: Fusion.Value<{ [string]: number }>,
	LayoutOrder: number?,
	Position: UDim2?,
	Size: UDim2?,
}

local ROW_HEIGHT = 26

local function formatValue(def: Stats.StatDef, value: number): string
	local text = string.format(`%.{def.decimals}f`, value)
	return if def.format == "pct" then text .. "%" else text
end

local function formatPart(value: number, pct: boolean?): string
	local sign = if value >= 0 then "+" else ""
	local rounded = math.floor(value * 100 + 0.5) / 100
	local text = if rounded == math.floor(rounded) then string.format("%d", rounded) else tostring(rounded)
	return sign .. text .. (if pct then "%" else "")
end

local function DerivedList(scope: Scope, props: Props): Instance
	local derived = State.Value({ "derived" })
	local character = State.Value({ "character" })

	-- Preview of all values with the pending allocation applied (nil when nothing is pending).
	local preview = scope:Computed(function(use): { [string]: number }?
		local pending = use(props.Pending)
		local d = use(derived)
		local c = use(character)
		if next(pending) == nil or type(d) ~= "table" or type(c) ~= "table" then
			return nil
		end
		local stats = table.clone(c.stats)
		for id, add in pending do
			stats[id] = (stats[id] or 0) + add
		end
		return StatCalc.compute({
			level = c.level,
			stats = stats,
			sources = { d.mods },
			weapon = d.weapon,
		}).values
	end)

	local children = {}
	local order = 0
	for _, group in Stats.groups do
		order += 1
		table.insert(
			children,
			scope:New("TextLabel")({
				Name = `Group_{group}`,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Text = Text.T(scope, `statGroup.{group}`),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.Gold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
			})
		)
		for _, def in Stats.list do
			if def.group ~= group then
				continue
			end
			order += 1
			local value = scope:Computed(function(use): number
				local d = use(derived)
				return if type(d) == "table" then d.values[def.id] or 0 else 0
			end)
			local row = scope:New("Frame")({
				Name = def.id,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				BackgroundTransparency = if order % 2 == 0 then 1 else 0.93,
				BackgroundColor3 = Theme.Colors.Parchment,
				Active = true,
				[Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, Theme.Padding.Small),
						PaddingRight = UDim.new(0, Theme.Padding.Small),
					}),
					scope:New("TextLabel")({
						Name = "Name",
						Size = UDim2.fromScale(0.68, 1), -- S29: narrower column, long names keep more room
						BackgroundTransparency = 1,
						Text = Text.T(scope, def.nameKey),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small + 1,
						TextColor3 = Theme.Colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					scope:New("TextLabel")({
						Name = "Value",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(0.32, 1),
						BackgroundTransparency = 1,
						RichText = true,
						Text = scope:Computed(function(use): string
							local current = use(value)
							local p = use(preview)
							local text = formatValue(def, current)
							if p and p[def.id] and math.abs(p[def.id] - current) > 1e-6 then
								return `<font color="#4FD16B">{formatValue(def, p[def.id])}</font>`
							end
							return text
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small + 1,
						TextColor3 = Theme.Colors.Parchment,
						TextXAlignment = Enum.TextXAlignment.Right,
					}),
				},
			})
			Tooltip.attach(
				scope,
				row :: GuiObject,
				scope:Computed(function(use): string
					local d = use(derived)
					local lines = { Text.get(use, def.nameKey) }
					local parts = if type(d) == "table" then d.breakdown[def.id] else nil
					if parts then
						for _, part in parts do
							if part.value ~= 0 then
								table.insert(lines, `{Text.get(use, part.key)}: {formatPart(part.value, part.pct)}`)
							end
						end
					end
					if def.cap then
						table.insert(lines, Text.get(use, "character.cap", { cap = formatValue(def, def.cap) }))
					end
					return table.concat(lines, "\n")
				end)
			)
			table.insert(children, row)
		end
	end

	return scope:New("ScrollingFrame")({
		Name = "DerivedList",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.GoldDim,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
			children :: any,
		},
	})
end

return DerivedList
