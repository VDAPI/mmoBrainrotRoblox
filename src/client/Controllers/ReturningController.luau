--!strict
-- Help for returning players, client side (S153, docs/DESIGN.md §11): the "What has changed" window ("whatsnew"). It
-- opens on its own once when the character is in the world and Logic/Returning.letter finds entries newer than
-- account.returning.seen: on a world server (S155: no S14 guide to wait for any more), with no cutscene, modal or window open
-- (so after the login reward window; it waits until the player closes it) and with the world loaded (as
-- CutsceneController's idle), ENTER_DELAY s after entering. The player closing it (the button, the X, Esc, another
-- window) sends ChangelogSeen (the newest id shown); a cutscene's CloseAll does not, so the letter comes back after
-- the scene. The server owns `seen`. From the game menu ("What's new") it shows the latest entries regardless of
-- `seen` (and marks the new ones read too).
-- The bonus itself is all server-side (ReturningService); its HUD icon is Hud/BlessingIcon.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Changelog = require(ReplicatedStorage.Shared.Data.Changelog)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Returning = require(ReplicatedStorage.Shared.Logic.Returning)
local ServerModeView = require(script.Parent.Parent.UI.ServerModeView)
local State = require(script.Parent.Parent.UI.State)
local WhatsNew = require(script.Parent.Parent.UI.Screens.WhatsNew)

local ReturningController = {
	Name = "ReturningController",
	Deps = { "WindowManager", "CutsceneController", "WorldController" },
}

local WindowManager: any
local CutsceneController: any
local WorldController: any

local ENTER_DELAY = 4 -- seconds after entering the world (after the login reward window's 2 s)
local RETRY = 1 -- seconds between checks while a window, a modal or a cutscene is in the way

local scope = Fusion.scoped(Fusion)
local pending = false
local letterNext = false -- the next build shows the letter (new entries) instead of the latest ones
local sentUpTo = 0 -- the highest id sent this session (the server's answer comes with the state)
local serverSeen = 0 -- the last `seen` the server sent (a drop = /returning letter)

local function seen(): number
	return math.max(Returning.sanitize(State.Get({ "account", "returning" })).seen, sentUpTo)
end

local function letterNow(): { Changelog.Entry }
	if State.Get({ "account", "returning" }) == nil then
		return {}
	end
	return Returning.letter(seen(), Changelog.ENTRIES, Clock.now())
end

local function wanted(): boolean
	if State.Get({ "session", "phase" }) ~= "playing" or not ServerModeView.isWorld() then
		return false
	end
	return #letterNow() > 0
end

-- The world is loaded and the character stands in it (as CutsceneController's idle).
local function ready(): boolean
	local character = Players.LocalPlayer.Character
	return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil and not WorldController.IsLoading()
end

local function check()
	if pending or not wanted() then
		return
	end
	pending = true
	task.spawn(function()
		task.wait(ENTER_DELAY)
		while wanted() do
			if Fusion.peek(WindowManager.IsOpen("whatsnew")) then
				break
			end
			if
				ready()
				and not CutsceneController.IsPlaying()
				and not WindowManager.HasModal()
				and not WindowManager.AnyOpen()
			then
				letterNext = true
				WindowManager.Open("whatsnew")
				break
			end
			task.wait(RETRY)
		end
		pending = false
	end)
end

-- Marks the entries up to the newest shown read (only when something new was among them).
local function markRead(entries: { Changelog.Entry })
	local top = 0
	for _, e in entries do
		top = math.max(top, e.id)
	end
	if top > seen() then
		sentUpTo = top
		Net.Send("ChangelogSeen", top)
	end
end

-- S155: whether the window waits to open on its own (the tutorial hint waits for it).
function ReturningController.Pending(): boolean
	return pending
end

function ReturningController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	CutsceneController = registry.Get("CutsceneController")
	WorldController = registry.Get("WorldController")
	WindowManager.Register({
		id = "whatsnew",
		titleKey = "changelog.window.title",
		size = Vector2.new(720, 620),
		build = function(s, close)
			local entries = if letterNext then letterNow() else Returning.recent(Changelog.ENTRIES, Clock.now())
			letterNext = false
			-- the player closing it (the button, the X, Esc, another window) counts as read; a cutscene's CloseAll (it
			-- sets IsPlaying first) does not, and check() shows the letter again after the scene
			table.insert(s :: any, function()
				if CutsceneController.IsPlaying() then
					check()
				else
					markRead(entries)
				end
			end)
			return WhatsNew(s, { Entries = entries, Close = close })
		end,
	})
end

function ReturningController.Start()
	scope:Observer(State.Value({ "session", "phase" })):onBind(check)
	scope:Observer(State.Value({ "account", "returning" })):onBind(function()
		local raw = State.Get({ "account", "returning" })
		if raw ~= nil then
			local now = Returning.sanitize(raw).seen
			if now < serverSeen then
				sentUpTo = 0 -- /returning letter: the server set `seen` back
			end
			serverSeen = now
		end
		check()
	end)
end

return ReturningController
