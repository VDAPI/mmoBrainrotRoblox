--!strict
-- Forge → Transmute (S134j, docs/DESIGN.md §6a): pick an item (drag it onto the anvil or click it in the list —
-- backpack and equipped items that Logic/Reroll.eligible accepts), pick one random regular bonus line (after the
-- first reroll only the locked line, marked ↻; the rest locked), see what it can become ("Possible results": chance
-- and range from Logic/Reroll.preview, the same pure function the server rolls with), the cost (owned / needed, the
-- attempt number and the next attempt's gold) and an optional Stone of Transmutation. "Transmute" asks first (the
-- first reroll of an item also says the choice locks), plays the forge's tension and shows "old → new".
-- Everything is computed again by the server (RerollBonus); this only shows it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Parent.Device)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Net = require(ReplicatedStorage.Shared.Net)
local Picker = require(script.Parent.Picker)
local Reroll = require(ReplicatedStorage.Shared.Logic.Reroll)
local Bonuses = require(ReplicatedStorage.Shared.Data.Bonuses)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local StatGroups = require(ReplicatedStorage.Shared.Logic.StatGroups)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local TooltipModel = require(ReplicatedStorage.Shared.Logic.TooltipModel)
local Types = require(ReplicatedStorage.Shared.Types)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Target: Fusion.Value<Picker.Target?>,
	ShowModal: (spec: any) -> (),
}

type Result = { old: Types.Bonus, new: Types.Bonus, quality: number, item: Types.ItemInstance }

local TENSION = 1.2
local LIST_WIDTH = 262
local GOOD = Theme.hex(Theme.Paper.Success)
local BAD = Theme.hex(Theme.Paper.Danger)
-- Tooltip roles that are not lines (base stats, trait, skill effects): shown grey, "Cannot be transmuted".
local FIXED_ROLES =
	{ stat = true, speedDps = true, element = true, traitName = true, trait = true, fxTitle = true, fx = true }

-- The item's lines in the tooltip's group order: { at, id, v, quality } (ids after the legacy conversion).
local function linesOf(item: Types.ItemInstance): { ItemRoll.BonusLine }
	local lines = table.clone(ItemRoll.itemStats(item).bonuses)
	table.sort(lines, function(a: ItemRoll.BonusLine, b: ItemRoll.BonusLine): boolean
		local ra, rb = StatGroups.rank(a.id), StatGroups.rank(b.id)
		if ra ~= rb then
			return ra < rb
		end
		return (a.at or 0) < (b.at or 0)
	end)
	return lines
end

-- A line as the tab shows it (S134j fix): read through ItemRoll.itemStats like the line list and the tooltip, so a
-- two-handed weapon's x twoHandedBonusMul and the legacy id conversion apply to the confirm and the result too.
local function lineText(lang: string, item: Types.ItemInstance, stat: string, v: number): string
	local probe = table.clone(item)
	probe.bonuses = { { stat = stat, v = v } }
	local shown = ItemRoll.itemStats(probe).bonuses[1]
	return if shown then TooltipModel.bonusText(lang, shown.id, shown.v) else TooltipModel.bonusText(lang, stat, v)
end

local function pctText(use: Fusion.Use, chance: number): string
	if chance < 0.01 then
		return Text.get(use, "smith.reroll.chanceLow")
	end
	return Text.get(use, "smith.reroll.chance", { pct = math.floor(chance * 100 + 0.5) })
end

local function qualityBar(scope: Scope, quality: Fusion.UsedAs<number>, position: UDim2): Instance
	return scope:New("Frame")({
		Name = "Quality",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = position,
		Size = UDim2.fromOffset(46, 6),
		BackgroundColor3 = Theme.Paper.Sunken,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			scope:New("Frame")({
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromScale(math.clamp(use(quality), 0.05, 1), 1)
				end),
				BackgroundColor3 = scope:Computed(function(use): Color3
					local q = use(quality)
					return if q >= 0.9
						then Theme.Paper.Heading
						elseif q >= 0.5 then Theme.Paper.Success
						else Theme.Paper.TextMuted
				end),
				[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			}),
		},
	})
end

local function label(scope: Scope, order: number, text: Fusion.UsedAs<string>, color: Color3?, size: number?): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		RichText = true,
		TextWrapped = true,
		Text = text,
		FontFace = Theme.Fonts.BodyMedium,
		TextSize = size or Theme.TextSize.Small,
		TextColor3 = color or Theme.Paper.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function Reroll_(scope: Scope, props: Props): Instance
	local inventory = State.Value({ "character", "inventory" })
	local equipment = State.Value({ "character", "equipment" })
	local gold = State.Value({ "character", "gold" })
	local class = State.Value({ "character", "class" })
	local useStone = scope:Value(false)
	local picked = scope:Value(nil :: number?) -- clicked line (bonuses index) while the choice is open
	local phase = scope:Value("idle") -- idle | forging | done
	local result = scope:Value(nil :: Result?)
	local anvil: Instance? = nil

	local function reset()
		picked:set(nil)
		phase:set("idle")
		result:set(nil)
	end
	-- S134j fix: a new target (dropped on the anvil while this tab is open) starts clean: no line, no old result.
	scope:Observer(props.Target):onChange(reset)

	local item = scope:Computed(function(use): Types.ItemInstance?
		return Picker.resolve(use(props.Target), use(inventory), use(equipment))
	end)
	-- Why the item cannot be transmuted at all (nil: it can, or no item).
	local refusal = scope:Computed(function(use): string?
		local i = use(item)
		if not i then
			return nil
		end
		local ok, err = Reroll.eligible(i)
		return if ok then nil else err or "smith.reroll.error.noLines"
	end)
	local ready = scope:Computed(function(use): boolean
		return use(item) ~= nil and use(refusal) == nil
	end)
	-- The line to reroll: the locked one, else the clicked one when it still can be rerolled.
	local line = scope:Computed(function(use): number?
		local i = use(item)
		if not i or not use(ready) then
			return nil
		end
		local locked = Reroll.state(i).line
		if locked then
			return locked
		end
		local at = use(picked)
		return if at and Reroll.canLine(i, at) then at else nil
	end)
	local stones = scope:Computed(function(use): number
		return Picker.count(use(inventory), Reroll.STONE)
	end)
	local withStone = scope:Computed(function(use): boolean
		return use(useStone) and use(stones) > 0
	end)
	local cost = scope:Computed(function(use): Reroll.Cost?
		local i = use(item)
		if not i or not use(ready) then
			return nil
		end
		return if use(withStone) then Reroll.costWithStone(i) else Reroll.cost(i)
	end)
	-- Why "Transmute" is off (no modal then): the line, the gold, the materials.
	local blocker = scope:Computed(function(use): string?
		local i, c = use(item), use(cost)
		if not i or not c then
			return nil
		end
		if use(line) == nil then
			return "smith.reroll.pickLine"
		end
		if (use(gold) or 0) < c.gold then
			return "shop.error.gold"
		end
		local inv = use(inventory)
		for _, material in c.materials do
			if Picker.count(inv, material.id) < material.n then
				return "smith.missing"
			end
		end
		return nil
	end)

	local function doReroll()
		local target = Fusion.peek(props.Target)
		local current = Fusion.peek(item)
		local index = Fusion.peek(line)
		if not target or not current or not index or Fusion.peek(phase) == "forging" then
			return
		end
		local expected = current.bonuses[index].stat
		phase:set("forging")
		result:set(nil)
		Picker.sparks(anvil, TENSION)
		local startedAt = os.clock()
		task.spawn(function()
			local ok, err, data =
				Net.Invoke("RerollBonus", target.location, target.key, index, expected, Fusion.peek(withStone))
			local wait = TENSION - (os.clock() - startedAt)
			if wait > 0 then
				task.wait(wait)
			end
			if Fusion.peek(props.Target) ~= target then
				phase:set("idle") -- another item was picked meanwhile: its tab stays clean
				return
			end
			if not ok then
				phase:set("idle")
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
				return
			end
			Sounds.play("levelUp")
			local after = Fusion.peek(item) or current
			result:set({
				old = { stat = data.old.stat, v = data.old.v },
				new = { stat = data.new.stat, v = data.new.v },
				item = current,
				quality = ItemRoll.bonusQuality(data.new.stat, data.new.v, after.ilvl, after.rarity),
			})
			phase:set("done")
		end)
	end

	local function confirm()
		local i, index = Fusion.peek(item), Fusion.peek(line)
		if not i or not index or Fusion.peek(blocker) ~= nil or Fusion.peek(phase) == "forging" then
			return
		end
		local lang = Fusion.peek(Text.Lang)
		local bonus = i.bonuses[index]
		local message = Text.now("smith.reroll.confirm", { line = lineText(lang, i, bonus.stat, bonus.v) })
		if Reroll.state(i).line == nil then
			message ..= `\n\n<b>{Text.now("smith.reroll.confirmLock")}</b>`
		end
		props.ShowModal({
			Title = Text.now("smith.reroll.confirmTitle"),
			Message = message,
			ConfirmText = Text.now("smith.reroll.button"),
			CancelText = Text.now("common.cancel"),
			OnConfirm = function(): (boolean, string?)
				doReroll()
				return true, nil
			end,
		})
	end

	local candidates = Picker.list(scope, {
		Prefix = "rr",
		Target = props.Target,
		Inventory = inventory,
		Equipment = equipment,
		Filter = function(candidate: Types.ItemInstance): boolean
			return (Reroll.eligible(candidate))
		end,
		OnPick = reset,
	})

	-- The bonus lines: clickable while the choice is open, the locked line ↻, the rest 🔒.
	local lineRows = scope:Computed(function(use, s: Scope): { Instance }
		local i = use(item)
		local rows: { Instance } = {}
		if not i or not use(ready) then
			return rows
		end
		local lang = use(Text.Lang)
		local locked = Reroll.state(i).line
		for order, bonus in linesOf(i) do
			local at = bonus.at or 0
			local canPick = (Reroll.canLine(i, at))
			local mark = if locked == at then ` {TooltipModel.REROLL_MARK}` elseif not canPick then "  🔒" else ""
			table.insert(
				rows,
				s:New("TextButton")({
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 30),
					AutoButtonColor = canPick,
					BackgroundColor3 = s:Computed(function(use2): Color3
						return if use2(line) == at then Theme.Paper.Hover else Theme.Paper.Raised
					end),
					BackgroundTransparency = if canPick then 0 else 0.5,
					Text = "",
					[OnEvent("Activated")] = function()
						if canPick and locked == nil and Fusion.peek(phase) ~= "forging" then
							Sounds.play("click")
							picked:set(at)
							phase:set("idle")
							result:set(nil)
						end
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(8, 0),
							Size = UDim2.new(1, -70, 1, 0),
							BackgroundTransparency = 1,
							Text = TooltipModel.bonusText(lang, bonus.id, bonus.v) .. mark,
							TextTruncate = Enum.TextTruncate.AtEnd,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if canPick then Theme.Paper.Text else Theme.Paper.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						qualityBar(s, bonus.quality, UDim2.new(1, -8, 0.5, 0)),
					},
				})
			)
		end
		return rows
	end)

	-- Base stats, the trait and the skill effects: grey, never transmuted.
	local fixedText = scope:Computed(function(use): string
		local i = use(item)
		if not i or not use(ready) then
			return ""
		end
		local lang = use(Text.Lang)
		local parts: { string } = {}
		for _, entry in TooltipModel.build(i, nil, { lang = lang, hints = false }).lines do
			if FIXED_ROLES[entry.role] then
				table.insert(parts, TooltipModel.plain(entry.text))
			end
		end
		if #parts == 0 then
			return ""
		end
		return `<b>{Text.get(use, "smith.reroll.notRerollable")}</b>\n` .. table.concat(parts, "\n")
	end)

	-- "Possible results" of the line (chance, range); the current stat highlighted.
	local outcomeRows = scope:Computed(function(use, s: Scope): { Instance }
		local i, index = use(item), use(line)
		local rows: { Instance } = {}
		if not i or not index then
			return rows
		end
		local lang = use(Text.Lang)
		local current = i.bonuses[index].stat
		local currentDef = Bonuses.get(current)
		for order, outcome in Reroll.preview(i, index, use(class)) do
			local mine = outcome.stat == current or (currentDef ~= nil and currentDef.param == outcome.stat)
			table.insert(
				rows,
				s:New("Frame")({
					LayoutOrder = order,
					Size = UDim2.new(1, -8, 0, 24),
					BackgroundTransparency = if mine then 0.4 else 1,
					BackgroundColor3 = Theme.Paper.Rule,
					[Children] = {
						s:New("TextLabel")({
							Position = UDim2.fromOffset(6, 0),
							Size = UDim2.new(1, -70, 1, 0),
							BackgroundTransparency = 1,
							Text = TooltipModel.rangeText(lang, outcome.stat, outcome.min, outcome.max),
							TextTruncate = Enum.TextTruncate.AtEnd,
							FontFace = if mine then Theme.Fonts.BodyBold else Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						s:New("TextLabel")({
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -6, 0, 0),
							Size = UDim2.new(0, 60, 1, 0),
							BackgroundTransparency = 1,
							Text = pctText(use, outcome.chance),
							FontFace = Theme.Fonts.BodyMedium,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.Heading,
							TextXAlignment = Enum.TextXAlignment.Right,
						}),
					},
				})
			)
		end
		return rows
	end)

	local costText = scope:Computed(function(use): string
		local c, i = use(cost), use(item)
		if not c or not i then
			return ""
		end
		local enoughGold = (use(gold) or 0) >= c.gold
		local parts = {
			`<font color="{if enoughGold then Theme.hex(Theme.Paper.Heading) else BAD}">◉ {Format.number(c.gold)}</font>`,
		}
		local inv = use(inventory)
		if use(withStone) then
			-- the stone pays the essence: the essence of the attempt struck through
			for _, material in Reroll.cost(i).materials do
				table.insert(parts, `<s>{ItemText.get(use, material.id)} {material.n}</s>`)
			end
			table.insert(parts, `<font color="{GOOD}">{ItemText.get(use, Reroll.STONE)} 1/{use(stones)}</font>`)
		else
			for _, material in c.materials do
				local have = Picker.count(inv, material.id)
				local color = if have >= material.n then GOOD else BAD
				table.insert(parts, `<font color="{color}">{ItemText.get(use, material.id)} {have}/{material.n}</font>`)
			end
		end
		return `{Text.get(use, "smith.upgrade.cost")}: ` .. table.concat(parts, "  ")
	end)
	local countText = scope:Computed(function(use): string
		local i = use(item)
		if not i or not use(ready) then
			return ""
		end
		local n = Reroll.state(i).n
		local nextGold = Reroll.costAt(i, n + 1).gold
		return `{Text.get(use, "smith.reroll.count", { n = n + 1 })} · {Text.get(
			use,
			"smith.reroll.next",
			{ gold = `◉ {Format.number(nextGold)}` }
		)}`
	end)
	local resultText = scope:Computed(function(use): string
		local r = use(result)
		if not r then
			return ""
		end
		local lang = use(Text.Lang)
		return Text.get(use, "smith.reroll.result", {
			old = `<s>{lineText(lang, r.item, r.old.stat, r.old.v)}</s>`,
			new = `<b>{lineText(lang, r.item, r.new.stat, r.new.v)}</b>`,
		})
	end)

	local touch = scope:Computed(function(use): boolean
		return use(Device.Touch)
	end)

	local function section(order: number, key: string): Instance
		return label(scope, order, Text.T(scope, key), Theme.Paper.TextMuted)
	end

	local details = scope:New("ScrollingFrame")({
		Name = "Anvil",
		Position = scope:Computed(function(use): UDim2
			return if use(touch) then UDim2.fromOffset(0, 136) else UDim2.fromOffset(LIST_WIDTH + 18, 0)
		end),
		Size = scope:Computed(function(use): UDim2
			return if use(touch) then UDim2.new(1, 0, 1, -136) else UDim2.new(1, -(LIST_WIDTH + 18), 1, 0)
		end),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Paper.Surface,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Rule,
		ClipsDescendants = true,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			-- Drop target for dragged items
			scope:New("Frame")({
				Name = "Slot",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(84, 84),
				BackgroundTransparency = 1,
				[Children] = ItemSlot(scope, {
					SlotId = "smith:reroll",
					Size = 84,
					Item = item,
					Placeholder = "⚒",
					EmptyTooltip = Text.T(scope, "smith.reroll.pick"),
				}),
			}),
			scope:New("TextLabel")({
				Name = "Name",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local i = use(item)
					if not i then
						return Text.get(use, "smith.reroll.pick")
					end
					return ItemText.get(use, i.id, i.up, ItemRoll.elementOf(i))
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = scope:Computed(function(use): Color3
					local i = use(item)
					return if i then ItemText.rarityName(i.rarity, "paper") else Theme.Paper.TextMuted
				end),
			}),
			label(
				scope,
				3,
				scope:Computed(function(use): string
					local i = use(item)
					if not i then
						return ""
					end
					local why = use(refusal)
					if why then
						return Text.get(use, why)
					end
					return if use(line) == nil then Text.get(use, "smith.reroll.pickLine") else ""
				end),
				Theme.Paper.Warning
			),
			-- Lines
			scope:New("Frame")({
				Name = "Lines",
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
					-- S134j fix: the ↻ mark's legend ("Transmuted line") once the choice is locked
					scope:New("TextLabel")({
						LayoutOrder = 0,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 18),
						Visible = scope:Computed(function(use): boolean
							local i = use(item)
							return i ~= nil and use(ready) and Reroll.state(i).line ~= nil
						end),
						Text = scope:Computed(function(use): string
							return `{TooltipModel.REROLL_MARK} {Text.get(use, "smith.reroll.lineLocked")}`
						end),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					lineRows :: any,
				},
			}),
			label(scope, 5, fixedText, Theme.Paper.TextMuted),
			-- Possible results
			scope:New("Frame")({
				Name = "Outcomes",
				LayoutOrder = 6,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(line) ~= nil
				end),
				[Children] = {
					scope:New("UIListLayout")({ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
					section(1, "smith.reroll.outcomes"),
					scope:New("ScrollingFrame")({
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 150),
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 5,
						ScrollBarImageColor3 = Theme.Paper.Rule,
						[Children] = {
							scope:New("UIListLayout")({
								Padding = UDim.new(0, 2),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							outcomeRows :: any,
						},
					}),
				},
			}),
			label(scope, 7, costText),
			label(scope, 8, countText, Theme.Paper.TextMuted),
			-- Stone of Transmutation (only when the player has one)
			scope:New("TextButton")({
				Name = "Stone",
				LayoutOrder = 9,
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(stones) > 0 and use(cost) ~= nil
				end),
				Text = scope:Computed(function(use): string
					local mark = if use(useStone) then "☑" else "☐"
					return `{mark}  {Text.get(use, "smith.reroll.stone", { count = use(stones) })}`
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				[OnEvent("Activated")] = function()
					Sounds.play("click")
					useStone:set(not Fusion.peek(useStone))
				end,
			}),
			Button(scope, {
				LayoutOrder = 10,
				Size = UDim2.new(0.8, 0, 0, Theme.Size.ButtonHeight),
				Variant = "primary",
				Text = scope:Computed(function(use): string
					return Text.get(use, if use(phase) == "done" then "smith.reroll.again" else "smith.reroll.button")
				end),
				Disabled = scope:Computed(function(use): boolean
					return use(item) == nil or use(blocker) ~= nil or use(phase) == "forging"
				end),
				OnClick = confirm,
			}),
			label(
				scope,
				11,
				scope:Computed(function(use): string
					local why = use(blocker)
					return if why and why ~= "smith.reroll.pickLine" then Text.get(use, why) else ""
				end),
				Theme.Paper.Danger
			),
			-- Result: old (struck through) → new, with the new line's quality
			scope:New("Frame")({
				Name = "Result",
				LayoutOrder = 12,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(result) ~= nil
				end),
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.new(1, -56, 1, 0),
						BackgroundTransparency = 1,
						RichText = true,
						TextWrapped = true,
						Text = resultText,
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Paper.Heading,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					qualityBar(
						scope,
						scope:Computed(function(use): number
							local r = use(result)
							return if r then r.quality else 0
						end),
						UDim2.fromScale(1, 0.5)
					),
				},
			}),
		},
	})
	anvil = details

	return scope:New("Frame")({
		Name = "Reroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("TextLabel")({
				Size = UDim2.fromOffset(LIST_WIDTH, 24),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "smith.upgrade.items"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			-- Items (a strip on top on a phone, a column on the left on PC)
			scope:New("ScrollingFrame")({
				Position = UDim2.fromOffset(0, 28),
				Size = scope:Computed(function(use): UDim2
					return if use(touch) then UDim2.new(1, 0, 0, 100) else UDim2.new(0, LIST_WIDTH, 1, -28)
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
			details,
		},
	})
end

return Reroll_
