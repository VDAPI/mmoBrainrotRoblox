--!strict
-- Forge → Effect (S160k, owner 2026-10-21, docs/DESIGN.md §6a): "Change effect" of a Legendary or Mythic item. Pick an
-- item (drag it onto the anvil or click it in the list: items Logic/EffectReroll.eligible accepts), pick one of its
-- skill effects, see what it can become ("Possible results": every effect of the same tier from the drop pool, each
-- equally likely), the cost (gold, essence and a Stone of Effect Transmutation together, each owned / needed) and where
-- the stone comes from. "Change effect" asks first, plays the forge's tension and shows "old → new". Everything is
-- computed again by the server (RerollEffect); this only shows it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Parent.Device)
local EffectReroll = require(ReplicatedStorage.Shared.Logic.EffectReroll)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemEffects = require(ReplicatedStorage.Shared.Logic.ItemEffects)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Net = require(ReplicatedStorage.Shared.Net)
local Picker = require(script.Parent.Picker)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Target: Fusion.Value<Picker.Target?>,
	ShowModal: (spec: any) -> (),
}

local TENSION = 1.2
local LIST_WIDTH = 262
local GOOD = Theme.hex(Theme.Paper.Success)
local BAD = Theme.hex(Theme.Paper.Danger)

-- "Name: what it does" of an effect id in the current language.
local function effectText(lang: string, id: string): string
	local def = ItemEffects.resolve(id)
	if not def then
		return id
	end
	return `<b>{Text.now(def.nameKey)}</b>: {ItemEffects.line(def, lang)}`
end

local function label(scope: Scope, order: number, text: Fusion.UsedAs<string>, color: Color3?): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		RichText = true,
		TextWrapped = true,
		Text = text,
		FontFace = Theme.Fonts.BodyMedium,
		TextSize = Theme.TextSize.Small,
		TextColor3 = color or Theme.Paper.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function Effect(scope: Scope, props: Props): Instance
	local inventory = State.Value({ "character", "inventory" })
	local equipment = State.Value({ "character", "equipment" })
	local gold = State.Value({ "character", "gold" })
	local class = State.Value({ "character", "class" })
	local picked = scope:Value(nil :: number?)
	local phase = scope:Value("idle") -- idle | forging | done
	local result = scope:Value(nil :: { old: string, new: string }?)
	local anvil: Instance? = nil

	local function reset()
		picked:set(nil)
		phase:set("idle")
		result:set(nil)
	end
	scope:Observer(props.Target):onChange(reset)

	local item = scope:Computed(function(use): Types.ItemInstance?
		return Picker.resolve(use(props.Target), use(inventory), use(equipment))
	end)
	local refusal = scope:Computed(function(use): string?
		local i = use(item)
		if not i then
			return nil
		end
		local ok, err = EffectReroll.eligible(i)
		return if ok then nil else err or "smith.effect.error.none"
	end)
	local ready = scope:Computed(function(use): boolean
		return use(item) ~= nil and use(refusal) == nil
	end)
	-- The effect to change: the clicked one, or the only one.
	local index = scope:Computed(function(use): number?
		local i = use(item)
		if not i or not use(ready) then
			return nil
		end
		local at = use(picked)
		if at and EffectReroll.canIndex(i, at) then
			return at
		end
		local fx: any = i.fx
		return if type(fx) == "table" and #fx == 1 and EffectReroll.canIndex(i, 1) then 1 else nil
	end)
	local stones = scope:Computed(function(use): number
		return Picker.count(use(inventory), EffectReroll.STONE)
	end)
	local cost = scope:Computed(function(use): EffectReroll.Cost?
		local i = use(item)
		if not i or not use(ready) then
			return nil
		end
		return EffectReroll.payment(i)
	end)
	local outcomes = scope:Computed(function(use): { EffectReroll.Outcome }
		local i, at = use(item), use(index)
		if not i or not at then
			return {}
		end
		return EffectReroll.preview(i, at, use(class))
	end)
	local blocker = scope:Computed(function(use): string?
		local c = use(cost)
		if not c then
			return nil
		end
		if use(index) == nil then
			return "smith.effect.pickEffect"
		end
		if #use(outcomes) == 0 then
			return "smith.effect.error.empty"
		end
		if use(stones) < 1 then
			return "smith.effect.error.noStone"
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

	local function doChange()
		local target = Fusion.peek(props.Target)
		local current = Fusion.peek(item)
		local at = Fusion.peek(index)
		if not target or not current or not at or Fusion.peek(phase) == "forging" then
			return
		end
		local expected = (current.fx :: { string })[at]
		phase:set("forging")
		result:set(nil)
		Picker.sparks(anvil, TENSION)
		local startedAt = os.clock()
		task.spawn(function()
			local ok, err, data = Net.Invoke("RerollEffect", target.location, target.key, at, expected)
			local wait = TENSION - (os.clock() - startedAt)
			if wait > 0 then
				task.wait(wait)
			end
			if Fusion.peek(props.Target) ~= target then
				phase:set("idle")
				return
			end
			if not ok then
				phase:set("idle")
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
				return
			end
			Sounds.play("levelUp")
			result:set({ old = data.old, new = data.new })
			picked:set(at)
			phase:set("done")
		end)
	end

	local function confirm()
		local i, at, c = Fusion.peek(item), Fusion.peek(index), Fusion.peek(cost)
		if not i or not at or not c or Fusion.peek(blocker) ~= nil or Fusion.peek(phase) == "forging" then
			return
		end
		local lang = Fusion.peek(Text.Lang)
		local essence = c.materials[1]
		props.ShowModal({
			Title = Text.now("smith.effect.confirmTitle"),
			Message = Text.now("smith.effect.confirm", {
				effect = effectText(lang, (i.fx :: { string })[at]),
				gold = Format.number(c.gold),
				essence = if essence and essence.id ~= EffectReroll.STONE
					then `{ItemText.name(essence.id)} ×{essence.n}`
					else "-",
				stone = ItemText.name(EffectReroll.STONE),
			}),
			ConfirmText = Text.now("smith.effect.button"),
			CancelText = Text.now("common.cancel"),
			OnConfirm = function(): (boolean, string?)
				doChange()
				return true, nil
			end,
		})
	end

	local candidates = Picker.list(scope, {
		Prefix = "fx",
		Target = props.Target,
		Inventory = inventory,
		Equipment = equipment,
		Filter = function(candidate: Types.ItemInstance): boolean
			return (EffectReroll.eligible(candidate))
		end,
		OnPick = reset,
	})

	local effectRows = scope:Computed(function(use, s: Scope): { Instance }
		local i = use(item)
		local rows: { Instance } = {}
		if not i or not use(ready) then
			return rows
		end
		local lang = use(Text.Lang)
		local fx: { string } = if type(i.fx) == "table" then i.fx :: any else {}
		for at, id in fx do
			local canPick = (EffectReroll.canIndex(i, at))
			local def = ItemEffects.resolve(id)
			local tier = if def then Text.get(use, `smith.effect.tier.{def.tier}`) else ""
			table.insert(
				rows,
				s:New("TextButton")({
					LayoutOrder = at,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					AutoButtonColor = canPick,
					BackgroundColor3 = s:Computed(function(use2): Color3
						return if use2(index) == at then Theme.Paper.Hover else Theme.Paper.Raised
					end),
					Text = "",
					[OnEvent("Activated")] = function()
						if canPick and Fusion.peek(phase) ~= "forging" then
							Sounds.play("click")
							picked:set(at)
							phase:set("idle")
							result:set(nil)
						end
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
						s:New("UIPadding")({
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
							PaddingTop = UDim.new(0, 4),
							PaddingBottom = UDim.new(0, 4),
						}),
						s:New("TextLabel")({
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							RichText = true,
							TextWrapped = true,
							Text = `{effectText(lang, id)} <font color="{Theme.hex(Theme.Paper.TextMuted)}">({tier})</font>`,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
					},
				})
			)
		end
		return rows
	end)

	local outcomeRows = scope:Computed(function(use, s: Scope): { Instance }
		local rows: { Instance } = {}
		local lang = use(Text.Lang)
		for order, outcome in use(outcomes) do
			table.insert(
				rows,
				label(
					s,
					order,
					`{effectText(lang, outcome.id)}  <font color="{Theme.hex(Theme.Paper.Heading)}">{Text.get(
						use,
						"smith.reroll.chance",
						{ pct = math.floor(outcome.chance * 100 + 0.5) }
					)}</font>`
				)
			)
		end
		return rows
	end)

	local costText = scope:Computed(function(use): string
		local c = use(cost)
		if not c then
			return ""
		end
		local enoughGold = (use(gold) or 0) >= c.gold
		local parts = {
			`<font color="{if enoughGold then Theme.hex(Theme.Paper.Heading) else BAD}">◉ {Format.number(c.gold)}</font>`,
		}
		local inv = use(inventory)
		for _, material in c.materials do
			local have = Picker.count(inv, material.id)
			local color = if have >= material.n then GOOD else BAD
			table.insert(parts, `<font color="{color}">{ItemText.get(use, material.id)} {have}/{material.n}</font>`)
		end
		return `{Text.get(use, "smith.upgrade.cost")}: ` .. table.concat(parts, "  ")
	end)

	local touch = scope:Computed(function(use): boolean
		return use(Device.Touch)
	end)

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
			scope:New("Frame")({
				Name = "Slot",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(84, 84),
				BackgroundTransparency = 1,
				[Children] = ItemSlot(scope, {
					SlotId = "smith:effect",
					Size = 84,
					Item = item,
					Placeholder = "⚒",
					EmptyTooltip = Text.T(scope, "smith.effect.pick"),
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
						return Text.get(use, "smith.effect.pick")
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
						return Text.get(use, "smith.effect.intro")
					end
					local why = use(refusal)
					if why then
						return Text.get(use, why)
					end
					return if use(index) == nil then Text.get(use, "smith.effect.pickEffect") else ""
				end),
				Theme.Paper.Warning
			),
			scope:New("Frame")({
				Name = "Effects",
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
					effectRows :: any,
				},
			}),
			scope:New("Frame")({
				Name = "Outcomes",
				LayoutOrder = 5,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(index) ~= nil
				end),
				[Children] = {
					scope:New("UIListLayout")({ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
					label(scope, 1, Text.T(scope, "smith.reroll.outcomes"), Theme.Paper.TextMuted),
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
			label(scope, 6, costText),
			label(
				scope,
				7,
				scope:Computed(function(use): string
					if use(cost) == nil then
						return ""
					end
					return Text.get(use, "smith.effect.stoneHint", { count = use(stones) })
				end),
				Theme.Paper.TextMuted
			),
			Button(scope, {
				LayoutOrder = 8,
				Size = UDim2.new(0.8, 0, 0, Theme.Size.ButtonHeight),
				Variant = "primary",
				Text = scope:Computed(function(use): string
					return Text.get(use, if use(phase) == "done" then "smith.effect.again" else "smith.effect.button")
				end),
				Disabled = scope:Computed(function(use): boolean
					return use(item) == nil or use(blocker) ~= nil or use(phase) == "forging"
				end),
				OnClick = confirm,
			}),
			label(
				scope,
				9,
				scope:Computed(function(use): string
					local why = use(blocker)
					return if why and why ~= "smith.effect.pickEffect" then Text.get(use, why) else ""
				end),
				Theme.Paper.Danger
			),
			label(
				scope,
				10,
				scope:Computed(function(use): string
					local r = use(result)
					if not r then
						return ""
					end
					local lang = use(Text.Lang)
					return Text.get(use, "smith.reroll.result", {
						old = `<s>{effectText(lang, r.old)}</s>`,
						new = effectText(lang, r.new),
					})
				end),
				Theme.Paper.Heading
			),
		},
	})
	anvil = details

	return scope:New("Frame")({
		Name = "Effect",
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

return Effect
