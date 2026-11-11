--!strict
-- Derived statistics grouped as Offense / Defense / Resources / Other, with a tooltip explaining where
-- each value comes from. While stat points are pending, values are previewed with Logic/StatCalc and the
-- difference is shown in green. Owner 2026-11-10: as tall as its rows (the statistics section of the backpack window
-- scrolls with its column, UI/Components/Section).
-- Owner 2026-11-10 (UI plan: 37 rows, 11 names cut): one Section per group next to the statistics' section (one fold
-- level), "Ofensywa" open, the rest folded (charOffense / charDefense / charResources / charOther in Data/Folds/Gear);
-- a name never cut: it wraps to a second line beside its value.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterSections = require(ReplicatedStorage.Shared.Logic.CharacterSections)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Section = require(script.Parent.Parent.Parent.Components.Section)
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
	LayoutOrder: number?, -- the sections take LayoutOrder + 1 .. + 4
}

local ROW_HEIGHT = 30 -- one line of Small text; a long name takes a second line
local VALUE_WIDTH = 84

-- Owner 2026-11-10 (UI plan): each group of Data/Stats folds on its own (Data/Folds/Gear).
local SECTIONS: { [string]: string } = {
	offense = "charOffense",
	defense = "charDefense",
	resources = "charResources",
	other = "charOther",
}

local function DerivedList(scope: Scope, props: Props): { Instance }
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

	-- owner 2026-11-10: one section per group, the attack ones open, the rest folded to their header
	local sections: { Instance } = {}
	for index, group in Stats.groups do
		local rows: { Instance } = {}
		local rowIndex = 0
		for _, def in Stats.list do
			if def.group ~= group then
				continue
			end
			rowIndex += 1
			local value = scope:Computed(function(use): number
				local d = use(derived)
				return if type(d) == "table" then d.values[def.id] or 0 else 0
			end)
			local row = scope:New("Frame")({
				Name = def.id,
				LayoutOrder = rowIndex,
				Active = true,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.Y,
				-- alternating parchment, as the dense list rows had (S135)
				BackgroundColor3 = Theme.Paper.Raised,
				BackgroundTransparency = if rowIndex % 2 == 0 then 0.5 else 1,
				[Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
					}),
					-- the name wraps to a second line instead of being cut ("Regeneracja energii w walce (na s)")
					scope:New("TextLabel")({
						Name = "Name",
						Size = UDim2.new(1, -VALUE_WIDTH, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Text = Text.T(scope, def.nameKey),
						TextWrapped = true,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						Name = "Value",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(VALUE_WIDTH, ROW_HEIGHT - 8),
						BackgroundTransparency = 1,
						RichText = true,
						Text = scope:Computed(function(use): string
							local current = use(value)
							local p = use(preview)
							local mark = Text.get(use, "format.decimal") -- "5,3%" in Polish
							local text = CharacterSections.statValue(def, current, mark)
							if p and p[def.id] and math.abs(p[def.id] - current) > 1e-6 then
								local after = CharacterSections.statValue(def, p[def.id], mark)
								return `<font color="{Theme.hex(Theme.Paper.Success)}">{after}</font>`
							end
							return text
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Heading,
						TextXAlignment = Enum.TextXAlignment.Right,
					}),
				},
			})
			Tooltip.attach(
				scope,
				row :: GuiObject,
				scope:Computed(function(use): string
					local d = use(derived)
					local mark = Text.get(use, "format.decimal")
					local lines = { Text.get(use, def.nameKey) }
					local parts = if type(d) == "table" then d.breakdown[def.id] else nil
					if parts then
						for _, part in parts do
							if part.value ~= 0 then
								local amount = CharacterSections.statPart(part.value, part.pct, mark)
								table.insert(lines, `{Text.get(use, part.key)}: {amount}`)
							end
						end
					end
					if def.cap then
						local cap = CharacterSections.statValue(def, def.cap, mark)
						table.insert(lines, Text.get(use, "character.cap", { cap = cap }))
					end
					return table.concat(lines, "\n")
				end)
			)
			table.insert(rows, row)
		end
		table.insert(
			sections,
			Section.new(scope, {
				Id = SECTIONS[group] or "charOther",
				Name = `Group_{group}`,
				LayoutOrder = (props.LayoutOrder or 0) + index,
				Title = Text.T(scope, `statGroup.{group}`),
				Padding = 0,
				Children = rows,
			})
		)
	end
	return sections
end

return DerivedList
