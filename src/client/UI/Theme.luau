--!strict
-- Visual language (DESIGN §23): serious fantasy. Every component reads colours, fonts, sizes and
-- timings from here; never hardcode them in screens.

local Theme = {}

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

Theme.Fonts = {
	Heading = Font.fromEnum(Enum.Font.Fondamento),
	Body = Font.fromEnum(Enum.Font.BuilderSans),
	BodyBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	BodyMedium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
}

-- Sizes are in pixels at the base resolution; UIScale adapts them to the screen.
Theme.TextSize = {
	Small = 16,
	Body = 20,
	Large = 24,
	Title = 32,
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
