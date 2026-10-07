--!strict
-- Touch skill buttons (DESIGN §14.1, §23): five round buttons in an arc around the attack button, a page
-- switch for slots 6–10 and a "target" button (nearest enemy). Hidden on PC.
-- S28: dragging a button aims an area skill (the preview follows the finger, release casts there, coming back onto
-- the button cancels); a tap casts as before.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Cast: (slot: number) -> (),
	Color: (skillId: string) -> Color3,
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
		local rad = math.rad(angle)
		local offset = Vector2.new(math.cos(rad), -math.sin(rad)) * RADIUS
		local button = scope:New("TextButton")({
			Name = `MobileSkill{i}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, CENTER.X + offset.X, 1, CENTER.Y + offset.Y),
			Size = UDim2.fromOffset(SIZE, SIZE),
			AutoButtonColor = true,
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.15,
			Text = scope:Computed(function(use): string
				local id = use(skillId)
				local skill = id and SkillData.get(id)
				return if skill then skill.glyph else tostring(use(slot) % 10)
			end),
			TextScaled = true,
			FontFace = Theme.Fonts.BodyBold,
			TextColor3 = scope:Computed(function(use): Color3
				local id = use(skillId)
				return if id then props.Color(id) else Theme.Colors.TextMuted
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
				scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 2 }),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0.2, 0),
					PaddingBottom = UDim.new(0.2, 0),
					PaddingLeft = UDim.new(0.2, 0),
					PaddingRight = UDim.new(0.2, 0),
				}),
			},
		})
		buttonsByIndex[i] = button :: GuiObject
		table.insert(buttons, button)
	end

	local function smallButton(name: string, position: UDim2, text: Fusion.UsedAs<string>, onClick: () -> ())
		return scope:New("TextButton")({
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Size = UDim2.fromOffset(84, 44),
			BackgroundColor3 = Theme.Colors.PanelRaised,
			BackgroundTransparency = 0.1,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.Gold,
			[OnEvent("Activated")] = onClick,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 1 }),
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
				UDim2.new(1, CENTER.X, 1, CENTER.Y - RADIUS - 56),
				Text.T(scope, "hud.targetButton"),
				props.SelectTarget
			),
		},
	})
end

return MobileSkills
