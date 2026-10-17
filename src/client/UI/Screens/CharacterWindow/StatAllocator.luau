--!strict
-- Primary stats with +/- buttons (DESIGN §4.3). Points are reserved locally (pending) and sent together
-- with "Confirm"; holding + or - repeats faster. The pending values feed a live preview of derived stats.
-- FIX 2026-10-09: every stat says what one point gives (numbers from Data/Stats.Formula).
-- S54: DEX crit, speed and dodge per point at the current character level (StatCalc.dexFactor).
-- S58 (ROZWOJ 2.11): "Spend as the path suggests" adds the free points to the reservation by the plan of the leading
-- direction (S138, Logic/Paths.mainOf; or the class, Logic/Paths.statPlan; split by Logic/StatPlan.suggest); the
-- player confirms as usual. A line below the buttons names the plan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local StatCalc = require(ReplicatedStorage.Shared.Logic.StatCalc)
local StatPlan = require(ReplicatedStorage.Shared.Logic.StatPlan)
local Stats = require(ReplicatedStorage.Shared.Data.Stats)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>
type PlanInfo = { plan: StatPlan.Plan, pathKey: string? }

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
-- DEX crit, speed and dodge depend on the character level and are built in the component.
local DESC_ARGS: { [string]: Text.ArgsIn } = {
	str = { phys = pct(F.physPerStat * 100), armor = pct(F.armorPerStr) },
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
		BackgroundColor3 = Theme.Paper.Raised,
		BackgroundTransparency = scope:Computed(function(use): number
			return if use(enabled) then 0 else 0.6
		end),
		Text = glyph,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Large,
		TextColor3 = scope:Computed(function(use): Color3
			return if use(enabled) then Theme.Paper.Heading else Theme.Paper.TextMuted
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
				Color = Theme.Paper.Rule,
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
	local level = State.Value({ "character", "level" })
	local classId = State.Value({ "character", "class" })
	local pathState = State.Value({ "character", "path" })

	-- The plan of the leading direction (S138), else of the class; nil without a class or with an empty plan.
	local planInfo = scope:Computed(function(use): PlanInfo?
		local c = use(classId)
		if type(c) ~= "string" or Classes.get(c) == nil then
			return nil
		end
		local plan, def = Paths.statPlan({ class = c, level = 1, path = use(pathState) } :: any)
		if next(plan) == nil then
			return nil
		end
		return { plan = plan, pathKey = if def then def.nameKey else nil }
	end)

	-- What one DEX point gives at the current level: ranged damage in full, crit, speed and dodge rated (S54).
	local function ratedDex(perPoint: number): Fusion.Computed<string>
		return scope:Computed(function(use): string
			local L = use(level)
			return pct(perPoint * StatCalc.dexFactor(if type(L) == "number" then L else 1))
		end)
	end
	local descArgs: { [string]: Text.ArgsIn } = table.clone(DESC_ARGS)
	descArgs.dex = {
		phys = pct(F.physPerStat * 100),
		crit = ratedDex(F.critPerDex),
		speed = ratedDex(F.atkSpeedPerDex * 100),
		dodge = ratedDex(F.dodgePerDex),
	}

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

	-- Adds the rest of the free points by the plan; the player's own reservations stay.
	local function suggest()
		local info = Fusion.peek(planInfo)
		local free = Fusion.peek(available)
		local class = Classes.get(Fusion.peek(classId) or "")
		if Fusion.peek(busy) or free <= 0 or info == nil or class == nil then
			return
		end
		local reserved = Fusion.peek(pending)
		local current: { [string]: number } = {}
		local base = State.Get({ "character", "stats" })
		for _, id in Stats.primary do
			current[id] = (if type(base) == "table" then base[id] or 0 else 0) + (reserved[id] or 0)
		end
		local adds = StatPlan.suggest(info.plan, class.startStats :: any, current, free)
		local nextPending = table.clone(reserved)
		for id, n in adds do
			nextPending[id] = (nextPending[id] or 0) + n
		end
		pending:set(nextPending)
		Sounds.play("click")
	end

	local function confirm()
		local request = Fusion.peek(pending)
		if total(request) <= 0 or Fusion.peek(busy) then
			return
		end
		busy:set(true)
		task.spawn(function()
			-- the set the points were reserved in: the server rejects them after a switch still in flight (S58 F3)
			local slot = if State.Get({ "character", "buildSlot" }) == 2 then 2 else 1
			local ok, err = Net.Invoke("AllocateStats", request, slot)
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
								TextColor3 = Theme.Paper.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							scope:New("TextLabel")({
								Name = "Desc",
								Position = UDim2.fromOffset(0, 24),
								Size = UDim2.new(1, 0, 1, -24),
								BackgroundTransparency = 1,
								Text = Text.T(scope, `stat.{id}.desc`, descArgs[id]),
								TextWrapped = true,
								FontFace = Theme.Fonts.Body,
								TextSize = Theme.TextSize.Small,
								TextColor3 = Theme.Paper.TextMuted,
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
								return `{shown + plus} <font color="{Theme.hex(Theme.Paper.Success)}">(+{plus})</font>`
							end
							return tostring(shown)
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Large,
						TextColor3 = Theme.Paper.Heading,
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
					return if use(available) > 0 then Theme.Paper.Success else Theme.Paper.TextMuted
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
						Size = UDim2.new(0.24, -Theme.Padding.Small * 2 / 3, 1, 0),
						Disabled = scope:Computed(function(use): boolean
							return total(use(pending)) == 0 or use(busy)
						end),
						OnClick = function()
							pending:set({})
						end,
					}),
					Button(scope, {
						LayoutOrder = 2,
						Text = Text.T(scope, "character.suggest"),
						Variant = "secondary",
						TextSize = Theme.TextSize.Small,
						Size = UDim2.new(0.42, -Theme.Padding.Small * 2 / 3, 1, 0),
						Disabled = scope:Computed(function(use): boolean
							return use(planInfo) == nil or use(available) <= 0 or use(busy)
						end),
						OnClick = suggest,
					}),
					Button(scope, {
						LayoutOrder = 3,
						Text = Text.T(scope, "common.confirm"),
						Variant = "primary",
						Size = UDim2.new(0.34, -Theme.Padding.Small * 2 / 3, 1, 0),
						Disabled = scope:Computed(function(use): boolean
							return total(use(pending)) == 0 or use(busy)
						end),
						OnClick = confirm,
					}),
				},
			}),
			scope:New("TextLabel")({
				Name = "Plan",
				LayoutOrder = 12,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local info = use(planInfo)
					if info == nil then
						return ""
					end
					local parts: { string } = {}
					for _, id in Stats.primary do
						local w = info.plan[id]
						if w then
							table.insert(parts, `{Text.get(use, "stat." .. id)} {w}`)
						end
					end
					local plan = table.concat(parts, " · ")
					if info.pathKey then
						return Text.get(use, "character.plan.path", { path = Text.get(use, info.pathKey), plan = plan })
					end
					return Text.get(use, "character.plan.class", { plan = plan })
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		},
	})
end

return StatAllocator
