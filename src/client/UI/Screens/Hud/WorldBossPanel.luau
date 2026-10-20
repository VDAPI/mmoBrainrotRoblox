--!strict
-- World boss panel (S149b, DESIGN §15.6): the HUD side of the world boss (state branch `worldBoss`, Logic/WorldBoss).
-- On the boss's map from the first warning to the end of the marker ("full", Logic/WorldBoss.panelOf): the boss's
-- name, the time to the start, then the HP bar, the phase and the time to its leave, the channel to break (the shared
-- Components/ChannelBar of the dungeon boss bar), the own share ("Share 12 %") and whether the reward is due (✓ or the
-- reason: level / share / claimed), "Guide" while outside the circle; after the fight "Slain" / "Gone" for the
-- marker's linger. On any other map from the first warning to the end of the fight (S149c): one line "{boss} in 7:42 ·
-- {place}", then "{boss} fights, 1:52:31 left · {place}" (Logic/WorldBoss.lineOf) with "Guide"; a tap on the line opens
-- the world map at the barrow with its card (props.OpenMap).
-- A tap on the header folds the panel to one line (kept for the session). PC: the right column over the quest
-- tracker (the S101 world event panel stands under it: the boss comes first); touch: the left column under the
-- portrait like the world event panel (never over the skill buttons). Sounds: ui.worldboss.spawn when the boss
-- wakes, ui.worldboss.victory when it falls (silent until the owner picks ids). Iron surface (Data/UiWindows).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local ChannelBar = require(script.Parent.Parent.Parent.Components.ChannelBar)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)
local WorldBoss = require(ReplicatedStorage.Shared.Logic.WorldBoss)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type GuideTarget = { map: string, x: number, z: number, labelKey: string }

export type Props = {
	Guide: (target: GuideTarget) -> (),
	-- Set to the pixels the quest tracker moves down (PC; 0 while hidden or on touch).
	Offset: Fusion.Value<number>?,
	-- Set to the panel's height plus a gap while it shows (both devices): the world event panel stands under it.
	Height: Fusion.Value<number>?,
	Sfx: ((key: string) -> boolean)?,
	-- S149c: opens the world map centred on the barrow with its card (the compact line's tap)
	OpenMap: (() -> ())?,
}

local WIDTH_PC = 280
local WIDTH_TOUCH = 220
local PAD = 8
local GAP = 3
local TITLE = 24
local LINE = 20
local BAR = 16
local CHANNEL = 20
local REWARD = 30
local BUTTON_PC = 34
local BUTTON_TOUCH = 44
-- the anchors of Hud/WorldEventPanel (touch: under the portrait and the effect icons, below the party frames)
local TOUCH_TOP = Theme.Padding.Large + 136 + 6 + 44
local PARTY_TOP = Theme.Padding.Large + 136 + 70
local PARTY_ROW = 58 + 6
local PC_TOP = 400

-- The fold of the panel lives for the session (a remount keeps it).
local folded = false

local function WorldBossPanel(scope: Scope, props: Props): Instance
	local branch = State.Value({ "worldBoss" })
	local zoneMap = State.Value({ "zone", "map" })
	local party = State.Value({ "party" })
	local touch = Device.Touch
	local now = scope:Value(Clock.now())
	local inside = scope:Value(false)
	local collapsed = scope:Value(folded)
	local clock = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			clock += dt
			if clock < 0.25 then
				return
			end
			clock = 0
			now:set(Clock.now())
			-- whether the player stands in the fighters' circle ("Guide" hides there)
			local here = false
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local map = Maps.get(WorldBoss.Data.map)
			if root and map and Fusion.peek(zoneMap) == map.id then
				here =
					WorldBoss.inArena(WorldBoss.spot(), root.Position.X - map.offset.x, root.Position.Z - map.offset.z)
			end
			if here ~= Fusion.peek(inside) then
				inside:set(here)
			end
		end)
	)

	local mode = scope:Computed(function(use): string?
		return WorldBoss.panelOf(use(branch), use(zoneMap))
	end)
	local current = scope:Computed(function(use): any
		return if use(mode) ~= nil then use(branch) else nil
	end)
	local phase = scope:Computed(function(use): string
		local b = use(current)
		return if b then b.phase else ""
	end)
	local full = scope:Computed(function(use): boolean
		return use(mode) == "full" and not use(collapsed)
	end)
	local active = scope:Computed(function(use): boolean
		return use(full) and use(phase) == "active"
	end)
	local channel = scope:Computed(function(use): any
		local b = use(current)
		return if use(active) and b and type(b.channel) == "table" then b.channel else nil
	end)
	local standing = scope:Computed(function(use): boolean
		local p = use(phase)
		return use(full) and (p == "active" or p == "slain")
	end)
	local guideShown = scope:Computed(function(use): boolean
		local m = use(mode)
		if m == "line" then
			return true
		end
		local p = use(phase)
		return use(full) and (p == "warn" or p == "active") and not use(inside)
	end)
	local button = scope:Computed(function(use): number
		return if use(touch) then BUTTON_TOUCH else BUTTON_PC
	end)
	-- the header folds the panel, so on touch it is a full-size tap target
	local header = scope:Computed(function(use): number
		return if use(touch) then BUTTON_TOUCH else TITLE
	end)

	-- Sounds when the boss wakes and when it falls (only for players who see the panel).
	local lastKey = ""
	scope:Observer(branch):onBind(function()
		local b = Fusion.peek(branch)
		local key = if type(b) == "table" and type(b.phase) == "string" then `{b.id}|{b.phase}` else ""
		if key == lastKey then
			return
		end
		local was = lastKey
		lastKey = key
		local sfx = props.Sfx
		if not sfx or was == "" or Fusion.peek(mode) == nil or type(b) ~= "table" then
			return
		end
		if b.phase == "active" and was == `{b.id}|warn` then
			sfx("ui.worldboss.spawn")
		elseif b.phase == "slain" and was == `{b.id}|active` then
			sfx("ui.worldboss.victory")
		end
	end)

	local touchTop = scope:Computed(function(use): number
		local p = use(party)
		local others = 0
		if type(p) == "table" and type(p.members) == "table" then
			for _, member in p.members do
				if member.id ~= Players.LocalPlayer.UserId then
					others += 1
				end
			end
		end
		return if others > 0 then PARTY_TOP + others * PARTY_ROW else TOUCH_TOP
	end)
	local height = scope:Computed(function(use): number
		local rows = { use(header) }
		if use(full) then
			table.insert(rows, LINE)
			if use(active) then
				table.insert(rows, BAR)
				if use(channel) ~= nil then
					table.insert(rows, CHANNEL)
				end
			end
			if use(standing) then
				table.insert(rows, LINE)
				table.insert(rows, REWARD)
			end
		end
		if use(guideShown) then
			table.insert(rows, use(button))
		end
		local h = PAD * 2
		for i, row in rows do
			h += row + (if i > 1 then GAP else 0)
		end
		return h
	end)
	local shown = scope:Computed(function(use): boolean
		return use(current) ~= nil
	end)
	if props.Offset then
		local offset = props.Offset
		local pixels = scope:Computed(function(use): number
			return if use(shown) and not use(touch) then use(height) + 8 else 0
		end)
		scope:Observer(pixels):onBind(function()
			offset:set(Fusion.peek(pixels))
		end)
	end
	if props.Height then
		local out = props.Height
		local pixels = scope:Computed(function(use): number
			return if use(shown) then use(height) + 8 else 0
		end)
		scope:Observer(pixels):onBind(function()
			out:set(Fusion.peek(pixels))
		end)
	end

	local bossName = scope:Computed(function(use): string
		local b = use(current)
		return if b and type(b.nameKey) == "string" then Text.get(use, b.nameKey) else ""
	end)
	local hpPct = scope:Computed(function(use): number
		local b = use(current)
		if not b then
			return 0
		end
		if b.phase == "slain" then
			return 0
		end
		return math.floor(math.clamp(tonumber(b.hp) or 1, 0, 1) * 100 + 0.5)
	end)
	local title = scope:Computed(function(use): string
		local b = use(current)
		if not b then
			return ""
		end
		if use(mode) == "line" then
			local map = Maps.get(b.map)
			local key, seconds = WorldBoss.lineOf(b, use(now))
			return Text.get(use, key or "hud.worldboss.line", {
				boss = use(bossName),
				time = Time.format(seconds or 0),
				place = Text.get(use, WorldBoss.spot().nameKey),
				map = if map then Text.get(use, map.nameKey) else b.map,
			})
		end
		if use(collapsed) then
			return Text.get(use, "hud.worldboss.collapsed", { boss = use(bossName), pct = use(hpPct) })
		end
		return `♛ {use(bossName)}`
	end)
	local stateText = scope:Computed(function(use): string
		local b = use(current)
		if not b then
			return ""
		end
		local t = use(now)
		if b.phase == "warn" then
			return Text.get(use, "hud.event.startsIn", { time = Time.format(Time.remaining(b.startsAt or 0, t)) })
		elseif b.phase == "active" then
			local left = Text.get(use, "hud.event.timeLeft", { time = Time.format(Time.remaining(b.endsAt or 0, t)) })
			return `{Text.get(use, "boss.phase", { phase = b.bossPhase or 1 })} · {left}`
		elseif b.phase == "slain" then
			return Text.get(use, "worldboss.card.slain")
		end
		return Text.get(use, "worldboss.card.left")
	end)
	local mine = scope:Computed(function(use): any
		local b = use(current)
		return if b and type(b.mine) == "table" then b.mine else nil
	end)
	local shareText = scope:Computed(function(use): string
		local m = use(mine)
		local pct = if m then math.floor((tonumber(m.pct) or 0) * 1000 + 0.5) / 10 else 0
		return Text.get(use, "hud.worldboss.share", { pct = pct })
	end)
	local rewardOk = scope:Computed(function(use): boolean
		local m = use(mine)
		return m ~= nil and m.ok == true
	end)
	local rewardText = scope:Computed(function(use): string
		local m = use(mine)
		if m and m.ok == true then
			return Text.get(use, "hud.worldboss.rewardOk")
		end
		local reason = if m and type(m.reason) == "string" then m.reason else nil
		if reason then
			local b = use(current)
			return Text.get(use, `worldboss.noReward.{reason}`, { level = if b then b.minLevel else 0 })
		end
		return Text.get(use, "hud.event.mineNo")
	end)
	local stroke = Theme.tint(UiPalette.map.worldBoss)

	local function line(
		order: number,
		h: number,
		text: Fusion.UsedAs<string>,
		color: Fusion.UsedAs<Color3>,
		font: Font,
		visible: Fusion.UsedAs<boolean>
	): Instance
		return scope:New("TextLabel")({
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, h),
			Text = text,
			TextColor3 = color,
			TextSize = Theme.TextSize.Small,
			FontFace = font,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = h > LINE,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Visible = visible,
		})
	end

	return scope:New("Frame")({
		Name = "WorldBossPanel",
		AnchorPoint = scope:Computed(function(use): Vector2
			return if use(touch) then Vector2.new(0, 0) else Vector2.new(1, 0)
		end),
		Position = scope:Computed(function(use): UDim2
			if use(touch) then
				return UDim2.fromOffset(Theme.Padding.Large, use(touchTop))
			end
			return UDim2.new(1, -Theme.Padding.Large, 0, PC_TOP)
		end),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(if use(touch) then WIDTH_TOUCH else WIDTH_PC, use(height))
		end),
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Visible = shown,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = stroke, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, PAD),
				PaddingBottom = UDim.new(0, PAD),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
			-- the header: a tap folds / unfolds the full panel
			scope:New("TextButton")({
				Name = "Header",
				LayoutOrder = 1,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, use(header))
				end),
				Text = title,
				TextColor3 = Theme.Brass.Bright,
				TextSize = Theme.TextSize.Small,
				FontFace = Theme.Fonts.Display,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				[OnEvent("Activated")] = function()
					if Fusion.peek(mode) == "line" then
						-- S149c: the compact line opens the map at the barrow
						if props.OpenMap then
							props.OpenMap()
						end
						return
					end
					if Fusion.peek(mode) ~= "full" then
						return
					end
					folded = not Fusion.peek(collapsed)
					collapsed:set(folded)
				end,
			}),
			line(2, LINE, stateText, Theme.Iron.Text, Theme.Fonts.BodyMedium, full),
			scope:New("Frame")({
				Name = "HpRow",
				LayoutOrder = 3,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, BAR),
				Visible = active,
				[Children] = Bar(scope, {
					Name = "Hp",
					Surface = "iron",
					Value = hpPct,
					Max = 100,
					Color = Theme.Resource.Hp,
					Label = scope:Computed(function(use): string
						return `{use(hpPct)}%`
					end),
					ShowNumbers = false,
					Size = UDim2.fromScale(1, 1),
				}),
			}),
			ChannelBar(scope, {
				Name = "Channel",
				LayoutOrder = 4,
				Channel = channel,
				Now = now,
				Size = UDim2.new(1, 0, 0, CHANNEL),
			}),
			line(5, LINE, shareText, Theme.Iron.Text, Theme.Fonts.BodyBold, standing),
			line(
				6,
				REWARD,
				rewardText,
				scope:Computed(function(use): Color3
					return if use(rewardOk) then Theme.Iron.Success else Theme.Iron.TextMuted
				end),
				Theme.Fonts.Body,
				standing
			),
			Button(scope, {
				Surface = "iron",
				Name = "Guide",
				LayoutOrder = 7,
				Text = Text.T(scope, "hud.event.guide"),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				Visible = guideShown,
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, use(button))
				end),
				OnClick = function()
					local spot = WorldBoss.spot()
					props.Guide({ map = WorldBoss.Data.map, x = spot.x, z = spot.z, labelKey = spot.nameKey })
				end,
			}),
		},
	})
end

return WorldBossPanel
