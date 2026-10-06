--!strict
-- Dev panel, "Console" tab (S23): a command line with hints (names and usage from Data/AdminCommands), history
-- on ↑ / ↓ (the last 30, this session) and the log of results (100 lines). Commands go through AdminRun like the
-- buttons do.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AdminArgs = require(ReplicatedStorage.Shared.Logic.AdminArgs)
local AdminCommands = require(ReplicatedStorage.Shared.Data.AdminCommands)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Dev = require(script.Parent.Dev)

local Children, OnEvent, Out = Fusion.Children, Fusion.OnEvent, Fusion.Out

local function Console(s: Dev.Scope): Instance
	local line = Dev.ConsoleLine
	local historyIndex = 0
	local box: TextBox? = nil

	local hints = s:Computed(function(use): string
		local text = use(line)
		use(Text.Lang)
		local name = AdminArgs.parseLine(text)
		if not name or name == "" then
			return Text.get(use, "dev.console.hint")
		end
		local out = {}
		for _, def in AdminCommands.sorted() do
			if string.sub(def.name, 1, #name) == name then
				table.insert(out, Text.now(def.usageKey))
				if #out >= 6 then
					break
				end
			end
		end
		return if #out > 0 then table.concat(out, "\n") else Text.get(use, "admin.unknown")
	end)

	local function submit()
		local text = Fusion.peek(line)
		local name, args = AdminArgs.parseLine(text)
		if not name then
			return
		end
		historyIndex = 0
		line:set("")
		Dev.run(name, args)
	end

	table.insert(
		s,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if not box or not box:IsFocused() then
				return
			end
			local history = Dev.History
			if input.KeyCode == Enum.KeyCode.Up and #history > 0 then
				historyIndex = math.min(#history, historyIndex + 1)
				line:set(history[#history - historyIndex + 1])
			elseif input.KeyCode == Enum.KeyCode.Down then
				historyIndex = math.max(0, historyIndex - 1)
				line:set(if historyIndex == 0 then "" else history[#history - historyIndex + 1])
			end
		end)
	)

	local logRows = s:Computed(function(use, inner: Dev.Scope): { Instance }
		local out = {}
		for i, entry in use(Dev.Log) do
			table.insert(
				out,
				inner:New("TextLabel")({
					LayoutOrder = i,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = entry.text,
					TextWrapped = true,
					FontFace = if entry.ok == nil then Theme.Fonts.BodyBold else Theme.Fonts.Body,
					TextSize = 14,
					TextColor3 = if entry.ok == nil
						then Theme.Colors.GoldBright
						elseif entry.ok then Theme.Colors.Text
						else Theme.Colors.DangerHover,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
		end
		return out
	end)

	local input = s:New("TextBox")({
		LayoutOrder = 1,
		Size = UDim2.new(1, -110, 0, Theme.Size.MinTouch),
		BackgroundColor3 = Theme.Colors.Background,
		ClearTextOnFocus = false,
		PlaceholderText = "/lvl 50",
		Text = line,
		[Out("Text")] = line,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		[OnEvent("FocusLost")] = function(enter: boolean)
			if enter then
				submit()
			end
		end,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
		},
	}) :: TextBox
	box = input

	return s:New("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			s:New("Frame")({
				Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					input,
					Dev.button(s, Text.T(s, "dev.console.run"), submit, 100),
				},
			}),
			s:New("TextLabel")({
				Position = UDim2.fromOffset(0, Theme.Size.MinTouch + 6),
				Size = UDim2.new(1, 0, 0, 96),
				BackgroundColor3 = Theme.Colors.Panel,
				Text = hints,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = Theme.Fonts.Body,
				TextSize = 13,
				TextColor3 = Theme.Colors.TextMuted,
				[Children] = {
					s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					s:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 4) }),
				},
			}),
			s:New("ScrollingFrame")({
				Position = UDim2.fromOffset(0, Theme.Size.MinTouch + 108),
				Size = UDim2.new(1, 0, 1, -(Theme.Size.MinTouch + 108)),
				BackgroundColor3 = Theme.Colors.Background,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 6,
				[Children] = {
					s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
					s:New("UIPadding")({ PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
					logRows :: any,
				},
			}),
		},
	})
end

return Console
