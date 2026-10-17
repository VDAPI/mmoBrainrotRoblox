--!strict
-- S101b (DESIGN-15 §3.5): the box of an NPC comment at the left edge of the screen (layer Toasts), used when the
-- speaker is not near enough for a bubble: a portrait (one shared Preview; the NPC's glyph when its model is not
-- streamed in), the name and the line (up to two rows). It slides in, and goes after Config.Barks.toastSeconds or on a
-- click / touch. PC: 380 x 76 at 42% of the height; phone (Device.Touch): 300 x 68 at 30%, above the joystick and away
-- from the skill buttons. BarkController shows one comment at a time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Preview = require(script.Parent.Parent.WorldMap.Preview)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Api = {
	frame: Instance,
	show: (npcId: string, line: string) -> (),
	hide: () -> (),
}

local MARGIN = 16
local PORTRAIT = 56

local BarkToast = {}

function BarkToast.new(scope: Scope): Api
	local npc = scope:Value(nil :: string?)
	local line = scope:Value("")
	local token = 0
	local preview = Preview.new(scope, nil, { portrait = true })

	local size = scope:Computed(function(use): Vector2
		return if use(Device.Touch) then Vector2.new(300, 68) else Vector2.new(380, 76)
	end)
	local height = scope:Computed(function(use): number
		return if use(Device.Touch) then 0.3 else 0.42
	end)

	local box: Frame
	local hidden = scope:Computed(function(use): UDim2
		return UDim2.new(0, -use(size).X - MARGIN, use(height), 0)
	end)
	local shown = scope:Computed(function(use): UDim2
		return UDim2.new(0, MARGIN, use(height), 0)
	end)

	local function hide()
		token += 1
		if box then
			TweenService:Create(box, TweenInfo.new(0.2), { Position = Fusion.peek(hidden) }):Play()
			local mine = token
			task.delay(0.25, function()
				if token == mine then
					box.Visible = false
				end
			end)
		end
	end

	box = scope:New("Frame")({
		Name = "BarkToast",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = Fusion.peek(hidden),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(use(size).X, use(size).Y)
		end),
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Visible = false,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("Frame")({
				Name = "Portrait",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 10, 0.5, 0),
				Size = UDim2.fromOffset(PORTRAIT, PORTRAIT),
				BackgroundColor3 = Theme.Iron.Sunken,
				ClipsDescendants = true,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
					preview.frame,
				},
			}),
			scope:New("TextLabel")({
				Name = "Name",
				Position = UDim2.fromOffset(PORTRAIT + 20, 6),
				Size = UDim2.new(1, -(PORTRAIT + 28), 0, 18),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local def = Npcs.get(use(npc) or "")
					return if def then Text.get(use, def.nameKey) else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Name = "Line",
				Position = UDim2.fromOffset(PORTRAIT + 20, 26),
				Size = UDim2.new(1, -(PORTRAIT + 28), 1, -30),
				BackgroundTransparency = 1,
				Text = line,
				TextWrapped = true,
				TextScaled = false,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
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

	local function show(npcId: string, text: string)
		token += 1
		local mine = token
		npc:set(npcId)
		line:set(text)
		local def = Npcs.get(npcId)
		preview.show(
			if def
				then { kind = "npc", id = def.id, glyph = def.icon }
				else { kind = "glyph", id = "", glyph = "?", color = Theme.Iron.Text }
		)
		box.Position = Fusion.peek(hidden)
		box.Visible = true
		TweenService:Create(box, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = Fusion.peek(shown),
		}):Play()
		task.delay(Config.Barks.toastSeconds, function()
			if token == mine then
				hide()
			end
		end)
	end

	return { frame = box, show = show, hide = hide }
end

return BarkToast
