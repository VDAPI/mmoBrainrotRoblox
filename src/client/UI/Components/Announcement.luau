--!strict
-- Server-wide announcement banner (DESIGN §5.5 legendary drops): golden text, one at a time. Announcement.push(text,
-- style?, seconds?) anywhere. S30: style "mythic" (a mythic drop) is red, bigger, stays longer and pulses with a
-- rotating frame.
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): the banner goes
-- through UI/Notify (Logic/NoticeQueue): the banner's place in the band under the target (owner question 2), 5 s, a
-- mythic one 8 s, a world boss's 15 s in red even when an alert takes its place for a moment; another server's news
-- waits up to 30 s in combat, then drops (owner question 5); with a window open it stands over the window or under its
-- title bar (question UI 8). Announcements stay banner-only (owner decision). This file keeps the banner's look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local SoftRequire = require(script.Parent.Parent.SoftRequire)
local Theme = require(script.Parent.Parent.Theme)
-- Studio check 2026-10-31 (UI/SoftRequire): the controllers that announce require this, so the new message door is
-- soft here; without it (not synced yet) the banners show nothing instead of taking those controllers down.
local Notify = SoftRequire(
	function()
		return require(script.Parent.Parent.Notify)
	end,
	{
		push = function(_spec: any): any
			return nil
		end,
		bannerTone = function(_key: string): string
			return "legendary"
		end,
	} :: any,
	"UI/Notify"
)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
-- UI/Notify.Live (a soft require carries no types)
type Live = { id: number, count: Fusion.Value<number>, phone: boolean, close: () -> (), relayout: () -> () }

local Announcement = {}

export type Style = "legendary" | "mythic"

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

-- The banner's look in its place: gold, or red with a rotating, pulsing frame (a mythic drop, the Blood Moon, a world
-- boss).
local function view(text: string, mythic: boolean): (Scope, Live) -> Instance
	return function(s: Scope, live: Live): Instance
		local spin = s:Value(0)
		local pulse = s:Value(0)
		if mythic then
			local clock = 0
			table.insert(
				s,
				RunService.RenderStepped:Connect(function(dt: number)
					clock += dt
					spin:set((clock * 120) % 360)
					pulse:set(math.sin(clock * 6) * 0.5 + 0.5)
				end)
			)
		end
		return s:New("Frame")({
			Name = "Announcement",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Iron.Sunken,
			BackgroundTransparency = 0.15,
			[Children] = {
				s:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
				s:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = s:Computed(function(use): number
						return if mythic then Theme.Stroke.Thick + 2 + use(pulse) * 2 else Theme.Stroke.Thick
					end),
					Color = Theme.Plain,
					[Children] = s:New("UIGradient")({
						Color = if mythic then FRAME.mythic else FRAME.legendary,
						Rotation = spin,
					}),
				}),
				s:New("UIGradient")({ Color = if mythic then BACKDROP.mythic else BACKDROP.legendary }),
				s:New("TextLabel")({
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(Theme.Padding.Small, 0),
					Size = UDim2.new(1, -2 * Theme.Padding.Small, 1, 0),
					Text = s:Computed(function(use): string
						local n = use(live.count)
						return if n > 1 then `{text}  ×{n}` else text
					end),
					RichText = true,
					FontFace = Theme.Fonts.Display,
					TextSize = if live.phone
						then Theme.TextSize.Body
						elseif mythic then Theme.TextSize.Title
						else Theme.TextSize.Large + 2,
					TextColor3 = if mythic then MYTHIC_TEXT else Theme.Brass.Bright,
					TextStrokeColor3 = if mythic then MYTHIC.color else Theme.Shade,
					TextStrokeTransparency = s:Computed(function(use): number
						return if mythic then 0.5 - use(pulse) * 0.3 else 0.4
					end),
					TextWrapped = true,
				}),
			},
		})
	end
end

-- What NotificationController knows of a server's announcement: its key (a world boss's, a mythic drop's, another
-- server's news) on top of the style.
export type Options = { key: string?, crossServer: boolean? }

function Announcement.push(text: string, kind: Style?, seconds: number?, options: Options?)
	local key = options and options.key
	local tone = if key then Notify.bannerTone(key) else kind or "legendary"
	if kind == "mythic" and tone == "legendary" then
		tone = "mythic"
	end
	Notify.push({
		class = "banner",
		text = text,
		key = key,
		tone = tone,
		seconds = seconds,
		crossServer = options and options.crossServer,
		build = view(text, tone ~= "legendary"),
	})
end

-- UIController mounts the announcements once; the message host (UI/Notify, Toast.mount) shows them now.
function Announcement.mount(_scope: Fusion.Scope<typeof(Fusion)>, _parent: Instance) end

return Announcement
