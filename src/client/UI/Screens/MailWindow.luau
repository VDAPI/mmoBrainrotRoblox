--!strict
-- Mail window (DESIGN §18): parcels on the left (sender, subject, time left), the selected parcel on the
-- right (message, gold, items with tooltips) with "Collect"; "Collect all" below. Collecting only works
-- at the mailbox (the Auctioneer in the capital); the list itself can be read anywhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	-- Resolves "@key" / "#item:" message arguments (NotificationController.ResolveArgs).
	ResolveArgs: (args: any) -> { [string]: any }?,
	AtMailbox: Fusion.UsedAs<boolean>,
}

local function subject(use: Fusion.Use, parcel: any, resolve: (args: any) -> { [string]: any }?): string
	return Text.get(use, parcel.subjectKey, resolve(parcel.args))
end

local function MailWindow(scope: Scope, props: Props): Fusion.Child
	local mail = State.Value({ "mail" })
	local selectedId = scope:Value(nil :: string?)
	local busy = scope:Value(false)

	local parcels = scope:Computed(function(use): { any }
		local m = use(mail)
		return if type(m) == "table" then m.list else {}
	end)
	local selected = scope:Computed(function(use): any
		local id = use(selectedId)
		for _, parcel in use(parcels) do
			if parcel.id == id then
				return parcel
			end
		end
		return use(parcels)[1]
	end)

	local function invoke(name: string, ...: any)
		busy:set(true)
		local args = table.pack(...)
		task.spawn(function()
			local ok, err, count = Net.Invoke(name, table.unpack(args, 1, args.n))
			busy:set(false)
			if ok then
				Sounds.play("levelUp")
				Toast.push(Text.now("mail.claimed", { n = count or 1 }), "success")
			else
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	local listRows = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		local now = Workspace:GetServerTimeNow()
		for i, parcel in use(parcels) do
			local isSelected = use(selected) == parcel
			table.insert(
				list,
				s:New("TextButton")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 58),
					AutoButtonColor = false,
					Text = "",
					BackgroundColor3 = if isSelected then Theme.Colors.PanelHover else Theme.Colors.PanelRaised,
					BackgroundTransparency = 0.2,
					[Fusion.OnEvent("Activated")] = function()
						Sounds.play("click")
						selectedId:set(parcel.id)
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIStroke")({ Color = Theme.Colors.Gold, Transparency = if isSelected then 0 else 1 }),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(10, 4),
							Size = UDim2.new(1, -20, 0, 26),
							BackgroundTransparency = 1,
							Text = `{if #parcel.items > 0 then "📦 " elseif parcel.gold > 0 then "◉ " else "✉ "}{subject(
								use,
								parcel,
								props.ResolveArgs
							)}`,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Colors.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(10, 30),
							Size = UDim2.new(1, -20, 0, 22),
							BackgroundTransparency = 1,
							Text = Text.get(use, "mail.row", {
								from = Text.get(use, `mail.from.{parcel.from}`),
								days = math.max(0, math.floor((parcel.expiresAt - now) / 86400)),
							}),
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Colors.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
					} :: any,
				})
			)
		end
		if #list == 0 then
			table.insert(
				list,
				s:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 60),
					BackgroundTransparency = 1,
					Text = Text.get(use, "mail.empty"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.TextMuted,
				})
			)
		end
		return list
	end)

	local preview = scope:Computed(function(use, s: Scope): Instance?
		local parcel = use(selected)
		if not parcel then
			return nil
		end
		local itemSlots = {}
		for i, item in parcel.items do
			table.insert(
				itemSlots,
				ItemSlot(s, { SlotId = `view:mail:{parcel.id}:{i}`, Item = item, Size = 60, LayoutOrder = i })
			)
		end
		return s:New("Frame")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			[Children] = {
				s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
				s:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = subject(use, parcel, props.ResolveArgs),
					TextWrapped = true,
					FontFace = Theme.Fonts.Heading,
					TextSize = Theme.TextSize.Large,
					TextColor3 = Theme.Colors.GoldBright,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				s:New("TextLabel")({
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundTransparency = 1,
					Text = Text.get(use, "mail.gold", { gold = Format.number(parcel.gold) }),
					Visible = parcel.gold > 0,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.GoldBright,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				s:New("Frame")({
					LayoutOrder = 3,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = {
						s:New("UIGridLayout")({
							CellSize = UDim2.fromOffset(60, 60),
							CellPadding = UDim2.fromOffset(6, 6),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						itemSlots :: any,
					},
				}),
				Button(s, {
					LayoutOrder = 4,
					Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
					Variant = "primary",
					Text = Text.T(s, "mail.claim"),
					Disabled = s:Computed(function(use2): boolean
						return use2(busy) or not use2(props.AtMailbox)
					end),
					OnClick = function()
						invoke("MailClaim", parcel.id)
					end,
				}),
			},
		})
	end)

	return {
		scope:New("ScrollingFrame")({
			Size = UDim2.new(0.45, -6, 1, -56),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
				listRows :: any,
			},
		}),
		scope:New("Frame")({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.55, -6, 1, -56),
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.3,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 12),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),
				preview :: any,
			},
		}),
		Button(scope, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromOffset(240, 48),
			Text = Text.T(scope, "mail.claimAll"),
			Disabled = scope:Computed(function(use): boolean
				return use(busy) or not use(props.AtMailbox) or #use(parcels) == 0
			end),
			OnClick = function()
				invoke("MailClaimAll")
			end,
		}),
		scope:New("TextLabel")({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.new(1, -260, 0, 48),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				return Text.get(use, if use(props.AtMailbox) then "mail.hint.here" else "mail.hint.away")
			end),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	}
end

return MailWindow
