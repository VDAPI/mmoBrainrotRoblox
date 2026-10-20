--!strict
-- Season pass, client side (S152b, docs/DESIGN.md §21b): registers the season pass window ("season": key win_season,
-- the HUD button next to the login reward, the game menu, the shop's card), sends the claims (SeasonClaim,
-- SeasonClaimAll; an error becomes a toast) and opens the one purchase dialog (UI/SeasonPassBuy, "Top up" opens the
-- Dragon Shop on its currency tab). The server decides everything; the window shows account.season through
-- UI/SeasonState.
--   SeasonController.Open()  the window
--   SeasonController.Buy()   the purchase dialog of the premium track

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local SeasonPass = require(script.Parent.Parent.UI.Screens.SeasonPass)
local SeasonPassBuy = require(script.Parent.Parent.UI.SeasonPassBuy)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local SeasonController = {
	Name = "SeasonController",
	Deps = { "WindowManager", "PremiumController" },
}

local WindowManager: any
local PremiumController: any

local scope = Fusion.scoped(Fusion)
-- one claim at a time (the server answers before the next one goes)
local busy = scope:Value(false)

local function send(name: string, ...: any)
	if Fusion.peek(busy) then
		return
	end
	busy:set(true)
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = Net.Invoke(name, table.unpack(args, 1, args.n))
		busy:set(false)
		if ok then
			Sounds.play("levelUp")
		else
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

function SeasonController.Open()
	WindowManager.Open("season")
end

function SeasonController.Buy()
	SeasonPassBuy.ask(function()
		PremiumController.OpenShop("currency")
	end)
end

function SeasonController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	PremiumController = registry.Get("PremiumController")
	WindowManager.Register({
		id = "season",
		titleKey = "season.window.title",
		size = Vector2.new(1000, 660),
		hotkey = Enum.KeyCode.C, -- a fallback: WindowManager follows the win_season action
		build = function(s)
			return SeasonPass(s, {
				Claim = function(tier: number, track: string, seasonId: string)
					send("SeasonClaim", tier, track, seasonId)
				end,
				ClaimAll = function()
					send("SeasonClaimAll")
				end,
				Buy = SeasonController.Buy,
			})
		end,
	})
end

return SeasonController
