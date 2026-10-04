--!strict
-- Party window (P): members with class, level, HP/mana, leader crown; invite by name; leave; the leader can
-- kick and promote; party chat toggle; the loot rules (DESIGN §17).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function invoke(name: string, ...: any): boolean
	local ok, err = Net.Invoke(name, ...)
	if not ok then
		Sounds.play("error")
		Toast.push(Text.now(err or "error.internal"), "error")
	end
	return ok
end

-- Points the chat input at the party channel (or back to the general one).
local function setChat(party: boolean): boolean
	local config = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if not config then
		return false
	end
	if party then
		for _, channel in TextChatService:GetDescendants() do
			if channel:IsA("TextChannel") and channel:GetAttribute("VaelthornChannel") == "party" then
				config.TargetTextChannel = channel
				return true
			end
		end
		return false
	end
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general and general:IsA("TextChannel") then
		config.TargetTextChannel = general
	end
	return true
end

local function bar(scope: Scope, ratio: Fusion.UsedAs<number>, color: Color3, y: number): Instance
	return scope:New("Frame")({
		Position = UDim2.fromOffset(70, y),
		Size = UDim2.new(1, -250, 0, 10),
		BackgroundColor3 = Theme.Colors.Background,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			scope:New("Frame")({
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromScale(math.clamp(use(ratio), 0, 1), 1)
				end),
				BackgroundColor3 = color,
				[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			}),
		},
	})
end

local function PartyWindow(scope: Scope): Fusion.Child
	local party = State.Value({ "party" })
	local myId = game:GetService("Players").LocalPlayer.UserId
	local inviteName = scope:Value("")
	local partyChat = scope:Value(false)

	local amLeader = scope:Computed(function(use): boolean
		local p = use(party)
		return type(p) ~= "table" or p.leader == myId
	end)

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local p = use(party)
		local list = {}
		if type(p) ~= "table" then
			table.insert(
				list,
				s:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 60),
					BackgroundTransparency = 1,
					Text = Text.get(use, "party.none"),
					TextWrapped = true,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.TextMuted,
				})
			)
			return list
		end
		for i, member in p.members do
			local class = Classes.get(member.class)
			local isLeader = member.id == p.leader
			table.insert(
				list,
				s:New("Frame")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 64),
					BackgroundColor3 = Theme.Colors.PanelRaised,
					BackgroundTransparency = 0.35,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(8, 8),
							Size = UDim2.fromOffset(48, 48),
							BackgroundColor3 = Theme.Colors.Panel,
							Text = if class then class.icon else "?",
							TextScaled = true,
							TextColor3 = Theme.Colors.GoldBright,
							FontFace = Theme.Fonts.BodyBold,
							[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(70, 6),
							Size = UDim2.new(1, -250, 0, 24),
							BackgroundTransparency = 1,
							Text = `{if isLeader then "♛ " else ""}{member.name}  ·  {Text.get(use, "hud.level", {
								level = member.level,
							})}{if member.dead then " ☠" else ""}`,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = if isLeader then Theme.Colors.GoldBright else Theme.Colors.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						bar(s, member.hp / math.max(1, member.maxHp), Theme.Colors.Hp, 34),
						bar(s, member.mana / math.max(1, member.maxMana), Theme.Colors.Mana, 48),
						Button(s, {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -92, 0.5, 0),
							Size = UDim2.fromOffset(84, 40),
							TextSize = Theme.TextSize.Small,
							Text = Text.T(s, "party.promote"),
							Visible = use(amLeader) and member.id ~= myId,
							OnClick = function()
								task.spawn(invoke, "PartyPromote", member.id)
							end,
						}),
						Button(s, {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -6, 0.5, 0),
							Size = UDim2.fromOffset(80, 40),
							TextSize = Theme.TextSize.Small,
							Variant = "danger",
							Text = Text.T(s, "party.kick"),
							Visible = use(amLeader) and member.id ~= myId,
							OnClick = function()
								task.spawn(invoke, "PartyKick", member.id)
							end,
						}),
					},
				})
			)
		end
		return list
	end)

	return {
		scope:New("Frame")({
			Name = "Invite",
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundTransparency = 1,
			[Children] = {
				TextInput(scope, {
					Size = UDim2.new(1, -170, 0, 44),
					Text = inviteName,
					Placeholder = Text.T(scope, "party.invitePlaceholder"),
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(160, 44),
					Variant = "primary",
					Text = Text.T(scope, "party.invite"),
					OnClick = function()
						local name = Fusion.peek(inviteName)
						if name == "" then
							return
						end
						task.spawn(function()
							if invoke("PartyInvite", name) then
								Toast.push(Text.now("party.inviteSent", { name = name }), "success")
								inviteName:set("")
							end
						end)
					end,
				}),
			},
		}),
		scope:New("ScrollingFrame")({
			Position = UDim2.fromOffset(0, 58),
			Size = UDim2.new(1, 0, 1, -196),
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
		scope:New("TextLabel")({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -58),
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundTransparency = 1,
			Text = Text.T(scope, "party.rules"),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		scope:New("Frame")({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return type(use(party)) == "table"
			end),
			[Children] = {
				Button(scope, {
					Size = UDim2.fromOffset(220, 46),
					Text = scope:Computed(function(use): string
						return Text.get(use, if use(partyChat) then "party.chatParty" else "party.chatGeneral")
					end),
					OnClick = function()
						local want = not Fusion.peek(partyChat)
						if setChat(want) then
							partyChat:set(want)
						end
					end,
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(180, 46),
					Variant = "danger",
					Text = Text.T(scope, "party.leave"),
					OnClick = function()
						setChat(false)
						partyChat:set(false)
						task.spawn(invoke, "PartyLeave")
					end,
				}),
			},
		}),
	}
end

return PartyWindow
