--!strict
-- Fishing minigame (DESIGN §12). Waiting: "Waiting for a bite..." with a Cancel button. Bite: a horizontal
-- bar with a green zone and an indicator sweeping back and forth; click / Space / tap while the indicator is
-- inside the zone, 3 times in a row. Every hit narrows the zone and speeds up the indicator; a miss lets the
-- fish escape. Big touch targets: the whole bar area is the button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

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

local BAR_WIDTH = 640

local function FishingGame(scope: Scope, props: Props): Instance
	local position = scope:Value(0) -- 0..1
	local zoneCenter = scope:Value(0.5)
	local zoneWidth = scope:Value(0.2)
	local hits = scope:Value(0)
	local flash = scope:Value(Theme.Colors.Success)
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
			flash:set(Theme.Colors.Success)
			if count >= current.hits then
				finish(count)
				return
			end
			zoneWidth:set(width * current.shrink)
			speed *= current.speedUp
			newZone()
		else
			flash:set(Theme.Colors.Danger)
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

	return scope:New("Frame")({
		Name = "Fishing",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -230),
		Size = UDim2.fromOffset(BAR_WIDTH + 40, 190),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.1,
		Visible = scope:Computed(function(use): boolean
			return use(props.Phase) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 1.5 }),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(0, 10),
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					if use(isBite) then
						return `❗ {Text.get(use, "fish.bite")}  {use(hits)}/{(use(props.Params) or { hits = 3 }).hits}`
					end
					return Text.get(use, "fish.waiting")
				end),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(isBite) then Theme.Colors.GoldBright else Theme.Colors.Parchment
				end),
			}),
			-- The bar (also the big tap target)
			scope:New("TextButton")({
				Name = "Bar",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 60),
				Size = UDim2.fromOffset(BAR_WIDTH, 64),
				BackgroundColor3 = Theme.Colors.Background,
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
						BackgroundColor3 = Theme.Colors.Success,
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
						BackgroundColor3 = Theme.Colors.GoldBright,
						ZIndex = 2,
						[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
					}),
				},
			}),
			scope:New("TextLabel")({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 72),
				Size = UDim2.fromOffset(BAR_WIDTH, 40),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(isBite)
				end),
				Text = "〰  ◯  〰",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 34,
				TextColor3 = Theme.Colors.Accent,
			}),
			scope:New("TextLabel")({
				Position = UDim2.new(0, 20, 1, -50),
				Size = UDim2.new(1, -200, 0, 40),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return if use(isBite) then Text.get(use, "fish.hint") else ""
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -14, 1, -10),
				Size = UDim2.fromOffset(150, 44),
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
