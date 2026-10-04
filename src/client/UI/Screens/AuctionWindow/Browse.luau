--!strict
-- Auction window, "Browse" tab: filters on the left (category, class, rarity, level range, name, price
-- order), results on the right (icon, name in rarity colour, level, price, time left, seller, "Buy" with a
-- confirmation) and paging. Clicking a row loads the full item (bonuses) for its tooltip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Market = require(ReplicatedStorage.Shared.Data.Market)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local LEFT = 250

-- Cycles through options on click: { value, labelKey }.
local function cycleButton(
	scope: Scope,
	order: number,
	value: Fusion.Value<any>,
	options: { { value: any, label: (use: Fusion.Use) -> string } }
): Instance
	return Button(scope, {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = Theme.TextSize.Small,
		Text = scope:Computed(function(use): string
			local current = use(value)
			for _, option in options do
				if option.value == current then
					return option.label(use)
				end
			end
			return options[1].label(use)
		end),
		OnClick = function()
			local current = Fusion.peek(value)
			local index = 1
			for i, option in options do
				if option.value == current then
					index = i
				end
			end
			value:set(options[index % #options + 1].value)
		end,
	})
end

local function Browse(scope: Scope, showModal: (spec: any) -> ()): Instance
	local category = scope:Value(nil :: string?)
	local class = scope:Value(nil :: string?)
	local rarity = scope:Value(nil :: number?)
	local minLevel = scope:Value("")
	local maxLevel = scope:Value("")
	local nameText = scope:Value("")
	local descending = scope:Value(false)
	local page = scope:Value(1)
	local result = scope:Value(nil :: any)
	local loading = scope:Value(false)
	local fullItems = scope:Value({} :: { [string]: any })

	local function run(targetPage: number)
		if Fusion.peek(loading) then
			return
		end
		loading:set(true)
		task.spawn(function()
			local filter = {
				category = Fusion.peek(category),
				class = Fusion.peek(class),
				rarity = Fusion.peek(rarity),
				minLevel = tonumber(Fusion.peek(minLevel)),
				maxLevel = tonumber(Fusion.peek(maxLevel)),
				text = Fusion.peek(nameText),
			}
			local ok, data = Net.Invoke("AuctionSearch", filter, targetPage, Fusion.peek(descending))
			loading:set(false)
			if ok then
				result:set(data)
				page:set(data.page)
			else
				Sounds.play("error")
				Toast.push(Text.now(data or "error.internal"), "error")
			end
		end)
	end

	local function loadDetails(id: string)
		if Fusion.peek(fullItems)[id] then
			return
		end
		task.spawn(function()
			local ok, item = Net.Invoke("AuctionDetails", id)
			if ok and type(item) == "table" then
				local copy = table.clone(Fusion.peek(fullItems))
				copy[id] = item
				fullItems:set(copy)
			end
		end)
	end

	local function confirmBuy(entry: any)
		local name = ItemText.name(entry.item.id, entry.item.up)
		showModal({
			Title = Text.now("auction.buy.title"),
			Message = Text.now("auction.buy.confirm", {
				item = if entry.item.n > 1 then `{name} x{entry.item.n}` else name,
				price = Format.number(entry.price),
			}),
			ConfirmText = Text.now("auction.buy"),
			CancelText = Text.now("common.cancel"),
			OnConfirm = function(): (boolean, string?)
				local ok, err = Net.Invoke("AuctionBuy", entry.id, entry.price)
				if not ok then
					run(Fusion.peek(page))
					return false, Text.now(err or "error.internal")
				end
				Sounds.play("levelUp")
				Toast.push(Text.now(err or "auction.bought", { item = name }), "success")
				run(Fusion.peek(page))
				return true, nil
			end,
		})
	end

	-- Filters ------------------------------------------------------------------------------------
	local categoryButtons = {}
	local allCategories: { { id: string?, nameKey: string } } = { { id = nil, nameKey = "auction.category.all" } }
	for _, c in Market.categories do
		table.insert(allCategories, { id = c.id, nameKey = c.nameKey })
	end
	for i, c in allCategories do
		table.insert(
			categoryButtons,
			Button(scope, {
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 34),
				TextSize = Theme.TextSize.Small,
				Variant = scope:Computed(function(use): any
					return if use(category) == c.id then "primary" else "secondary"
				end),
				Text = Text.T(scope, c.nameKey),
				OnClick = function()
					category:set(c.id)
					run(1)
				end,
			})
		)
	end

	local classOptions: { { value: any, label: (use: Fusion.Use) -> string } } = {
		{
			value = nil,
			label = function(use)
				return Text.get(use, "auction.filter.anyClass")
			end,
		},
	}
	for _, id in Classes.order do
		local def = Classes.get(id)
		table.insert(classOptions, {
			value = id,
			label = function(use)
				return if def then Text.get(use, def.nameKey) else id
			end,
		})
	end
	local rarityOptions: { { value: any, label: (use: Fusion.Use) -> string } } = {
		{
			value = nil,
			label = function(use)
				return Text.get(use, "auction.filter.anyRarity")
			end,
		},
	}
	for id, def in Rarities.list do
		table.insert(rarityOptions, {
			value = id,
			label = function(use)
				return Text.get(use, def.nameKey)
			end,
		})
	end

	local filters = scope:New("ScrollingFrame")({
		Size = UDim2.new(0, LEFT, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
			scope:New("Frame")({
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
					categoryButtons :: any,
				},
			}),
			cycleButton(scope, 2, class, classOptions),
			cycleButton(scope, 3, rarity, rarityOptions),
			scope:New("Frame")({
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundTransparency = 1,
				[Children] = {
					TextInput(scope, {
						Size = UDim2.new(0.5, -4, 0, 46),
						Text = minLevel,
						MaxLength = 3,
						Placeholder = Text.T(scope, "auction.filter.minLevel"),
					}),
					TextInput(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0.5, -4, 0, 46),
						Text = maxLevel,
						MaxLength = 3,
						Placeholder = Text.T(scope, "auction.filter.maxLevel"),
					}),
				},
			}),
			TextInput(scope, {
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 46),
				Text = nameText,
				MaxLength = 40,
				Placeholder = Text.T(scope, "auction.filter.name"),
				OnSubmit = function()
					run(1)
				end,
			}),
			cycleButton(scope, 6, descending, {
				{
					value = false,
					label = function(use)
						return Text.get(use, "auction.sort.asc")
					end,
				},
				{
					value = true,
					label = function(use)
						return Text.get(use, "auction.sort.desc")
					end,
				},
			}),
			Button(scope, {
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 46),
				Variant = "primary",
				Text = Text.T(scope, "auction.search"),
				Disabled = loading,
				OnClick = function()
					run(1)
				end,
			}),
		},
	})

	-- Results ------------------------------------------------------------------------------------
	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local data = use(result)
		local list = {}
		if type(data) ~= "table" then
			return list
		end
		if #data.results == 0 then
			table.insert(
				list,
				s:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 60),
					BackgroundTransparency = 1,
					Text = Text.get(use, "auction.noResults"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.TextMuted,
				})
			)
		end
		local now = Workspace:GetServerTimeNow()
		local level = State.Get({ "character", "level" }) or 1
		for i, entry in data.results do
			local item = s:Computed(function(use2): any
				return use2(fullItems)[entry.id] or entry.item
			end)
			local name = ItemText.get(use, entry.item.id, entry.item.up)
			table.insert(
				list,
				s:New("TextButton")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 64),
					AutoButtonColor = false,
					Text = "",
					BackgroundColor3 = Theme.Colors.PanelRaised,
					BackgroundTransparency = 0.3,
					[Fusion.OnEvent("Activated")] = function()
						loadDetails(entry.id)
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						ItemSlot(s, {
							SlotId = `view:auc:{entry.id}`,
							Item = item,
							Size = 52,
							Position = UDim2.fromOffset(6, 6),
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(68, 6),
							Size = UDim2.new(1, -330, 0, 26),
							BackgroundTransparency = 1,
							Text = if entry.item.n > 1 then `{name} x{entry.item.n}` else name,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = ItemText.rarityColor(entry.item.rarity),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(68, 34),
							Size = UDim2.new(1, -330, 0, 22),
							BackgroundTransparency = 1,
							Text = Text.get(use, "auction.row", {
								level = entry.level,
								time = Format.time(entry.expiresAt - now),
								seller = entry.seller,
							}),
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if entry.level > level then Theme.Colors.Danger else Theme.Colors.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -140, 0.5, 0),
							Size = UDim2.fromOffset(170, 30),
							BackgroundTransparency = 1,
							Text = `◉ {Format.number(entry.price)}`,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = Theme.Colors.GoldBright,
							TextXAlignment = Enum.TextXAlignment.Right,
						}),
						Button(s, {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -8, 0.5, 0),
							Size = UDim2.fromOffset(120, 44),
							Variant = "primary",
							TextSize = Theme.TextSize.Small,
							Text = Text.T(s, if entry.own then "auction.own" else "auction.buy"),
							Disabled = entry.own,
							OnClick = function()
								confirmBuy(entry)
							end,
						}),
					},
				})
			)
		end
		return list
	end)

	return scope:New("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			filters,
			scope:New("ScrollingFrame")({
				Position = UDim2.fromOffset(LEFT + 10, 0),
				Size = UDim2.new(1, -(LEFT + 10), 1, -54),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
					rows :: any,
				},
			}),
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, LEFT + 10, 1, 0),
				Size = UDim2.new(1, -(LEFT + 10), 0, 46),
				BackgroundTransparency = 1,
				[Children] = {
					Button(scope, {
						Size = UDim2.fromOffset(110, 44),
						Text = "◀",
						OnClick = function()
							run(math.max(1, Fusion.peek(page) - 1))
						end,
					}),
					scope:New("TextLabel")({
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.fromScale(0.5, 0),
						Size = UDim2.new(1, -240, 1, 0),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local data = use(result)
							if use(loading) then
								return Text.get(use, "auction.loading")
							end
							if type(data) ~= "table" then
								return Text.get(use, "auction.hint")
							end
							return Text.get(
								use,
								"auction.page",
								{ page = data.page, pages = data.pages, total = data.total }
							)
						end),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(110, 44),
						Text = "▶",
						OnClick = function()
							local data = Fusion.peek(result)
							local pages = if type(data) == "table" then data.pages else 1
							run(math.min(pages, Fusion.peek(page) + 1))
						end,
					}),
				},
			}),
		},
	})
end

return Browse
