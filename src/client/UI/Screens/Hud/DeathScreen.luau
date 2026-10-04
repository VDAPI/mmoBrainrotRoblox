--!strict
-- Death screen (DESIGN §3.4): dimmed world, "You died", respawn countdown and "Respawn now" for Dragon
-- Shards. Visible while the state branch `death` exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
	local cost = scope:Computed(function(use): number
		local d = use(death)
		return if d then d.cost else 0
	end)

	local function respawnNow()
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("RespawnNow")
			busy:set(false)
			if not ok then
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

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
				Size = UDim2.fromOffset(560, 320),
				BackgroundTransparency = 1,
				ZIndex = 51,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, Theme.Padding.Medium),
					}),
					scope:New("TextLabel")({
						Name = "Title",
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 80),
						BackgroundTransparency = 1,
						Text = Text.T(scope, "death.title"),
						FontFace = Theme.Fonts.Heading,
						TextSize = 72,
						TextColor3 = Theme.Colors.DangerHover,
						TextStrokeTransparency = 0.4,
						ZIndex = 52,
					}),
					scope:New("TextLabel")({
						Name = "Countdown",
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return Text.get(use, "death.countdown", { time = Format.time(math.ceil(use(remaining))) })
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Large,
						TextColor3 = Theme.Colors.Parchment,
						ZIndex = 52,
					}),
					scope:New("TextLabel")({
						Name = "Note",
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundTransparency = 1,
						Text = Text.T(scope, "death.nothingLost"),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
						ZIndex = 52,
					}),
					Button(scope, {
						Name = "RespawnNow",
						LayoutOrder = 4,
						Size = UDim2.fromOffset(420, Theme.Size.ButtonHeight),
						Variant = "primary",
						Text = scope:Computed(function(use): string
							return Text.get(use, "death.respawnNow", { cost = use(cost) })
						end),
						Disabled = scope:Computed(function(use): boolean
							local owned = use(shards)
							return use(busy) or type(owned) ~= "number" or owned < use(cost)
						end),
						OnClick = respawnNow,
					}),
					Button(scope, {
						Name = "RespawnRobux",
						LayoutOrder = 5,
						Size = UDim2.fromOffset(420, Theme.Size.ButtonHeightSmall),
						Text = Text.T(scope, "death.respawnRobux", { robux = Products.respawn.robux }),
						Disabled = busy,
						OnClick = function()
							busy:set(true)
							task.spawn(function()
								local ok, err = Net.Invoke("BuyProduct", Products.respawn.key)
								busy:set(false)
								if not ok then
									Toast.push(Text.now(err or "error.internal"), "error")
								end
							end)
						end,
					}),
					scope:New("TextLabel")({
						Name = "Shards",
						LayoutOrder = 6,
						Size = UDim2.new(1, 0, 0, 22),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return Text.get(use, "death.shardsOwned", { shards = Format.number(use(shards) or 0) })
						end),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
						ZIndex = 52,
					}),
				},
			}),
		},
	})
end

return DeathScreen
