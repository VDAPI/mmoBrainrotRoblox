--!strict
-- Forge → Upgrading (DESIGN §6): pick an item (drag it onto the anvil slot or click it in the list — backpack
-- and equipped items), see +N → +N+1 with stat comparison, the success chance in a big coloured number, the
-- cost (owned / needed) and an optional Scroll of Protection. "Upgrade" plays ~1.5 s of tension (sparks,
-- rising sound) and then the result: golden burst and the new +N, or a red crack and the drop.
-- Owner 2026-11-10 (UI plan L10, "niektóre rzeczy zasłaniają inne"): on a phone "Ulepsz" covered the Scroll of
-- Protection's line. The parts now stand where Logic/GearLayout.smithUpgrade puts them, from the view's measured size:
-- the anvil panel with the item, a scrolling middle (name, comparison, chance and cost, the scroll) and the result,
-- and the button under the panel; a phone puts the item next to the middle. Review 2026-11-10: the size comes without
-- the window's opening motion (UI/ViewSize), and the Scroll of Protection's toggle is 44 high on touch (UI-ZASADY).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Parent.Device)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GearLayout = require(ReplicatedStorage.Shared.Logic.GearLayout)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Net = require(ReplicatedStorage.Shared.Net)
local Picker = require(script.Parent.Picker)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Stats = require(ReplicatedStorage.Shared.Data.Stats)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)
local Upgrade = require(ReplicatedStorage.Shared.Logic.Upgrade)
local ViewSize = require(script.Parent.Parent.Parent.ViewSize)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Target = Picker.Target

export type Props = {
	Target: Fusion.Value<Target?>,
}

local TENSION = 1.5
-- the view's size on PC (860 x 660 under the window's tabs) until it is measured
local AREA_PC = { w = 816, h = 512 }

local count = Picker.count
local resolve = Picker.resolve

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
	for _, key in keys do
		local stat, isPct = ItemRoll.baseKey(key)
		local def = Stats.get(aliases[stat] or stat)
		local name = Text.get(use, `stat.{aliases[stat] or stat}`)
		local value = stats.base[key]
		local text = if value % 1 == 0 then tostring(value) else string.format("%.1f", value)
		if isPct or (def and def.format == "pct") then
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
	local flashColor = scope:Value(Theme.Paper.Surface)
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
		Picker.sparks(anvil, TENSION)
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
				flashColor:set(Theme.Paper.Heading)
				Sounds.play("levelUp")
				resultText:set(Text.now("smith.upgrade.success", { name = ItemText.name(current.id, result.to) }))
			elseif result.protected then
				phase:set("saved")
				flashColor:set(Theme.Paper.Link)
				Sounds.play("error")
				resultText:set(Text.now("smith.upgrade.saved"))
			else
				phase:set("fail")
				flashColor:set(Theme.Paper.Danger)
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

	-- Items that can be upgraded: equipped first, then the backpack (S134j: Picker, shared with Transmute).
	local candidates = Picker.list(scope, {
		Prefix = "up",
		Target = props.Target,
		Inventory = inventory,
		Equipment = equipment,
		Filter = function()
			return true
		end,
		OnPick = function()
			phase:set("idle")
			resultText:set("")
		end,
	})

	local chance = scope:Computed(function(use): number
		local i = use(item)
		return if i and Upgrade.canUpgrade(i) then Upgrade.chance(i.up + 1) else 0
	end)

	-- the parts' rects (GearLayout.smithUpgrade) from the view's own size
	local view = ViewSize.new(scope)
	local layout = scope:Computed(function(use): GearLayout.SmithUpgrade
		return GearLayout.smithUpgrade(use(view.size) or AREA_PC)
	end)
	local function at(pick: (GearLayout.SmithUpgrade) -> GearLayout.Rect): Fusion.Computed<UDim2>
		return scope:Computed(function(use): UDim2
			local r = pick(use(layout))
			return UDim2.fromOffset(r.left, r.top)
		end)
	end
	local function sized(pick: (GearLayout.SmithUpgrade) -> GearLayout.Rect): Fusion.Computed<UDim2>
		return scope:Computed(function(use): UDim2
			local r = pick(use(layout))
			return UDim2.fromOffset(r.right - r.left, r.bottom - r.top)
		end)
	end
	local function listRect(l: GearLayout.SmithUpgrade): GearLayout.Rect
		return l.list
	end
	local function anvilRect(l: GearLayout.SmithUpgrade): GearLayout.Rect
		return l.anvil
	end
	local function slotRect(l: GearLayout.SmithUpgrade): GearLayout.Rect
		return l.slot
	end
	local function middleRect(l: GearLayout.SmithUpgrade): GearLayout.Rect
		return l.middle
	end
	local function resultRect(l: GearLayout.SmithUpgrade): GearLayout.Rect
		return l.result
	end
	local function buttonRect(l: GearLayout.SmithUpgrade): GearLayout.Rect
		return l.button
	end
	local listSize = sized(listRect)

	local root = scope:New("Frame")({
		Name = "Upgrade",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			view.ruler,
			-- Left: items
			scope:New("TextLabel")({
				Position = at(listRect),
				Size = UDim2.fromOffset(260, 24),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "smith.upgrade.items"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("ScrollingFrame")({
				Position = UDim2.fromOffset(0, 28),
				Size = scope:Computed(function(use): UDim2
					local size: UDim2 = use(listSize)
					return UDim2.fromOffset(size.X.Offset, size.Y.Offset - 28)
				end),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Paper.Rule,
				[Children] = {
					scope:New("UIGridLayout")({
						CellSize = UDim2.fromOffset(56, 56),
						CellPadding = UDim2.fromOffset(6, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					candidates :: any,
				},
			}),
			-- Right: the anvil panel (it flashes with the result and holds the sparks)
			scope:New("Frame")({
				Name = "Anvil",
				Position = at(anvilRect),
				Size = sized(anvilRect),
				BackgroundColor3 = flashColor,
				BackgroundTransparency = scope:Computed(function(use): number
					return 0.6 + use(animatedFlash) * 0.4
				end),
				ClipsDescendants = true,
				[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			}),
			-- Drop target for dragged items
			scope:New("Frame")({
				Name = "Slot",
				Position = at(slotRect),
				Size = sized(slotRect),
				BackgroundTransparency = 1,
				ZIndex = 2,
				[Children] = ItemSlot(scope, {
					SlotId = "smith:upgrade",
					Size = GearLayout.SMITH.slot,
					Item = item,
					Placeholder = "⚒",
					EmptyTooltip = Text.T(scope, "smith.upgrade.pick"),
				}),
			}),
			-- the name, the comparison, the chance and the cost, the Scroll of Protection: scrolling
			scope:New("ScrollingFrame")({
				Name = "Middle",
				Position = at(middleRect),
				Size = sized(middleRect),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Paper.Rule,
				ZIndex = 2,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
					scope:New("TextLabel")({
						Name = "Name",
						LayoutOrder = 1,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local i = use(item)
							if not i then
								return Text.get(use, "smith.upgrade.pick")
							end
							return ItemText.get(use, i.id, i.up)
						end),
						TextWrapped = true,
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Large,
						TextColor3 = scope:Computed(function(use): Color3
							local i = use(item)
							return if i then ItemText.rarityName(i.rarity, "paper") else Theme.Paper.TextMuted
						end),
					}),
					-- Stats now / after
					scope:New("TextLabel")({
						Name = "Compare",
						LayoutOrder = 2,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
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
								table.insert(
									lines,
									`{line}  <font color="{Theme.hex(Theme.Paper.Success)}">→ {after[index] or ""}</font>`
								)
							end
							return table.concat(lines, "\n")
						end),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
					-- Chance and cost
					scope:New("Frame")({
						Name = "Odds",
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 64),
						BackgroundTransparency = 1,
						Visible = scope:Computed(function(use): boolean
							return use(item) ~= nil
						end),
						[Children] = {
							scope:New("TextLabel")({
								Name = "Chance",
								Size = UDim2.fromScale(0.4, 1),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use): string
									return if use(item) then `{use(chance)}%` else ""
								end),
								FontFace = Theme.Fonts.Display,
								TextSize = Theme.TextSize.Hero,
								TextColor3 = scope:Computed(function(use): Color3
									local c = use(chance)
									if c >= 70 then
										return Theme.Paper.Success
									elseif c >= 40 then
										return Theme.Paper.Warning
									end
									return Theme.Paper.Danger
								end),
							}),
							scope:New("TextLabel")({
								Name = "Cost",
								Position = UDim2.new(0.4, 8, 0, 0),
								Size = UDim2.new(0.6, -8, 1, 0),
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
										`<font color="{if enoughGold
											then Theme.hex(Theme.Paper.Heading)
											else Theme.hex(Theme.Paper.Danger)}">◉ {Format.number(c.gold)}</font>`,
									}
									local inv = use(inventory)
									for _, material in c.materials do
										local have = count(inv, material.id)
										local color = if have >= material.n
											then Theme.hex(Theme.Paper.Success)
											else Theme.hex(Theme.Paper.Danger)
										table.insert(
											parts,
											`<font color="{color}">{ItemText.get(use, material.id)} {have}/{material.n}</font>`
										)
									end
									return `{Text.get(use, "smith.upgrade.cost")}: ` .. table.concat(parts, "  ")
								end),
								FontFace = Theme.Fonts.BodyMedium,
								TextSize = Theme.TextSize.Small,
								TextColor3 = Theme.Paper.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
						},
					}),
					-- Protection checkbox
					scope:New("TextButton")({
						Name = "Protect",
						LayoutOrder = 4,
						Size = scope:Computed(function(use): UDim2
							return UDim2.new(1, 0, 0, if use(Device.Touch) then Theme.Size.MinTouch else 36)
						end),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local mark = if use(protect) then "☑" else "☐"
							return `{mark}  {Text.get(
								use,
								"smith.upgrade.protect",
								{ count = count(use(inventory), "scroll_protection") }
							)}`
						end),
						TextWrapped = true,
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Paper.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						[OnEvent("Activated")] = function()
							Sounds.play("click")
							protect:set(not Fusion.peek(protect))
						end,
					}),
				},
			}),
			scope:New("TextLabel")({
				Name = "Result",
				Position = at(resultRect),
				Size = sized(resultRect),
				BackgroundTransparency = 1,
				ZIndex = 2,
				Text = resultText,
				TextWrapped = true,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = scope:Computed(function(use): Color3
					local p = use(phase)
					if p == "success" then
						return Theme.Paper.Heading
					elseif p == "fail" then
						return Theme.Paper.Danger
					end
					return Theme.Paper.Link
				end),
			}),
			-- "Ulepsz" under the anvil, in the footer
			Button(scope, {
				Position = at(buttonRect),
				Size = sized(buttonRect),
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
		},
	})
	view.watch(root)
	anvil = root:FindFirstChild("Anvil") :: Frame?
	return root
end

return Upgrade_
