--!strict
-- Auction house and mail on the client (DESIGN §18): the auction window (Auctioneer, service "auction"),
-- the mail window (service "mail", or the mail icon of the HUD: owner 2026-10-21, Hud/MailButton shows the number of
-- parcels waiting). Collecting needs the mailbox nearby; AtMailbox follows the distance to the Auctioneer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AuctionWindow = require(script.Parent.Parent.UI.Screens.AuctionWindow)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MailCompose = require(script.Parent.Parent.UI.Screens.MailCompose)
local MailWindow = require(script.Parent.Parent.UI.Screens.MailWindow)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)

local MarketController = {
	Name = "MarketController",
	Deps = { "WindowManager", "NotificationController", "SocialController" }, -- S133: SocialController
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

function MarketController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	local NotificationController = registry.Get("NotificationController")
	local SocialController = registry.Get("SocialController")
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
			return MailWindow(s, {
				ResolveArgs = NotificationController.ResolveArgs,
				AtMailbox = atMailbox,
				Compose = SocialController.ComposeTo,
				IgnoreName = SocialController.IgnoreByName,
			})
		end,
	})
	-- S133: a letter to another player (SocialController.ComposeTo fills the recipient and opens it)
	WindowManager.Register({
		id = "mailCompose",
		titleKey = "window.mailCompose.title",
		size = Vector2.new(760, 680),
		build = function(s, close)
			return MailCompose(s, { AtMailbox = atMailbox, Close = close })
		end,
	})
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
