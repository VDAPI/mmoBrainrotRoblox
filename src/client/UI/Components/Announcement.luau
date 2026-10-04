--!strict
-- Server-wide announcement banner (DESIGN §5.5 legendary drops): golden text sliding in at the top of the
-- screen, one at a time from a queue. Announcement.push(text) anywhere; Announcement.mount(scope, root) once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

local Announcement = {}

local SHOW_SECONDS = 5

local moduleScope = Fusion.scoped(Fusion)
local current = moduleScope:Value(nil :: string?)
local offset = moduleScope:Value(-80)
local animated = moduleScope:Spring(offset, 22, 0.75)
local queue: { string } = {}
local showing = false

local function nextAnnouncement()
	if showing or #queue == 0 then
		return
	end
	showing = true
	current:set(table.remove(queue, 1))
	offset:set(130)
	task.delay(SHOW_SECONDS, function()
		offset:set(-80)
		task.delay(0.6, function()
			showing = false
			current:set(nil)
			nextAnnouncement()
		end)
	end)
end

function Announcement.push(text: string)
	table.insert(queue, text)
	nextAnnouncement()
end

function Announcement.mount(scope: Fusion.Scope<typeof(Fusion)>, parent: Instance)
	scope:New("Frame")({
		Name = "Announcement",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = scope:Computed(function(use): UDim2
			return UDim2.new(0.5, 0, 0, use(animated))
		end),
		Size = UDim2.fromOffset(900, 64),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.15,
		Visible = scope:Computed(function(use): boolean
			return use(current) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thick,
				Color = Color3.fromHex("#FF9F1C"),
			}),
			scope:New("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHex("#3A2A10")),
					ColorSequenceKeypoint.new(0.5, Color3.fromHex("#1B1D23")),
					ColorSequenceKeypoint.new(1, Color3.fromHex("#3A2A10")),
				}),
			}),
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = scope:Computed(function(use): string
					return use(current) or ""
				end),
				RichText = true,
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large + 2,
				TextColor3 = Theme.Colors.GoldBright,
				TextStrokeTransparency = 0.4,
				TextWrapped = true,
			}),
		},
	})
end

return Announcement
