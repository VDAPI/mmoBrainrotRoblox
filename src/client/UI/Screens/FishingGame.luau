--!strict
-- Fishing minigame (DESIGN §12). Waiting: "Waiting for a bite..." with a Cancel button. Bite: a horizontal
-- bar with a green zone and an indicator sweeping back and forth; click / Space / tap while the indicator is
-- inside the zone, 3 times in a row. Every hit narrows the zone and speeds up the indicator; a miss lets the
-- fish escape. Big touch targets: the whole bar area is the button.
-- Owner 2026-11-10 (UI plan E, Logic/WorldLayout.fishing): the panel never stands under Roblox's top bar (it is in the
-- Windows layer, which reaches under it). On a phone it is 170 tall between the HUD's left and right columns, at the
-- top of the free middle (nothing is targeted while fishing): the title, the bar, a two-line touch hint under it;
-- "Anuluj" shows while waiting (a bite lasts seconds and ends by itself).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local Scale = require(script.Parent.Parent.Scale)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local WorldLayout = require(ReplicatedStorage.Shared.Logic.WorldLayout)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Params = {
	zone: number,
	speed: number,
	hits: number,
	shrink: number,
	speedUp: number,
	timeLimit: number,
	auto: boolean?,
}

export type Props = {
	-- nil = hidden, "waiting", "bite"
	Phase: Fusion.UsedAs<string?>,
	Params: Fusion.UsedAs<Params?>,
	-- Bumped by the controller to start a new minigame round.
	Round: Fusion.UsedAs<number>,
	OnFinish: (hits: number) -> (),
	OnCancel: () -> (),
	-- Set by the controller so Space / clicks outside the bar can press too.
	PressSignal: { press: (() -> ())? },
}

local function FishingGame(scope: Scope, props: Props): Instance
	local position = scope:Value(0) -- 0..1
	local zoneCenter = scope:Value(0.5)
	local zoneWidth = scope:Value(0.2)
	local hits = scope:Value(0)
	local flash = scope:Value(Theme.Iron.Success)
	local running = false
	local direction = 1
	local speed = 1
	local params: Params? = nil
	local startedAt = 0

	local function finish(result: number)
		if not running then
			return
		end
		running = false
		props.OnFinish(result)
	end

	local function newZone()
		local width = Fusion.peek(zoneWidth)
		zoneCenter:set(width / 2 + math.random() * (1 - width))
	end

	local function start()
		params = Fusion.peek(props.Params)
		if not params then
			return
		end
		running = true
		direction = 1
		speed = params.speed
		startedAt = os.clock()
		hits:set(0)
		position:set(0)
		zoneWidth:set(params.zone)
		newZone()
		if params.auto then
			task.delay(1, function()
				hits:set(params and params.hits or 3)
				finish(params and params.hits or 3)
			end)
		end
	end

	local function press()
		local current = params
		if not running or not current or current.auto then
			return
		end
		local p = Fusion.peek(position)
		local center, width = Fusion.peek(zoneCenter), Fusion.peek(zoneWidth)
		if math.abs(p - center) <= width / 2 then
			local count = Fusion.peek(hits) + 1
			hits:set(count)
			flash:set(Theme.Iron.Success)
			if count >= current.hits then
				finish(count)
				return
			end
			zoneWidth:set(width * current.shrink)
			speed *= current.speedUp
			newZone()
		else
			flash:set(Theme.Iron.Danger)
			finish(Fusion.peek(hits))
		end
	end
	props.PressSignal.press = press

	scope:Observer(props.Round):onChange(function()
		start()
	end)

	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt)
			if not running then
				return
			end
			local current = params
			if current and os.clock() - startedAt > current.timeLimit then
				finish(Fusion.peek(hits))
				return
			end
			local p = Fusion.peek(position) + direction * speed * 2 * dt
			if p >= 1 then
				p, direction = 1, -1
			elseif p <= 0 then
				p, direction = 0, 1
			end
			position:set(p)
		end)
	)

	local isBite = scope:Computed(function(use): boolean
		return use(props.Phase) == "bite"
	end)

	-- owner 2026-11-10: the layer is the whole screen; Roblox's top bar (Scale.TopBar, screen px) is cut off its top
	local layout = scope:Computed(function(use): WorldLayout.Fishing
		local size: Vector2 = use(Scale.VirtualSize)
		local bar = use(Scale.TopBar) / use(Scale.Value)
		return WorldLayout.fishing({ w = size.X, h = size.Y }, bar, use(PhoneLayout.Compact))
	end)
	-- the bar's top and height, and the glyph's top while waiting
	local function barTop(use: Fusion.Use): number
		return if use(layout).compact then 48 else 60
	end

	return scope:New("Frame")({
		Name = "Fishing",
		Position = scope:Computed(function(use): UDim2
			local panel = use(layout).panel
			return UDim2.fromOffset(panel.left, panel.top)
		end),
		Size = scope:Computed(function(use): UDim2
			local panel = use(layout).panel
			return UDim2.fromOffset(panel.right - panel.left, panel.bottom - panel.top)
		end),
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Visible = scope:Computed(function(use): boolean
			return use(props.Phase) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("TextLabel")({
				Position = scope:Computed(function(use): UDim2
					return if use(layout).compact then UDim2.fromOffset(12, 6) else UDim2.fromOffset(0, 10)
				end),
				Size = scope:Computed(function(use): UDim2
					return if use(layout).compact then UDim2.new(1, -24, 0, 34) else UDim2.new(1, 0, 0, 40)
				end),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					if use(isBite) then
						return `❗ {Text.get(use, "fish.bite")}  {use(hits)}/{(use(props.Params) or { hits = 3 }).hits}`
					end
					return Text.get(use, "fish.waiting")
				end),
				FontFace = Theme.Fonts.Display,
				TextSize = scope:Computed(function(use): number
					return if use(layout).compact then Theme.TextSize.Body else Theme.TextSize.Large
				end),
				TextColor3 = scope:Computed(function(use): Color3
					return if use(isBite) then Theme.Brass.Bright else Theme.Iron.Text
				end),
			}),
			-- The bar (also the big tap target)
			scope:New("TextButton")({
				Name = "Bar",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = scope:Computed(function(use): UDim2
					return UDim2.new(0.5, 0, 0, barTop(use))
				end),
				Size = scope:Computed(function(use): UDim2
					local l = use(layout)
					return UDim2.fromOffset(l.bar, if l.compact then 52 else 64)
				end),
				BackgroundColor3 = Theme.Iron.Sunken,
				AutoButtonColor = false,
				Text = "",
				Visible = isBite,
				[OnEvent("Activated")] = press,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({ Color = flash, Thickness = 2 }),
					scope:New("Frame")({
						Name = "Zone",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = scope:Computed(function(use): UDim2
							return UDim2.fromScale(use(zoneCenter), 0)
						end),
						Size = scope:Computed(function(use): UDim2
							return UDim2.fromScale(use(zoneWidth), 1)
						end),
						BackgroundColor3 = Theme.Iron.Success,
						BackgroundTransparency = 0.35,
						[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					}),
					scope:New("Frame")({
						Name = "Indicator",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = scope:Computed(function(use): UDim2
							return UDim2.fromScale(use(position), 0.5)
						end),
						Size = UDim2.new(0, 8, 1, 16),
						BackgroundColor3 = Theme.Iron.Selected,
						ZIndex = 2,
						[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
					}),
				},
			}),
			scope:New("TextLabel")({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = scope:Computed(function(use): UDim2
					return UDim2.new(0.5, 0, 0, barTop(use) + (if use(layout).compact then 2 else 12))
				end),
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(use(layout).bar, 40)
				end),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(isBite)
				end),
				Text = "〰  ◯  〰",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Title,
				TextColor3 = Theme.Iron.Link,
			}),
			scope:New("TextLabel")({
				-- a phone: two lines under the bar, the whole width (the touch hint)
				Position = scope:Computed(function(use): UDim2
					return if use(layout).compact then UDim2.fromOffset(12, 116) else UDim2.new(0, 20, 1, -50)
				end),
				Size = scope:Computed(function(use): UDim2
					return if use(layout).compact then UDim2.new(1, -24, 0, 44) else UDim2.new(1, -200, 0, 40)
				end),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					if not use(isBite) then
						return ""
					end
					return Text.get(use, if use(layout).compact then "fish.hintTouch" else "fish.hint")
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Button(scope, {
				Surface = "iron", -- S135: on a dark HUD / overlay surface
				-- owner 2026-11-10: a phone shows it while waiting, in the hint's place under the bar
				Visible = scope:Computed(function(use): boolean
					return not (use(layout).compact and use(isBite))
				end),
				AnchorPoint = scope:Computed(function(use): Vector2
					return if use(layout).compact then Vector2.new(0.5, 1) else Vector2.new(1, 1)
				end),
				Position = scope:Computed(function(use): UDim2
					return if use(layout).compact then UDim2.new(0.5, 0, 1, -10) else UDim2.new(1, -14, 1, -10)
				end),
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(if use(layout).compact then 140 else 150, 44)
				end),
				Text = Text.T(scope, "common.cancel"),
				OnClick = function()
					running = false
					props.OnCancel()
				end,
			}),
		},
	})
end

return FishingGame
