--!strict
-- Skill bar (DESIGN §14.1): 10 slots on keys 1–0. Cooldown as a darkening sweep with seconds left (the
-- global cooldown too), blue/yellow tint when mana/energy is short, red key when the target is out of range.
-- Drag skills from the tree or between slots; right-click clears a slot; click casts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DragDrop = require(script.Parent.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.Parent.Keybinds)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Cast: (slot: number) -> (),
	Clear: (slot: number) -> (),
	Usable: (skillId: string) -> (boolean, boolean, boolean),
	Color: (skillId: string) -> Color3,
	SlotSize: number,
}

local function SkillBar(scope: Scope, props: Props): { Instance }
	local hotbar = State.Value({ "character", "hotbar" })
	local skillLevels = State.Value({ "character", "skills" })
	local cooldowns = State.Value({ "skills" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local tick = scope:Value(0) -- refreshes range / resource checks

	local accumulator = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			now:set(Workspace:GetServerTimeNow())
			accumulator += dt
			if accumulator >= 0.2 then
				accumulator = 0
				tick:set(Fusion.peek(tick) + 1)
			end
		end)
	)

	local slots = {}
	for index = 1, SkillData.HOTBAR_SLOTS do
		local skillId = scope:Computed(function(use): string?
			local bar = use(hotbar)
			return if type(bar) == "table" then bar[tostring(index)] else nil
		end)
		local skill = scope:Computed(function(use): SkillData.SkillDef?
			local id = use(skillId)
			return if id then SkillData.get(id) else nil
		end)
		local remaining = scope:Computed(function(use): number
			local id = use(skillId)
			local state = use(cooldowns)
			if not id or type(state) ~= "table" then
				return 0
			end
			local t = use(now)
			local readyAt = math.max(if state.cd then state.cd[id] or 0 else 0, state.gcd or 0)
			return math.max(0, readyAt - t)
		end)
		local fraction = scope:Computed(function(use): number
			local s = use(skill)
			local left = use(remaining)
			if not s or left <= 0 then
				return 0
			end
			local levels = use(skillLevels)
			local level = if type(levels) == "table" then levels[s.id] or 1 else 1
			local total = math.max(SkillData.GCD, Skills.scaled(s, s.cooldown, level))
			return math.clamp(left / total, 0, 1)
		end)
		local usable = scope:Computed(function(use): { resource: boolean, range: boolean, element: boolean }
			use(tick)
			local id = use(skillId)
			if not id then
				return { resource = true, range = true, element = true }
			end
			local resource, range, element = props.Usable(id)
			return { resource = resource, range = range, element = element }
		end)

		local key = Keybinds.Label(scope, `skill_{index}`)
		local slot = scope:New("TextButton")({
			Name = `Skill{index}`,
			LayoutOrder = index,
			Size = UDim2.fromOffset(props.SlotSize, props.SlotSize),
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.2,
			Text = "",
			[OnEvent("Activated")] = function()
				if os.clock() - DragDrop.LastDropAt < 0.3 then
					return
				end
				props.Cast(index)
			end,
			[OnEvent("MouseButton2Click")] = function()
				props.Clear(index)
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = Theme.Stroke.Normal,
					Color = scope:Computed(function(use): Color3
						if use(DragDrop.Selected) == `bar:{index}` then
							return Theme.Colors.GoldBright
						end
						local id = use(skillId)
						return if id then props.Color(id) else Theme.Colors.GoldDim
					end),
					Transparency = 0.2,
				}),
				scope:New("TextLabel")({
					Name = "Icon",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = scope:Computed(function(use): string
						local s = use(skill)
						return if s then s.glyph else ""
					end),
					TextScaled = true,
					FontFace = Theme.Fonts.BodyBold,
					TextColor3 = scope:Computed(function(use): Color3
						local id = use(skillId)
						return if id then props.Color(id) else Theme.Colors.Text
					end),
					[Children] = scope:New("UIPadding")({
						PaddingTop = UDim.new(0.15, 0),
						PaddingBottom = UDim.new(0.15, 0),
						PaddingLeft = UDim.new(0.15, 0),
						PaddingRight = UDim.new(0.15, 0),
					}),
				}),
				-- Weapon of the wrong element (Mage, S18): greyed out.
				scope:New("Frame")({
					Name = "ElementTint",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.fromHex("#2A2A2E"),
					BackgroundTransparency = 0.25,
					Visible = scope:Computed(function(use): boolean
						return use(skill) ~= nil and not use(usable).element
					end),
					ZIndex = 2,
					[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				}),
				-- Not enough mana / energy
				scope:New("Frame")({
					Name = "ResourceTint",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = scope:Computed(function(use): Color3
						local s = use(skill)
						return if s and s.resource == "mana" then Theme.Colors.Mana else Theme.Colors.Energy
					end),
					BackgroundTransparency = 0.55,
					Visible = scope:Computed(function(use): boolean
						return use(skill) ~= nil and not use(usable).resource
					end),
					ZIndex = 2,
					[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				}),
				-- Cooldown sweep
				scope:New("Frame")({
					Name = "Cooldown",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = scope:Computed(function(use): UDim2
						return UDim2.fromScale(1, use(fraction))
					end),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.4,
					ZIndex = 3,
					[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				}),
				scope:New("TextLabel")({
					Name = "Seconds",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = scope:Computed(function(use): string
						local left = use(remaining)
						if left <= SkillData.GCD then
							return ""
						end
						return if left >= 10 then tostring(math.ceil(left)) else string.format("%.1f", left)
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 20,
					TextColor3 = Theme.Colors.Text,
					TextStrokeTransparency = 0.2,
					ZIndex = 4,
				}),
				scope:New("TextLabel")({
					Name = "Key",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -4, 1, -2),
					Size = UDim2.fromOffset(20, 16),
					BackgroundTransparency = 1,
					Text = key,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 13,
					TextColor3 = scope:Computed(function(use): Color3
						return if use(skill) ~= nil and not use(usable).range
							then Theme.Colors.DangerHover
							else Theme.Colors.TextMuted
					end),
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 5,
				}),
			},
		})
		DragDrop.register(scope, slot :: GuiObject, `bar:{index}`)
		Tooltip.attach(
			scope,
			slot :: GuiObject,
			scope:Computed(function(use): string
				local s = use(skill)
				if not s then
					return Text.get(use, "hud.skillSlot", { n = key })
				end
				local levels = use(skillLevels)
				local level = if type(levels) == "table" then levels[s.id] or 1 else 1
				local lang = use(Text.Lang)
				local text = `{Text.get(use, s.nameKey)} ({level})\n{Skills.formatDescription(s, level, lang)}`
				local element = Skills.requiredElement(s)
				if element then
					text ..= `\n{Text.get(
						use,
						"skill.requiresElement",
						{ element = Text.get(use, `element.{element}`) }
					)}`
				end
				return text
			end)
		)
		table.insert(slots, slot)
	end
	return slots
end

return SkillBar
