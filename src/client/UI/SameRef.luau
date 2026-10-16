--!strict
-- "Same reference = no change" for table-valued state (S134f). Fusion 0.3 treats an unfrozen table as never similar,
-- not even to itself, so every set of the same item table recomputes everything that depends on it. SameRef.of
-- mirrors a state object into a Value that is set only when the reference really changes; dependants (item slot
-- icon, texts, frame) then recompute only on a real change. Constants pass through unchanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local peek = Fusion.peek

type Scope = Fusion.Scope<typeof(Fusion)>

local SameRef = {}

local function isState(target: any): boolean
	return type(target) == "table" and target.type == "State"
end

function SameRef.of<T>(scope: Scope, source: Fusion.UsedAs<T>): Fusion.UsedAs<T>
	if not isState(source) then
		return source
	end
	local state = source :: any
	local out = scope:Value(peek(state))
	scope:Observer(state):onChange(function()
		local value = peek(state)
		if not rawequal(value, peek(out)) then
			out:set(value)
		end
	end)
	return out :: any
end

return SameRef
