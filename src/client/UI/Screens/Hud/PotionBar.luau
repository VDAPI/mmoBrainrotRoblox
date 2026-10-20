--!strict
-- Potion bar (DESIGN §9): three slots (health Z, mana X, energy V) showing the assigned potion, how many
-- are left and the cooldown (Logic/Potions.interval of the character level). Click / tap drinks; drop a potion
-- from the backpack to assign it; right-click (or long-press on touch) opens a picker with the qualities you carry.
-- S122: the Elixir of Wholeness fits every slot (Logic/Potions.fitsSlot); its slot shows the saved elixir cooldown
-- (character.fullElixir.readyAt, os.time = server time), "0/10" once today's limit is used up, no quality numeral.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Config = require(ReplicatedStorage.Shared.Config)
local DragDrop = require(script.Parent.Parent.Parent.DragDrop)
local FullElixir = require(ReplicatedStorage.Shared.Logic.FullElixir)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Motion = require(script.Parent.Parent.Parent.Motion)
local Keybinds = require(script.Parent.Parent.Parent.Keybinds)
local IconState = require(script.Parent.Parent.Parent.IconState)
local ItemIcon = require(script.Parent.Parent.Parent.Components.ItemIcon)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Potions = require(ReplicatedStorage.Shared.Logic.Potions)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	LayoutOrder: number?,
	Use: (kind: string) -> (),
	Assign: (kind: string, itemId: string?) -> (),
}

local SIZE = 56
local ROMAN = { "I", "II", "III", "IV", "V" }
local LONG_PRESS = 0.5

local KINDS: { { kind: string, color: Color3 } } = {
	{ kind = "hp", color = Theme.Resource.Hp },
	{ kind = "mana", color = Theme.Resource.Mana },
	{ kind = "energy", color = Theme.Resource.Energy },
}

local function PotionBar(scope: Scope, props: Props): Instance
	local inventory = State.Value({ "character", "inventory" })
	local potionBar = State.Value({ "character", "potionBar" })
	local cooldowns = State.Value({ "potions" })
	local level = State.Value({ "character", "level" })
	local elixir = State.Value({ "character", "fullElixir" }) -- S122
	local now = scope:Value(Workspace:GetServerTimeNow())
	local picker = scope:Value(nil :: string?)

	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			local t = Workspace:GetServerTimeNow()
			-- S122: also while the elixir recovers, and every few seconds after it was used today (the UTC day
			-- may reset the "0/10" mark)
			local e = Fusion.peek(elixir)
			local recovering = type(e) == "table" and FullElixir.readyIn(e, t) > 0
			local usedToday = type(e) == "table" and (e.used or 0) > 0 and t - Fusion.peek(now) >= 5
			if Fusion.peek(cooldowns) ~= nil or recovering or usedToday then
				now:set(t)
			end
		end)
	)

	local function count(inv: any, itemId: string?): number
		if not itemId or type(inv) ~= "table" then
			return 0
		end
		local n = 0
		for _, item in inv do
			if item.id == itemId then
				n += item.n
			end
		end
		return n
	end

	local slots = {}
	for index, entry in KINDS do
		local assigned = scope:Computed(function(use): string?
			local bar = use(potionBar)
			return if type(bar) == "table" then bar[entry.kind] else nil
		end)
		local amount = scope:Computed(function(use): number
			return count(use(inventory), use(assigned))
		end)
		local assignedDef = scope:Computed(function(use): Items.ItemDef?
			local id = use(assigned)
			return if id then Items.get(id) else nil
		end)
		local showArt = scope:Computed(function(use): boolean
			return IconState.picture(use, use(assignedDef)) ~= nil
		end)
		local isElixir = scope:Computed(function(use): boolean
			local def = use(assignedDef)
			return def ~= nil and def.use ~= nil and def.use.kind == "fullElixir"
		end)
		local cooldown = scope:Computed(function(use): number
			if use(isElixir) then
				-- S122: the saved elixir cooldown (os.time on the server = Roblox server time here)
				return math.clamp(FullElixir.readyIn(use(elixir), use(now)) / Config.FullElixir.cooldown, 0, 1)
			end
			local c = use(cooldowns)
			local ready = if type(c) == "table" then c[entry.kind] else nil
			if not ready then
				return 0
			end
			-- S54: the interval grows with the character level (Logic/Potions, same function as the server).
			return math.clamp((ready - use(now)) / Potions.interval(use(level) or 1), 0, 1)
		end)
		local pressToken = 0

		local slot = scope:New("TextButton")({
			Name = `Potion_{entry.kind}`,
			LayoutOrder = index,
			Size = UDim2.fromOffset(SIZE, SIZE),
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Iron.Raised, -- S136: the iron slot
			BackgroundTransparency = Theme.HudAlpha,
			Text = "",
			[OnEvent("Activated")] = function()
				if os.clock() - DragDrop.LastDropAt < 0.3 then
					return
				end
				props.Use(entry.kind)
			end,
			[OnEvent("MouseButton2Click")] = function()
				picker:set(if Fusion.peek(picker) == entry.kind then nil else entry.kind)
			end,
			[OnEvent("InputBegan")] = function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.Touch then
					pressToken += 1
					local token = pressToken
					task.delay(LONG_PRESS, function()
						if token == pressToken then
							picker:set(entry.kind)
						end
					end)
				end
			end,
			[OnEvent("InputEnded")] = function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.Touch then
					pressToken += 1
				end
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = Theme.Stroke.Normal,
					Color = Theme.Brass.Line,
				}),
				-- S35: the assigned potion's picture (size and colour from its data) while the atlases are loaded.
				ItemIcon(scope, {
					Def = assignedDef,
					Size = UDim2.fromScale(0.8, 0.8),
					Transparency = scope:Computed(function(use): number
						return if use(amount) > 0 then 0 else 0.6
					end),
					Visible = showArt,
				}),
				-- S119: without the potion's own picture, the empty-flask silhouette in the potion colour once loaded.
				ArtIcon(scope, {
					Name = "Icon",
					Key = UiArt.hud("potion_empty"),
					Glyph = "⚗",
					GlyphColor = entry.color,
					ImageScale = 0.6,
					Size = UDim2.fromScale(1, 1),
					Visible = scope:Computed(function(use): boolean
						return not use(showArt)
					end),
					Transparency = scope:Computed(function(use): number
						return if use(amount) > 0 then 0 else 0.7
					end),
					Label = { FontFace = Theme.Fonts.BodyBold, TextSize = Theme.TextSize.Title },
				}),
				scope:New("TextLabel")({
					Name = "Quality",
					Position = UDim2.fromOffset(4, 2),
					Size = UDim2.fromOffset(20, 14),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						local id = use(assigned)
						local def = id and Items.get(id)
						if use(isElixir) then
							-- S122: no quality numeral; "0/10" once today's limit is used up
							local left = FullElixir.leftToday(use(elixir), use(now))
							return if left <= 0 then `0/{Config.FullElixir.dailyLimit}` else ""
						end
						return if def and def.tier then ROMAN[def.tier] or "" else ""
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Caption,
					TextColor3 = Theme.Iron.Text,
					TextStrokeTransparency = 0.2,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				scope:New("TextLabel")({
					Name = "Count",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -3, 1, -1),
					Size = UDim2.fromOffset(40, 16),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return tostring(use(amount))
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Caption,
					TextColor3 = Theme.Iron.Text,
					TextStrokeTransparency = 0.2,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				scope:New("TextLabel")({
					Name = "Key",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -4, 0, 2),
					Size = UDim2.fromOffset(16, 16),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = Theme.Iron.Sunken, -- S136: the key on a plaque
					BackgroundTransparency = Theme.BadgeAlpha,
					Text = Keybinds.Label(scope, `potion_{entry.kind}`),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Caption,
					TextColor3 = Theme.Iron.Text,
				}),
				-- Cooldown sweep (fills from the bottom)
				scope:New("Frame")({
					Name = "Cooldown",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = scope:Computed(function(use): UDim2
						return UDim2.fromScale(1, use(cooldown))
					end),
					BackgroundColor3 = Theme.Shade,
					BackgroundTransparency = 0.45,
					ZIndex = 3,
					[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				}),
			},
		})
		Motion.feedback(scope, slot :: GuiButton, Theme.Corner.Small) -- W28: hover sheen and a sink while held
		DragDrop.register(scope, slot :: GuiObject, `pot:{entry.kind}`)
		Tooltip.attach(
			scope,
			slot :: GuiObject,
			scope:Computed(function(use): string
				local id = use(assigned)
				if id and use(isElixir) then
					-- S122: key, cooldown and uses left today
					local state = use(elixir)
					local t = use(now)
					local wait = FullElixir.readyIn(state, t)
					return Text.get(use, "fullElixir.slot", {
						key = Keybinds.label(`potion_{entry.kind}`),
						time = if wait > 0 then Time.format(wait) else Text.get(use, "fullElixir.ready"),
						left = FullElixir.leftToday(state, t),
						max = Config.FullElixir.dailyLimit,
					})
				end
				local head = Text.get(use, `potion.slot.{entry.kind}`)
				return if id then `{ItemText.get(use, id)}\n{head}` else head
			end)
		)
		table.insert(slots, slot)
	end

	-- Picker: the potion qualities of the opened kind found in the backpack.
	local pickerList = scope:Computed(function(use, s: Scope): { Instance }
		local kind = use(picker)
		if not kind then
			return {}
		end
		local inv = use(inventory) or {}
		local found: { [string]: number } = {}
		for _, item in inv do
			-- S122: one rule with the server (the elixir fits every slot)
			if Potions.fitsSlot(Items.get(item.id), kind) then
				found[item.id] = (found[item.id] or 0) + item.n
			end
		end
		local ids = {}
		for id in found do
			table.insert(ids, id)
		end
		table.sort(ids)
		local list: { Instance } = {}
		if #ids == 0 then
			table.insert(
				list,
				s:New("TextLabel")({
					Size = UDim2.fromOffset(240, 32),
					BackgroundTransparency = 1,
					Text = Text.get(use, "potion.pick.empty"),
					TextWrapped = true,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Iron.Text,
				})
			)
		end
		for i, id in ids do
			-- S122: the elixir row carries the item's glyph and colour (no quality numeral)
			local def = Items.get(id)
			local elixirRow = def ~= nil and def.use ~= nil and def.use.kind == "fullElixir"
			table.insert(
				list,
				s:New("TextButton")({
					LayoutOrder = i,
					Size = UDim2.fromOffset(240, Theme.Size.MinTouch),
					AutoButtonColor = true,
					BackgroundColor3 = Theme.Iron.Raised,
					Text = if elixirRow and def
						then `{def.icon.glyph} {ItemText.get(use, id)} ({found[id]})`
						else `{ItemText.get(use, id)} ({found[id]})`,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = if elixirRow and def then Theme.readable(def.icon.color, "iron") else Theme.Iron.Text,
					[OnEvent("Activated")] = function()
						picker:set(nil)
						props.Assign(kind, id)
					end,
					[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				})
			)
		end
		return list
	end)

	return scope:New("Frame")({
		Name = "PotionBar",
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(SIZE * 3 + 12, SIZE),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("Frame")({
				Name = "Slots",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					slots :: any,
				},
			}),
			scope:New("Frame")({
				Name = "Picker",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -8),
				Size = UDim2.fromOffset(252, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Iron.Surface,
				Visible = scope:Computed(function(use): boolean
					return use(picker) ~= nil
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 6),
						PaddingBottom = UDim.new(0, 6),
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
					}),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					pickerList :: any,
				},
			}),
		},
	})
end

return PotionBar
