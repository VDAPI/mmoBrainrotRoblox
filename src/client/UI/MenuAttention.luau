--!strict
-- S155b: the HUD explains itself. The "!" of HUD menu buttons beyond the skills window (SkillsAttention):
--   * the backpack button while stat points wait to be spent (they are spent in the backpack window);
--   * a button whose feature a level up just unlocked (Logic/Unlocks, marked by UnlockController) until its window
--     is first opened in this session.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.State)

type Scope = Fusion.Scope<typeof(Fusion)>

local MenuAttention = {}

local scope = Fusion.scoped(Fusion)
local fresh = scope:Value({} :: { [string]: boolean })
local statPoints = State.Value({ "character", "statPoints" })

-- Marks the window `id` as newly unlocked.
function MenuAttention.mark(id: string)
	local now = table.clone(Fusion.peek(fresh))
	now[id] = true
	fresh:set(now)
end

-- The window `id` was opened: no longer new.
function MenuAttention.clear(id: string)
	local now = Fusion.peek(fresh)
	if now[id] then
		local out = table.clone(now)
		out[id] = nil
		fresh:set(out)
	end
end

-- Badge of a newly unlocked window (a HUD MenuEntry.badge).
function MenuAttention.unlocked(id: string): (s: Scope) -> Fusion.Computed<boolean>
	return function(s: Scope): Fusion.Computed<boolean>
		return s:Computed(function(use): boolean
			return use(fresh)[id] == true
		end)
	end
end

-- Badge of the backpack button: unspent stat points.
function MenuAttention.statPoints(s: Scope): Fusion.Computed<boolean>
	return s:Computed(function(use): boolean
		local n = use(statPoints)
		return type(n) == "number" and n > 0
	end)
end

return MenuAttention
