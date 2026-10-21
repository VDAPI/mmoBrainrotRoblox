--!strict
-- Party window (P): members with class, level, HP/mana, leader crown; invite by name; leave; the leader can
-- kick and promote; party chat toggle; the loot rules (DESIGN §17). S134f: a second tab with the party finder board
-- (UI/Screens/PartyFinder) and "Recent fights" (the fight log window).
-- 2026-10-21 (owner: too many descriptions): the loot rules are no longer a block of text under the list; they sit
-- behind the "i" of the bonus lines (Components/InfoTip), the bonus lines are short, "not in a party" is one line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GroupLuck = require(script.Parent.Parent.GroupLuck)
local InfoLine = require(script.Parent.Parent.Components.InfoLine)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local Net = require(ReplicatedStorage.Shared.Net)
local PartyBonus = require(ReplicatedStorage.Shared.Logic.PartyBonus)
local PartyLoot = require(ReplicatedStorage.Shared.Logic.PartyLoot)
local PartyFinder = require(script.Parent.PartyFinder)
local PathBadge = require(script.Parent.Parent.Components.PathBadge)
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

local TAB_BAR = 48 -- S134f: the tab strip above the content

local function PartyWindow(scope: Scope, options: Options): Fusion.Child
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
					Size = UDim2.new(1, 0, 0, 64),
					BackgroundColor3 = Theme.Paper.Raised,
					BackgroundTransparency = 0.35,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(8, 8),
							Size = UDim2.fromOffset(48, 48),
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
						PathBadge.new(s, use, member.path, 18, UDim2.fromOffset(40, 40)) :: any,
						s:New("TextLabel")({
							Position = UDim2.fromOffset(70, 6),
							Size = UDim2.new(1, -250, 0, 24),
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
						bar(s, member.hp / math.max(1, member.maxHp), Theme.Resource.Hp, 34),
						bar(s, member.mana / math.max(1, member.maxMana), Theme.Resource.Mana, 48),
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
	local bonusText = scope:Computed(function(use): string
		local p = use(party)
		if type(p) ~= "table" then
			return ""
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
		local text = poolLine .. "\n" .. line
		return if luckLine then text .. "\n" .. luckLine else text
	end)

	local content = {
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
			Size = UDim2.new(1, 0, 1, -188),
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
		-- the bonus lines (pool, classes, Fortune) with the loot rules behind the "i" at their right
		scope:New("Frame")({
			Name = "Bonus",
			Position = UDim2.new(0, 0, 1, -126),
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return type(use(party)) == "table"
			end),
			[Children] = {
				scope:New("TextLabel")({
					Size = UDim2.new(1, -36, 1, 0),
					BackgroundTransparency = 1,
					Text = bonusText,
					TextWrapped = true,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.Heading,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
				InfoTip.new(scope, {
					Name = "Rules",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 0),
					Text = Text.T(scope, "party.rules", { gap = Progression.partyCarryGap }),
				}),
			},
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
	-- S134f: the members (as before) and the party finder board ("Looking for a party") in two tabs; "Recent fights"
	-- opens the fight log window.
	local tab = scope:Value("members")
	local members = scope:New("Frame")({
		Name = "Members",
		Position = UDim2.fromOffset(0, TAB_BAR),
		Size = UDim2.new(1, 0, 1, -TAB_BAR),
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
				Position = UDim2.fromOffset(0, TAB_BAR),
				Size = UDim2.new(1, 0, 1, -TAB_BAR),
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
