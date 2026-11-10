--!strict
-- Party window (P): members with class, level, HP/mana, leader crown; invite by name; leave; the leader can
-- kick and promote; party chat toggle; the loot rules (DESIGN §17). S134f: a second tab with the party finder board
-- (UI/Screens/PartyFinder) and "Recent fights" (the fight log window).
-- 2026-10-21 (owner: too many descriptions): the loot rules are no longer a block of text under the list; they sit
-- behind the "i" of the bonus lines (Components/InfoTip), the bonus lines are short, "not in a party" is one line.
-- Owner 2026-11-10 ("bardzo dużo napisów, niektóre rzeczy zasłaniają inne"; UI plan E, Logic/WorldLayout.party): the
-- bonus is one line (the pool, the variety while it pays) with the variety rule, Fortune and the loot rules behind its
-- (i); the tabs, the invite row and the rows come from WorldLayout. A phone puts the invite, the chat and "Leave" into
-- one row on top and its rows are 52 tall, so at least three members show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GroupLuck = require(script.Parent.Parent.GroupLuck)
local InfoLine = require(script.Parent.Parent.Components.InfoLine)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local Net = require(ReplicatedStorage.Shared.Net)
local PartyBonus = require(ReplicatedStorage.Shared.Logic.PartyBonus)
local PartyLoot = require(ReplicatedStorage.Shared.Logic.PartyLoot)
local PartyFinder = require(script.Parent.PartyFinder)
local PathBadge = require(script.Parent.Parent.Components.PathBadge)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local TextInput = require(script.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.UiArtState)
local WorldLayout = require(ReplicatedStorage.Shared.Logic.WorldLayout)

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

local function bar(scope: Scope, ratio: Fusion.UsedAs<number>, color: Color3, y: number, left: number): Instance
	return scope:New("Frame")({
		Position = UDim2.fromOffset(left, y),
		Size = UDim2.new(1, -(left + 180), 0, if left < 70 then 8 else 10),
		BackgroundColor3 = Theme.Resource.Track,
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

-- S134f: what the party controller passes (the fight log window, the guide to a finder listing).
export type Options = {
	OpenFightLog: (() -> ())?,
	Guide: ((place: any, labelKey: string) -> ())?,
}

local function PartyWindow(scope: Scope, options: Options): Fusion.Child
	local party = State.Value({ "party" })
	local myId = game:GetService("Players").LocalPlayer.UserId
	local inviteName = scope:Value("")
	local partyChat = scope:Value(false)
	-- Logic/WorldLayout.party: the tabs (S134f), the invite row, the rows, the bonus line and the footer of this device
	local layout = scope:Computed(function(use): WorldLayout.Party
		local device: WorldLayout.Device = WorldLayout.device(use(Device.Touch) == true, use(PhoneLayout.Compact))
		return WorldLayout.party(WorldLayout.CHROME, device)
	end)
	local function sized(build: (l: WorldLayout.Party) -> UDim2): Fusion.Computed<UDim2>
		return scope:Computed(function(use): UDim2
			return build(use(layout))
		end)
	end

	local amLeader = scope:Computed(function(use): boolean
		local p = use(party)
		return type(p) ~= "table" or p.leader == myId
	end)

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local p = use(party)
		local l = use(layout)
		local avatar = l.avatar
		local inset = (l.row - avatar) / 2
		local left = avatar + inset + 14
		local compact = l.row < 64
		local list = {}
		if type(p) ~= "table" then
			table.insert(
				list,
				InfoLine.new(s, {
					Size = UDim2.new(1, 0, 0, 60),
					Center = true,
					Text = Text.get(use, "party.none.short"),
					Info = Text.get(use, "party.none"),
					TextSize = Theme.TextSize.Body,
					Color = Theme.Paper.TextMuted,
				})
			)
			return list
		end
		for i, member in p.members do
			local class = Classes.get(member.class)
			local isLeader = member.id == p.leader
			local pathDef = PathBadge.def(member.path)
			table.insert(
				list,
				s:New("Frame")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, l.row),
					BackgroundColor3 = Theme.Paper.Raised,
					BackgroundTransparency = 0.35,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(inset, inset),
							Size = UDim2.fromOffset(avatar, avatar),
							BackgroundColor3 = Theme.Paper.Surface,
							-- S119: class emblem once loaded (glyph otherwise).
							Text = s:Computed(function(use2): string
								if class and UiArtState.ready(use2, UiArt.classEmblem(class.id)) then
									return ""
								end
								return if class then class.icon else "?"
							end),
							TextScaled = true,
							TextColor3 = Theme.Paper.Heading,
							FontFace = Theme.Fonts.BodyBold,
							[Children] = {
								s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
								ArtIcon.Image(s, {
									Key = if class then UiArt.classEmblem(class.id) else nil,
									Size = UDim2.fromScale(0.9, 0.9),
									Position = UDim2.fromScale(0.5, 0.5),
									AnchorPoint = Vector2.new(0.5, 0.5),
								}),
							},
						}),
						PathBadge.new(s, use, member.path, 18, UDim2.fromOffset(avatar - 8, avatar - 8)) :: any,
						s:New("TextLabel")({
							Position = UDim2.fromOffset(left, if compact then 4 else 6),
							Size = UDim2.new(1, -(left + 180), 0, if compact then 22 else 24),
							BackgroundTransparency = 1,
							Text = `{if isLeader then "♛ " else ""}{member.name}  ·  {Text.get(use, "hud.level", {
								level = member.level,
							})}{if pathDef then ` · {Text.get(use, pathDef.nameKey)}` else ""}{if member.dead
								then " ☠"
								else ""}`,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = if isLeader then Theme.Paper.Heading else Theme.Paper.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						bar(
							s,
							member.hp / math.max(1, member.maxHp),
							Theme.Resource.Hp,
							if compact then 28 else 34,
							left
						),
						bar(
							s,
							member.mana / math.max(1, member.maxMana),
							Theme.Resource.Mana,
							if compact then 40 else 48,
							left
						),
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

	-- S60: the class variety bonus of the party (potential: the kill counts members within range) and Fortune.
	-- S134b: above it the monster EXP/gold pool of the whole party (potential: only members nearby, fighting and not
	-- carried grow it, Logic/PartyLoot).
	local bonusLines = scope:Computed(function(use): { string }
		local p = use(party)
		if type(p) ~= "table" then
			return {}
		end
		local classes: { string } = {}
		for _, member in p.members do
			table.insert(classes, if type(member.class) == "string" then member.class else "")
		end
		local n = #classes
		local poolLine = if n > 1
			then Text.get(use, "party.pool", {
				pool = math.floor(PartyLoot.poolMul(n) * 100 + 0.5),
				n = n,
				each = math.floor(PartyLoot.poolMul(n) * 100 / n + 0.5),
			})
			else Text.get(use, "party.poolNone", { per = Progression.partyPoolPerMember })
		local pct = PartyBonus.variety(classes)
		local line = if pct > 0
			then Text.get(use, "party.variety", { pct = pct })
			else Text.get(
				use,
				"party.varietyNone",
				{ per = Progression.varietyPerClass, max = Progression.varietyMax }
			)
		local luckLine = GroupLuck.line(use, GroupLuck.use(use))
		-- the one line: the pool, and the variety while it pays; the full lines go behind the (i)
		local short = if pct > 0 then `{poolLine}  ·  {line}` else poolLine
		local out = { short, poolLine, line }
		if luckLine then
			table.insert(out, luckLine)
		end
		return out
	end)
	local bonusText = scope:Computed(function(use): string
		return use(bonusLines)[1] or ""
	end)
	local bonusInfo = scope:Computed(function(use): string
		local lines = table.clone(use(bonusLines))
		table.remove(lines, 1)
		table.insert(lines, "")
		table.insert(lines, Text.get(use, "party.rules", { gap = Progression.partyCarryGap }))
		return table.concat(lines, "\n")
	end)
	local inParty = scope:Computed(function(use): boolean
		return type(use(party)) == "table"
	end)
	local function chatButton(s: Scope, size: Fusion.UsedAs<UDim2>, position: Fusion.UsedAs<UDim2>?): Instance
		return Button(s, {
			Size = size,
			Position = position,
			TextSize = Theme.TextSize.Small,
			Text = s:Computed(function(use): string
				return Text.get(use, if use(partyChat) then "party.chatParty" else "party.chatGeneral")
			end),
			OnClick = function()
				local want = not Fusion.peek(partyChat)
				if setChat(want) then
					partyChat:set(want)
				end
			end,
		})
	end
	local function leaveButton(s: Scope, size: Fusion.UsedAs<UDim2>): Instance
		return Button(s, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = size,
			Variant = "danger",
			TextSize = Theme.TextSize.Small,
			Text = Text.T(s, "party.leave"),
			OnClick = function()
				setChat(false)
				partyChat:set(false)
				task.spawn(invoke, "PartyLeave")
			end,
		})
	end
	-- a phone: the chat and "Leave" at the invite row's right (in a party)
	local PHONE_CHAT, PHONE_LEAVE = 150, 130
	local phoneButtons = scope:Computed(function(use, s: Scope): { Instance }
		if use(layout).footer > 0 or not use(inParty) then
			return {}
		end
		return {
			chatButton(
				s,
				UDim2.fromOffset(PHONE_CHAT, Theme.Size.MinTouch),
				UDim2.new(1, -(PHONE_LEAVE + PHONE_CHAT + 8), 0, 0)
			),
			leaveButton(s, UDim2.fromOffset(PHONE_LEAVE, Theme.Size.MinTouch)),
		}
	end)
	-- the invite field and its button: narrower on a phone in a party (the chat and "Leave" beside them)
	local inviteRight = scope:Computed(function(use): number
		return if use(layout).footer == 0 and use(inParty) then PHONE_LEAVE + PHONE_CHAT + 16 else 0
	end)

	local content = {
		scope:New("Frame")({
			Name = "Invite",
			Size = sized(function(l)
				return UDim2.new(1, 0, 0, l.invite)
			end),
			BackgroundTransparency = 1,
			[Children] = {
				TextInput(scope, {
					Size = scope:Computed(function(use): UDim2
						return UDim2.new(1, -(170 + use(inviteRight)), 0, 44)
					end),
					Text = inviteName,
					Placeholder = Text.T(scope, "party.invitePlaceholder"),
				}),
				phoneButtons :: any,
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = scope:Computed(function(use): UDim2
						return UDim2.new(1, -use(inviteRight), 0, 0)
					end),
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
			Position = sized(function(l)
				return UDim2.fromOffset(0, l.invite)
			end),
			Size = sized(function(l)
				return UDim2.new(1, 0, 1, -(l.invite + l.bonus + l.footer))
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
				rows :: any,
			},
		}),
		-- the bonus line (the pool, the variety while it pays) with the rest and the loot rules behind the "i"
		scope:New("Frame")({
			Name = "Bonus",
			AnchorPoint = Vector2.new(0, 1),
			Position = sized(function(l)
				return UDim2.new(0, 0, 1, -l.footer)
			end),
			Size = sized(function(l)
				return UDim2.new(1, 0, 0, l.bonus)
			end),
			BackgroundTransparency = 1,
			Visible = inParty,
			[Children] = {
				scope:New("TextLabel")({
					Size = UDim2.new(1, -36, 0, 22),
					Position = UDim2.fromOffset(0, 4),
					BackgroundTransparency = 1,
					Text = bonusText,
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.Heading,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
				InfoTip.new(scope, {
					Name = "Rules",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 2),
					Text = bonusInfo,
				}),
			},
		}),
		-- PC and a tablet: the chat and "Leave" pinned at the bottom
		scope:New("Frame")({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return use(inParty) and use(layout).footer > 0
			end),
			[Children] = {
				chatButton(scope, UDim2.fromOffset(220, 46)),
				leaveButton(scope, UDim2.fromOffset(180, 46)),
			},
		}),
	}
	-- S134f: the members (as before) and the party finder board ("Looking for a party") in two tabs; "Recent fights"
	-- opens the fight log window.
	local tab = scope:Value("members")
	local members = scope:New("Frame")({
		Name = "Members",
		Position = sized(function(l)
			return UDim2.fromOffset(0, l.tabs)
		end),
		Size = sized(function(l)
			return UDim2.new(1, 0, 1, -l.tabs)
		end),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return use(tab) == "members"
		end),
		[Children] = content :: any,
	})
	local finder = scope:Computed(function(use, s: Scope): { Instance }
		if use(tab) ~= "finder" then
			return {}
		end
		return {
			s:New("Frame")({
				Name = "Finder",
				Position = UDim2.fromOffset(0, use(layout).tabs),
				Size = UDim2.new(1, 0, 1, -use(layout).tabs),
				BackgroundTransparency = 1,
				[Children] = { PartyFinder(s, { Guide = options.Guide }) },
			}),
		}
	end)
	local openLog = options.OpenFightLog
	return {
		Tabs(scope, {
			Size = UDim2.new(1, -190, 0, 40),
			Selected = tab,
			Tabs = {
				{ id = "members", label = Text.T(scope, "window.party.title") },
				{ id = "finder", label = Text.T(scope, "finder.tab") },
			},
		}),
		Button(scope, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(180, 40),
			TextSize = Theme.TextSize.Small,
			Text = Text.T(scope, "fight.recent"),
			Visible = openLog ~= nil,
			OnClick = function()
				if openLog then
					openLog()
				end
			end,
		}),
		members,
		finder :: any,
	}
end

return PartyWindow
