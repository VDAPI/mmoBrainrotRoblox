--!strict
-- Low health warning (S134f, DESIGN §23): a red vignette (four edge bands with a transparency gradient, no image)
-- pulsing with a heartbeat below Config.LowHp.onPct of max HP (Logic/LowHp: hysteresis, stronger at lower HP),
-- and the `ui.lowHp` heartbeat (silent until the owner picks an id). Purely client side: reads `character.hp` and
-- `derived.values.maxHp`, sends nothing. Off with the setting `lowHpWarn`, while dead (death screen), in the arena
-- stands as a spectator and with the HUD (cutscenes hide the whole HUD root). Below windows and toasts (HUD ZIndex 1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LowHp = require(ReplicatedStorage.Shared.Logic.LowHp)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children
local peek = Fusion.peek

type Scope = Fusion.Scope<typeof(Fusion)>

local CFG = Config.LowHp
local BAND = 0.22 -- band depth as a share of the screen side

-- Visible on screen: this frame and every GuiObject / ScreenGui above it is shown.
local function onScreen(instance: Instance): boolean
	local node: Instance? = instance
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		elseif node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

-- One edge band: solid at the edge, fading towards the centre (`rotation` points the gradient inwards).
local function band(
	scope: Scope,
	alpha: Fusion.Value<number>,
	size: UDim2,
	position: UDim2,
	anchor: Vector2,
	rotation: number
): Instance
	return scope:New("Frame")({
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = Theme.Colors.Danger,
		BackgroundTransparency = alpha,
		BorderSizePixel = 0,
		Active = false,
		[Children] = {
			scope:New("UIGradient")({
				Rotation = rotation,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		},
	})
end

local function LowHpVignette(scope: Scope): Instance
	local hp = State.Value({ "character", "hp" })
	local maxHp = State.Value({ "derived", "values", "maxHp" })
	local enabled = State.Value({ "account", "settings", "lowHpWarn" })
	local death = State.Value({ "death" })
	local tourney = State.Value({ "tourney" })

	local on = scope:Value(false)
	local intensity = scope:Value(0)
	local function update()
		local isOn, strength = LowHp.state(peek(hp), peek(maxHp), peek(on), CFG)
		on:set(isOn)
		intensity:set(strength)
	end
	update()
	scope:Observer(hp):onChange(update)
	scope:Observer(maxHp):onChange(update)

	local spectator = scope:Computed(function(use): boolean
		local t = use(tourney)
		local me = type(t) == "table" and type(t.live) == "table" and t.live.me or nil
		return type(me) == "table" and me.state == "spectator"
	end)
	local shown = scope:Computed(function(use): boolean
		return use(on) and use(enabled) ~= false and use(death) == nil and not use(spectator)
	end)

	-- Every band shares one transparency driven by the heartbeat tween.
	local alpha = scope:Value(1)
	local root = scope:New("Frame")({
		Name = "LowHpVignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = 1,
		Visible = shown,
		[Children] = {
			band(scope, alpha, UDim2.fromScale(1, BAND), UDim2.fromScale(0, 0), Vector2.zero, 90),
			band(scope, alpha, UDim2.fromScale(1, BAND), UDim2.fromScale(0, 1), Vector2.new(0, 1), 270),
			band(scope, alpha, UDim2.fromScale(BAND, 1), UDim2.fromScale(0, 0), Vector2.zero, 0),
			band(scope, alpha, UDim2.fromScale(BAND, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180),
		},
	})
	local focused = true
	table.insert(
		scope,
		UserInputService.WindowFocused:Connect(function()
			focused = true
		end)
	)
	table.insert(
		scope,
		UserInputService.WindowFocusReleased:Connect(function()
			focused = false
		end)
	)

	-- Heartbeat: a quick rise to the strength of this beat and a slower fade, then the next beat.
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	local pulse = Instance.new("NumberValue")
	pulse.Value = 1
	table.insert(scope, pulse)
	table.insert(
		scope,
		pulse.Changed:Connect(function(value: number)
			alpha:set(value)
		end)
	)
	task.spawn(function()
		while alive do
			local strength = peek(intensity)
			local interval = LowHp.beatInterval(strength, CFG)
			if peek(shown) and onScreen(root) then
				local peak = 1 - CFG.maxAlpha * (0.45 + 0.55 * strength)
				local rest = 1 - CFG.maxAlpha * (0.2 + 0.3 * strength)
				pulse.Value = rest
				TweenService:Create(pulse, TweenInfo.new(interval * 0.18, Enum.EasingStyle.Quad), { Value = peak })
					:Play()
				task.delay(interval * 0.18, function()
					if alive then
						TweenService:Create(
							pulse,
							TweenInfo.new(interval * 0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
							{ Value = rest }
						):Play()
					end
				end)
				if focused then
					Sounds.key("ui.lowHp", 0.6 + 0.4 * strength)
				end
			else
				pulse.Value = 1
			end
			task.wait(interval)
		end
	end)

	return root
end

return LowHpVignette
