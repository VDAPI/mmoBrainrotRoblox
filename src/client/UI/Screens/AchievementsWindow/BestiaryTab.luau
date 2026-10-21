--!strict
-- The bestiary tab of the achievements window (S151c, docs/DESIGN.md §20c). The middle: the four regions with their
-- progress bars (tiers reached / all, ✔ when complete: the region's title achievement) and the entries of the chosen
-- region (the name or "???" before the first kill, the tier, kills / the next goal, a bar). The details (PC a panel on
-- the right, phone a sheet): the model preview once the first tier reveals it (WorldMap/Preview, the map cards'
-- builder), the tiers with their points, then what the tiers reveal: levels, where and how it attacks (I), the drops
-- seen and the defence (II), the weaknesses (III), and the character's bonus against the family. Everything from
-- Logic/Bestiary over Context.st (the replicated character.ach); the window computes no rule of its own.
-- 2026-10-21 (owner: too many descriptions): the family bonus is one short line, how it grows behind an "i".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local BestiaryData = require(ReplicatedStorage.Shared.Data.Bestiary)
local Bestiary = require(ReplicatedStorage.Shared.Logic.Bestiary)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Context = require(script.Parent.Context)
local Families = require(ReplicatedStorage.Shared.Data.Families)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoLine = require(script.Parent.Parent.Parent.Components.InfoLine)
local ItemName = require(ReplicatedStorage.Shared.Logic.ItemName)
local ListRow = require(script.Parent.Parent.Parent.Components.ListRow)
local Preview = require(script.Parent.Parent.WorldMap.Preview)
local SectionLabel = require(script.Parent.Parent.Parent.Components.SectionLabel)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local BestiaryTab = {}

local GAP = 6
local REGION_ROW = 40
local ENTRY_ROW = 58
local COUNT = 96
local PREVIEW = 150
local TOP = 44

local function chr(use: Fusion.Use, ctx: Context.Ctx): any
	return use(ctx.st).chr
end

local function regionName(use: Fusion.Use, region: string): string
	return Text.get(use, `map.{region}.name`)
end

-- "I✓ II [III]" of an entry row (the next tier in brackets).
local function tiersText(row: Bestiary.Row): string
	local parts: { string } = {}
	for i = 1, row.tiers do
		local numeral = Context.ROMAN[i] or tostring(i)
		if i <= row.tier then
			table.insert(parts, `{numeral}✓`)
		elseif i == row.tier + 1 then
			table.insert(parts, `[{numeral}]`)
		else
			table.insert(parts, numeral)
		end
	end
	return table.concat(parts, " ")
end

local function bar(s: Scope, value: Fusion.UsedAs<number>, done: boolean, layout: { [any]: any }): Instance
	local spec: { [any]: any } = {
		Value = value,
		Max = 1,
		Color = if done then Theme.Paper.Success else Theme.Brass.Frame,
		Surface = "paper",
	}
	for k, v in layout do
		spec[k] = v
	end
	return Bar(s, spec :: any)
end

-- The region rows (progress bars; a click shows the region's entries).
local function regionRows(scope: Scope, ctx: Context.Ctx): Instance
	local regions = scope:Computed(function(use): { Bestiary.RegionRow }
		return Bestiary.regions(chr(use, ctx))
	end)
	local rows: { Instance } = {}
	for i, region in BestiaryData.REGIONS do
		local live = scope:Computed(function(use): Bestiary.RegionRow
			return use(regions)[i]
		end)
		table.insert(
			rows,
			ListRow(scope, {
				Name = region,
				LayoutOrder = i,
				Index = i,
				Height = REGION_ROW,
				Dense = true,
				RightInset = COUNT,
				Text = scope:Computed(function(use): string
					local r = use(live)
					local name = regionName(use, region)
					return if r.complete then `{name}  ✔` else name
				end),
				Value = scope:Computed(function(use): string?
					local r = use(live)
					return Text.get(use, "best.region.tiers", { done = r.done, max = r.max })
				end),
				Selected = scope:Computed(function(use): boolean
					return use(ctx.region) == region
				end),
				OnClick = function()
					ctx.region:set(region)
				end,
				[Children] = scope:Computed(function(use, s: Scope): Instance
					local r = use(live)
					return bar(s, r.pct, r.complete, {
						Name = "Progress",
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, Theme.Padding.Small + 4, 1, -4),
						Size = UDim2.new(1, -(Theme.Padding.Small * 2 + 8), 0, 5),
					})
				end) :: any,
			})
		)
	end
	return scope:New("Frame")({
		Name = "Regions",
		Size = UDim2.new(1, 0, 0, (REGION_ROW + 2) * #BestiaryData.REGIONS + 26),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
			scope:New("TextLabel")({
				Name = "Head",
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local c = chr(use, ctx)
					return Text.get(use, "best.head", { points = Bestiary.points(c), max = Bestiary.pointsMax() })
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Label,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			rows :: any,
		},
	})
end

-- The shape of the entry list: what forces a rebuild (the region, known entries, tiers).
local function shapeOf(region: string, rows: { Bestiary.Row }): string
	local parts: { string } = { region }
	for _, row in rows do
		table.insert(parts, `{row.id}:{if row.known then 1 else 0}:{row.tier}`)
	end
	return table.concat(parts, ",")
end

-- The entries of the chosen region.
local function entryRows(scope: Scope, ctx: Context.Ctx, touch: boolean): Instance
	local rows = scope:Computed(function(use): { Bestiary.Row }
		return Bestiary.rows(chr(use, ctx), use(ctx.region))
	end)
	local byId = scope:Computed(function(use): { [string]: Bestiary.Row }
		local out: { [string]: Bestiary.Row } = {}
		for _, row in use(rows) do
			out[row.id] = row
		end
		return out
	end)
	local shape = scope:Computed(function(use): string
		return shapeOf(use(ctx.region), use(rows))
	end)
	local items = scope:Computed(function(use, s: Scope): { Instance }
		use(shape)
		local out: { Instance } = {}
		for i, row in Fusion.peek(rows) do
			local id = row.id
			local live = s:Computed(function(use2): Bestiary.Row
				return use2(byId)[id] or row
			end)
			local name = if row.nameKey then Text.get(use, row.nameKey) else Text.get(use, "best.unknown")
			if row.boss then
				name = `☠ {name}`
			end
			local sub = if row.known
				then `{tiersText(row)} · {Text.get(
					use,
					"best.points",
					{ n = Bestiary.pointsOf(BestiaryData.get(id) :: any, row.tier) }
				)}`
				else Text.get(use, if row.boss then "best.unknownBoss" else "best.unknownSub")
			table.insert(
				out,
				ListRow(s, {
					Name = id,
					LayoutOrder = i,
					Index = i,
					Height = ENTRY_ROW,
					RightInset = COUNT + 8,
					Text = name,
					Sub = sub,
					Muted = not row.known,
					Selected = s:Computed(function(use2): boolean
						return use2(ctx.entry) == id
					end),
					OnClick = function()
						ctx.entry:set(id)
						if touch then
							ctx.sheet:set(true)
						end
					end,
					[Children] = {
						s:New("TextLabel")({
							Name = "Count",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -8, 0, 4),
							Size = UDim2.fromOffset(COUNT, 20),
							BackgroundTransparency = 1,
							Text = s:Computed(function(use2): string
								local r = use2(live)
								return if r.mastered then `✔ {r.kills}` else `{r.kills} / {r.goal}`
							end),
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Caption,
							TextColor3 = if row.mastered then Theme.Paper.Success else Theme.Paper.Label,
							TextXAlignment = Enum.TextXAlignment.Right,
							ZIndex = 2,
						}),
						bar(
							s,
							s:Computed(function(use2): number
								return use2(live).pct
							end),
							row.mastered,
							{
								Name = "Progress",
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.new(0, Theme.Padding.Small + 4, 1, -5),
								Size = UDim2.new(1, -(Theme.Padding.Small * 2 + 12), 0, 5),
							}
						),
					},
				})
			)
		end
		return out
	end)
	return scope:New("ScrollingFrame")({
		Name = "Entries",
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Label,
		Size = UDim2.fromScale(1, 1),
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
			items :: any,
		},
	})
end

-- The middle of the tab: the regions on top, the entries of the chosen one under them.
function BestiaryTab.list(scope: Scope, ctx: Context.Ctx, touch: boolean): Instance
	local top = (REGION_ROW + 2) * #BestiaryData.REGIONS + 26 + GAP
	return scope:New("Frame")({
		Name = "Bestiary",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			regionRows(scope, ctx),
			scope:New("Frame")({
				Name = "List",
				Position = UDim2.fromOffset(0, top),
				Size = UDim2.new(1, 0, 1, -top),
				BackgroundTransparency = 1,
				[Children] = entryRows(scope, ctx, touch),
			}),
		},
	})
end

-- Details ---------------------------------------------------------------------------------------------------------------

local function selection(use: Fusion.Use, ctx: Context.Ctx): Bestiary.View?
	local id = use(ctx.entry)
	if not id then
		return nil
	end
	return Bestiary.view(chr(use, ctx), id)
end

-- A text line with its arguments; `element` names an element key (translated here).
local function lineText(use: Fusion.Use, line: Bestiary.Line): string
	local args: { [string]: any } = {}
	for k, v in (line.args or {}) :: { [string]: any } do
		args[k] = if k == "element" and type(v) == "string" then Text.get(use, v) else v
	end
	return Text.get(use, line.key, args)
end

-- The lines of the details (instances in layout order).
function BestiaryTab.lines(s: Scope, use: Fusion.Use, ctx: Context.Ctx): { Instance }
	local out: { Instance } = {}
	local function text(value: string, font: Font, size: number, color: Color3)
		table.insert(
			out,
			s:New("TextLabel")({
				LayoutOrder = #out + 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				TextWrapped = true,
				Text = value,
				FontFace = font,
				TextSize = size,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		)
	end
	local function section(key: string)
		table.insert(out, SectionLabel(s, { LayoutOrder = #out + 1, Text = Text.get(use, key) }))
	end
	local function locked(tier: number, entry: BestiaryData.Entry)
		text(
			Text.get(use, "best.locked", { tier = Context.ROMAN[tier] or tostring(tier), n = entry.tiers[tier] }),
			Theme.Fonts.Body,
			Theme.TextSize.Small,
			Theme.Paper.TextMuted
		)
	end
	local view = selection(use, ctx)
	local entry = if view then BestiaryData.get(view.id) else nil
	if not view or not entry then
		text(Text.get(use, "best.select"), Theme.Fonts.Body, Theme.TextSize.Body, Theme.Paper.TextMuted)
		return out
	end
	text(
		if view.nameKey then Text.get(use, view.nameKey) else Text.get(use, "best.unknown"),
		Theme.Fonts.Display,
		Theme.TextSize.Large,
		Theme.Paper.Heading
	)
	local meta = { regionName(use, view.region) }
	local family = if view.family then Families.get(view.family) else nil
	if family then
		table.insert(meta, Text.get(use, family.nameKey))
	end
	if view.boss then
		table.insert(meta, Text.get(use, "best.boss"))
	end
	text(table.concat(meta, " · "), Theme.Fonts.BodyMedium, Theme.TextSize.Small, Theme.Paper.TextMuted)
	if not view.known then
		text(
			Text.get(use, "best.unknownHint", { region = regionName(use, view.region) }),
			Theme.Fonts.Body,
			Theme.TextSize.Small,
			Theme.Paper.Text
		)
	end

	section("best.section.progress")
	table.insert(
		out,
		Bar(s, {
			LayoutOrder = #out + 1,
			Size = UDim2.new(1, 0, 0, 12),
			Value = view.pct,
			Max = 1,
			Color = if view.mastered then Theme.Paper.Success else Theme.Brass.Frame,
			Surface = "paper",
		})
	)
	text(
		Text.get(use, "best.kills", { kills = view.kills, goal = view.goal }),
		Theme.Fonts.BodyBold,
		Theme.TextSize.Small,
		Theme.Paper.Label
	)
	for i, step in view.steps do
		local parts = {
			Context.ROMAN[i] or tostring(i),
			Text.get(use, "best.step", { n = step.goal }),
			Text.get(use, "best.points", { n = step.points }),
			Text.get(use, `best.reveal{i}`),
		}
		text(
			`{table.concat(parts, " · ")}{if step.done then "  ✔" else ""}`,
			if i == view.tier + 1 then Theme.Fonts.BodyBold else Theme.Fonts.Body,
			Theme.TextSize.Small,
			if step.done then Theme.Paper.Success else Theme.Paper.Text
		)
	end

	section("best.section.about")
	if view.levels then
		local levels = view.levels
		text(
			if levels.min == levels.max
				then Text.get(use, "best.level", { n = levels.min })
				else Text.get(use, "best.levels", { min = levels.min, max = levels.max }),
			Theme.Fonts.BodyMedium,
			Theme.TextSize.Body,
			Theme.Paper.Text
		)
		text(
			Text.get(use, if view.cave then "best.where.cave" else "best.where.open", {
				region = regionName(use, view.region),
			}),
			Theme.Fonts.Body,
			Theme.TextSize.Small,
			Theme.Paper.Text
		)
		local attack: { string } = {}
		local lines: { Bestiary.Line } = view.attack or {}
		for _, line in lines do
			table.insert(attack, lineText(use, line))
		end
		text(table.concat(attack, " · "), Theme.Fonts.Body, Theme.TextSize.Small, Theme.Paper.Text)
	else
		locked(BestiaryData.REVEAL.portrait, entry)
	end

	section("best.section.drops")
	if view.drops then
		for _, drop in view.drops do
			text(
				if drop.seen
					then `• {ItemName.get(use(Text.Lang), drop.id)}`
					else `• {Text.get(use, "best.unknown")}`,
				Theme.Fonts.Body,
				Theme.TextSize.Small,
				if drop.seen then Theme.Paper.Text else Theme.Paper.TextMuted
			)
		end
		if view.defence then
			text(
				Text.get(use, "best.defence", { name = Text.get(use, `monsterDefence.{view.defence}.name`) }),
				Theme.Fonts.BodyMedium,
				Theme.TextSize.Small,
				Theme.Paper.Text
			)
		end
	else
		locked(BestiaryData.REVEAL.drops, entry)
	end

	section("best.section.weak")
	if view.weak then
		for _, line in view.weak do
			text(`• {lineText(use, line)}`, Theme.Fonts.Body, Theme.TextSize.Small, Theme.Paper.Text)
		end
	else
		locked(BestiaryData.REVEAL.weak, entry)
	end

	if family then
		section("best.section.bonus")
		local args = {
			pct = view.familyPct,
			per = BestiaryData.FAMILY_PCT,
			cap = BestiaryData.FAMILY_CAP,
			family = Text.get(use, family.nameKey),
		}
		table.insert(
			out,
			InfoLine.new(s, {
				LayoutOrder = #out + 1,
				Text = Text.get(use, "best.bonus.short", args),
				Info = Text.get(use, "best.bonus", args),
				Color = if view.familyPct > 0 then Theme.Paper.Success else Theme.Paper.Text,
			})
		)
	end
	return out
end

-- The preview of the selection: the model once the first tier reveals it, "?" before.
local function preview(scope: Scope, ctx: Context.Ctx): (Instance, Fusion.Computed<boolean>)
	local api = Preview.new(scope, ctx.props.BuildLook)
	local spec = scope:Computed(function(use): Preview.Spec?
		local view = selection(use, ctx)
		if not view then
			return nil
		end
		if view.levels == nil then
			return { kind = "glyph", id = view.id, glyph = "?", color = Theme.Paper.TextMuted }
		end
		return { kind = if view.boss then "boss" else "monster", id = view.id, variant = "normal" }
	end)
	scope:Observer(spec):onBind(function()
		api.show(Fusion.peek(spec))
	end)
	local shown = scope:Computed(function(use): boolean
		return use(spec) ~= nil
	end)
	local holder = scope:New("Frame")({
		Name = "PreviewHolder",
		Size = UDim2.new(1, 0, 0, PREVIEW),
		BackgroundColor3 = Theme.Paper.Sunken,
		Visible = shown,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			api.frame,
		},
	})
	return holder, shown
end

local function scroller(scope: Scope, ctx: Context.Ctx, offset: Fusion.Computed<number>, bottom: number): Instance
	local lines = scope:Computed(function(use, s: Scope): { Instance }
		return BestiaryTab.lines(s, use, ctx)
	end)
	return scope:New("ScrollingFrame")({
		Name = "Lines",
		Position = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(0, use(offset))
		end),
		Size = scope:Computed(function(use): UDim2
			local top: number = use(offset)
			return UDim2.new(1, 0, 1, -(top + bottom))
		end),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Label,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
			lines :: any,
		},
	})
end

-- PC: the panel at the right edge (shown while the bestiary tab is open).
function BestiaryTab.panel(scope: Scope, ctx: Context.Ctx, width: number): Instance
	local holder, shown = preview(scope, ctx)
	local offset = scope:Computed(function(use): number
		return if use(shown) then PREVIEW + GAP else 0
	end)
	return scope:New("Frame")({
		Name = "BestiaryDetails",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, width, 1, 0),
		BackgroundColor3 = Theme.Paper.Raised,
		Visible = scope:Computed(function(use): boolean
			return use(ctx.cat) == Context.BESTIARY
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Paper.Border,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Padding.Medium),
				PaddingBottom = UDim.new(0, Theme.Padding.Medium),
				PaddingLeft = UDim.new(0, Theme.Padding.Medium),
				PaddingRight = UDim.new(0, Theme.Padding.Medium),
			}),
			holder,
			scroller(scope, ctx, offset, 0),
		},
	})
end

-- Phone: the sheet over the window (Back, the preview, the lines).
function BestiaryTab.sheet(scope: Scope, ctx: Context.Ctx): Instance
	local height = Theme.Size.MinTouch
	local holder, shown = preview(scope, ctx)
	local offset = scope:Computed(function(use): number
		return TOP + GAP + (if use(shown) then PREVIEW + GAP else 0)
	end)
	local holderFrame = holder :: Frame
	holderFrame.Position = UDim2.fromOffset(0, TOP + GAP)
	return scope:New("TextButton")({
		Name = "BestiarySheet",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Paper.Surface,
		Text = "",
		ZIndex = 10,
		Visible = scope:Computed(function(use): boolean
			return use(ctx.cat) == Context.BESTIARY and use(ctx.sheet) and use(ctx.entry) ~= nil
		end),
		[OnEvent("Activated")] = function() end,
		[Children] = {
			Button(scope, {
				Size = UDim2.fromOffset(height + 72, height),
				Variant = "ghost",
				TextSize = Theme.TextSize.Small,
				Text = scope:Computed(function(use): string
					return `← {Text.get(use, "ach.back")}`
				end),
				OnClick = function()
					ctx.sheet:set(false)
				end,
			}),
			holder,
			scroller(scope, ctx, offset, 0),
		},
	})
end

return BestiaryTab
