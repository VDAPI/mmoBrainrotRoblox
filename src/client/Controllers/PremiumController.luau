--!strict
-- Premium shop (◆) and wardrobe (♛) windows in the HUD menu (DESIGN §21–23). S120: the Dragon Shop with tabs
-- (UI/Screens/PremiumShop), the purchase confirmation (UI/PremiumConfirm), OpenShop(tab) for later sessions and
-- OpenWardrobe(start) on a cosmetic kind with a cosmetic tried on. No key: the HUD menu button opens the shop.

local PremiumConfirm = require(script.Parent.Parent.UI.PremiumConfirm)
local PremiumShop = require(script.Parent.Parent.UI.Screens.PremiumShop)
local Wardrobe = require(script.Parent.Parent.UI.Screens.Wardrobe)
local WardrobeStart = require(script.Parent.Parent.UI.WardrobeStart)

local PremiumController = {
	Name = "PremiumController",
	Deps = { "WindowManager" },
}

local WindowManager: any

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

function PremiumController.Init(registry)
	WindowManager = registry.Get("WindowManager")
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
			})
		end,
	})
	WindowManager.Register({
		id = "wardrobe",
		titleKey = "window.wardrobe.title",
		size = Vector2.new(980, 640),
		build = function(s)
			return Wardrobe(s, {
				OpenShop = function()
					PremiumController.OpenShop("currency")
				end,
			})
		end,
	})
end

return PremiumController
