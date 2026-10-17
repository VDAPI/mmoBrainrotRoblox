--!strict
-- Story cutscene overlay (S102, CutsceneController, on the Modals layer): black cinema bars (12% of the height on PC,
-- 9% on a phone), the chapter title in the middle (gold, with the chapter line under it), the current line in the
-- bottom bar (speaker in gold, narration in italics, up to 1100 px wide), "Skip" in the top bar and the "Next ▸" hint
-- at the right edge of the bottom bar. A click or tap anywhere goes to the next line. The card mode (no shot
-- possible) shows the same over a dimmed view. `Black` fades the whole screen for the cuts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Title: Fusion.UsedAs<string?>, -- text (already localized)
	Subtitle: Fusion.UsedAs<string?>,
	Speaker: Fusion.UsedAs<string?>, -- nil = narration
	Line: Fusion.UsedAs<string?>,
	Card: Fusion.UsedAs<boolean>, -- card mode: dim the whole view (Config.Cutscene.cardDim)
	CardDim: number,
	Black: Fusion.UsedAs<number>, -- 0 = clear .. 1 = black (fades)
	OnSkip: () -> (),
	OnNext: () -> (),
}

local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function Cutscene(scope: Scope, props: Props): Instance
	local touch = Device.Touch
	local bar = scope:Computed(function(use): number
		return if use(touch) then 0.09 else 0.12
	end)
	local function sized(pc: number, phone: number): Fusion.Computed<number>
		return scope:Computed(function(use): number
			return if use(touch) then phone else pc
		end)
	end
	local lineText = scope:Computed(function(use): string
		local line = use(props.Line)
		if not line then
			return ""
		end
		local speaker = use(props.Speaker)
		if speaker then
			local gold = "#" .. Theme.Iron.Heading:ToHex()
			return `<font color="{gold}"><b>{escape(speaker)}</b></font>   {escape(line)}`
		end
		return `<i>{escape(line)}</i>`
	end)
	return scope:New("TextButton")({
		Name = "Cutscene",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Shade,
		BackgroundTransparency = scope:Computed(function(use): number
			return if use(props.Card) then 1 - props.CardDim else 1
		end),
		AutoButtonColor = false,
		Text = "",
		Active = true,
		ZIndex = 50,
		[OnEvent("Activated")] = function()
			props.OnNext()
		end,
		[Children] = {
			-- top bar with "Skip"
			scope:New("Frame")({
				Name = "Top",
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromScale(1, use(bar))
				end),
				BackgroundColor3 = Theme.Shade,
				BorderSizePixel = 0,
				ZIndex = 51,
				[Children] = {
					scope:New("TextButton")({
						Name = "Skip",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -24, 0.5, 0),
						Size = scope:Computed(function(use): UDim2
							return if use(touch) then UDim2.fromOffset(120, 44) else UDim2.fromOffset(160, 48)
						end),
						BackgroundColor3 = Theme.Iron.Raised,
						BackgroundTransparency = 0.2,
						AutoButtonColor = true,
						Text = Text.T(scope, "cutscene.skip"),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = sized(Theme.TextSize.Large, Theme.TextSize.Body),
						TextColor3 = Theme.Iron.Text,
						ZIndex = 52,
						[OnEvent("Activated")] = function()
							props.OnSkip()
						end,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
						},
					}),
				},
			}),
			-- bottom bar with the line and the "Next" hint
			scope:New("Frame")({
				Name = "Bottom",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromScale(1, use(bar))
				end),
				BackgroundColor3 = Theme.Shade,
				BorderSizePixel = 0,
				ZIndex = 51,
				[Children] = {
					scope:New("TextLabel")({
						Name = "Line",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = scope:Computed(function(use): UDim2
							-- clear of the hint on the right (also on 800 x 400)
							return UDim2.new(1, if use(touch) then -220 else -320, 1, -8)
						end),
						BackgroundTransparency = 1,
						RichText = true,
						TextWrapped = true,
						Text = lineText,
						FontFace = Theme.Fonts.Body,
						TextSize = sized(Theme.TextSize.Large, Theme.TextSize.Body),
						TextColor3 = Theme.Iron.Text,
						ZIndex = 52,
						[Children] = {
							scope:New("UISizeConstraint")({ MaxSize = Vector2.new(1100, math.huge) }),
						},
					}),
					scope:New("TextLabel")({
						Name = "Next",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -24, 0.5, 0),
						Size = UDim2.fromOffset(110, 30),
						BackgroundTransparency = 1,
						Text = Text.T(scope, "cutscene.next"),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = sized(Theme.TextSize.Body, Theme.TextSize.Small),
						TextColor3 = Theme.Iron.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Right,
						ZIndex = 52,
					}),
				},
			}),
			-- the chapter title in the middle
			scope:New("Frame")({
				Name = "Title",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.fromScale(0.9, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(props.Title) ~= nil
				end),
				ZIndex = 52,
				[Children] = {
					scope:New("UIListLayout")({
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					scope:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextWrapped = true,
						Text = scope:Computed(function(use): string
							return use(props.Title) or ""
						end),
						FontFace = Theme.Fonts.Display,
						TextSize = sized(Theme.TextSize.Hero, Theme.TextSize.Title + 10),
						TextColor3 = Theme.Brass.Bright,
						TextStrokeTransparency = 0.5,
						ZIndex = 52,
					}),
					scope:New("TextLabel")({
						LayoutOrder = 2,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextWrapped = true,
						Visible = scope:Computed(function(use): boolean
							return use(props.Subtitle) ~= nil
						end),
						Text = scope:Computed(function(use): string
							return use(props.Subtitle) or ""
						end),
						FontFace = Theme.Fonts.Display,
						TextSize = sized(Theme.TextSize.Title, Theme.TextSize.Large),
						TextColor3 = Theme.Iron.Text,
						TextStrokeTransparency = 0.6,
						ZIndex = 52,
					}),
				},
			}),
			-- fades between cuts
			scope:New("Frame")({
				Name = "Black",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Shade,
				BackgroundTransparency = scope:Computed(function(use): number
					return 1 - use(props.Black)
				end),
				BorderSizePixel = 0,
				ZIndex = 60,
			}),
		},
	}) :: Instance
end

return Cutscene
