--!strict
-- Auction window, "My listings" tab: the character's listings with status (active, sold, expired,
-- cancelled), price, time left and "Cancel" for active ones. Loaded from the server when the tab opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local STATUS_COLORS: { [string]: Color3 } = {
	active = Theme.Colors.Success,
	sold = Theme.Colors.GoldBright,
	expired = Theme.Colors.Warning,
	cancelled = Theme.Colors.TextMuted,
}

local function Mine(scope: Scope, showModal: (spec: any) -> ()): Instance
	local listings = scope:Value(nil :: { any }?)
	local loading = scope:Value(false)

	local function load()
		if Fusion.peek(loading) then
			return
		end
		loading:set(true)
		task.spawn(function()
			local ok, data = Net.Invoke("AuctionMine")
			loading:set(false)
			if ok then
				listings:set(data)
			else
				Toast.push(Text.now(data or "error.internal"), "error")
			end
		end)
	end
	load()

	local function cancel(entry: any)
		showModal({
			Title = Text.now("auction.cancel.title"),
			Message = Text.now(
				"auction.cancel.confirm",
				{ item = ItemText.name(entry.item.id, entry.item.up, entry.item.el) }
			),
			ConfirmText = Text.now("auction.cancel"),
			CancelText = Text.now("common.cancel"),
			Variant = "danger",
			OnConfirm = function(): (boolean, string?)
				local ok, err = Net.Invoke("AuctionCancel", entry.id)
				load()
				if not ok then
					return false, Text.now(err or "error.internal")
				end
				Sounds.play("click")
				Toast.push(Text.now("auction.cancelled"), "info")
				return true, nil
			end,
		})
	end

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local data = use(listings)
		local list = {}
		if type(data) ~= "table" or #data == 0 then
			table.insert(
				list,
				s:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 60),
					BackgroundTransparency = 1,
					Text = Text.get(use, if use(loading) then "auction.loading" else "auction.mine.empty"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.TextMuted,
				})
			)
			return list
		end
		local now = Workspace:GetServerTimeNow()
		for i, entry in data do
			local name = ItemText.get(use, entry.item.id, entry.item.up, entry.item.el)
			local status = Text.get(use, `auction.status.{entry.status}`)
			local detail = if entry.status == "active"
				then Format.time(entry.expiresAt - now)
				elseif entry.status == "sold" then Text.get(
					use,
					"auction.mine.soldTo",
					{ name = entry.buyer or "?" }
				)
				else Text.get(use, "auction.mine.mailed")
			table.insert(
				list,
				s:New("Frame")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 64),
					BackgroundColor3 = Theme.Colors.PanelRaised,
					BackgroundTransparency = 0.3,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						ItemSlot(s, {
							SlotId = `view:mine:{entry.id}`,
							Item = entry.item,
							Size = 52,
							Position = UDim2.fromOffset(6, 6),
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(68, 6),
							Size = UDim2.new(1, -330, 0, 26),
							BackgroundTransparency = 1,
							Text = if entry.item.n > 1 then `{name} x{entry.item.n}` else name,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = ItemText.rarityColor(entry.item.rarity),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(68, 34),
							Size = UDim2.new(1, -330, 0, 22),
							BackgroundTransparency = 1,
							RichText = true,
							Text = `<font color="#{(STATUS_COLORS[entry.status] or Theme.Colors.Text):ToHex()}">{status}</font>  ·  {detail}`,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Colors.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						s:New("TextLabel")({
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -140, 0.5, 0),
							Size = UDim2.fromOffset(170, 30),
							BackgroundTransparency = 1,
							Text = `◉ {Format.number(entry.price)}`,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = Theme.Colors.GoldBright,
							TextXAlignment = Enum.TextXAlignment.Right,
						}),
						Button(s, {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -8, 0.5, 0),
							Size = UDim2.fromOffset(120, 44),
							Variant = "danger",
							TextSize = Theme.TextSize.Small,
							Text = Text.T(s, "auction.cancel"),
							Visible = entry.status == "active",
							OnClick = function()
								cancel(entry)
							end,
						}),
					},
				})
			)
		end
		return list
	end)

	return scope:New("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("ScrollingFrame")({
				Size = UDim2.new(1, 0, 1, -54),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
					rows :: any,
				},
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.fromOffset(200, 46),
				Text = Text.T(scope, "auction.refresh"),
				Disabled = loading,
				OnClick = load,
			}),
			scope:New("TextLabel")({
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.new(1, -220, 0, 46),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "auction.mine.hint"),
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		},
	})
end

return Mine
