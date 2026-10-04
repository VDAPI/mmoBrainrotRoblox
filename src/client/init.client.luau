--!strict
-- Client bootstrap: wait for remotes, then load every module in Controllers/ (Init -> Start).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Loader = require(Shared.Util.Loader)

Net.initClient()
Loader.load(script:WaitForChild("Controllers"), "Client")
