--!strict
-- Emote wheel (S123, DESIGN-17 §4): an overlay in the middle of the screen (not a window: it closes after a choice)
-- with up to PAGE owned emotes on a circle (glyph and name, buttons of at least 56 px for touch), "◀ ▶" when there
-- are more, "Close" in the middle and a click outside closing it. An emote that cannot start now (dead, riding, a
-- skill being cast; the server checks combat and the cooldown too) is dimmed and its tooltip says why; picking it
-- shows the reason instead of asking the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRules = require(ReplicatedStorage.Shared.Logic.CosmeticRules)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)
local Tooltip = require(script.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Play: (cosmeticId: string) -> (),
	Close: () -> (),
	-- why no emote can start now (an error key of emote.error.*), nil = free
	Blocked: Fusion.UsedAs<string?>,
}

local PAGE = 8
local RADIUS = 150
local BUTTON = Vector2.new(112, 72)
local CENTER = 84

local function EmoteWheel(scope: Scope, props: Props): Instance
	local account = State.Value({ "account" })
	local page = scope:Value(1)
	local owned = scope:Computed(function(use): { string }
		return CosmeticRules.ownedEmotes(use(account))
	end)
	local pages = scope:Computed(function(use): number
		return math.max(1, math.ceil(#use(owned) / PAGE))
	end)

	local buttons = scope:Computed(function(use, s: Scope): { Instance }
		local list = use(owned)
		local p = math.clamp(use(page), 1, use(pages))
		local first = (p - 1) * PAGE + 1
		local count = math.min(PAGE, #list - first + 1)
		local out: { Instance } = {}
		if count <= 0 then
			table.insert(
				out,
				s:New("TextLabel")({
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0.5, -CENTER),
					Size = UDim2.fromOffset(280, 30),
					BackgroundTransparency = 1,
					Text = Text.get(use, "emote.wheel.empty"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.TextMuted,
				})
			)
		end
		for i = 1, math.max(0, count) do
			local id = list[first + i - 1]
			local def = Cosmetics.get(id) :: Cosmetics.Def
			local angle = math.rad(-90 + (i - 1) * 360 / math.max(count, 1))
			local blocked = s:Computed(function(use2): string?
				return use2(props.Blocked)
			end)
			local button = s:New("TextButton")({
				Name = id,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, math.cos(angle) * RADIUS, 0.5, math.sin(angle) * RADIUS),
				Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
				AutoButtonColor = true,
				BackgroundColor3 = Theme.Colors.PanelRaised,
				BackgroundTransparency = s:Computed(function(use2): number
					return if use2(blocked) then 0.55 else 0.1
				end),
				Text = "",
				[OnEvent("Activated")] = function()
					local why = Fusion.peek(blocked)
					if why then
						Sounds.play("error")
						Toast.push(Text.now(why), "error")
						return
					end
					Sounds.play("click")
					props.Play(id)
				end,
				[Children] = {
					s:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					s:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromHex(def.color),
						Thickness = Theme.Stroke.Normal,
					}),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(0, 6),
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						Text = def.icon,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 26,
						TextColor3 = s:Computed(function(use2): Color3
							return if use2(blocked) then Theme.Colors.TextMuted else Theme.Colors.Text
						end),
					}),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(4, 40),
						Size = UDim2.new(1, -8, 0, 24),
						BackgroundTransparency = 1,
						Text = Text.get(use, def.nameKey),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = s:Computed(function(use2): Color3
							return if use2(blocked) then Theme.Colors.TextMuted else Theme.Colors.Parchment
						end),
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
				},
			}) :: GuiObject
			Tooltip.attach(
				s,
				button,
				s:Computed(function(use2): string
					local why = use2(blocked)
					return if why then Text.get(use2, why) else Text.get(use2, def.nameKey)
				end)
			)
			table.insert(out, button)
		end
		return out
	end)

	local function arrow(text: string, x: number, delta: number): Instance
		return scope:New("TextButton")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, x, 0.5, RADIUS + BUTTON.Y),
			Size = UDim2.fromOffset(Theme.Size.MinTouch + 12, Theme.Size.MinTouch + 12),
			Visible = scope:Computed(function(use): boolean
				return use(pages) > 1
			end),
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.15,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Large,
			TextColor3 = Theme.Colors.Gold,
			[OnEvent("Activated")] = function()
				Sounds.play("click")
				local n = Fusion.peek(pages)
				page:set((Fusion.peek(page) - 1 + delta) % n + 1)
			end,
			[Children] = { scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }) },
		})
	end

	return scope:New("TextButton")({
		Name = "EmoteWheel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		AutoButtonColor = false,
		Text = "",
		-- a click outside the buttons closes the wheel
		[OnEvent("Activated")] = function()
			props.Close()
		end,
		[Children] = {
			scope:New("TextLabel")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, -(RADIUS + BUTTON.Y + 10)),
				Size = UDim2.fromOffset(300, 36),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "emote.wheel"),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.Gold,
			}),
			scope:New("TextButton")({
				Name = "Close",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(CENTER, CENTER),
				BackgroundColor3 = Theme.Colors.Panel,
				BackgroundTransparency = 0.1,
				Text = Text.T(scope, "emote.wheel.close"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Text,
				[OnEvent("Activated")] = function()
					Sounds.play("click")
					props.Close()
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Theme.Colors.GoldDim,
						Thickness = Theme.Stroke.Normal,
					}),
				},
			}),
			buttons :: any,
			arrow("◀", -70, -1),
			arrow("▶", 70, 1),
		},
	})
end

return EmoteWheel
