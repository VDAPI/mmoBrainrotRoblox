--!strict
-- Server-wide announcement banner (DESIGN §5.5 legendary drops): golden text sliding in at the top of the
-- screen, one at a time from a queue. Announcement.push(text, style?) anywhere; Announcement.mount(scope, root)
-- once. S30: style "mythic" (a mythic drop) is red, bigger, stays longer and pulses with a rotating frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

local Announcement = {}

export type Style = "legendary" | "mythic"

local SHOW_SECONDS = 5
local MYTHIC_SECONDS = 8

local LEGENDARY = Rarities.get(Rarities.LEGENDARY)
local MYTHIC = Rarities.get(Rarities.MYTHIC)

local function sequence(c1: Color3, c2: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1),
		ColorSequenceKeypoint.new(0.5, c2),
		ColorSequenceKeypoint.new(1, c1),
	})
end

local BACKDROP = {
	legendary = sequence(Color3.fromHex("#3A2A10"), Color3.fromHex("#1B1D23")),
	mythic = sequence(Color3.fromHex("#4A0C0A"), Color3.fromHex("#1B1013")),
}
local MYTHIC_COLORS = MYTHIC.frame.gradient or { MYTHIC.color, MYTHIC.color }
local FRAME = {
	legendary = sequence(LEGENDARY.color, LEGENDARY.color),
	mythic = sequence(MYTHIC_COLORS[1], MYTHIC_COLORS[2]),
}

type Entry = { text: string, style: Style }

local moduleScope = Fusion.scoped(Fusion)
local current = moduleScope:Value(nil :: string?)
local style = moduleScope:Value("legendary" :: Style)
local offset = moduleScope:Value(-80)
local animated = moduleScope:Spring(offset, 22, 0.75)
local spin = moduleScope:Value(0)
local pulse = moduleScope:Value(0)
local queue: { Entry } = {}
local showing = false
local spinConnection: RBXScriptConnection? = nil

-- The rotating frame and pulse run only while a mythic banner is on screen.
local function animate(on: boolean)
	if on and not spinConnection then
		local clock = 0
		spinConnection = RunService.RenderStepped:Connect(function(dt: number)
			clock += dt
			spin:set((clock * 120) % 360)
			pulse:set(math.sin(clock * 6) * 0.5 + 0.5)
		end)
	elseif not on and spinConnection then
		spinConnection:Disconnect()
		spinConnection = nil
		pulse:set(0)
	end
end

local function nextAnnouncement()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local entry = table.remove(queue, 1) :: Entry
	current:set(entry.text)
	style:set(entry.style)
	animate(entry.style == "mythic")
	offset:set(if entry.style == "mythic" then 150 else 130)
	task.delay(if entry.style == "mythic" then MYTHIC_SECONDS else SHOW_SECONDS, function()
		offset:set(-80)
		task.delay(0.6, function()
			showing = false
			current:set(nil)
			animate(false)
			nextAnnouncement()
		end)
	end)
end

function Announcement.push(text: string, kind: Style?)
	local entry: Entry = { text = text, style = kind or "legendary" }
	-- A mythic drop jumps ahead of the queued ordinary announcements.
	if entry.style == "mythic" then
		local at = 1
		while queue[at] and queue[at].style == "mythic" do
			at += 1
		end
		table.insert(queue, at, entry)
	else
		table.insert(queue, entry)
	end
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
		Size = scope:Computed(function(use): UDim2
			return if use(style) == "mythic" then UDim2.fromOffset(980, 84) else UDim2.fromOffset(900, 64)
		end),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.15,
		Visible = scope:Computed(function(use): boolean
			return use(current) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = scope:Computed(function(use): number
					return if use(style) == "mythic"
						then Theme.Stroke.Thick + 2 + use(pulse) * 2
						else Theme.Stroke.Thick
				end),
				Color = Color3.new(1, 1, 1),
				[Children] = scope:New("UIGradient")({
					Color = scope:Computed(function(use): ColorSequence
						return if use(style) == "mythic" then FRAME.mythic else FRAME.legendary
					end),
					Rotation = spin,
				}),
			}),
			scope:New("UIGradient")({
				Color = scope:Computed(function(use): ColorSequence
					return if use(style) == "mythic" then BACKDROP.mythic else BACKDROP.legendary
				end),
			}),
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = scope:Computed(function(use): string
					return use(current) or ""
				end),
				RichText = true,
				FontFace = Theme.Fonts.Heading,
				TextSize = scope:Computed(function(use): number
					return if use(style) == "mythic" then Theme.TextSize.Title else Theme.TextSize.Large + 2
				end),
				TextColor3 = scope:Computed(function(use): Color3
					return if use(style) == "mythic" then Color3.fromHex("#FFD0C8") else Theme.Colors.GoldBright
				end),
				TextStrokeColor3 = scope:Computed(function(use): Color3
					return if use(style) == "mythic" then MYTHIC.color else Color3.new(0, 0, 0)
				end),
				TextStrokeTransparency = scope:Computed(function(use): number
					return if use(style) == "mythic" then 0.5 - use(pulse) * 0.3 else 0.4
				end),
				TextWrapped = true,
			}),
		},
	})
end

return Announcement
