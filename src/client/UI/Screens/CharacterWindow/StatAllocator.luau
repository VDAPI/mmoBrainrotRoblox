--!strict
-- Primary stats with +/- buttons (DESIGN §4.3). Points are reserved locally (pending) and sent together
-- with "Confirm"; holding + or - repeats faster. The pending values feed a live preview of derived stats.
-- FIX 2026-10-09: every stat says what one point gives (numbers from Data/Stats.Formula).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Stats = require(ReplicatedStorage.Shared.Data.Stats)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	-- { str, dex, int, vit } points reserved but not yet confirmed.
	Pending: Fusion.Value<{ [string]: number }>,
}

local HOLD_DELAY = 0.35
local ROW_HEIGHT = 50

-- What one point of a stat gives, as arguments of "stat.<id>.desc" (Data/Stats.Formula).
local function pct(value: number): string
	return string.format("%g", math.floor(value * 1000 + 0.5) / 1000)
end
local F = Stats.Formula
local DESC_ARGS: { [string]: { [string]: string } } = {
	str = { phys = pct(F.physPerStat * 100), armor = pct(F.armorPerStr) },
	dex = {
		phys = pct(F.physPerStat * 100),
		crit = pct(F.critPerDex),
		speed = pct(F.atkSpeedPerDex * 100),
		dodge = pct(F.dodgePerDex),
	},
	int = { mag = pct(F.magPerInt * 100), mana = pct(F.manaPerInt), mres = pct(F.mresPerInt) },
	vit = { hp = pct(F.hpPerVit), armor = pct(F.armorPerVit), mres = pct(F.mresPerVit) },
}

local function total(pending: { [string]: number }): number
	local sum = 0
	for _, v in pending do
		sum += v
	end
	return sum
end

-- A +/- button that repeats while held (accelerating).
local function stepButton(
	scope: Scope,
	glyph: string,
	layoutOrder: number,
	step: () -> boolean,
	enabled: Fusion.UsedAs<boolean>
): Instance
	local holding = 0
	local function startHold()
		holding += 1
		local token = holding
		if not step() then
			return
		end
		task.delay(HOLD_DELAY, function()
			local interval = 0.12
			while holding == token do
				if not step() then
					break
				end
				task.wait(interval)
				interval = math.max(0.03, interval * 0.85)
			end
		end)
	end
	local function stopHold()
		holding += 1
	end
	table.insert(scope, stopHold)

	return scope:New("TextButton")({
		Name = glyph,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(ROW_HEIGHT, ROW_HEIGHT),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = scope:Computed(function(use): number
			return if use(enabled) then 0 else 0.6
		end),
		Text = glyph,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = 26,
		TextColor3 = scope:Computed(function(use): Color3
			return if use(enabled) then Theme.Colors.Gold else Theme.Colors.TextMuted
		end),
		[OnEvent("InputBegan")] = function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				startHold()
			end
		end,
		[OnEvent("InputEnded")] = function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				stopHold()
			end
		end,
		[OnEvent("MouseLeave")] = stopHold,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Colors.GoldDim,
			}),
		},
	})
end

local function StatAllocator(scope: Scope, props: Props): Instance
	local pending = props.Pending
	local statPoints = State.Value({ "character", "statPoints" })
	local stats = State.Value({ "character", "stats" })
	local primary = State.Value({ "derived", "primary" })
	local busy = scope:Value(false)

	local available = scope:Computed(function(use): number
		local points = use(statPoints)
		return (if type(points) == "number" then points else 0) - total(use(pending))
	end)

	local function change(id: string, delta: number): boolean
		local current = table.clone(Fusion.peek(pending))
		local value = (current[id] or 0) + delta
		if value < 0 or (delta > 0 and Fusion.peek(available) <= 0) then
			return false
		end
		current[id] = if value == 0 then nil :: any else value
		pending:set(current)
		Sounds.play("click")
		return true
	end

	local function confirm()
		local request = Fusion.peek(pending)
		if total(request) <= 0 or Fusion.peek(busy) then
			return
		end
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("AllocateStats", request)
			busy:set(false)
			if ok then
				pending:set({})
				Toast.push(Text.now("character.statsSaved"), "success")
			else
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	local rows = {}
	for index, id in Stats.primary do
		local added = scope:Computed(function(use): number
			return use(pending)[id] or 0
		end)
		table.insert(
			rows,
			scope:New("Frame")({
				Name = id,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Padding.Small),
					}),
					scope:New("Frame")({
						Name = "Label",
						LayoutOrder = 1,
						Size = UDim2.new(1, -(44 * 2 + 90 + Theme.Padding.Small * 3), 1, 0),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("TextLabel")({
								Name = "Name",
								Size = UDim2.new(1, 0, 0, 24),
								BackgroundTransparency = 1,
								Text = Text.T(scope, `stat.{id}`),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = Theme.Colors.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							scope:New("TextLabel")({
								Name = "Desc",
								Position = UDim2.fromOffset(0, 24),
								Size = UDim2.new(1, 0, 1, -24),
								BackgroundTransparency = 1,
								Text = Text.T(scope, `stat.{id}.desc`, DESC_ARGS[id]),
								TextWrapped = true,
								FontFace = Theme.Fonts.Body,
								TextSize = 12,
								TextColor3 = Theme.Colors.TextMuted,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Top,
							}),
						},
					}),
					stepButton(
						scope,
						"−",
						2,
						function()
							return change(id, -1)
						end,
						scope:Computed(function(use): boolean
							return use(added) > 0
						end)
					),
					scope:New("TextLabel")({
						Name = "Value",
						LayoutOrder = 3,
						Size = UDim2.fromOffset(90, ROW_HEIGHT),
						BackgroundTransparency = 1,
						RichText = true,
						Text = scope:Computed(function(use): string
							local final = use(primary)
							local base = use(stats)
							local shown = if type(final) == "table"
								then final[id]
								elseif type(base) == "table" then base[id]
								else 0
							local plus = use(added)
							if plus > 0 then
								return `{shown + plus} <font color="#4FD16B">(+{plus})</font>`
							end
							return tostring(shown)
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Large,
						TextColor3 = Theme.Colors.Gold,
					}),
					stepButton(
						scope,
						"+",
						4,
						function()
							return change(id, 1)
						end,
						scope:Computed(function(use): boolean
							return use(available) > 0
						end)
					),
				},
			})
		)
	end

	return scope:New("Frame")({
		Name = "StatAllocator",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Tiny),
			}),
			rows :: any,
			scope:New("TextLabel")({
				Name = "Points",
				LayoutOrder = 10,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return Text.get(use, "character.pointsLeft", { points = use(available) })
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(available) > 0 then Theme.Colors.Success else Theme.Colors.TextMuted
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("Frame")({
				Name = "Buttons",
				LayoutOrder = 11,
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeightSmall),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Padding.Small),
					}),
					Button(scope, {
						LayoutOrder = 1,
						Text = Text.T(scope, "common.cancel"),
						Variant = "ghost",
						Size = UDim2.new(0.5, -Theme.Padding.Small / 2, 1, 0),
						Disabled = scope:Computed(function(use): boolean
							return total(use(pending)) == 0 or use(busy)
						end),
						OnClick = function()
							pending:set({})
						end,
					}),
					Button(scope, {
						LayoutOrder = 2,
						Text = Text.T(scope, "common.confirm"),
						Variant = "primary",
						Size = UDim2.new(0.5, -Theme.Padding.Small / 2, 1, 0),
						Disabled = scope:Computed(function(use): boolean
							return total(use(pending)) == 0 or use(busy)
						end),
						OnClick = confirm,
					}),
				},
			}),
		},
	})
end

return StatAllocator
