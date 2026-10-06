--!strict
-- Dev panel, "Performance" tab (S23): the server's /perf every 2 s while the tab is shown, and the client's FPS,
-- ping, memory, decoration chunks and city detail (S21).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Dev = require(script.Parent.Dev)

local REFRESH = 2

local function Perf(s: Dev.Scope, controllers: { [string]: any }): Instance
	local server = s:Value({} :: { string })
	local client = s:Value({} :: { string })
	local frame = 1 / 60
	table.insert(
		s,
		RunService.Heartbeat:Connect(function(dt: number)
			frame = frame * 0.95 + dt * 0.05
		end)
	)

	local function clientLines(): { string }
		local lines = {
			Text.now("dev.perf.client", {
				fps = math.floor(1 / math.max(frame, 1e-3)),
				ping = math.floor(Players.LocalPlayer:GetNetworkPing() * 1000),
				memory = math.floor(Stats:GetTotalMemoryUsageMb()),
			}),
		}
		local decor = controllers.DecorController
		if decor then
			local chunks, parts = decor.Stats()
			table.insert(lines, Text.now("dev.perf.decor", { chunks = chunks, parts = parts }))
		end
		local town = controllers.TownDetailController
		if town then
			local builds, detail, fine, lastMs = town.Stats()
			table.insert(
				lines,
				Text.now(
					"dev.perf.town",
					{ builds = builds, detail = detail, fine = fine, ms = string.format("%.1f", lastMs) }
				)
			)
		end
		return lines
	end

	local running = true
	table.insert(s, function()
		running = false
	end)
	task.spawn(function()
		while running do
			if Fusion.peek(Dev.Tab) == "perf" then
				client:set(clientLines())
				local ok, _, lines = Net.Invoke("AdminRun", "perf", {})
				if ok and type(lines) == "table" then
					local out = {}
					for _, line in lines do
						table.insert(out, Dev.lineText(line))
					end
					server:set(out)
				end
			end
			task.wait(REFRESH)
		end
	end)

	local function block(order: number, value: Fusion.Value<{ string }>): Instance
		return s:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Background,
			Text = s:Computed(function(use): string
				return table.concat(use(value), "\n")
			end),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = 14,
			TextColor3 = Theme.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			[Fusion.Children] = {
				s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				s:New("UIPadding")({
					PaddingLeft = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				}),
			},
		})
	end

	return Dev.column(s, {
		Dev.header(s, 1, "dev.perf.server"),
		block(2, server),
		Dev.header(s, 3, "dev.perf.clientTitle"),
		block(4, client),
		Dev.header(s, 5, "dev.allCommands"),
		Dev.commandRows(s, 6, { "perf" }) :: any,
	})
end

return Perf
