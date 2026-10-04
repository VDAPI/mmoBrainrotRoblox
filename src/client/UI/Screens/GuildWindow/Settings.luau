--!strict
-- Guild window, "Settings" tab: PvP protection between members (leader switches it), chat channel hint,
-- leave the guild, disband it (leader, confirmed by typing the guild name).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Common = require(script.Parent.Common)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Guild = require(ReplicatedStorage.Shared.Logic.Guild)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function paragraph(scope: Scope, order: number, text: Fusion.UsedAs<string>, height: number): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		Text = text,
		TextWrapped = true,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Colors.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end

local function Settings(scope: Scope, showModal: (spec: any) -> ()): Instance
	local guild = State.Value({ "guild" })
	local protection = scope:Computed(function(use): boolean
		local g = use(guild)
		return type(g) ~= "table" or g.settings == nil or g.settings.guildPvpProtection ~= false
	end)
	local isLeader = scope:Computed(function(use): boolean
		local g = use(guild)
		return type(g) == "table" and g.myRank == "leader"
	end)

	return scope:New("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			Common.list(scope, 10),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "guild.settings.pvp"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			paragraph(scope, 2, Text.T(scope, "guild.settings.pvpHint"), 44),
			Button(scope, {
				LayoutOrder = 3,
				Size = UDim2.fromOffset(300, 46),
				Variant = scope:Computed(function(use): any
					return if use(protection) then "primary" else "secondary"
				end),
				Disabled = scope:Computed(function(use): boolean
					local g = use(guild)
					return not (type(g) == "table" and Guild.can(g.myRank, "settings"))
				end),
				Text = scope:Computed(function(use): string
					return Text.get(use, if use(protection) then "guild.settings.pvpOn" else "guild.settings.pvpOff")
				end),
				OnClick = function()
					task.spawn(Common.invoke, "GuildSetting", "guildPvpProtection", not Fusion.peek(protection))
				end,
			}),
			paragraph(scope, 4, Text.T(scope, "guild.settings.chatHint"), 44),
			paragraph(
				scope,
				5,
				scope:Computed(function(use): string
					return if use(isLeader) then Text.get(use, "guild.settings.leaderHint") else ""
				end),
				44
			),
			scope:New("Frame")({
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundTransparency = 1,
				[Children] = {
					Button(scope, {
						Size = UDim2.fromOffset(220, 46),
						Variant = "danger",
						Text = Text.T(scope, "guild.leave"),
						OnClick = function()
							showModal({
								Title = Text.now("guild.leave"),
								Message = Text.now("guild.leave.confirm"),
								ConfirmText = Text.now("common.confirm"),
								CancelText = Text.now("common.cancel"),
								Variant = "danger",
								OnConfirm = function()
									return Common.modalInvoke("GuildLeave")
								end,
							})
						end,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(240, 46),
						Variant = "danger",
						Visible = isLeader,
						Text = Text.T(scope, "guild.disband"),
						OnClick = function()
							local g = State.Get({ "guild" })
							if not g then
								return
							end
							showModal({
								Title = Text.now("guild.disband"),
								Message = Text.now("guild.disband.confirm", { name = g.name }),
								ConfirmText = Text.now("guild.disband"),
								CancelText = Text.now("common.cancel"),
								Variant = "danger",
								Input = { Placeholder = g.name, MustMatch = g.name, MaxLength = 20 },
								OnConfirm = function(text: string)
									return Common.modalInvoke("GuildDisband", text)
								end,
							})
						end,
					}),
				},
			}),
		},
	})
end

return Settings
