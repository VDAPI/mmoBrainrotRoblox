--!strict
-- Premium shop (◆) and wardrobe (♛) windows in the HUD menu (DESIGN §21–23).

local PremiumShop = require(script.Parent.Parent.UI.Screens.PremiumShop)
local Wardrobe = require(script.Parent.Parent.UI.Screens.Wardrobe)

local PremiumController = {
	Name = "PremiumController",
	Deps = { "WindowManager" },
}

function PremiumController.Init(registry)
	local WindowManager = registry.Get("WindowManager")
	WindowManager.Register({
		id = "premium",
		titleKey = "window.shop.premium",
		size = Vector2.new(820, 640),
		build = function(s)
			return PremiumShop(s, {
				ShowModal = WindowManager.ShowModal,
				OpenWardrobe = function()
					WindowManager.Close("premium")
					WindowManager.Open("wardrobe")
				end,
			})
		end,
	})
	WindowManager.Register({
		id = "wardrobe",
		titleKey = "window.wardrobe.title",
		size = Vector2.new(980, 640),
		build = Wardrobe,
	})
end

return PremiumController
