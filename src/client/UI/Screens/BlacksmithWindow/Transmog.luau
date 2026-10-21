--!strict
-- Forge → Appearance (S154, docs/DESIGN.md §6b): pick a weapon or an off-hand (drag it onto the anvil or click it in
-- the list: backpack and equipped items that Logic/Transmog.supports), pick a look of its type from the account's
-- collection in the iron showcase (the item's own look first, the worn look framed in brass, boss looks marked ♛,
-- looks not yet owned dimmed with where to get them), see it turning in the preview with the item's rarity colour and
-- the cost (owned / needed). "Apply look" asks first; "Restore own" is free. Everything is checked again by the server
-- (TransmogApply); stats never change.
-- 2026-10-21 (owner: too many detailed descriptions): the note under the buttons is one short line, the full note
-- (smith.transmog.note) behind its "i".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Parent.Device)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Parent.Components.InfoTip)
local ItemIcon = require(script.Parent.Parent.Parent.Components.ItemIcon)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Picker = require(script.Parent.Picker)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local TransmogLogic = require(ReplicatedStorage.Shared.Logic.Transmog)
local Types = require(ReplicatedStorage.Shared.Types)
local WeaponBuild = require(ReplicatedStorage.Shared.Util.WeaponBuild)
local WeaponLooks = require(ReplicatedStorage.Shared.Data.WeaponLooks)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Target: Fusion.Value<Picker.Target?>,
	ShowModal: (spec: any) -> (),
}

local LIST_WIDTH = 262
local TILE_W, TILE_H = 96, 116
local PREVIEW_HEIGHT = 210
local TENSION = 0.6
local OWN = "" -- the "Own look" tile (taking the worn look off)
local GOOD = Theme.hex(Theme.Paper.Success)
local BAD = Theme.hex(Theme.Paper.Danger)

local function label(
	scope: Scope,
	order: number,
	text: Fusion.UsedAs<string>,
	color: Fusion.UsedAs<Color3>?,
	size: number?
): Instance
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

-- The boss whose item gives a boss look, as a localized name ("" when unknown).
local function bossName(use: Fusion.Use, key: string): string
	local def = TransmogLogic.lookDef(key)
	local boss = def and def.bossId and Bosses.get(def.bossId)
	return if boss then Text.get(use, boss.nameKey) else ""
end

-- The look name (the item the look comes from; a boss look: the full name of the boss item).
local function lookName(use: Fusion.Use, key: string): string
	local def = TransmogLogic.lookDef(key)
	return if def then ItemText.get(use, def.id) else key
end

-- A held model of `def` on an invisible anchor (the hand or the back of WeaponLooks), for a ViewportFrame; the focus
-- point and the orbit distance.
local function buildPreview(def: Items.ItemDef, accent: Color3): (Model?, Vector3, number)
	local look = WeaponLooks.get(def.type)
	if not look then
		return nil, Vector3.zero, 6
	end
	local holder = Instance.new("Model")
	holder.Name = "TransmogPreview"
	local anchor = Instance.new("Part")
	anchor.Name = if look.hand == "back" then "UpperTorso" elseif look.hand == "left" then "LeftHand" else "RightHand"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CFrame = CFrame.identity
	anchor.Parent = holder
	local held = WeaponBuild.attach(holder, def.type, accent, "VaelthornPreview", def)
	if not held then
		holder:Destroy()
		return nil, Vector3.zero, 6
	end
	-- the bounds of the weapon alone (the anchor is a point at the origin)
	anchor.Parent = nil
	local frame, size = holder:GetBoundingBox()
	anchor.Parent = holder
	return holder, frame.Position, math.max(3, size.Magnitude * 1.15)
end

-- 2026-10-21 (owner: too many detailed descriptions): a short line with an "i" right after it holding the longer text
-- (Components/InfoTip); the row hides while the line is empty.
local function infoLine(
	scope: Scope,
	order: number,
	text: Fusion.UsedAs<string>,
	info: Fusion.UsedAs<string>,
	color: Color3?
): Instance
	return scope:New("Frame")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = scope:Computed(function(use): boolean
			return use(text) ~= ""
		end),
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Size = UDim2.new(),
				AutomaticSize = Enum.AutomaticSize.XY,
				RichText = true,
				TextWrapped = true,
				Text = text,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = color or Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				[Children] = scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink }),
			}),
			InfoTip.new(scope, { Text = info, LayoutOrder = 2 }),
		},
	})
end

local function Transmog(scope: Scope, props: Props): Instance
	local inventory = State.Value({ "character", "inventory" })
	local equipment = State.Value({ "character", "equipment" })
	local gold = State.Value({ "character", "gold" })
	local collection = State.Value({ "account", "transmog" })
	local picked = scope:Value(nil :: string?) -- the clicked tile (OWN = the own look), nil = the worn one
	local busy = scope:Value(false)
	local anvil: Instance? = nil

	scope:Observer(props.Target):onChange(function()
		picked:set(nil)
	end)

	local item = scope:Computed(function(use): Types.ItemInstance?
		return Picker.resolve(use(props.Target), use(inventory), use(equipment))
	end)
	local itemDef = scope:Computed(function(use): Items.ItemDef?
		local i = use(item)
		return if i then Items.get(i.id) else nil
	end)
	local looks = scope:Computed(function(use): { [string]: boolean }
		return TransmogLogic.sanitize(use(collection)).looks
	end)
	-- Why the item has no looks at all (nil: it has, or no item).
	local refusal = scope:Computed(function(use): string?
		local d = use(itemDef)
		if not d then
			return nil
		end
		return if TransmogLogic.supports(d) then nil else "transmog.error.type"
	end)
	-- The worn look (OWN when none) and the shown one (the clicked tile, else the worn one).
	local worn = scope:Computed(function(use): string
		local i = use(item)
		return if i then TransmogLogic.current(i) or OWN else OWN
	end)
	local shown = scope:Computed(function(use): string
		local p = use(picked)
		return if p ~= nil then p else use(worn)
	end)
	-- The look key of the item's own definition (its tile is the "Own look" one).
	local ownKey = scope:Computed(function(use): string?
		local d = use(itemDef)
		return if d and TransmogLogic.supports(d) then TransmogLogic.lookOf(d) else nil
	end)
	local cost = scope:Computed(function(use): TransmogLogic.Cost?
		local i = use(item)
		if not i or use(refusal) ~= nil then
			return nil
		end
		return TransmogLogic.cost(i)
	end)
	-- Why "Apply look" is off: no look picked, the own / worn look, a look not owned, the gold, the materials.
	local blocker = scope:Computed(function(use): string?
		local i, c = use(item), use(cost)
		if not i or not c then
			return nil
		end
		local key = use(shown)
		if key == OWN or key == use(worn) then
			return "smith.transmog.pickLook"
		end
		local ok, err = TransmogLogic.canApply(i, key, use(looks))
		if not ok then
			return err
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

	local function send(look: string)
		local target, current = Fusion.peek(props.Target), Fusion.peek(item)
		if not target or not current or Fusion.peek(busy) then
			return
		end
		busy:set(true)
		Picker.sparks(anvil, TENSION)
		local startedAt = os.clock()
		task.spawn(function()
			local ok, err = Net.Invoke("TransmogApply", target.location, target.key, look, current.uid)
			local wait = TENSION - (os.clock() - startedAt)
			if wait > 0 then
				task.wait(wait)
			end
			busy:set(false)
			if not ok then
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
				return
			end
			Sounds.play("levelUp")
			picked:set(nil)
			if look == OWN then
				Toast.push(Text.now("smith.transmog.restored"), "success")
			else
				local def = TransmogLogic.lookDef(look)
				Toast.push(
					Text.now("smith.transmog.done", { name = if def then ItemText.name(def.id) else look }),
					"success"
				)
			end
		end)
	end

	local function confirm()
		local i, key = Fusion.peek(item), Fusion.peek(shown)
		if not i or Fusion.peek(blocker) ~= nil or Fusion.peek(busy) then
			return
		end
		local def = TransmogLogic.lookDef(key)
		props.ShowModal({
			Title = Text.now("smith.transmog.confirmTitle"),
			Message = Text.now("smith.transmog.confirm", {
				name = `<b>{if def then ItemText.name(def.id) else key}</b>`,
				item = `<b>{ItemText.name(i.id, i.up, ItemRoll.elementOf(i))}</b>`,
			}),
			ConfirmText = Text.now("smith.transmog.apply"),
			CancelText = Text.now("common.cancel"),
			OnConfirm = function(): (boolean, string?)
				send(key)
				return true, nil
			end,
		})
	end

	local candidates = Picker.list(scope, {
		Prefix = "tm",
		Target = props.Target,
		Inventory = inventory,
		Equipment = equipment,
		Filter = function(candidate: Types.ItemInstance): boolean
			return TransmogLogic.supports(Items.get(candidate.id))
		end,
		OnPick = function()
			picked:set(nil)
		end,
	})

	-- One tile of the showcase: the look's icon and name, ♛ for a boss look, 🔒 and dimmed while not owned, the brass
	-- frame on the worn look, the selected background on the shown one.
	local function tile(s: Scope, order: number, key: string, def: Items.ItemDef?, owned: boolean, boss: boolean)
		return s:New("TextButton")({
			Name = if key == OWN then "Own" else key,
			LayoutOrder = order,
			AutoButtonColor = false,
			BackgroundColor3 = s:Computed(function(use): Color3
				return if use(shown) == key then Theme.Iron.Selected else Theme.Iron.Raised
			end),
			Text = "",
			[OnEvent("Activated")] = function()
				if Fusion.peek(busy) then
					return
				end
				Sounds.play("click")
				picked:set(key)
			end,
			[Children] = {
				s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				s:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = s:Computed(function(use): number
						return if use(worn) == key then Theme.Stroke.Normal + 1 else Theme.Stroke.Thin
					end),
					Color = s:Computed(function(use): Color3
						return if use(worn) == key then Theme.Brass.Bright else Theme.Iron.Border
					end),
				}),
				ItemIcon(s, {
					Def = def,
					Element = s:Computed(function(use): string?
						local i = use(item)
						return if i then ItemRoll.elementOf(i) else nil
					end),
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 6),
					Size = UDim2.fromOffset(52, 52),
					Transparency = if owned then 0 else 0.6,
				}),
				s:New("TextLabel")({
					Name = "Name",
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -4),
					Size = UDim2.new(1, -6, 0, 50),
					BackgroundTransparency = 1,
					Text = s:Computed(function(use): string
						if key == OWN then
							return Text.get(use, "smith.transmog.own")
						end
						return lookName(use, key)
					end),
					TextWrapped = true,
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = if owned then Theme.Iron.Text else Theme.Iron.TextMuted,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
				-- ♛ a boss look (rare)
				s:New("TextLabel")({
					Name = "Boss",
					Position = UDim2.fromOffset(3, 3),
					Size = UDim2.fromOffset(20, 20),
					BackgroundColor3 = Theme.Iron.Surface,
					Visible = boss,
					Text = "♛",
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Caption,
					TextColor3 = Theme.Brass.Bright,
					[Children] = s:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
				}),
				s:New("TextLabel")({
					Name = "Locked",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -3, 0, 3),
					Size = UDim2.fromOffset(18, 18),
					BackgroundTransparency = 1,
					Visible = not owned,
					Text = "🔒",
					TextScaled = true,
					FontFace = Theme.Fonts.BodyBold,
					TextColor3 = Theme.Iron.TextMuted,
				}),
			},
		})
	end

	local tiles = scope:Computed(function(use, s: Scope): { Instance }
		local d = use(itemDef)
		local out: { Instance } = {}
		if not d or use(refusal) ~= nil then
			return out
		end
		local own = use(ownKey)
		local owned = use(looks)
		table.insert(out, tile(s, 1, OWN, d, true, false))
		for order, key in TransmogLogic.looksOf(d.type) do
			if key ~= own then
				local boss = TransmogLogic.isBoss(key)
				table.insert(out, tile(s, order + 1, key, TransmogLogic.lookDef(key), owned[key] == true, boss))
			end
		end
		return out
	end)

	local headText = scope:Computed(function(use): string
		local d = use(itemDef)
		if not d or use(refusal) ~= nil then
			return ""
		end
		local n, all = TransmogLogic.count(d.type, use(looks))
		return Text.get(
			use,
			"smith.transmog.collection",
			{ type = Text.get(use, `itemBase.{d.type}`), n = n, all = all }
		)
	end)

	-- Under the showcase: the shown look's name, "From a boss: X" for a boss look, where to get a look not owned.
	local shownText = scope:Computed(function(use): string
		local i = use(item)
		if not i or use(refusal) ~= nil then
			return ""
		end
		local key = use(shown)
		if key == OWN then
			return Text.get(
				use,
				"smith.transmog.ownLine",
				{ name = ItemText.get(use, i.id, i.up, ItemRoll.elementOf(i)) }
			)
		end
		local parts = { `<b>{lookName(use, key)}</b>` }
		if TransmogLogic.isBoss(key) then
			table.insert(parts, Text.get(use, "smith.transmog.fromBoss", { boss = bossName(use, key) }))
		end
		if use(looks)[key] ~= true then
			table.insert(
				parts,
				if TransmogLogic.isBoss(key)
					then Text.get(use, "smith.transmog.lockedBoss", { boss = bossName(use, key) })
					else Text.get(use, "smith.transmog.lockedHint")
			)
		end
		return table.concat(parts, " · ")
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
		return `{Text.get(use, "smith.upgrade.cost")}: {table.concat(parts, "  ")} · {Text.get(
			use,
			"smith.transmog.free"
		)}`
	end)

	-- Preview ---------------------------------------------------------------------------------------------------
	local viewport = scope:New("ViewportFrame")({
		Name = "Preview",
		LayoutOrder = 7,
		Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT),
		BackgroundColor3 = Theme.Paper.Sunken,
		Ambient = Color3.fromRGB(160, 150, 140),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1, -1),
		Visible = scope:Computed(function(use): boolean
			return use(item) ~= nil and use(refusal) == nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Paper.Rule }),
		},
	}) :: ViewportFrame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	table.insert(scope, camera)
	local model: Model? = nil
	local focus, orbit = Vector3.zero, 6
	local function rebuild()
		if model then
			model:Destroy()
			model = nil
		end
		local i = Fusion.peek(item)
		if not i or Fusion.peek(refusal) ~= nil then
			return
		end
		local key = Fusion.peek(shown)
		local def = if key == OWN then Items.get(i.id) else TransmogLogic.lookDef(key)
		if not def then
			return
		end
		-- the item's rarity colour on the look (S154: the rarity is the item's, not the look's)
		local built, at, distance = buildPreview(def, Rarities.get(i.rarity).color)
		if built then
			built.Parent = viewport
			model = built
			focus, orbit = at, distance
		end
	end
	rebuild()
	scope:Observer(shown):onChange(rebuild)
	scope:Observer(item):onChange(rebuild)
	table.insert(scope, function()
		if model then
			model:Destroy()
		end
	end)
	local angle = 0
	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt: number)
			angle += dt * 0.7
			camera.CFrame =
				CFrame.new(focus + Vector3.new(math.sin(angle) * orbit, orbit * 0.25, math.cos(angle) * orbit), focus)
		end)
	)

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
			-- Drop target for dragged items
			scope:New("Frame")({
				Name = "Slot",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(84, 84),
				BackgroundTransparency = 1,
				[Children] = ItemSlot(scope, {
					SlotId = "smith:transmog",
					Size = 84,
					Item = item,
					Placeholder = "⚒",
					EmptyTooltip = Text.T(scope, "smith.transmog.pick"),
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
						return Text.get(use, "smith.transmog.pick")
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
					local why = use(refusal)
					return if why then Text.get(use, why) else ""
				end),
				Theme.Paper.Warning
			),
			label(scope, 4, headText, Theme.Paper.TextMuted),
			-- The showcase (iron): the looks of the item's type
			scope:New("Frame")({
				Name = "Showcase",
				LayoutOrder = 5,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Iron.Sunken,
				Visible = scope:Computed(function(use): boolean
					return use(item) ~= nil and use(refusal) == nil
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 8),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
					scope:New("UIGridLayout")({
						CellSize = UDim2.fromOffset(TILE_W, TILE_H),
						CellPadding = UDim2.fromOffset(6, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					tiles :: any,
				},
			}),
			label(scope, 6, shownText),
			viewport,
			label(scope, 8, costText),
			Button(scope, {
				LayoutOrder = 9,
				Size = UDim2.new(0.8, 0, 0, Theme.Size.ButtonHeight),
				Variant = "primary",
				Text = Text.T(scope, "smith.transmog.apply"),
				Visible = scope:Computed(function(use): boolean
					return use(item) ~= nil and use(refusal) == nil
				end),
				Disabled = scope:Computed(function(use): boolean
					return use(item) == nil or use(blocker) ~= nil or use(busy)
				end),
				OnClick = confirm,
			}),
			Button(scope, {
				LayoutOrder = 10,
				Size = UDim2.new(0.8, 0, 0, Theme.Size.ButtonHeightSmall + 4),
				Variant = "secondary",
				Text = Text.T(scope, "smith.transmog.restore"),
				Visible = scope:Computed(function(use): boolean
					return use(worn) ~= OWN
				end),
				Disabled = busy,
				OnClick = function()
					send(OWN)
				end,
			}),
			label(
				scope,
				11,
				scope:Computed(function(use): string
					local why = use(blocker)
					return if why then Text.get(use, why) else ""
				end),
				-- "Pick a look" is a hint, not an error
				scope:Computed(function(use): Color3
					return if use(blocker) == "smith.transmog.pickLook"
						then Theme.Paper.TextMuted
						else Theme.Paper.Danger
				end)
			),
			infoLine(
				scope,
				12,
				scope:Computed(function(use): string
					return if use(item) ~= nil and use(refusal) == nil
						then Text.get(use, "smith.transmog.note.short")
						else ""
				end),
				Text.T(scope, "smith.transmog.note"),
				Theme.Paper.TextMuted
			),
		},
	})
	anvil = details

	return scope:New("Frame")({
		Name = "Transmog",
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

return Transmog
