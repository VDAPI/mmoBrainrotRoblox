--!strict
-- Auction house and mail on the client (DESIGN §18): the auction window (Auctioneer, service "auction"),
-- the mail window (service "mail", or the HUD envelope), and the HUD envelope with the number of parcels
-- waiting. Collecting needs the mailbox nearby; AtMailbox follows the distance to the Auctioneer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AuctionWindow = require(script.Parent.Parent.UI.Screens.AuctionWindow)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MailWindow = require(script.Parent.Parent.UI.Screens.MailWindow)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local State = require(script.Parent.Parent.UI.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

local MarketController = {
	Name = "MarketController",
	Deps = { "WindowManager", "UIController", "NotificationController" },
}

local MAILBOX_NPCS: { string } = {}
for _, def in Npcs.list do
	if table.find(def.services, "mail" :: any) then
		table.insert(MAILBOX_NPCS, def.id)
	end
end

local scope = Fusion.scoped(Fusion)
local WindowManager: any
local auctionTab = scope:Value("browse")
local atMailbox = scope:Value(false)

function MarketController.OpenAuction()
	WindowManager.Close("npc")
	WindowManager.Open("auction")
end

function MarketController.OpenMail()
	WindowManager.Close("npc")
	WindowManager.Open("mail")
end

local function envelope(): Instance
	local count = scope:Computed(function(use): number
		local mail = use(State.Value({ "mail" }))
		return if type(mail) == "table" then mail.count or 0 else 0
	end)
	return scope:New("TextButton")({
		Name = "MailEnvelope",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Theme.Padding.Large),
		Size = UDim2.fromOffset(84, 52),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = scope:Computed(function(use): boolean
			return use(count) > 0 and use(State.Value({ "session", "phase" })) == "playing"
		end),
		Text = scope:Computed(function(use): string
			return `✉ {use(count)}`
		end),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Large,
		TextColor3 = Theme.Colors.GoldBright,
		[OnEvent("Activated")] = function()
			WindowManager.Toggle("mail")
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 1.5 }),
		},
	})
end

function MarketController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	local NotificationController = registry.Get("NotificationController")
	local UIController = registry.Get("UIController")
	WindowManager.Register({
		id = "auction",
		titleKey = "window.auction.title",
		size = Vector2.new(1080, 700),
		build = function(s)
			return AuctionWindow(s, { ShowModal = WindowManager.ShowModal, Tab = auctionTab })
		end,
	})
	WindowManager.Register({
		id = "mail",
		titleKey = "window.mail.title",
		size = Vector2.new(900, 620),
		build = function(s)
			return MailWindow(s, { ResolveArgs = NotificationController.ResolveArgs, AtMailbox = atMailbox })
		end,
	})
	envelope().Parent = UIController.GetLayer("Screens")
end

function MarketController.Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local world = Workspace:FindFirstChild("World")
			local folder = world and world:FindFirstChild("Npcs")
			local near = false
			if root and folder then
				for _, id in MAILBOX_NPCS do
					local model = folder:FindFirstChild(id) :: Model?
					if model and (model:GetPivot().Position - root.Position).Magnitude <= Npcs.INTERACT_RANGE + 6 then
						near = true
					end
				end
			end
			if Fusion.peek(atMailbox) ~= near then
				atMailbox:set(near)
			end
		end
	end)
end

return MarketController
