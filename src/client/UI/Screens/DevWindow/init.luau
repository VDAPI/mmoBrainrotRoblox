--!strict
-- Dev panel window (S23, F2 or the "DEV" button, admins only): favourites bar on top, vertical tabs on the
-- left, the tab's content on the right and the last result at the bottom. Every action goes through
-- AdminRun (Dev.run); the server checks the rights and validates the arguments.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminCommands = require(ReplicatedStorage.Shared.Data.AdminCommands)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SideTabs = require(script.Parent.Parent.Components.SideTabs)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Character = require(script.Character)
local Console = require(script.Console)
local Data = require(script.Data)
local Dev = require(script.Dev)
local Economy = require(script.Economy)
local Items = require(script.Items)
local Monsters = require(script.Monsters)
local Perf = require(script.Perf)
local Quests = require(script.Quests)
local World = require(script.World)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

local TABS = {
	"character",
	"items",
	"world",
	"monsters",
	"combat",
	"quests",
	"economy",
	"perf",
	"console",
	"data",
}

local PIN_HEIGHT = 48
local STATUS_HEIGHT = 30
local SIDE_WIDTH = 170

local function combatTab(s: Dev.Scope): Instance
	return Dev.column(s, {
		Dev.header(s, 1, "dev.tab.combat"),
		Dev.commandRows(s, 2, { "combat" }) :: any,
	})
end

export type Props = { Controllers: { [string]: any } }

local function DevWindow(scope: Dev.Scope, props: Props): Fusion.Child
	local tabs = {}
	for _, id in TABS do
		table.insert(tabs, { id = id, label = Text.T(scope, `dev.tab.{id}`) })
	end

	local builders: { [string]: (Dev.Scope) -> Instance } = {
		character = Character,
		items = Items,
		world = World,
		monsters = Monsters,
		combat = combatTab,
		quests = Quests,
		economy = Economy,
		perf = function(s: Dev.Scope): Instance
			return Perf(s, props.Controllers)
		end,
		console = Console,
		data = Data,
	}
	local pages = {}
	for _, id in TABS do
		table.insert(
			pages,
			scope:New("Frame")({
				Name = `Page_{id}`,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(Dev.Tab) == id
				end),
				[Children] = builders[id](scope),
			})
		)
	end

	local pinsValue = State.Value({ "account", "settings", "devPins" })
	local pinButtons = scope:Computed(function(use, s: Dev.Scope): { Instance }
		local pins = use(pinsValue)
		local out = {}
		for i, name in (if type(pins) == "table" then pins else {}) :: { string } do
			local def = AdminCommands.get(name)
			if not def then
				continue
			end
			local needsArgs = false
			for _, arg in def.args do
				if not arg.optional and arg.default == nil then
					needsArgs = true
				end
			end
			table.insert(
				out,
				s:New("TextButton")({
					LayoutOrder = i,
					Size = UDim2.fromOffset(0, PIN_HEIGHT - 8),
					AutomaticSize = Enum.AutomaticSize.X,
					AutoButtonColor = true,
					BackgroundColor3 = Theme.Colors.PanelRaised,
					Text = `★ /{name}`,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.GoldBright,
					[OnEvent("Activated")] = function()
						if needsArgs then
							Dev.prefill(`/{name} `)
						else
							Dev.run(name)
						end
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
					},
				})
			)
		end
		if #out == 0 then
			table.insert(
				out,
				s:New("TextLabel")({
					Size = UDim2.fromOffset(500, PIN_HEIGHT - 8),
					BackgroundTransparency = 1,
					Text = Text.get(use, "dev.pins.empty"),
					FontFace = Theme.Fonts.Body,
					TextSize = 13,
					TextColor3 = Theme.Colors.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
		end
		return out
	end)

	return {
		-- Favourites
		scope:New("ScrollingFrame")({
			Name = "Pins",
			Size = UDim2.new(1, 0, 0, PIN_HEIGHT),
			BackgroundColor3 = Theme.Colors.Panel,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 3,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 6),
				}),
				scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
				pinButtons :: any,
			},
		}),
		SideTabs(scope, {
			Tabs = tabs,
			Selected = Dev.Tab,
			Position = UDim2.fromOffset(0, PIN_HEIGHT + 8),
			Size = UDim2.new(0, SIDE_WIDTH, 1, -(PIN_HEIGHT + 8 + STATUS_HEIGHT + 6)),
		}),
		scope:New("Frame")({
			Name = "Content",
			Position = UDim2.fromOffset(SIDE_WIDTH + 10, PIN_HEIGHT + 8),
			Size = UDim2.new(1, -(SIDE_WIDTH + 10), 1, -(PIN_HEIGHT + 8 + STATUS_HEIGHT + 6)),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			[Children] = pages,
		}),
		-- Status bar: the last result
		scope:New("TextLabel")({
			Name = "Status",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, STATUS_HEIGHT),
			BackgroundColor3 = scope:Computed(function(use): Color3
				local status = use(Dev.Status)
				if status.text == "" then
					return Theme.Colors.Panel
				end
				return if status.ok then Color3.fromHex("#1F3A26") else Color3.fromHex("#4A1E1B")
			end),
			Text = scope:Computed(function(use): string
				local status = use(Dev.Status)
				if use(Dev.Busy) then
					return Text.get(use, "dev.busy")
				end
				return if status.text == "" then Text.get(use, "dev.ready") else status.text
			end),
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Small,
			TextColor3 = scope:Computed(function(use): Color3
				local status = use(Dev.Status)
				return if status.text == "" or status.ok then Theme.Colors.Text else Theme.Colors.DangerHover
			end),
			TextXAlignment = Enum.TextXAlignment.Left,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10) }),
			},
		}),
	}
end

return DevWindow
