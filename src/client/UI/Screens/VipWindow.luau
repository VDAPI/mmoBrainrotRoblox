--!strict
-- VIP window (DESIGN-17 §2, S121): the status (subscription, "VIP forever" or none) with "Subscribe" (or "Soon"
-- without an id on a live server), the benefits (Logic/Vip.BENEFITS: numbers from Config.Vip), today's state (shards,
-- free respawn, the free return to the city with its countdown) and the cosmetic of the month with the VIP cosmetics
-- the account already has. PC: two columns (benefits left, today and the month right); phone: one scrolling column.
-- Opened from the game menu, the Passes tab of the Dragon Shop and the VIP card there; no key. The server decides
-- everything (MonetizationService, VipService); this window only shows the replicated branches and asks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Components.Button)
local Cards = require(script.Parent.PremiumShop.Cards)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)
local Tooltip = require(script.Parent.Parent.Components.Tooltip)
local Vip = require(ReplicatedStorage.Shared.Logic.Vip)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	OpenWardrobe: (() -> ())?,
}

export type VipBranch = { active: boolean?, sub: boolean?, pass: boolean?, renewing: boolean?, endsAt: number? }

local VipWindow = {}

local function branch(value: any): VipBranch
	return if type(value) == "table" then value else {}
end

-- "dd.mm.yyyy" of a UTC time.
function VipWindow.date(t: number): string
	local year, month, day = Time.civil(t)
	return string.format("%02d.%02d.%04d", day, month, year)
end

-- The status line of the VIP branch (also the VIP card of the shop).
function VipWindow.statusText(use: Fusion.Use, vip: VipBranch): string
	if vip.sub then
		local text = Text.get(use, "vip.status.sub")
		if vip.renewing == true then
			text ..= ", " .. Text.get(use, "vip.status.renewing")
		elseif vip.renewing == false then
			text ..= ", " .. Text.get(use, "vip.status.ending")
		end
		if vip.endsAt then
			text ..= " " .. Text.get(use, "vip.status.until", { date = VipWindow.date(vip.endsAt) })
		end
		return text
	elseif vip.pass or vip.active then
		return Text.get(use, "vip.status.pass")
	end
	return Text.get(use, "vip.status.none")
end

-- Whether "Subscribe" can be offered here (Studio simulates; an empty id on a live server shows "Soon").
function VipWindow.subscribeSoon(): boolean
	local sub = Products.getSubscription("vip")
	return sub == nil or Premium.subscriptionState(sub, RunService:IsStudio()) == "soon"
end

-- "Subscribe" / "Soon" (hidden while VIP is active). `width` and `layout` place it.
function VipWindow.subscribeButton(scope: Scope, vip: Fusion.UsedAs<any>, props: { [string]: any }): Instance
	local soon = VipWindow.subscribeSoon()
	local button = Button(scope, {
		Variant = "primary",
		Text = Text.T(scope, if soon then "premium.soon" else "premium.subscribe"),
		Disabled = soon,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		TextSize = Theme.TextSize.Small,
		Visible = scope:Computed(function(use): boolean
			return branch(use(vip)).active ~= true
		end),
		OnClick = function()
			Cards.invoke("BuySubscription", "vip")
		end,
	})
	if soon then
		Tooltip.attach(scope, button :: GuiObject, Text.T(scope, "premium.soon.hint"))
	end
	return button
end

local function label(scope: Scope, props: { [string]: any }): Instance
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Colors.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}
	for key, value in props do
		base[key] = value
	end
	return scope:New("TextLabel")(base :: any)
end

local function header(scope: Scope, order: number, key: string): Instance
	return label(scope, {
		LayoutOrder = order,
		Text = Text.T(scope, key),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Colors.GoldBright,
	})
end

-- A panel holding rows one under another.
local function panel(scope: Scope, order: number, children: { any }): Instance
	local list: { any } = {
		scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		scope:New("UIPadding")({
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
	}
	for _, child in children do
		table.insert(list, child)
	end
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.2,
		[Children] = list :: any,
	})
end

-- One benefit: a glyph and the text with its numbers (fractions with the language's decimal mark).
local function benefitRow(scope: Scope, order: number, row: Vip.Benefit): Instance
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("TextLabel")({
				Size = UDim2.fromOffset(28, 24),
				BackgroundTransparency = 1,
				Text = row.icon,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.GoldBright,
			}),
			label(scope, {
				Position = UDim2.fromOffset(34, 2),
				Size = UDim2.new(1, -34, 0, 0),
				Text = scope:Computed(function(use): string
					local args: { [string]: any } = {}
					local mark = Text.get(use, "format.decimal")
					local given: { [string]: any } = row.args or {}
					for name, value in given do
						if type(value) == "number" and value ~= math.floor(value) then
							args[name] = (string.gsub(tostring(value), "%.", mark))
						else
							args[name] = value
						end
					end
					return Text.get(use, `vip.benefit.{row.key}`, args)
				end),
			}),
		},
	})
end

local function invoke(name: string)
	task.spawn(function()
		local ok, err, args = Net.Invoke(name)
		if ok then
			Sounds.play("levelUp")
		else
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal", Cards.resolveArgs(args)), "error")
		end
	end)
end

function VipWindow.build(scope: Scope, props: Props?): Instance
	Net.Send("PremiumFunnel", "vip", "open") -- S131: the VIP funnel (Logic/ShopFunnel)
	local vip = State.Value({ "vip" })
	local vipState = State.Value({ "account", "vip" })
	local owned = State.Value({ "account", "cosmetics", "owned" })
	local map = State.Value({ "character", "location", "map" })
	local touch = Device.Touch

	-- The clock (every second): texts and button states only.
	local now = scope:Value(Clock.now())
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(1)
			if alive then
				now:set(Clock.now())
			end
		end
	end)

	local active = scope:Computed(function(use): boolean
		return branch(use(vip)).active == true
	end)
	local recallLeft = scope:Computed(function(use): number
		return Vip.recallLeft(use(vipState), use(now))
	end)
	local inCity = scope:Computed(function(use): boolean
		return use(map) == Config.StartingMap
	end)

	-- Header: star, title, status and the subscription button / the account note.
	local top = scope:New("Frame")({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.2,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Colors.GoldBright,
				Thickness = Theme.Stroke.Normal,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(10, 8),
				Size = UDim2.fromOffset(56, 56),
				BackgroundTransparency = 1,
				Text = "★",
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = Theme.Colors.GoldBright,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(76, 8),
				Size = UDim2.new(1, -280, 0, 28),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "vip.title"),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.GoldBright,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(76, 38),
				Size = UDim2.new(1, -280, 0, 26),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return VipWindow.statusText(use, branch(use(vip)))
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(active) then Theme.Colors.Success else Theme.Colors.TextMuted
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			VipWindow.subscribeButton(scope, vip, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(190, 48),
			}),
			label(scope, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(190, 0),
				Text = Text.T(scope, "vip.manage"),
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Right,
				Visible = scope:Computed(function(use): boolean
					return branch(use(vip)).sub == true
				end),
			}),
		},
	})

	-- Left column: benefits.
	local benefitRows: { any } = { header(scope, 0, "vip.benefits") }
	for i, row in Vip.BENEFITS do
		table.insert(benefitRows, benefitRow(scope, i, row))
	end
	table.insert(
		benefitRows,
		label(scope, {
			LayoutOrder = 100,
			Text = Text.T(scope, "vip.noPower"),
			TextColor3 = Theme.Colors.TextMuted,
		})
	)

	-- Right column: today.
	local recallButton = Button(scope, {
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 48),
		Variant = "secondary",
		TextSize = Theme.TextSize.Small,
		Visible = active,
		Disabled = scope:Computed(function(use): boolean
			return use(recallLeft) > 0 or use(inCity)
		end),
		Text = scope:Computed(function(use): string
			local left = use(recallLeft)
			if left > 0 then
				return Text.get(use, "vip.recall.wait", { time = Time.format(left) })
			end
			return Text.get(use, "vip.recall")
		end),
		OnClick = function()
			invoke("VipRecall")
		end,
	})
	local today = panel(scope, 2, {
		header(scope, 1, "vip.today"),
		label(scope, {
			LayoutOrder = 2,
			Text = scope:Computed(function(use): string
				local done = use(active) and not Vip.dailyDue(use(vipState), use(now))
				return Text.get(use, if done then "vip.today.shards" else "vip.today.shardsSoon")
			end),
		}),
		label(scope, {
			LayoutOrder = 3,
			Text = scope:Computed(function(use): string
				local n = if use(active) then Vip.respawnLeft(use(vipState), use(now)) else 0
				return Text.get(use, "vip.today.respawn", { n = n })
			end),
		}),
		recallButton,
		label(scope, {
			LayoutOrder = 5,
			Text = Text.T(scope, "vip.error.inCity"),
			TextColor3 = Theme.Colors.TextMuted,
			Visible = scope:Computed(function(use): boolean
				return use(active) and use(inCity) and use(recallLeft) <= 0
			end),
		}),
	})

	-- Right column: the cosmetic of the month and the VIP cosmetics owned.
	local monthKey = scope:Computed(function(use): string
		return Time.monthKey(use(now))
	end)
	local monthDef = scope:Computed(function(use): Cosmetics.Def?
		local id = Vip.monthCosmetic(use(monthKey))
		return if id then Cosmetics.get(id) else nil
	end)
	local month = panel(scope, 3, {
		header(scope, 1, "vip.month"),
		scope:New("Frame")({
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("TextLabel")({
					Size = UDim2.fromOffset(56, 56),
					BackgroundColor3 = scope:Computed(function(use): Color3
						local def = use(monthDef)
						return if def then Color3.fromHex(def.color) else Theme.Colors.Panel
					end),
					Text = scope:Computed(function(use): string
						local def = use(monthDef)
						return if def then def.icon else "✦"
					end),
					TextScaled = true,
					FontFace = Theme.Fonts.BodyBold,
					TextColor3 = Color3.new(1, 1, 1),
					TextStrokeTransparency = 0.4,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						scope:New("UIPadding")({
							PaddingTop = UDim.new(0, 8),
							PaddingBottom = UDim.new(0, 8),
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
						}),
					},
				}),
				label(scope, {
					Position = UDim2.fromOffset(66, 0),
					Size = UDim2.new(1, -66, 0, 0),
					Text = scope:Computed(function(use): string
						local def = use(monthDef)
						if not def then
							return Text.get(use, "vip.month.none")
						end
						local name = Text.get(use, def.nameKey)
						local kind = Text.get(use, `wardrobe.kind.{def.kind}`)
						local mine = branch(use(owned) :: any) :: any
						local state = if mine[def.id] == true then "vip.month.owned" else "vip.month.next"
						return `<b>{name}</b> · {kind}\n{Text.get(use, state)}`
					end),
					RichText = true,
				}),
			},
		}),
		label(scope, {
			LayoutOrder = 3,
			Text = Text.T(scope, "vip.month.collection"),
			TextColor3 = Theme.Colors.TextMuted,
		}),
		scope:New("Frame")({
			LayoutOrder = 4,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIGridLayout")({
					CellSize = UDim2.fromOffset(44, 44),
					CellPadding = UDim2.fromOffset(6, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				scope:Computed(function(use, s: Scope): { Instance }
					local mine = branch(use(owned) :: any) :: any
					local tiles: { Instance } = {}
					for _, def in Cosmetics.list do
						local key = def.obtain and def.obtain.vipMonth
						if key and mine[def.id] == true then
							local tile = s:New("TextLabel")({
								LayoutOrder = tonumber(key) or 0,
								BackgroundColor3 = Color3.fromHex(def.color),
								Text = def.icon,
								TextScaled = true,
								FontFace = Theme.Fonts.BodyBold,
								TextColor3 = Color3.new(1, 1, 1),
								TextStrokeTransparency = 0.4,
								[Children] = {
									s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
									s:New("UIPadding")({
										PaddingTop = UDim.new(0, 6),
										PaddingBottom = UDim.new(0, 6),
										PaddingLeft = UDim.new(0, 6),
										PaddingRight = UDim.new(0, 6),
									}),
								},
							}) :: GuiObject
							local year, m = Time.monthLabel(key)
							Tooltip.attach(
								s,
								tile,
								s:Computed(function(u): string
									local when = if year and m then string.format("%02d.%04d", m, year) else key
									return `{Text.get(u, def.nameKey)} · {Text.get(u, "wardrobe.obtain.vip", {
										month = when,
									})}`
								end)
							)
							table.insert(tiles, tile)
						end
					end
					return tiles
				end) :: any,
			},
		}),
		Button(scope, {
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, 44),
			Variant = "ghost",
			Surface = "iron", -- S135: on a dark HUD / overlay surface
			TextSize = Theme.TextSize.Small,
			Text = Text.T(scope, "window.wardrobe.title"),
			Visible = props ~= nil and props.OpenWardrobe ~= nil,
			OnClick = function()
				if props and props.OpenWardrobe then
					props.OpenWardrobe()
				end
			end,
		}),
	})

	local function column(order: number, children: { any }): Instance
		local list: { any } = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
		}
		for _, child in children do
			table.insert(list, child)
		end
		return scope:New("Frame")({
			LayoutOrder = order,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = scope:Computed(function(use): UDim2
				return if use(touch) then UDim2.fromScale(1, 0) else UDim2.new(0.5, -6, 0, 0)
			end),
			[Children] = list :: any,
		})
	end

	local columns = scope:New("Frame")({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = scope:Computed(function(use): Enum.FillDirection
					return if use(touch) then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
				end),
				Padding = UDim.new(0, 12),
			}),
			column(1, { panel(scope, 1, benefitRows) }),
			column(2, { today, month }),
		},
	})

	return scope:New("ScrollingFrame")({
		Name = "VipWindow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		[Children] = {
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }),
			top,
			columns,
		},
	})
end

return VipWindow
