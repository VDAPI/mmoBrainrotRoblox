--!strict
-- Player-to-player on the client (S10): duel and trade invitations (popup with Accept / Decline and a
-- countdown), the trade window (opens with state `trade`, closing it cancels the trade) and the kill feed
-- (right side, map-local, 5 s per line).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.UI.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local TradeWindow = require(script.Parent.Parent.UI.Screens.TradeWindow)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SocialController = {
	Name = "SocialController",
	Deps = { "WindowManager", "UIController" },
}

local FEED_SECONDS = 5
local FEED_MAX = 5

local scope = Fusion.scoped(Fusion)
local WindowManager: any

type Invite = { kind: "duel" | "trade", from: string, left: number }
local invite = scope:Value(nil :: Invite?)
local feed = scope:Value({} :: { { text: string, at: number } })

local function invoke(name: string, ...: any): boolean
	local ok, err = Net.Invoke(name, ...)
	if not ok then
		Sounds.play("error")
		Toast.push(Text.now(err or "error.internal"), "error")
	end
	return ok
end

function SocialController.Challenge(userId: number)
	task.spawn(function()
		if invoke("DuelChallenge", userId) then
			Toast.push(Text.now("duel.sent"), "success")
		end
	end)
end

function SocialController.RequestTrade(userId: number)
	task.spawn(function()
		if invoke("TradeRequest", userId) then
			Toast.push(Text.now("trade.sent"), "success")
		end
	end)
end

local function respond(accept: boolean)
	local current = Fusion.peek(invite)
	invite:set(nil)
	if current then
		task.spawn(invoke, if current.kind == "duel" then "DuelRespond" else "TradeRespond", accept)
	end
end

local function showInvite(kind: "duel" | "trade", from: string, seconds: number)
	Sounds.play("levelUp")
	local entry: Invite = { kind = kind, from = from, left = seconds }
	invite:set(entry)
	task.spawn(function()
		while Fusion.peek(invite) == entry and entry.left > 0 do
			task.wait(1)
			if Fusion.peek(invite) ~= entry then
				return
			end
			local updated = table.clone(entry)
			updated.left -= 1
			entry = updated
			invite:set(updated)
		end
		if Fusion.peek(invite) == entry then
			invite:set(nil)
		end
	end)
end

local function invitePopup(): Instance
	return scope:New("Frame")({
		Name = "SocialInvite",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 260),
		Size = UDim2.fromOffset(460, 130),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = scope:Computed(function(use): boolean
			return use(invite) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 1.5 }),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(16, 10),
				Size = UDim2.new(1, -32, 0, 50),
				BackgroundTransparency = 1,
				TextWrapped = true,
				Text = scope:Computed(function(use): string
					local i = use(invite)
					if not i then
						return ""
					end
					return Text.get(use, if i.kind == "duel" then "duel.invited" else "trade.invited", {
						name = i.from,
						seconds = i.left,
					})
				end),
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

local function killFeed(): Instance
	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		for i, entry in use(feed) do
			table.insert(
				list,
				s:New("TextLabel")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = Theme.Colors.Panel,
					BackgroundTransparency = 0.35,
					Text = entry.text,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 16,
					TextColor3 = Theme.Colors.Text,
					TextXAlignment = Enum.TextXAlignment.Right,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
					},
				})
			)
		end
		return list
	end)
	return scope:New("Frame")({
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Theme.Padding.Large, 0, 380),
		Size = UDim2.fromOffset(340, FEED_MAX * 30),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
			}),
			rows :: any,
		},
	})
end

function SocialController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	local UIController = registry.Get("UIController")
	WindowManager.Register({
		id = "trade",
		titleKey = "window.trade.title",
		size = Vector2.new(640, 520),
		build = TradeWindow,
	})
	invitePopup().Parent = UIController.GetLayer("Modals")
	killFeed().Parent = UIController.GetLayer("Screens")
end

function SocialController.Start()
	Net.On("DuelInvited", function(from: string, seconds: number)
		showInvite("duel", from, seconds)
	end)
	Net.On("TradeInvited", function(from: string, seconds: number)
		showInvite("trade", from, seconds)
	end)
	Net.On("KillFeed", function(killer: string, victim: string)
		local list = table.clone(Fusion.peek(feed))
		table.insert(list, { text = `{killer}  ⚔  {victim}`, at = os.clock() })
		while #list > FEED_MAX do
			table.remove(list, 1)
		end
		feed:set(list)
		task.delay(FEED_SECONDS, function()
			local current = Fusion.peek(feed)
			local kept = {}
			for _, entry in current do
				if os.clock() - entry.at < FEED_SECONDS then
					table.insert(kept, entry)
				end
			end
			feed:set(kept)
		end)
	end)

	-- The trade window follows the trade state; closing it cancels the trade.
	local tradeOpen = WindowManager.IsOpen("trade")
	scope:Observer(State.Value({ "trade" })):onChange(function()
		if State.Get({ "trade" }) ~= nil then
			if not Fusion.peek(tradeOpen) then
				WindowManager.Open("trade")
				WindowManager.Open("inventory")
			end
		elseif Fusion.peek(tradeOpen) then
			WindowManager.Close("trade")
		end
	end)
	scope:Observer(tradeOpen):onChange(function()
		if not Fusion.peek(tradeOpen) and State.Get({ "trade" }) ~= nil then
			Net.Send("TradeCancel")
		end
	end)
end

return SocialController
