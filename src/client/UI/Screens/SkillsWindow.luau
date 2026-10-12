--!strict
-- Skills window (K), DESIGN §23. S56 (ROZWOJ 3.3, 4): ranks grow with the character level, so the window is a list
-- of the class's skills (rank "6/10", the level of the next rank or "From lv. 34", breakpoint badges 5A / 10A) with
-- "To bar", and a details panel for the selected skill (current and next rank, cost, cooldown, range, element,
-- breakpoints). A full bar opens a 2 x 5 slot picker: the chosen slot is replaced. Unlocked actives can be dragged
-- onto the bar. The full window (920 x 640, paths) comes in S59.
-- S28: "Preview": a copy of the character in a viewport plays the skill's animation and effect (VfxController.Preview).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Elements = require(ReplicatedStorage.Shared.Data.Elements)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Pool = require(script.Parent.Parent.Parent.Vfx.Pool)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local SkillInfo = require(script.Parent.Parent.SkillInfo)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local LIST_WIDTH = 400
local ROW_HEIGHT = 56
local TILE = 44
local HEADER_HEIGHT = 36
local PREVIEW_HEIGHT = 150
local PICK_CELL = 64

local GOLD_HEX = "#E8C66A"
local MUTED_HEX = "#7A746A"

-- A still copy of the local character for the preview viewport (scripts and plates removed, root anchored).
local function mannequin(): Model?
	local character = game:GetService("Players").LocalPlayer.Character
	if not character then
		return nil
	end
	local was = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = was
	if not copy then
		return nil
	end
	for _, item in copy:GetDescendants() do
		if
			item:IsA("LuaSourceContainer")
			or item:IsA("BillboardGui")
			or item:IsA("ProximityPrompt")
			or item:IsA("Sound")
			or item:IsA("ForceField")
		then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = item.Name == "HumanoidRootPart"
			item.CanCollide = false
		end
	end
	copy:SetAttribute("VaelthornPreview", true)
	copy:SetAttribute("EntityId", nil)
	copy:PivotTo(CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(180), 0))
	return copy
end

-- Slot ("1".."10") holding `id` on `bar`, or nil.
local function slotOf(bar: any, id: string): string?
	if type(bar) ~= "table" then
		return nil
	end
	for slot, existing in bar do
		if existing == id then
			return slot
		end
	end
	return nil
end

local function SkillsWindow(scope: Scope, preview: ((model: Model, skillId: string) -> ())?): Fusion.Child
	local classId = State.Value({ "character", "class" })
	local level = State.Value({ "character", "level" })
	local hotbar = State.Value({ "character", "hotbar" })
	local weaponState = State.Value({ "derived", "weapon" })
	local selected = scope:Value(nil :: string?)
	local picking = scope:Value(nil :: string?)
	local busy = false

	local function rankOf(use: Fusion.Use, skill: SkillData.SkillDef): number
		return Skills.rankFor(use(classId), use(level) or 1, skill)
	end

	local function fail(err: string?)
		Sounds.play("error")
		Toast.push(Text.now(err or "error.internal"), "error")
	end

	-- "To bar": the first free slot, or the 2 x 5 picker when the bar is full.
	local function toBar(id: string)
		if busy then
			return
		end
		local bar = Fusion.peek(hotbar)
		local current = if type(bar) == "table" then bar else {}
		if slotOf(current, id) == nil and Skills.firstFreeSlot(current) == nil then
			picking:set(id)
			return
		end
		busy = true
		task.spawn(function()
			local ok, err = Net.Invoke("PutOnBar", id)
			busy = false
			if ok then
				return
			end
			if err == "skills.error.barFull" then
				picking:set(id)
			else
				fail(err)
			end
		end)
	end

	local function pickSlot(slot: number)
		local id = Fusion.peek(picking)
		if busy or not id then
			return
		end
		busy = true
		task.spawn(function()
			local ok, err = Net.Invoke("PutOnBar", id, slot)
			busy = false
			if ok then
				picking:set(nil)
			else
				fail(err)
			end
		end)
	end

	-- List (rebuilt when the class or the level changes: unlocks decide what can be dragged)
	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local list: { Instance } = {}
		local skills: { SkillData.SkillDef } = table.clone(SkillData.byClass[use(classId) or ""] or {})
		table.sort(skills, function(a, b)
			return a.order < b.order
		end)
		local class = Classes.get(use(classId) or "")
		local accent = if class then Color3.fromHex(class.color) else Theme.Colors.Gold
		for i, skill in skills do
			local rank = rankOf(use, skill)
			local unlocked = rank > 0
			local passive = skill.type == "passive"
			local corner = if passive then Theme.Corner.Round else Theme.Corner.Small
			local onBarSlot = s:Computed(function(use2): string?
				return slotOf(use2(hotbar), skill.id)
			end)
			local tile = s:New("Frame")({
				Name = "Tile",
				Position = UDim2.fromOffset(6, (ROW_HEIGHT - TILE) / 2),
				Size = UDim2.fromOffset(TILE, TILE),
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
						Visible = s:Computed(function(use2): boolean
							local weapon = use2(weaponState)
							return not Skills.elementAllowed(
								skill,
								if type(weapon) == "table" then weapon.element else nil
							)
						end),
						[Children] = s:New("UICorner")({ CornerRadius = corner }),
					}),
					s:New("TextLabel")({
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = skill.glyph,
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
			if unlocked and not passive then
				DragDrop.register(s, tile :: GuiObject, `skill:{skill.id}`)
			end
			table.insert(
				list,
				s:New("TextButton")({
					Name = skill.id,
					LayoutOrder = i,
					Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
					AutoButtonColor = false,
					BackgroundColor3 = s:Computed(function(use2): Color3
						return if use2(selected) == skill.id then Theme.Colors.PanelHover else Theme.Colors.PanelRaised
					end),
					BackgroundTransparency = s:Computed(function(use2): number
						return if use2(selected) == skill.id then 0 else 0.6
					end),
					Text = "",
					[OnEvent("Activated")] = function()
						selected:set(skill.id)
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						tile,
						s:New("TextLabel")({
							Name = "Name",
							Position = UDim2.fromOffset(TILE + 16, 6),
							Size = UDim2.new(1, -(TILE + 16 + 110), 0, 22),
							BackgroundTransparency = 1,
							RichText = true,
							Text = s:Computed(function(use2): string
								local name = Text.get(use2, skill.nameKey)
								if passive or not skill.breakpoints then
									return name
								end
								-- S56: badges of the breakpoint ranks, gold once reached (option A until S57)
								local badges = {}
								for _, at in Skills.BREAKPOINT_LEVELS do
									if skill.breakpoints[at] then
										local option = string.upper(Skills.chosen(skill, at, nil))
										local color = if rank >= at then GOLD_HEX else MUTED_HEX
										table.insert(badges, `<font color="{color}">{at}{option}</font>`)
									end
								end
								return `{name}  {table.concat(badges, " ")}`
							end),
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if unlocked then Theme.Colors.Parchment else Theme.Colors.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							Name = "Rank",
							Position = UDim2.fromOffset(TILE + 16, 28),
							Size = UDim2.new(1, -(TILE + 16 + 110), 0, 20),
							BackgroundTransparency = 1,
							Text = s:Computed(function(use2): string
								if not unlocked then
									return Text.get(use2, "skills.unlockAt", { level = skill.unlock })
								end
								local text = Text.get(use2, "skills.rank", { rank = rank, max = skill.maxLevel })
								local tail = if rank < skill.maxLevel
									then Text.get(use2, "skills.nextAt", { level = Skills.rankLevel(skill, rank + 1) })
									else Text.get(use2, "skills.maxed")
								return `{text} · {tail}`
							end),
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
								Size = UDim2.fromOffset(96, 32),
								Variant = "secondary",
								TextSize = 14,
								Text = Text.T(s, "skills.toBar"),
								Visible = s:Computed(function(use2): boolean
									return use2(onBarSlot) == nil
								end),
								OnClick = function()
									toBar(skill.id)
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
								local slot = use2(onBarSlot)
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
		local rank = rankOf(use, skill)
		local shown = math.max(1, rank)
		local opts = { level = use(level) or 1 }
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
		local header = Text.get(use, "skills.rank", { rank = rank, max = skill.maxLevel })
		if skill.type == "passive" then
			header ..= ` · {Text.get(use, "skills.passive")}`
		end
		line(header, Theme.Colors.Parchment, Theme.TextSize.Body, Theme.Fonts.BodyBold)
		if rank <= 0 then
			line(Text.get(use, "skills.unlockAt", { level = skill.unlock }), Theme.Colors.DangerHover)
		end
		if skill.type ~= "passive" then
			local shape = SkillInfo.shapeLine(use, skill, shown)
			if shape ~= "" then
				line(shape, Theme.Colors.Parchment)
			end
			line(SkillInfo.costLine(use, skill, shown), Theme.Colors.TextMuted)
		end
		-- Weapon element (Mage, S18): requirement in red while the weapon does not fit, adaptive note.
		local element = Skills.requiredElement(skill)
		if element then
			local weapon = use(weaponState)
			local fits = type(weapon) == "table" and weapon.element == element
			line(
				Text.get(use, "skill.requiresElement", { element = Text.get(use, `element.{element}`) }),
				if fits then Color3.fromHex(Elements.COLORS[element]) else Theme.Colors.DangerHover
			)
		elseif skill.adaptive then
			line(Text.get(use, "skill.adaptive"), Theme.Colors.Parchment)
		end
		line(
			Text.get(use, if rank > 0 then "skills.current" else "skills.notLearned"),
			Theme.Colors.Gold,
			nil,
			Theme.Fonts.BodyBold
		)
		line(Skills.formatDescription(skill, shown, lang, opts))
		if rank < skill.maxLevel then
			local nextRank = rank + 1
			line(Text.get(use, "skills.next"), Theme.Colors.Gold, nil, Theme.Fonts.BodyBold)
			line(
				Text.get(use, "skills.nextRank", { rank = nextRank, level = Skills.rankLevel(skill, nextRank) }),
				Theme.Colors.TextMuted
			)
			line(Skills.formatDescription(skill, nextRank, lang, opts), Theme.Colors.Success)
		end
		-- S28: breakpoints at ranks 5 and 10 (reached ones bright, later ones greyed).
		local bps = SkillInfo.breakpoints(use, skill, rank)
		if #bps > 0 then
			line(Text.get(use, "skills.breakpoints"), Theme.Colors.Gold, nil, Theme.Fonts.BodyBold)
			for _, bp in bps do
				line(
					(if bp.reached then "✔ " else "") .. bp.text,
					if bp.reached then Theme.Colors.Success else Theme.Colors.TextMuted
				)
			end
		end
		return out
	end)

	local canPut = scope:Computed(function(use): boolean
		local id = use(selected)
		local skill = id and SkillData.get(id)
		if not skill or skill.type == "passive" or rankOf(use, skill) <= 0 then
			return false
		end
		return slotOf(use(hotbar), skill.id) == nil
	end)

	-- Preview viewport (S28)
	local world = scope:New("WorldModel")({}) :: WorldModel
	local camera = scope:New("Camera")({
		FieldOfView = 40,
		CFrame = CFrame.lookAt(Vector3.new(7, 5, -11), Vector3.new(0, 3, 0)),
	}) :: Camera
	local copy: Model? = nil
	local function play()
		local id = Fusion.peek(selected)
		local skill = id and SkillData.get(id)
		if not id or not skill or skill.type == "passive" or not preview then
			return
		end
		if copy then
			copy:Destroy()
		end
		copy = mannequin()
		local model = copy
		if not model then
			return
		end
		model.Parent = world
		Pool.setOverride(world)
		preview(model, id)
		task.delay(2.5, function()
			Pool.setOverride(nil)
		end)
	end
	table.insert(scope, function()
		Pool.setOverride(nil)
		if copy then
			copy:Destroy()
		end
	end)
	local previewFrame = scope:New("ViewportFrame")({
		Name = "Preview",
		Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT),
		BackgroundColor3 = Theme.Colors.Background,
		Ambient = Color3.fromRGB(150, 145, 140),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1.2, -0.8),
		CurrentCamera = camera,
		[Children] = {
			world :: any,
			camera :: any,
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }) :: any,
			Button(scope, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -6, 1, -6),
				Size = UDim2.fromOffset(120, 36),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "skills.preview"),
				Disabled = scope:Computed(function(use): boolean
					local id = use(selected)
					local skill = id and SkillData.get(id)
					return skill == nil or skill.type == "passive"
				end),
				OnClick = play,
			}),
		},
	})

	-- Slot picker over the window (full bar): 2 x 5 cells with the key and the skill on it.
	local cells: { Instance } = {}
	for index = 1, SkillData.HOTBAR_SLOTS do
		local key = if index == 10 then "0" else tostring(index)
		local glyph = scope:Computed(function(use): string
			local bar = use(hotbar)
			local id = if type(bar) == "table" then bar[tostring(index)] else nil
			local skill = id and SkillData.get(id)
			return if skill then skill.glyph else ""
		end)
		table.insert(
			cells,
			scope:New("TextButton")({
				Name = `Slot{index}`,
				LayoutOrder = index,
				AutoButtonColor = true,
				BackgroundColor3 = Theme.Colors.PanelRaised,
				Text = "",
				[OnEvent("Activated")] = function()
					pickSlot(index)
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = 2,
						Color = Theme.Colors.GoldDim,
					}),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = glyph,
						TextScaled = true,
						FontFace = Theme.Fonts.BodyBold,
						TextColor3 = Theme.Colors.Parchment,
						[Children] = scope:New("UIPadding")({
							PaddingTop = UDim.new(0.2, 0),
							PaddingBottom = UDim.new(0.2, 0),
							PaddingLeft = UDim.new(0.2, 0),
							PaddingRight = UDim.new(0.2, 0),
						}),
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(4, 2),
						Size = UDim2.fromOffset(20, 16),
						BackgroundTransparency = 1,
						Text = key,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 13,
						TextColor3 = Theme.Colors.Gold,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			})
		)
	end
	local gridWidth = 5 * PICK_CELL + 4 * 8
	local picker = scope:New("TextButton")({
		Name = "Picker",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.25,
		Text = "",
		ZIndex = 20,
		Visible = scope:Computed(function(use): boolean
			return use(picking) ~= nil
		end),
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(gridWidth + 32, 2 * PICK_CELL + 8 + 40 + Theme.Size.ButtonHeightSmall + 48),
				BackgroundColor3 = Theme.Colors.PanelRaised,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 2 }),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(16, 12),
						Size = UDim2.new(1, -32, 0, 32),
						BackgroundTransparency = 1,
						Text = Text.T(scope, "skills.pick.title"),
						TextWrapped = true,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.Gold,
					}),
					scope:New("Frame")({
						Position = UDim2.fromOffset(16, 52),
						Size = UDim2.fromOffset(gridWidth, 2 * PICK_CELL + 8),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIGridLayout")({
								CellSize = UDim2.fromOffset(PICK_CELL, PICK_CELL),
								CellPadding = UDim2.fromOffset(8, 8),
								FillDirectionMaxCells = 5,
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							cells :: any,
						},
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.new(0.5, 0, 1, -12),
						Size = UDim2.fromOffset(160, Theme.Size.ButtonHeightSmall),
						Variant = "ghost",
						TextSize = Theme.TextSize.Small,
						Text = Text.T(scope, "common.cancel"),
						OnClick = function()
							picking:set(nil)
						end,
					}),
				},
			}),
		},
	})

	return {
		scope:New("TextLabel")({
			Name = "Hint",
			Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
			BackgroundTransparency = 1,
			Text = Text.T(scope, "skills.hint"),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = 14,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("ScrollingFrame")({
			Name = "List",
			Position = UDim2.fromOffset(0, HEADER_HEIGHT + 4),
			Size = UDim2.new(0, LIST_WIDTH + 12, 1, -(HEADER_HEIGHT + 4)),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Colors.GoldDim,
			[Children] = {
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				rows :: any,
			},
		}),
		scope:New("Frame")({
			Name = "Details",
			Position = UDim2.fromOffset(LIST_WIDTH + 24, HEADER_HEIGHT + 4),
			Size = UDim2.new(1, -(LIST_WIDTH + 24), 1, -(HEADER_HEIGHT + 4)),
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
				previewFrame,
				scope:New("ScrollingFrame")({
					Position = UDim2.fromOffset(0, PREVIEW_HEIGHT + 8),
					Size = UDim2.new(1, 0, 1, -(Theme.Size.ButtonHeight + 12 + PREVIEW_HEIGHT + 8)),
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
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
					Variant = "primary",
					Text = Text.T(scope, "skills.toBar"),
					Disabled = scope:Computed(function(use): boolean
						return not use(canPut)
					end),
					OnClick = function()
						local id = Fusion.peek(selected)
						if id then
							toBar(id)
						end
					end,
				}),
			},
		}),
		picker,
	}
end

return SkillsWindow
