--!strict
-- S134k: the hunting contract actions of the journal, the contract board and the NPC windows in one place: "Accept all"
-- and "Hand in all" at a giver (the NPC the player talks to, UI/NpcPresence), one contract from a row, "Abandon" (the
-- caller asks first). The server says what was taken and handed in (toasts, the completion message).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Sounds)
local Text = require(script.Parent.Text)
local Toast = require(script.Parent.Components.Toast)

local ContractActions = {}

local function call(name: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = Net.Invoke(name, table.unpack(args, 1, args.n))
		if ok then
			Sounds.play("levelUp")
		else
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

function ContractActions.acceptAll(npcId: string)
	call("ContractAccept", npcId)
end

function ContractActions.turnInAll(npcId: string)
	call("ContractTurnIn", npcId)
end

function ContractActions.acceptOne(npcId: string, level: number)
	call("ContractAcceptOne", npcId, level)
end

function ContractActions.abandon(level: number)
	call("ContractAbandon", level)
end

return ContractActions
