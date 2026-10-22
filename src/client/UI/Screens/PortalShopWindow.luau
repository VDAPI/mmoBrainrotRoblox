--!strict
-- S160k (owner 2026-10-21): the Portal Master's shop (Data/PortalShop). The Dragon Currency on top, then every teleport
-- stone of the game with its icon, name, what it does, how many the character carries and three ways to get it: one
-- stone, ten stones, or the everlasting stone (once per account; "Owned" afterwards, "Take your copy" for a character
-- without one). Logic/PortalShop.canBuy (the server's own rule) says why a button is off. Buying works only at the
-- Portal Master (the window opens from his dialog and closes when the player walks away); forever asks first.
-- 2026-10-21 (owner: too many detailed descriptions): one short line on top (the rules behind its "i"); a row says only
-- how many the character carries, where the stone leads is behind the "i" after its name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local CurrencyIcon = require(script.Parent.Parent.Components.CurrencyIcon)
local Data = require(ReplicatedStorage.Shared.Data.PortalShop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Modal = require(script.Parent.Parent.Components.Modal)
local Net = require(ReplicatedStorage.Shared.Net)
local PortalShop = require(ReplicatedStorage.Shared.Logic.PortalShop)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use

export type Props = {
	NpcId: Fusion.UsedAs<string?>, -- the NPC the player talks to (NpcController.Current)
	ShowModal: (spec: Modal.Spec) -> (),
}

local ICON = 48
local INTRO = 24 -- the one-line intro under the balance
local PACK = 10 -- the second "by the piece" button

local function count(inv: any, itemId: string): number
	local n = 0
	for _, item in inv or {} do
		if item.id == itemId then
			n += item.n
		end
	end
	return n
end

local function label(s: Scope, order: number, text: string, size: number, color: Color3, font: Font?): Instance
	return s:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		RichText = true,
		TextWrapped = true,
		Text = text,
		FontFace = font or Theme.Fonts.Body,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function PortalShopWindow(scope: Scope, props: Props): Fusion.Child
	local shards = State.Value({ "account", "dragonShards" })
	local portalStones = State.Value({ "account", "portalStones" })
	local inventory = State.Value({ "character", "inventory" })
	local busy = scope:Value(false)

	local function send(entry: Data.Entry, mode: string, n: number, name: string): (boolean, string?)
		busy:set(true)
		local ok, err = Net.Invoke("PortalShopBuy", entry.itemId, mode, n)
		busy:set(false)
		if ok then
			Sounds.play("levelUp")
			local key = if mode == "perm"
				then "portalshop.boughtPerm"
				elseif mode == "claim" then "portalshop.claimed"
				else "portalshop.bought"
			Toast.push(Text.now(key, { name = name, n = n }), "success")
			return true, nil
		end
		Sounds.play("error")
		return false, Text.now(err or "error.internal")
	end

	local function buy(entry: Data.Entry, mode: string, n: number, name: string)
		if Fusion.peek(busy) or Fusion.peek(props.NpcId) ~= Data.NPC then
			return
		end
		if mode == "perm" then
			props.ShowModal({
				Title = Text.now("portalshop.permTitle"),
				Message = Text.now("portalshop.permConfirm", { name = name, price = entry.perm }),
				ConfirmText = Text.now("portalshop.buyPerm"),
				CancelText = Text.now("common.cancel"),
				OnConfirm = function(): (boolean, string?)
					return send(entry, mode, n, name)
				end,
			})
			return
		end
		task.spawn(function()
			local ok, err = send(entry, mode, n, name)
			if not ok then
				Toast.push(err or Text.now("error.internal"), "error")
			end
		end)
	end

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local account = { dragonShards = use(shards) or 0, portalStones = use(portalStones) }
		local inv = use(inventory)
		local here = use(props.NpcId) == Data.NPC
		local locked = use(busy) or not here
		local out: { Instance } = {}
		if not here then
			table.insert(
				out,
				label(s, 0, Text.get(use, "portalshop.atMaster"), Theme.TextSize.Small, Theme.Paper.Warning)
			)
		end
		-- owner 2026-10-22 (Studio: "10 szt. · 100 ◆" wrapped, the ◆ alone on a second line): wide enough for the
		-- longest label ("Na stałe · 600 ◆", "Take your copy") in Small with the button's padding, at every scale
		-- (tests/uifit.spec); three of them (540 px) fit the 720 px window on every device
		local buttonWidth = 176
		for order, entry in Data.list do
			local def = Items.get(entry.itemId)
			local name = ItemText.get(use, entry.itemId)
			local permName = ItemText.get(use, entry.permId)
			local owned = PortalShop.owned(account, entry.itemId)
			local held = count(inv, entry.permId)
			local notes = {
				Text.get(use, "portalshop.carry", { n = count(inv, entry.itemId) }),
			}
			if owned then
				table.insert(notes, Text.get(use, "portalshop.ownedNote", { name = permName }))
			end
			local function priceButton(
				layout: number,
				mode: string,
				n: number,
				textKey: string,
				variant: string
			): Instance
				local ok = PortalShop.canBuy(entry, mode, n, account, held)
				return Button(s, {
					LayoutOrder = layout,
					Size = UDim2.fromOffset(buttonWidth, Theme.Size.MinTouch),
					Variant = variant :: any,
					Disabled = not ok or locked,
					Text = Text.get(use, textKey, { n = n, price = PortalShop.price(entry, mode, n) or 0 }),
					TextSize = Theme.TextSize.Small,
					OnClick = function()
						buy(entry, mode, n, if mode == "piece" then name else permName)
					end,
				})
			end
			local permAction: Instance
			if not owned then
				permAction = priceButton(3, "perm", 1, "portalshop.perm", "primary")
			elseif held == 0 then
				permAction = priceButton(3, "claim", 1, "portalshop.claim", "primary")
			else
				permAction = s:New("TextLabel")({
					LayoutOrder = 3,
					Size = UDim2.fromOffset(buttonWidth, Theme.Size.MinTouch),
					BackgroundTransparency = 1,
					Text = Text.get(use, "portalshop.owned"),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.Success,
				})
			end
			table.insert(
				out,
				s:New("Frame")({
					LayoutOrder = order,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Theme.Paper.Surface,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIPadding")({
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
							PaddingTop = UDim.new(0, 6),
							PaddingBottom = UDim.new(0, 6),
						}),
						s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
						-- icon, name and notes
						s:New("Frame")({
							LayoutOrder = 1,
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							[Children] = {
								s:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Horizontal,
									SortOrder = Enum.SortOrder.LayoutOrder,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									Padding = UDim.new(0, 8),
								}),
								ItemIcon(s, { Def = def, Size = UDim2.fromOffset(ICON, ICON), LayoutOrder = 1 }),
								s:New("Frame")({
									LayoutOrder = 2,
									Size = UDim2.new(1, -(ICON + 8), 0, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
									BackgroundTransparency = 1,
									[Children] = {
										s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
										-- the name and its "i" (where the stone leads)
										s:New("Frame")({
											LayoutOrder = 1,
											Size = UDim2.fromScale(1, 0),
											AutomaticSize = Enum.AutomaticSize.Y,
											BackgroundTransparency = 1,
											[Children] = {
												s:New("UIListLayout")({
													FillDirection = Enum.FillDirection.Horizontal,
													VerticalAlignment = Enum.VerticalAlignment.Center,
													SortOrder = Enum.SortOrder.LayoutOrder,
													Padding = UDim.new(0, 6),
												}),
												s:New("TextLabel")({
													LayoutOrder = 1,
													Size = UDim2.new(),
													AutomaticSize = Enum.AutomaticSize.XY,
													BackgroundTransparency = 1,
													TextWrapped = true,
													Text = name,
													FontFace = Theme.Fonts.BodyBold,
													TextSize = Theme.TextSize.Body,
													TextColor3 = Theme.Paper.Text,
													TextXAlignment = Enum.TextXAlignment.Left,
													[Children] = s:New("UIFlexItem")({
														FlexMode = Enum.UIFlexMode.Shrink,
													}),
												}),
												InfoTip.new(s, {
													Text = Text.get(use, `item.{entry.itemId}.desc`),
													LayoutOrder = 2,
												}),
											},
										}),
										label(
											s,
											2,
											table.concat(notes, " · "),
											Theme.TextSize.Small,
											Theme.Paper.TextMuted
										),
									},
								}),
							},
						}),
						-- buttons: one, ten, forever
						s:New("Frame")({
							LayoutOrder = 2,
							Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
							BackgroundTransparency = 1,
							[Children] = {
								s:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Horizontal,
									SortOrder = Enum.SortOrder.LayoutOrder,
									HorizontalAlignment = Enum.HorizontalAlignment.Right,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									Padding = UDim.new(0, 6),
								}),
								priceButton(1, "piece", 1, "portalshop.buyOne", "secondary"),
								priceButton(2, "piece", PACK, "portalshop.buyMany", "secondary"),
								permAction,
							},
						}),
					},
				})
			)
		end
		return out
	end)

	return {
		scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				CurrencyIcon(scope, { Currency = "dragon", Size = UDim2.fromOffset(22, 22), LayoutOrder = 1 }),
				scope:New("TextLabel")({
					LayoutOrder = 2,
					Size = UDim2.fromOffset(0, 28),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return Text.get(use, "portalshop.balance", { n = use(shards) or 0 })
					end),
					FontFace = Theme.Fonts.Display,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Heading,
				}),
			},
		}),
		-- one short line, the rules of the pieces and the everlasting stone behind its "i"
		scope:New("Frame")({
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 0, INTRO),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				scope:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.fromScale(0, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Text = Text.T(scope, "portalshop.intro.short"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					[Children] = scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink }),
				}),
				InfoTip.new(scope, { Text = Text.T(scope, "portalshop.intro"), LayoutOrder = 2 }),
			},
		}),
		scope:New("ScrollingFrame")({
			Position = UDim2.fromOffset(0, 32 + INTRO + 4),
			Size = UDim2.new(1, 0, 1, -(32 + INTRO + 4)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Paper.Rule,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
				rows :: any,
			},
		}),
	}
end

return PortalShopWindow
