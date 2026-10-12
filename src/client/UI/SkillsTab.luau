--!strict
-- A tab the skills window should open (S57): the Scroll of a New Path asks for the main path's tab. The window watches
-- `Requested` (also while it is open) and takes the request once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

local SkillsTab = {}

SkillsTab.Requested = scope:Value(nil :: string?)

function SkillsTab.request(tabId: string)
	SkillsTab.Requested:set(tabId)
end

-- The requested tab (nil: none), cleared once taken.
function SkillsTab.take(): string?
	local tab = Fusion.peek(SkillsTab.Requested)
	if tab ~= nil then
		SkillsTab.Requested:set(nil)
	end
	return tab
end

return SkillsTab
