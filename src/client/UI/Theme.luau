--!strict
-- Visual language (DESIGN §23): serious fantasy. Every component reads colours, fonts, sizes and
-- timings from here; never hardcode them in screens.
-- S135 "Parchment and iron": the colour values live in Shared/Data/UiPalette (hex, contrast-tested). Windows marked
-- `paper` in Shared/Data/UiWindows use the roles Theme.Paper / Theme.Iron / Theme.Brass only; a colour from game
-- data (class, element, rarity, title) reaches a TextColor3 through Theme.readable(hex, surface).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contrast = require(ReplicatedStorage.Shared.Logic.Contrast)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)

local Theme = {}

-- "paper" | "iron" (a plain string: Fusion props and locals widen literal unions)
export type SurfaceName = string

export type Roles = {
	Surface: Color3,
	Raised: Color3,
	Sunken: Color3,
	Hover: Color3,
	Selected: Color3,
	Text: Color3,
	TextMuted: Color3,
	Label: Color3,
	Heading: Color3,
	Border: Color3,
	Rule: Color3,
	Accent: Color3,
	AccentText: Color3,
	Danger: Color3,
	DangerText: Color3,
	Success: Color3,
	Warning: Color3,
	Link: Color3,
}

local function roles(s: UiPalette.Surface): Roles
	return table.freeze({
		Surface = Color3.fromHex(s.surface),
		Raised = Color3.fromHex(s.raised),
		Sunken = Color3.fromHex(s.sunken),
		Hover = Color3.fromHex(s.hover),
		Selected = Color3.fromHex(s.selected),
		Text = Color3.fromHex(s.text),
		TextMuted = Color3.fromHex(s.textMuted),
		Label = Color3.fromHex(s.label),
		Heading = Color3.fromHex(s.heading),
		Border = Color3.fromHex(s.border),
		Rule = Color3.fromHex(s.rule),
		Accent = Color3.fromHex(s.accent),
		AccentText = Color3.fromHex(s.accentText),
		Danger = Color3.fromHex(s.danger),
		DangerText = Color3.fromHex(s.dangerText),
		Success = Color3.fromHex(s.success),
		Warning = Color3.fromHex(s.warning),
		Link = Color3.fromHex(s.link),
	})
end

-- S135: the two surfaces (Data/UiPalette): parchment inside windows, iron for title bars, tooltips, HUD, overlays.
Theme.Paper = roles(UiPalette.paper)
Theme.Iron = roles(UiPalette.iron)
Theme.Brass = table.freeze({
	Frame = Color3.fromHex(UiPalette.brass.frame),
	Line = Color3.fromHex(UiPalette.brass.line),
	Bright = Color3.fromHex(UiPalette.brass.bright),
})
Theme.Resource = table.freeze({
	Hp = Color3.fromHex(UiPalette.resource.hp),
	Mana = Color3.fromHex(UiPalette.resource.mana),
	Energy = Color3.fromHex(UiPalette.resource.energy),
	Exp = Color3.fromHex(UiPalette.resource.exp),
	Track = Color3.fromHex(UiPalette.resource.track),
})
Theme.Zone = table.freeze({
	Green = Color3.fromHex(UiPalette.zone.green),
	Yellow = Color3.fromHex(UiPalette.zone.yellow),
	Red = Color3.fromHex(UiPalette.zone.red),
})
-- Untinted image colour (ImageColor3) and the black of overlays / text strokes.
Theme.Plain = Color3.fromHex(UiPalette.neutral.plain)
Theme.Shade = Color3.fromHex(UiPalette.neutral.shade)

-- The role table of a surface ("paper" when nil).
function Theme.surface(name: SurfaceName?): Roles
	return if name == "iron" then Theme.Iron else Theme.Paper
end

local readableCache: { [string]: Color3 } = {}

-- The background colours of a surface (UiPalette.BACKGROUNDS: surface, raised, sunken, hover, selected).
local function backgroundsOf(surface: SurfaceName?): { string }
	local s = (if surface == "iron" then UiPalette.iron else UiPalette.paper) :: any
	local out = {}
	for _, role in UiPalette.BACKGROUNDS do
		table.insert(out, s[role] :: string)
	end
	return out
end

local BACKGROUNDS = { paper = backgroundsOf("paper"), iron = backgroundsOf("iron") }

-- Hex of a game-data colour corrected to the contrast `min` (default 4.5) on every background role of the surface
-- (rows on Raised / Selected included).
function Theme.readableHex(hex: string, surface: SurfaceName?, min: number?): string
	local list = if surface == "iron" then BACKGROUNDS.iron else BACKGROUNDS.paper
	return Contrast.readableOn(hex, list, min or UiPalette.MIN_TEXT)
end

-- S135: a colour from game data (class, element, rarity, title, TooltipModel `hex`) as text on a surface: the only
-- way from such a hex to TextColor3 in windows on the new look. Cached by key.
function Theme.readable(hex: string, surface: SurfaceName?, min: number?): Color3
	local key = `{hex}|{surface or "paper"}|{min or 0}`
	local cached = readableCache[key]
	if cached then
		return cached
	end
	local color = Color3.fromHex(Theme.readableHex(hex, surface, min))
	readableCache[key] = color
	return color
end

-- "#RRGGBB" of a token for RichText `<font color="...">`.
function Theme.hex(color: Color3): string
	return "#" .. string.upper(color:ToHex())
end

-- A token mixed towards another (hover / pressed / disabled states of components).
function Theme.mix(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

-- Legacy dark palette: windows not yet on parchment (Data/UiWindows `paper = false`) and the HUD. Removed in S136.
Theme.Colors = {
	-- Surfaces
	Background = Color3.fromHex("#14161B"),
	Panel = Color3.fromHex("#1B1D23"),
	PanelRaised = Color3.fromHex("#252832"),
	PanelHover = Color3.fromHex("#2E323E"),
	Overlay = Color3.fromHex("#000000"),

	-- Lines and accents
	Gold = Color3.fromHex("#C9A45C"),
	GoldBright = Color3.fromHex("#E8C25A"),
	GoldDim = Color3.fromHex("#7A6438"),
	-- S124: second and third place in rankings (with GoldBright for the first)
	Silver = Color3.fromHex("#C9CED6"),
	Bronze = Color3.fromHex("#C48A58"),
	Border = Color3.fromHex("#3A3F4C"),
	Accent = Color3.fromHex("#4A8FE7"),
	AccentHover = Color3.fromHex("#5E9EF0"),
	AccentPressed = Color3.fromHex("#3874C4"),

	-- Text
	Text = Color3.fromHex("#E8E4DA"),
	TextMuted = Color3.fromHex("#9A9DA8"),
	TextDark = Color3.fromHex("#2A2218"),
	Parchment = Color3.fromHex("#EADDBE"),

	-- Status
	Danger = Color3.fromHex("#B8423A"),
	DangerHover = Color3.fromHex("#CC5248"),
	Success = Color3.fromHex("#4FD16B"),
	Warning = Color3.fromHex("#E0A23B"),

	-- Resources
	Hp = Color3.fromHex("#C2352E"),
	Mana = Color3.fromHex("#3D6FD6"),
	Energy = Color3.fromHex("#D9B23A"),
	Exp = Color3.fromHex("#8E5BD9"),

	-- PvP zones
	ZoneGreen = Color3.fromHex("#4FD16B"),
	ZoneYellow = Color3.fromHex("#E0C23B"),
	ZoneRed = Color3.fromHex("#D64A3E"),
}

-- Item rarity colours live in Shared.Data.Rarities (S30: `color`, `textColor`, `frame`); see UI/ItemText.

-- S135: Merriweather (the heaviest weight; Roblox picks the nearest it has) for window titles and headings instead
-- of the decorative Fondamento; Builder Sans stays the body face (the Roblox counterpart of the mock-up's sans).
local DISPLAY = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy)

Theme.Fonts = {
	Display = DISPLAY,
	Heading = DISPLAY,
	Body = Font.fromEnum(Enum.Font.BuilderSans),
	BodyBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	BodyMedium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
}

-- Sizes are in pixels at the base resolution; UIScale adapts them to the screen.
-- S135: Caption only for upper-case section labels; body text >= Small (17).
Theme.TextSize = {
	Caption = 15,
	Small = 17,
	Body = 20,
	Large = 24,
	Title = 30,
	Hero = 64,
}

Theme.Size = {
	ButtonHeight = 52,
	ButtonHeightSmall = 40,
	IconButton = 52,
	MinTouch = 44,
	InputHeight = 52,
	WindowHeader = 52,
	BarHeight = 22,
	-- S135
	RowHeight = 48, -- list row (>= MinTouch)
	SlotSize = 64, -- item slot (ItemSlot default)
	FrameOuter = 3, -- iron window frame
	FrameInner = 1, -- brass line inside it
	HeaderRule = 2, -- brass line under the title bar
}

Theme.Corner = {
	Small = UDim.new(0, 6),
	Medium = UDim.new(0, 10),
	Large = UDim.new(0, 16),
	Round = UDim.new(1, 0),
}

Theme.Padding = {
	Tiny = 4,
	Small = 8,
	Medium = 14,
	Large = 22,
	Huge = 36,
}

Theme.Stroke = {
	Thin = 1,
	Normal = 2,
	Thick = 3,
}

Theme.Anim = {
	Fast = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	BarSpeed = 18, -- Spring speed for resource bars
}

-- Base resolution for UIScale (see UI/Scale).
Theme.BaseResolution = Vector2.new(1920, 1080)
-- Touch devices use a smaller base so everything renders larger.
Theme.BaseResolutionTouch = Vector2.new(1280, 720)

return Theme
