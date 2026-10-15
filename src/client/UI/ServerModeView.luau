--!strict
-- The mode of the server the client is on (S127, DESIGN-17 §6), from the Workspace attribute ServerMode that the
-- server's Arena/ServerMode sets before any service starts: "world" (every public server), "arena" (a reserved server
-- of one global arena match) or "tournament" (S130). On a non-world server the client hides what needs the world
-- (the world map, travel, the quest journal) and shows "Entering the arena…" instead of the character list.

local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local ServerModeView = {}

function ServerModeView.mode(): string
	local mode = Workspace:GetAttribute("ServerMode")
	return if type(mode) == "string" then mode else "world"
end

function ServerModeView.isWorld(): boolean
	return ServerModeView.mode() == "world"
end

-- Whether this client just came back from an arena server (TeleportService:GetLocalPlayerTeleportData() returns the
-- TeleportData of the teleport that brought it here): the server picks the character itself.
function ServerModeView.backFromArena(): boolean
	local ok, data = pcall(function()
		return TeleportService:GetLocalPlayerTeleportData()
	end)
	return ok and type(data) == "table" and type((data :: any).arenaReturn) == "string"
end

return ServerModeView
