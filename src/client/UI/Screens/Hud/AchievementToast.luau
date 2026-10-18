--!strict
-- S151 (docs/DESIGN.md §20b): the achievement toast (layer Toasts, iron with a brass edge): a header, the name in the
-- display face, the category and the points, and the reward lines (title, cosmetic, Dragon Shards, gold). The catch-up
-- of old progress uses it with a summary line. It slides down from the top edge, stays Config.Achievements.toastSeconds
-- and goes on a click / touch. PC: 440 x 104 under the top edge; phone (Device.Touch): 340 x 96 at the top, far from the
-- skill buttons. AchievementController shows one at a time (S151b adds "View" once the achievements window exists).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

-- What the toast shows (texts already in the viewer's language).
export type View = { header: string, name: string, meta: string, reward: string }

export type Api = {
	frame: Instance,
	show: (view: View, onDone: () -> ()) -> (),
	hide: () -> (),
}

local TOP = 64
local ICON = 56

local AchievementToast = {}

function AchievementToast.new(scope: Scope): Api
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

	local function label(name: string, y: number, h: number, font: Font, textSize: number, color: Color3, key: string)
		return scope:New("TextLabel")({
			Name = name,
			Position = UDim2.fromOffset(ICON + 22, y),
			Size = UDim2.new(1, -(ICON + 30), 0, h),
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
			label("Header", 8, 18, Theme.Fonts.BodyBold, Theme.TextSize.Caption, Theme.Brass.Bright, "header"),
			label("Name", 26, 28, Theme.Fonts.Display, Theme.TextSize.Large, Theme.Iron.Heading, "name"),
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
