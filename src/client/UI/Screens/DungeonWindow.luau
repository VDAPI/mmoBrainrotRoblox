--!strict
-- Dungeon gate window (DESIGN §16): boss name and level, required level, state (free / taken by X's group
-- with the time left), every party member with ✓ / ✗ and why (level, daily lockout with the time to reset,
-- too far), and "Enter" for the leader.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Region: Fusion.UsedAs<string?>,
	Close: () -> (),
}

local function DungeonWindow(scope: Scope, props: Props): Fusion.Child
	local info = scope:Value(nil :: any)
	local now = scope:Value(Workspace:GetServerTimeNow())
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			local region = Fusion.peek(props.Region)
			if region then
				local ok, _, data = Net.Invoke("DungeonInfo", region)
				if ok and alive then
					info:set(data)
				end
			end
			for _ = 1, 4 do
				if not alive then
					break
				end
				task.wait(0.5)
				now:set(Workspace:GetServerTimeNow())
			end
		end
	end)

	local members = scope:Computed(function(use, s: Scope): { Instance }
		local data = use(info)
		local list = {}
		if not data then
			return list
		end
		for i, member in data.members do
			local reason = ""
			if member.reason then
				reason = Text.get(use, member.reason)
				if member.lockLeft then
					reason ..= ` ({Time.format(member.lockLeft)})`
				end
			end
			table.insert(
				list,
				s:New("TextLabel")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 1,
					Text = `{if member.ok then "✓" else "✗"}  {member.name} · {Text.get(use, "hud.level", {
						level = member.level,
					})}{if reason ~= "" then `  —  {reason}` else ""}`,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Body,
					TextColor3 = if member.ok then Theme.Colors.Success else Theme.Colors.DangerHover,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
			)
		end
		return list
	end)

	return {
		scope:New("TextLabel")({
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local data = use(info)
				return if data then Text.get(use, data.nameKey) else "…"
			end),
			FontFace = Theme.Fonts.Heading,
			TextSize = 30,
			TextColor3 = Theme.Colors.GoldBright,
		}),
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local data = use(info)
				if not data then
					return ""
				end
				return Text.get(use, "dungeon.levels", { level = data.level, required = data.required })
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Colors.Parchment,
		}),
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(0, 74),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local data = use(info)
				if not data then
					return ""
				end
				if not data.built then
					return Text.get(use, "worldmap.soon")
				end
				if data.busy then
					local left = Time.format(Time.remaining(data.endsAt or 0, use(now)))
					return Text.get(use, "dungeon.busyBy", { name = data.leaderName or "?", time = left })
				end
				return Text.get(use, "dungeon.free")
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Body,
			TextColor3 = scope:Computed(function(use): Color3
				local data = use(info)
				return if data and data.busy then Theme.Colors.DangerHover else Theme.Colors.Success
			end),
		}),
		scope:New("Frame")({
			Position = UDim2.fromOffset(0, 116),
			Size = UDim2.new(1, 0, 1, -186),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
				members :: any,
			},
		}),
		Button(scope, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(260, 56),
			Variant = "primary",
			Text = scope:Computed(function(use): string
				local data = use(info)
				return Text.get(use, if data and not data.isLeader then "dungeon.leaderOnly" else "dungeon.enter")
			end),
			Disabled = scope:Computed(function(use): boolean
				local data = use(info)
				return not data or data.busy or not data.isLeader or not data.built
			end),
			OnClick = function()
				local region = Fusion.peek(props.Region)
				if not region then
					return
				end
				task.spawn(function()
					local ok, err = Net.Invoke("EnterDungeon", region)
					if ok then
						Sounds.play("levelUp")
						props.Close()
					else
						Sounds.play("error")
						Toast.push(Text.now(err or "error.internal"), "error")
					end
				end)
			end,
		}),
	}
end

return DungeonWindow
