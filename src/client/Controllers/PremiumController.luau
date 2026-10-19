--!strict
-- Premium shop (◆) and wardrobe (♛) windows in the HUD menu (DESIGN §21–23). S120: the Dragon Shop with tabs
-- (UI/Screens/PremiumShop), the purchase confirmation (UI/PremiumConfirm), OpenShop(tab) for later sessions and
-- OpenWardrobe(start) on a cosmetic kind with a cosmetic tried on. No key: the HUD menu button opens the shop.
-- S121: the VIP window ("vip", no key: the game menu, the Passes tab and its VIP card open it).
-- S123: the wardrobe previews emotes and level-up effects on the own character in the world (EmoteController,
-- EffectsController; nobody else sees them).
-- S132 (DESIGN-17 §9a): the look window ("look": face, skin, hair; the wardrobe's button and the barber open it).
-- S152b: the Passes tab's season pass card opens the season pass window and its purchase dialog (SeasonController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRules = require(ReplicatedStorage.Shared.Logic.CosmeticRules)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)

local LookWindow = require(script.Parent.Parent.UI.Screens.LookWindow)

local PremiumConfirm = require(script.Parent.Parent.UI.PremiumConfirm)
local PremiumShop = require(script.Parent.Parent.UI.Screens.PremiumShop)
local VipWindow = require(script.Parent.Parent.UI.Screens.VipWindow)
local Wardrobe = require(script.Parent.Parent.UI.Screens.Wardrobe)
local WardrobeStart = require(script.Parent.Parent.UI.WardrobeStart)

local PremiumController = {
	Name = "PremiumController",
	Deps = { "WindowManager", "EmoteController", "EffectsController" },
}

local Registry: any
local WindowManager: any
local EmoteController: any
local EffectsController: any

-- Opens the Dragon Shop, on `tab` when it is given and visible (S121–S123 open their own tab).
function PremiumController.OpenShop(tab: string?)
	if tab then
		PremiumShop.select(tab)
	end
	WindowManager.Close("wardrobe")
	WindowManager.Open("premium")
end

-- Closes the shop and opens the wardrobe, on the `start.kind` tab with `start.try` tried on when given.
function PremiumController.OpenWardrobe(start: { kind: string?, try: string? }?)
	WindowManager.Close("premium")
	WindowManager.Close("wardrobe")
	WardrobeStart.kind = if start then start.kind else nil
	WardrobeStart.try = if start then start.try else nil
	WindowManager.Open("wardrobe")
end

-- S132: the look window (closes the wardrobe and the shop so they never overlap on a phone).
function PremiumController.OpenLook()
	WindowManager.Close("premium")
	WindowManager.Close("wardrobe")
	WindowManager.Open("look")
end

-- S121: the VIP window (closes the shop so the two never overlap on a phone).
function PremiumController.OpenVip()
	WindowManager.Close("premium")
	WindowManager.Open("vip")
end

function PremiumController.Init(registry)
	Registry = registry
	WindowManager = registry.Get("WindowManager")
	EmoteController = registry.Get("EmoteController")
	EffectsController = registry.Get("EffectsController")
	PremiumConfirm.setShowModal(WindowManager.ShowModal)
	WindowManager.Register({
		id = "premium",
		titleKey = "window.shop.premium",
		size = Vector2.new(900, 640),
		build = function(s)
			return PremiumShop.build(s, {
				ShowModal = WindowManager.ShowModal,
				OpenWardrobe = PremiumController.OpenWardrobe,
				Select = PremiumShop.select,
				OpenVip = PremiumController.OpenVip,
				-- S152b: the season pass card (SeasonController depends on this controller: looked up when used)
				OpenSeason = function()
					Registry.Get("SeasonController").Open()
				end,
				BuySeason = function()
					Registry.Get("SeasonController").Buy()
				end,
			})
		end,
	})
	WindowManager.Register({
		id = "wardrobe",
		titleKey = "window.wardrobe.title",
		size = Vector2.new(980, 640),
		build = function(s)
			return Wardrobe(s, {
				OpenShop = function(tab: string?)
					PremiumController.OpenShop(tab or "currency")
				end,
				-- S123: local previews (only this client sees them)
				PreviewEmote = EmoteController.Preview,
				OpenLook = PremiumController.OpenLook, -- S132
				-- S154: the weapon looks tab leads to the blacksmith (NpcController looked up when used)
				GuideToSmith = function()
					WindowManager.Close("wardrobe")
					Registry.Get("NpcController").GuideToNpc("blacksmith")
				end,
				PreviewLevelUp = function(cosmeticId: string)
					local model = Players.LocalPlayer.Character
					if model then
						EffectsController.PlayLevelUp(model, CosmeticRules.levelUpStyle(Cosmetics.get(cosmeticId)))
					end
				end,
			})
		end,
	})
	WindowManager.Register({
		id = "look",
		titleKey = "window.look.title",
		size = Vector2.new(820, 600),
		build = function(s)
			return LookWindow(s)
		end,
	})
	WindowManager.Register({
		id = "vip",
		titleKey = "window.vip.title",
		size = Vector2.new(760, 620),
		build = function(s)
			return VipWindow.build(s, {
				OpenWardrobe = function()
					WindowManager.Close("vip")
					PremiumController.OpenWardrobe(nil)
				end,
			})
		end,
	})
end

return PremiumController
