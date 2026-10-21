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
-- S159w: the wandering merchant's caravan (⚖) on its spot with the time he stays, faded with "in 4:12" before he comes.
-- Owner 2026-10-20 "Mapa": every marker keeps one screen size at every zoom (a UIScale of 1 / zoom, offsets under a
-- marker divided by the zoom); party members, own marks, the quest target and the world event sit on the same dark
-- ringed plates as the Canvas symbols, and their filter chips (Logic/MapMarkers "party", "mark", "objective",
-- "event") hide them. The hint is bigger (body text).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Canvas = require(script.Parent.Canvas)
local MapMarkers = require(ReplicatedStorage.Shared.Logic.MapMarkers)
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
local WanderingMerchant = require(ReplicatedStorage.Shared.Logic.WanderingMerchant)
local WorldBoss = require(ReplicatedStorage.Shared.Logic.WorldBoss)
local WorldEvents = require(ReplicatedStorage.Shared.Logic.WorldEvents)

type Scope = Fusion.Scope<typeof(Fusion)>

local Overlay = {}

local PARTY = 4
local MARKS = 8
local MARKER_PLATE = 30 -- party, own marks, quest target, world event
local MARKER_ART = 18

-- UIScales of every marker of the open window (1 / zoom keeps them one size on screen).
type Scales = { UIScale }

local function counter(scales: Scales, object: GuiObject)
	local scale = Instance.new("UIScale")
	scale.Parent = object
	table.insert(scales, scale)
end

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

-- A clickable marker (party member, own mark): a transparent hit button with a ringed plate and the glyph.
local function marker(
	scales: Scales,
	parent: Instance,
	text: string,
	color: Color3,
	size: number,
	z: number,
	category: string
): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Size = UDim2.fromOffset(Canvas.HIT, Canvas.HIT)
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.Text = ""
	b.ZIndex = z
	b.Visible = false
	b.Parent = parent
	counter(scales, b)
	local def = MapMarkers.byId[category]
	Canvas.plate(b, if def then def.shape else "round", MARKER_PLATE, color, z + 1)
	local glyph = label(b, text, color, size, z + 2)
	glyph.Name = "Glyph"
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	return b
end

-- A marker that is not a button (quest target, world event): a frame holding a ringed plate and the glyph.
local function plated(
	scales: Scales,
	parent: Instance,
	text: string,
	color: Color3,
	size: number,
	z: number
): (Frame, TextLabel, UIStroke)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(MARKER_PLATE, MARKER_PLATE)
	f.BackgroundTransparency = 1
	f.ZIndex = z
	f.Visible = false
	f.Parent = parent
	counter(scales, f)
	local _, stroke = Canvas.plate(f, "round", MARKER_PLATE, color, z)
	local glyph = label(f, text, color, size, z + 1)
	glyph.Name = "Glyph"
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	return f, glyph, stroke
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
	refreshMarks: (cached: Canvas.Cached?, marks: any, hidden: { [string]: boolean }) -> (),
	step: (
		cached: Canvas.Cached,
		me: Vector2?,
		heading: number?,
		hidden: { [string]: boolean },
		selection: Selection?
	) -> (),
}

function Overlay.new(scope: Scope): Api
	local frame = Instance.new("Frame")
	frame.Name = "Dynamic"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 8
	table.insert(scope, frame)
	local scales: Scales = {}
	local zoomNow = 1

	local player = label(frame, "▲", Theme.Iron.Link, Theme.TextSize.Large, 12)
	counter(scales, player)
	local quest, questGlyph = plated(scales, frame, "★", Theme.Brass.Bright, Theme.TextSize.Body, 11)
	-- S101b: the name of a hinted place under the star
	local questPlace = label(frame, "", Theme.Iron.Text, Theme.TextSize.Caption, 11)
	questPlace.Size = UDim2.fromOffset(180, 18)
	questPlace.Visible = false
	counter(scales, questPlace)
	local nav = label(frame, "◆", Theme.tint(UiPalette.map.guide), Theme.TextSize.Body, 11)
	counter(scales, nav)
	UiArtState.decorate(player, UiArt.mapIcon("player"), { size = 26 })
	UiArtState.decorate(questGlyph, UiArt.mapIcon("quest"), { size = MARKER_ART })
	UiArtState.decorate(nav, UiArt.mapIcon("guide"), { size = 20 })
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
	local eventMarker, eventGlyph, eventStroke =
		plated(scales, frame, "⚔", Theme.Brass.Bright, Theme.TextSize.Body, 11)
	local eventTime = label(frame, "", Theme.Iron.Text, Theme.TextSize.Caption, 11)
	eventTime.Size = UDim2.fromOffset(70, 18)
	eventTime.Visible = false
	counter(scales, eventTime)
	local eventClock = 0
	-- S149b: the world boss over its barrow
	local bossColor = Theme.tint(UiPalette.map.worldBoss)
	local bossMarker = label(frame, "♛", bossColor, Theme.TextSize.Large, 12)
	bossMarker.Visible = false
	counter(scales, bossMarker)
	UiArtState.decorate(bossMarker, UiArt.mapIcon("worldboss"), { size = 26 })
	local bossCross = label(frame, "✕", Theme.Iron.Danger, Theme.TextSize.Large, 13)
	bossCross.Visible = false
	counter(scales, bossCross)
	local bossCaption = label(frame, "", Theme.Iron.Text, Theme.TextSize.Caption, 11)
	bossCaption.Size = UDim2.fromOffset(160, 18)
	bossCaption.Visible = false
	counter(scales, bossCaption)
	local bossRing = Instance.new("Frame")
	bossRing.Name = "WorldBossRing"
	bossRing.AnchorPoint = Vector2.new(0.5, 0.5)
	bossRing.Size = UDim2.fromOffset(46, 46)
	bossRing.BackgroundTransparency = 1
	bossRing.ZIndex = 11
	bossRing.Visible = false
	bossRing.Parent = frame
	counter(scales, bossRing)
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
	counter(scales, bossBar)
	local bossFill = Instance.new("Frame")
	bossFill.BackgroundColor3 = Theme.Resource.Hp
	bossFill.BorderSizePixel = 0
	bossFill.Size = UDim2.fromScale(1, 1)
	bossFill.ZIndex = 12
	bossFill.Parent = bossBar
	local bossClock = 0
	-- S159w: the wandering merchant's caravan (bright while he trades, faded in the last 10 min before he comes) and
	-- his time under it
	local merchantMarker = label(frame, "⚖", Theme.tint(WanderingMerchant.Data.look.canvas), Theme.TextSize.Large, 11)
	merchantMarker.Visible = false
	counter(scales, merchantMarker)
	local merchantCaption = label(frame, "", Theme.Iron.Text, Theme.TextSize.Caption, 11)
	merchantCaption.Size = UDim2.fromOffset(160, 18)
	merchantCaption.Visible = false
	counter(scales, merchantCaption)
	local merchantClock = 0
	local partyMarkers: { TextButton } = {}
	local partyIds: { number? } = {}
	for i = 1, PARTY do
		partyMarkers[i] =
			marker(scales, frame, "●", Theme.tint(UiPalette.map.party), Theme.TextSize.Body, 10, "party")
		UiArtState.decorate(
			partyMarkers[i]:FindFirstChild("Glyph") :: TextLabel,
			UiArt.mapIcon("party"),
			{ size = MARKER_ART }
		)
	end
	local markButtons: { TextButton } = {}
	for i = 1, MARKS do
		markButtons[i] = marker(scales, frame, "⚑", Theme.Brass.Bright, Theme.TextSize.Body, 10, "mark")
		UiArtState.decorate(markButtons[i]:FindFirstChild("Glyph") :: TextLabel, nil, { size = MARKER_ART })
	end

	-- Selection ring: one looping tween, no per-frame work.
	local ring = Instance.new("Frame")
	ring.Name = "Selection"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Size = UDim2.fromOffset(48, 48)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 9
	ring.Visible = false
	ring.Parent = frame
	counter(scales, ring)
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
	local hintTitle = hintLine(1, Theme.TextSize.Body, Theme.Brass.Bright)
	local hintSub = hintLine(2, Theme.TextSize.Small, Theme.Iron.Text)
	hintPadding.PaddingLeft = UDim.new(0, 10)
	hintPadding.PaddingRight = UDim.new(0, 10)
	hintPadding.PaddingTop = UDim.new(0, 6)
	hintPadding.PaddingBottom = UDim.new(0, 6)
	hintList.Padding = UDim.new(0, 2)

	local api: Api
	api = {
		frame = frame,
		ring = ring,
		hint = hint,
		partyMarkers = partyMarkers,
		partyIds = partyIds,
		markButtons = markButtons,
		setZoom = function(zoom: number)
			zoomNow = zoom
			for _, scale in scales do
				scale.Scale = 1 / zoom
			end
			hintScale.Scale = 1 / zoom
		end,
		showHint = function(title: string, sub: string?, pixel: Vector2, zoom: number)
			hintTitle.Text = title
			hintSub.Text = sub or ""
			hintSub.Visible = sub ~= nil and sub ~= ""
			hint.Position = UDim2.fromOffset(pixel.X, pixel.Y - (Canvas.PLATE / 2 + 6) / zoom)
			hint.Visible = true
		end,
		hideHint = function()
			hint.Visible = false
		end,
		-- Own marks of the shown map (≤ 8 buttons, repositioned when the marks or the map change).
		refreshMarks = function(cached: Canvas.Cached?, marks: any, hidden: { [string]: boolean })
			local used = 0
			if cached and type(marks) == "table" and not hidden.mark then
				for index, mark in marks do
					if mark.map == cached.mapId and used < #markButtons then
						used += 1
						local button = markButtons[used]
						local icon = MapMarks.get(mark.icon)
						local glyph = button:FindFirstChild("Glyph") :: TextLabel
						glyph.Text = if icon then icon.glyph else "⚑"
						glyph.TextColor3 = if icon then Theme.tint(icon.color) else Theme.Brass.Bright
						UiArtState.retarget(glyph, if icon then UiArt.mark(icon.id) else nil, glyph.TextColor3)
						local plate = button:FindFirstChild("Plate")
						local stroke = plate and plate:FindFirstChildOfClass("UIStroke")
						if stroke then
							stroke.Color = glyph.TextColor3
						end
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
			hidden: { [string]: boolean },
			selection: Selection?
		)
			local z = zoomNow
			player.Visible = me ~= nil
			if me then
				player.Position = UDim2.fromOffset(me.X, me.Y)
				if heading then
					player.Rotation = heading
				end
			end
			local target = Fusion.peek(QuestTrack.Target)
			local questOn = not hidden.objective
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
					questPlace.Position = UDim2.fromOffset(p.X, p.Y + 26 / z)
					questPlace.Text = Text.now(target.place)
				end
			end
			local event = State.Get({ "worldEvent" })
			local eventDef = if not hidden.event
					and type(event) == "table"
					and event.map == cached.mapId
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
				eventGlyph.Text = eventDef.glyph
				eventGlyph.TextColor3 = Theme.tint(eventDef.color)
				eventGlyph.TextTransparency = if event.phase == "warn" then 0.4 else 0
				eventStroke.Color = eventGlyph.TextColor3
				eventTime.Position = UDim2.fromOffset(p.X, p.Y + 26 / z)
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
				bossBar.Position = UDim2.fromOffset(p.X, p.Y + 22 / z)
				bossFill.Size = UDim2.fromScale(math.clamp(boss.hp or 1, 0, 1), 1)
				-- under the barrow's plate (and the HP bar while it fights)
				bossCaption.Position = UDim2.fromOffset(p.X, p.Y + (if boss.state == "active" then 34 else 28) / z)
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
			-- S159w: the wandering merchant (Logic/WanderingMerchant: the same visit on every server and client)
			local now = Clock.now()
			local visit = WanderingMerchant.shown(now)
			local soon = WanderingMerchant.Data.schedule.warn[1]
			local trading = now >= visit.startsAt
			local merchantHere = visit.spot.map == cached.mapId and (trading or visit.startsAt - now <= soon)
			merchantMarker.Visible = merchantHere
			merchantCaption.Visible = merchantHere
			if merchantHere then
				local p = Canvas.toPixel(cached, visit.spot.x, visit.spot.z)
				merchantMarker.Position = UDim2.fromOffset(p.X, p.Y)
				merchantMarker.TextTransparency = if trading then 0 else 0.4
				merchantCaption.Position = UDim2.fromOffset(p.X, p.Y + 22 / zoomNow)
				local clock = os.clock()
				if clock - merchantClock >= 0.5 then
					merchantClock = clock
					merchantCaption.Text = if trading
						then Text.now("wanderer.map.here", { time = Time.format(math.max(0, visit.endsAt - now)) })
						else Text.now(
							"wanderer.map.soon",
							{ time = Time.format(math.max(0, visit.startsAt - now)) }
						)
				end
			end
			local guide = Fusion.peek(NavTarget.Target)
			nav.Visible = guide ~= nil and guide.map == cached.mapId
			if guide and guide.map == cached.mapId then
				local p = Canvas.toPixel(cached, guide.x, guide.z)
				nav.Position = UDim2.fromOffset(p.X, p.Y - 22 / z)
			end
			local party = State.Get({ "party" })
			local shown = 0
			local map = Maps.get(cached.mapId)
			if type(party) == "table" and map and not hidden.party then
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
