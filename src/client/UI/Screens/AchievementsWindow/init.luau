--!strict
-- Achievements window (N, the game menu and the HUD menu; S151b, docs/DESIGN.md §20b). On top the summary (points,
-- earned, the range switch All / Account / This character and the filter All / In progress / Earned); under it the
-- categories (PC a column with icons, phone a scrolling tab strip), the list of the category (a series folded to its
-- current step, the tracking star) and the details of the selection (PC a panel on the right, phone a sheet over the
-- window). Everything comes from Logic/AchievementView over the replicated save (Context: read at most every
-- Config.Achievements.listRefresh seconds); the server decides tracking (AchievementTrack).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Context)
local Details = require(script.Details)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local List = require(script.List)
local Summary = require(script.Summary)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = Context.Props

local GAP = 8

local function desktop(scope: Scope, ctx: Context.Ctx): Instance
	local top = Summary.HEIGHT + GAP
	return scope:New("Frame")({
		Name = "Desktop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			Summary.new(scope, ctx, false),
			scope:New("Frame")({
				Name = "Body",
				Position = UDim2.fromOffset(0, top),
				Size = UDim2.new(1, 0, 1, -top),
				BackgroundTransparency = 1,
				[Children] = {
					List.categories(scope, ctx),
					scope:New("Frame")({
						Name = "Middle",
						Position = UDim2.fromOffset(List.CATEGORY_WIDTH + GAP, 0),
						Size = UDim2.new(1, -(List.CATEGORY_WIDTH + Details.WIDTH + GAP * 2), 1, 0),
						BackgroundTransparency = 1,
						[Children] = List.rows(scope, ctx, false),
					}),
					Details.panel(scope, ctx),
				},
			}),
		},
	})
end

local function touchLayout(scope: Scope, ctx: Context.Ctx): Instance
	local tabsTop = Summary.HEIGHT_TOUCH + GAP
	local listTop = tabsTop + 50 + GAP
	return scope:New("Frame")({
		Name = "Touch",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			Summary.new(scope, ctx, true),
			scope:New("Frame")({
				Name = "Categories",
				Position = UDim2.fromOffset(0, tabsTop),
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundTransparency = 1,
				[Children] = List.categoryTabs(scope, ctx),
			}),
			scope:New("Frame")({
				Name = "Middle",
				Position = UDim2.fromOffset(0, listTop),
				Size = UDim2.new(1, 0, 1, -listTop),
				BackgroundTransparency = 1,
				[Children] = List.rows(scope, ctx, true),
			}),
			Details.sheet(scope, ctx),
		},
	})
end

local function AchievementsWindow(scope: Scope, props: Props): Fusion.Child
	local ctx = Context.new(scope, props)
	-- the layout follows the input device (touch = full-screen window, the skills window pattern)
	local layout = scope:Computed(function(use, s: Scope): Instance
		if use(Device.Touch) then
			return touchLayout(s, ctx)
		end
		return desktop(s, ctx)
	end)
	return layout :: any
end

return AchievementsWindow
