--!strict
-- Dungeon gate window (DESIGN §16): boss name and level, required level, state (free / taken by X's group
-- with the time left), every party member with ✓ / ✗ and why (level, daily lockout with the time to reset,
-- too far), the own grind progress (S30: "Dziś: 1/3" and the current personal Legendary / Mythic chances) and
-- "Enter" for the leader. S60: the Legendary chance with the group's Fortune (UI/GroupLuck) and its line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local BossScaling = require(ReplicatedStorage.Shared.Logic.BossScaling)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Button = require(script.Parent.Parent.Components.Button)
local Config = require(ReplicatedStorage.Shared.Config)
local Loot = require(ReplicatedStorage.Shared.Logic.Loot)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local State = require(script.Parent.Parent.State)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GroupLuck = require(script.Parent.Parent.GroupLuck)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.UiArtState)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Region: Fusion.UsedAs<string?>,
	Close: () -> (),
}

-- S134f: the leader and at least one more member may come along now: the gate asks "Ready?" first.
local function asks(data: any): boolean
	if type(data) ~= "table" or not data.isLeader or type(data.members) ~= "table" then
		return false
	end
	local able = 0
	for _, member in data.members do
		if member.ok then
			able += 1
		end
	end
	return able >= 2
end

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

	local bossRuns = State.Value({ "character", "bossRuns" })
	local grind = scope:Computed(function(use): string
		local region = use(props.Region)
		local boss = if region then Bosses.forRegion(region) else nil
		if not boss then
			return ""
		end
		local runs = use(bossRuns)
		local t = use(now)
		local done = BossScaling.runsToday(if type(runs) == "table" then runs else nil, boss.id, t)
		local luck = GroupLuck.use(use)
		local chances = Loot.bossChances(
			boss.id,
			BossScaling.killsToday(if type(runs) == "table" then runs else nil, boss.id, t),
			luck
		)
		local runsLine = Text.get(use, "worldmap.card.runsToday", {
			n = done,
			limit = Config.Boss.dailyRuns,
			time = Time.format(BossScaling.untilReset(t)),
		})
		local chanceLine = Text.get(use, "worldmap.card.bossChances", {
			leg = math.floor(chances.legendary * 100 + 0.5),
			myth = math.floor(chances.mythic * 100 + 0.5),
		})
		local luckLine = GroupLuck.line(use, luck)
		return runsLine .. "\n" .. chanceLine .. (if luckLine then "\n" .. luckLine else "")
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
					TextColor3 = if member.ok then Theme.Paper.Success else Theme.Paper.Danger,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
			)
		end
		return list
	end)

	-- S119: the dungeon banner behind the header lines (name, levels, state), darkened, once loaded; the layout
	-- does not move, without the banner the window is as before.
	local banner = scope:Computed(function(use): string?
		local region = use(props.Region)
		local boss = if region then Bosses.forRegion(region) else nil
		return if boss then UiArt.dungeon(boss.id) else nil
	end)
	scope:Observer(banner):onBind(function()
		UiArtState.ensureKey(Fusion.peek(banner))
	end)
	local bannerShown = ArtIcon.Shown(scope, banner)
	-- The header lines stand on the darkened banner once it is shown: iron text with a dark stroke there, parchment
	-- ink without it.
	local function onBanner(paper: Color3, iron: Color3)
		return scope:Computed(function(use): Color3
			return if use(bannerShown) then iron else paper
		end)
	end
	local headerStroke = scope:Computed(function(use): number
		return if use(bannerShown) then 0.4 else 1
	end)

	return {
		ArtIcon.Image(scope, {
			Name = "Banner",
			Key = banner,
			Size = UDim2.new(1, 0, 0, 106),
			ScaleType = Enum.ScaleType.Crop,
			Corner = Theme.Corner.Small,
		}) :: any,
		scope:New("Frame")({
			Name = "BannerShade",
			Size = UDim2.new(1, 0, 0, 106),
			BackgroundColor3 = Theme.Shade,
			BackgroundTransparency = 0.35,
			Visible = bannerShown,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIGradient")({
					Rotation = 90,
					Transparency = NumberSequence.new(0.6, 0),
				}),
			},
		}),
		scope:New("TextLabel")({
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local data = use(info)
				return if data then Text.get(use, data.nameKey) else "…"
			end),
			FontFace = Theme.Fonts.Display,
			TextSize = Theme.TextSize.Title,
			TextColor3 = onBanner(Theme.Paper.Heading, Theme.Brass.Bright),
			TextStrokeColor3 = Theme.Shade,
			TextStrokeTransparency = headerStroke,
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
			TextColor3 = onBanner(Theme.Paper.Text, Theme.Iron.Text),
			TextStrokeColor3 = Theme.Shade,
			TextStrokeTransparency = headerStroke,
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
				local roles = if use(bannerShown) then Theme.Iron else Theme.Paper
				return if data and data.busy then roles.Danger else roles.Success
			end),
			TextStrokeColor3 = Theme.Shade,
			TextStrokeTransparency = headerStroke,
		}),
		scope:New("TextLabel")({
			Name = "Grind",
			Position = UDim2.fromOffset(0, 108),
			Size = UDim2.new(1, 0, 0, 66),
			BackgroundTransparency = 1,
			Text = grind,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Rarities.get(Rarities.LEGENDARY).textColor,
			TextWrapped = true,
		}),
		scope:New("Frame")({
			Position = UDim2.fromOffset(0, 180),
			Size = UDim2.new(1, 0, 1, -250),
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
				if data and not data.isLeader then
					return Text.get(use, "dungeon.leaderOnly")
				end
				-- S134f: a leader with a member able to come along asks "Ready?" first (DungeonService ready check)
				return Text.get(use, if asks(data) then "dungeon.ready.ask" else "dungeon.enter")
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
					local asking = asks(Fusion.peek(info))
					local ok, err = Net.Invoke("EnterDungeon", region)
					if ok then
						Sounds.play(if asking then "click" else "levelUp")
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
