--!strict
-- Mounts window (S97, docs/DESIGN-15.md §2): the owned mounts (level, speed, the active one), "To obtain" (boss and
-- quest mounts the character lacks; a premium one only while it is on sale), the details of the selected mount with a
-- rotating preview in the account's mount skin, choosing the active mount and the upgrade panel (character level,
-- gold, monster parts). "Upgrade" works only next to the stablemaster (`Near`); the server checks everything again.
-- Reads narrow state branches only (mounts, level, gold, inventory, the mount skin), never the whole character.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AreaProfileText = require(script.Parent.Parent.AreaProfileText)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Button = require(script.Parent.Parent.Components.Button)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local Inventory = require(ReplicatedStorage.Shared.Logic.Inventory)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local MountData = require(ReplicatedStorage.Shared.Data.Mounts)
local MountLook = require(ReplicatedStorage.Shared.Util.MountLook)
local Mounts = require(ReplicatedStorage.Shared.Logic.Mounts)
local Net = require(ReplicatedStorage.Shared.Net)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Near: Fusion.UsedAs<boolean>, -- next to the stablemaster (upgrades)
	OpenWardrobe: () -> (), -- the wardrobe on its mount skin tab
}

local LIST_WIDTH = 320
local ROW = 64
local PREVIEW = 210

local function invoke(name: string, arg: string)
	task.spawn(function()
		local ok, err = Net.Invoke(name, arg)
		if ok then
			Sounds.play("levelUp")
		else
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal", { level = Config.Mount.minLevel }), "error")
		end
	end)
end

-- Owned mounts sorted by level (highest first), then by id.
local function ownedList(state: any): { { id: string, lvl: number } }
	local out: { { id: string, lvl: number } } = {}
	if type(state) ~= "table" or type(state.owned) ~= "table" then
		return out
	end
	for id, entry in state.owned do
		if MountData.get(id) then
			table.insert(out, { id = id, lvl = math.clamp(tonumber(entry.lvl) or 1, 1, Config.Mount.maxLevel) })
		end
	end
	table.sort(out, function(a, b)
		if a.lvl ~= b.lvl then
			return a.lvl > b.lvl
		end
		return a.id < b.id
	end)
	return out
end

local function premiumOnSale(id: string): boolean
	for _, offer in Premium.mountOffers() do
		if offer.mount == id then
			return true
		end
	end
	return false
end

-- "Rare loot: Grimrok" / "The stablemaster's quest" / the premium shop.
local function sourceText(use: Fusion.Use, def: MountData.MountDef): string
	if def.source == "boss" and def.boss then
		local boss = Bosses.get(def.boss)
		return Text.get(use, "mount.source.boss", { boss = if boss then Text.get(use, boss.nameKey) else def.boss })
	elseif def.source == "quest" then
		return Text.get(use, "mount.source.quest")
	elseif def.source == "premium" then
		return Text.get(use, "premium.mounts.title")
	end
	return ""
end

local function swatch(s: Scope, def: MountData.MountDef, dim: boolean): Instance
	return s:New("Frame")({
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(ROW - 16, ROW - 16),
		BackgroundColor3 = Theme.tint(def.look.colors.base),
		BackgroundTransparency = if dim then 0.5 else 0,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIStroke")({ Color = Theme.tint(def.look.colors.accent), Thickness = Theme.Stroke.Thick }),
			s:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "♞",
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = Theme.readable(def.look.colors.accent, "paper"),
				TextStrokeTransparency = 0.4,
			}),
		},
	})
end

local function line(
	s: Scope,
	order: number,
	text: Fusion.UsedAs<string>,
	color: Fusion.UsedAs<Color3>?,
	size: number?
): Instance
	return s:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextWrapped = true,
		FontFace = Theme.Fonts.Body,
		TextSize = size or Theme.TextSize.Small,
		TextColor3 = color or Theme.Paper.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function MountWindow(scope: Scope, props: Props): Fusion.Child
	local mounts = State.Value({ "character", "mounts" })
	local level = State.Value({ "character", "level" })
	local gold = State.Value({ "character", "gold" })
	local inventory = State.Value({ "character", "inventory" })
	local skin = State.Value({ "account", "cosmetics", "equipped", "mountskin" })
	local picked = scope:Value(nil :: string?)

	-- The mount shown on the right: the picked one, else the active one, else nothing.
	local selected = scope:Computed(function(use): string?
		local id = use(picked)
		if id and MountData.get(id) then
			return id
		end
		local active = Mounts.activeOf(use(mounts))
		return active
	end)
	local ownedLevel = scope:Computed(function(use): number?
		local id = use(selected)
		local state = use(mounts)
		local entry = id and type(state) == "table" and state.owned and state.owned[id]
		return if entry then math.clamp(tonumber(entry.lvl) or 1, 1, Config.Mount.maxLevel) else nil
	end)

	-- List ----------------------------------------------------------------------------------------------------------
	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local out: { Instance } = {}
		local state = use(mounts)
		local lvl = tonumber(use(level)) or 1
		local owned = ownedList(state)
		local active = Mounts.activeOf(state)
		local current = use(selected)
		local order = 0
		local function add(child: Instance)
			order += 1
			(child :: any).LayoutOrder = order
			table.insert(out, child)
		end
		if #owned == 0 then
			local key = if lvl >= Config.Mount.minLevel then "mount.empty" else "mount.error.level"
			add(line(s, 0, Text.get(use, key, { level = Config.Mount.minLevel }), Theme.Paper.TextMuted))
		end
		for _, item in owned do
			local def = MountData.get(item.id) :: MountData.MountDef
			add(s:New("TextButton")({
				Size = UDim2.new(1, 0, 0, ROW),
				AutoButtonColor = false,
				Text = "",
				BackgroundColor3 = if current == item.id then Theme.Paper.Hover else Theme.Paper.Raised,
				BackgroundTransparency = 0.2,
				[OnEvent("Activated")] = function()
					Sounds.play("click")
					picked:set(item.id)
				end,
				[Children] = {
					s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					swatch(s, def, false),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(ROW + 2, 6),
						Size = UDim2.new(1, -(ROW + 8), 0, 26),
						BackgroundTransparency = 1,
						Text = Text.get(use, def.nameKey),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = if active == item.id then Theme.Paper.Heading else Theme.Paper.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(ROW + 2, 34),
						Size = UDim2.new(1, -(ROW + 8), 0, 22),
						BackgroundTransparency = 1,
						Text = `{Text.get(use, "mount.level", { lvl = item.lvl, max = Config.Mount.maxLevel })} · ×{AreaProfileText.mul(
							use,
							Mounts.speedMul(item.lvl)
						)}{if active == item.id then ` · {Text.get(use, "mount.active")}` else ""}`,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = if active == item.id then Theme.Paper.Heading else Theme.Paper.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
				},
			}))
		end
		-- To obtain: mounts the character lacks (a premium one only while on sale).
		local toGet: { MountData.MountDef } = {}
		local have = if type(state) == "table" and type(state.owned) == "table" then state.owned else {}
		for _, def in MountData.list do
			if have[def.id] == nil and Mounts.isObtainable(def, premiumOnSale) then
				table.insert(toGet, def)
			end
		end
		if #toGet > 0 then
			add(s:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Text = Text.get(use, "mount.toGet"),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
			}))
		end
		for _, def in toGet do
			add(s:New("TextButton")({
				Size = UDim2.new(1, 0, 0, ROW),
				AutoButtonColor = false,
				Text = "",
				BackgroundColor3 = if current == def.id then Theme.Paper.Hover else Theme.Paper.Surface,
				BackgroundTransparency = 0.3,
				[OnEvent("Activated")] = function()
					Sounds.play("click")
					picked:set(def.id)
				end,
				[Children] = {
					s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					swatch(s, def, true),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(ROW + 2, 6),
						Size = UDim2.new(1, -(ROW + 8), 0, 26),
						BackgroundTransparency = 1,
						Text = Text.get(use, def.nameKey),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Paper.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(ROW + 2, 34),
						Size = UDim2.new(1, -(ROW + 8), 0, 22),
						BackgroundTransparency = 1,
						Text = `{Text.get(use, "mount.level", { lvl = def.startLevel, max = Config.Mount.maxLevel })} · {sourceText(
							use,
							def
						)}`,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
				},
			}))
		end
		return out
	end)

	-- Preview ---------------------------------------------------------------------------------------------------------
	local viewport = scope:New("ViewportFrame")({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, PREVIEW),
		Visible = scope:Computed(function(use): boolean
			return use(selected) ~= nil
		end),
		BackgroundColor3 = Theme.Paper.Sunken,
		Ambient = Color3.fromRGB(160, 150, 140),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1, -1),
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
	local shown = scope:Computed(function(use): string
		local id = use(selected) or ""
		local s = use(skin)
		return `{id}|{if type(s) == "string" then s else ""}`
	end)
	local function rebuild()
		if model then
			model:Destroy()
			model = nil
		end
		local id = Fusion.peek(selected)
		if not id then
			return
		end
		local s = Fusion.peek(skin)
		model = MountLook.preview(id, if type(s) == "string" then s else nil)
		if model then
			model.Parent = viewport
		end
	end
	rebuild()
	scope:Observer(shown):onChange(rebuild)
	table.insert(scope, function()
		if model then
			model:Destroy()
		end
	end)
	local angle = 0
	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt: number)
			angle += dt * 0.5
			camera.CFrame =
				CFrame.new(Vector3.new(math.sin(angle) * 13, 5, math.cos(angle) * 13), Vector3.new(0, 2.6, 0))
		end)
	)

	-- Details and upgrade -----------------------------------------------------------------------------------------
	local details = scope:Computed(function(use, s: Scope): { Instance }
		local out: { Instance } = {}
		local chosen = use(selected)
		local def = chosen and MountData.get(chosen)
		if not chosen or not def then
			table.insert(out, line(s, 2, Text.get(use, "mount.pick"), Theme.Paper.TextMuted, Theme.TextSize.Body))
			return out
		end
		local id: string = chosen
		local owned = use(ownedLevel)
		local lvl = owned or def.startLevel
		local state = use(mounts)
		local active = Mounts.activeOf(state)
		-- 2026-10-21 (owner: too many detailed descriptions): the name with its story behind the "i"
		local name = line(s, 1, Text.get(use, def.nameKey), Theme.Paper.Heading, Theme.TextSize.Large) :: TextLabel
		name.Size = UDim2.new()
		name.AutomaticSize = Enum.AutomaticSize.XY
		s:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink, Parent = name })
		table.insert(
			out,
			s:New("Frame")({
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					name,
					InfoTip.new(s, { Text = Text.get(use, `mount.{def.id}.desc`), LayoutOrder = 2 }),
				},
			})
		)
		table.insert(
			out,
			line(
				s,
				4,
				`{Text.get(use, "mount.level", { lvl = lvl, max = Config.Mount.maxLevel })} · {Text.get(
					use,
					"mount.speed",
					{
						mul = AreaProfileText.mul(use, Mounts.speedMul(lvl)),
						max = AreaProfileText.mul(use, Config.Mount.maxMul),
					}
				)}`
			)
		)
		table.insert(
			out,
			line(s, 5, Text.get(use, "mount.mountTime", { s = AreaProfileText.mul(use, Mounts.mountTime(lvl)) }))
		)
		if not owned then
			table.insert(out, line(s, 6, sourceText(use, def), Theme.Paper.Heading))
			return out
		end
		-- Look (the account's mount skin) and the wardrobe.
		local skinId = use(skin)
		local skinDef = if type(skinId) == "string" then Cosmetics.get(skinId) else nil
		table.insert(
			out,
			s:New("Frame")({
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("TextLabel")({
						Size = UDim2.new(1, -170, 1, 0),
						BackgroundTransparency = 1,
						Text = if skinDef
							then Text.get(use, "mount.skin", { skin = Text.get(use, skinDef.nameKey) })
							else Text.get(use, "mount.skin.none"),
						TextWrapped = true,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Button(s, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(160, 44),
						Variant = "secondary",
						TextSize = Theme.TextSize.Small,
						Text = Text.T(s, "mount.openWardrobe"),
						OnClick = props.OpenWardrobe,
					}),
				},
			})
		)
		local isActive = active == id
		table.insert(
			out,
			Button(s, {
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 44),
				Variant = if isActive then "secondary" else "primary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(s, if isActive then "mount.active" else "mount.choose"),
				Disabled = isActive,
				OnClick = function()
					invoke("MountSetActive", id)
				end,
			})
		)
		-- Upgrade panel.
		if owned >= Config.Mount.maxLevel then
			table.insert(out, line(s, 8, Text.get(use, "mount.upgrade.max"), Theme.Paper.Success, Theme.TextSize.Body))
			return out
		end
		local step = Mounts.upgradeCost(owned + 1)
		if not step then
			return out
		end
		local charLevel = tonumber(use(level)) or 1
		local money = tonumber(use(gold)) or 0
		local inv = use(inventory)
		local counts: { [string]: number } = {}
		for _, m in step.materials do
			counts[m.id] = if type(inv) == "table" then Inventory.count(inv :: any, m.id) else 0
		end
		local ok, err = Mounts.canUpgrade({ level = charLevel, gold = money, mounts = state }, id, counts)
		local near = use(props.Near)
		table.insert(
			out,
			line(
				s,
				8,
				Text.get(use, "mount.upgrade.title", { lvl = owned + 1 }),
				Theme.Paper.Heading,
				Theme.TextSize.Body
			)
		)
		table.insert(
			out,
			line(
				s,
				9,
				Text.get(use, "mount.upgrade.speed", {
					from = AreaProfileText.mul(use, Mounts.speedMul(owned)),
					to = AreaProfileText.mul(use, Mounts.speedMul(owned + 1)),
				})
			)
		)
		if Mounts.mountTime(owned) ~= Mounts.mountTime(owned + 1) then
			table.insert(
				out,
				line(
					s,
					10,
					Text.get(use, "mount.upgrade.mountTime", {
						from = AreaProfileText.mul(use, Mounts.mountTime(owned)),
						to = AreaProfileText.mul(use, Mounts.mountTime(owned + 1)),
					})
				)
			)
		end
		table.insert(
			out,
			line(
				s,
				11,
				Text.get(use, "mount.upgrade.needLevel", { level = step.level }),
				if charLevel >= step.level then Theme.Paper.Text else Theme.Paper.Danger
			)
		)
		table.insert(
			out,
			line(
				s,
				12,
				Text.get(use, "mount.upgrade.gold", { have = Format.number(money), cost = Format.number(step.gold) }),
				if money >= step.gold then Theme.Paper.Heading else Theme.Paper.Danger
			)
		)
		local mats: { Instance } = {}
		for i, m in step.materials do
			local item = Items.get(m.id)
			local have = counts[m.id] or 0
			table.insert(
				mats,
				s:New("Frame")({
					LayoutOrder = i,
					Size = UDim2.fromOffset(150, 48),
					BackgroundTransparency = 1,
					[Children] = {
						ItemIcon(s, { Def = item, Size = UDim2.fromOffset(44, 44) }),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(50, 0),
							Size = UDim2.new(1, -50, 1, 0),
							BackgroundTransparency = 1,
							Text = `{have}/{m.n}\n{Text.get(use, `item.{m.id}.name`)}`,
							TextWrapped = true,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if have >= m.n then Theme.Paper.Text else Theme.Paper.Danger,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
					},
				})
			)
		end
		table.insert(
			out,
			s:New("Frame")({
				LayoutOrder = 13,
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					mats :: any,
				},
			})
		)
		local reason = if not near then "mount.upgrade.atStable" elseif not ok then err else nil
		table.insert(
			out,
			Button(s, {
				LayoutOrder = 14,
				Size = UDim2.new(1, 0, 0, 44),
				Variant = "primary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(s, "mount.upgrade"),
				Disabled = reason ~= nil,
				OnClick = function()
					invoke("MountUpgrade", id)
				end,
			})
		)
		if reason then
			table.insert(out, line(s, 15, Text.get(use, reason, { level = step.level }), Theme.Paper.Warning))
		end
		return out
	end)

	return {
		scope:New("ScrollingFrame")({
			Size = UDim2.new(0, LIST_WIDTH, 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
				rows :: any,
			},
		}),
		scope:New("ScrollingFrame")({
			Position = UDim2.fromOffset(LIST_WIDTH + 16, 0),
			Size = UDim2.new(1, -(LIST_WIDTH + 16), 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
				viewport :: Instance,
				details :: any,
			},
		}),
	}
end

return MountWindow
