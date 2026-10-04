--!strict
-- Party member frames (DESIGN §17, left side under the portrait): name, class glyph, level, HP and mana,
-- leader crown, "far" when on another map or beyond 80 studs. Clicking a frame targets the member (heals).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local FAR = 80
local WIDTH = 260
local HEIGHT = 58

local function PartyFrames(scope: Scope, onSelect: (userId: number) -> ()): Instance
	local party = State.Value({ "party" })
	local myMap = State.Value({ "character", "location", "map" })
	local me = Players.LocalPlayer

	local frames = scope:Computed(function(use, s: Scope): { Instance }
		local p = use(party)
		local list = {}
		if type(p) ~= "table" then
			return list
		end
		local myRoot = me.Character and me.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local order = 0
		for _, member in p.members do
			if member.id ~= me.UserId then
				order += 1
				local class = Classes.get(member.class)
				local far = member.map ~= use(myMap)
					or (
						myRoot ~= nil
						and Vector2.new(member.x - myRoot.Position.X, member.z - myRoot.Position.Z).Magnitude > FAR
					)
				local hpRatio = math.clamp(member.hp / math.max(1, member.maxHp), 0, 1)
				local manaRatio = math.clamp(member.mana / math.max(1, member.maxMana), 0, 1)
				table.insert(
					list,
					s:New("TextButton")({
						Name = member.name,
						LayoutOrder = order,
						Size = UDim2.fromOffset(WIDTH, HEIGHT),
						BackgroundColor3 = Theme.Colors.Panel,
						BackgroundTransparency = if far then 0.45 else 0.12,
						AutoButtonColor = true,
						Text = "",
						[OnEvent("Activated")] = function()
							onSelect(member.id)
						end,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							s:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = if member.id == p.leader then Theme.Colors.Gold else Theme.Colors.Border,
								Thickness = 1.5,
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(6, 6),
								Size = UDim2.fromOffset(28, 28),
								BackgroundTransparency = 1,
								Text = if class then class.icon else "?",
								TextScaled = true,
								FontFace = Theme.Fonts.BodyBold,
								TextColor3 = Theme.Colors.GoldBright,
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(40, 4),
								Size = UDim2.new(1, -46, 0, 20),
								BackgroundTransparency = 1,
								Text = `{if member.id == p.leader then "♛ " else ""}{member.name} · {member.level}{if member.dead
									then " ☠"
									elseif far then ` · {Text.get(use, "party.far")}`
									else ""}`,
								FontFace = Theme.Fonts.BodyBold,
								TextSize = 15,
								TextColor3 = if member.dead then Theme.Colors.DangerHover else Theme.Colors.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),
							s:New("Frame")({
								Position = UDim2.fromOffset(40, 28),
								Size = UDim2.new(1, -48, 0, 12),
								BackgroundColor3 = Theme.Colors.Background,
								[Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
									s:New("Frame")({
										Size = UDim2.fromScale(hpRatio, 1),
										BackgroundColor3 = Theme.Colors.Hp,
										[Children] = s:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
									}),
								},
							}),
							s:New("Frame")({
								Position = UDim2.fromOffset(40, 43),
								Size = UDim2.new(1, -48, 0, 8),
								BackgroundColor3 = Theme.Colors.Background,
								[Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
									s:New("Frame")({
										Size = UDim2.fromScale(manaRatio, 1),
										BackgroundColor3 = Theme.Colors.Mana,
										[Children] = s:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
									}),
								},
							}),
						},
					})
				)
			end
		end
		return list
	end)

	return scope:New("Frame")({
		Name = "PartyFrames",
		Position = UDim2.fromOffset(Theme.Padding.Large, Theme.Padding.Large + 136 + 70),
		Size = UDim2.fromOffset(WIDTH, 4 * (HEIGHT + 6)),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			frames :: any,
		},
	})
end

return PartyFrames
