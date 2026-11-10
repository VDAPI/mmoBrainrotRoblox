--!strict
-- S133: the friends window (key win_friends, HUD menu on a phone): tabs "Friends" and "Ignored".
-- S150 friends 2.0: the server publishes the runtime branch `friends` while the window is open (FriendService):
--   * header: "In the game n / max", the time of the last refresh ("refreshing..." while a row waits for the read
--     budget) and two settings: Invisible (account.settings.appearOffline) and who may join (friendJoin);
--   * a friend row: class icon, name, class, level, where (Logic/Presence.label: this server with the map, another server with the
--     map and level, private server, arena, tournament, offline, unknown) and the server tag (friends on the same
--     other server sort next to each other); buttons from Logic/Social.friendRowEntries: Join (primary; greyed with
--     the reason line from Logic/FriendJoin.canJoin), Invite to party, Whisper, Write a letter, "..." (Remove, Ignore).
--     On a phone only Join stays in the row; the rest goes to the action sheet of "...";
--   * "Roblox friends in the game": character name, status, Join and Add friend (a request needs the same server).
-- The ignored tab lists ignored players with "Stop ignoring" and ignores a character by name; 2026-10-21: its header
-- is the count only, what ignoring does sits behind an "i" (Components/InfoLine).
-- Owner 2026-11-10 ("bardzo dużo napisów, niektóre rzeczy zasłaniają inne"; UI plan E, Logic/WorldLayout.friends): a row
-- is one row of 56 (the name and the state, the reason under it, the buttons at its right): Join and "⋯" on touch,
-- Join, Whisper and "⋯" on PC (the party invite and the letter go to the "⋯" sheet). A phone shows the online count
-- beside the tabs and only the two switches under them, so at least three friends show.
-- UI package C (same owner note): the tab strip and the phone's online count are Theme.Size.TabHeight (44) high, as
-- Components/Tabs draws the tabs (their frame was 40); a row stays 56 (WorldLayout.friends says why).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Device = require(script.Parent.Parent.Device)
local FriendJoin = require(ReplicatedStorage.Shared.Logic.FriendJoin)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoLine = require(script.Parent.Parent.Components.InfoLine)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local Presence = require(ReplicatedStorage.Shared.Logic.Presence)
local Social = require(ReplicatedStorage.Shared.Logic.Social)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Theme)
local WorldLayout = require(ReplicatedStorage.Shared.Logic.WorldLayout)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Actions = {
	Join: (userId: number) -> (),
	Party: (userId: number, name: string, here: boolean) -> (),
	Whisper: (userId: number, name: string) -> (),
	Mail: (name: string) -> (),
	Remove: (userId: number, name: string) -> (),
	Ignore: (userId: number, name: string) -> (),
	AddFriend: (userId: number) -> (),
	Unignore: (userId: number, name: string) -> (),
	IgnoreName: (name: string) -> (),
	Sheet: (title: string, entries: { Social.MenuEntry }, run: (id: string) -> ()) -> (),
	Setting: (name: string, value: any) -> (),
}

export type Props = {
	Actions: Actions,
}

-- A row's buttons: Join 128, the others 112, "⋯" 52, 6 apart.
local BUTTON_GAP = 6
local MORE = "⋯"

local STATUS_COLOR: { [string]: Color3 } = {
	here = Theme.Paper.Success,
	world = Theme.Paper.Link,
	private = Theme.Paper.Link,
	arena = Theme.Paper.Link,
	tournament = Theme.Paper.Link,
	unknown = Theme.Paper.TextMuted,
	offline = Theme.Paper.TextMuted,
}

local function escape(text: string): string
	return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function className(use: Fusion.Use, class: any): string
	local def = if type(class) == "string" then Classes.get(class) else nil
	return if def then Text.get(use, def.nameKey) else ""
end

-- The class icon in the class colour before a name (RichText), "" without a class.
local function classIcon(class: any): string
	local def = if type(class) == "string" then Classes.get(class) else nil
	return if def then `<font color="{Theme.readableHex(def.color)}">{def.icon}</font> ` else ""
end

-- "class · level · status · Server TAG" of a row of the `friends` branch.
local function describe(use: Fusion.Use, row: any, fallbackClass: string?): string
	local status: Presence.Status = (
		if type(row) == "table" and type(row.s) == "string" then row.s else "unknown"
	) :: any
	local parts = {}
	local class = className(use, if type(row) == "table" and row.cls then row.cls else fallbackClass)
	if class ~= "" then
		table.insert(parts, class)
	end
	if status == "here" and type(row.lvl) == "number" then
		table.insert(parts, Text.get(use, "hud.level", { level = row.lvl }))
	end
	local key, args = Presence.label(status, nil)
	if type(row) == "table" then
		local map = Maps.get(if type(row.map) == "string" then row.map else "")
		args.map = if map then Text.get(use, map.nameKey) else "?"
		args.lvl = if type(row.lvl) == "number" then row.lvl else "?"
	end
	table.insert(parts, Text.get(use, key, args))
	if type(row) == "table" and type(row.tag) == "string" and status ~= "here" then
		table.insert(parts, Text.get(use, "friends.server", { tag = row.tag }))
	end
	if type(row) == "table" and row.r then
		table.insert(parts, Text.get(use, "friends.refreshing"))
	end
	return table.concat(parts, " · ")
end

-- `own` = the viewer's settings (appearOffline, friendJoin): an invitation from another server needs them.
local function viewOf(row: any, payload: any, friend: boolean, own: { hidden: boolean, pj: string }): FriendJoin.View
	return {
		friend = friend,
		ignored = false,
		status = (if type(row) == "table" and type(row.s) == "string" then row.s else "unknown") :: any,
		pj = if type(row) == "table" then row.pj else nil,
		hereMode = if type(payload) == "table" and type(payload.mode) == "string" then payload.mode else "world",
		block = if type(payload) == "table" then payload.block else nil,
		cooldownUntil = if type(payload) == "table" then payload.cd else nil,
		selfHidden = own.hidden,
		selfPj = own.pj,
		selfPrivate = type(payload) == "table" and payload.priv == true,
	}
end

local function buttonWidth(label: string, primary: boolean?): number
	return if primary then 128 elseif label == MORE then 52 else 112
end

local function rowButton(s: Scope, order: number, label: string, enabled: boolean, onClick: () -> (), primary: boolean?)
	return Button(s, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(buttonWidth(label, primary), Theme.Size.MinTouch),
		TextSize = Theme.TextSize.Small,
		Variant = if primary then "primary" else "secondary",
		Text = label,
		Disabled = not enabled,
		OnClick = onClick,
	})
end

-- One line of a row (owner 2026-11-10: a row is one row, so a line is cut, not wrapped).
local function textLine(s: Scope, order: number, text: string, color: Color3, size: number?, rich: boolean?): Instance
	local textSize = size or Theme.TextSize.Body
	return s:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, textSize + 4),
		BackgroundTransparency = 1,
		RichText = rich == true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = text,
		FontFace = Theme.Fonts.Body,
		TextSize = textSize,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- A row `height` tall (WorldLayout.friends): the lines on the left, the buttons (`width` wide in all) at the right.
local function row(s: Scope, order: number, lines: { Instance }, buttons: { Instance }, height: number, width: number)
	return s:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.Paper.Raised,
		BackgroundTransparency = 0.2,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIPadding")({
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 6),
			}),
			s:New("Frame")({
				Name = "Lines",
				Size = UDim2.new(1, -(width + 8), 1, 0),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 2),
					}),
					lines :: any,
				},
			}),
			s:New("Frame")({
				Name = "Buttons",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(width, Theme.Size.MinTouch),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, BUTTON_GAP),
					}),
					buttons :: any,
				},
			}),
		},
	})
end

-- The width of a row's buttons (labels with whether each is the primary one).
local function buttonsWidth(labels: { { text: string, primary: boolean? } }): number
	local width = 0
	for i, b in labels do
		width += buttonWidth(b.text, b.primary) + (if i > 1 then BUTTON_GAP else 0)
	end
	return width
end

local function emptyLine(s: Scope, order: number, text: string): Instance
	return s:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
		TextWrapped = true,
		Text = text,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Paper.TextMuted,
	})
end

local function FriendsWindow(scope: Scope, props: Props): Fusion.Child
	local tab = scope:Value("friends")
	local ignoreName = scope:Value("")
	local social = State.Value({ "account", "social" })
	local branch = State.Value({ "friends" })
	local party = State.Value({ "party" })
	local appearOffline = State.Value({ "account", "settings", "appearOffline" })
	local friendJoin = State.Value({ "account", "settings", "friendJoin" })
	local me = Players.LocalPlayer.UserId
	local A = props.Actions
	-- Logic/WorldLayout.friends: the tabs, the header and the rows of this device
	local layout = scope:Computed(function(use): WorldLayout.Friends
		local device: WorldLayout.Device = WorldLayout.device(use(Device.Touch) == true, use(PhoneLayout.Compact))
		return WorldLayout.friends(WorldLayout.CHROME, device)
	end)

	-- Only who leads and who is in the party ("leader|,id,id,"): the `party` branch changes with every move of a
	-- member, and an unchanged string does not rebuild the rows.
	local partyKey = scope:Computed(function(use): string
		local p = use(party)
		if type(p) ~= "table" then
			return ""
		end
		local ids = {}
		for _, member in p.members or {} do
			table.insert(ids, tostring(member.id))
		end
		return `{tostring(p.leader)}|,{table.concat(ids, ",")},`
	end)

	local function partyContext(key: string, userId: number): (boolean, boolean)
		if key == "" then
			return false, false
		end
		local bar = string.find(key, "|", 1, true) :: number
		local inMine = string.find(key, `,{userId},`, bar, true) ~= nil
		return inMine, string.sub(key, 1, bar - 1) ~= tostring(me)
	end

	local function runEntry(id: string, userId: number, name: string, here: boolean)
		if id == "join" then
			A.Join(userId)
		elseif id == "party" then
			A.Party(userId, name, here)
		elseif id == "whisper" then
			A.Whisper(userId, name)
		elseif id == "mail" then
			A.Mail(name)
		elseif id == "remove" then
			A.Remove(userId, name)
		elseif id == "ignore" then
			A.Ignore(userId, name)
		end
	end

	local friendRows = scope:Computed(function(use, s: Scope): { Instance }
		local data = use(social)
		local payload = use(branch)
		local rows = if type(payload) == "table" and type(payload.list) == "table" then payload.list else {}
		local touch = use(Device.Touch)
		local height = use(layout).row
		local partyNow = use(partyKey)
		local own = {
			hidden = use(appearOffline) == true,
			pj = if use(friendJoin) == "none" then "none" else "friends",
		}
		local list = {}
		if type(data) == "table" and type(data.friends) == "table" then
			for key, friend in data.friends do
				table.insert(list, { key = key, friend = friend, row = rows[key] })
			end
		end
		table.sort(list, function(a, b)
			local sa = Presence.ORDER[if a.row then a.row.s else "unknown"] or 5
			local sb = Presence.ORDER[if b.row then b.row.s else "unknown"] or 5
			if sa ~= sb then
				return sa < sb
			end
			local ta = if a.row and type(a.row.tag) == "string" then a.row.tag else ""
			local tb = if b.row and type(b.row.tag) == "string" then b.row.tag else ""
			if ta ~= tb then
				return ta < tb
			end
			return string.lower(a.friend.name) < string.lower(b.friend.name)
		end)
		local now = os.time()
		local out = {}
		for i, e in list do
			local userId = tonumber(e.key) :: number
			local name: string = e.friend.name
			local view = viewOf(e.row, payload, true, own)
			local here = view.status == "here"
			local inMine, notLeader = partyContext(partyNow, userId)
			local entries = Social.friendRowEntries({
				view = view,
				now = now,
				inMyParty = inMine,
				notPartyLeader = notLeader,
			})
			local color = STATUS_COLOR[view.status] or Theme.Paper.TextMuted
			local lines = {
				textLine(
					s,
					1,
					`{classIcon(if e.row and e.row.cls then e.row.cls else e.friend.class)}<b>{escape(name)}</b>   <font color="#{color:ToHex()}">{escape(
						describe(use, e.row, e.friend.class)
					)}</font>`,
					Theme.Paper.Text,
					nil,
					true
				),
			}
			local join = entries.primary[1]
			if not join.enabled and join.reasonKey and Presence.online(view.status) then
				table.insert(
					lines,
					textLine(s, 2, Text.get(use, join.reasonKey), Theme.Paper.TextMuted, Theme.TextSize.Small)
				)
			end
			local buttons = {}
			local labels: { { text: string, primary: boolean? } } = {}
			local sheet: { Social.MenuEntry } = {}
			for order, entry in entries.primary do
				-- touch: Join in the row; PC: Join and Whisper; the rest in the "⋯" sheet
				if entry.id ~= "join" and (touch or entry.id ~= "whisper") then
					if entry.enabled then
						table.insert(sheet, entry)
					end
					continue
				end
				local label = Text.get(use, entry.labelKey)
				table.insert(labels, { text = label, primary = entry.id == "join" })
				table.insert(
					buttons,
					rowButton(s, order, label, entry.enabled, function()
						runEntry(entry.id, userId, name, here)
					end, entry.id == "join")
				)
			end
			for _, entry in entries.more do
				table.insert(sheet, entry)
			end
			table.insert(labels, { text = MORE })
			table.insert(
				buttons,
				rowButton(s, 20, MORE, true, function()
					A.Sheet(name, sheet, function(id: string)
						runEntry(id, userId, name, here)
					end)
				end)
			)
			table.insert(out, row(s, i, lines, buttons, height, buttonsWidth(labels)))
		end
		if #out == 0 then
			table.insert(out, emptyLine(s, 1, Text.get(use, "social.friends.empty")))
		end
		-- Roblox friends who play Vaelthorn (not on the list, not ignored)
		local roblox = if type(payload) == "table" and type(payload.roblox) == "table" then payload.roblox else {}
		local extra = {}
		for key, r in roblox do
			if type(r) == "table" and type(r.name) == "string" then
				table.insert(extra, { key = key, row = r })
			end
		end
		table.sort(extra, function(a, b)
			local sa, sb = Presence.ORDER[a.row.s] or 5, Presence.ORDER[b.row.s] or 5
			if sa ~= sb then
				return sa < sb
			end
			return string.lower(a.row.name) < string.lower(b.row.name)
		end)
		local base = #out
		table.insert(
			out,
			s:New("TextLabel")({
				LayoutOrder = base + 1,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				Text = Text.get(use, "friends.roblox.title"),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		)
		for i, e in extra do
			local userId = tonumber(e.key) :: number
			local view = viewOf(e.row, payload, true, own)
			local here = view.status == "here"
			local ok, reason = FriendJoin.canJoin(view, now)
			local color = STATUS_COLOR[view.status] or Theme.Paper.TextMuted
			local lines = {
				textLine(
					s,
					1,
					`{classIcon(e.row.cls)}<b>{escape(e.row.name)}</b>   <font color="#{color:ToHex()}">{escape(
						describe(use, e.row, nil)
					)}</font>`,
					Theme.Paper.Text,
					nil,
					true
				),
			}
			if not ok and reason then
				table.insert(lines, textLine(s, 2, Text.get(use, reason), Theme.Paper.TextMuted, Theme.TextSize.Small))
			elseif not here then
				table.insert(
					lines,
					textLine(s, 2, Text.get(use, "friends.reason.addHere"), Theme.Paper.TextMuted, Theme.TextSize.Small)
				)
			end
			local joinLabel, addLabel = Text.get(use, "friends.join"), Text.get(use, "friends.roblox.add")
			table.insert(
				out,
				row(s, base + 1 + i, lines, {
					rowButton(s, 1, joinLabel, ok, function()
						A.Join(userId)
					end, true),
					rowButton(s, 2, addLabel, here, function()
						A.AddFriend(userId)
					end),
				}, height, buttonsWidth({ { text = joinLabel, primary = true }, { text = addLabel } }))
			)
		end
		if #extra == 0 then
			table.insert(out, emptyLine(s, base + 2, Text.get(use, "friends.roblox.empty")))
		end
		return out
	end)

	local ignoredRows = scope:Computed(function(use, s: Scope): { Instance }
		local data = use(social)
		local height = use(layout).row
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
			local unignore = Text.get(use, "social.menu.unignore")
			table.insert(
				out,
				row(s, i, {
					textLine(
						s,
						1,
						`<b>{escape(name)}</b>   {escape(className(use, e.entry.class))}`,
						Theme.Paper.Text,
						nil,
						true
					),
				}, {
					rowButton(s, 1, unignore, true, function()
						A.Unignore(userId, name)
					end),
				}, height, buttonsWidth({ { text = unignore } }))
			)
		end
		if #out == 0 then
			table.insert(out, emptyLine(s, 1, Text.get(use, "social.ignored.empty")))
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

	-- "In the game n / max · refreshed HH:MM": PC over the switches, a phone beside the tabs
	local statusText = scope:Computed(function(use): string
		local payload = use(branch)
		local parts = {}
		local online = if type(payload) == "table" and type(payload.online) == "number" then payload.online else 0
		table.insert(parts, Text.get(use, "friends.online", { n = online, max = Config.Social.maxFriends }))
		if type(payload) == "table" and type(payload.at) == "number" then
			table.insert(parts, Text.get(use, "friends.updated", { time = os.date("%H:%M", payload.at) }))
		else
			table.insert(parts, Text.get(use, "friends.refreshing"))
		end
		return table.concat(parts, " · ")
	end)
	local phone = scope:Computed(function(use): boolean
		return use(layout).status == 0
	end)
	local PHONE_TABS = 320
	local header = scope:New("Frame")({
		Name = "FriendsHeader",
		Position = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(0, use(layout).tabs)
		end),
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(1, 0, 0, use(layout).header)
		end),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return use(tab) == "friends"
		end),
		[Children] = {
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(phone)
				end),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = statusText,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("Frame")({
				Position = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(0, use(layout).status)
				end),
				Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					Button(scope, {
						LayoutOrder = 1,
						Size = UDim2.new(0.5, -4, 0, Theme.Size.MinTouch),
						TextSize = Theme.TextSize.Small,
						Variant = scope:Computed(function(use): any
							return if use(appearOffline) == true then "primary" else "secondary"
						end),
						Text = scope:Computed(function(use): string
							local on = use(appearOffline) == true
							return `{Text.get(use, "friends.appearOffline")}: {Text.get(
								use,
								if on then "menu.on" else "menu.off"
							)}`
						end),
						OnClick = function()
							A.Setting("appearOffline", Fusion.peek(appearOffline) ~= true)
						end,
					}),
					Button(scope, {
						LayoutOrder = 2,
						Size = UDim2.new(0.5, -4, 0, Theme.Size.MinTouch),
						TextSize = Theme.TextSize.Small,
						Text = scope:Computed(function(use): string
							return Text.get(
								use,
								if use(friendJoin) == "none"
									then "friends.joinRule.none"
									else "friends.joinRule.friends"
							)
						end),
						OnClick = function()
							A.Setting("friendJoin", if Fusion.peek(friendJoin) == "none" then "friends" else "none")
						end,
					}),
				},
			}),
		},
	})

	return {
		scope:New("Frame")({
			Name = "TabStrip",
			Size = scope:Computed(function(use): UDim2
				return if use(phone)
					then UDim2.fromOffset(PHONE_TABS, Theme.Size.TabHeight)
					else UDim2.new(1, 0, 0, Theme.Size.TabHeight)
			end),
			BackgroundTransparency = 1,
			[Children] = Tabs(scope, {
				Selected = tab,
				Tabs = {
					{ id = "friends", label = Text.T(scope, "social.tab.friends") },
					{ id = "ignored", label = Text.T(scope, "social.tab.ignored") },
				},
			}),
		}),
		-- a phone: the online count beside the tabs
		scope:New("TextLabel")({
			Name = "Status",
			Position = UDim2.fromOffset(PHONE_TABS + 8, 0),
			Size = UDim2.new(1, -(PHONE_TABS + 8), 0, Theme.Size.TabHeight),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return use(phone) and use(tab) == "friends"
			end),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = statusText,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Paper.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		header,
		InfoLine.new(scope, {
			Position = scope:Computed(function(use): UDim2
				return UDim2.fromOffset(0, use(layout).tabs)
			end),
			Size = UDim2.new(1, 0, 0, 40),
			Visible = scope:Computed(function(use): boolean
				return use(tab) == "ignored"
			end),
			Text = scope:Computed(function(use): string
				return Text.get(
					use,
					"social.ignored.hint.short",
					{ n = count(use, "ignored"), max = Config.Social.maxIgnored }
				)
			end),
			Info = scope:Computed(function(use): string
				return Text.get(
					use,
					"social.ignored.hint",
					{ n = count(use, "ignored"), max = Config.Social.maxIgnored }
				)
			end),
			Color = Theme.Paper.TextMuted,
		}),
		scope:New("ScrollingFrame")({
			Position = scope:Computed(function(use): UDim2
				local l = use(layout)
				return UDim2.fromOffset(0, if use(tab) == "friends" then l.list.top else l.tabs + 44)
			end),
			Size = scope:Computed(function(use): UDim2
				local l = use(layout)
				local top = if use(tab) == "friends" then l.list.top else l.tabs + 44
				local bottom = if use(tab) == "ignored" then 60 else 0
				return UDim2.new(1, 0, 1, -(top + bottom))
			end),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = scope:Computed(function(use): UDim
						return UDim.new(0, use(layout).list.gap)
					end),
				}),
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
						A.IgnoreName(Fusion.peek(ignoreName))
						ignoreName:set("")
					end,
				}),
			},
		}),
	}
end

return FriendsWindow
