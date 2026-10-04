--!strict
-- Guild window, "Overview" tab: name and tag, leader, members / limit, treasury, founding date, active
-- bonuses, the message of the day (editable with the permission) and depositing gold into the treasury.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Common = require(script.Parent.Common)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Guild = require(ReplicatedStorage.Shared.Logic.Guild)
local GuildSkills = require(ReplicatedStorage.Shared.Data.GuildSkills)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function Overview(scope: Scope, showModal: (spec: any) -> ()): Instance
	local guild = State.Value({ "guild" })
	local gold = State.Value({ "character", "gold" })
	local amount = scope:Value("")

	local function field(name: string): Fusion.Computed<any>
		return scope:Computed(function(use): any
			local g = use(guild)
			return if type(g) == "table" then g[name] else nil
		end)
	end

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
		end
		return if #parts > 0 then table.concat(parts, "  ·  ") else Text.get(use, "guild.bonuses.none")
	end)

	local canMotd = scope:Computed(function(use): boolean
		local g = use(guild)
		return type(g) == "table" and Guild.can(g.myRank, "motd")
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

	local function deposit()
		local n = tonumber(Fusion.peek(amount))
		if not n or n < 1 or n ~= math.floor(n) then
			Sounds.play("error")
			Toast.push(Text.now("guild.error.amount"), "error")
			return
		end
		task.spawn(function()
			if Common.invoke("GuildDeposit", n) then
				Sounds.play("levelUp")
				Toast.push(Text.now("guild.deposited", { amount = Format.number(n) }), "success")
				amount:set("")
			end
		end)
	end

	return scope:New("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			Common.list(scope, 6),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local g = use(guild)
					return if type(g) == "table" then `[{g.tag}]  {g.name}` else ""
				end),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Title,
				TextColor3 = Theme.Colors.GoldBright,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
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
					return `◉ {Format.number(use(field("treasury")) or 0)}`
				end)
			),
			Common.infoRow(
				scope,
				5,
				Text.T(scope, "guild.founded"),
				scope:Computed(function(use): string
					local at = use(field("createdAt"))
					return if type(at) == "number" then os.date("!%Y-%m-%d", at) :: string else ""
				end)
			),
			scope:New("TextLabel")({
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return `{Text.get(use, "guild.bonuses")}: {use(bonusText)}`
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Success,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			-- Message of the day on parchment.
			scope:New("Frame")({
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 120),
				BackgroundColor3 = Theme.Colors.Parchment,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({ Color = Theme.Colors.GoldDim }),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(12, 8),
						Size = UDim2.new(1, -150, 0, 24),
						BackgroundTransparency = 1,
						Text = Text.T(scope, "guild.motd"),
						FontFace = Theme.Fonts.Heading,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Colors.TextDark,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(12, 34),
						Size = UDim2.new(1, -24, 1, -42),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local motd = use(field("motd"))
							return if type(motd) == "string" and motd ~= ""
								then motd
								else Text.get(use, "guild.motd.empty")
						end),
						TextWrapped = true,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Colors.TextDark,
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
			-- Deposit
			scope:New("Frame")({
				LayoutOrder = 8,
				Size = UDim2.new(1, 0, 0, 52),
				BackgroundTransparency = 1,
				[Children] = {
					TextInput(scope, {
						Size = UDim2.new(1, -330, 0, 48),
						Text = amount,
						MaxLength = 10,
						Placeholder = Text.T(scope, "guild.deposit.placeholder"),
						OnSubmit = deposit,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -170, 0, 0),
						Size = UDim2.fromOffset(150, 48),
						Text = scope:Computed(function(use): string
							return `◉ {Format.number(use(gold) or 0)}`
						end),
						TextSize = Theme.TextSize.Small,
						OnClick = function()
							amount:set(tostring(State.Get({ "character", "gold" }) or 0))
						end,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(160, 48),
						Variant = "primary",
						Text = Text.T(scope, "guild.deposit"),
						OnClick = deposit,
					}),
				},
			}),
		},
	})
end

return Overview
