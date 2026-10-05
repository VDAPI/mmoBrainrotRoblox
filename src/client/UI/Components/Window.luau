--!strict
-- Game window: gold-framed panel with a title bar and close button. Draggable by the title bar on PC,
-- full screen on touch devices. Opened and stacked by WindowManager; content goes in [Children].

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Scale = require(script.Parent.Parent.Scale)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Title: UsedAs<string>,
	Size: Vector2, -- desktop size in virtual pixels
	Offset: Vector2?, -- initial offset from the screen centre (desktop), e.g. side-by-side windows
	OnClose: () -> (),
	OnFocus: (() -> ())?,
	ZIndex: UsedAs<number>?,
	Name: string?,
	[typeof(Children)]: Fusion.Child?,
}

local function Window(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	-- Offset from the screen centre, in virtual pixels (desktop only).
	local offset = scope:Value(props.Offset or Vector2.zero)
	local closeHovered = scope:Value(false)
	local dragging = false
	local dragStart = Vector2.zero
	local offsetStart = Vector2.zero

	local function clampOffset(value: Vector2): Vector2
		-- Keep at least the title bar on screen.
		local screen = Fusion.peek(Scale.VirtualSize)
		local maxX = math.max(0, screen.X / 2 + props.Size.X / 2 - 80)
		local maxY = math.max(0, screen.Y / 2 + props.Size.Y / 2 - Theme.Size.WindowHeader)
		local minY = -math.max(0, screen.Y / 2 - props.Size.Y / 2)
		return Vector2.new(math.clamp(value.X, -maxX, maxX), math.clamp(value.Y, minY, maxY))
	end

	table.insert(
		scope,
		UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = Scale.toVirtual(Vector2.new(input.Position.X, input.Position.Y)) - dragStart
				offset:set(clampOffset(offsetStart + delta))
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
	)

	local fullscreen = Device.Touch

	return scope:New("Frame")({
		Name = props.Name or "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = scope:Computed(function(use): UDim2
			if use(fullscreen) then
				return UDim2.fromScale(0.5, 0.5)
			end
			local o: Vector2 = use(offset)
			return UDim2.new(0.5, o.X, 0.5, o.Y)
		end),
		Size = scope:Computed(function(use): UDim2
			if use(fullscreen) then
				return UDim2.fromScale(1, 1)
			end
			return UDim2.fromOffset(props.Size.X, props.Size.Y)
		end),
		ZIndex = props.ZIndex,
		BackgroundColor3 = Theme.Colors.Panel,
		Active = true, -- swallow clicks so they do not reach the world

		[OnEvent("InputBegan")] = function(input: InputObject)
			if
				props.OnFocus
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				props.OnFocus()
			end
		end,

		[Children] = {
			scope:New("UICorner")({
				CornerRadius = scope:Computed(function(use): UDim
					return if use(fullscreen) then UDim.new(0, 0) else Theme.Corner.Medium
				end),
			}),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thick,
				Color = Theme.Colors.Gold,
				Transparency = 0.1,
			}),
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, Theme.Size.WindowHeader),
				BackgroundColor3 = Theme.Colors.PanelRaised,
				Active = true,

				[OnEvent("InputBegan")] = function(input: InputObject)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and not Fusion.peek(fullscreen) then
						dragging = true
						dragStart = Scale.toVirtual(Vector2.new(input.Position.X, input.Position.Y))
						offsetStart = Fusion.peek(offset)
					end
				end,

				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					-- Square off the header's bottom corners.
					scope:New("Frame")({
						Name = "CornerFill",
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, 12),
						BackgroundColor3 = Theme.Colors.PanelRaised,
						BorderSizePixel = 0,
					}),
					scope:New("Frame")({
						Name = "Rule",
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, 2),
						BackgroundColor3 = Theme.Colors.GoldDim,
						BorderSizePixel = 0,
						ZIndex = 2,
					}),
					scope:New("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(Theme.Padding.Large, 0),
						Size = UDim2.new(1, -Theme.Padding.Large * 2 - Theme.Size.WindowHeader, 1, 0),
						Text = props.Title,
						FontFace = Theme.Fonts.Heading,
						TextSize = Theme.TextSize.Large + 2,
						TextColor3 = Theme.Colors.Gold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 2,
					}),
					scope:New("TextButton")({
						Name = "Close",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -6, 0.5, 0),
						Size = UDim2.fromOffset(Theme.Size.MinTouch, Theme.Size.MinTouch),
						AutoButtonColor = false,
						BackgroundColor3 = Theme.Colors.Danger,
						BackgroundTransparency = scope:Computed(function(use): number
							return if use(closeHovered) then 0.1 else 1
						end),
						Text = "✕",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Large,
						TextColor3 = Theme.Colors.Text,
						ZIndex = 2,
						[OnEvent("MouseEnter")] = function()
							closeHovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							closeHovered:set(false)
						end,
						[OnEvent("Activated")] = function()
							Sounds.play("click")
							props.OnClose()
						end,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						},
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Content",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, Theme.Size.WindowHeader),
				Size = UDim2.new(1, 0, 1, -Theme.Size.WindowHeader),
				ClipsDescendants = true,
				[Children] = {
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, Theme.Padding.Large),
						PaddingBottom = UDim.new(0, Theme.Padding.Large),
						PaddingLeft = UDim.new(0, Theme.Padding.Large),
						PaddingRight = UDim.new(0, Theme.Padding.Large),
					}),
					props[Children] :: any,
				},
			}),
		},
	})
end

return Window
