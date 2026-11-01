--!strict
-- Server-wide announcement banner (DESIGN §5.5 legendary drops): golden text sliding in at the top of the
-- screen, one at a time from a queue. Announcement.push(text, style?) anywhere; Announcement.mount(scope, root)
-- once. S30: style "mythic" (a mythic drop) is red, bigger, stays longer and pulses with a rotating frame.
-- UI plan phase 2 (Studio 2026-10-31: the world boss's banner sat on an open window's title bar): while a window is open
-- the banner stands under its title bar (UI/HudCover.HeaderBottom, Logic/TopBand.underHeader).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Scale = require(script.Parent.Parent.Scale)
local SoftRequire = require(script.Parent.Parent.SoftRequire)
local Theme = require(script.Parent.Parent.Theme)
-- Studio check 2026-10-31: soft, like Components/Toast (a module not synced yet keeps the banner at its old place)
local HudCover = SoftRequire(function()
	return require(script.Parent.Parent.HudCover)
end, { HeaderBottom = nil } :: any, "UI/HudCover")
local TopBand = SoftRequire(
	function()
		return require(ReplicatedStorage.Shared.Logic.TopBand)
	end,
	{
		underHeader = function(top: number): number
			return top
		end,
		underBars = function(top: number): number
			return top
		end,
	} :: any,
	"Logic/TopBand"
)

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

-- S135: colours from Data/UiPalette.announce
local BACKDROP = {
	legendary = sequence(Theme.Announce.LegendaryGlow, Theme.Announce.LegendaryBase),
	mythic = sequence(Theme.Announce.MythicGlow, Theme.Announce.MythicBase),
}
local MYTHIC_TEXT = Theme.Announce.MythicText
local MYTHIC_COLORS = MYTHIC.frame.gradient or { MYTHIC.color, MYTHIC.color }
local FRAME = {
	legendary = sequence(LEGENDARY.color, LEGENDARY.color),
	mythic = sequence(MYTHIC_COLORS[1], MYTHIC_COLORS[2]),
}

type Entry = { text: string, style: Style, seconds: number? } -- seconds: how long it stays (default by style)

local moduleScope = Fusion.scoped(Fusion)
local current = moduleScope:Value(nil :: string?)
local style = moduleScope:Value("legendary" :: Style)
local HIDDEN = -80
local shown = moduleScope:Value(false)
local layerTop = moduleScope:Value(0) -- the layer's top edge on the screen (Announcement.mount)
-- The banner's centre: its own place, or under the title bar of an open window; above the screen while hidden.
local target = moduleScope:Computed(function(use): number
	if not use(shown) then
		return HIDDEN
	end
	local mythic = use(style) == "mythic"
	local centre = if mythic then 150 else 130
	local half = (if mythic then 84 else 64) / 2
	local header = use(HudCover.HeaderBottom)
	local top = TopBand.underBars(
		centre - half,
		use(Scale.TopBar),
		if header then header - use(layerTop) else nil,
		use(Scale.Value)
	)
	return top + half
end)
local animated = moduleScope:Spring(target, 22, 0.75)
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
	shown:set(true)
	task.delay(entry.seconds or (if entry.style == "mythic" then MYTHIC_SECONDS else SHOW_SECONDS), function()
		shown:set(false)
		task.delay(0.6, function()
			showing = false
			current:set(nil)
			animate(false)
			nextAnnouncement()
		end)
	end)
end

function Announcement.push(text: string, kind: Style?, seconds: number?)
	local entry: Entry = { text = text, style = kind or "legendary", seconds = seconds }
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
	if parent:IsA("GuiObject") then
		local layer = parent
		local function track()
			layerTop:set(layer.AbsolutePosition.Y)
		end
		track()
		table.insert(scope, layer:GetPropertyChangedSignal("AbsolutePosition"):Connect(track))
	end
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
		BackgroundColor3 = Theme.Iron.Sunken,
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
				Color = Theme.Plain,
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
				FontFace = Theme.Fonts.Display,
				TextSize = scope:Computed(function(use): number
					return if use(style) == "mythic" then Theme.TextSize.Title else Theme.TextSize.Large + 2
				end),
				TextColor3 = scope:Computed(function(use): Color3
					return if use(style) == "mythic" then MYTHIC_TEXT else Theme.Brass.Bright
				end),
				TextStrokeColor3 = scope:Computed(function(use): Color3
					return if use(style) == "mythic" then MYTHIC.color else Theme.Shade
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
