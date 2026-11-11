--!strict
-- Alchemist window (DESIGN §10): recipes grouped by tab (Blessings, Scrolls & stones, Materials, Elixirs),
-- locked ones show the required level, each row shows ingredients owned / needed, gold and brewing time with
-- "Order". On the right the queue: 3 (VIP 4) slots with progress bars, countdowns, "Collect" / "Collect all".
-- Owner 2026-11-10 (UI plan L10): the queue scrolls between its title and "Odbierz wszystko" pinned to the bottom, so
-- on a phone the button no longer covers the third slot; the parts stand where Logic/GearLayout.alchemy puts them,
-- from the window content's measured size (UI/ViewSize: without the window's opening motion, review 2026-11-10).
-- Adoption stage (UI package D after C, 2026-11-10): "Odbierz wszystko" stands in the window's Footer (pinned under
-- the content, outside its scroll) under the queue, and the orders are list rows (Components/ListRow `Tall`: the name
-- over the time left, a progress line along the bottom) instead of 84-px cards, so a phone shows two of them.
-- Review 2026-11-11: the orders' names are Small 17 again (ListRow `Dense`; at Body 20 every blessing read
-- "Błogosławieństw…") in a queue 300 px wide where the recipes keep their room (Logic/GearLayout.alchemy).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GearLayout = require(ReplicatedStorage.Shared.Logic.GearLayout)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.ItemText)
local ListRow = require(script.Parent.Parent.Components.ListRow)
local Net = require(ReplicatedStorage.Shared.Net)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)
local ViewSize = require(script.Parent.Parent.ViewSize)
local Window = require(script.Parent.Parent.Components.Window)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	NpcId: Fusion.UsedAs<string?>,
}

-- the body's size on PC (1000 x 680, above the footer) until it is measured
local AREA_PC = { w = 956, h = 524 }
-- an order's icon in its list row (ListRow `Tall`, 64 high), with room on its left for the row's bar
local ICON = 44

type Layout = Fusion.Computed<GearLayout.Alchemy>

-- Final UI review 2026-11-11: an order's name in the queue. A resistance elixir has a short one ("Eliksir na ogień",
-- whole in a phone's 270-px queue, where the four full names all read "Eliksir Odporności …"); its icon's tooltip keeps
-- the full name.
local function orderName(use: Fusion.Use, recipe: Recipes.Recipe): string
	return if recipe.group == "elixir"
		then Text.get(use, `alchemy.queue.{recipe.id}`)
		else ItemText.get(use, recipe.result.id)
end

-- The position and the size of one of the layout's rects, following it.
local function placed(
	scope: Scope,
	layout: Layout,
	pick: (GearLayout.Alchemy) -> GearLayout.Rect
): (Fusion.Computed<UDim2>, Fusion.Computed<UDim2>)
	return scope:Computed(function(use): UDim2
		local r = pick(use(layout))
		return UDim2.fromOffset(r.left, r.top)
	end),
		scope:Computed(function(use): UDim2
			local r = pick(use(layout))
			return UDim2.fromOffset(r.right - r.left, r.bottom - r.top)
		end)
end

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
		BackgroundColor3 = Theme.Paper.Raised,
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
					return if use(locked) then Theme.Paper.TextMuted else Theme.Paper.Text
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
						return `<font color="{Theme.hex(Theme.Paper.Danger)}">{Text.get(
							use,
							"tooltip.requiresLevel",
							{ level = recipe.level }
						)}</font>`
					end
					local inv = use(inventory)
					local parts = {}
					for _, ingredient in recipe.ingredients do
						local have = count(inv, ingredient.id)
						local color = if have >= ingredient.n
							then Theme.hex(Theme.Paper.Success)
							else Theme.hex(Theme.Paper.Danger)
						table.insert(
							parts,
							`<font color="{color}">{ItemText.get(use, ingredient.id)} {have}/{ingredient.n}</font>`
						)
					end
					local goldColor = if (use(gold) or 0) >= recipe.gold
						then Theme.hex(Theme.Paper.Heading)
						else Theme.hex(Theme.Paper.Danger)
					table.insert(parts, `<font color="{goldColor}">◉ {Format.number(recipe.gold)}</font>`)
					table.insert(parts, `⌛ {Time.format(recipe.time)}`)
					return table.concat(parts, "  ")
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Text,
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

-- The queue's title and rows, and "Odbierz wszystko" for the window's footer.
local function queuePanel(scope: Scope, props: Props, layout: Layout): ({ Instance }, Instance)
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
				local sub = s:Computed(function(use2): string
					if use2(ready) then
						return `<font color="{Theme.hex(Theme.Paper.Success)}">{Text.get(use2, "alchemy.ready.short")}</font>`
					end
					return Time.format(Time.remaining(readyAt, use2(now)))
				end)
				table.insert(
					list,
					ListRow(s, {
						Name = `Order{index}`,
						LayoutOrder = index,
						Index = index,
						Tall = true,
						Dense = true,
						Inset = ICON + 4,
						RichText = true,
						Text = orderName(use, recipe),
						Sub = sub,
						[Children] = {
							ItemSlot(s, {
								SlotId = `view:queue:{index}`,
								Item = ItemRoll.makeStack(recipe.result.id, recipe.result.n, `queue:{index}`),
								Size = ICON,
								Position = UDim2.fromOffset(Theme.Padding.Small + 4, (GearLayout.ROW_TALL - ICON) / 2),
							}),
							-- the progress line along the row's bottom, under the time left
							s:New("Frame")({
								Name = "Progress",
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.new(0, ICON + 16, 1, -4),
								Size = UDim2.new(1, -(ICON + 24), 0, 4),
								BackgroundColor3 = Theme.Paper.Rule,
								BorderSizePixel = 0,
								[Children] = s:New("Frame")({
									Size = s:Computed(function(use2): UDim2
										return UDim2.fromScale(use2(progress), 1)
									end),
									BackgroundColor3 = s:Computed(function(use2): Color3
										return if use2(ready) then Theme.Paper.Success else Theme.Paper.Accent
									end),
									BorderSizePixel = 0,
								}),
							}),
						},
					})
				)
			elseif index <= Recipes.QUEUE_SLOTS or orders[index] ~= nil then
				table.insert(
					list,
					ListRow(s, {
						Name = `Order{index}`,
						LayoutOrder = index,
						Index = index,
						Tall = true,
						Dense = true,
						Muted = true,
						Text = Text.get(use, "alchemy.emptySlot"),
					})
				)
			end
		end
		return list
	end)

	local anyReady = scope:Computed(function(use): boolean
		return #Time.readyItems(use(queue) or {}, use(now)) > 0
	end)

	local titleAt, titleSize = placed(scope, layout, function(l)
		return l.title
	end)
	local queueAt, queueSize = placed(scope, layout, function(l)
		return l.queue
	end)
	-- in the window's footer, under the queue (GearLayout.alchemy: the queue's width, the row's height)
	local collectSize = scope:Computed(function(use): UDim2
		local r = use(layout).collect
		return UDim2.fromOffset(r.right - r.left, r.bottom - r.top)
	end)
	local collectButton = Button(scope, {
		LayoutOrder = 1,
		Size = collectSize,
		Variant = "primary",
		Text = Text.T(scope, "alchemy.collectAll"),
		Disabled = scope:Computed(function(use): boolean
			return not use(anyReady)
		end),
		OnClick = collect,
	})
	return {
		scope:New("TextLabel")({
			Name = "QueueTitle",
			Position = titleAt,
			Size = titleSize,
			BackgroundTransparency = 1,
			Text = Text.T(scope, "alchemy.queue"),
			FontFace = Theme.Fonts.Display,
			TextSize = Theme.TextSize.Large,
			TextColor3 = Theme.Paper.Heading,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		-- the orders scroll; "Odbierz wszystko" stands in the window's footer under them
		scope:New("ScrollingFrame")({
			Name = "Queue",
			Position = queueAt,
			Size = queueSize,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Paper.Rule,
			[Children] = {
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, GearLayout.ALCHEMY.gap),
				}),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
				slots :: any,
			},
		}),
	},
		collectButton
end

local function AlchemyWindow(scope: Scope, props: Props): Window.Parts
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

	-- the recipes and the queue (GearLayout.alchemy) from the body's own size, above the footer
	local view = ViewSize.new(scope)
	local layout = scope:Computed(function(use): GearLayout.Alchemy
		return GearLayout.alchemy(use(view.size) or AREA_PC)
	end)
	local recipesAt, recipesSize = placed(scope, layout, function(l)
		return l.recipes
	end)

	local queueParts, collectButton = queuePanel(scope, props, layout)
	local root = scope:New("Frame")({
		Name = "Alchemy",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			view.ruler,
			scope:New("Frame")({
				Name = "Recipes",
				Position = recipesAt,
				Size = recipesSize,
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
					-- the group tabs fit or scroll sideways (Components/Tabs; tests/gearlayout.spec checks the strip)
					scope:New("ScrollingFrame")({
						Position = UDim2.fromOffset(0, GearLayout.tabsTop()),
						Size = UDim2.new(1, 0, 1, -GearLayout.tabsTop()),
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 6,
						ScrollBarImageColor3 = Theme.Paper.Rule,
						[Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 6),
							}),
							scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
							rows :: any,
						},
					}),
				},
			}),
			queueParts :: any,
		},
	})
	view.watch(root)
	return { Content = root, Footer = collectButton }
end

return AlchemyWindow
