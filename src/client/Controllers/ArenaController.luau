--!strict
-- Ranked arena (S126, DESIGN-17 §6), client side: the arena window (UI/Screens/ArenaWindow: the HUD menu entry, the
-- key win_arena = U, the Arena Master's dialog), the match offer card (UI/Screens/ArenaOffer) and the queue / match
-- panel on the HUD (UI/Screens/Hud/ArenaPanel). Everything reads the state branches `character.arena` and
-- `arenaLive`; the only question to the server is ArenaStatus (on opening the window and every STATUS_EVERY s while
-- it is open). The server decides everything (ArenaService): these calls only ask.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaOffer = require(script.Parent.Parent.UI.Screens.ArenaOffer)
local ArenaPanel = require(script.Parent.Parent.UI.Screens.Hud.ArenaPanel)
local ArenaWindow = require(script.Parent.Parent.UI.Screens.ArenaWindow)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local ArenaController = {
	Name = "ArenaController",
	Deps = { "WindowManager", "UIController", "SfxController" },
}

local STATUS_EVERY = 10

local scope = Fusion.scoped(Fusion)
local WindowManager: any
local UIController: any
local SfxController: any

-- The last ArenaStatus answer ({ scope, waiting, busy?, pending }), nil before the first.
ArenaController.Status = scope:Value(nil :: any)
local live = State.Value({ "arenaLive" })
local polling = false

-- The text of an error key with its arguments (the server returns bare keys).
function ArenaController.ErrorText(key: string): string
	local args: { [string]: any }? = nil
	if key == "arena.error.level" or key == "arena.bracket.none" then
		args = { level = Arena.MIN_LEVEL }
	elseif key == "arena.error.penalty" then
		local value = Fusion.peek(live)
		local untilAt = if type(value) == "table" then tonumber(value.penaltyUntil) else nil
		args = { time = Time.format(if untilAt then untilAt - Workspace:GetServerTimeNow() else 0) }
	end
	return Text.now(key, args)
end

local function fail(err: any)
	Sounds.play("error")
	Toast.push(ArenaController.ErrorText(if type(err) == "string" then err else "error.internal"), "error")
end

local function call(remote: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = Net.Invoke(remote, table.unpack(args, 1, args.n))
		if not ok then
			fail(err)
		end
	end)
end

function ArenaController.Open()
	WindowManager.Open("arena")
end

function ArenaController.Join(mode: string)
	call("ArenaJoin", mode)
end

function ArenaController.Leave()
	call("ArenaLeave")
end

function ArenaController.Respond(accept: boolean)
	call("ArenaRespond", accept)
end

function ArenaController.Spectate()
	call("ArenaSpectate")
end

-- S127: leave the arena server now (after the result).
function ArenaController.ReturnNow()
	call("ArenaReturnNow")
end

function ArenaController.RefreshStatus()
	task.spawn(function()
		local ok, data = Net.Invoke("ArenaStatus")
		if ok and type(data) == "table" then
			ArenaController.Status:set(data)
		end
	end)
end

-- Asks for the status now and every STATUS_EVERY s while the window is open.
local function pollWhileOpen()
	ArenaController.RefreshStatus()
	if polling then
		return
	end
	polling = true
	task.spawn(function()
		local isOpen = WindowManager.IsOpen("arena")
		while true do
			task.wait(STATUS_EVERY)
			if not Fusion.peek(isOpen) then
				break
			end
			ArenaController.RefreshStatus()
		end
		polling = false
	end)
end

function ArenaController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	UIController = registry.Get("UIController")
	SfxController = registry.Get("SfxController")
	WindowManager.Register({
		id = "arena",
		titleKey = "window.arena.title",
		size = Vector2.new(940, 620),
		hotkey = Enum.KeyCode.U, -- a fallback: WindowManager follows the win_arena action
		build = function(s: any)
			pollWhileOpen()
			return ArenaWindow(s, {
				Status = ArenaController.Status,
				Join = ArenaController.Join,
				Leave = ArenaController.Leave,
				Spectate = ArenaController.Spectate,
				ErrorText = ArenaController.ErrorText,
			})
		end,
	})
	ArenaOffer(scope, { Respond = ArenaController.Respond }).Parent = UIController.GetLayer("Screens")
	ArenaPanel(scope, { Leave = ArenaController.Leave, ReturnNow = ArenaController.ReturnNow }).Parent =
		UIController.GetLayer("Screens")
end

function ArenaController.Start()
	-- a new match offer rings (the quest jingle: a short, clear call)
	local lastOffer: string? = nil
	scope:Observer(live):onChange(function()
		local value = Fusion.peek(live)
		local offer = if type(value) == "table" then value.offer else nil
		local id = if type(offer) == "table" then offer.id else nil
		if id and id ~= lastOffer then
			SfxController.Ui("ui.quest")
		end
		lastOffer = id
	end)
end

return ArenaController
