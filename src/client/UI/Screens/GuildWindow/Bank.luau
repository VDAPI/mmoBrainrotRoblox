--!strict
-- Guild window, "Bank" tab (S159g, Logic/GuildBank): the treasury with deposit and withdrawal (rank right and daily
-- limit), and the item vault next to the backpack. Items are dragged between them ("inv:N" <-> "gv:N", ItemController);
-- a double click on a vault item takes it. Every move lands in the guild log (Overview tab).
-- 2026-10-21 (owner: too many descriptions): the drag hint is one short line, its rules behind an "i".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Common = require(script.Parent.Common)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Guild = require(ReplicatedStorage.Shared.Logic.Guild)
local InfoLine = require(script.Parent.Parent.Parent.Components.InfoLine)
local Inventory = require(ReplicatedStorage.Shared.Logic.Inventory)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SLOT = 52
local TOP = 150 -- height of the gold part above the two grids

-- One grid of item slots; each slot listens to its own state key (`basePath` + index).
local function grid(scope: Scope, prefix: string, count: Fusion.UsedAs<number>, basePath: { string }): Instance
	local slots = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		for index = 1, use(count) do
			local path = table.clone(basePath)
			table.insert(path, tostring(index))
			table.insert(
				list,
				ItemSlot(s, {
					SlotId = `{prefix}:{index}`,
					Size = SLOT,
					LayoutOrder = index,
					Item = State.Value(path),
				})
			)
		end
		return list
	end)
	return scope:New("ScrollingFrame")({
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Rule,
		[Children] = {
			scope:New("UIGridLayout")({
				CellSize = UDim2.fromOffset(SLOT, SLOT),
				CellPadding = UDim2.fromOffset(4, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2) }),
			slots :: any,
		},
	})
end

local function title(scope: Scope, text: Fusion.UsedAs<string>): Instance
	return scope:New("TextLabel")({
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = text,
		FontFace = Theme.Fonts.Display,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Paper.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local function Bank(scope: Scope): Instance
	local guild = State.Value({ "guild" })
	local gold = State.Value({ "character", "gold" })
	local inventory = State.Value({ "character", "inventory" })
	local backpack = State.Value({ "character", "equipment", "backpack" })
	local pockets = State.Value({ "passes", "pockets" })
	local amount = scope:Value("")

	local capacity = scope:Computed(function(use): number
		local item = use(backpack)
		local cap = Inventory.capacityOf(if item then item.id else nil, use(pockets) == true)
		return math.max(cap, Inventory.lastIndex(use(inventory) or {}))
	end)
	-- a vault that shrank never hides items: the slots above the size stay visible until emptied
	local vaultCount = scope:Computed(function(use): number
		local g = use(guild)
		if type(g) ~= "table" then
			return 0
		end
		local last = 0
		for key in g.vault or {} do
			last = math.max(last, tonumber(key) or 0)
		end
		return math.max(g.vaultSize or 0, last)
	end)
	local canWithdraw = scope:Computed(function(use): boolean
		local g = use(guild)
		return type(g) == "table" and Guild.can(g.myRank, "withdrawGold", g)
	end)

	local function parsed(): number?
		local n = tonumber(Fusion.peek(amount))
		if not n or n < 1 or n ~= math.floor(n) then
			Sounds.play("error")
			Toast.push(Text.now("guild.error.amount"), "error")
			return nil
		end
		return n
	end

	local function deposit()
		local n = parsed()
		if not n then
			return
		end
		task.spawn(function()
			if Common.invoke("GuildDeposit", n) then
				Sounds.play("levelUp")
				Toast.push(Text.now("guild.deposited", { amount = Format.number(n) }), "success")
				amount:set("")
			end
		end)
	end

	local function withdraw()
		local n = parsed()
		if not n then
			return
		end
		task.spawn(function()
			if Common.invoke("GuildWithdraw", n) then
				Sounds.play("levelUp")
				Toast.push(Text.now("guild.withdrawn", { amount = Format.number(n) }), "success")
				amount:set("")
			end
		end)
	end

	return scope:New("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			-- Gold
			scope:New("Frame")({
				Size = UDim2.new(1, 0, 0, TOP),
				BackgroundTransparency = 1,
				[Children] = {
					Common.list(scope, 6),
					scope:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 30),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local g = use(guild)
							return Text.get(use, "guild.bank.treasury", {
								gold = Format.number(if type(g) == "table" then g.treasury else 0),
							})
						end),
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Large,
						TextColor3 = Theme.Paper.Heading,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("Frame")({
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 48),
						BackgroundTransparency = 1,
						[Children] = {
							TextInput(scope, {
								Size = UDim2.new(1, -490, 0, 46),
								Text = amount,
								MaxLength = 10,
								Placeholder = Text.T(scope, "guild.deposit.placeholder"),
								OnSubmit = deposit,
							}),
							Button(scope, {
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.new(1, -330, 0, 0),
								Size = UDim2.fromOffset(150, 46),
								Text = scope:Computed(function(use): string
									return `◉ {Format.number(use(gold) or 0)}`
								end),
								TextSize = Theme.TextSize.Small,
								OnClick = function()
									amount:set(tostring(State.Get({ "character", "gold" }) or 0))
								end,
							}),
							Button(scope, {
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.new(1, -168, 0, 0),
								Size = UDim2.fromOffset(152, 46),
								Variant = "primary",
								Text = Text.T(scope, "guild.deposit"),
								OnClick = deposit,
							}),
							Button(scope, {
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.fromScale(1, 0),
								Size = UDim2.fromOffset(160, 46),
								Text = Text.T(scope, "guild.withdraw"),
								Disabled = scope:Computed(function(use): boolean
									return not use(canWithdraw)
								end),
								OnClick = withdraw,
							}),
						},
					}),
					Common.paragraph(
						scope,
						3,
						scope:Computed(function(use): string
							local g = use(guild)
							if type(g) ~= "table" then
								return ""
							end
							local goldLine = if not Guild.can(g.myRank, "withdrawGold", g)
								then Text.get(use, "guild.bank.noGold")
								elseif g.goldLeft == -1 then Text.get(use, "guild.bank.goldFree")
								else Text.get(
									use,
									"guild.bank.goldLeft",
									{ gold = Format.number(g.goldLeft or 0) }
								)
							local itemLine = if not Guild.can(g.myRank, "takeItem", g)
								then Text.get(use, "guild.bank.noItems")
								elseif g.itemsLeft == -1 then Text.get(use, "guild.bank.itemsFree")
								else Text.get(use, "guild.bank.itemsLeft", { n = g.itemsLeft or 0 })
							return `{goldLine}  ·  {itemLine}`
						end)
					),
					InfoLine.new(scope, {
						LayoutOrder = 4,
						Text = Text.T(scope, "guild.bank.hint.short"),
						Info = Text.T(scope, "guild.bank.hint"),
						Color = Theme.Paper.TextMuted,
					}),
				},
			}),
			-- Backpack | vault
			scope:New("Frame")({
				Position = UDim2.fromOffset(0, TOP),
				Size = UDim2.new(0.5, -8, 1, -TOP),
				BackgroundTransparency = 1,
				[Children] = {
					title(scope, Text.T(scope, "deposit.inventory")),
					grid(scope, "inv", capacity, { "character", "inventory" }),
				},
			}),
			scope:New("Frame")({
				Position = UDim2.new(0.5, 8, 0, TOP),
				Size = UDim2.new(0.5, -8, 1, -TOP),
				BackgroundTransparency = 1,
				[Children] = {
					title(
						scope,
						scope:Computed(function(use): string
							local g = use(guild)
							local used = 0
							for _ in if type(g) == "table" then g.vault or {} else {} do
								used += 1
							end
							return Text.get(use, "guild.bank.vault", {
								used = used,
								size = if type(g) == "table" then g.vaultSize or 0 else 0,
							})
						end)
					),
					grid(scope, "gv", vaultCount, { "guild", "vault" }),
				},
			}),
		},
	})
end

return Bank
