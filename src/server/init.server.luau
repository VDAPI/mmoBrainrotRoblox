--!strict
-- Server bootstrap: remotes first, then every module in Services/ (Init -> Start).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Loader = require(Shared.Util.Loader)

-- Characters are spawned by CharacterService after the player picks one (also set in default.project.json).
Players.CharacterAutoLoads = false

Net.initServer()
-- S127: reserved arena/tournament servers learn their mode before any service starts (WorldService.Init builds only
-- their map and must not yield). World servers return at once.
local ServerMode = require(script:WaitForChild("Arena"):WaitForChild("ServerMode")) :: any
ServerMode.resolve()
Loader.load(script:WaitForChild("Services"), "Server")
