--!strict
-- Guild window, "Skills" tab: the treasury and five cards (DESIGN §19) with level x/5, the current and next
-- effect, the treasury cost and "Upgrade" (officers and the leader).

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
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function card(scope: Scope, def: GuildSkills.SkillDef, order: number, guild: Fusion.Value<any>): Instance
	local level = scope:Computed(function(use): number
		local g = use(guild)
		return if type(g) == "table" then Guild.skillLevel(g.skills, def.id) else 0
	end)
	local cost = scope:Computed(function(use): number?
		return Guild.upgradeCost(def.id, use(level))
	end)
	local canUpgrade = scope:Computed(function(use): boolean
		local g = use(guild)
		local c = use(cost)
		return type(g) == "table" and c ~= nil and Guild.can(g.myRank, "upgrade") and g.treasury >= c
	end)
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.2,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Transparency = 0.4 }),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.fromOffset(64, 64),
				BackgroundColor3 = Theme.Colors.Panel,
				Text = def.icon,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = Theme.Colors.GoldBright,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 8),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
				},
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(86, 8),
				Size = UDim2.new(1, -280, 0, 26),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return `{Text.get(use, def.nameKey)}  ·  {use(level)}/{GuildSkills.MAX_LEVEL}`
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(86, 36),
				Size = UDim2.new(1, -280, 0, 40),
				BackgroundTransparency = 1,
				RichText = true,
				TextWrapped = true,
				Text = scope:Computed(function(use): string
					local lvl = use(level)
					local now = Text.get(use, "guild.skill.now", {
						effect = Text.get(use, def.descKey, { value = Guild.skillEffect(def.id, lvl) }),
					})
					if lvl >= GuildSkills.MAX_LEVEL then
						return now
					end
					local next = Text.get(use, "guild.skill.next", {
						effect = Text.get(use, def.descKey, { value = Guild.skillEffect(def.id, lvl + 1) }),
					})
					return `{now}\n<font color="#{Theme.Colors.Success:ToHex()}">{next}</font>`
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			scope:New("TextLabel")({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 6),
				Size = UDim2.fromOffset(180, 24),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local c = use(cost)
					return if c then `◉ {Format.number(c)}` else Text.get(use, "guild.skill.max")
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.GoldBright,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -10, 1, -8),
				Size = UDim2.fromOffset(150, 42),
				Variant = "primary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "guild.skill.upgrade"),
				Disabled = scope:Computed(function(use): boolean
					return not use(canUpgrade)
				end),
				Visible = scope:Computed(function(use): boolean
					return use(cost) ~= nil
				end),
				OnClick = function()
					task.spawn(function()
						if Common.invoke("GuildUpgrade", def.id) then
							Sounds.play("levelUp")
						end
					end)
				end,
			}),
		},
	})
end

local function Skills(scope: Scope): Instance
	local guild = State.Value({ "guild" })
	local cards = {}
	for i, def in GuildSkills.list do
		table.insert(cards, card(scope, def, i + 1, guild))
	end
	return scope:New("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		[Children] = {
			Common.list(scope, 8),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local g = use(guild)
					local treasury = if type(g) == "table" then g.treasury else 0
					local key = if type(g) == "table" and Guild.can(g.myRank, "upgrade")
						then "guild.skill.treasury"
						else "guild.skill.treasuryNoRight"
					return Text.get(use, key, { gold = Format.number(treasury) })
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Gold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			cards :: any,
		},
	})
end

return Skills
