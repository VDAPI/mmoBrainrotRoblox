--!strict
-- Skills window (K), DESIGN §23: the class tree as a graph (icons with "level/max", requirement lines,
-- locked nodes grey with their unlock level) and a details panel for the selected skill (current and next
-- level, cost, cooldown, range, requirements, "Learn"). Learned active skills can be dragged onto the bar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local NODE = 64
local COL_STEP = 100
local ROW_STEP = 94
local TREE_WIDTH = 4 * COL_STEP
local TREE_HEIGHT = 6 * ROW_STEP

local function nodeCenter(skill: SkillData.SkillDef): Vector2
	return Vector2.new((skill.col - 0.5) * COL_STEP, (skill.row - 0.5) * ROW_STEP)
end

local function SkillsWindow(scope: Scope, showModal: (spec: any) -> ()): Fusion.Child
	local classId = State.Value({ "character", "class" })
	local skillLevels = State.Value({ "character", "skills" })
	local points = State.Value({ "character", "skillPoints" })
	local level = State.Value({ "character", "level" })
	local selected = scope:Value(nil :: string?)
	local busy = false

	local function levelOf(use: Fusion.Use, id: string): number
		local levels = use(skillLevels)
		return if type(levels) == "table" then levels[id] or 0 else 0
	end

	local function learn(id: string)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local ok, err, detail = Net.Invoke("LearnSkill", id)
			busy = false
			if ok then
				Sounds.play("levelUp")
				return
			end
			local args: { [string]: any } = {}
			if type(detail) == "number" then
				args.level = detail
			elseif type(detail) == "table" then
				local other = SkillData.get(detail.skill)
				args.skill = if other then Text.now(other.nameKey) else detail.skill
				args.level = detail.level
			end
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal", args), "error")
		end)
	end

	-- Tree (rebuilt when the class changes)
	local tree = scope:Computed(function(use, s: Scope): { Instance }
		local list: { Instance } = {}
		local skills: { SkillData.SkillDef } = SkillData.byClass[use(classId) or ""] or {}
		local class = Classes.get(use(classId) or "")
		local accent = if class then Color3.fromHex(class.color) else Theme.Colors.Gold
		-- Requirement lines first (under the nodes).
		for _, skill in skills do
			local requires: { { skill: string, level: number } } = skill.requires or {}
			for _, requirement in requires do
				local other = SkillData.get(requirement.skill)
				if other then
					local a, b = nodeCenter(other), nodeCenter(skill)
					local delta = b - a
					table.insert(
						list,
						s:New("Frame")({
							Name = `Line_{other.id}_{skill.id}`,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
							Size = UDim2.fromOffset(delta.Magnitude, 4),
							Rotation = math.deg(math.atan2(delta.Y, delta.X)),
							BackgroundColor3 = s:Computed(function(use2): Color3
								return if levelOf(use2, other.id) >= requirement.level
									then Theme.Colors.Gold
									else Theme.Colors.Border
							end),
							BorderSizePixel = 0,
							ZIndex = 1,
						})
					)
				end
			end
		end
		for _, skill in skills do
			local center = nodeCenter(skill)
			local current = s:Computed(function(use2): number
				return levelOf(use2, skill.id)
			end)
			local locked = s:Computed(function(use2): boolean
				return (use2(level) or 1) < skill.unlock
			end)
			local node = s:New("TextButton")({
				Name = skill.id,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(center.X, center.Y),
				Size = UDim2.fromOffset(NODE, NODE),
				AutoButtonColor = false,
				BackgroundColor3 = s:Computed(function(use2): Color3
					if use2(selected) == skill.id then
						return Theme.Colors.PanelHover
					end
					return if use2(locked) then Theme.Colors.Background else Theme.Colors.PanelRaised
				end),
				Text = "",
				ZIndex = 2,
				[OnEvent("Activated")] = function()
					selected:set(skill.id)
				end,
				[Children] = {
					s:New("UICorner")({
						CornerRadius = if skill.type == "passive" then Theme.Corner.Round else Theme.Corner.Small,
					}),
					s:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = s:Computed(function(use2): number
							return if use2(selected) == skill.id then 3 else 2
						end),
						Color = s:Computed(function(use2): Color3
							if use2(selected) == skill.id then
								return Theme.Colors.GoldBright
							end
							return if use2(current) > 0 then accent else Theme.Colors.Border
						end),
					}),
					s:New("TextLabel")({
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = skill.glyph,
						TextScaled = true,
						FontFace = Theme.Fonts.BodyBold,
						TextColor3 = s:Computed(function(use2): Color3
							if use2(locked) then
								return Theme.Colors.Border
							end
							return if use2(current) > 0 then accent else Theme.Colors.TextMuted
						end),
						ZIndex = 3,
						[Children] = s:New("UIPadding")({
							PaddingTop = UDim.new(0.18, 0),
							PaddingBottom = UDim.new(0.18, 0),
							PaddingLeft = UDim.new(0.18, 0),
							PaddingRight = UDim.new(0.18, 0),
						}),
					}),
					s:New("TextLabel")({
						Name = "Level",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 1, 2),
						Size = UDim2.fromOffset(NODE + 20, 18),
						BackgroundTransparency = 1,
						Text = s:Computed(function(use2): string
							if use2(locked) then
								return `Lv {skill.unlock}`
							end
							return `{use2(current)}/{skill.maxLevel}`
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 13,
						TextColor3 = s:Computed(function(use2): Color3
							return if use2(locked) then Theme.Colors.TextMuted else Theme.Colors.Parchment
						end),
						ZIndex = 3,
					}),
				},
			})
			DragDrop.register(s, node :: GuiObject, `skill:{skill.id}`)
			table.insert(list, node)
		end
		return list
	end)

	-- Details of the selected skill
	local details = scope:Computed(function(use, s: Scope): { Instance }
		local id = use(selected)
		local skill = id and SkillData.get(id)
		if not skill then
			return {
				s:New("TextLabel")({
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 40),
					Text = Text.get(use, "skills.dragHint"),
					TextWrapped = true,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.TextMuted,
				}),
			}
		end
		local lang = use(Text.Lang)
		local current = levelOf(use, skill.id)
		local order = 0
		local out: { Instance } = {}
		local function line(text: string, color: Color3?, size: number?, font: Font?)
			order += 1
			table.insert(
				out,
				s:New("TextLabel")({
					LayoutOrder = order,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Text = text,
					RichText = true,
					TextWrapped = true,
					FontFace = font or Theme.Fonts.Body,
					TextSize = size or Theme.TextSize.Small,
					TextColor3 = color or Theme.Colors.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
		end
		line(Text.get(use, skill.nameKey), Theme.Colors.Gold, Theme.TextSize.Large, Theme.Fonts.Heading)
		local header = Text.get(use, "skills.level", { level = current, max = skill.maxLevel })
		if skill.type == "passive" then
			header ..= ` · {Text.get(use, "skills.passive")}`
		end
		line(header, Theme.Colors.Parchment, Theme.TextSize.Body, Theme.Fonts.BodyBold)
		if skill.type ~= "passive" then
			local shown = math.max(1, current)
			local cost = Skills.scaled(skill, skill.cost, shown)
			local parts = {}
			if cost > 0 and skill.resource then
				table.insert(parts, Text.get(use, `skills.cost.{skill.resource}`, { cost = math.floor(cost) }))
			end
			table.insert(
				parts,
				Text.get(use, "skills.cooldown", { cooldown = Skills.scaled(skill, skill.cooldown, shown) })
			)
			if skill.range then
				table.insert(parts, Text.get(use, "skills.range", { range = skill.range }))
			end
			line(table.concat(parts, " · "), Theme.Colors.TextMuted)
		end
		line(Text.get(use, "skills.current"), Theme.Colors.Gold, nil, Theme.Fonts.BodyBold)
		if current > 0 then
			line(Skills.formatDescription(skill, current, lang))
		else
			line(Text.get(use, "skills.notLearned"), Theme.Colors.TextMuted)
		end
		if current < skill.maxLevel then
			line(Text.get(use, "skills.next"), Theme.Colors.Gold, nil, Theme.Fonts.BodyBold)
			line(Skills.formatDescription(skill, current + 1, lang), Theme.Colors.Success)
			local needed = Skills.levelRequirement(skill, current + 1)
			if (use(level) or 1) < needed then
				line(Text.get(use, "skills.requiresLevel", { level = needed }), Theme.Colors.DangerHover)
			end
			local requires: { { skill: string, level: number } } = skill.requires or {}
			for _, requirement in requires do
				local other = SkillData.get(requirement.skill)
				if other and levelOf(use, other.id) < requirement.level then
					line(
						Text.get(
							use,
							"skills.requires",
							{ skill = Text.get(use, other.nameKey), level = requirement.level }
						),
						Theme.Colors.DangerHover
					)
				end
			end
		end
		return out
	end)

	local canLearn = scope:Computed(function(use): boolean
		local id = use(selected)
		local skill = id and SkillData.get(id)
		if not skill then
			return false
		end
		use(skillLevels)
		use(points)
		use(level)
		local char = State.Get({ "character" })
		return char ~= nil and (Skills.canLearn(char, skill.id))
	end)

	return {
		scope:New("TextLabel")({
			Name = "Points",
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				return Text.get(use, "skills.points", { points = use(points) or 0 })
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Body,
			TextColor3 = scope:Computed(function(use): Color3
				return if (use(points) or 0) > 0 then Theme.Colors.Success else Theme.Colors.TextMuted
			end),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("ScrollingFrame")({
			Name = "Tree",
			Position = UDim2.fromOffset(0, 36),
			Size = UDim2.new(0, TREE_WIDTH + 12, 1, -36),
			CanvasSize = UDim2.fromOffset(TREE_WIDTH, TREE_HEIGHT + 20),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Colors.GoldDim,
			[Children] = tree :: any,
		}),
		scope:New("Frame")({
			Name = "Details",
			Position = UDim2.fromOffset(TREE_WIDTH + 24, 36),
			Size = UDim2.new(1, -(TREE_WIDTH + 24), 1, -36),
			BackgroundColor3 = Theme.Colors.PanelRaised,
			BackgroundTransparency = 0.3,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, Theme.Padding.Medium),
					PaddingBottom = UDim.new(0, Theme.Padding.Medium),
					PaddingLeft = UDim.new(0, Theme.Padding.Medium),
					PaddingRight = UDim.new(0, Theme.Padding.Medium),
				}),
				scope:New("ScrollingFrame")({
					Size = UDim2.new(1, 0, 1, -(Theme.Size.ButtonHeight * 2 + 20)),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 4,
					[Children] = {
						scope:New("UIListLayout")({
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 6),
						}),
						details :: any,
					},
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, -(Theme.Size.ButtonHeight + 8)),
					Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
					Variant = "primary",
					Text = Text.T(scope, "skills.learn"),
					Disabled = scope:Computed(function(use): boolean
						return not use(canLearn)
					end),
					OnClick = function()
						local id = Fusion.peek(selected)
						if id then
							learn(id)
						end
					end,
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeightSmall),
					Variant = "ghost",
					TextSize = Theme.TextSize.Small,
					Text = Text.T(scope, "skills.reset"),
					OnClick = function()
						local char = State.Get({ "character" })
						showModal({
							Title = Text.now("skills.reset.title"),
							Message = Text.now(
								"skills.reset.message",
								{ points = if char then Skills.spentPoints(char) else 0 }
							),
							ConfirmText = Text.now("common.confirm"),
							CancelText = Text.now("common.cancel"),
							Variant = "danger",
							OnConfirm = function(): (boolean, string?)
								local ok, err = Net.Invoke("ResetSkills")
								if ok then
									Toast.push(Text.now("skills.reset.done"), "success")
									return true, nil
								end
								return false, Text.now(err or "error.internal")
							end,
						})
					end,
				}),
			},
		}),
	}
end

return SkillsWindow
