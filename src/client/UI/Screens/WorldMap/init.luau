--!strict
-- World map (M), DESIGN §23. S20/S22: a list of maps on the left (region -> map -> caves, coloured by the level
-- band, areas of the selected map under it) and the detailed map on the right (WorldMap/Canvas: the sketch,
-- monster areas, portals, caves, dungeons, NPCs, nodes), zoom with the wheel / pinch / buttons, drag to pan,
-- "Centre on me", layer toggles, the band legend and "Show only recommended".
-- S25 (interactive map): every icon is clickable. PC: hover = a small hint, click = a pinned card
-- (WorldMap/DetailCard + WorldMap/Cards) that stays until ✕, a click on empty ground or another icon; the
-- selected icon gets a pulsing gold ring. Touch: tap = the card as a bottom sheet; dragging the map keeps it.
-- Cards have a 3D preview (WorldMap/Preview) and actions: Guide (NavController draws a path, the HUD shows the
-- distance), Walk (the character walks there itself), Centre, Show map, Profile, Remove. A double click / long
-- press on the ground opens a menu: Walk here, Guide here, Place a mark (own marks, Data/MapMarks). Search
-- (WorldMap/Search) over the list, service chips that highlight NPCs, quest marks (! / ?) over NPC icons,
-- party members, own marks and the guide target on the map.
-- Performance: the static layer of every map is built once and cached (Canvas), zoom is a UIScale, panning
-- moves one frame; per frame only the player, party, quest and guide markers move. No Instance.new in
-- RenderStepped; one set of connections for the shown map, dropped on map change and on close.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Canvas = require(script.Canvas)
local Cards = require(script.Cards)
local DetailCard = require(script.DetailCard)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Gestures = require(script.Gestures)
local GroundMenu = require(script.GroundMenu)
local MapSearch = require(ReplicatedStorage.Shared.Logic.MapSearch)
local MapSketch = require(script.Parent.Parent.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local NavTarget = require(script.Parent.Parent.NavTarget)
local Net = require(ReplicatedStorage.Shared.Net)
local NpcMarkState = require(script.Parent.Parent.NpcMarkState)
local Panels = require(script.Panels)
local Overlay = require(script.Overlay)
local Preview = require(script.Preview)
local Scale = require(script.Parent.Parent.Scale)
local Search = require(script.Search)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local LIST_WIDTH = 230
local ZOOMS = Canvas.ZOOMS
local LIVE_REFRESH = 2 -- seconds between refreshes of live cards (party, timers)

-- Services handed in by WorldController.
export type Services = {
	Guide: (target: NavTarget.Target) -> (),
	Walk: (target: NavTarget.Target) -> boolean,
	Resolve: (mapId: string, x: number, z: number) -> (number?, number?),
	OpenProfile: (userId: number) -> (),
	BuildLook: Preview.BuildLook?,
}

local services: Services? = nil

type Selection = { kind: string, id: string, extra: any? }

local function WorldMapWindow(scope: Scope, closeWindow: (() -> ())?): Fusion.Child
	local mapId = State.Value({ "character", "location", "map" })
	local level = State.Value({ "character", "level" })
	local classId = State.Value({ "character", "class" })
	local marksState = State.Value({ "character", "mapMarks" })
	local touch = Device.Touch
	local selected = scope:Value(Fusion.peek(mapId) or "city")
	local zoomIndex = scope:Value(1)
	local center = scope:Value(Vector2.new(Canvas.SIZE / 2, Canvas.SIZE / 2)) -- canvas pixel in the view middle
	local onlyRecommended = scope:Value(false)
	local highlight = scope:Value(nil :: string?)
	local chips = scope:Value({} :: { [string]: boolean })
	local toggles = {
		areas = scope:Value(true),
		nodes = scope:Value(true),
		npcs = scope:Value(true),
		icons = scope:Value(true),
		quest = scope:Value(true),
	}

	-- Chips hold chip keys; the canvas wants the set of services they match.
	local function serviceFilter(): { [string]: boolean }
		return Panels.servicesOf(Fusion.peek(chips))
	end

	local current: Canvas.Cached? = nil
	local stack: { Selection } = {}
	local gestures: Gestures.Api
	local hoverEntry: Selection? = nil

	-- Map view -----------------------------------------------------------------------------------------------
	local view = scope:New("Frame")({
		Name = "View",
		Position = UDim2.fromOffset(LIST_WIDTH + 12, 0),
		Size = UDim2.new(1, -(LIST_WIDTH + 12), 1, -48),
		BackgroundColor3 = Theme.Colors.Background,
		ClipsDescendants = true,
		[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
	}) :: Frame
	local holder = scope:New("Frame")({
		Name = "Holder",
		Parent = view,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}) :: Frame
	local uiScale = Instance.new("UIScale")
	local overlay = Overlay.new(scope)
	local dynamic = overlay.frame
	local ring = overlay.ring
	local partyMarkers = overlay.partyMarkers
	local partyIds = overlay.partyIds
	local markButtons = overlay.markButtons
	table.insert(scope, uiScale)

	local emptyLabel = scope:New("TextLabel")({
		Parent = view,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Text = Text.T(scope, "worldmap.soon"),
		FontFace = Theme.Fonts.Heading,
		TextSize = 28,
		TextColor3 = Theme.Colors.Parchment,
	}) :: TextLabel

	-- Cached canvases outlive the window: detach them before the window is destroyed.
	table.insert(scope, function()
		if current then
			current.canvas.Parent = nil
			uiScale.Parent = nil
			dynamic.Parent = nil
		end
	end)

	local function zoom(): number
		return ZOOMS[Fusion.peek(zoomIndex)]
	end

	-- Canvas pixel of a map-relative point on the shown map.
	local function pixelOf(x: number, z: number): Vector2?
		return if current then Canvas.toPixel(current, x, z) else nil
	end

	local function myPixel(): Vector2?
		local map = Maps.get(Fusion.peek(selected))
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not current or not map or not root or Fusion.peek(mapId) ~= map.id then
			return nil
		end
		local relative = root.Position - Vector3.new(map.offset.x, map.offset.y, map.offset.z)
		return pixelOf(relative.X, relative.Z)
	end

	local function myPosition(): Vector3?
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return if root then root.Position else nil
	end

	local function applyToggles()
		if not current then
			return
		end
		Canvas.applyZoom(current, Fusion.peek(zoomIndex), {
			areas = Fusion.peek(toggles.areas),
			icons = Fusion.peek(toggles.icons),
			npcs = Fusion.peek(toggles.npcs),
			nodes = Fusion.peek(toggles.nodes),
		})
		overlay.setZoom(zoom())
	end

	local function place()
		if not current then
			return
		end
		local z = zoom()
		uiScale.Scale = z
		local size = view.AbsoluteSize / math.max(0.1, Fusion.peek(Scale.Value))
		local c = Fusion.peek(center)
		current.canvas.Position = UDim2.fromOffset(size.X / 2 - c.X * z, size.Y / 2 - c.Y * z)
	end

	-- Cards ---------------------------------------------------------------------------------------------------
	local card: DetailCard.Api
	local renderCard: (keepScroll: boolean?) -> ()
	local selectCard: (kind: string, id: string, extra: any?, push: boolean?) -> ()

	local function closeCard()
		table.clear(stack)
		card.show(nil)
		ring.Visible = false
	end

	-- Where a selection sits on the shown map (for the ring), or nil.
	local function selectionPixel(entry: Selection): Vector2?
		if not current then
			return nil
		end
		if entry.kind == "area" then
			for _, area in current.areas do
				if area.area.id == entry.id then
					return nil -- areas get their gold outline instead
				end
			end
			return nil
		end
		if entry.kind == "party" or entry.kind == "mark" then
			return nil -- follows the dynamic marker (RenderStepped)
		end
		if entry.kind == "node" and type(entry.extra) == "table" and entry.extra.map == current.mapId then
			return pixelOf(entry.extra.x, entry.extra.z)
		end
		local iconKind = if entry.kind == "boss" then "dungeon" else entry.kind
		for _, icon in current.icons do
			if icon.kind == iconKind and icon.id == entry.id then
				return icon.pixel
			end
		end
		return nil
	end

	local function centerOn(map: string, x: number, z: number, zoomTo: number?)
		if Fusion.peek(selected) ~= map then
			selected:set(map)
		end
		if zoomTo then
			zoomIndex:set(math.max(Fusion.peek(zoomIndex), zoomTo))
		end
		local p = pixelOf(x, z)
		if p then
			center:set(p)
		end
	end

	local function context(): Cards.Context
		local svc = services
		return {
			here = Fusion.peek(mapId),
			position = myPosition(),
			level = Fusion.peek(level) or 1,
			class = Fusion.peek(classId) or "Warrior",
			guide = function(target: NavTarget.Target)
				if svc then
					svc.Guide(target)
					Sounds.play("click")
					Toast.push(
						Text.now("nav.started", {
							name = if target.label
								then target.label
								elseif target.labelKey then Text.now(target.labelKey)
								else "",
						}),
						"info",
						3
					)
				end
			end,
			walk = function(target: NavTarget.Target)
				if svc and svc.Walk(target) then
					Sounds.play("click")
					if State.Get({ "account", "settings", "mapCloseOnWalk" }) ~= false and closeWindow then
						closeWindow()
					end
				end
			end,
			center = function(map: string, x: number, z: number)
				centerOn(map, x, z, 3)
			end,
			showMap = function(map: string)
				selected:set(map)
			end,
			open = function(kind: string, id: string, extra: any?)
				selectCard(kind, id, extra, true)
			end,
			back = if #stack > 1
				then function()
					table.remove(stack)
					renderCard()
				end
				else nil,
			openProfile = function(userId: number)
				if svc then
					svc.OpenProfile(userId)
				end
			end,
			removeMark = function(index: number)
				task.spawn(function()
					local ok, err = Net.Invoke("MapMarkRemove", index)
					if ok then
						Toast.push(Text.now("worldmap.mark.removed"), "info", 2)
						closeCard()
					else
						Toast.push(Text.now(err or "error.internal"), "error")
					end
				end)
			end,
			refresh = function()
				renderCard(true)
			end,
		}
	end

	renderCard = function(keepScroll: boolean?)
		local top = stack[#stack]
		if not top then
			card.show(nil)
			ring.Visible = false
			return
		end
		local spec = Cards.build(context(), top.kind, top.id, top.extra)
		if not spec then
			closeCard()
			return
		end
		card.show(spec, keepScroll)
		local p = selectionPixel(stack[1])
		ring.Visible = p ~= nil
		if p then
			ring.Position = UDim2.fromOffset(p.X, p.Y)
		end
	end

	selectCard = function(kind: string, id: string, extra: any?, push: boolean?)
		if not push then
			table.clear(stack)
		end
		-- Re-selecting the same sub-card (variant switch) replaces it instead of stacking.
		local top = stack[#stack]
		if push and top and top.kind == kind and top.id == id then
			stack[#stack] = { kind = kind, id = id, extra = extra }
		else
			table.insert(stack, { kind = kind, id = id, extra = extra })
		end
		if kind == "area" then
			highlight:set(id)
		end
		overlay.hideHint()
		renderCard()
	end

	card = DetailCard.new(scope, {
		Touch = touch,
		BuildLook = if services then services.BuildLook else nil,
		OnClose = closeCard,
	})

	-- Ground menu (double click / long press) ------------------------------------------------------------------
	local function pointTarget(point: GroundMenu.Point): NavTarget.Target?
		local x, z = point.x, point.z
		if services then
			local rx, rz = services.Resolve(point.map, x, z)
			if not rx or not rz then
				Toast.push(Text.now("nav.unreachable"), "warning", 3)
				return nil
			end
			x, z = rx, rz
		end
		return { map = point.map, x = x, z = z, kind = "point", label = Text.now("worldmap.menu.point") }
	end

	local menu = GroundMenu.new(scope, {
		Touch = touch,
		Scale = scope:Computed(function(use): number
			return 1 / ZOOMS[use(zoomIndex)]
		end),
		OnHere = scope:Computed(function(use): boolean
			return use(selected) == use(mapId)
		end),
		OnWalk = function(point)
			local target = pointTarget(point)
			if target then
				context().walk(target)
			end
		end,
		OnGuide = function(point)
			local target = pointTarget(point)
			if target then
				context().guide(target)
			end
		end,
		OnMark = function(point, icon)
			task.spawn(function()
				local ok, err = Net.Invoke("MapMarkAdd", point.map, point.x, point.z, icon)
				if ok then
					Sounds.play("click")
					Toast.push(Text.now("worldmap.mark.added"), "success", 2)
				else
					Sounds.play("error")
					Toast.push(Text.now(err or "error.internal"), "error")
				end
			end)
		end,
		Consume = function()
			gestures.consume()
		end,
	})
	menu.frame.Parent = dynamic
	local hideMenu = menu.hide

	local function openMenu(pixel: Vector2)
		if not current then
			return
		end
		local x, z = MapSketch.fromPixel(current.sketch, current.scale, pixel)
		local map = Maps.get(current.mapId)
		if not map or math.abs(x) > map.size.x / 2 or math.abs(z) > map.size.z / 2 then
			return
		end
		menu.open(pixel, { map = current.mapId, x = x, z = z }, zoom())
		overlay.hideHint()
		Sounds.play("click")
	end

	-- Hover hint (PC) -------------------------------------------------------------------------------------------
	local function showHint(entry: Selection?, pixel: Vector2?)
		hoverEntry = entry
		if not entry or not pixel or Fusion.peek(touch) then
			overlay.hideHint()
			return
		end
		local title, sub = Cards.hint(entry.kind, entry.id, Fusion.peek(level) or 1, entry.extra)
		overlay.showHint(title, sub, pixel, zoom())
	end

	-- Gestures (drag, zoom, taps, double tap / long press -> ground menu).
	gestures = Gestures.new(scope, {
		View = view,
		Canvas = function(): Canvas.Cached?
			return current
		end,
		Pan = function(delta: Vector2)
			center:set(Fusion.peek(center) - delta)
		end,
		Zoom = function(delta: number)
			zoomIndex:set(math.clamp(Fusion.peek(zoomIndex) + delta, 1, #ZOOMS))
		end,
		PinchStart = function(): number
			return Fusion.peek(zoomIndex)
		end,
		PinchSet = function(index: number)
			zoomIndex:set(math.clamp(index, 1, #ZOOMS))
		end,
		Select = function(entry: Selection)
			hideMenu()
			Sounds.play("click")
			selectCard(entry.kind, entry.id, entry.extra)
		end,
		Ground = function()
			hideMenu()
			if card.isOpen() then
				closeCard()
			end
		end,
		Menu = openMenu,
	})

	-- One set of connections for the icons and areas of the shown map.
	local connections: { RBXScriptConnection } = {}
	local function unwire()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
	local function wire()
		unwire()
		if not current then
			return
		end
		local cached = current
		local function hook(button: GuiButton, entry: Selection, pixel: () -> Vector2?)
			table.insert(
				connections,
				button.Activated:Connect(function(input: InputObject)
					gestures.buttonTap(input, entry)
				end)
			)
			table.insert(
				connections,
				button.MouseEnter:Connect(function()
					showHint(entry, pixel())
				end)
			)
			table.insert(
				connections,
				button.MouseLeave:Connect(function()
					if hoverEntry == entry then
						showHint(nil, nil)
					end
				end)
			)
		end
		for _, icon in cached.icons do
			local entry: Selection = if icon.kind == "node"
				then { kind = "node", id = icon.id, extra = { map = cached.mapId, x = icon.x, z = icon.z } }
				else { kind = icon.kind, id = icon.id }
			hook(icon.button, entry, function()
				return icon.pixel
			end)
		end
		for _, area in cached.areas do
			local entry: Selection = { kind = "area", id = area.area.id, extra = { map = cached.mapId } }
			hook(area.frame, entry, function()
				local x, z = AreaAdvice.centre(area.area)
				return pixelOf(x, z)
			end)
		end
		for i, button in partyMarkers do
			table.insert(
				connections,
				button.Activated:Connect(function(input: InputObject)
					local userId = partyIds[i]
					if userId then
						gestures.buttonTap(input, { kind = "party", id = tostring(userId) })
					end
				end)
			)
		end
		for _, button in markButtons do
			table.insert(
				connections,
				button.Activated:Connect(function(input: InputObject)
					local index = button:GetAttribute("Index")
					if type(index) == "number" then
						gestures.buttonTap(input, { kind = "mark", id = tostring(index) })
					end
				end)
			)
		end
	end
	table.insert(scope, unwire)

	local function refreshMarks()
		overlay.refreshMarks(current, Fusion.peek(marksState))
	end

	local function show(id: string)
		if current then
			current.canvas.Parent = nil
		end
		hideMenu()
		showHint(nil, nil)
		current = Canvas.get(id)
		emptyLabel.Visible = current == nil
		if not current then
			unwire()
			return
		end
		local cached = current
		-- S22: open on the player (their own map) with the recommended area outlined.
		local playerLevel = Fusion.peek(level) or 1
		local best = if Areas.byMap[id] then AreaAdvice.best(playerLevel, id) else nil
		highlight:set(if best then best.id else nil)
		Canvas.refresh(
			cached,
			playerLevel,
			{ onlyRecommended = Fusion.peek(onlyRecommended), highlight = Fusion.peek(highlight) }
		)
		Canvas.applyMarks(cached, Fusion.peek(NpcMarkState.Marks))
		Canvas.applyFilter(cached, serviceFilter())
		uiScale.Parent = cached.canvas
		dynamic.Parent = cached.canvas
		cached.canvas.Parent = holder
		center:set(Vector2.new(cached.canvas.Size.X.Offset / 2, cached.canvas.Size.Y.Offset / 2))
		if id == Fusion.peek(mapId) then
			local me = myPixel()
			if me then
				center:set(me)
			end
		end
		applyToggles()
		refreshMarks()
		wire()
		place()
		-- The pinned card stays, but its ring belongs to the old map.
		local first = stack[1]
		local p = if first then selectionPixel(first) else nil
		ring.Visible = p ~= nil
		if p then
			ring.Position = UDim2.fromOffset(p.X, p.Y)
		end
	end

	scope:Observer(selected):onBind(function()
		show(Fusion.peek(selected))
	end)
	scope:Observer(zoomIndex):onChange(function()
		applyToggles()
		place()
		hideMenu()
	end)
	scope:Observer(center):onChange(place)
	for _, toggle in toggles do
		scope:Observer(toggle):onChange(applyToggles)
	end
	local function refreshView()
		if current then
			Canvas.refresh(
				current,
				Fusion.peek(level) or 1,
				{ onlyRecommended = Fusion.peek(onlyRecommended), highlight = Fusion.peek(highlight) }
			)
		end
	end
	scope:Observer(level):onChange(refreshView)
	scope:Observer(Text.Lang):onChange(function()
		refreshView()
		if #stack > 0 then
			renderCard(true)
		end
	end)
	scope:Observer(onlyRecommended):onChange(refreshView)
	scope:Observer(highlight):onChange(refreshView)
	scope:Observer(NpcMarkState.Marks):onChange(function()
		if current then
			Canvas.applyMarks(current, Fusion.peek(NpcMarkState.Marks))
			applyToggles()
		end
	end)
	scope:Observer(chips):onChange(function()
		if current then
			Canvas.applyFilter(current, serviceFilter())
		end
	end)
	scope:Observer(marksState):onChange(function()
		refreshMarks()
		local top = stack[#stack]
		if top and top.kind == "mark" then
			renderCard(true)
		end
	end)
	table.insert(scope, view:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))

	-- Area rows in the list: zoom in on the area, outline it and open its card.
	local function focusArea(area: Areas.Area)
		if not current then
			return
		end
		local cx, cz = AreaAdvice.centre(area)
		highlight:set(area.id)
		zoomIndex:set(math.max(Fusion.peek(zoomIndex), 2))
		local p = pixelOf(cx, cz)
		if p then
			center:set(p)
		end
		selectCard("area", area.id, { map = current.mapId })
	end

	-- Requests from outside (minimap click, search, the HUD): centre / open a card.
	local function applyFocus(focus: NavTarget.Focus?)
		if not focus then
			return
		end
		NavTarget.MapFocus:set(nil)
		local map = focus.map or Fusion.peek(mapId) or "city"
		if Fusion.peek(selected) ~= map then
			selected:set(map)
		end
		if focus.zoom then
			zoomIndex:set(math.clamp(focus.zoom, 1, #ZOOMS))
		end
		if focus.x and focus.z then
			local p = pixelOf(focus.x, focus.z)
			if p then
				center:set(p)
			end
		elseif map == Fusion.peek(mapId) then
			local me = myPixel()
			if me then
				center:set(me)
			end
		end
		if focus.card then
			selectCard(focus.card.kind, focus.card.id, (focus.card :: any).extra)
		end
	end
	scope:Observer(NavTarget.MapFocus):onBind(function()
		applyFocus(Fusion.peek(NavTarget.MapFocus))
	end)

	-- Search results: switch the map, zoom to the thing, open its card.
	local function onSearch(result: MapSearch.Result)
		local kind = result.kind
		local extra: any = nil
		local cardKind, cardId = kind, result.id
		if kind == "area" or kind == "node" then
			extra = { map = result.map, x = result.x, z = result.z }
		elseif kind == "map" then
			cardKind = ""
		elseif kind == "cave" then
			cardKind = "cave"
		elseif kind == "boss" then
			local boss = Bosses.get(result.id)
			if boss then
				cardKind, cardId = "dungeon", boss.region
			end
		end
		applyFocus({
			map = result.map,
			x = result.x,
			z = result.z,
			zoom = if kind == "map" or kind == "cave" then 1 else 3,
			card = if cardKind ~= "" then { kind = cardKind, id = cardId, extra = extra } :: any else nil,
		})
	end
	local search = Search.new(scope, { OnPick = onSearch, Touch = touch })

	local function zoomBy(delta: number)
		zoomIndex:set(math.clamp(Fusion.peek(zoomIndex) + delta, 1, #ZOOMS))
	end

	-- Moving markers (positions only) and the live card refresh.
	local liveClock = 0
	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt)
			if not current then
				return
			end
			local me = myPixel()
			local heading: number? = nil
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if me and root then
				local look = root.CFrame.LookVector
				heading = math.deg(math.atan2(look.X, -look.Z))
			end
			overlay.step(current, me, heading, Fusion.peek(toggles.quest), stack[1])
			liveClock += dt
			if liveClock >= LIVE_REFRESH then
				liveClock = 0
				local top = stack[#stack]
				if top and (top.kind == "party" or top.kind == "cave" or top.kind == "dungeon") then
					renderCard(true)
				end
			end
		end)
	)

	return {
		scope:New("Frame")({
			Name = "Left",
			Size = UDim2.new(0, LIST_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			[Children] = {
				search.box,
				scope:New("ScrollingFrame")({
					Name = "MapList",
					Position = UDim2.fromOffset(0, 46),
					Size = UDim2.new(1, 0, 1, -46),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollBarThickness = 5,
					ScrollBarImageColor3 = Theme.Colors.GoldDim,
					Visible = scope:Computed(function(use): boolean
						return not use(search.active)
					end),
					[Children] = {
						scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
						Panels.mapList(scope, {
							Selected = selected,
							MapId = mapId,
							Level = level,
							Highlight = highlight,
							OnArea = focusArea,
						}) :: any,
					},
				}),
				search.results,
			},
		}),
		view,
		Panels.bands(scope, {
			Position = UDim2.fromOffset(LIST_WIDTH + 22, 10),
			Selected = selected,
			Level = level,
			OnlyRecommended = onlyRecommended,
		}),
		Panels.chips(scope, {
			Position = UDim2.fromOffset(LIST_WIDTH + 22, 10),
			RightGap = 340,
			Selected = selected,
			Chips = chips,
			Touch = touch,
		}),
		card.frame,
		Panels.bar(scope, {
			Position = UDim2.new(0, LIST_WIDTH + 12, 1, 0),
			Size = UDim2.new(1, -(LIST_WIDTH + 12), 0, 40),
			Toggles = toggles :: any,
			ZoomBy = zoomBy,
			CentreOnMe = function()
				if Fusion.peek(selected) ~= Fusion.peek(mapId) then
					selected:set(Fusion.peek(mapId) or "city")
				end
				local me = myPixel()
				if me then
					center:set(me)
				end
			end,
		}),
	}
end

local WorldMap = {}

-- WorldController hands in the guide, the walk, the profile window and the look builder (S25).
function WorldMap.setServices(value: Services)
	services = value
end

-- Drops the cached static layers and search indexes (admin /mapcache clear, a rebuilt map).
function WorldMap.clearCache()
	Canvas.clearCache()
	Search.clearCache()
end

return setmetatable(WorldMap, {
	__call = function(_, scope: Scope, close: (() -> ())?): Fusion.Child
		return WorldMapWindow(scope, close)
	end,
}) :: any
