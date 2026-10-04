--!strict
-- Channel bar above the skill bar: channelled skills (Evocation, Prayer — state `skills.channel`) and the
-- Stone of Return (state `travel`). Fills over the channel time; disappears when done or interrupted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

type Channel = { label: string, endsAt: number, duration: number }

local function CastBar(scope: Scope): Instance
	local skillChannel = State.Value({ "skills", "channel" })
	local travel = State.Value({ "travel" })
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
			return { label = Text.get(use, "teleport.channel"), endsAt = t.endsAt, duration = t.duration or 5 }
		end
		local c = use(skillChannel)
		if type(c) == "table" and c.endsAt then
			local skill = SkillData.get(c.skill or "")
			return {
				label = if skill then Text.get(use, skill.nameKey) else Text.get(use, "cast.channel"),
				endsAt = c.endsAt,
				duration = c.duration or 3,
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
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(360, 26),
		BackgroundColor3 = Theme.Colors.Background,
		Visible = scope:Computed(function(use): boolean
			local c = use(channel)
			return c ~= nil and use(now) < c.endsAt
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 1 }),
			scope:New("Frame")({
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromScale(use(progress), 1)
				end),
				BackgroundColor3 = Theme.Colors.Accent,
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
				TextColor3 = Theme.Colors.Text,
				TextStrokeTransparency = 0.4,
				ZIndex = 2,
			}),
		},
	})
end

return CastBar
