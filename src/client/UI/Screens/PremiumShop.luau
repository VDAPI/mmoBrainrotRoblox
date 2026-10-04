--!strict
-- Premium shop (DESIGN §21): Dragon Shard packs and gamepasses (Robux; simulated in Studio / with id 0),
-- services for shards (scrolls with the daily limit, renaming the character) and a link to the wardrobe.
-- Nothing here sells power: no EXP, stats or items with bonuses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.ItemText)
local Net = require(ReplicatedStorage.Shared.Net)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	ShowModal: (spec: any) -> (),
	OpenWardrobe: () -> (),
}

local function invoke(name: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = Net.Invoke(name, table.unpack(args, 1, args.n))
		if ok then
			Sounds.play("levelUp")
			if err then
				Toast.push(Text.now(err), "info")
			end
		else
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

local function card(
	scope: Scope,
	order: number,
	icon: string,
	title: Fusion.UsedAs<string>,
	subtitle: Fusion.UsedAs<string>,
	button: Instance
): Instance
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.2,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(10, 8),
				Size = UDim2.fromOffset(54, 54),
				BackgroundColor3 = Theme.Colors.Panel,
				Text = icon,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = Theme.Colors.GoldBright,
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
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(76, 8),
				Size = UDim2.new(1, -270, 0, 28),
				BackgroundTransparency = 1,
				Text = title,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(76, 36),
				Size = UDim2.new(1, -270, 0, 24),
				BackgroundTransparency = 1,
				Text = subtitle,
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			button,
		},
	})
end

local function buyButton(
	scope: Scope,
	text: Fusion.UsedAs<string>,
	disabled: Fusion.UsedAs<boolean>?,
	onClick: () -> ()
): Instance
	return Button(scope, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(180, 48),
		Variant = "primary",
		TextSize = Theme.TextSize.Small,
		Text = text,
		Disabled = disabled,
		OnClick = onClick,
	})
end

local function currencyTab(scope: Scope): { Instance }
	local passes = State.Value({ "passes" })
	local list = {}
	for i, pack in Products.shardPacks do
		table.insert(
			list,
			card(
				scope,
				i,
				"◆",
				Text.T(scope, "premium.pack", { n = Format.number(pack.shards) }),
				Text.T(scope, "premium.pack.desc"),
				buyButton(scope, `R$ {pack.robux}`, nil, function()
					invoke("BuyProduct", pack.key)
				end)
			)
		)
	end
	for i, pass in Products.passes do
		local isOwned = scope:Computed(function(use): boolean
			local p = use(passes)
			return type(p) == "table" and p[pass.key] == true
		end)
		table.insert(
			list,
			card(
				scope,
				100 + i,
				pass.icon,
				Text.T(scope, `premium.pass.{pass.key}`),
				Text.T(scope, `premium.pass.{pass.key}.desc`),
				buyButton(
					scope,
					scope:Computed(function(use): string
						return if use(isOwned) then Text.get(use, "premium.owned") else `R$ {pass.robux}`
					end),
					isOwned,
					function()
						invoke("BuyPass", pass.key)
					end
				)
			)
		)
	end
	return list
end

local function servicesTab(scope: Scope, props: Props): { Instance }
	local shards = State.Value({ "account", "dragonShards" })
	local limits = State.Value({ "account", "dailyLimits" })
	local list = {}
	for i, entry in Products.shop do
		if entry.kind == "item" and entry.itemId then
			local itemId = entry.itemId
			table.insert(
				list,
				card(
					scope,
					i,
					"📜",
					scope:Computed(function(use): string
						return ItemText.get(use, itemId)
					end),
					scope:Computed(function(use): string
						if not entry.dailyLimit then
							return Text.get(use, "premium.service.item")
						end
						local l = use(limits)
						local used = if type(l) == "table" then Premium.usedToday(l, os.time()) else 0
						return Text.get(use, "premium.service.limit", { used = used, max = entry.dailyLimit })
					end),
					buyButton(
						scope,
						`◆ {entry.price}`,
						scope:Computed(function(use): boolean
							return (use(shards) or 0) < entry.price
						end),
						function()
							invoke("PremiumBuy", entry.key)
						end
					)
				)
			)
		elseif entry.kind == "rename" then
			table.insert(
				list,
				card(
					scope,
					i,
					"✎",
					Text.T(scope, "premium.rename"),
					Text.T(scope, "premium.rename.desc"),
					buyButton(
						scope,
						`◆ {entry.price}`,
						scope:Computed(function(use): boolean
							return (use(shards) or 0) < entry.price
						end),
						function()
							props.ShowModal({
								Title = Text.now("premium.rename"),
								Message = Text.now("premium.rename.confirm", { price = entry.price }),
								ConfirmText = Text.now("common.confirm"),
								CancelText = Text.now("common.cancel"),
								Input = { Placeholder = Text.now("premium.rename.placeholder"), MaxLength = 16 },
								OnConfirm = function(text: string): (boolean, string?)
									local ok, err = Net.Invoke("PremiumRename", text)
									if not ok then
										return false, Text.now(err or "error.internal")
									end
									Sounds.play("levelUp")
									Toast.push(Text.now("premium.renamed", { name = text }), "success")
									return true, nil
								end,
							})
						end
					)
				)
			)
		end
	end
	table.insert(
		list,
		card(
			scope,
			99,
			"♛",
			Text.T(scope, "window.wardrobe.title"),
			Text.T(scope, "premium.wardrobe.desc"),
			buyButton(scope, Text.T(scope, "premium.openWardrobe"), nil, props.OpenWardrobe)
		)
	)
	return list
end

local function PremiumShop(scope: Scope, props: Props): Fusion.Child
	local tab = scope:Value("currency")
	local shards = State.Value({ "account", "dragonShards" })
	local content = scope:Computed(function(use, s: Scope): { Instance }
		return if use(tab) == "services" then servicesTab(s, props) else currencyTab(s)
	end)
	return {
		Tabs(scope, {
			Selected = tab,
			Size = UDim2.new(1, -220, 0, Theme.Size.ButtonHeightSmall),
			Tabs = {
				{ id = "currency", label = Text.T(scope, "premium.tab.currency") },
				{ id = "services", label = Text.T(scope, "premium.tab.services") },
			},
		}),
		scope:New("TextLabel")({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(210, Theme.Size.ButtonHeightSmall),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				return `◆ {Format.number(use(shards) or 0)}`
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Large,
			TextColor3 = Theme.Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		scope:New("ScrollingFrame")({
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 1, -52),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
				content :: any,
			},
		}),
	}
end

return PremiumShop
