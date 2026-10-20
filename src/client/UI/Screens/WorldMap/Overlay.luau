--!strict
-- Moving layer of the world map (S20, S25), parented into the shown map's canvas: the player arrow, the quest
-- star, the guide target, party members and own marks (buttons, clickable), the pulsing gold ring of the
-- selection and the hover hint. Everything is created once per window; per frame only positions change
-- (`step`). Hit areas keep Canvas.HIT pixels at every zoom and the hint is counter-scaled. S101: the world event's
-- glyph (a label, not a button) with its time to the start / end under it. S101b: a target with a `place` (the hint
-- of a dialogue answer) shows the place's name under the star.
-- S119: player, quest, guide, party and own marks get the owner's silhouettes (UiArtState.decorate) once loaded.
-- S149b: the world boss over its barrow (Canvas draws the barrow): a brighter crown while it wakes (faded, with the
-- countdown), a pulsing ring and an HP bar while it fights, a cross for the marker's linger after the kill or the
-- leave; between the occurrences only the caption "Next: 14:00" (the player's own clock) under the barrow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Canvas = require(script.Parent.Canvas)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local ClockText = require(script.Parent.Parent.Parent.ClockText)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MapMarks = require(ReplicatedStorage.Shared.Data.MapMarks)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local NavTarget = require(script.Parent.Parent.Parent.NavTarget)
local QuestTrack = require(script.Parent.Parent.Parent.QuestTrack)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.Parent.UiArtState)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)
local WorldBoss = require(ReplicatedStorage.Shared.Logic.WorldBoss)
local WorldEvents = require(ReplicatedStorage.Shared.Logic.WorldEvents)

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

	local player = label(frame, "▲", Theme.Iron.Link, 20, 12)
	local quest = label(frame, "★", Theme.Brass.Bright, 18, 11)
	-- S101b: the name of a hinted place under the star
	local questPlace = label(frame, "", Theme.Iron.Text, 12, 11)
	questPlace.Size = UDim2.fromOffset(160, 16)
	questPlace.Visible = false
	local nav = label(frame, "◆", Theme.tint(UiPalette.map.guide), 16, 11)
	UiArtState.decorate(player, UiArt.mapIcon("player"), { size = 20 })
	UiArtState.decorate(quest, UiArt.mapIcon("quest"), { size = 18 })
	UiArtState.decorate(nav, UiArt.mapIcon("guide"), { size = 16 })
	-- S101: the world event on this map (warning: faded) and its time to the start / end.
	-- S134d: the Invasion zone's circle under the marker (radius from the state, `zone` studs)
	local eventZone = Instance.new("Frame")
	eventZone.Name = "WorldEventZone"
	eventZone.AnchorPoint = Vector2.new(0.5, 0.5)
	eventZone.BackgroundTransparency = 0.8
	eventZone.BorderSizePixel = 0
	eventZone.ZIndex = 10
	eventZone.Visible = false
	eventZone.Parent = frame
	local eventZoneCorner = Instance.new("UICorner")
	eventZoneCorner.CornerRadius = UDim.new(0.5, 0)
	eventZoneCorner.Parent = eventZone
	local eventZoneStroke = Instance.new("UIStroke")
	eventZoneStroke.Thickness = 2
	eventZoneStroke.Parent = eventZone
	local eventMarker = label(frame, "⚔", Theme.Brass.Bright, 20, 11)
	eventMarker.Visible = false
	local eventTime = label(frame, "", Theme.Iron.Text, 12, 11)
	eventTime.Size = UDim2.fromOffset(60, 16)
	eventTime.Visible = false
	local eventClock = 0
	-- S149b: the world boss over its barrow
	local bossColor = Theme.tint(UiPalette.map.worldBoss)
	local bossMarker = label(frame, "♛", bossColor, 24, 12)
	bossMarker.Visible = false
	UiArtState.decorate(bossMarker, UiArt.mapIcon("worldboss"), { size = 24 })
	local bossCross = label(frame, "✕", Theme.Iron.Danger, 22, 13)
	bossCross.Visible = false
	local bossCaption = label(frame, "", Theme.Iron.Text, 12, 11)
	bossCaption.Size = UDim2.fromOffset(140, 16)
	bossCaption.Visible = false
	local bossRing = Instance.new("Frame")
	bossRing.Name = "WorldBossRing"
	bossRing.AnchorPoint = Vector2.new(0.5, 0.5)
	bossRing.Size = UDim2.fromOffset(40, 40)
	bossRing.BackgroundTransparency = 1
	bossRing.ZIndex = 11
	bossRing.Visible = false
	bossRing.Parent = frame
	local bossRingCorner = Instance.new("UICorner")
	bossRingCorner.CornerRadius = UDim.new(0.5, 0)
	bossRingCorner.Parent = bossRing
	local bossRingStroke = Instance.new("UIStroke")
	bossRingStroke.Color = bossColor
	bossRingStroke.Thickness = 2.5
	bossRingStroke.Parent = bossRing
	local bossPulse = TweenService:Create(
		bossRingStroke,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.8, Thickness = 1 }
	)
	bossPulse:Play()
	table.insert(scope, bossPulse)
	local bossBar = Instance.new("Frame")
	bossBar.Name = "WorldBossHp"
	bossBar.AnchorPoint = Vector2.new(0.5, 0.5)
	bossBar.Size = UDim2.fromOffset(40, 5)
	bossBar.BackgroundColor3 = Theme.Resource.Track
	bossBar.BorderSizePixel = 0
	bossBar.ZIndex = 11
	bossBar.Visible = false
	bossBar.Parent = frame
	local bossFill = Instance.new("Frame")
	bossFill.BackgroundColor3 = Theme.Resource.Hp
	bossFill.BorderSizePixel = 0
	bossFill.Size = UDim2.fromScale(1, 1)
	bossFill.ZIndex = 12
	bossFill.Parent = bossBar
	local bossClock = 0
	local partyMarkers: { TextButton } = {}
	local partyIds: { number? } = {}
	for i = 1, PARTY do
		partyMarkers[i] = marker(frame, "●", Theme.tint(UiPalette.map.party), 14, 10)
		UiArtState.decorate(partyMarkers[i]:FindFirstChild("Glyph") :: TextLabel, UiArt.mapIcon("party"), { size = 14 })
	end
	local markButtons: { TextButton } = {}
	for i = 1, MARKS do
		markButtons[i] = marker(frame, "⚑", Theme.Brass.Bright, 16, 10)
		UiArtState.decorate(markButtons[i]:FindFirstChild("Glyph") :: TextLabel, nil, { size = 16 })
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
	ringStroke.Color = Theme.Brass.Bright
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
	hint.BackgroundColor3 = Theme.Iron.Surface
	hint.BackgroundTransparency = 0
	hint.ZIndex = 40
	hint.Visible = false
	hint.Parent = frame
	local hintScale = Instance.new("UIScale")
	hintScale.Parent = hint
	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = Theme.Corner.Small
	hintCorner.Parent = hint
	local hintStroke = Instance.new("UIStroke")
	hintStroke.Color = Theme.Brass.Line
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
	local hintTitle = hintLine(1, Theme.TextSize.Small, Theme.Brass.Bright)
	local hintSub = hintLine(2, Theme.TextSize.Small, Theme.Iron.Text)

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
						glyph.TextColor3 = if icon then Theme.tint(icon.color) else Theme.Brass.Bright
						UiArtState.retarget(glyph, if icon then UiArt.mark(icon.id) else nil, glyph.TextColor3)
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
			questPlace.Visible = questOn and target ~= nil and target.place ~= nil
			if questOn and target and target.x and target.z then
				local p = Canvas.toPixel(cached, target.x, target.z)
				quest.Position = UDim2.fromOffset(p.X, p.Y)
				if target.place then
					questPlace.Position = UDim2.fromOffset(p.X, p.Y + 16)
					questPlace.Text = Text.now(target.place)
				end
			end
			local event = State.Get({ "worldEvent" })
			local eventDef = if type(event) == "table" and event.map == cached.mapId
				then WorldEvents.kindOf(event.kind)
				else nil
			eventMarker.Visible = eventDef ~= nil
			eventTime.Visible = eventDef ~= nil
			local zone = if eventDef and type(event) == "table" then tonumber(event.zone) else nil
			eventZone.Visible = zone ~= nil
			if eventDef and type(event) == "table" then
				local p = Canvas.toPixel(cached, event.x, event.z)
				if zone then
					local edge = Canvas.toPixel(cached, event.x + zone, event.z)
					local size = math.max(8, (edge - p).Magnitude * 2)
					local tint = Theme.tint(eventDef.color)
					eventZone.Position = UDim2.fromOffset(p.X, p.Y)
					eventZone.Size = UDim2.fromOffset(size, size)
					eventZone.BackgroundColor3 = tint
					eventZoneStroke.Color = tint
					eventZoneStroke.Transparency = if event.phase == "warn" then 0.5 else 0.1
				end
				eventMarker.Position = UDim2.fromOffset(p.X, p.Y)
				eventMarker.Text = eventDef.glyph
				eventMarker.TextColor3 = Theme.tint(eventDef.color)
				eventMarker.TextTransparency = if event.phase == "warn" then 0.4 else 0
				eventTime.Position = UDim2.fromOffset(p.X, p.Y + 16)
				local clock = os.clock()
				if clock - eventClock >= 0.5 then
					eventClock = clock
					local t = Workspace:GetServerTimeNow()
					eventTime.Text = Time.format((if event.phase == "warn" then event.startsAt else event.endsAt) - t)
				end
			end
			-- S149b: the world boss's live state over its barrow
			local boss = WorldBoss.markerOf(State.Get({ "worldBoss" }), Clock.now())
			local bossHere = boss.map == cached.mapId
			local live = bossHere and WorldBoss.markerLive(boss)
			bossMarker.Visible = live
			bossCross.Visible = live and (boss.state == "slain" or boss.state == "left")
			bossRing.Visible = live and boss.state == "active"
			bossBar.Visible = live and boss.state == "active"
			bossCaption.Visible = bossHere
			if bossHere then
				local p = Canvas.toPixel(cached, boss.x, boss.z)
				bossMarker.Position = UDim2.fromOffset(p.X, p.Y)
				bossMarker.TextTransparency = if boss.state == "warn"
					then 0.4
					elseif boss.state == "active" then 0
					else 0.5
				bossCross.Position = UDim2.fromOffset(p.X, p.Y)
				bossRing.Position = UDim2.fromOffset(p.X, p.Y)
				bossBar.Position = UDim2.fromOffset(p.X, p.Y + 16)
				bossFill.Size = UDim2.fromScale(math.clamp(boss.hp or 1, 0, 1), 1)
				-- under the barrow's own caption (Canvas, 14 px down)
				bossCaption.Position = UDim2.fromOffset(p.X, p.Y + if boss.state == "active" then 26 else 28)
				local clock = os.clock()
				if clock - bossClock >= 0.5 then
					bossClock = clock
					local t = Clock.now()
					if boss.state == "idle" then
						bossCaption.Text = Text.now("worldboss.map.next", { time = ClockText.hhmm(boss.at or t) })
					elseif boss.state == "warn" then
						bossCaption.Text =
							Text.now("worldboss.map.soon", { time = Time.format(Time.remaining(boss.at or t, t)) })
					elseif boss.state == "active" then
						bossCaption.Text = Time.format(Time.remaining(boss.at or t, t))
					else
						bossCaption.Text =
							Text.now(if boss.state == "slain" then "worldboss.card.slain" else "worldboss.card.left")
					end
				end
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
