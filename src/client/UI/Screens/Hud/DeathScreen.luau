--!strict
-- Death screen (DESIGN §3.4): dimmed world, "You died", respawn countdown and "Respawn now" for Dragon
-- Shards or Robux. Visible while the state branch `death` exists. S22: once the countdown ends (or after a
-- paid skip) two choices replace it: "Respawn in the city" [1] and "Respawn here" [2] (in a dungeon: at its
-- entrance); without a choice the server picks the city at `deadline`. Keys 1 and 2 are local to this screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function label(scope: Scope, props: { [string]: any }): Instance
	local base = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Colors.Parchment,
		ZIndex = 52,
	}
	for key, value in props do
		base[key] = value
	end
	return scope:New("TextLabel")(base :: any)
end

local function DeathScreen(scope: Scope): Instance
	local death = State.Value({ "death" })
	local shards = State.Value({ "account", "dragonShards" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local busy = scope:Value(false)

	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			if Fusion.peek(death) ~= nil then
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)

	local remaining = scope:Computed(function(use): number
		local d = use(death)
		return if d then math.max(0, d.respawnAt - use(now)) else 0
	end)
	local choosing = scope:Computed(function(use): boolean
		local d = use(death)
		return d ~= nil and use(now) >= d.respawnAt
	end)
	local untilCity = scope:Computed(function(use): number
		local d = use(death)
		return if d and d.deadline then math.max(0, d.deadline - use(now)) else 0
	end)
	local cost = scope:Computed(function(use): number
		local d = use(death)
		return if d then d.cost else 0
	end)
	local counting = scope:Computed(function(use): boolean
		return not use(choosing)
	end)

	local function invoke(name: string, ...: any)
		if Fusion.peek(busy) then
			return
		end
		busy:set(true)
		local args = { ... }
		task.spawn(function()
			local ok, err = Net.Invoke(name, table.unpack(args))
			busy:set(false)
			if not ok then
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	local function choose(choice: string)
		if Fusion.peek(death) ~= nil and Fusion.peek(choosing) then
			invoke("RespawnChoice", choice)
		end
	end

	-- Keys 1 / 2 while the choice is open (local to this screen, not Keybinds actions).
	table.insert(
		scope,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or Fusion.peek(death) == nil or not Fusion.peek(choosing) then
				return
			end
			if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.KeypadOne then
				choose("city")
			elseif input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.KeypadTwo then
				choose("here")
			end
		end)
	)

	local width = 460

	return scope:New("Frame")({
		Name = "DeathScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = scope:Computed(function(use): boolean
			return use(death) ~= nil
		end),
		ZIndex = 50,
		[Children] = {
			scope:New("UIGradient")({
				Color = ColorSequence.new(Color3.fromHex("#3A0D0B"), Color3.new(0, 0, 0)),
				Rotation = 90,
			}),
			scope:New("Frame")({
				Name = "Content",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.new(0.92, 0, 0, 380), -- phones: 92% of the width, at most `width`
				BackgroundTransparency = 1,
				ZIndex = 51,
				[Children] = {
					scope:New("UISizeConstraint")({ MaxSize = Vector2.new(width, math.huge) }),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, Theme.Padding.Medium),
					}),
					label(scope, {
						Name = "Title",
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 80),
						Text = Text.T(scope, "death.title"),
						FontFace = Theme.Fonts.Heading,
						TextSize = 72,
						TextColor3 = Theme.Colors.DangerHover,
						TextStrokeTransparency = 0.4,
					}),
					label(scope, {
						Name = "Countdown",
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 32),
						Text = scope:Computed(function(use): string
							if use(choosing) then
								return Text.get(use, "death.choose")
							end
							return Text.get(use, "death.countdown", { time = Format.time(math.ceil(use(remaining))) })
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Large,
					}),
					label(scope, {
						Name = "Note",
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 24),
						Text = scope:Computed(function(use): string
							if use(choosing) then
								return Text.get(
									use,
									"death.autoCity",
									{ time = Format.time(math.ceil(use(untilCity))) }
								)
							end
							return Text.get(use, "death.nothingLost")
						end),
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
					}),
					-- Countdown: pay to skip it.
					Button(scope, {
						Name = "RespawnNow",
						LayoutOrder = 4,
						Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
						Variant = "primary",
						Visible = counting,
						Text = scope:Computed(function(use): string
							return Text.get(use, "death.respawnNow", { cost = use(cost) })
						end),
						Disabled = scope:Computed(function(use): boolean
							local owned = use(shards)
							return use(busy) or type(owned) ~= "number" or owned < use(cost)
						end),
						OnClick = function()
							invoke("RespawnNow")
						end,
					}),
					Button(scope, {
						Name = "RespawnRobux",
						LayoutOrder = 5,
						Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeightSmall),
						Visible = counting,
						Text = Text.T(scope, "death.respawnRobux", { robux = Products.respawn.robux }),
						Disabled = busy,
						OnClick = function()
							invoke("BuyProduct", Products.respawn.key)
						end,
					}),
					-- Choice.
					Button(scope, {
						Name = "RespawnCity",
						LayoutOrder = 6,
						Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
						Variant = "primary",
						Visible = choosing,
						Disabled = busy,
						Text = Text.T(scope, "death.respawnCity"),
						OnClick = function()
							choose("city")
						end,
					}),
					Button(scope, {
						Name = "RespawnHere",
						LayoutOrder = 7,
						Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
						Visible = choosing,
						Disabled = busy,
						Text = scope:Computed(function(use): string
							local d = use(death)
							return Text.get(
								use,
								if d and d.dungeon then "death.respawnEntrance" else "death.respawnHere"
							)
						end),
						OnClick = function()
							choose("here")
						end,
					}),
					label(scope, {
						Name = "Shards",
						LayoutOrder = 8,
						Size = UDim2.new(1, 0, 0, 22),
						Visible = counting,
						Text = scope:Computed(function(use): string
							return Text.get(use, "death.shardsOwned", { shards = Format.number(use(shards) or 0) })
						end),
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
					}),
					label(scope, {
						Name = "Protection",
						LayoutOrder = 9,
						Size = UDim2.new(1, 0, 0, 40),
						Visible = choosing,
						TextWrapped = true,
						Text = Text.T(scope, "death.protectionNote"),
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
					}),
				},
			}),
		},
	})
end

return DeathScreen
