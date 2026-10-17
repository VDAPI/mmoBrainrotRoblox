--!strict
-- "Base" tab of the skills window (S56 rows, S59 layout): one row per skill of the class without a path, in data
-- order: the tile (draggable onto the bar once unlocked), the name with breakpoint badges (5A / 10B; "5?" with a dot
-- when option B waits for a choice), "Rank 6/10 · next at lv. 26" and "To bar" / "On bar: 3" / "Passive". A click
-- selects the skill (on a phone it also opens the details sheet).
-- S135 (owner: "the text on the left blends together"): every row is a ListRow (alternating parchment, a rule, the
-- selected row with a brass bar), the name in Body ink, the rank line in Small muted ink, breakpoint badges as small
-- raised plaques, "To bar" a secondary button; a locked row is muted with a padlock, never grey on grey.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Context = require(script.Parent.Context)
local DragDrop = require(script.Parent.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ListRow = require(script.Parent.Parent.Parent.Components.ListRow)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local TILE = 44
local BADGE_W = 38
local BADGE_GAP = 4
local BUTTON_W = 104

local BaseList = {}

-- The skill tile: glyph in the class colour (S119: the skill's picture once loaded), round for passives, greyed while
-- the weapon element does not fit.
function BaseList.tile(
	s: Scope,
	ctx: Context.Ctx,
	skill: SkillData.SkillDef,
	unlocked: boolean,
	accent: Color3,
	size: number
): Instance
	local corner = if skill.type == "passive" then Theme.Corner.Round else Theme.Corner.Small
	local shown = ArtIcon.Shown(s, UiArt.skill(skill.id))
	local tile = s:New("Frame")({
		Name = "Tile",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = if unlocked then Theme.Paper.Raised else Theme.Paper.Sunken,
		[Children] = {
			s:New("UICorner")({ CornerRadius = corner }),
			s:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = if unlocked then accent else Theme.Paper.Border,
			}),
			-- Wrong weapon element (Mage, S18): greyed out.
			s:New("Frame")({
				Name = "ElementTint",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Iron.Surface,
				BackgroundTransparency = 0.35,
				ZIndex = 5,
				Visible = s:Computed(function(use): boolean
					local weapon = use(ctx.weapon)
					return not Skills.elementAllowed(skill, if type(weapon) == "table" then weapon.element else nil)
				end),
				[Children] = s:New("UICorner")({ CornerRadius = corner }),
			}),
			-- S119: the skill's picture over the whole tile once loaded (dimmed while locked), the glyph otherwise.
			ArtIcon.Image(s, {
				Key = UiArt.skill(skill.id),
				ZIndex = 2,
				Corner = corner,
				ImageColor = if unlocked then nil else Theme.mix(Theme.Plain, Theme.Shade, 0.4),
				Transparency = if unlocked then 0 else 0.35,
			}),
			s:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = s:Computed(function(use): string
					return if use(shown) then "" else skill.glyph
				end),
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = if unlocked then accent else Theme.Paper.TextMuted,
				ZIndex = 3,
				[Children] = s:New("UIPadding")({
					PaddingTop = UDim.new(0.18, 0),
					PaddingBottom = UDim.new(0.18, 0),
					PaddingLeft = UDim.new(0.18, 0),
					PaddingRight = UDim.new(0.18, 0),
				}),
			}),
		},
	})
	if unlocked and skill.type ~= "passive" then
		DragDrop.register(s, tile :: GuiObject, `skill:{skill.id}`)
	end
	return tile
end

export type Badge = { text: string, reached: boolean, pending: boolean }

-- S135: the breakpoint badges of a row ("5A", "10B"; "5?" while option B waits for a choice).
function BaseList.badgeList(skill: SkillData.SkillDef, rank: number, choices: Skills.Choices?): { Badge }
	local out: { Badge } = {}
	if skill.type == "passive" or not skill.breakpoints then
		return out
	end
	for _, at in Skills.BREAKPOINT_LEVELS do
		local pair = skill.breakpoints[at]
		if pair then
			local pending = pair.b ~= nil
				and rank >= at
				and (choices == nil or choices[Skills.choiceKey(skill.id, at)] == nil)
			local option = if pending then "?" else string.upper(Skills.chosen(skill, at, choices))
			table.insert(out, { text = `{at}{option}`, reached = rank >= at, pending = pending })
		end
	end
	return out
end

-- One plaque: raised with an edge and ink text once reached, sunken and muted before, warning text and a red dot
-- while a choice waits.
function BaseList.badge(s: Scope, badge: Badge, order: number): Instance
	return s:New("TextLabel")({
		Name = `Badge{order}`,
		LayoutOrder = order,
		Size = UDim2.fromOffset(BADGE_W, 24),
		BackgroundColor3 = if badge.reached then Theme.Paper.Raised else Theme.Paper.Sunken,
		RichText = true,
		Text = if badge.pending
			then `{badge.text}<font color="{Theme.hex(Theme.Paper.Danger)}">●</font>`
			else badge.text,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Caption,
		TextColor3 = if badge.pending
			then Theme.Paper.Warning
			elseif badge.reached then Theme.Paper.Text
			else Theme.Paper.TextMuted,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			s:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = if badge.reached then Theme.Paper.Border else Theme.Paper.Rule,
			}),
		},
	})
end

function BaseList.new(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions, touch: boolean): Fusion.Computed<any>
	local rowHeight = if touch then 68 else 60
	local buttonHeight = if touch then Theme.Size.MinTouch else 36

	return scope:Computed(function(use, s: Scope): { Instance }
		if use(ctx.activeTab) ~= "base" then
			return {}
		end
		local character = use(ctx.character)
		if not character then
			return {}
		end
		local skills: { SkillData.SkillDef } = {}
		local classSkills: { SkillData.SkillDef } = SkillData.byClass[character.class] or {}
		for _, skill in classSkills do
			if skill.path == nil then
				table.insert(skills, skill)
			end
		end
		table.sort(skills, function(a, b)
			return a.order < b.order
		end)
		local choices = if character.path then character.path.bp else nil
		local class = Classes.get(character.class)
		-- S135: the class colour made readable on parchment
		local accent = if class then Theme.readable(class.color, "paper") else Theme.Paper.Heading
		local list: { Instance } = {
			s:New("TextLabel")({
				Name = "Hint",
				LayoutOrder = 0,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = Text.get(use, "skills.hint"),
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}
		for i, skill in skills do
			local rank = Paths.skillRank(character, skill.id)
			local unlocked = rank > 0
			local passive = skill.type == "passive"
			local onBar = s:Computed(function(use2): string?
				return Actions.slotOf(use2(ctx.hotbar), skill.id)
			end)
			local tile = BaseList.tile(s, ctx, skill, unlocked, accent, TILE)
			local tileAny = tile :: any
			tileAny.Position = UDim2.fromOffset(10, (rowHeight - TILE) / 2)
			local badges = BaseList.badgeList(skill, rank, choices)
			local badgeWidth = if #badges > 0 then #badges * (BADGE_W + BADGE_GAP) else 0
			local name = Text.get(use, skill.nameKey)
			local sub = if not unlocked
				then `🔒 {Text.get(use, "skills.unlockAt", { level = skill.unlock })}`
				else `{Text.get(use, "skills.rank", { rank = rank, max = skill.maxLevel })} · {if rank
						< skill.maxLevel
					then Text.get(use, "skills.nextAt", { level = Skills.rankLevel(skill, rank + 1) })
					else Text.get(use, "skills.maxed")}`
			local plaques: { Instance } = {}
			for n, badge in badges do
				table.insert(plaques, BaseList.badge(s, badge, n))
			end
			table.insert(
				list,
				ListRow(s, {
					Name = skill.id,
					LayoutOrder = i,
					Index = i,
					Height = rowHeight,
					Inset = TILE + 12,
					RightInset = BUTTON_W + 12 + badgeWidth,
					Text = name,
					Sub = sub,
					Muted = not unlocked,
					Selected = s:Computed(function(use2): boolean
						local sel = use2(ctx.selected)
						return sel ~= nil and sel.id == skill.id
					end),
					OnClick = function()
						ctx.selected:set({ kind = "skill", id = skill.id })
						if touch then
							ctx.previewOpen:set(false)
							ctx.sheet:set(true)
						end
					end,
					[Children] = {
						tile,
						s:New("Frame")({
							Name = "Badges",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -(BUTTON_W + 12), 0.5, 0),
							Size = UDim2.fromOffset(badgeWidth, 24),
							BackgroundTransparency = 1,
							Visible = #badges > 0,
							[Children] = {
								s:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Horizontal,
									SortOrder = Enum.SortOrder.LayoutOrder,
									Padding = UDim.new(0, BADGE_GAP),
								}),
								plaques :: any,
							},
						}),
						if unlocked and not passive
							then Button(s, {
								AnchorPoint = Vector2.new(1, 0.5),
								Position = UDim2.new(1, -8, 0.5, 0),
								Size = UDim2.fromOffset(BUTTON_W, buttonHeight),
								Variant = "secondary",
								TextSize = Theme.TextSize.Small,
								Text = Text.get(use, "skills.toBar"),
								Visible = s:Computed(function(use2): boolean
									return use2(onBar) == nil
								end),
								OnClick = function()
									actions.toBar(skill.id)
								end,
							}) :: any
							else nil,
						s:New("TextLabel")({
							Name = "Status",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -8, 0.5, 0),
							Size = UDim2.fromOffset(BUTTON_W, 22),
							BackgroundTransparency = 1,
							Text = s:Computed(function(use2): string
								if passive then
									return Text.get(use2, "skills.passive")
								end
								local slot = use2(onBar)
								return if slot then Text.get(use2, "skills.onBar", { slot = slot }) else ""
							end),
							FontFace = Theme.Fonts.BodyMedium,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Right,
						}),
					},
				})
			)
		end
		return list
	end)
end

return BaseList
