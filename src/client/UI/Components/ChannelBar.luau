--!strict
-- The bar of a boss's channel to break (S134, shared since S149b by the dungeon boss bar in DungeonController and the
-- world boss panel Hud/WorldBossPanel): the share of the damage that breaks it already dealt (fill), the seconds left
-- (text). `Channel` is the `channel` of the state branch ({ id, endsAt, need, done }) or nil (the bar hides); `Now`
-- the clock the branch's `endsAt` is measured in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Channel: UsedAs<any>,
	Now: UsedAs<number>,
	Position: UsedAs<UDim2>?,
	Size: UsedAs<UDim2>?,
	LayoutOrder: number?,
	Name: string?,
}

local function ChannelBar(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local ratio = scope:Computed(function(use): number
		local c = use(props.Channel)
		if type(c) ~= "table" then
			return 0
		end
		return math.clamp((tonumber(c.done) or 0) / math.max(1e-9, tonumber(c.need) or 1), 0, 1)
	end)
	return scope:New("Frame")({
		Name = props.Name or "ChannelBar",
		Position = props.Position,
		Size = props.Size or UDim2.new(1, 0, 0, 22),
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = Theme.Iron.Sunken,
		Visible = scope:Computed(function(use): boolean
			return type(use(props.Channel)) == "table"
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			scope:New("UIStroke")({ Color = Theme.Iron.Link, Thickness = 1.5 }),
			scope:New("Frame")({
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromScale(use(ratio), 1)
				end),
				BackgroundColor3 = Theme.Iron.Accent,
				[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			}),
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local c = use(props.Channel)
					if type(c) ~= "table" then
						return ""
					end
					local left = Time.remaining(tonumber(c.endsAt) or 0, use(props.Now))
					return Text.get(use, "boss.mechanic.channel.bar", { time = string.format("%.1f", left) })
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextStrokeTransparency = 0.3,
				ZIndex = 2,
			}),
		},
	})
end

return ChannelBar
