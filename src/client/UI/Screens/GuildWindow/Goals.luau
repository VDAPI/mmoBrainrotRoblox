--!strict
-- Guild window, "Goals" tab (S159g, Logic/GuildProgress): the three goals of the week with progress, rewards and
-- "Take" (Dragon Shards for members who earned enough guild EXP this week), the rally of all three, the player's own
-- guild EXP (this week, today against the daily cap) and how guild EXP is earned.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Common = require(script.Parent.Common)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GuildProgress = require(ReplicatedStorage.Shared.Logic.GuildProgress)
local GuildProgressData = require(ReplicatedStorage.Shared.Data.GuildProgress)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Rules = GuildProgressData.Rules

-- The order activities are explained in ("How to earn guild EXP").
local SOURCES = {
	"kill",
	"elite",
	"elite2",
	"boss",
	"worldBoss",
	"quest",
	"contract",
	"event",
	"gather",
	"fish",
	"craft",
	"brew",
	"upgrade",
}

local function goalCard(scope: Scope, index: number, guild: Fusion.Value<any>, work: Fusion.Value<any>): Instance
	local goal = scope:Computed(function(use): any
		local g = use(guild)
		local week = if type(g) == "table" then g.week else nil
		return if type(week) == "table" then week.goals[index] else nil
	end)
	local def = scope:Computed(function(use): any
		local current = use(goal)
		return if current then GuildProgressData.goalById[current.id] else nil
	end)
	-- "claim" | "claimed" | "short" (not enough guild EXP this week) | "open"
	local status = scope:Computed(function(use): string
		local g, current = use(guild), use(goal)
		if type(g) ~= "table" or not current or not current.done then
			return "open"
		end
		local w = use(work)
		if type(w) == "table" and w.week == g.week.w and type(w.claimed) == "table" and w.claimed[current.id] then
			return "claimed"
		end
		return if (g.week.mine or 0) >= Rules.claimMin then "claim" else "short"
	end)
	return scope:New("Frame")({
		LayoutOrder = 10 + index,
		Size = UDim2.new(1, 0, 0, 112),
		BackgroundColor3 = Theme.Paper.Raised,
		BackgroundTransparency = 0.2,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				Color = scope:Computed(function(use): Color3
					local current = use(goal)
					return if current and current.done then Theme.Paper.Success else Theme.Paper.Rule
				end),
				Transparency = 0.3,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.new(1, -200, 0, 26),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local d = use(def)
					local current = use(goal)
					if not d or not current then
						return ""
					end
					local mark = if current.done then "✔ " else ""
					return mark .. Text.get(use, d.nameKey)
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(12, 34),
				Size = UDim2.new(1, -200, 0, 22),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local d = use(def)
					local current = use(goal)
					return if d and current then Text.get(use, d.descKey, { n = Format.number(current.target) }) else ""
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Bar(scope, {
				Position = UDim2.fromOffset(12, 62),
				Size = UDim2.new(1, -212, 0, 14),
				Value = scope:Computed(function(use): number
					local current = use(goal)
					return if current then current.n else 0
				end),
				Max = scope:Computed(function(use): number
					local current = use(goal)
					return if current then math.max(1, current.target) else 1
				end),
				Color = Theme.Brass.Frame,
				Surface = "paper",
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(12, 80),
				Size = UDim2.new(1, -212, 0, 24),
				BackgroundTransparency = 1,
				RichText = true,
				Text = scope:Computed(function(use): string
					local current = use(goal)
					local d = use(def)
					local g = use(guild)
					if not current or not d or type(g) ~= "table" then
						return ""
					end
					return Text.get(use, "guild.goal.progress", {
						n = Format.number(current.n),
						target = Format.number(current.target),
						exp = Format.number(d.exp),
						gold = Format.number(GuildProgress.goalGold(g.level or 1)),
						shards = Rules.claimShards,
					})
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Label,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(176, 48),
				Variant = scope:Computed(function(use): any
					return if use(status) == "claim" then "primary" else "secondary"
				end),
				TextSize = Theme.TextSize.Small,
				Disabled = scope:Computed(function(use): boolean
					return use(status) ~= "claim"
				end),
				Text = scope:Computed(function(use): string
					local s = use(status)
					if s == "claimed" then
						return Text.get(use, "guild.goal.claimed")
					elseif s == "short" then
						return Text.get(use, "guild.goal.short", { n = Rules.claimMin })
					elseif s == "claim" then
						return Text.get(use, "guild.goal.claim", { shards = Rules.claimShards })
					end
					return Text.get(use, "guild.goal.open")
				end),
				OnClick = function()
					task.spawn(function()
						if Common.invoke("GuildClaimGoal", index) then
							Sounds.play("levelUp")
							Toast.push(Text.now("guild.goal.claimedToast", { shards = Rules.claimShards }), "success")
						end
					end)
				end,
			}),
		},
	})
end

local function Goals(scope: Scope): Instance
	local guild = State.Value({ "guild" })
	local work = State.Value({ "character", "guildWork" })

	return Common.page(scope, 8, {
		Common.heading(scope, 1, Text.T(scope, "guild.goals.title")),
		Common.paragraph(
			scope,
			2,
			scope:Computed(function(use): string
				local g = use(guild)
				local week = if type(g) == "table" and g.week then g.week.w else Time.weekNumber(os.time())
				local d, h, m = Time.split(Time.weekStart(week + 1) - os.time())
				return Text.get(use, "guild.goals.intro", { d = d, h = h, m = m, min = Rules.claimMin })
			end)
		),
		Common.paragraph(
			scope,
			3,
			scope:Computed(function(use): string
				local g = use(guild)
				local w = use(work)
				local day = Time.dayNumber(os.time())
				local todayExp = if type(w) == "table" and w.day == day then w.today or 0 else 0
				return Text.get(use, "guild.goals.mine", {
					week = Format.number(if type(g) == "table" and g.week then g.week.mine or 0 else 0),
					today = Format.number(todayExp),
					cap = Format.number(Rules.dailyCap),
				})
			end),
			Theme.Paper.Text
		),
		goalCard(scope, 1, guild, work),
		goalCard(scope, 2, guild, work),
		goalCard(scope, 3, guild, work),
		-- The rally of all three goals
		scope:New("Frame")({
			LayoutOrder = 20,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = scope:Computed(function(use): Color3
				local g = use(guild)
				return if type(g) == "table" and g.rally then Theme.Paper.Selected else Theme.Paper.Sunken
			end),
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),
				Common.paragraph(
					scope,
					1,
					scope:Computed(function(use): string
						local g = use(guild)
						if type(g) == "table" and g.rally then
							local d, h = Time.split(Time.weekStart(g.rally + 1) - os.time())
							return Text.get(use, "guild.rally.active", {
								exp = Rules.rallyExp,
								gold = Rules.rallyGold,
								d = d,
								h = h,
							})
						end
						return Text.get(use, "guild.rally.hint", { exp = Rules.rallyExp, gold = Rules.rallyGold })
					end),
					Theme.Paper.Text
				),
			},
		}),
		Common.heading(scope, 30, Text.T(scope, "guild.source.title")),
		Common.paragraph(scope, 31, Text.T(scope, "guild.source.intro", { gap = Rules.greyGap, cap = Rules.dailyCap })),
		Common.paragraph(
			scope,
			32,
			scope:Computed(function(use): string
				local parts = {}
				for _, act in SOURCES do
					table.insert(parts, `{Text.get(use, `guild.source.{act}`)} +{GuildProgressData.POINTS[act]}`)
				end
				return table.concat(parts, "  ·  ")
			end),
			Theme.Paper.Text
		),
	})
end

return Goals
