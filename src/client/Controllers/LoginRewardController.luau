--!strict
-- Login reward (S100, docs/DESIGN-15.md §5), client side: the "login" window, the streak status for the HUD button
-- (Status, Badge) and the window that opens on its own once a day. The server decides the day and the contents
-- (ClaimLoginReward); the client only shows account.login and the UTC day of the shared clock (Util/Clock).
-- Opening on its own: in the world, a reward waiting, with no modal and no window open (it waits until the player
-- closes it), 2 s after entering (the map loads); S155: no longer after the S14 guide, the tutorial hint of a new
-- character waits for this window instead (TutorialController). Once per "<UTC day>:<last>" in this client session:
-- closing the window keeps it closed today (also after a character switch), /loginset and /loginnext (a new `last`)
-- open it again. Midnight UTC during play only lights the badge.
-- S155b: not while the character's tutorial runs (a new player's first sight is the "move" hint, not a window); the
-- badge on the HUD button still lights, and the window opens on its own once the tutorial is finished or skipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LoginReward = require(ReplicatedStorage.Shared.Logic.LoginReward)
local LoginRewardWindow = require(script.Parent.Parent.UI.Screens.LoginReward)
local Net = require(ReplicatedStorage.Shared.Net)
local ServerModeView = require(script.Parent.Parent.UI.ServerModeView)
local State = require(script.Parent.Parent.UI.State)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Tutorial = require(ReplicatedStorage.Shared.Logic.Tutorial)

local LoginRewardController = {
	Name = "LoginRewardController",
	Deps = { "WindowManager" },
}

local WindowManager: any

local ENTER_DELAY = 2 -- seconds after entering the world (the map loads)
local RETRY = 1 -- seconds between checks while a window or a modal is open
local DAY_CHECK = 30 -- seconds between checks of the UTC day (the badge lights at midnight)

local scope = Fusion.scoped(Fusion)
local login = State.Value({ "account", "login" })
local today = scope:Value(Time.dayNumber(Clock.now()))

-- The streak status today; nil before the account arrives.
LoginRewardController.Status = scope:Computed(function(use): LoginReward.Status?
	local raw = use(login)
	if raw == nil then
		return nil
	end
	return LoginReward.status(LoginReward.sanitize(raw), use(today))
end)

-- A reward waits today (the "!" on the HUD button).
LoginRewardController.Badge = scope:Computed(function(use): boolean
	local status = use(LoginRewardController.Status)
	return status ~= nil and status.claimable
end)

local shownKey: string? = nil -- "<UTC day>:<last>" of the last automatic opening
local pending = false

local function keyNow(): string
	local state = LoginReward.sanitize(State.Get({ "account", "login" }))
	return `{Time.dayNumber(Clock.now())}:{state.last}`
end

-- Whether the window may open on its own now (apart from other windows and modals).
local function wanted(): boolean
	if State.Get({ "session", "phase" }) ~= "playing" then
		return false
	end
	if not ServerModeView.isWorld() then
		return false -- S127: no window popping up on an arena server (the reward waits for the world)
	end
	local tutorial = State.Get({ "character", "tutorial" })
	if tutorial ~= nil and Tutorial.current(Tutorial.sanitize(tutorial)) ~= nil then
		return false -- S155b: the tutorial comes first
	end
	-- A fresh UTC day (Status follows `today`, refreshed only every DAY_CHECK)
	local raw = State.Get({ "account", "login" })
	if raw == nil then
		return false
	end
	local status = LoginReward.status(LoginReward.sanitize(raw), Time.dayNumber(Clock.now()))
	return status.claimable and shownKey ~= keyNow()
end

local function check()
	if pending or not wanted() then
		return
	end
	pending = true
	task.spawn(function()
		task.wait(ENTER_DELAY)
		while wanted() do
			if Fusion.peek(WindowManager.IsOpen("login")) then
				shownKey = keyNow() -- opened by the player meanwhile: closing it keeps it closed today
				break
			end
			if not WindowManager.HasModal() and not WindowManager.AnyOpen() then
				shownKey = keyNow()
				WindowManager.Open("login")
				break
			end
			task.wait(RETRY)
		end
		pending = false
	end)
end

function LoginRewardController.Open()
	WindowManager.Open("login")
end

-- S155: whether the window waits to open on its own (the tutorial hint waits for it).
function LoginRewardController.Pending(): boolean
	return pending
end

function LoginRewardController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	WindowManager.Register({
		id = "login",
		titleKey = "window.login.title",
		size = Vector2.new(860, 520),
		build = function(s, close)
			shownKey = keyNow() -- any opening counts as shown today
			return LoginRewardWindow(s, {
				Claim = function(): (boolean, string?, any?)
					return Net.Invoke("ClaimLoginReward")
				end,
				Close = close,
			})
		end,
	})
end

function LoginRewardController.Start()
	scope:Observer(State.Value({ "session", "phase" })):onBind(check)
	scope:Observer(login):onBind(check)
	scope:Observer(State.Value({ "character", "tutorial" })):onChange(check) -- S155b: finished or skipped
	task.spawn(function()
		while true do
			task.wait(DAY_CHECK)
			today:set(Time.dayNumber(Clock.now()))
		end
	end)
end

return LoginRewardController
