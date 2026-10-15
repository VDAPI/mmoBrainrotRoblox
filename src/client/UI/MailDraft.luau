--!strict
-- S133: the letter being written (MailCompose): who it goes to. The player menu, the friends window, the mail window
-- and "the player is on another server" set it before the compose window opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

return {
	To = scope:Value(""),
	-- bumped on every "write to ..." so the compose window clears the rest of the previous letter
	Fresh = scope:Value(0),
}
