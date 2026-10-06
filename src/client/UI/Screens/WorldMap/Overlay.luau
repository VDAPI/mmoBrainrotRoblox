--!strict
-- Moving layer of the world map (S20, S25), parented into the shown map's canvas: the player arrow, the quest
-- star, the guide target, party members and own marks (buttons, clickable), the pulsing gold ring of the
-- selection and the hover hint. Everything is created once per window; per frame only positions change
-- (`step`). Hit areas keep Canvas.HIT pixels at every zoom and the hint is counter-scaled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Canvas = require(script.Parent.Canvas)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MapMarks = require(ReplicatedStorage.Shared.Data.MapMarks)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local NavTarget = require(script.Parent.Parent.Parent.NavTarget)
local QuestTrack = require(script.Parent.Parent.Parent.QuestTrack)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Parent.Theme)

type Scope = Fusion.Scope<typeof(Fusion)>

local Overlay = {}

local PARTY = 4
local MARKS = 8

local function label(parent: Instance, text: string, color: Color3, size: number, z: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = UDim2.fromOffset(size + 10, size + 6)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.FontFace = Theme.Fonts.BodyBold
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.25
	l.ZIndex = z
	l.Parent = parent
	return l
end

local function marker(parent: Instance, text: string, color: Color3, size: number, z: number): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Size = UDim2.fromOffset(Canvas.HIT, Canvas.HIT)
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.Text = ""
	b.ZIndex = z
	b.Visible = false
	b.Parent = parent
	local glyph = label(b, text, color, size, z + 1)
	glyph.Name = "Glyph"
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	return b
end

export type Selection = { kind: string, id: string, extra: any? }

export type Api = {
	frame: Frame,
	ring: Frame,
	hint: Frame,
	partyMarkers: { TextButton },
	partyIds: { number? },
	markButtons: { TextButton },
	setZoom: (zoom: number) -> (),
	showHint: (title: string, sub: string?, pixel: Vector2, zoom: number) -> (),
	hideHint: () -> (),
	refreshMarks: (cached: Canvas.Cached?, marks: any) -> (),
	step: (cached: Canvas.Cached, me: Vector2?, heading: number?, showQuest: boolean, selection: Selection?) -> (),
}

function Overlay.new(scope: Scope): Api
	local frame = Instance.new("Frame")
	frame.Name = "Dynamic"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 8
	table.insert(scope, frame)

	local player = label(frame, "▲", Theme.Colors.Accent, 20, 12)
	local quest = label(frame, "★", Theme.Colors.GoldBright, 18, 11)
	local nav = label(frame, "◆", Color3.fromHex("#F2E28A"), 16, 11)
	local partyMarkers: { TextButton } = {}
	local partyIds: { number? } = {}
	for i = 1, PARTY do
		partyMarkers[i] = marker(frame, "●", Color3.fromHex("#4A8FE7"), 14, 10)
	end
	local markButtons: { TextButton } = {}
	for i = 1, MARKS do
		markButtons[i] = marker(frame, "⚑", Theme.Colors.GoldBright, 16, 10)
	end

	-- Selection ring: one looping tween, no per-frame work.
	local ring = Instance.new("Frame")
	ring.Name = "Selection"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Size = UDim2.fromOffset(30, 30)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 9
	ring.Visible = false
	ring.Parent = frame
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0.5, 0)
	ringCorner.Parent = ring
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Theme.Colors.GoldBright
	ringStroke.Thickness = 2.5
	ringStroke.Parent = ring
	local pulse = TweenService:Create(
		ringStroke,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.75, Thickness = 1.2 }
	)
	pulse:Play()
	table.insert(scope, pulse)

	-- Hover hint (PC), above the hovered thing.
	local hint = Instance.new("Frame")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.AutomaticSize = Enum.AutomaticSize.XY
	hint.Size = UDim2.fromOffset(0, 0)
	hint.BackgroundColor3 = Theme.Colors.Panel
	hint.BackgroundTransparency = 0.05
	hint.ZIndex = 40
	hint.Visible = false
	hint.Parent = frame
	local hintScale = Instance.new("UIScale")
	hintScale.Parent = hint
	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = Theme.Corner.Small
	hintCorner.Parent = hint
	local hintStroke = Instance.new("UIStroke")
	hintStroke.Color = Theme.Colors.GoldDim
	hintStroke.Parent = hint
	local hintPadding = Instance.new("UIPadding")
	hintPadding.PaddingLeft = UDim.new(0, 8)
	hintPadding.PaddingRight = UDim.new(0, 8)
	hintPadding.PaddingTop = UDim.new(0, 4)
	hintPadding.PaddingBottom = UDim.new(0, 4)
	hintPadding.Parent = hint
	local hintList = Instance.new("UIListLayout")
	hintList.SortOrder = Enum.SortOrder.LayoutOrder
	hintList.Parent = hint
	local function hintLine(order: number, size: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.LayoutOrder = order
		l.AutomaticSize = Enum.AutomaticSize.XY
		l.Size = UDim2.fromOffset(0, 0)
		l.BackgroundTransparency = 1
		l.FontFace = if order == 1 then Theme.Fonts.BodyBold else Theme.Fonts.Body
		l.TextSize = size
		l.TextColor3 = color
		l.ZIndex = 41
		l.Parent = hint
		return l
	end
	local hintTitle = hintLine(1, 15, Theme.Colors.GoldBright)
	local hintSub = hintLine(2, 13, Theme.Colors.Text)

	local api: Api
	api = {
		frame = frame,
		ring = ring,
		hint = hint,
		partyMarkers = partyMarkers,
		partyIds = partyIds,
		markButtons = markButtons,
		setZoom = function(zoom: number)
			local hit = Canvas.HIT / zoom
			for _, button in partyMarkers do
				button.Size = UDim2.fromOffset(hit, hit)
			end
			for _, button in markButtons do
				button.Size = UDim2.fromOffset(hit, hit)
			end
			hintScale.Scale = 1 / zoom
		end,
		showHint = function(title: string, sub: string?, pixel: Vector2, zoom: number)
			hintTitle.Text = title
			hintSub.Text = sub or ""
			hintSub.Visible = sub ~= nil and sub ~= ""
			hint.Position = UDim2.fromOffset(pixel.X, pixel.Y - 14 / zoom)
			hint.Visible = true
		end,
		hideHint = function()
			hint.Visible = false
		end,
		-- Own marks of the shown map (≤ 8 buttons, repositioned when the marks or the map change).
		refreshMarks = function(cached: Canvas.Cached?, marks: any)
			local used = 0
			if cached and type(marks) == "table" then
				for index, mark in marks do
					if mark.map == cached.mapId and used < #markButtons then
						used += 1
						local button = markButtons[used]
						local icon = MapMarks.get(mark.icon)
						local glyph = button:FindFirstChild("Glyph") :: TextLabel
						glyph.Text = if icon then icon.glyph else "⚑"
						glyph.TextColor3 = if icon then Color3.fromHex(icon.color) else Theme.Colors.GoldBright
						local p = Canvas.toPixel(cached, mark.x, mark.z)
						button.Position = UDim2.fromOffset(p.X, p.Y)
						button:SetAttribute("Index", index)
						button.Visible = true
					end
				end
			end
			for i = used + 1, #markButtons do
				markButtons[i].Visible = false
				markButtons[i]:SetAttribute("Index", nil)
			end
		end,
		-- Positions of the moving markers; the ring follows a selected party member or mark.
		step = function(
			cached: Canvas.Cached,
			me: Vector2?,
			heading: number?,
			showQuest: boolean,
			selection: Selection?
		)
			player.Visible = me ~= nil
			if me then
				player.Position = UDim2.fromOffset(me.X, me.Y)
				if heading then
					player.Rotation = heading
				end
			end
			local target = Fusion.peek(QuestTrack.Target)
			local questOn = showQuest
				and target ~= nil
				and target.map == cached.mapId
				and target.x ~= nil
				and target.z ~= nil
				and Fusion.peek(QuestTrack.Tracked) == true
			quest.Visible = questOn
			if questOn and target and target.x and target.z then
				local p = Canvas.toPixel(cached, target.x, target.z)
				quest.Position = UDim2.fromOffset(p.X, p.Y)
			end
			local guide = Fusion.peek(NavTarget.Target)
			nav.Visible = guide ~= nil and guide.map == cached.mapId
			if guide and guide.map == cached.mapId then
				local p = Canvas.toPixel(cached, guide.x, guide.z)
				nav.Position = UDim2.fromOffset(p.X, p.Y - 12)
			end
			local party = State.Get({ "party" })
			local shown = 0
			local map = Maps.get(cached.mapId)
			if type(party) == "table" and map then
				for _, member in party.members do
					if member.id ~= Players.LocalPlayer.UserId and member.map == map.id and shown < PARTY then
						shown += 1
						local p = Canvas.toPixel(cached, member.x - map.offset.x, member.z - map.offset.z)
						partyMarkers[shown].Position = UDim2.fromOffset(p.X, p.Y)
						partyIds[shown] = member.id
						if selection and selection.kind == "party" and selection.id == tostring(member.id) then
							ring.Visible = true
							ring.Position = UDim2.fromOffset(p.X, p.Y)
						end
					end
				end
			end
			for i, dot in partyMarkers do
				dot.Visible = i <= shown
				if i > shown then
					partyIds[i] = nil
				end
			end
			if selection and selection.kind == "mark" then
				for _, button in markButtons do
					if button.Visible and tostring(button:GetAttribute("Index")) == selection.id then
						ring.Visible = true
						ring.Position = button.Position
					end
				end
			end
		end,
	}
	return api
end

return Overlay
