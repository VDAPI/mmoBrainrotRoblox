--!strict
-- Forge → Upgrading (DESIGN §6): pick an item (drag it onto the anvil slot or click it in the list — backpack
-- and equipped items), see +N → +N+1 with stat comparison, the success chance in a big coloured number, the
-- cost (owned / needed) and an optional Scroll of Protection. "Upgrade" plays ~1.5 s of tension (sparks,
-- rising sound) and then the result: golden burst and the new +N, or a red crack and the drop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local SelectableSlot = require(script.Parent.Parent.Parent.Components.SelectableSlot)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Stats = require(ReplicatedStorage.Shared.Data.Stats)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)
local Upgrade = require(ReplicatedStorage.Shared.Logic.Upgrade)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Target = { location: string, key: string }

export type Props = {
	Target: Fusion.Value<Target?>,
}

local TENSION = 1.5

local function count(inv: any, itemId: string): number
	local n = 0
	for _, item in inv or {} do
		if item.id == itemId then
			n += item.n
		end
	end
	return n
end

local function resolve(target: Target?, inventory: any, equipment: any): Types.ItemInstance?
	if not target then
		return nil
	end
	if target.location == "eq" then
		return if type(equipment) == "table" then equipment[target.key] else nil
	end
	return if type(inventory) == "table" then inventory[target.key] else nil
end

-- Base stat lines "stat: value" for an item at an upgrade level.
local function statLines(use: Fusion.Use, item: Types.ItemInstance, up: number): { string }
	local copy = table.clone(item)
	copy.up = up
	local stats = ItemRoll.itemStats(copy)
	local lines = {}
	if stats.weapon then
		if stats.weapon.dmg > 0 then
			table.insert(lines, Text.get(use, "tooltip.damage", { dmg = stats.weapon.dmg }))
		end
		if stats.weapon.mdmg > 0 then
			table.insert(lines, Text.get(use, "tooltip.magicDamage", { mdmg = stats.weapon.mdmg }))
		end
	end
	local keys = {}
	for stat in stats.base do
		table.insert(keys, stat)
	end
	table.sort(keys)
	local aliases = { hp = "maxHp", mana = "maxMana", energy = "maxEnergy" }
	for _, stat in keys do
		local def = Stats.get(aliases[stat] or stat)
		local name = Text.get(use, `stat.{aliases[stat] or stat}`)
		local value = stats.base[stat]
		local text = if value % 1 == 0 then tostring(value) else string.format("%.1f", value)
		if def and def.format == "pct" then
			text ..= "%"
		end
		table.insert(lines, `{name}: {text}`)
	end
	return lines
end

local function Upgrade_(scope: Scope, props: Props): Instance
	local inventory = State.Value({ "character", "inventory" })
	local equipment = State.Value({ "character", "equipment" })
	local gold = State.Value({ "character", "gold" })
	local protect = scope:Value(false)
	local phase = scope:Value("idle") -- idle | forging | success | fail | saved
	local resultText = scope:Value("")
	local flashColor = scope:Value(Theme.Colors.Panel)
	local flash = scope:Value(1)
	local animatedFlash = scope:Tween(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	local anvil: Frame? = nil

	local item = scope:Computed(function(use): Types.ItemInstance?
		return resolve(use(props.Target), use(inventory), use(equipment))
	end)
	local cost = scope:Computed(function(use): Upgrade.Cost?
		local i = use(item)
		if not i or not Upgrade.canUpgrade(i) then
			return nil
		end
		return Upgrade.cost(i, i.up + 1)
	end)

	local function sparks()
		local holder = anvil
		if not holder then
			return
		end
		for i = 1, 18 do
			task.delay(i * TENSION / 20, function()
				local spark = Instance.new("Frame")
				spark.AnchorPoint = Vector2.new(0.5, 0.5)
				spark.Position = UDim2.fromScale(0.5, 0.55)
				spark.Size = UDim2.fromOffset(6, 6)
				spark.BackgroundColor3 = Color3.fromHex("#FFD36B")
				spark.BorderSizePixel = 0
				spark.ZIndex = 5
				spark.Parent = holder
				local angle = math.random() * math.pi * 2
				local distance = 60 + math.random() * 90
				TweenService:Create(spark, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.new(0.5, math.cos(angle) * distance, 0.55, math.sin(angle) * distance - 30),
					BackgroundTransparency = 1,
				}):Play()
				task.delay(0.55, function()
					spark:Destroy()
				end)
				Sounds.playPitched("hit", 0.8 + i * 0.07)
			end)
		end
	end

	local function doUpgrade()
		local target = Fusion.peek(props.Target)
		local current = Fusion.peek(item)
		if not target or not current or Fusion.peek(phase) == "forging" then
			return
		end
		phase:set("forging")
		resultText:set("")
		sparks()
		local startedAt = os.clock()
		task.spawn(function()
			local ok, err, result = Net.Invoke("UpgradeItem", target.location, target.key, Fusion.peek(protect))
			local wait = TENSION - (os.clock() - startedAt)
			if wait > 0 then
				task.wait(wait)
			end
			if not ok then
				phase:set("idle")
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
				return
			end
			flash:set(0)
			if result.success then
				phase:set("success")
				flashColor:set(Theme.Colors.GoldBright)
				Sounds.play("levelUp")
				resultText:set(Text.now("smith.upgrade.success", { name = ItemText.name(current.id, result.to) }))
			elseif result.protected then
				phase:set("saved")
				flashColor:set(Theme.Colors.Accent)
				Sounds.play("error")
				resultText:set(Text.now("smith.upgrade.saved"))
			else
				phase:set("fail")
				flashColor:set(Theme.Colors.Danger)
				Sounds.playPitched("error", 0.4)
				resultText:set(
					if result.to == 0 and result.from == 0
						then Text.now("smith.upgrade.failZero")
						else Text.now("smith.upgrade.fail", { up = result.to })
				)
			end
			task.delay(0.05, function()
				flash:set(1)
			end)
		end)
	end

	-- Items that can be upgraded: equipped first, then the backpack.
	local candidates = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		local order = 0
		local function add(location: string, key: string, candidate: Types.ItemInstance)
			order += 1
			table.insert(
				list,
				SelectableSlot(s, {
					Id = `up:{location}:{key}`,
					LayoutOrder = order,
					Size = 56,
					Item = candidate,
					Selected = s:Computed(function(use2): boolean
						local t = use2(props.Target)
						return t ~= nil and t.location == location and t.key == key
					end),
					OnToggle = function()
						props.Target:set({ location = location, key = key })
						phase:set("idle")
						resultText:set("")
					end,
				})
			)
		end
		for slot, candidate in use(equipment) or {} do
			local def = Items.get(candidate.id)
			if slot ~= "backpack" and def and def.category == "equipment" then
				add("eq", slot, candidate)
			end
		end
		local keys = {}
		for key in use(inventory) or {} do
			table.insert(keys, tonumber(key) :: number)
		end
		table.sort(keys)
		for _, index in keys do
			local candidate = (use(inventory) :: any)[tostring(index)]
			local def = Items.get(candidate.id)
			if def and def.category == "equipment" then
				add("inv", tostring(index), candidate)
			end
		end
		return list
	end)

	local chance = scope:Computed(function(use): number
		local i = use(item)
		return if i and Upgrade.canUpgrade(i) then Upgrade.chance(i.up + 1) else 0
	end)

	local root = scope:New("Frame")({
		Name = "Upgrade",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			-- Left: items
			scope:New("TextLabel")({
				Size = UDim2.fromOffset(260, 24),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "smith.upgrade.items"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("ScrollingFrame")({
				Position = UDim2.fromOffset(0, 28),
				Size = UDim2.new(0, 262, 1, -28),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Colors.GoldDim,
				[Children] = {
					scope:New("UIGridLayout")({
						CellSize = UDim2.fromOffset(56, 56),
						CellPadding = UDim2.fromOffset(6, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					candidates :: any,
				},
			}),
			-- Right: anvil and details
			scope:New("Frame")({
				Name = "Anvil",
				Position = UDim2.fromOffset(280, 0),
				Size = UDim2.new(1, -280, 1, 0),
				BackgroundColor3 = flashColor,
				BackgroundTransparency = scope:Computed(function(use): number
					return 0.6 + use(animatedFlash) * 0.4
				end),
				ClipsDescendants = true,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 10),
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingBottom = UDim.new(0, 10),
					}),
					-- Drop target for dragged items
					scope:New("Frame")({
						Name = "Slot",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.fromScale(0.5, 0),
						Size = UDim2.fromOffset(84, 84),
						BackgroundTransparency = 1,
						[Children] = ItemSlot(scope, {
							SlotId = "smith:upgrade",
							Size = 84,
							Item = item,
							Placeholder = "⚒",
							EmptyTooltip = Text.T(scope, "smith.upgrade.pick"),
						}),
					}),
					scope:New("TextLabel")({
						Name = "Name",
						Position = UDim2.fromOffset(0, 92),
						Size = UDim2.new(1, 0, 0, 30),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local i = use(item)
							if not i then
								return Text.get(use, "smith.upgrade.pick")
							end
							return ItemText.get(use, i.id, i.up)
						end),
						TextWrapped = true,
						FontFace = Theme.Fonts.Heading,
						TextSize = Theme.TextSize.Large,
						TextColor3 = scope:Computed(function(use): Color3
							local i = use(item)
							return if i then ItemText.rarityColor(i.rarity) else Theme.Colors.TextMuted
						end),
					}),
					-- Stats now / after
					scope:New("TextLabel")({
						Name = "Compare",
						Position = UDim2.fromOffset(0, 128),
						Size = UDim2.new(1, 0, 0, 110),
						BackgroundTransparency = 1,
						RichText = true,
						TextWrapped = true,
						Text = scope:Computed(function(use): string
							local i = use(item)
							if not i then
								return ""
							end
							if not Upgrade.canUpgrade(i) then
								return Text.get(use, "smith.upgrade.max")
							end
							local now = statLines(use, i, i.up)
							local after = statLines(use, i, i.up + 1)
							local lines = {
								`<b>{Text.get(use, "smith.upgrade.now")} +{i.up} → {Text.get(
									use,
									"smith.upgrade.next"
								)} +{i.up + 1}</b>`,
							}
							for index, line in now do
								table.insert(lines, `{line}  <font color="#4FD16B">→ {after[index] or ""}</font>`)
							end
							return table.concat(lines, "\n")
						end),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
					-- Chance
					scope:New("TextLabel")({
						Name = "Chance",
						Position = UDim2.fromOffset(0, 240),
						Size = UDim2.new(0.4, 0, 0, 64),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return if use(item) then `{use(chance)}%` else ""
						end),
						FontFace = Theme.Fonts.Heading,
						TextSize = 56,
						TextColor3 = scope:Computed(function(use): Color3
							local c = use(chance)
							if c >= 70 then
								return Theme.Colors.Success
							elseif c >= 40 then
								return Theme.Colors.Warning
							end
							return Theme.Colors.DangerHover
						end),
					}),
					scope:New("TextLabel")({
						Name = "Cost",
						Position = UDim2.new(0.4, 8, 0, 240),
						Size = UDim2.new(0.6, -8, 0, 64),
						BackgroundTransparency = 1,
						RichText = true,
						TextWrapped = true,
						Text = scope:Computed(function(use): string
							local c = use(cost)
							if not c then
								return ""
							end
							local enoughGold = (use(gold) or 0) >= c.gold
							local parts = {
								`<font color="{if enoughGold then "#E8C25A" else "#CC5248"}">◉ {Format.number(c.gold)}</font>`,
							}
							local inv = use(inventory)
							for _, material in c.materials do
								local have = count(inv, material.id)
								local color = if have >= material.n then "#4FD16B" else "#CC5248"
								table.insert(
									parts,
									`<font color="{color}">{ItemText.get(use, material.id)} {have}/{material.n}</font>`
								)
							end
							return `{Text.get(use, "smith.upgrade.cost")}: ` .. table.concat(parts, "  ")
						end),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					-- Protection checkbox
					scope:New("TextButton")({
						Name = "Protect",
						Position = UDim2.fromOffset(0, 312),
						Size = UDim2.new(1, 0, 0, 36),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local mark = if use(protect) then "☑" else "☐"
							return `{mark}  {Text.get(
								use,
								"smith.upgrade.protect",
								{ count = count(use(inventory), "scroll_protection") }
							)}`
						end),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Colors.Parchment,
						TextXAlignment = Enum.TextXAlignment.Left,
						[OnEvent("Activated")] = function()
							Sounds.play("click")
							protect:set(not Fusion.peek(protect))
						end,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.new(0.5, 0, 1, -34),
						Size = UDim2.new(0.8, 0, 0, Theme.Size.ButtonHeight),
						Variant = "primary",
						Text = scope:Computed(function(use): string
							local p = use(phase)
							return Text.get(use, if p == "idle" then "smith.upgrade.button" else "smith.upgrade.again")
						end),
						Disabled = scope:Computed(function(use): boolean
							local i = use(item)
							return i == nil or not Upgrade.canUpgrade(i) or use(phase) == "forging"
						end),
						OnClick = doUpgrade,
					}),
					scope:New("TextLabel")({
						Name = "Result",
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, 28),
						BackgroundTransparency = 1,
						Text = resultText,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = scope:Computed(function(use): Color3
							local p = use(phase)
							if p == "success" then
								return Theme.Colors.GoldBright
							elseif p == "fail" then
								return Theme.Colors.DangerHover
							end
							return Theme.Colors.AccentHover
						end),
					}),
				},
			}),
		},
	})
	anvil = root:FindFirstChild("Anvil") :: Frame?
	return root
end

return Upgrade_
