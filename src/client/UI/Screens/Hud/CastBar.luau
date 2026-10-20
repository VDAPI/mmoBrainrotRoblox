--!strict
-- Channel bar above the skill bar: channelled skills (Evocation, Prayer — state `skills.channel`) and the
-- teleport stones (state `travel`), gathering (state `gather`) and quest interactions (S27, state `questUse`). Fills
-- over the channel time; disappears when done or interrupted. S76: aiming (castTime, `kind = "castTime"`) reads
-- "Aiming: <skill>" in the danger colour. S96: mounting (state `mountCast` = { endsAt, duration, label }).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

type Channel = { label: string, endsAt: number, duration: number, aiming: boolean? }

local function CastBar(scope: Scope): Instance
	local skillChannel = State.Value({ "skills", "channel" })
	local travel = State.Value({ "travel" })
	local gather = State.Value({ "gather" })
	local questUse = State.Value({ "questUse" }) -- S27: holding a quest interaction
	local mountCast = State.Value({ "mountCast" }) -- S96: mounting
	local now = scope:Value(Workspace:GetServerTimeNow())
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			now:set(Workspace:GetServerTimeNow())
		end)
	)

	local channel = scope:Computed(function(use): Channel?
		local t = use(travel)
		if type(t) == "table" and t.endsAt then
			return {
				label = Text.get(use, if type(t.label) == "string" then t.label else "teleport.channel"),
				endsAt = t.endsAt,
				duration = t.duration or 5,
			}
		end
		local m = use(mountCast)
		if type(m) == "table" and m.endsAt then
			return {
				label = Text.get(use, if type(m.label) == "string" then m.label else "mount.casting"),
				endsAt = m.endsAt,
				duration = m.duration or 1.5,
			}
		end
		local u = use(questUse)
		if type(u) == "table" and u.endsAt then
			return {
				label = Text.get(use, if type(u.label) == "string" then u.label else "quest.use.default"),
				endsAt = u.endsAt,
				duration = u.duration or 2,
			}
		end
		local g = use(gather)
		if type(g) == "table" and g.endsAt then
			return {
				label = Text.get(use, if g.category == "ore" then "gather.mining" else "gather.picking"),
				endsAt = g.endsAt,
				duration = g.duration or 2,
			}
		end
		local c = use(skillChannel)
		if type(c) == "table" and c.endsAt then
			local skill = SkillData.get(c.skill or "")
			local aiming = c.kind == "castTime"
			local name = if skill then Text.get(use, skill.nameKey) else Text.get(use, "cast.channel")
			return {
				label = if aiming then Text.get(use, "cast.aiming", { skill = name }) else name,
				endsAt = c.endsAt,
				duration = c.duration or 3,
				aiming = aiming,
			}
		end
		return nil
	end)
	local progress = scope:Computed(function(use): number
		local c = use(channel)
		if not c then
			return 0
		end
		return math.clamp(1 - (c.endsAt - use(now)) / math.max(0.1, c.duration), 0, 1)
	end)

	return scope:New("Frame")({
		Name = "CastBar",
		-- W29: under the target frame on a phone in landscape (Logic/PhoneHud)
		AnchorPoint = PhoneLayout.Anchor(scope, "castBar", Vector2.new(0.5, 1)),
		Position = PhoneLayout.Position(scope, "castBar", UDim2.new(0.5, 0, 1, -100)),
		Size = PhoneLayout.Size(scope, "castBar", UDim2.fromOffset(360, 26)),
		BackgroundColor3 = Theme.Resource.Track,
		Visible = scope:Computed(function(use): boolean
			local c = use(channel)
			return c ~= nil and use(now) < c.endsAt
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("Frame")({
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromScale(use(progress), 1)
				end),
				BackgroundColor3 = scope:Computed(function(use): Color3
					local c = use(channel)
					return if c and c.aiming then Theme.Resource.Hp else Theme.Resource.Mana
				end),
				[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			}),
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local c = use(channel)
					return if c then c.label else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextStrokeTransparency = 0.4,
				ZIndex = 2,
			}),
		},
	})
end

return CastBar
