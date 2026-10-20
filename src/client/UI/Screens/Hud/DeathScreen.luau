--!strict
-- Death screen (DESIGN §3.4): dimmed world, "You died", respawn countdown and "Respawn now" for Dragon
-- Shards (W28: only shards, cheap; "Top up" opens the shop when the balance is short). Visible while the state branch `death` exists. S22: once the countdown ends (or after a
-- paid skip) two choices replace it: "Respawn in the city" [1] and "Respawn here" [2] (in a dungeon: at its
-- entrance); without a choice the server picks the city at `deadline`. Keys 1 and 2 are local to this screen.
-- FIX 2026-10-15: "Respawn here" shows its gold price (`death.hereCost`) and is disabled without enough gold.
-- S121: "VIP respawn (free)" above the paid buttons while counting, only with VIP and a free respawn left today.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local CurrencyIcon = require(script.Parent.Parent.Parent.Components.CurrencyIcon)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local Vip = require(ReplicatedStorage.Shared.Logic.Vip)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function label(scope: Scope, props: { [string]: any }): Instance
	local base = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Iron.Text,
		ZIndex = 52,
	}
	for key, value in props do
		base[key] = value
	end
	return scope:New("TextLabel")(base :: any)
end

-- W28: the Dragon Currency icon at the left end of the paid respawn button (the text stays centred).
local function withCurrency(scope: Scope, button: Instance): Instance
	local icon = CurrencyIcon(scope, {
		Currency = "dragon",
		Surface = "iron",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		ZIndex = 2,
	})
	icon.Parent = button
	return button
end

export type Props = {
	OpenShop: (() -> ())?, -- W28: the Dragon Shop on the currency tab ("Top up" without enough shards)
}

local function DeathScreen(scope: Scope, props: Props?): Instance
	local openShop = props and props.OpenShop
	local death = State.Value({ "death" })
	local shards = State.Value({ "account", "dragonShards" })
	local gold = State.Value({ "character", "gold" })
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
	local hereCost = scope:Computed(function(use): number
		local d = use(death)
		return if d and type(d.hereCost) == "number" then d.hereCost else 0
	end)
	local counting = scope:Computed(function(use): boolean
		return not use(choosing)
	end)
	-- S129: a death on a Blood Moon map during the event: no paid or VIP skip (a hint instead of the buttons)
	local moonBlocked = scope:Computed(function(use): boolean
		local d = use(death)
		return d ~= nil and d.bloodMoon == true
	end)
	local canSkip = scope:Computed(function(use): boolean
		return use(counting) and not use(moonBlocked)
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

	-- W28 (owner): the skip costs Dragon Shards only (cheap, Config.RespawnNowCost); without enough a "Top up" button
	-- opens the shop on the currency tab (the Robux respawn product is gone).
	local short = scope:Computed(function(use): boolean
		local owned = use(shards)
		return type(owned) ~= "number" or owned < use(cost)
	end)
	local topUpButton = Button(scope, {
		Surface = "iron", -- S135: on a dark HUD / overlay surface
		Name = "RespawnTopUp",
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeightSmall),
		Visible = scope:Computed(function(use): boolean
			return use(canSkip) and use(short) and openShop ~= nil
		end),
		Text = Text.T(scope, "death.topUp"),
		OnClick = function()
			if openShop then
				openShop()
			end
		end,
	})

	-- S121: the free VIP respawn (VipService; once per UTC day).
	local vipActive = State.Value({ "vip", "active" })
	local vipState = State.Value({ "account", "vip" })
	local vipButton = Button(scope, {
		Surface = "iron", -- S135: on a dark HUD / overlay surface
		Name = "VipRespawn",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
		Variant = "primary",
		Text = Text.T(scope, "death.vipRespawn"),
		Visible = scope:Computed(function(use): boolean
			use(now) -- re-read every tick: the day may change while dead
			return use(canSkip) and use(vipActive) == true and Vip.respawnLeft(use(vipState), Clock.now()) > 0
		end),
		Disabled = busy,
		OnClick = function()
			invoke("VipRespawn")
		end,
	})

	local width = 460

	return scope:New("Frame")({
		Name = "DeathScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Shade,
		BackgroundTransparency = 0.45,
		Visible = scope:Computed(function(use): boolean
			return use(death) ~= nil
		end),
		ZIndex = 50,
		[Children] = {
			scope:New("UIGradient")({
				Color = ColorSequence.new(Theme.Announce.DeathGlow, Theme.Shade),
				Rotation = 90,
			}),
			scope:New("Frame")({
				Name = "Content",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.new(0.92, 0, 0, 440), -- phones: 92% of the width, at most `width`
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
						LayoutOrder = 0,
						Size = UDim2.new(1, 0, 0, 80),
						Text = Text.T(scope, "death.title"),
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Hero,
						TextColor3 = Theme.Iron.Danger,
						TextStrokeTransparency = 0.4,
					}),
					label(scope, {
						Name = "Countdown",
						LayoutOrder = 1,
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
						LayoutOrder = 2,
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
						TextColor3 = Theme.Iron.TextMuted,
					}),
					vipButton,
					label(scope, {
						Name = "BloodMoonHint",
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 40),
						Visible = scope:Computed(function(use): boolean
							return use(counting) and use(moonBlocked)
						end),
						TextWrapped = true,
						Text = Text.T(scope, "death.bloodMoonHint"),
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Iron.Danger,
					}),
					-- Countdown: pay to skip it (W28: Dragon Shards only, the shard icon at the left end).
					withCurrency(
						scope,
						Button(scope, {
							Surface = "iron", -- S135: on a dark HUD / overlay surface
							Name = "RespawnNow",
							LayoutOrder = 4,
							Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
							Variant = "primary",
							Visible = canSkip,
							Text = scope:Computed(function(use): string
								return Text.get(use, "death.respawnNow", { cost = Format.number(use(cost)) })
							end),
							Disabled = busy,
							OnClick = function()
								if Fusion.peek(short) then
									-- a clear refusal at once (the server says the same), "Top up" is right below
									Sounds.play("error")
									Toast.push(Text.now("death.error.noShards"), "error")
									return
								end
								invoke("RespawnNow")
							end,
						})
					),
					topUpButton,
					-- Choice.
					Button(scope, {
						Surface = "iron", -- S135: on a dark HUD / overlay surface
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
						Surface = "iron", -- S135: on a dark HUD / overlay surface
						Name = "RespawnHere",
						LayoutOrder = 7,
						Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
						Visible = choosing,
						Disabled = scope:Computed(function(use): boolean
							local owned = use(gold)
							return use(busy)
								or (use(hereCost) > 0 and (type(owned) ~= "number" or owned < use(hereCost)))
						end),
						Text = scope:Computed(function(use): string
							local d = use(death)
							if d and d.dungeon then
								return Text.get(use, "death.respawnEntrance")
							end
							local price = use(hereCost)
							if price > 0 then
								return Text.get(use, "death.respawnHereCost", { gold = Format.number(price) })
							end
							return Text.get(use, "death.respawnHere")
						end),
						OnClick = function()
							choose("here")
						end,
					}),
					label(scope, {
						Name = "Shards",
						LayoutOrder = 8,
						Size = UDim2.new(1, 0, 0, 22),
						Text = scope:Computed(function(use): string
							if use(choosing) then
								return Text.get(use, "death.goldOwned", { gold = Format.number(use(gold) or 0) })
							end
							return Text.get(use, "death.shardsOwned", { shards = Format.number(use(shards) or 0) })
						end),
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Iron.TextMuted,
					}),
					label(scope, {
						Name = "Protection",
						LayoutOrder = 9,
						Size = UDim2.new(1, 0, 0, 40),
						Visible = choosing,
						TextWrapped = true,
						Text = Text.T(scope, "death.protectionNote"),
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Iron.TextMuted,
					}),
				},
			}),
		},
	})
end

return DeathScreen
