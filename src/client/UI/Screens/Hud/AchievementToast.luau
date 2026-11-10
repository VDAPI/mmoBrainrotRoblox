--!strict
-- S151 (docs/DESIGN.md §20b): the achievement toast (layer Toasts, iron with a brass edge): a header, the name in the
-- display face, the category and the points, and the reward lines (title, cosmetic, Dragon Shards, gold). The catch-up
-- of old progress uses it with a summary line. It stays Config.Achievements.toastSeconds and goes on a click / touch.
-- PC: 440 x 104; phone (Device.Touch): 340 x 96. S151b: "View" (for a single achievement) opens the achievements
-- window on it.
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): it is a banner of
-- UI/Notify's queue (AchievementController pushes it): the banner's place in the band under the target, one banner at a
-- time (so it waits for the zone, the area and the server's banners); it waits while a window is open, and a window
-- that opens while it shows puts it under the window's title bar (docs/UI-ZASADY.md §6). This file keeps its look.
-- Review 2026-11-10: the header and "View" are Small (Caption is for capitals only, UI-ZASADY §8).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Notify = require(script.Parent.Parent.Parent.Notify)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

-- What the toast shows (texts already in the viewer's language).
export type View = { header: string, name: string, meta: string, reward: string, id: string? }

local AchievementToast = {}

-- Its size on PC and on a touch screen; a phone shows one row of HudLine height in its M zone (the name and "View").
AchievementToast.SIZE = table.freeze({ pc = Vector2.new(440, 104), touch = Vector2.new(340, 96) })
AchievementToast.PHONE_H = Theme.Size.HudLine

local ICON = 56
local VIEW_WIDTH = 96

-- The look of `view` in the place UI/Notify gives it; `onView(id)`: the "View" button of a single achievement (S151b).
function AchievementToast.build(view: View, onView: ((id: string) -> ())?): (Scope, Notify.Live) -> Instance
	return function(scope: Scope, live: Notify.Live): Instance
		-- `right`: room kept free at the right edge (S151b: the "View" button next to the header and the name)
		local function label(
			name: string,
			y: number,
			h: number,
			font: Font,
			textSize: number,
			color: Color3,
			text: string,
			right: number?
		)
			return scope:New("TextLabel")({
				Name = name,
				Position = UDim2.fromOffset(ICON + 22, y),
				Size = UDim2.new(1, -(ICON + 30 + (right or 0)), 0, h),
				BackgroundTransparency = 1,
				Text = text,
				FontFace = font,
				TextSize = textSize,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		end
		local viewable = onView ~= nil and view.id ~= nil
		local function openView()
			live.close()
			if onView and view.id then
				onView(view.id)
			end
		end
		if live.phone then
			-- one row in the M zone: ✦, the name, "View"; a tap elsewhere closes it
			return scope:New("Frame")({
				Name = "AchievementToast",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Iron.Surface,
				BackgroundTransparency = Theme.HudAlpha,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({ Color = Theme.Brass.Bright, Thickness = Theme.Stroke.Normal }),
					scope:New("TextLabel")({
						Name = "Name",
						Position = UDim2.fromOffset(Theme.Padding.Small, 0),
						Size = UDim2.new(1, -(Theme.Padding.Small * 2 + (if viewable then VIEW_WIDTH else 0)), 1, 0),
						BackgroundTransparency = 1,
						Text = `✦ {view.name}`,
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Brass.Bright,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					scope:New("TextButton")({
						Name = "Dismiss",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 5,
						[OnEvent("Activated")] = live.close,
					}),
					scope:New("TextButton")({
						Name = "View",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -4, 0.5, 0),
						Size = UDim2.fromOffset(VIEW_WIDTH, Theme.Size.MinTouch),
						AutoButtonColor = false,
						BackgroundColor3 = Theme.Iron.Raised,
						Text = Text.T(scope, "ach.toast.view"),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Brass.Bright,
						ZIndex = 6,
						Visible = viewable,
						[OnEvent("Activated")] = openView,
						[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					}),
				},
			})
		end
		return scope:New("Frame")({
			Name = "AchievementToast",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Iron.Surface,
			BackgroundTransparency = Theme.HudAlpha,
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
					Theme.TextSize.Small,
					Theme.Brass.Bright,
					view.header,
					VIEW_WIDTH + 8
				),
				label(
					"Name",
					26,
					28,
					Theme.Fonts.Display,
					Theme.TextSize.Large,
					Theme.Iron.Heading,
					view.name,
					VIEW_WIDTH + 8
				),
				label("Meta", 54, 20, Theme.Fonts.Body, Theme.TextSize.Small, Theme.Iron.TextMuted, view.meta),
				label("Reward", 74, 22, Theme.Fonts.BodyMedium, Theme.TextSize.Small, Theme.Iron.Text, view.reward),
				scope:New("TextButton")({
					Name = "Dismiss",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 5,
					[OnEvent("Activated")] = live.close,
				}),
				-- S151b: open the achievements window on it (over the dismiss area)
				scope:New("TextButton")({
					Name = "View",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 8),
					-- a touch screen's tap target is MinTouch high (y 8..52, the Meta line starts at 54)
					Size = UDim2.fromOffset(
						VIEW_WIDTH,
						if Fusion.peek(Device.Touch) then Theme.Size.MinTouch else Theme.Size.MinTouch - 12
					),
					AutoButtonColor = false,
					BackgroundColor3 = Theme.Iron.Raised,
					Text = Text.T(scope, "ach.toast.view"),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Brass.Bright,
					ZIndex = 6,
					Visible = viewable,
					[OnEvent("Activated")] = openView,
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
		})
	end
end

return AchievementToast
