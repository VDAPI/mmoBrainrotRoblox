--!strict
-- S133: writing a letter to another player (DESIGN §18): the recipient's character name (friends as suggestions),
-- a subject, the text, gold and up to Config.PlayerMail.maxItems whole stacks from the backpack (unbound, without the
-- padlock). The postage and today's count are shown before sending; gold and items leave only at the mailbox (the
-- Auctioneer), a plain letter goes from anywhere. The server checks, filters and sends everything (MailService).
-- 2026-10-21 (owner: too many detailed descriptions): a one-line intro (the mailbox line under the form says the rest
-- when it matters), the rule for items behind the "i" of the items label.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local MailDraft = require(script.Parent.Parent.MailDraft)
local Net = require(ReplicatedStorage.Shared.Net)
local NumberInput = require(script.Parent.Parent.Components.NumberInput)
local SelectableSlot = require(script.Parent.Parent.Components.SelectableSlot)
local Social = require(ReplicatedStorage.Shared.Logic.Social)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children, OnChange = Fusion.Children, Fusion.OnChange

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	AtMailbox: Fusion.UsedAs<boolean>,
	Close: () -> (),
}

local RULES = Config.PlayerMail
local LABEL_W = 110

local function label(scope: Scope, key: string, order: number): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = Text.T(scope, key),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Paper.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- 2026-10-21 (owner: too many detailed descriptions): a field label with an "i" after it holding the rule.
local function labelWithInfo(scope: Scope, key: string, infoKey: string, order: number): Instance
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 22),
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
				Text = Text.T(scope, key),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				[Children] = scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink }),
			}),
			InfoTip.new(scope, { Text = Text.T(scope, infoKey), LayoutOrder = 2 }),
		},
	})
end

local function clampText(text: string, max: number): string
	local length = utf8.len(text)
	if length == nil or length <= max then
		return text
	end
	local cut = utf8.offset(text, max + 1)
	return if cut then string.sub(text, 1, cut - 1) else text
end

local function MailCompose(scope: Scope, props: Props): Fusion.Child
	local subject = scope:Value("")
	local body = scope:Value("")
	local gold = scope:Value(0)
	local picked = scope:Value({} :: { [string]: number }) -- item uid -> backpack slot
	local busy = scope:Value(false)

	-- A new "write to ..." starts a clean letter.
	scope:Observer(MailDraft.Fresh):onChange(function()
		subject:set("")
		body:set("")
		gold:set(0)
		picked:set({})
	end)

	local myGold = scope:Computed(function(use): number
		local g = use(State.Value({ "character", "gold" }))
		return if type(g) == "number" then g else 0
	end)
	local pickedCount = scope:Computed(function(use): number
		local n = 0
		for _ in use(picked) do
			n += 1
		end
		return n
	end)
	local fee = scope:Computed(function(use): number
		return Social.letterFee(use(pickedCount))
	end)

	-- Friends whose name starts with what was typed (up to six), as quick picks.
	local suggestions = scope:Computed(function(use, s: Scope): { Instance }
		local social = use(State.Value({ "account", "social" }))
		local typed = string.lower(use(MailDraft.To))
		local names: { string } = {}
		if type(social) == "table" and type(social.friends) == "table" then
			for _, friend in social.friends do
				local name = friend.name
				if type(name) == "string" and string.sub(string.lower(name), 1, #typed) == typed then
					table.insert(names, name)
				end
			end
		end
		table.sort(names)
		local out = {}
		for i, name in names do
			if i > 6 or string.lower(name) == typed then
				continue
			end
			table.insert(
				out,
				Button(s, {
					LayoutOrder = i,
					Size = UDim2.fromOffset(120, 34),
					TextSize = Theme.TextSize.Small,
					Text = name,
					OnClick = function()
						MailDraft.To:set(name)
					end,
				})
			)
		end
		return out
	end)

	-- Backpack items that may go into a letter.
	local itemRows = scope:Computed(function(use, s: Scope): { Instance }
		local inventory = use(State.Value({ "character", "inventory" }))
		local slots: { number } = {}
		if type(inventory) == "table" then
			for key, item in inventory do
				local index = tonumber(key)
				if index and Social.mailableItem(item) then
					table.insert(slots, index)
				end
			end
		end
		table.sort(slots)
		local out = {}
		for order, index in slots do
			local item = inventory[tostring(index)]
			table.insert(
				out,
				SelectableSlot(s, {
					Id = `mail:{index}`,
					Item = item,
					Size = 56,
					LayoutOrder = order,
					Selected = s:Computed(function(use2): boolean
						return use2(picked)[item.uid] ~= nil
					end),
					OnToggle = function()
						local current = table.clone(Fusion.peek(picked))
						if current[item.uid] then
							current[item.uid] = nil
						elseif Fusion.peek(pickedCount) < RULES.maxItems then
							current[item.uid] = index
						else
							Sounds.play("error")
							Toast.push(Text.now("mail.error.tooManyItems"), "error")
							return
						end
						picked:set(current)
					end,
				})
			)
		end
		if #out == 0 then
			table.insert(
				out,
				s:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 1,
					Text = Text.get(use, "mail.compose.noItems"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.TextMuted,
				})
			)
		end
		return out
	end)

	local function send()
		local slots: { number } = {}
		for _, index in Fusion.peek(picked) do
			table.insert(slots, index)
		end
		table.sort(slots)
		local letter = {
			to = Fusion.peek(MailDraft.To),
			subject = Fusion.peek(subject),
			body = Fusion.peek(body),
			gold = math.max(0, math.floor(Fusion.peek(gold))),
			items = slots,
		}
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("MailSend", letter)
			busy:set(false)
			if ok then
				Sounds.play("levelUp")
				Toast.push(Text.now("mail.sent", { name = letter.to }), "success")
				MailDraft.To:set("")
				MailDraft.Fresh:set(Fusion.peek(MailDraft.Fresh) + 1)
				props.Close()
			else
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal", { level = RULES.minLevel }), "error")
			end
		end)
	end

	local needsMailbox = scope:Computed(function(use): boolean
		return Social.needsMailbox(use(gold), use(pickedCount))
	end)

	return {
		scope:New("ScrollingFrame")({
			Size = UDim2.new(1, 0, 1, -60),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
				scope:New("TextLabel")({
					LayoutOrder = 0,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = Text.T(scope, "mail.compose.intro"),
					TextWrapped = true,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				label(scope, "mail.compose.to", 1),
				TextInput(scope, {
					LayoutOrder = 2,
					Text = MailDraft.To,
					Placeholder = Text.T(scope, "mail.compose.toHint"),
					MaxLength = Config.CharacterName.MaxLength,
					Size = UDim2.new(1, 0, 0, 44),
				}),
				scope:New("Frame")({
					LayoutOrder = 3,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							Wraps = true,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 6),
						}),
						suggestions :: any,
					},
				}),
				label(scope, "mail.compose.subject", 4),
				TextInput(scope, {
					LayoutOrder = 5,
					Text = subject,
					Placeholder = Text.T(scope, "mail.compose.subjectHint"),
					MaxLength = RULES.subjectMax,
					Size = UDim2.new(1, 0, 0, 44),
				}),
				label(scope, "mail.compose.body", 6),
				scope:New("Frame")({
					LayoutOrder = 7,
					Size = UDim2.new(1, 0, 0, 130),
					BackgroundColor3 = Theme.Paper.Raised,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						scope:New("UIStroke")({ Color = Theme.Paper.Rule }),
						scope:New("TextBox")({
							Position = UDim2.fromOffset(10, 8),
							Size = UDim2.new(1, -20, 1, -34),
							BackgroundTransparency = 1,
							ClearTextOnFocus = false,
							MultiLine = true,
							TextWrapped = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Top,
							PlaceholderText = Text.T(scope, "mail.compose.bodyHint"),
							PlaceholderColor3 = Theme.Paper.TextMuted,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Body,
							TextColor3 = Theme.Paper.Text,
							Text = body,
							[OnChange("Text")] = function(text: string)
								local clamped = clampText(text, RULES.bodyMax)
								if clamped ~= Fusion.peek(body) then
									body:set(clamped)
								end
							end,
						}),
						scope:New("TextLabel")({
							AnchorPoint = Vector2.new(1, 1),
							Position = UDim2.new(1, -8, 1, -4),
							Size = UDim2.fromOffset(120, 20),
							BackgroundTransparency = 1,
							Text = scope:Computed(function(use): string
								return `{utf8.len(use(body)) or 0} / {RULES.bodyMax}`
							end),
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Right,
						}),
					},
				}),
				scope:New("Frame")({
					LayoutOrder = 8,
					Size = UDim2.new(1, 0, 0, 44),
					BackgroundTransparency = 1,
					[Children] = {
						scope:New("TextLabel")({
							Size = UDim2.new(0, LABEL_W, 1, 0),
							BackgroundTransparency = 1,
							Text = Text.T(scope, "mail.compose.gold"),
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						scope:New("Frame")({
							Position = UDim2.fromOffset(LABEL_W, 0),
							Size = UDim2.fromOffset(220, 44),
							BackgroundTransparency = 1,
							[Children] = {
								NumberInput(scope, {
									Value = gold,
									Min = 0,
									Max = 1e9,
									Size = UDim2.fromOffset(220, 44),
								}),
							},
						}),
					},
				}),
				labelWithInfo(scope, "mail.compose.items", "mail.compose.items.info", 9),
				scope:New("Frame")({
					LayoutOrder = 10,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = {
						scope:New("UIGridLayout")({
							CellSize = UDim2.fromOffset(56, 56),
							CellPadding = UDim2.fromOffset(6, 6),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						itemRows :: any,
					},
				}),
			},
		}),
		scope:New("TextLabel")({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, -230, 0, 52),
			BackgroundTransparency = 1,
			TextWrapped = true,
			Text = scope:Computed(function(use): string
				local character = use(State.Value({ "character" }))
				local counter = if type(character) == "table" then character.mailSent else nil
				local line = Text.get(use, "mail.compose.fee", {
					fee = Format.number(use(fee)),
					sent = Social.sentToday(counter, Workspace:GetServerTimeNow()),
					max = RULES.perDay,
				})
				if use(needsMailbox) and not use(props.AtMailbox) then
					line ..= "\n" .. Text.get(use, "mail.compose.atMailbox")
				end
				return line
			end),
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = scope:Computed(function(use): Color3
				return if use(needsMailbox) and not use(props.AtMailbox)
					then Theme.Paper.Danger
					else Theme.Paper.TextMuted
			end),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Button(scope, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(220, 48),
			Variant = "primary",
			Text = Text.T(scope, "mail.compose.send"),
			Disabled = scope:Computed(function(use): boolean
				return use(busy)
					or use(MailDraft.To) == ""
					or (use(subject) == "" and use(body) == "")
					or use(gold) + use(fee) > use(myGold)
					or (use(needsMailbox) and not use(props.AtMailbox))
			end),
			OnClick = send,
		}),
	}
end

return MailCompose
