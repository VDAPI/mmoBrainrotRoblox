--!strict
-- Guild window (G, DESIGN §19, §23): Overview / Members / Goals / Bank / Skills / Settings tabs (Goals and Bank S159g).
-- Without a guild it says where to found one (the Guild Master in the capital) and how to join (an invitation);
-- 2026-10-21: two short lines, the level and the price behind an "i" (Components/InfoLine).
-- Owner 2026-11-10 ("too much text, things covering each other, nothing folds"), UI package C's tabs: the strip's frame
-- is WindowFrame.tabStrip(true) high (the tabs 44 and the scroll bar's room; it was 40 around a taller strip) and the
-- tab's page starts under it and the selected tab's frame, read from the same numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bank = require(script.Bank)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Goals = require(script.Goals)
local GuildSkills = require(ReplicatedStorage.Shared.Data.GuildSkills)
local InfoLine = require(script.Parent.Parent.Components.InfoLine)
local Members = require(script.Members)
local Overview = require(script.Overview)
local Settings = require(script.Settings)
local Skills = require(script.Skills)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local WindowFrame = require(ReplicatedStorage.Shared.Logic.WindowFrame)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

-- the scrolling tab strip's height (Components/Tabs with Scroll)
local STRIP = WindowFrame.tabStrip(true).height

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
		elseif tab == "goals" then
			return Goals(s)
		elseif tab == "bank" then
			return Bank(s)
		elseif tab == "skills" then
			return Skills(s)
		elseif tab == "settings" then
			return Settings(s, props.ShowModal)
		end
		return Overview(s, props.ShowModal)
	end)

	-- guildId without state = still loading the record from the store.
	local loading = scope:Computed(function(use): boolean
		return use(guildId) ~= nil
	end)
	return {
		InfoLine.new(scope, {
			Name = "NoGuild",
			Position = UDim2.fromOffset(0, 100), -- the middle of the old 200 px message
			AnchorPoint = Vector2.new(0, 0.5),
			Center = true,
			Visible = scope:Computed(function(use): boolean
				return not use(hasGuild)
			end),
			Text = scope:Computed(function(use): string
				return Text.get(use, if use(loading) then "guild.loading" else "guild.noneInfo.short")
			end),
			Info = Text.T(scope, "guild.noneInfo", {
				cost = Format.number(GuildSkills.Rules.createCost),
				level = GuildSkills.Rules.createLevel,
			}),
			InfoVisible = scope:Computed(function(use): boolean
				return not use(loading)
			end),
			TextSize = Theme.TextSize.Body,
			Color = Theme.Paper.TextMuted,
		}),
		scope:New("Frame")({
			Name = "TabStrip",
			Size = UDim2.new(1, 0, 0, STRIP),
			BackgroundTransparency = 1,
			Visible = hasGuild,
			[Children] = Tabs(scope, {
				Selected = props.Tab,
				Scroll = true, -- S159g: six tabs (a phone scrolls the strip)
				Tabs = {
					{ id = "overview", label = Text.T(scope, "guild.tab.overview") },
					{ id = "members", label = Text.T(scope, "guild.tab.members") },
					{ id = "goals", label = Text.T(scope, "guild.tab.goals") },
					{ id = "bank", label = Text.T(scope, "guild.tab.bank") },
					{ id = "skills", label = Text.T(scope, "guild.tab.skills") },
					{ id = "settings", label = Text.T(scope, "guild.tab.settings") },
				},
			}),
		}),
		scope:New("Frame")({
			Name = "Content",
			Position = UDim2.fromOffset(0, STRIP + WindowFrame.TAB_EDGE),
			Size = UDim2.new(1, 0, 1, -(STRIP + WindowFrame.TAB_EDGE)),
			BackgroundTransparency = 1,
			[Children] = content :: any,
		}),
	}
end

return GuildWindow
