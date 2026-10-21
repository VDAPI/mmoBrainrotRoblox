--!strict
-- Touch skill buttons (DESIGN §14.1, §23): five round buttons in an arc around the attack button, a page
-- switch for slots 6–10 (S137: 8 slots; S156: 10 again, two full pages) and a "target" button (nearest enemy).
-- Hidden on PC.
-- S28: dragging a button aims an area skill (the preview follows the finger, release casts there, coming back onto
-- the button cancels); a tap casts as before.
-- Owner 2026-10-21: the cost in the button's top-left corner like the bar (Components/CostBadge).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local CostBadge = require(script.Parent.Parent.Parent.Components.CostBadge)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Cast: (slot: number) -> (),
	Color: (skillId: string) -> Color3,
	-- owner 2026-10-21: the cost a cast takes now and its resource (SkillController.Cost; nil: no badge)
	Cost: ((skillId: string) -> (number, string?))?,
	SelectTarget: () -> (),
	-- S28 drag aiming (SkillController.AimStart / AimMove / AimEnd).
	AimStart: ((slot: number) -> boolean)?,
	AimMove: ((slot: number, drag: Vector2) -> boolean)?,
	AimEnd: ((slot: number, cast: boolean) -> ())?,
}

local CANCEL_RADIUS = 34 -- pixels: releasing this close to the button cancels an aim

local SIZE = 68
-- Arc around the attack button (anchored bottom-right at (-110, -150), 104 px): angles in degrees.
local CENTER = Vector2.new(-162, -202)
local RADIUS = 120
local ANGLES = { 180, 150, 120, 90, 60 }

local function MobileSkills(scope: Scope, props: Props): Instance
	local page = scope:Value(0)
	local hotbar = State.Value({ "character", "hotbar" })
	-- refreshes the cost badges (twice a second, only while the buttons show)
	local tick = scope:Value(0)
	local acc = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc >= 0.5 and Fusion.peek(Device.Touch) then
				acc = 0
				tick:set(Fusion.peek(tick) + 1)
			end
		end)
	)

	local buttons = {}
	local buttonsByIndex: { [number]: GuiObject } = {}
	local suppress: { [number]: boolean } = {}
	for i, angle in ANGLES do
		local slot = scope:Computed(function(use): number
			return use(page) * 5 + i
		end)
		local skillId = scope:Computed(function(use): string?
			local bar = use(hotbar)
			return if type(bar) == "table" then bar[tostring(use(slot))] else nil
		end)
		-- S119: the skill's picture fills the round button once loaded (the glyph or slot number otherwise).
		local artKey = scope:Computed(function(use): string?
			local id = use(skillId)
			return if id and SkillData.get(id) then UiArt.skill(id) else nil
		end)
		local artShown = ArtIcon.Shown(scope, artKey)
		local rad = math.rad(angle)
		local offset = Vector2.new(math.cos(rad), -math.sin(rad)) * RADIUS
		-- W29: a tighter arc of smaller buttons around the corner attack button on a phone in landscape
		local phoneX, phoneY = PhoneHud.skillCenter(i)
		local button = scope:New("TextButton")({
			Name = `MobileSkill{i}`,
			Visible = scope:Computed(function(use): boolean
				return use(slot) <= SkillData.HOTBAR_SLOTS
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = PhoneLayout.Pick(
				scope,
				UDim2.new(1, phoneX, 1, phoneY),
				UDim2.new(1, CENTER.X + offset.X, 1, CENTER.Y + offset.Y)
			),
			Size = PhoneLayout.Pick(
				scope,
				UDim2.fromOffset(PhoneHud.SKILL, PhoneHud.SKILL),
				UDim2.fromOffset(SIZE, SIZE)
			),
			AutoButtonColor = true,
			BackgroundColor3 = Theme.Iron.Raised, -- S136: the iron slot
			BackgroundTransparency = Theme.HudAlpha,
			Text = scope:Computed(function(use): string
				local id = use(skillId)
				local skill = id and SkillData.get(id)
				if skill and use(artShown) then
					return ""
				end
				return if skill then skill.glyph else tostring(use(slot) % 10)
			end),
			TextScaled = true,
			FontFace = Theme.Fonts.BodyBold,
			TextColor3 = scope:Computed(function(use): Color3
				local id = use(skillId)
				return if id then props.Color(id) else Theme.Iron.TextMuted
			end),
			[OnEvent("Activated")] = function()
				if suppress[i] then
					suppress[i] = false
					return
				end
				props.Cast(Fusion.peek(slot))
			end,
			[OnEvent("InputBegan")] = function(input: InputObject)
				if input.UserInputType ~= Enum.UserInputType.Touch or not props.AimStart then
					return
				end
				local s = Fusion.peek(slot)
				if not props.AimStart(s) then
					return
				end
				local button = buttonsByIndex[i]
				local origin = if button
					then button.AbsolutePosition + button.AbsoluteSize / 2
					else Vector2.new(input.Position.X, input.Position.Y)
				local aiming = false
				local moved: RBXScriptConnection
				local ended: RBXScriptConnection
				moved = UserInputService.InputChanged:Connect(function(other: InputObject)
					if other ~= input then
						return
					end
					local drag = Vector2.new(other.Position.X, other.Position.Y) - origin
					if props.AimMove then
						aiming = props.AimMove(s, drag) or aiming
					end
				end)
				ended = UserInputService.InputEnded:Connect(function(other: InputObject)
					if other ~= input then
						return
					end
					moved:Disconnect()
					ended:Disconnect()
					if aiming and props.AimEnd then
						local drag = Vector2.new(other.Position.X, other.Position.Y) - origin
						suppress[i] = true
						task.delay(0.3, function()
							suppress[i] = false
						end)
						props.AimEnd(s, drag.Magnitude > CANCEL_RADIUS)
					end
				end)
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
				scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Normal }),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0.2, 0),
					PaddingBottom = UDim.new(0.2, 0),
					PaddingLeft = UDim.new(0.2, 0),
					PaddingRight = UDim.new(0.2, 0),
				}),
				-- Inside the 20% padding: 1 / 0.6 of the content box = the whole button.
				ArtIcon.Image(scope, {
					Key = artKey,
					Size = UDim2.fromScale(1 / 0.6, 1 / 0.6),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Corner = UDim.new(0.5, 0),
				}),
				-- the button's top-left corner: the content box starts 20 % in and is 60 % wide (-0.2 / 0.6)
				if props.Cost
					then CostBadge(scope, {
						SkillId = skillId,
						Cost = props.Cost,
						Tick = tick,
						Position = UDim2.fromScale(-1 / 3, -1 / 3),
					})
					else nil :: any,
			},
		})
		buttonsByIndex[i] = button :: GuiObject
		table.insert(buttons, button)
	end

	-- `place`: its place on a phone in landscape (Logic/PhoneHud)
	local function smallButton(
		name: string,
		place: string,
		position: UDim2,
		text: Fusion.UsedAs<string>,
		onClick: () -> ()
	)
		return scope:New("TextButton")({
			Name = name,
			AnchorPoint = PhoneLayout.Anchor(scope, place, Vector2.new(0.5, 0.5)),
			Position = PhoneLayout.Position(scope, place, position),
			Size = UDim2.fromOffset(84, 44),
			BackgroundColor3 = Theme.Iron.Raised,
			BackgroundTransparency = Theme.HudAlpha,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Iron.Heading,
			[OnEvent("Activated")] = onClick,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			},
		})
	end

	return scope:New("Frame")({
		Name = "MobileSkills",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = Device.Touch,
		[Children] = {
			buttons :: any,
			smallButton(
				"Page",
				"page",
				UDim2.new(1, CENTER.X - RADIUS - 70, 1, CENTER.Y + 40),
				scope:Computed(function(use): string
					return Text.get(use, "hud.page", { page = use(page) + 1 })
				end),
				function()
					page:set(1 - Fusion.peek(page))
				end
			),
			smallButton(
				"Target",
				"targetButton",
				UDim2.new(1, CENTER.X, 1, CENTER.Y - RADIUS - 56),
				Text.T(scope, "hud.targetButton"),
				props.SelectTarget
			),
		},
	})
end

return MobileSkills
