--!strict
-- Ready check overlay (S134f, DESIGN §16): while the state branch `readyCheck` exists (DungeonService): the boss,
-- every asked member with ✓ / ✗ / …, "Ready" / "Not now" (44 px and more, phones) and a bar of the time left. Once
-- everyone said yes the buttons go and the big 3-2-1 comes from BossAnnounce. Mounted once by DungeonController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function answer(yes: boolean)
	Sounds.play("click")
	task.spawn(function()
		local ok, err = Net.Invoke("DungeonReady", yes)
		if not ok then
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

local function ReadyCheck(scope: Scope): Instance
	local check = State.Value({ "readyCheck" })
	local myId = game:GetService("Players").LocalPlayer.UserId
	local now = scope:Value(Workspace:GetServerTimeNow())
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			if Fusion.peek(check) ~= nil then
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)
	local going = scope:Computed(function(use): boolean
		local c = use(check)
		return type(c) == "table" and c.goAt ~= nil
	end)
	local mine = scope:Computed(function(use): boolean?
		local c = use(check)
		if type(c) ~= "table" or type(c.members) ~= "table" then
			return nil
		end
		for _, member in c.members do
			if member.id == myId then
				return member.answer
			end
		end
		return nil
	end)

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local c = use(check)
		local out: { Instance } = {}
		if type(c) ~= "table" or type(c.members) ~= "table" then
			return out
		end
		for i, member in c.members do
			local mark = if member.answer == true then "✓" elseif member.answer == false then "✗" else "…"
			local color = if member.answer == true
				then Theme.Paper.Success
				elseif member.answer == false then Theme.Paper.Danger
				else Theme.Paper.TextMuted
			table.insert(
				out,
				s:New("TextLabel")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					Text = `{mark}  {member.name}`,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Body,
					TextColor3 = color,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
		end
		return out
	end)

	return scope:New("Frame")({
		Name = "ReadyCheck",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Paper.Surface,
		BackgroundTransparency = 0,
		Active = true,
		Visible = scope:Computed(function(use): boolean
			return type(use(check)) == "table"
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thick,
				Color = Theme.Paper.Border,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Padding.Medium),
				PaddingBottom = UDim.new(0, Theme.Padding.Medium),
				PaddingLeft = UDim.new(0, Theme.Padding.Large),
				PaddingRight = UDim.new(0, Theme.Padding.Large),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local c = use(check)
					local boss = if type(c) == "table" and type(c.bossKey) == "string"
						then Text.get(use, c.bossKey)
						else ""
					return Text.get(use, "dungeon.ready.title", { boss = boss })
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Paper.Heading,
			}),
			scope:New("Frame")({
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
					rows :: any,
				},
			}),
			-- time left
			scope:New("Frame")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 8),
				BackgroundColor3 = Theme.Paper.Sunken,
				Visible = scope:Computed(function(use): boolean
					return not use(going)
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
					scope:New("Frame")({
						Size = scope:Computed(function(use): UDim2
							local c = use(check)
							if type(c) ~= "table" or type(c.endsAt) ~= "number" then
								return UDim2.fromScale(0, 1)
							end
							local total = Config.Boss.readyTimeout
							local left = math.clamp(c.endsAt - use(now), 0, total)
							return UDim2.fromScale(left / total, 1)
						end),
						BackgroundColor3 = Theme.Brass.Frame,
						[Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }) },
					}),
				},
			}),
			scope:New("TextLabel")({
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(going) or use(mine) ~= nil
				end),
				Text = scope:Computed(function(use): string
					return Text.get(use, if use(going) then "dungeon.ready.go" else "dungeon.ready.waiting")
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
			}),
			scope:New("Frame")({
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(going) and use(mine) == nil
				end),
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 10),
					}),
					Button(scope, {
						LayoutOrder = 1,
						Size = UDim2.fromOffset(150, 48),
						Variant = "primary",
						Text = Text.T(scope, "dungeon.ready.yes"),
						OnClick = function()
							answer(true)
						end,
					}),
					Button(scope, {
						LayoutOrder = 2,
						Size = UDim2.fromOffset(150, 48),
						Variant = "secondary",
						Text = Text.T(scope, "dungeon.ready.no"),
						OnClick = function()
							answer(false)
						end,
					}),
				},
			}),
		},
	})
end

return ReadyCheck
