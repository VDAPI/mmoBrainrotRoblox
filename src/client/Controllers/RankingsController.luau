--!strict
-- Rankings (S124, DESIGN-17 §5): registers the Rankings window (UI/Screens/RankingsWindow) for the HUD menu entry, the
-- key win_rankings (Data/Keybinds, default R) and the Hall of Fame board in the city (FameBoardController).

local RankingsWindow = require(script.Parent.Parent.UI.Screens.RankingsWindow)

local RankingsController = {
	Name = "RankingsController",
	Deps = { "WindowManager" },
}

local WindowManager: any

function RankingsController.Open()
	WindowManager.Open("rankings")
end

function RankingsController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	WindowManager.Register({
		id = "rankings",
		titleKey = "window.rankings.title",
		-- review 2026-11-10: 720 tall, so the board shows 5 rows under the podium PC opens (WorldLayout.rankings)
		size = Vector2.new(900, 720),
		hotkey = Enum.KeyCode.R, -- a fallback: WindowManager follows the win_rankings action
		build = function(scope: any)
			return RankingsWindow(scope, nil)
		end,
	})
end

return RankingsController
