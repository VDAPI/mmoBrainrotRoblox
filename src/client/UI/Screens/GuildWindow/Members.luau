--!strict
-- Guild window, "Members" tab: invite by name (with the permission), the member list (online first) with
-- class, level, rank, online here / on another server / offline, contribution, and the actions the own
-- rank allows: promote/demote and hand over leadership (leader), kick (higher rank only).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Common = require(script.Parent.Common)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Guild = require(ReplicatedStorage.Shared.Logic.Guild)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local RANK_COLORS: { [string]: Color3 } = {
	leader = Theme.Colors.GoldBright,
	officer = Theme.Colors.Accent,
	member = Theme.Colors.TextMuted,
}

local function Members(scope: Scope, showModal: (spec: any) -> ()): Instance
	local guild = State.Value({ "guild" })
	local inviteName = scope:Value("")

	local canInvite = scope:Computed(function(use): boolean
		local g = use(guild)
		return type(g) == "table" and Guild.can(g.myRank, "invite")
	end)

	local function confirm(
		titleKey: string,
		messageKey: string,
		name: string,
		variant: string,
		fn: () -> (boolean, string?)
	)
		showModal({
			Title = Text.now(titleKey),
			Message = Text.now(messageKey, { name = name }),
			ConfirmText = Text.now("common.confirm"),
			CancelText = Text.now("common.cancel"),
			Variant = variant,
			OnConfirm = function()
				return fn()
			end,
		})
	end

	local function actionButton(s: Scope, order: number, key: string, variant: string?, onClick: () -> ()): Instance
		return Button(s, {
			LayoutOrder = order,
			Size = UDim2.fromOffset(104, 38),
			TextSize = Theme.TextSize.Small,
			Variant = variant :: any,
			Text = Text.T(s, key),
			OnClick = onClick,
		})
	end

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local g = use(guild)
		local list = {}
		if type(g) ~= "table" then
			return list
		end
		local ordered: { any } = table.clone(g.members)
		local index: { [any]: number } = {}
		for i, member in g.members do
			index[member] = i
		end
		table.sort(ordered, function(a, b)
			if a.online ~= b.online then
				return a.online
			end
			return index[a] < index[b]
		end)
		for i, member in ordered do
			local class = Classes.get(member.class)
			local isMe = member.key == g.myKey
			local actions = {}
			if not isMe then
				if Guild.can(g.myRank, "promote") and member.rank ~= "leader" then
					local promote = member.rank == "member"
					table.insert(
						actions,
						actionButton(s, 1, if promote then "guild.promote" else "guild.demote", nil, function()
							task.spawn(
								Common.invoke,
								"GuildSetRank",
								member.key,
								if promote then "officer" else "member"
							)
						end)
					)
					table.insert(
						actions,
						actionButton(s, 2, "guild.transfer", nil, function()
							confirm("guild.transfer.title", "guild.transfer.confirm", member.name, "primary", function()
								return Common.modalInvoke("GuildTransfer", member.key)
							end)
						end)
					)
				end
				if Guild.can(g.myRank, "kick") and Guild.outranks(g.myRank, member.rank) then
					table.insert(
						actions,
						actionButton(s, 3, "guild.kick", "danger", function()
							confirm("guild.kick.title", "guild.kick.confirm", member.name, "danger", function()
								return Common.modalInvoke("GuildKick", member.key)
							end)
						end)
					)
				end
			end
			local status = if member.server == "here"
				then Text.get(use, "guild.online.here")
				elseif member.online then Text.get(use, "guild.online.other", { server = member.server or "?" })
				else Text.get(use, "guild.offline")
			table.insert(
				list,
				s:New("Frame")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 64),
					BackgroundColor3 = Theme.Colors.PanelRaised,
					BackgroundTransparency = if member.online then 0.2 else 0.6,
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
						s:New("Frame")({
							Name = "Dot",
							Position = UDim2.fromOffset(46, 46),
							Size = UDim2.fromOffset(12, 12),
							BackgroundColor3 = if member.server == "here"
								then Theme.Colors.Success
								elseif member.online then Theme.Colors.Accent
								else Theme.Colors.Border,
							[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(68, 6),
							Size = UDim2.new(1, -420, 0, 26),
							BackgroundTransparency = 1,
							Text = `{if member.rank == "leader" then "♛ " else ""}{member.name}  ·  {Text.get(
								use,
								"hud.level",
								{ level = member.level }
							)}`,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = if isMe then Theme.Colors.GoldBright else Theme.Colors.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(68, 34),
							Size = UDim2.new(1, -420, 0, 22),
							BackgroundTransparency = 1,
							RichText = true,
							Text = `<font color="#{RANK_COLORS[member.rank]:ToHex()}">{Text.get(
								use,
								`guild.rank.{member.rank}`
							)}</font>  ·  {status}  ·  ◉ {Format.number(member.contributed)}`,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Colors.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("Frame")({
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -8, 0.5, 0),
							Size = UDim2.fromOffset(330, 40),
							BackgroundTransparency = 1,
							[Children] = {
								s:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Horizontal,
									HorizontalAlignment = Enum.HorizontalAlignment.Right,
									SortOrder = Enum.SortOrder.LayoutOrder,
									Padding = UDim.new(0, 6),
								}),
								actions :: any,
							},
						}),
					},
				})
			)
		end
		return list
	end)

	local function invite()
		local name = Fusion.peek(inviteName)
		if name == "" then
			return
		end
		task.spawn(function()
			if Common.invoke("GuildInviteName", name) then
				Toast.push(Text.now("guild.inviteSent", { name = name }), "success")
				inviteName:set("")
			end
		end)
	end

	return scope:New("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("Frame")({
				Name = "Invite",
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundTransparency = 1,
				Visible = canInvite,
				[Children] = {
					TextInput(scope, {
						Size = UDim2.new(1, -170, 0, 44),
						Text = inviteName,
						Placeholder = Text.T(scope, "guild.invitePlaceholder"),
						OnSubmit = invite,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(160, 44),
						Variant = "primary",
						Text = Text.T(scope, "guild.invite"),
						OnClick = invite,
					}),
				},
			}),
			scope:New("ScrollingFrame")({
				Position = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(0, if use(canInvite) then 56 else 0)
				end),
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 1, if use(canInvite) then -56 else 0)
				end),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				[Children] = {
					Common.list(scope, 6),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
					rows :: any,
				},
			}),
		},
	})
end

return Members
