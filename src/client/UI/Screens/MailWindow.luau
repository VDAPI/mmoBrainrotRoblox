--!strict
-- Mail window (DESIGN §18): parcels on the left (sender, subject, time left), the selected parcel on the
-- right (message, gold, S125 Dragon Shards and a timed title, items with tooltips) with "Collect"; "Collect all" below. Collecting only works
-- at the mailbox (the Auctioneer in the capital); the list itself can be read anywhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local Leaderboard = require(ReplicatedStorage.Shared.Logic.Leaderboard)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	-- Resolves "@key" / "#item:" message arguments (NotificationController.ResolveArgs).
	ResolveArgs: (args: any) -> { [string]: any }?,
	AtMailbox: Fusion.UsedAs<boolean>,
	-- S133: "Write a letter" (empty recipient) and "Reply" (the sender), ignoring a letter's sender
	Compose: (to: string) -> (),
	IgnoreName: (name: string) -> (),
}

local function subject(use: Fusion.Use, parcel: any, resolve: (args: any) -> { [string]: any }?): string
	-- S133: a letter from a player shows its own (filtered) subject; its args are never resolved as keys
	if parcel.from == "player" then
		if type(parcel.subject) == "string" and parcel.subject ~= "" then
			return parcel.subject
		end
		return Text.get(use, parcel.subjectKey, { name = parcel.fromName or "?" })
	end
	return Text.get(use, parcel.subjectKey, resolve(parcel.args))
end

-- S133: nothing to take: gold, items, shards, a title, tokens or cosmetics (Logic/Mail.isEmpty on the client copy).
local function isEmpty(parcel: any): boolean
	return (parcel.gold or 0) <= 0
		and #parcel.items == 0
		and (parcel.shards or 0) <= 0
		and parcel.timedTitle == nil
		and (parcel.tokens or 0) <= 0
		and (parcel.cosmetics == nil or #parcel.cosmetics == 0)
end

-- S125: "Title: <name> (until <date>)", or "(expired)" after the term.
local function titleLine(use: Fusion.Use, timed: any): string
	if type(timed) ~= "table" or type(timed.id) ~= "string" then
		return ""
	end
	local def = TitleData.get(timed.id)
	local name = if def then Text.get(use, def.nameKey) else timed.id
	local untilTs = tonumber(timed.untilTs) or 0
	if untilTs <= Clock.now() then
		return Text.get(use, "mail.titleExpired", { title = name })
	end
	return Text.get(use, "mail.title", {
		title = name,
		["until"] = Text.get(use, "leaderboard.date", Leaderboard.dateParts(untilTs)),
	})
end

-- S129: "Cosmetic: <name>" for each cosmetic of a parcel (event rewards).
local function cosmeticsLine(use: Fusion.Use, ids: any): string
	if type(ids) ~= "table" then
		return ""
	end
	local lines = {}
	for _, id in ids do
		local def = if type(id) == "string" then Cosmetics.get(id) else nil
		table.insert(lines, Text.get(use, "mail.cosmetics", { name = if def then Text.get(use, def.nameKey) else id }))
	end
	return table.concat(lines, "\n")
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
					BackgroundColor3 = if isSelected then Theme.Paper.Hover else Theme.Paper.Raised,
					BackgroundTransparency = 0.2,
					[Fusion.OnEvent("Activated")] = function()
						Sounds.play("click")
						selectedId:set(parcel.id)
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIStroke")({ Color = Theme.Paper.Border, Transparency = if isSelected then 0 else 1 }),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(10, 4),
							Size = UDim2.new(1, -20, 0, 26),
							BackgroundTransparency = 1,
							Text = `{if (parcel.shards or 0) > 0
									or parcel.timedTitle ~= nil
									or (parcel.tokens or 0) > 0
									or parcel.cosmetics ~= nil
								then "◆ "
								elseif #parcel.items > 0 then "📦 "
								elseif parcel.gold > 0 then "◉ "
								else "✉ "}{subject(use, parcel, props.ResolveArgs)}`,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(10, 30),
							Size = UDim2.new(1, -20, 0, 22),
							BackgroundTransparency = 1,
							Text = Text.get(use, "mail.row", {
								from = if parcel.from == "player" and type(parcel.fromName) == "string"
									then parcel.fromName
									else Text.get(use, `mail.from.{parcel.from}`),
								days = math.max(0, math.floor((parcel.expiresAt - now) / 86400)),
							}),
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.TextMuted,
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
					TextColor3 = Theme.Paper.TextMuted,
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
		-- S133: a scrolling column (a letter's text can be long)
		return s:New("ScrollingFrame")({
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			[Children] = {
				s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
				s:New("UIPadding")({ PaddingRight = UDim.new(0, 6) }),
				-- S133: the text of a letter from a player (filtered by Roblox when it was sent)
				s:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = if type(parcel.body) == "string" then parcel.body else "",
					Visible = type(parcel.body) == "string" and parcel.body ~= "",
					TextWrapped = true,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				s:New("TextLabel")({
					LayoutOrder = 0,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = subject(use, parcel, props.ResolveArgs),
					TextWrapped = true,
					FontFace = Theme.Fonts.Display,
					TextSize = Theme.TextSize.Large,
					TextColor3 = Theme.Paper.Heading,
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
					TextColor3 = Theme.Paper.Heading,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				-- S125: Dragon Shards and a timed title (rankings, events)
				s:New("TextLabel")({
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundTransparency = 1,
					Text = Text.get(use, "mail.shards", { n = Format.number(parcel.shards or 0) }),
					Visible = (parcel.shards or 0) > 0,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Heading,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				s:New("TextLabel")({
					LayoutOrder = 4,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = titleLine(use, parcel.timedTitle),
					Visible = parcel.timedTitle ~= nil,
					TextWrapped = true,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				-- S129: Arena Tokens and cosmetics (events)
				s:New("TextLabel")({
					LayoutOrder = 5,
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundTransparency = 1,
					Text = Text.get(use, "mail.tokens", { n = Format.number(parcel.tokens or 0) }),
					Visible = (parcel.tokens or 0) > 0,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Heading,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				s:New("TextLabel")({
					LayoutOrder = 6,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = cosmeticsLine(use, parcel.cosmetics),
					Visible = type(parcel.cosmetics) == "table" and #parcel.cosmetics > 0,
					TextWrapped = true,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				s:New("Frame")({
					LayoutOrder = 7,
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
					LayoutOrder = 8,
					Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
					Variant = "primary",
					-- S133: a letter with nothing to take is thrown away anywhere ("Delete")
					Text = Text.T(s, if isEmpty(parcel) then "mail.delete" else "mail.claim"),
					Disabled = s:Computed(function(use2): boolean
						return use2(busy) or (not isEmpty(parcel) and not use2(props.AtMailbox))
					end),
					OnClick = function()
						invoke("MailClaim", parcel.id)
					end,
				}),
				-- S133: a letter from a player: reply, send it back with its contents, ignore the sender
				s:New("Frame")({
					LayoutOrder = 9,
					Size = UDim2.new(1, 0, 0, 44),
					BackgroundTransparency = 1,
					Visible = parcel.from == "player" and type(parcel.fromName) == "string",
					[Children] = {
						s:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 6),
						}),
						Button(s, {
							LayoutOrder = 1,
							Size = UDim2.new(1 / 3, -4, 1, 0),
							TextSize = Theme.TextSize.Small,
							Text = Text.T(s, "mail.reply"),
							OnClick = function()
								props.Compose(parcel.fromName or "")
							end,
						}),
						Button(s, {
							LayoutOrder = 2,
							Size = UDim2.new(1 / 3, -4, 1, 0),
							TextSize = Theme.TextSize.Small,
							Text = Text.T(s, "mail.sendBack"),
							Visible = (parcel.gold or 0) > 0 or #parcel.items > 0,
							Disabled = busy,
							OnClick = function()
								busy:set(true)
								task.spawn(function()
									local ok, err = Net.Invoke("MailReturn", parcel.id)
									busy:set(false)
									if ok then
										Toast.push(
											Text.now("mail.sentBack", { name = parcel.fromName or "" }),
											"success"
										)
									else
										Sounds.play("error")
										Toast.push(Text.now(err or "error.internal"), "error")
									end
								end)
							end,
						}),
						Button(s, {
							LayoutOrder = 3,
							Size = UDim2.new(1 / 3, -4, 1, 0),
							TextSize = Theme.TextSize.Small,
							Variant = "danger",
							Text = Text.T(s, "mail.ignoreSender"),
							OnClick = function()
								props.IgnoreName(parcel.fromName or "")
							end,
						}),
					},
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
			BackgroundColor3 = Theme.Paper.Surface,
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
		-- S133: a new letter to another player
		Button(scope, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 250, 1, 0),
			Size = UDim2.fromOffset(200, 48),
			Variant = "primary",
			Text = Text.T(scope, "mail.write"),
			OnClick = function()
				props.Compose("")
			end,
		}),
		scope:New("TextLabel")({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.new(1, -470, 0, 48),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				return Text.get(use, if use(props.AtMailbox) then "mail.hint.here" else "mail.hint.away")
			end),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Paper.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	}
end

return MailWindow
