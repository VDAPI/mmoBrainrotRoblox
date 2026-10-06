--!strict
-- Dev panel, "Data" tab (S23): wipe the account (two confirmations), reward codes again, empty the backpack,
-- command list and the admin log.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NumberInput = require(script.Parent.Parent.Parent.Components.NumberInput)
local Text = require(script.Parent.Parent.Parent.Text)

local Dev = require(script.Parent.Dev)

local function Data(s: Dev.Scope): Instance
	local logCount = s:Value(20)

	local function wipe()
		-- First confirmation: the panel modal; the server then asks for "/wipe confirm" within 30 s, which the
		-- second modal sends.
		Dev.run("wipe", {}, function()
			Dev.confirm("dev.data.wipeTitle", "dev.data.wipeAgain", function()
				Dev.runConfirmed("wipe", { "confirm" })
			end)
		end)
	end

	return Dev.column(s, {
		Dev.header(s, 1, "dev.data.title"),
		Dev.row(s, 2, nil, {
			Dev.button(s, Text.T(s, "dev.data.wipe"), wipe, 200, true),
			Dev.button(s, Text.T(s, "dev.data.codes"), function()
				Dev.run("resetcodes")
			end, 200),
			Dev.button(s, Text.T(s, "dev.items.clear"), function()
				Dev.run("clearinv")
			end, 200, true),
		}),
		Dev.row(s, 3, nil, {
			Dev.button(s, "/help", function()
				Dev.run("help")
				Dev.Tab:set("console")
			end, 100),
			NumberInput(s, { Value = logCount, Min = 1, Max = 200, Step = 10 }),
			Dev.button(s, "/adminlog", function()
				Dev.run("adminlog", { tostring(Fusion.peek(logCount)) })
				Dev.Tab:set("console")
			end, 130),
		}),
		Dev.header(s, 4, "dev.allCommands"),
		Dev.commandRows(s, 5, { "data" }) :: any,
	})
end

return Data
