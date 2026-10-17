--!strict
-- Parties on the client (DESIGN §17): the party window (P), member frames under the portrait, the invite
-- popup with Accept / Decline and a countdown, and the player menu on other players.
-- S133: the player menu (UI/Screens/PlayerMenu, entries from Logic/Social.menuEntries): Whisper, Write a letter,
-- Trade and Duel (S10), Invite to party, Invite to guild (S12, leader / officer), Profile (S15), Add / remove friend,
-- Ignore / stop ignoring, Follow player. It opens with a right click on a player, the "Actions" button next to the
-- target frame (a click or tap selects the player first) and, on a touch screen, by holding a finger on a player for
-- Config.Social.holdSeconds without moving it (a camera drag cancels). The first time a character selects another
-- player a one-time hint explains this (character.playerMenuHint).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.UI.Components.Button)
local Config = require(ReplicatedStorage.Shared.Config)
local Device = require(script.Parent.Parent.UI.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local NavTarget = require(script.Parent.Parent.UI.NavTarget)
local Net = require(ReplicatedStorage.Shared.Net)
local PartyFrames = require(script.Parent.Parent.UI.Screens.PartyFrames)
local PartyWindow = require(script.Parent.Parent.UI.Screens.PartyWindow)
local PlayerMenu = require(script.Parent.Parent.UI.Screens.PlayerMenu)
local ProfileWindow = require(script.Parent.Parent.UI.Screens.ProfileWindow)
local ServerModeView = require(script.Parent.Parent.UI.ServerModeView)
local Social = require(ReplicatedStorage.Shared.Logic.Social)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local Children = Fusion.Children

local PartyController = {
	Name = "PartyController",
	Deps = { "WindowManager", "UIController", "TargetController", "SocialController" },
}

local scope = Fusion.scoped(Fusion)
local Registry: any
local WindowManager: any
local TargetController: any
local SocialController: any

local inviteFrom = scope:Value(nil :: string?)
local inviteLeft = scope:Value(0)
local menuFor = scope:Value(nil :: Player?)
local menuAt = scope:Value(Vector2.zero)

local function invoke(name: string, ...: any): boolean
	local ok, err = Net.Invoke(name, ...)
	if not ok then
		Sounds.play("error")
		Toast.push(Text.now(err or "error.internal"), "error")
	end
	return ok
end

local function respond(accept: boolean)
	inviteFrom:set(nil)
	task.spawn(invoke, "PartyRespond", accept)
end

local function invitePopup(): Instance
	return scope:New("Frame")({
		Name = "PartyInvite",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(460, 130),
		BackgroundColor3 = Theme.Iron.Surface,
		Visible = scope:Computed(function(use): boolean
			return use(inviteFrom) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = 1.5 }),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(16, 10),
				Size = UDim2.new(1, -32, 0, 50),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return Text.get(use, "party.invited", { name = use(inviteFrom) or "", seconds = use(inviteLeft) })
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Iron.Text,
			}),
			Button(scope, {
				Surface = "iron", -- S135: on a dark HUD / overlay surface
				Position = UDim2.new(0, 16, 1, -62),
				Size = UDim2.new(0.5, -24, 0, 50),
				Variant = "primary",
				Text = Text.T(scope, "party.accept"),
				OnClick = function()
					respond(true)
				end,
			}),
			Button(scope, {
				Surface = "iron", -- S135: on a dark HUD / overlay surface
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16, 1, -62),
				Size = UDim2.new(0.5, -24, 0, 50),
				Text = Text.T(scope, "party.decline"),
				OnClick = function()
					respond(false)
				end,
			}),
		},
	})
end

-- S133: the player menu -------------------------------------------------------------------------------------------

local function charName(player: Player): string
	local model = player.Character
	local name = model and model:GetAttribute("CharName")
	return if type(name) == "string" then name else player.DisplayName
end

-- Whether the player's character stands on the local player's map (streamed in and inside the map's footprint).
local function onMyMap(player: Player): boolean
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local map = Maps.get(State.Get({ "character", "location", "map" }) or "")
	if not root or not root:IsA("BasePart") or not map then
		return false
	end
	local x, z = root.Position.X - map.offset.x, root.Position.Z - map.offset.z
	return math.abs(x) <= map.size.x / 2 + 50 and math.abs(z) <= map.size.z / 2 + 50
end

local function following(userId: number): boolean
	local target = Fusion.peek(NavTarget.Target)
	return target ~= nil and target.keep == true and target.follow == userId
end

-- What the local player knows about `target` (Logic/Social.MenuContext).
local function menuContext(use: Fusion.Use, target: Player): Social.MenuContext
	local social = use(State.Value({ "account", "social" }))
	local friends = if type(social) == "table" and type(social.friends) == "table" then social.friends else {}
	local ignored = if type(social) == "table" and type(social.ignored) == "table" then social.ignored else {}
	local key = Social.key(target.UserId)
	local party = use(State.Value({ "party" }))
	local inMyParty, notLeader = false, false
	if type(party) == "table" and type(party.members) == "table" then
		notLeader = party.leader ~= Players.LocalPlayer.UserId
		for _, member in party.members do
			if member.id == target.UserId then
				inMyParty = true
			end
		end
	end
	local model = target.Character
	local tag = model and model:GetAttribute("GuildTag")
	use(NavTarget.Target)
	return {
		sameMap = onMyMap(target),
		isFriend = friends[key] ~= nil,
		isIgnored = ignored[key] ~= nil,
		friendsFull = Social.count(friends) >= Config.Social.maxFriends,
		ignoredFull = Social.count(ignored) >= Config.Social.maxIgnored,
		guildRank = use(State.Value({ "guild", "myRank" })),
		targetInGuild = type(tag) == "string" and tag ~= "",
		inMyParty = inMyParty,
		notPartyLeader = notLeader,
		duelAllowed = ServerModeView.isWorld(),
		arenaChallenge = false, -- S126-S127 have no arena invitation by name (docs/DECYZJE.md S133)
		canReport = false, -- no client API opens the Roblox report dialog (docs/DECYZJE.md S133)
		following = following(target.UserId),
	}
end

-- "Follow player": the character walks after the target on this map (NavController, stopped by own movement).
local function follow(target: Player)
	local nav = Registry.Get("NavController")
	if following(target.UserId) then
		nav.Clear()
		return
	end
	local map = State.Get({ "character", "location", "map" })
	if type(map) ~= "string" or not onMyMap(target) then
		Toast.push(Text.now("social.reason.otherMap"), "info")
		return
	end
	nav.Walk({ map = map, x = 0, z = 0, follow = target.UserId, keep = true, label = charName(target) })
end

local function act(id: string, target: Player)
	local userId, name = target.UserId, charName(target)
	if id == "whisper" then
		SocialController.Whisper(userId, name)
	elseif id == "mail" then
		SocialController.ComposeTo(name)
	elseif id == "trade" then
		SocialController.RequestTrade(userId)
	elseif id == "duel" then
		SocialController.Challenge(userId)
	elseif id == "party" then
		SocialController.InviteParty(userId, name)
	elseif id == "guild" then
		task.spawn(function()
			if invoke("GuildInvite", userId) then
				Toast.push(Text.now("guild.inviteSent", { name = name }), "success")
			end
		end)
	elseif id == "profile" then
		PartyController.OpenProfile(userId)
	elseif id == "friend" then
		if Social.isFriend(State.Get({ "account", "social" }), userId) then
			SocialController.RemoveFriend(userId, name)
		else
			SocialController.AddFriend(userId)
		end
	elseif id == "ignore" then
		if Social.isIgnored(State.Get({ "account", "social" }), userId) then
			SocialController.Unignore(userId, name)
		else
			SocialController.Ignore(userId, name)
		end
	elseif id == "follow" then
		follow(target)
	end
end

-- Player whose character is under the screen point.
local function playerAt(position: Vector2): Player?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if Players.LocalPlayer.Character then
		table.insert(exclude, Players.LocalPlayer.Character)
	end
	-- Client-only decorations never take a click (S21).
	for _, name in { "Vaelthorn_TownDetail", "Vaelthorn_ClientDecor" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

local profileData = scope:Value(nil :: any)

-- Loads another player's profile and opens the profile window (S15).
function PartyController.OpenProfile(userId: number)
	profileData:set(nil)
	WindowManager.Open("profile")
	task.spawn(function()
		local ok, data = Net.Invoke("PlayerProfile", userId)
		if ok then
			profileData:set(data)
		else
			WindowManager.Close("profile")
			Toast.push(Text.now(data or "error.internal"), "error")
		end
	end)
end

function PartyController.OpenMenu(target: Player, at: Vector2)
	if target == Players.LocalPlayer then
		return
	end
	Sounds.play("click")
	menuAt:set(at)
	menuFor:set(target)
end

function PartyController.CloseMenu()
	menuFor:set(nil)
end

function PartyController.Init(registry)
	Registry = registry
	WindowManager = registry.Get("WindowManager")
	TargetController = registry.Get("TargetController")
	SocialController = registry.Get("SocialController")
	local UIController = registry.Get("UIController")
	WindowManager.Register({
		id = "party",
		titleKey = "window.party.title",
		size = Vector2.new(660, 620), -- S134f: room for the tab strip (was 640 x 560)
		hotkey = Enum.KeyCode.P,
		-- S134f: the finder tab guides to a listing; "Recent fights" opens the fight log
		build = function(s)
			return PartyWindow(s, {
				OpenFightLog = function()
					local log = Registry.Get("FightLogController")
					log.Open(1)
				end,
				Guide = function(place: any, labelKey: string)
					local nav = Registry.Get("NavController")
					nav.Guide({ map = place.map, x = place.x, z = place.z, labelKey = labelKey })
				end,
			})
		end,
	})
	WindowManager.Register({
		id = "profile",
		titleKey = "window.profile.title",
		size = Vector2.new(560, 560),
		build = function(s)
			return ProfileWindow(s, profileData)
		end,
	})
	local layer = UIController.GetLayer("Screens")
	PartyFrames(scope, function(userId: number)
		local member = Players:GetPlayerByUserId(userId)
		if member and member.Character then
			TargetController.SetTarget(member.Character)
		end
	end).Parent =
		layer
	invitePopup().Parent = UIController.GetLayer("Modals")
	-- The player menu lives in an unscaled ScreenGui so it opens exactly at the mouse.
	local gui = Instance.new("ScreenGui")
	gui.Name = "Vaelthorn_PlayerMenu"
	gui.DisplayOrder = 60
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	PlayerMenu(scope, {
		Target = menuFor,
		At = menuAt,
		Touch = Device.Touch,
		Context = menuContext,
		OnAction = act,
	}).Parent =
		gui
end

-- S133: the one-time hint when the character selects another player for the first time.
local function watchHint()
	local hinted = false
	scope:Observer(TargetController.Target):onChange(function()
		local model = Fusion.peek(TargetController.Target)
		local player = if model then Players:GetPlayerFromCharacter(model) else nil
		if hinted or not player or player == Players.LocalPlayer then
			return
		end
		if State.Get({ "character", "playerMenuHint" }) ~= false then
			return
		end
		hinted = true
		local key = if Fusion.peek(Device.Touch) then "social.hint.touch" else "social.hint.pc"
		Toast.push(Text.now(key), "info", 10)
		Net.Send("SocialHintSeen")
	end)
end

-- S133: holding a finger on a player opens the menu (cancelled by moving the finger: the camera drag).
type Hold = { input: InputObject, start: Vector2, token: number }
local hold: Hold? = nil
local holdToken = 0

local function startHold(input: InputObject)
	holdToken += 1
	local token = holdToken
	local start = Vector2.new(input.Position.X, input.Position.Y)
	hold = { input = input, start = start, token = token }
	task.delay(Config.Social.holdSeconds, function()
		local current = hold
		if not current or current.token ~= token then
			return
		end
		hold = nil
		local target = playerAt(current.start)
		if target and target ~= Players.LocalPlayer then
			PartyController.OpenMenu(target, current.start)
		end
	end)
end

function PartyController.Start()
	Net.On("PartyInvited", function(fromName: string, seconds: number)
		Sounds.play("levelUp")
		inviteFrom:set(fromName)
		local token = os.clock()
		inviteLeft:set(seconds)
		task.spawn(function()
			local left = seconds
			while left > 0 and Fusion.peek(inviteFrom) == fromName do
				task.wait(1)
				left -= 1
				inviteLeft:set(left)
			end
			if Fusion.peek(inviteFrom) == fromName and os.clock() - token >= seconds - 0.5 then
				inviteFrom:set(nil)
			end
		end)
	end)

	watchHint()

	UserInputService.InputBegan:Connect(function(input, processed)
		local kind = input.UserInputType
		if (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) and Fusion.peek(menuFor) then
			-- A click or tap in the world closes the menu (its own buttons close it after their action).
			if not processed then
				menuFor:set(nil)
			end
		end
		if processed then
			return
		end
		if kind == Enum.UserInputType.Touch then
			startHold(input)
			return
		end
		if kind ~= Enum.UserInputType.MouseButton2 then
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		local target = playerAt(at)
		if target then
			PartyController.OpenMenu(target, at)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local current = hold
		if current and input == current.input then
			local moved = Vector2.new(input.Position.X, input.Position.Y) - current.start
			if moved.Magnitude > Config.Social.holdMove then
				hold = nil
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local current = hold
		if current and input == current.input then
			hold = nil
		end
	end)
	-- The menu closes when its player leaves.
	Players.PlayerRemoving:Connect(function(player)
		if Fusion.peek(menuFor) == player then
			menuFor:set(nil)
		end
	end)
end

return PartyController
