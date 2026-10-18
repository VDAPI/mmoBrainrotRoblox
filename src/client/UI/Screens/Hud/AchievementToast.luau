--!strict
-- S151 (docs/DESIGN.md §20b): the achievement toast (layer Toasts, iron with a brass edge): a header, the name in the
-- display face, the category and the points, and the reward lines (title, cosmetic, Dragon Shards, gold). The catch-up
-- of old progress uses it with a summary line. It slides down from the top edge, stays Config.Achievements.toastSeconds
-- and goes on a click / touch. PC: 440 x 104 under the top edge; phone (Device.Touch): 340 x 96 at the top, far from the
-- skill buttons. AchievementController shows one at a time. S151b: "View" (for a single achievement) opens the
-- achievements window on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

-- What the toast shows (texts already in the viewer's language).
export type View = { header: string, name: string, meta: string, reward: string, id: string? }

export type Api = {
	frame: Instance,
	show: (view: View, onDone: () -> ()) -> (),
	hide: () -> (),
}

local TOP = 64
local ICON = 56
local VIEW_WIDTH = 96

local AchievementToast = {}

-- `onView(id)`: the "View" button of a single achievement (S151b).
function AchievementToast.new(scope: Scope, onView: ((id: string) -> ())?): Api
	local view = scope:Value({ header = "", name = "", meta = "", reward = "" } :: View)
	local token = 0
	local finished: (() -> ())? = nil

	local size = scope:Computed(function(use): Vector2
		return if use(Device.Touch) then Vector2.new(340, 96) else Vector2.new(440, 104)
	end)
	local hidden = scope:Computed(function(use): UDim2
		return UDim2.new(0.5, 0, 0, -use(size).Y - 8)
	end)
	local shown = UDim2.new(0.5, 0, 0, TOP)

	local box: Frame

	local function hide()
		token += 1
		local done = finished
		finished = nil
		if box then
			TweenService:Create(box, TweenInfo.new(0.2), { Position = Fusion.peek(hidden) }):Play()
			local mine = token
			task.delay(0.25, function()
				if token == mine then
					box.Visible = false
				end
				if done then
					done()
				end
			end)
		elseif done then
			done()
		end
	end

	-- `right`: room kept free at the right edge (S151b: the "View" button next to the header and the name)
	local function label(
		name: string,
		y: number,
		h: number,
		font: Font,
		textSize: number,
		color: Color3,
		key: string,
		right: number?
	)
		return scope:New("TextLabel")({
			Name = name,
			Position = UDim2.fromOffset(ICON + 22, y),
			Size = UDim2.new(1, -(ICON + 30 + (right or 0)), 0, h),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				return (use(view) :: any)[key]
			end),
			FontFace = font,
			TextSize = textSize,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end

	box = scope:New("Frame")({
		Name = "AchievementToast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = Fusion.peek(hidden),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(use(size).X, use(size).Y)
		end),
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Visible = false,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Brass.Bright, Thickness = Theme.Stroke.Normal }),
			scope:New("Frame")({
				Name = "Seal",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(ICON, ICON),
				BackgroundColor3 = Theme.Iron.Sunken,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Normal }),
					scope:New("TextLabel")({
						Name = "Glyph",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "✦",
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Title,
						TextColor3 = Theme.Brass.Bright,
					}),
				},
			}),
			label(
				"Header",
				8,
				18,
				Theme.Fonts.BodyBold,
				Theme.TextSize.Caption,
				Theme.Brass.Bright,
				"header",
				VIEW_WIDTH + 8
			),
			label(
				"Name",
				26,
				28,
				Theme.Fonts.Display,
				Theme.TextSize.Large,
				Theme.Iron.Heading,
				"name",
				VIEW_WIDTH + 8
			),
			label("Meta", 54, 20, Theme.Fonts.Body, Theme.TextSize.Small, Theme.Iron.TextMuted, "meta"),
			label("Reward", 74, 22, Theme.Fonts.BodyMedium, Theme.TextSize.Small, Theme.Iron.Text, "reward"),
			scope:New("TextButton")({
				Name = "Dismiss",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 5,
				[OnEvent("Activated")] = hide,
			}),
			-- S151b: open the achievements window on it (over the dismiss area)
			scope:New("TextButton")({
				Name = "View",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 8),
				-- a phone tap target is MinTouch high (y 8..52, the Meta line starts at 54)
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(
						VIEW_WIDTH,
						if use(Device.Touch) then Theme.Size.MinTouch else Theme.Size.MinTouch - 12
					)
				end),
				AutoButtonColor = false,
				BackgroundColor3 = Theme.Iron.Raised,
				Text = Text.T(scope, "ach.toast.view"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = Theme.Brass.Bright,
				ZIndex = 6,
				Visible = scope:Computed(function(use): boolean
					return onView ~= nil and (use(view) :: View).id ~= nil
				end),
				[OnEvent("Activated")] = function()
					local id = (Fusion.peek(view) :: View).id
					hide()
					if onView and id then
						onView(id)
					end
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Theme.Brass.Line,
						Thickness = Theme.Stroke.Thin,
					}),
				},
			}),
		},
	}) :: Frame

	local function show(nextView: View, onDone: () -> ())
		token += 1
		local mine = token
		finished = onDone
		view:set(nextView)
		box.Position = Fusion.peek(hidden)
		box.Visible = true
		TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = shown,
		}):Play()
		task.delay(Config.Achievements.toastSeconds, function()
			if token == mine then
				hide()
			end
		end)
	end

	return { frame = box, show = show, hide = hide }
end

return AchievementToast
