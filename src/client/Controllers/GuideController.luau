--!strict
-- First steps guide (S14): when a new character enters the world (character.guideDone = false) a short
-- series of speech bubbles points at the HUD parts (bars, skills, potions, menu, minimap, quest tracker,
-- chat). "Next" goes on, "Skip" ends it; both finish with GuideDone so it never shows again. The story
-- tutorial (S11) runs alongside and takes over after the last bubble.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.UI.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local Children = Fusion.Children

local GuideController = {
	Name = "GuideController",
	Deps = { "UIController" },
}

type Step = { key: string, anchor: Vector2, position: UDim2, arrow: string }

-- Bubble positions in the scaled HUD layer (1920x1080 base).
local STEPS: { Step } = {
	{ key = "guide.welcome", anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.42), arrow = "" },
	{ key = "guide.bars", anchor = Vector2.new(0, 0), position = UDim2.fromOffset(40, 190), arrow = "▲" },
	{ key = "guide.skills", anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -170), arrow = "▼" },
	{ key = "guide.potions", anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 380, 1, -170), arrow = "▼" },
	{ key = "guide.menu", anchor = Vector2.new(1, 0), position = UDim2.new(1, -40, 0, 100), arrow = "▲" },
	{ key = "guide.minimap", anchor = Vector2.new(1, 0), position = UDim2.new(1, -300, 0, 170), arrow = "▶" },
	{ key = "guide.quests", anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -330, 0.5, 0), arrow = "▶" },
	{ key = "guide.chat", anchor = Vector2.new(0, 0), position = UDim2.fromOffset(460, 40), arrow = "◀" },
	{ key = "guide.end", anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.42), arrow = "" },
}

local scope = Fusion.scoped(Fusion)
local step = scope:Value(0) -- 0 = hidden

local function finish()
	step:set(0)
	Net.Send("GuideDone")
end

local function bubble(): Instance
	local current = scope:Computed(function(use): Step?
		local i = use(step)
		return if i > 0 then STEPS[i] else nil
	end)
	return scope:New("Frame")({
		Name = "Guide",
		AnchorPoint = scope:Computed(function(use): Vector2
			local s = use(current)
			return if s then s.anchor else Vector2.zero
		end),
		Position = scope:Computed(function(use): UDim2
			local s = use(current)
			return if s then s.position else UDim2.new()
		end),
		Size = UDim2.fromOffset(460, 190),
		BackgroundColor3 = Theme.Colors.Parchment,
		Visible = scope:Computed(function(use): boolean
			return use(current) ~= nil
		end),
		ZIndex = 40,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 2 }),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(16, 10),
				Size = UDim2.new(1, -32, 0, 30),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local s = use(current)
					local arrow = if s and s.arrow ~= "" then `{s.arrow}  ` else ""
					return `{arrow}{Text.get(use, "guide.title", { n = use(step), total = #STEPS })}`
				end),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.TextDark,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 41,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(16, 44),
				Size = UDim2.new(1, -32, 0, 82),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local s = use(current)
					return if s then Text.get(use, s.key) else ""
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.TextDark,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 41,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 16, 1, -12),
				Size = UDim2.fromOffset(150, 44),
				Variant = "ghost",
				Text = Text.T(scope, "guide.skip"),
				OnClick = finish,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -16, 1, -12),
				Size = UDim2.fromOffset(170, 44),
				Variant = "primary",
				Text = scope:Computed(function(use): string
					return Text.get(use, if use(step) >= #STEPS then "guide.done" else "guide.next")
				end),
				OnClick = function()
					local i = Fusion.peek(step)
					if i >= #STEPS then
						finish()
					else
						step:set(i + 1)
					end
				end,
			}),
		},
	})
end

function GuideController.Init(registry)
	bubble().Parent = registry.Get("UIController").GetLayer("Modals")
end

function GuideController.Start()
	local function check()
		local playing = State.Get({ "session", "phase" }) == "playing"
		local pending = State.Get({ "character", "guideDone" }) == false
		if playing and pending and Fusion.peek(step) == 0 then
			step:set(1)
		elseif not (playing and pending) then
			step:set(0)
		end
	end
	scope:Observer(State.Value({ "session", "phase" })):onBind(check)
	scope:Observer(State.Value({ "character", "guideDone" })):onBind(check)
end

return GuideController
