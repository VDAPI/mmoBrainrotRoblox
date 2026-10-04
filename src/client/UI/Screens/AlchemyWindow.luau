--!strict
-- Alchemist window (DESIGN §10): recipes grouped by tab (Blessings, Scrolls & stones, Materials, Elixirs),
-- locked ones show the required level, each row shows ingredients owned / needed, gold and brewing time with
-- "Order". On the right the queue: 3 (VIP 4) slots with progress bars, countdowns, "Collect" / "Collect all".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.ItemText)
local Net = require(ReplicatedStorage.Shared.Net)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	NpcId: Fusion.UsedAs<string?>,
}

local QUEUE_WIDTH = 270

local function count(inv: any, itemId: string): number
	local n = 0
	for _, item in inv or {} do
		if item.id == itemId then
			n += item.n
		end
	end
	return n
end

local function invoke(name: string, ...: any): (boolean, any)
	local ok, err, extra = Net.Invoke(name, ...)
	if not ok then
		Sounds.play("error")
		Toast.push(Text.now(err or "error.internal"), "error")
	end
	return ok, extra
end

local function recipeRow(scope: Scope, props: Props, recipe: Recipes.Recipe, order: number): Instance
	local level = State.Value({ "character", "level" })
	local inventory = State.Value({ "character", "inventory" })
	local gold = State.Value({ "character", "gold" })
	local locked = scope:Computed(function(use): boolean
		return (use(level) or 1) < recipe.level
	end)
	return scope:New("Frame")({
		Name = recipe.id,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = scope:Computed(function(use): number
			return if use(locked) then 0.75 else 0.4
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			ItemSlot(scope, {
				SlotId = `view:alchemy:{recipe.id}`,
				Item = ItemRoll.makeStack(recipe.result.id, recipe.result.n, `preview:{recipe.id}`),
				Size = 58,
				Position = UDim2.fromOffset(8, 8),
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(76, 6),
				Size = UDim2.new(1, -220, 0, 24),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local name = ItemText.get(use, recipe.result.id)
					if recipe.result.n > 1 then
						name ..= ` x{recipe.result.n}`
					end
					return name
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(locked) then Theme.Colors.TextMuted else Theme.Colors.Text
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(76, 30),
				Size = UDim2.new(1, -220, 0, 40),
				BackgroundTransparency = 1,
				RichText = true,
				TextWrapped = true,
				Text = scope:Computed(function(use): string
					if use(locked) then
						return `<font color="#CC5248">{Text.get(use, "tooltip.requiresLevel", { level = recipe.level })}</font>`
					end
					local inv = use(inventory)
					local parts = {}
					for _, ingredient in recipe.ingredients do
						local have = count(inv, ingredient.id)
						local color = if have >= ingredient.n then "#4FD16B" else "#CC5248"
						table.insert(
							parts,
							`<font color="{color}">{ItemText.get(use, ingredient.id)} {have}/{ingredient.n}</font>`
						)
					end
					local goldColor = if (use(gold) or 0) >= recipe.gold then "#E8C25A" else "#CC5248"
					table.insert(parts, `<font color="{goldColor}">◉ {Format.number(recipe.gold)}</font>`)
					table.insert(parts, `⌛ {Time.format(recipe.time)}`)
					return table.concat(parts, "  ")
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Parchment,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(120, 48),
				Variant = "primary",
				Text = Text.T(scope, "alchemy.order"),
				Disabled = locked,
				OnClick = function()
					local npcId = Fusion.peek(props.NpcId)
					if not npcId then
						return
					end
					task.spawn(function()
						if invoke("StartRecipe", npcId, recipe.id) then
							Sounds.play("click")
							Toast.push(
								Text.now("alchemy.started", { name = ItemText.name(recipe.result.id) }),
								"success"
							)
						end
					end)
				end,
			}),
		},
	})
end

local function queuePanel(scope: Scope, props: Props): Instance
	local queue = State.Value({ "character", "alchemy" })
	local now = scope:Value(Clock.now())
	local accumulator = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			accumulator += dt
			if accumulator >= 0.25 then
				accumulator = 0
				now:set(Clock.now())
			end
		end)
	)

	local function collect()
		local npcId = Fusion.peek(props.NpcId)
		if not npcId then
			return
		end
		task.spawn(function()
			local ok, n = invoke("CollectAlchemy", npcId)
			if ok then
				Sounds.play("levelUp")
				Toast.push(Text.now("alchemy.collected", { n = n or 1 }), "success")
			end
		end)
	end

	local slots = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		local orders = use(queue) or {}
		for index = 1, Recipes.QUEUE_SLOTS_VIP do
			local order = orders[index]
			local recipe = order and Recipes.get(order.recipeId)
			if recipe and order then
				local readyAt = order.readyAt
				local progress = s:Computed(function(use2): number
					return Time.progress(order, recipe.time, use2(now))
				end)
				local ready = s:Computed(function(use2): boolean
					return readyAt <= use2(now)
				end)
				table.insert(
					list,
					s:New("Frame")({
						LayoutOrder = index,
						Size = UDim2.new(1, 0, 0, 84),
						BackgroundColor3 = Theme.Colors.PanelRaised,
						BackgroundTransparency = 0.3,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							ItemSlot(s, {
								SlotId = `view:queue:{index}`,
								Item = ItemRoll.makeStack(recipe.result.id, recipe.result.n, `queue:{index}`),
								Size = 52,
								Position = UDim2.fromOffset(6, 6),
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(66, 6),
								Size = UDim2.new(1, -72, 0, 22),
								BackgroundTransparency = 1,
								Text = ItemText.get(use, recipe.result.id),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Small,
								TextColor3 = Theme.Colors.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(66, 30),
								Size = UDim2.new(1, -72, 0, 20),
								BackgroundTransparency = 1,
								Text = s:Computed(function(use2): string
									if use2(ready) then
										return Text.get(use2, "alchemy.ready.short")
									end
									return Time.format(Time.remaining(readyAt, use2(now)))
								end),
								FontFace = Theme.Fonts.BodyMedium,
								TextSize = Theme.TextSize.Small,
								TextColor3 = s:Computed(function(use2): Color3
									return if use2(ready) then Theme.Colors.Success else Theme.Colors.Parchment
								end),
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							s:New("Frame")({
								Position = UDim2.new(0, 6, 1, -20),
								Size = UDim2.new(1, -12, 0, 12),
								BackgroundColor3 = Theme.Colors.Background,
								[Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
									s:New("Frame")({
										Size = s:Computed(function(use2): UDim2
											return UDim2.fromScale(use2(progress), 1)
										end),
										BackgroundColor3 = s:Computed(function(use2): Color3
											return if use2(ready) then Theme.Colors.Success else Theme.Colors.Accent
										end),
										[Children] = s:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
									}),
								},
							}),
						},
					})
				)
			elseif index <= Recipes.QUEUE_SLOTS or orders[index] ~= nil then
				table.insert(
					list,
					s:New("TextLabel")({
						LayoutOrder = index,
						Size = UDim2.new(1, 0, 0, 84),
						BackgroundColor3 = Theme.Colors.Background,
						BackgroundTransparency = 0.5,
						Text = Text.get(use, "alchemy.emptySlot"),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
						[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					})
				)
			end
		end
		return list
	end)

	local anyReady = scope:Computed(function(use): boolean
		return #Time.readyItems(use(queue) or {}, use(now)) > 0
	end)

	return scope:New("Frame")({
		Name = "Queue",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, QUEUE_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "alchemy.queue"),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.Gold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("Frame")({
				Position = UDim2.fromOffset(0, 40),
				Size = UDim2.new(1, 0, 1, -100),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
					slots :: any,
				},
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 52),
				Variant = "primary",
				Text = Text.T(scope, "alchemy.collectAll"),
				Disabled = scope:Computed(function(use): boolean
					return not use(anyReady)
				end),
				OnClick = collect,
			}),
		},
	})
end

local function AlchemyWindow(scope: Scope, props: Props): Fusion.Child
	local group = scope:Value("blessing")
	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		local selected = use(group)
		local recipes = {}
		for _, recipe in Recipes.list do
			if recipe.group == selected then
				table.insert(recipes, recipe)
			end
		end
		table.sort(recipes, function(a, b)
			if a.level ~= b.level then
				return a.level < b.level
			end
			return a.id < b.id
		end)
		for i, recipe in recipes do
			table.insert(list, recipeRow(s, props, recipe, i))
		end
		return list
	end)

	return {
		scope:New("Frame")({
			Name = "Recipes",
			Size = UDim2.new(1, -QUEUE_WIDTH - 16, 1, 0),
			BackgroundTransparency = 1,
			[Children] = {
				Tabs(scope, {
					Selected = group,
					Tabs = {
						{ id = "blessing", label = Text.T(scope, "alchemy.group.blessing") },
						{ id = "travel", label = Text.T(scope, "alchemy.group.travel") },
						{ id = "material", label = Text.T(scope, "alchemy.group.material") },
						{ id = "elixir", label = Text.T(scope, "alchemy.group.elixir") },
					},
				}),
				scope:New("ScrollingFrame")({
					Position = UDim2.fromOffset(0, 52),
					Size = UDim2.new(1, 0, 1, -52),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 6,
					ScrollBarImageColor3 = Theme.Colors.GoldDim,
					[Children] = {
						scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
						scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
						rows :: any,
					},
				}),
			},
		}),
		queuePanel(scope, props),
	}
end

return AlchemyWindow
