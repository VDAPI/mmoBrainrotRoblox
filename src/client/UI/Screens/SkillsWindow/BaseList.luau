--!strict
-- "Base" tab of the skills window (S56 rows, S59 layout): one row per skill of the class without a path, in data
-- order: the tile (draggable onto the bar once unlocked), the name with breakpoint badges (5A / 10B; "5?" with a dot
-- when option B waits for a choice), "Rank 6/10 · next at lv. 26" and "To bar" / "On bar: 3" / "Passive". A click
-- selects the skill (on a phone it also opens the details sheet).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Context = require(script.Parent.Context)
local DragDrop = require(script.Parent.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local TILE = 44
local GOLD_HEX = "#E8C66A"
local MUTED_HEX = "#7A746A"
local WARN_HEX = "#E0A23B"
local DANGER_HEX = "#CC5248"

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
		BackgroundColor3 = if unlocked then Theme.Colors.PanelRaised else Theme.Colors.Background,
		[Children] = {
			s:New("UICorner")({ CornerRadius = corner }),
			s:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 2,
				Color = if unlocked then accent else Theme.Colors.Border,
			}),
			-- Wrong weapon element (Mage, S18): greyed out.
			s:New("Frame")({
				Name = "ElementTint",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromHex("#2A2A2E"),
				BackgroundTransparency = 0.3,
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
				ImageColor = if unlocked then nil else Color3.fromRGB(150, 150, 150),
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
				TextColor3 = if unlocked then accent else Theme.Colors.Border,
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

-- "Fireball  5A 10?" (RichText): the working option per breakpoint rank, gold once reached; "?" and a dot while
-- option B waits for a choice.
function BaseList.badges(skill: SkillData.SkillDef, rank: number, choices: Skills.Choices?): string
	if skill.type == "passive" or not skill.breakpoints then
		return ""
	end
	local out = {}
	for _, at in Skills.BREAKPOINT_LEVELS do
		local pair = skill.breakpoints[at]
		if pair then
			local pending = pair.b ~= nil
				and rank >= at
				and (choices == nil or choices[Skills.choiceKey(skill.id, at)] == nil)
			if pending then
				table.insert(out, `<font color="{WARN_HEX}">{at}?</font><font color="{DANGER_HEX}">●</font>`)
			else
				local option = string.upper(Skills.chosen(skill, at, choices))
				table.insert(out, `<font color="{if rank >= at then GOLD_HEX else MUTED_HEX}">{at}{option}</font>`)
			end
		end
	end
	return table.concat(out, " ")
end

function BaseList.new(scope: Scope, ctx: Context.Ctx, actions: Actions.Actions, touch: boolean): Fusion.Computed<any>
	local rowHeight = if touch then 64 else 56
	local buttonHeight = if touch then Theme.Size.MinTouch else 32

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
		local accent = if class then Color3.fromHex(class.color) else Theme.Colors.Gold
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
				TextSize = 14,
				TextColor3 = Theme.Colors.TextMuted,
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
			tileAny.Position = UDim2.fromOffset(6, (rowHeight - TILE) / 2)
			local badges = BaseList.badges(skill, rank, choices)
			local name = Text.get(use, skill.nameKey)
			local sub = if not unlocked
				then Text.get(use, "skills.unlockAt", { level = skill.unlock })
				else `{Text.get(use, "skills.rank", { rank = rank, max = skill.maxLevel })} · {if rank
						< skill.maxLevel
					then Text.get(use, "skills.nextAt", { level = Skills.rankLevel(skill, rank + 1) })
					else Text.get(use, "skills.maxed")}`
			table.insert(
				list,
				s:New("TextButton")({
					Name = skill.id,
					LayoutOrder = i,
					Size = UDim2.new(1, -8, 0, rowHeight),
					AutoButtonColor = false,
					BackgroundColor3 = s:Computed(function(use2): Color3
						local sel = use2(ctx.selected)
						return if sel and sel.id == skill.id then Theme.Colors.PanelHover else Theme.Colors.PanelRaised
					end),
					BackgroundTransparency = s:Computed(function(use2): number
						local sel = use2(ctx.selected)
						return if sel and sel.id == skill.id then 0 else 0.6
					end),
					Text = "",
					[OnEvent("Activated")] = function()
						ctx.selected:set({ kind = "skill", id = skill.id })
						if touch then
							ctx.previewOpen:set(false)
							ctx.sheet:set(true)
						end
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						tile,
						s:New("TextLabel")({
							Name = "Name",
							Position = UDim2.fromOffset(TILE + 16, rowHeight / 2 - 22),
							Size = UDim2.new(1, -(TILE + 16 + 112), 0, 22),
							BackgroundTransparency = 1,
							RichText = true,
							Text = if badges ~= "" then `{name}  {badges}` else name,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if unlocked then Theme.Colors.Parchment else Theme.Colors.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							Name = "Rank",
							Position = UDim2.fromOffset(TILE + 16, rowHeight / 2),
							Size = UDim2.new(1, -(TILE + 16 + 112), 0, 20),
							BackgroundTransparency = 1,
							Text = sub,
							FontFace = Theme.Fonts.Body,
							TextSize = 14,
							TextColor3 = Theme.Colors.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						if unlocked and not passive
							then Button(s, {
								AnchorPoint = Vector2.new(1, 0.5),
								Position = UDim2.new(1, -8, 0.5, 0),
								Size = UDim2.fromOffset(96, buttonHeight),
								Variant = "secondary",
								TextSize = 14,
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
							Size = UDim2.fromOffset(100, 20),
							BackgroundTransparency = 1,
							Text = s:Computed(function(use2): string
								if passive then
									return Text.get(use2, "skills.passive")
								end
								local slot = use2(onBar)
								return if slot then Text.get(use2, "skills.onBar", { slot = slot }) else ""
							end),
							FontFace = Theme.Fonts.Body,
							TextSize = 14,
							TextColor3 = Theme.Colors.TextMuted,
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
