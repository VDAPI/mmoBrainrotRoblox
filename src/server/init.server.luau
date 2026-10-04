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
Loader.load(script:WaitForChild("Services"), "Server")
