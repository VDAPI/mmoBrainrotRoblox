--!strict
-- Guild window (G, DESIGN §19, §23): Overview / Members / Skills / Settings tabs. Without a guild it says
-- where to found one (the Guild Master in the capital) and how to join (an invitation from a member).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GuildSkills = require(ReplicatedStorage.Shared.Data.GuildSkills)
local Members = require(script.Members)
local Overview = require(script.Overview)
local Settings = require(script.Settings)
local Skills = require(script.Skills)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	ShowModal: (spec: any) -> (),
	Tab: Fusion.Value<string>,
}

local function GuildWindow(scope: Scope, props: Props): Fusion.Child
	local guildId = State.Value({ "character", "guildId" })
	local hasGuild = scope:Computed(function(use): boolean
		return use(State.Value({ "guild" })) ~= nil
	end)

	local content = scope:Computed(function(use, s: Scope): Instance?
		if not use(hasGuild) then
			return nil
		end
		local tab = use(props.Tab)
		if tab == "members" then
			return Members(s, props.ShowModal)
		elseif tab == "skills" then
			return Skills(s)
		elseif tab == "settings" then
			return Settings(s, props.ShowModal)
		end
		return Overview(s, props.ShowModal)
	end)

	return {
		scope:New("TextLabel")({
			Name = "NoGuild",
			Size = UDim2.new(1, 0, 0, 200),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return not use(hasGuild)
			end),
			Text = scope:Computed(function(use): string
				-- guildId without state = still loading the record from the store.
				if use(guildId) ~= nil then
					return Text.get(use, "guild.loading")
				end
				return Text.get(use, "guild.noneInfo", {
					cost = Format.number(GuildSkills.Rules.createCost),
					level = GuildSkills.Rules.createLevel,
				})
			end),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Colors.TextMuted,
		}),
		scope:New("Frame")({
			Name = "TabStrip",
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeightSmall),
			BackgroundTransparency = 1,
			Visible = hasGuild,
			[Children] = Tabs(scope, {
				Selected = props.Tab,
				Tabs = {
					{ id = "overview", label = Text.T(scope, "guild.tab.overview") },
					{ id = "members", label = Text.T(scope, "guild.tab.members") },
					{ id = "skills", label = Text.T(scope, "guild.tab.skills") },
					{ id = "settings", label = Text.T(scope, "guild.tab.settings") },
				},
			}),
		}),
		scope:New("Frame")({
			Name = "Content",
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 1, -52),
			BackgroundTransparency = 1,
			[Children] = content :: any,
		}),
	}
end

return GuildWindow
