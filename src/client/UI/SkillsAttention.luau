--!strict
-- The "!" of the skills window (S59, ROZWOJ 4): a free path point with a node to buy, or a breakpoint with option B
-- and no choice. One rule (Logic/PathView.attention) for the HUD button and the window tabs. Reads only the narrow
-- state branches it needs (class, level, path), never the whole character (HP changes several times a second).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local State = require(script.Parent.State)

type Scope = Fusion.Scope<typeof(Fusion)>

local SkillsAttention = {}

local classId = State.Value({ "character", "class" })
local level = State.Value({ "character", "level" })
local path = State.Value({ "character", "path" })

function SkillsAttention.attention(scope: Scope): Fusion.Computed<PathView.Attention?>
	return scope:Computed(function(use): PathView.Attention?
		local class = use(classId)
		if type(class) ~= "string" or class == "" then
			return nil
		end
		local lvl = use(level)
		return PathView.attention({ class = class, level = if type(lvl) == "number" then lvl else 1, path = use(path) })
	end)
end

function SkillsAttention.badge(scope: Scope): Fusion.Computed<boolean>
	local attention = SkillsAttention.attention(scope)
	return scope:Computed(function(use): boolean
		local a = use(attention)
		return a ~= nil and a.any
	end)
end

return SkillsAttention
