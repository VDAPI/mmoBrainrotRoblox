--!strict
-- S133: the friends window (key win_friends, HUD menu on a phone): tabs "Friends" and "Ignored". A friend row shows the
-- name, class and level (when known) and where the friend is: on this server with the map, in the game (another
-- server), offline or unknown (presence could not be read). Buttons: Whisper (this server), Write a letter, Invite to
-- party (this server), Remove. The ignored tab lists ignored players with "Stop ignoring" and ignores a character by
-- name. The statuses come from SocialController (FriendsStatus every Config.Social.statusRefresh while open).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Actions = {
	Whisper: (userId: number, name: string) -> (),
	Mail: (name: string) -> (),
	Party: (userId: number, name: string) -> (),
	Remove: (userId: number, name: string) -> (),
	Unignore: (userId: number, name: string) -> (),
	IgnoreName: (name: string) -> (),
}

export type Props = {
	Status: Fusion.UsedAs<{ [string]: any }>,
	Actions: Actions,
}

local STATUS_ORDER: { [string]: number } = { here = 1, online = 2, unknown = 3, offline = 4 }
local STATUS_COLOR: { [string]: Color3 } = {
	here = Color3.fromHex("#6FD38A"),
	online = Color3.fromHex("#6FB3FF"),
	unknown = Theme.Colors.TextMuted,
	offline = Theme.Colors.TextMuted,
}

local function escape(text: string): string
	return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function className(use: Fusion.Use, class: any): string
	local def = if type(class) == "string" then Classes.get(class) else nil
	return if def then Text.get(use, def.nameKey) else ""
end

local function statusText(use: Fusion.Use, status: any): string
	local s = if type(status) == "table" then status.s else nil
	if s == "here" then
		local map = Maps.get(status.m or "")
		return Text.get(use, "social.status.here", { map = if map then Text.get(use, map.nameKey) else "?" })
	elseif s == "online" then
		return Text.get(use, "social.status.online")
	elseif s == "offline" then
		return Text.get(use, "social.status.offline")
	end
	return Text.get(use, "social.status.unknown")
end

local function rowButton(s: Scope, order: number, key: string, enabled: boolean, onClick: () -> (), danger: boolean?)
	return Button(s, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(112, Theme.Size.MinTouch),
		TextSize = Theme.TextSize.Small,
		Variant = if danger then "danger" else "secondary",
		Text = Text.T(s, key),
		Disabled = not enabled,
		OnClick = onClick,
	})
end

local function row(s: Scope, order: number, title: Instance, buttons: { Instance }): Instance
	return s:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.2,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
			title,
			s:New("Frame")({
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Wraps = true,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					buttons :: any,
				},
			}),
		},
	})
end

local function titleLabel(s: Scope, text: string, sub: string, subColor: Color3): Instance
	return s:New("TextLabel")({
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		RichText = true,
		TextWrapped = true,
		Text = `<b>{escape(text)}</b>   <font color="#{subColor:ToHex()}">{escape(sub)}</font>`,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function FriendsWindow(scope: Scope, props: Props): Fusion.Child
	local tab = scope:Value("friends")
	local ignoreName = scope:Value("")
	local social = State.Value({ "account", "social" })

	local friendRows = scope:Computed(function(use, s: Scope): { Instance }
		local data = use(social)
		local statuses = use(props.Status)
		local list = {}
		if type(data) == "table" and type(data.friends) == "table" then
			for key, friend in data.friends do
				table.insert(list, { key = key, friend = friend, status = statuses[key] })
			end
		end
		table.sort(list, function(a, b)
			local sa = STATUS_ORDER[if a.status then a.status.s else "unknown"] or 3
			local sb = STATUS_ORDER[if b.status then b.status.s else "unknown"] or 3
			if sa ~= sb then
				return sa < sb
			end
			return string.lower(a.friend.name) < string.lower(b.friend.name)
		end)
		local out = {}
		for i, e in list do
			local userId = tonumber(e.key) :: number
			local status = e.status
			local here = type(status) == "table" and status.s == "here"
			local name: string = e.friend.name
			local class = if type(status) == "table" and status.c then status.c else e.friend.class
			local parts = { className(use, class) }
			if type(status) == "table" and type(status.l) == "number" then
				table.insert(parts, Text.get(use, "hud.level", { level = status.l }))
			end
			table.insert(parts, statusText(use, status))
			local color = STATUS_COLOR[if type(status) == "table" then status.s else "unknown"]
				or Theme.Colors.TextMuted
			table.insert(
				out,
				row(s, i, titleLabel(s, name, table.concat(parts, " · "), color), {
					rowButton(s, 1, "social.menu.whisper", here, function()
						props.Actions.Whisper(userId, name)
					end),
					rowButton(s, 2, "social.menu.mail", true, function()
						props.Actions.Mail(name)
					end),
					rowButton(s, 3, "social.friends.party", here, function()
						props.Actions.Party(userId, name)
					end),
					rowButton(s, 4, "social.friends.remove", true, function()
						props.Actions.Remove(userId, name)
					end, true),
				})
			)
		end
		if #out == 0 then
			table.insert(
				out,
				s:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 60),
					BackgroundTransparency = 1,
					TextWrapped = true,
					Text = Text.get(use, "social.friends.empty"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.TextMuted,
				})
			)
		end
		return out
	end)

	local ignoredRows = scope:Computed(function(use, s: Scope): { Instance }
		local data = use(social)
		local list = {}
		if type(data) == "table" and type(data.ignored) == "table" then
			for key, e in data.ignored do
				table.insert(list, { key = key, entry = e })
			end
		end
		table.sort(list, function(a, b)
			return string.lower(a.entry.name) < string.lower(b.entry.name)
		end)
		local out = {}
		for i, e in list do
			local userId = tonumber(e.key) :: number
			local name: string = e.entry.name
			table.insert(
				out,
				row(s, i, titleLabel(s, name, className(use, e.entry.class), Theme.Colors.TextMuted), {
					rowButton(s, 1, "social.menu.unignore", true, function()
						props.Actions.Unignore(userId, name)
					end),
				})
			)
		end
		if #out == 0 then
			table.insert(
				out,
				s:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 60),
					BackgroundTransparency = 1,
					TextWrapped = true,
					Text = Text.get(use, "social.ignored.empty"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.TextMuted,
				})
			)
		end
		return out
	end)

	local function count(use: Fusion.Use, field: string): number
		local data = use(social)
		local n = 0
		if type(data) == "table" and type(data[field]) == "table" then
			for _ in data[field] do
				n += 1
			end
		end
		return n
	end

	return {
		scope:New("Frame")({
			Name = "TabStrip",
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeightSmall),
			BackgroundTransparency = 1,
			[Children] = Tabs(scope, {
				Selected = tab,
				Tabs = {
					{ id = "friends", label = Text.T(scope, "social.tab.friends") },
					{ id = "ignored", label = Text.T(scope, "social.tab.ignored") },
				},
			}),
		}),
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(0, Theme.Size.ButtonHeightSmall + 6),
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			TextWrapped = true,
			Text = scope:Computed(function(use): string
				if use(tab) == "friends" then
					return Text.get(use, "social.friends.hint", {
						n = count(use, "friends"),
						max = Config.Social.maxFriends,
					})
				end
				return Text.get(
					use,
					"social.ignored.hint",
					{ n = count(use, "ignored"), max = Config.Social.maxIgnored }
				)
			end),
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("ScrollingFrame")({
			Position = UDim2.fromOffset(0, Theme.Size.ButtonHeightSmall + 50),
			Size = scope:Computed(function(use): UDim2
				local bottom = if use(tab) == "ignored" then 60 else 0
				return UDim2.new(1, 0, 1, -(Theme.Size.ButtonHeightSmall + 50 + bottom))
			end),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
				scope:Computed(function(use): any
					return if use(tab) == "friends" then use(friendRows) else use(ignoredRows)
				end) :: any,
			},
		}),
		scope:New("Frame")({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return use(tab) == "ignored"
			end),
			[Children] = {
				TextInput(scope, {
					Text = ignoreName,
					Placeholder = Text.T(scope, "social.ignored.byName"),
					MaxLength = Config.CharacterName.MaxLength,
					Size = UDim2.new(1, -170, 0, 44),
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(160, 44),
					Variant = "danger",
					Text = Text.T(scope, "social.menu.ignore"),
					Disabled = scope:Computed(function(use): boolean
						return use(ignoreName) == ""
					end),
					OnClick = function()
						props.Actions.IgnoreName(Fusion.peek(ignoreName))
						ignoreName:set("")
					end,
				}),
			},
		}),
	}
end

return FriendsWindow
