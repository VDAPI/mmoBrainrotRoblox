--!strict
-- Round minimap (DESIGN §23, top right), north up: the current map's sketch (paths, water, buildings),
-- the player arrow (camera heading), nearby monsters (bigger dots for elites), NPCs with their service
-- glyph, portals, dungeon gates and gathering nodes. Map name and zone colour below, zoom + / −.
-- S22: monster areas filled stronger in the band colour relative to the player (redrawn after a level-up),
-- level ranges written on them at the closest zoom, the current area's name in its band colour.
-- S25: a click / tap opens the world map centred on the player; quest marks (! / ?) over NPCs, own map marks,
-- the guide target and, when it is out of view (or on another map), an arrow on the edge towards it (or towards
-- the portal on the way). Moving markers come from pools (no instances created while playing).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AreaState = require(script.Parent.Parent.Parent.AreaState)
local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GroupColors = require(script.Parent.Parent.Parent.GroupColors)
local MapSketch = require(script.Parent.Parent.Parent.MapSketch)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local MapMarks = require(ReplicatedStorage.Shared.Data.MapMarks)
local MapRoute = require(ReplicatedStorage.Shared.Logic.MapRoute)
local NavTarget = require(script.Parent.Parent.Parent.NavTarget)
local NpcMarkState = require(script.Parent.Parent.Parent.NpcMarkState)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestTrack = require(script.Parent.Parent.Parent.QuestTrack)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local SIZE = 220
local ZOOMS = { 0.25, 0.4, 0.6, 0.9 }
local MONSTER_RANGE = 140
local MONSTER_DOTS = 60
local MAX_MARKS = 8
local EDGE = SIZE / 2 - 14 -- pixels from the centre where the edge arrow sits
local ZONE_COLORS = {
	green = Theme.Colors.ZoneGreen,
	yellow = Theme.Colors.ZoneYellow,
	red = Theme.Colors.ZoneRed,
}
local ICONS: { [string]: { glyph: string, color: string } } = {
	portal = { glyph = "◎", color = "#B9A8FF" },
	cave = { glyph = "⛰", color = "#D9C9A8" },
	dungeon = { glyph = "☠", color = "#D64A3E" },
	node = { glyph = "•", color = "#E8C25A" },
	spawn = { glyph = "", color = "#C9A45C" },
}

local function glyph(parent: Instance, text: string, color: string, position: Vector2, size: number, z: number?)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(position.X, position.Y)
	label.Size = UDim2.fromOffset(size, size)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.FontFace = Theme.Fonts.BodyBold
	label.TextColor3 = Color3.fromHex(color)
	label.TextStrokeTransparency = 0.3
	label.ZIndex = z or 3
	label.Parent = parent
	return label
end

export type Props = { ShowWindow: (id: string) -> () }

local function Minimap(scope: Scope, props: Props): Instance
	local zone = State.Value({ "zone" })
	local mapId = State.Value({ "character", "location", "map" })
	local zoomIndex = scope:Value(2)
	local scale = scope:Computed(function(use): number
		return ZOOMS[use(zoomIndex)]
	end)

	local canvas = scope:New("Frame")({
		Name = "Canvas",
		BackgroundTransparency = 1,
	}) :: Frame
	-- Rotating mode (option "minimapRotate", S14) turns this holder so the camera direction points up.
	local holder = scope:New("Frame")({
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
	}) :: Frame
	canvas.Parent = holder
	local rotating = State.Value({ "account", "settings", "minimapRotate" })
	local northPosition = scope:Value(UDim2.new(0.5, 0, 0, 12))
	local dynamic = scope:New("Frame")({
		Name = "Dynamic",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = canvas,
	}) :: Frame

	-- Pools of the moving markers (S25): created once, only moved and shown / hidden.
	local questStar = glyph(dynamic, "★", "#E8C25A", Vector2.zero, 20, 6)
	questStar.Visible = false
	local navGlyph = glyph(dynamic, "◆", "#F2E28A", Vector2.zero, 18, 7)
	navGlyph.Visible = false
	local navArrow = glyph(dynamic, "▲", "#F2E28A", Vector2.zero, 20, 8)
	navArrow.TextStrokeTransparency = 0
	navArrow.Visible = false
	local markPool: { TextLabel } = {}
	for i = 1, MAX_MARKS do
		markPool[i] = glyph(dynamic, "⚑", "#E8C25A", Vector2.zero, 16, 6)
		markPool[i].Visible = false
	end
	local partyPool: { TextLabel } = {}
	for i = 1, 4 do
		partyPool[i] = glyph(dynamic, "●", "#4A8FE7", Vector2.zero, 14, 5)
		partyPool[i].Visible = false
	end
	local dotPool: { Frame } = {}
	for i = 1, MONSTER_DOTS do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BorderSizePixel = 0
		dot.ZIndex = 4
		dot.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = dot
		dot.Parent = dynamic
		dotPool[i] = dot
	end

	local current: MapSketch.Sketch? = nil
	local npcMarks: { [string]: TextLabel } = {}
	-- Quest marks over the NPC glyphs (S25), refreshed when the quests change.
	local function applyMarks()
		local marks = Fusion.peek(NpcMarkState.Marks)
		for npcId, label in npcMarks do
			local style = NpcMarkState.style(marks[npcId] :: any)
			label.Visible = style ~= nil
			if style then
				label.Text = style.text
				label.TextColor3 = style.color
			end
		end
	end
	scope:Observer(NpcMarkState.Marks):onChange(applyMarks)
	local currentScale = 0
	local currentMap = ""
	local currentLevel = 0
	local level = State.Value({ "character", "level" })

	local function redraw()
		local id = Fusion.peek(mapId) or ""
		local s = Fusion.peek(scale)
		local playerLevel = Fusion.peek(level) or 1
		if id == currentMap and s == currentScale and playerLevel == currentLevel and current then
			return
		end
		currentLevel = playerLevel
		for _, child in canvas:GetChildren() do
			if child ~= dynamic then
				child:Destroy()
			end
		end
		currentMap, currentScale = id, s
		current = MapSketch.get(id)
		local sketch = current
		if not sketch then
			return
		end
		canvas.Size = UDim2.fromOffset(sketch.size.x * s, sketch.size.z * s)
		MapSketch.draw(canvas, sketch, s)
		-- Monster areas tinted by level difference (S20; S22: band of the nearest end of the range, ~30% fill,
		-- level ranges at the closest zoom), under the icons.
		local data = Areas.byMap[id]
		local closest = s >= ZOOMS[#ZOOMS]
		for _, area in (if data then data.areas else {}) :: { Areas.Area } do
			local r = area.rect
			local a1 = MapSketch.toPixel(sketch, s, r[1], r[2])
			local a2 = MapSketch.toPixel(sketch, s, r[3], r[4])
			local color = Color3.fromHex(LevelBand.COLORS[AreaAdvice.bandOf(area, playerLevel)])
			local f = Instance.new("Frame")
			f.Name = "Area"
			f.Position = UDim2.fromOffset(a1.X + 1, a1.Y + 1)
			f.Size = UDim2.fromOffset(a2.X - a1.X - 2, a2.Y - a1.Y - 2)
			f.BackgroundColor3 = color
			f.BackgroundTransparency = 0.7
			f.BorderSizePixel = 0
			f.ZIndex = 1
			f.Parent = canvas
			if closest then
				local levels = glyph(canvas, `{area.lv[1]}–{area.lv[2]}`, "#FFFFFF", (a1 + a2) / 2, 16, 2)
				levels.TextScaled = false
				levels.TextSize = 13
				levels.Size = UDim2.fromOffset(60, 16)
				levels.TextColor3 = color
				levels.TextStrokeTransparency = 0.1
			end
		end
		for _, icon in sketch.icons do
			local style = ICONS[icon.t]
			if style and style.glyph ~= "" then
				glyph(
					canvas,
					style.glyph,
					style.color,
					MapSketch.toPixel(sketch, s, icon.x, icon.z),
					if icon.t == "node" then 10 else 18,
					2
				)
			end
		end
		table.clear(npcMarks)
		for _, npc in Npcs.list do
			if npc.map == id and not npc.decoration then
				local p = MapSketch.toPixel(sketch, s, npc.position.x, npc.position.z)
				glyph(canvas, npc.icon, "#F2E8C9", p, 18, 2)
				local mark = glyph(canvas, "", "#E8C25A", p - Vector2.new(0, 14), 18, 3)
				mark.FontFace = Theme.Fonts.Heading
				mark.TextStrokeTransparency = 0.1
				mark.Visible = false
				npcMarks[npc.id] = mark
			end
		end
		applyMarks()
	end

	scope:Observer(mapId):onChange(redraw)
	scope:Observer(scale):onChange(redraw)
	scope:Observer(level):onChange(redraw)

	local arrowRotation = scope:Value(0)
	local accumulator = 0
	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt)
			if not current then
				redraw()
			end
			local sketch = current
			local map = Maps.get(currentMap)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not sketch or not map or not root then
				return
			end
			local relative = root.Position - Vector3.new(map.offset.x, map.offset.y, map.offset.z)
			local pixel = MapSketch.toPixel(sketch, currentScale, relative.X, relative.Z)
			canvas.Position = UDim2.new(0.5, -pixel.X, 0.5, -pixel.Y)
			local camera = Workspace.CurrentCamera
			if camera then
				local look = camera.CFrame.LookVector
				local heading = math.deg(math.atan2(look.X, -look.Z))
				-- The arrow shows where the character faces (S19), not the camera.
				local facing = root.CFrame.LookVector
				local characterHeading = math.deg(math.atan2(facing.X, -facing.Z))
				if Fusion.peek(rotating) == true then
					holder.Rotation = -heading
					arrowRotation:set(characterHeading - heading)
					local angle = math.rad(-heading)
					local r = SIZE / 2 - 12
					northPosition:set(UDim2.new(0.5, math.sin(angle) * r, 0.5, -math.cos(angle) * r))
				else
					holder.Rotation = 0
					arrowRotation:set(characterHeading)
					northPosition:set(UDim2.new(0.5, 0, 0, 12))
				end
			end
			accumulator += dt
			if accumulator < 0.4 then
				return
			end
			accumulator = 0
			local offset = Vector3.new(map.offset.x, map.offset.y, map.offset.z)
			local function at(x: number, z: number): Vector2
				return MapSketch.toPixel(sketch, currentScale, x, z)
			end
			-- Quest target (S11)
			local target = Fusion.peek(QuestTrack.Target)
			local showQuest = target ~= nil
				and target.map == currentMap
				and target.x ~= nil
				and target.z ~= nil
				and Fusion.peek(QuestTrack.Tracked) == true
			questStar.Visible = showQuest
			if showQuest and target and target.x and target.z then
				local p = at(target.x, target.z)
				questStar.Position = UDim2.fromOffset(p.X, p.Y)
			end
			-- Guide target (S25): the target itself, or an arrow on the edge when it is out of view / elsewhere.
			local nav = Fusion.peek(NavTarget.Target)
			local navPoint: Vector2? = nil
			if nav then
				if nav.map == currentMap then
					navPoint = at(nav.x, nav.z)
				else
					local exit = MapRoute.nextExit(currentMap, nav.map, MapSketch.isBuilt)
					if exit then
						navPoint = at(exit.x, exit.z)
					end
				end
			end
			local inView = navPoint ~= nil and (navPoint - pixel).Magnitude <= EDGE
			navGlyph.Visible = navPoint ~= nil and nav ~= nil and nav.map == currentMap and inView
			navArrow.Visible = navPoint ~= nil and not navGlyph.Visible
			if navPoint then
				if navGlyph.Visible then
					navGlyph.Position = UDim2.fromOffset(navPoint.X, navPoint.Y)
				else
					local direction = navPoint - pixel
					if direction.Magnitude > 0.01 then
						local unit = direction.Unit
						local edge = pixel + unit * math.min(EDGE, direction.Magnitude)
						navArrow.Position = UDim2.fromOffset(edge.X, edge.Y)
						navArrow.Rotation = math.deg(math.atan2(unit.X, -unit.Y))
					end
				end
			end
			-- Own marks (S25)
			local marks = State.Get({ "character", "mapMarks" })
			local usedMarks = 0
			if type(marks) == "table" then
				for _, mark in marks do
					if mark.map == currentMap and usedMarks < MAX_MARKS then
						usedMarks += 1
						local label = markPool[usedMarks]
						local icon = MapMarks.get(mark.icon)
						label.Text = if icon then icon.glyph else "⚑"
						label.TextColor3 = if icon then Color3.fromHex(icon.color) else Theme.Colors.GoldBright
						local p = at(mark.x, mark.z)
						label.Position = UDim2.fromOffset(p.X, p.Y)
						label.Visible = true
					end
				end
			end
			for i = usedMarks + 1, MAX_MARKS do
				markPool[i].Visible = false
			end
			-- Party members (blue dots)
			local party = State.Get({ "party" })
			local usedParty = 0
			if type(party) == "table" then
				for _, member in party.members do
					if
						member.id ~= Players.LocalPlayer.UserId
						and member.map == currentMap
						and usedParty < #partyPool
					then
						usedParty += 1
						local p = at(member.x - map.offset.x, member.z - map.offset.z)
						partyPool[usedParty].Position = UDim2.fromOffset(p.X, p.Y)
						partyPool[usedParty].Visible = true
					end
				end
			end
			for i = usedParty + 1, #partyPool do
				partyPool[i].Visible = false
			end
			-- Monsters nearby (S19: normal ones in the colour of their group size, elites gold).
			local usedDots = 0
			local monsters = Workspace:FindFirstChild("Monsters")
			if monsters then
				for _, model in monsters:GetChildren() do
					if usedDots >= MONSTER_DOTS then
						break
					end
					if model:IsA("Model") and model:GetAttribute("Dead") ~= true then
						local pivot = model:GetPivot().Position
						if (pivot - root.Position).Magnitude <= MONSTER_RANGE then
							usedDots += 1
							local local_ = pivot - offset
							local variant = model:GetAttribute("Variant")
							local size = if variant == "elite2" then 12 elseif variant == "elite" then 9 else 6
							local dot = dotPool[usedDots]
							local p = at(local_.X, local_.Z)
							dot.Position = UDim2.fromOffset(p.X, p.Y)
							dot.Size = UDim2.fromOffset(size, size)
							dot.BackgroundColor3 = if variant == "normal" or variant == nil
								then GroupColors.of(model:GetAttribute("GroupSize") :: number?)
								else Theme.Colors.GoldBright
							dot.Visible = true
						end
					end
				end
			end
			for i = usedDots + 1, MONSTER_DOTS do
				dotPool[i].Visible = false
			end
		end)
	)

	local function zoomButton(text: string, delta: number, order: number): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.1,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = 22,
			TextColor3 = Theme.Colors.Parchment,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			},
			[OnEvent("Activated")] = function()
				zoomIndex:set(math.clamp(Fusion.peek(zoomIndex) + delta, 1, #ZOOMS))
			end,
		})
	end

	return scope:New("Frame")({
		Name = "Minimap",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(SIZE + 44, SIZE + 46),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("CanvasGroup")({
				Name = "Disc",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(SIZE, SIZE),
				BackgroundColor3 = scope:Computed(function(use): Color3
					local map = Maps.get(use(mapId) or "")
					return MapSketch.background(if map then map.biome else "grass")
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					holder,
					-- S25: click / tap = the world map, centred on the player.
					scope:New("TextButton")({
						Name = "OpenMap",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 9,
						[OnEvent("Activated")] = function()
							NavTarget.MapFocus:set({ zoom = 2 })
							props.ShowWindow("map")
						end,
					}),
					scope:New("TextLabel")({
						Name = "Player",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(22, 22),
						BackgroundTransparency = 1,
						Text = "▲",
						TextScaled = true,
						TextColor3 = Theme.Colors.Accent,
						TextStrokeTransparency = 0,
						Rotation = arrowRotation,
						ZIndex = 10,
					}),
					scope:New("TextLabel")({
						Name = "North",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = northPosition,
						Size = UDim2.fromOffset(16, 16),
						BackgroundTransparency = 1,
						Text = "N",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 14,
						TextColor3 = Theme.Colors.Gold,
						ZIndex = 10,
					}),
				},
			}),
			-- Ring with the zone colour
			scope:New("Frame")({
				Name = "Ring",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(SIZE, SIZE),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({
						Thickness = 3,
						Color = scope:Computed(function(use): Color3
							local z = use(zone)
							return if type(z) == "table"
								then ZONE_COLORS[z.pvp] or Theme.Colors.Gold
								else Theme.Colors.Gold
						end),
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Zoom",
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, SIZE - 80),
				Size = UDim2.fromOffset(36, 80),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
					zoomButton("+", 1, 1),
					zoomButton("−", -1, 2),
				},
			}),
			-- Current monster area under the map name (S20).
			scope:New("TextLabel")({
				Name = "AreaName",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 1, 2),
				Size = UDim2.fromOffset(SIZE + 30, 22),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(AreaState.Current) ~= nil
				end),
				Text = scope:Computed(function(use): string
					local area = use(AreaState.Current)
					if not area then
						return ""
					end
					return Text.get(
						use,
						"area.label",
						{ name = Text.get(use, area.nameKey), min = area.lv[1], max = area.lv[2] }
					)
				end),
				TextTruncate = Enum.TextTruncate.AtEnd,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = 15,
				TextColor3 = scope:Computed(function(use): Color3
					local area = use(AreaState.Current)
					if not area then
						return Theme.Colors.Parchment
					end
					return Color3.fromHex(LevelBand.COLORS[AreaAdvice.bandOf(area, use(level) or 1)])
				end),
				TextStrokeTransparency = 0.2,
			}),
			scope:New("TextLabel")({
				Name = "MapName",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromOffset(SIZE + 30, 36),
				BackgroundColor3 = Theme.Colors.Panel,
				BackgroundTransparency = 0.15,
				Text = scope:Computed(function(use): string
					local z = use(zone)
					local map = Maps.get(use(mapId) or "")
					if type(z) == "table" and z.nameKey then
						return Text.get(use, AreaState.zoneNameKey(z, if map then map.nameKey else nil))
					end
					return if map then Text.get(use, map.nameKey) else ""
				end),
				TextTruncate = Enum.TextTruncate.AtEnd,
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Parchment,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Stroke.Normal,
						Color = scope:Computed(function(use): Color3
							local z = use(zone)
							return if type(z) == "table"
								then ZONE_COLORS[z.pvp] or Theme.Colors.Border
								else Theme.Colors.Border
						end),
					}),
				},
			}),
		},
	})
end

return Minimap
