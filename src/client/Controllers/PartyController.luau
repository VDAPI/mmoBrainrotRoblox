--!strict
-- Parties on the client (DESIGN §17): the party window (P), member frames under the portrait, the invite
-- popup with Accept / Decline and a countdown, and the context menu on other players (right click):
-- Invite to party, Trade and Duel (S10), Invite to guild (S12), Profile (S15).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.UI.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local PartyFrames = require(script.Parent.Parent.UI.Screens.PartyFrames)
local PartyWindow = require(script.Parent.Parent.UI.Screens.PartyWindow)
local ProfileWindow = require(script.Parent.Parent.UI.Screens.ProfileWindow)
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
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = scope:Computed(function(use): boolean
			return use(inviteFrom) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 1.5 }),
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
				TextColor3 = Theme.Colors.Text,
			}),
			Button(scope, {
				Position = UDim2.new(0, 16, 1, -62),
				Size = UDim2.new(0.5, -24, 0, 50),
				Variant = "primary",
				Text = Text.T(scope, "party.accept"),
				OnClick = function()
					respond(true)
				end,
			}),
			Button(scope, {
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

local function contextMenu(): Instance
	local function entry(
		order: number,
		key: string,
		action: (target: Player) -> (),
		visible: Fusion.UsedAs<boolean>?
	): Instance
		return Button(scope, {
			LayoutOrder = order,
			Visible = visible,
			Size = UDim2.new(1, 0, 0, 40),
			TextSize = Theme.TextSize.Small,
			Text = Text.T(scope, key),
			OnClick = function()
				local target = Fusion.peek(menuFor)
				menuFor:set(nil)
				if target then
					action(target)
				end
			end,
		})
	end
	return scope:New("Frame")({
		Name = "PlayerMenu",
		Position = scope:Computed(function(use): UDim2
			local at = use(menuAt)
			return UDim2.fromOffset(at.X, at.Y)
		end),
		Size = UDim2.fromOffset(200, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = scope:Computed(function(use): boolean
			return use(menuFor) ~= nil
		end),
		ZIndex = 20,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
			scope:New("TextLabel")({
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local target = use(menuFor)
					if not target then
						return ""
					end
					local char = target.Character
					local name = char and char:GetAttribute("CharName")
					return if type(name) == "string" then name else target.DisplayName
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.GoldBright,
			}),
			entry(1, "party.menu.invite", function(target)
				task.spawn(function()
					if invoke("PartyInviteUser", target.UserId) then
						Toast.push(Text.now("party.inviteSent", { name = target.DisplayName }), "success")
					end
				end)
			end),
			entry(2, "party.menu.trade", function(target)
				SocialController.RequestTrade(target.UserId)
			end),
			entry(3, "party.menu.duel", function(target)
				SocialController.Challenge(target.UserId)
			end),
			entry(
				4,
				"guild.menu.invite",
				function(target)
					task.spawn(function()
						if invoke("GuildInvite", target.UserId) then
							Toast.push(Text.now("guild.inviteSent", { name = target.DisplayName }), "success")
						end
					end)
				end,
				scope:Computed(function(use): boolean
					local rank = use(State.Value({ "guild", "myRank" }))
					return rank == "leader" or rank == "officer"
				end)
			),
			entry(5, "party.menu.profile", function(target)
				PartyController.OpenProfile(target.UserId)
			end),
		},
	})
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
	menuAt:set(at)
	menuFor:set(target)
end

function PartyController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	TargetController = registry.Get("TargetController")
	SocialController = registry.Get("SocialController")
	local UIController = registry.Get("UIController")
	WindowManager.Register({
		id = "party",
		titleKey = "window.party.title",
		size = Vector2.new(640, 560),
		hotkey = Enum.KeyCode.P,
		build = PartyWindow,
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
	-- The context menu lives in an unscaled ScreenGui so it opens exactly at the mouse.
	local gui = Instance.new("ScreenGui")
	gui.Name = "Vaelthorn_PlayerMenu"
	gui.DisplayOrder = 60
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	contextMenu().Parent = gui
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

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and Fusion.peek(menuFor) then
			-- Clicking elsewhere closes the menu (buttons handle their own click first).
			task.defer(function()
				menuFor:set(nil)
			end)
		end
		if processed or input.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		local target = playerAt(at)
		if target then
			PartyController.OpenMenu(target, at)
		end
	end)
end

return PartyController
