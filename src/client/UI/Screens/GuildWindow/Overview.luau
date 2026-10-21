--!strict
-- Guild window, "Overview" tab: the banner, name and tag, the guild level with its EXP bar (S159g), leader, members /
-- limit, treasury, founding date, active bonuses (skills and the weekly rally), the message of the day (editable with
-- the right) and the guild log (S159g: joins, ranks, bank, upgrades, goals, levels; newest first). Gold moved to the
-- "Bank" tab in S159g.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Common = require(script.Parent.Common)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Guild = require(ReplicatedStorage.Shared.Logic.Guild)
local GuildBanners = require(ReplicatedStorage.Shared.Data.GuildBanners)
local GuildProgressData = require(ReplicatedStorage.Shared.Data.GuildProgress)
local GuildSkills = require(ReplicatedStorage.Shared.Data.GuildSkills)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

-- One localized line of the guild log (Logic/Guild.LogEntry).
local function logLine(use: Fusion.Use, entry: any): string
	local args: { [string]: any } = { name = entry.n or "?", amount = Format.number(tonumber(entry.a) or 0) }
	if entry.k == "put" or entry.k == "take" then
		local colour = Theme.hex(ItemText.rarityName(entry.r or 1, "paper"))
		local count = if (tonumber(entry.a) or 1) > 1 then ` ×{entry.a}` else ""
		args.item = `<font color="{colour}">{ItemText.get(use, entry.i or "")}</font>{count}`
	elseif entry.k == "upgrade" then
		local def = GuildSkills.get(entry.x or "")
		args.skill = if def then Text.get(use, def.nameKey) else tostring(entry.x)
		args.level = entry.a
	elseif entry.k == "goal" then
		local def = GuildProgressData.goalById[entry.x or ""]
		args.goal = if def then Text.get(use, def.nameKey) else tostring(entry.x)
	elseif entry.k == "rank" then
		args.rank = Text.get(use, `guild.rank.{entry.x}`)
	elseif entry.k == "level" then
		args.level = entry.a
	end
	return `<font color="{Theme.hex(Theme.Paper.TextMuted)}">{Common.stamp(tonumber(entry.t) or 0)}</font>  {Text.get(
		use,
		`guild.log.{entry.k}`,
		args
	)}`
end

local function Overview(scope: Scope, showModal: (spec: any) -> ()): Instance
	local guild = State.Value({ "guild" })

	local function field(name: string): Fusion.Computed<any>
		return scope:Computed(function(use): any
			local g = use(guild)
			return if type(g) == "table" then g[name] else nil
		end)
	end

	-- fields read by several labels, made once (not inside other Computeds)
	local guildLevel = field("level")
	local levelInto = field("levelInto")
	local levelNeed = field("levelNeed")
	local treasury = field("treasury")
	local createdAt = field("createdAt")
	local motd = field("motd")

	local leaderName = scope:Computed(function(use): string
		local g = use(guild)
		if type(g) ~= "table" then
			return ""
		end
		for _, member in g.members do
			if member.key == g.leader then
				return member.name
			end
		end
		return "?"
	end)

	local bonusText = scope:Computed(function(use): string
		local g = use(guild)
		local parts = {}
		if type(g) == "table" then
			for _, def in GuildSkills.list do
				local level = Guild.skillLevel(g.skills, def.id)
				if level > 0 and def.stat ~= "members" then
					table.insert(parts, Text.get(use, def.descKey, { value = Guild.skillEffect(def.id, level) }))
				end
			end
			if g.rally then
				table.insert(
					parts,
					Text.get(use, "guild.rally.short", {
						exp = GuildProgressData.Rules.rallyExp,
						gold = GuildProgressData.Rules.rallyGold,
					})
				)
			end
		end
		return if #parts > 0 then table.concat(parts, "  ·  ") else Text.get(use, "guild.bonuses.none")
	end)

	local canMotd = scope:Computed(function(use): boolean
		local g = use(guild)
		return type(g) == "table" and Guild.can(g.myRank, "motd", g)
	end)

	local emblem = scope:Computed(function(use): string
		local g = use(guild)
		local id = if type(g) == "table" and g.banner then g.banner.e else nil
		return GuildBanners.emblem(id).glyph
	end)
	local colour = scope:Computed(function(use): Color3
		local g = use(guild)
		local id = if type(g) == "table" and g.banner then g.banner.c else nil
		return Theme.tint(GuildBanners.colour(id).hex)
	end)

	local function editMotd()
		local g = State.Get({ "guild" })
		showModal({
			Title = Text.now("guild.motd.edit"),
			Message = Text.now("guild.motd.hint", { max = GuildSkills.Rules.motdMax }),
			ConfirmText = Text.now("common.confirm"),
			CancelText = Text.now("common.cancel"),
			Input = { Placeholder = if g then g.motd else "", MaxLength = GuildSkills.Rules.motdMax },
			OnConfirm = function(text: string)
				return Common.modalInvoke("GuildSetMotd", text)
			end,
		})
	end

	local logRows = scope:Computed(function(use, s: Scope): { Instance }
		local g = use(guild)
		local list = {}
		local entries = if type(g) == "table" and type(g.log) == "table" then g.log else {}
		for i = #entries, 1, -1 do
			table.insert(
				list,
				s:New("TextLabel")({
					LayoutOrder = #entries - i + 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					RichText = true,
					TextWrapped = true,
					Text = logLine(use, entries[i]),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
		end
		if #list == 0 then
			table.insert(list, Common.paragraph(s, 1, Text.get(use, "guild.log.empty")))
		end
		return list
	end)

	return Common.page(scope, 6, {
		-- Banner, name, level and its EXP bar
		scope:New("Frame")({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 76),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("TextLabel")({
					Name = "Banner",
					Size = UDim2.fromOffset(64, 72),
					BackgroundColor3 = colour,
					Text = emblem,
					TextScaled = true,
					FontFace = Theme.Fonts.BodyBold,
					TextColor3 = Theme.Plain,
					TextStrokeTransparency = 0.4,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						scope:New("UIStroke")({ Color = Theme.Brass.Frame, Thickness = 2 }),
						scope:New("UIPadding")({
							PaddingTop = UDim.new(0, 10),
							PaddingBottom = UDim.new(0, 14),
							PaddingLeft = UDim.new(0, 8),
							PaddingRight = UDim.new(0, 8),
						}),
					},
				}),
				scope:New("TextLabel")({
					Position = UDim2.fromOffset(78, 0),
					Size = UDim2.new(1, -78, 0, 38),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						local g = use(guild)
						return if type(g) == "table" then `[{g.tag}]  {g.name}` else ""
					end),
					FontFace = Theme.Fonts.Display,
					TextSize = Theme.TextSize.Title,
					TextColor3 = Theme.Paper.Heading,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				scope:New("TextLabel")({
					Position = UDim2.fromOffset(78, 38),
					Size = UDim2.new(0, 220, 0, 22),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return Text.get(use, "guild.level", { level = use(guildLevel) or 1 })
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Bar(scope, {
					Position = UDim2.fromOffset(300, 42),
					Size = UDim2.new(1, -300, 0, 14),
					Value = scope:Computed(function(use): number
						return use(levelInto) or 0
					end),
					Max = scope:Computed(function(use): number
						return use(levelNeed) or 1
					end),
					Color = Theme.Brass.Frame,
					Surface = "paper",
				}),
				scope:New("TextLabel")({
					Position = UDim2.fromOffset(300, 58),
					Size = UDim2.new(1, -300, 0, 18),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						local need = use(levelNeed)
						if type(need) ~= "number" then
							return Text.get(use, "guild.level.max")
						end
						return Text.get(use, "guild.level.exp", {
							into = Format.number(use(levelInto) or 0),
							need = Format.number(need),
						})
					end),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Caption,
					TextColor3 = Theme.Paper.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			},
		}),
		Common.infoRow(scope, 2, Text.T(scope, "guild.leader"), leaderName),
		Common.infoRow(
			scope,
			3,
			Text.T(scope, "guild.members"),
			scope:Computed(function(use): string
				local g = use(guild)
				return if type(g) == "table" then `{#g.members} / {g.limit}` else ""
			end)
		),
		Common.infoRow(
			scope,
			4,
			Text.T(scope, "guild.treasury"),
			scope:Computed(function(use): string
				return `◉ {Format.number(use(treasury) or 0)}`
			end)
		),
		Common.infoRow(
			scope,
			5,
			Text.T(scope, "guild.founded"),
			scope:Computed(function(use): string
				local at = use(createdAt)
				return if type(at) == "number" then os.date("!%Y-%m-%d", at) :: string else ""
			end)
		),
		Common.paragraph(
			scope,
			6,
			scope:Computed(function(use): string
				return `{Text.get(use, "guild.bonuses")}: {use(bonusText)}`
			end),
			Theme.Paper.Success
		),
		-- Message of the day on parchment.
		scope:New("Frame")({
			LayoutOrder = 7,
			Size = UDim2.new(1, 0, 0, 110),
			BackgroundColor3 = Theme.Paper.Raised,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({ Color = Theme.Paper.Rule }),
				scope:New("TextLabel")({
					Position = UDim2.fromOffset(12, 8),
					Size = UDim2.new(1, -150, 0, 24),
					BackgroundTransparency = 1,
					Text = Text.T(scope, "guild.motd"),
					FontFace = Theme.Fonts.Display,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				scope:New("TextLabel")({
					Position = UDim2.fromOffset(12, 34),
					Size = UDim2.new(1, -24, 1, -42),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						local motd = use(motd)
						return if type(motd) == "string" and motd ~= "" then motd else Text.get(use, "guild.motd.empty")
					end),
					TextWrapped = true,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 6),
					Size = UDim2.fromOffset(130, 36),
					TextSize = Theme.TextSize.Small,
					Text = Text.T(scope, "guild.motd.editButton"),
					Visible = canMotd,
					OnClick = editMotd,
				}),
			},
		}),
		Common.heading(scope, 8, Text.T(scope, "guild.log")),
		scope:New("Frame")({
			LayoutOrder = 9,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = {
				Common.list(scope, 4),
				logRows :: any,
			},
		}),
	})
end

return Overview
