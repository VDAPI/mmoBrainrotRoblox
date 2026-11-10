--!strict
-- World boss panel (S149b, DESIGN §15.6): the HUD side of the world boss (state branch `worldBoss`, Logic/WorldBoss).
-- On the boss's map from the first warning to the end of the marker ("full", Logic/WorldBoss.panelOf): the boss's
-- name, the time to the start, then the HP bar, the phase and the time to its leave, the channel to break (the shared
-- Components/ChannelBar of the dungeon boss bar), the own share ("Share 12 %") and whether the reward is due (✓ or the
-- reason: level / share / claimed), "Guide" while outside the circle; after the fight "Slain" / "Gone" for the
-- marker's linger. On any other map from the first warning to the end of the fight (S149c): one line "{boss} in 7:42 ·
-- {place}", then "{boss} fights, 1:52:31 left · {place}" (Logic/WorldBoss.lineOf) with "Guide"; a tap on the line opens
-- the world map at the barrow with its card (props.OpenMap).
-- Owner 2026-11-10 (UI plan package A): the header is Hud/PanelHeader ("♛ boss", its HP or the time, "i" with the
-- place on other maps); a click folds the panel to that line on the account (Section.state "hudWorldBoss", Data/Folds/Hud:
-- open on PC, folded on a phone; it replaced the fold kept for the session), and the column folds it there too while it
-- has no room (UI/HudSlots.forced; a click then brings it back first). PC: the right column over the quest
-- tracker (the S101 world event panel stands under it: the boss comes first); touch: the left column under the
-- portrait like the world event panel (never over the skill buttons); owner 2026-10-21: the column's order and places
-- come from UI/HudSlots (Logic/HudStack), round the elements the player moved. Sounds: ui.worldboss.spawn when the boss
-- wakes, ui.worldboss.victory when it falls (silent until the owner picks ids). Iron surface (Data/UiWindows).
-- Owner 2026-11-10 ("too much text"; UI plan package A): the reward's reason is a short line ("Reward from level 30");
-- the whole "{boss} in 7:42 · {place}" sentence is the header's "i" (written in the header's props, so the text scan
-- holds it to the "i" and not to a HUD line).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local ChannelBar = require(script.Parent.Parent.Parent.Components.ChannelBar)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudDrag = require(script.Parent.Parent.Parent.HudDrag)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local PanelHeader = require(script.Parent.PanelHeader)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local Section = require(script.Parent.Parent.Parent.Components.Section)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)
local WorldBoss = require(ReplicatedStorage.Shared.Logic.WorldBoss)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type GuideTarget = { map: string, x: number, z: number, labelKey: string }

export type Props = {
	Guide: (target: GuideTarget) -> (),
	Sfx: ((key: string) -> boolean)?,
	-- S149c: opens the world map centred on the barrow with its card (the compact line's tap)
	OpenMap: (() -> ())?,
}

local WIDTH_PC = 280
local WIDTH_TOUCH = 220
local PAD = 8
local GAP = 3
local LINE = 20
local BAR = 16
local CHANNEL = 20
local REWARD = 30
local BUTTON_PC = 34
local BUTTON_TOUCH = 44

local function WorldBossPanel(scope: Scope, props: Props): Instance
	local branch = State.Value({ "worldBoss" })
	local zoneMap = State.Value({ "zone", "map" })
	local touch = Device.Touch
	local now = scope:Value(Clock.now())
	local inside = scope:Value(false)
	-- folded by the player (on the account) or by the column (no room)
	local open = Section.state(scope, "hudWorldBoss")
	local forced = HudSlots.forced(scope, "worldBoss")
	local collapsed = scope:Computed(function(use): boolean
		return not use(open) or use(forced)
	end)
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

	-- UI plan phase 2: the line on other maps only for a character that can get the reward (Logic/WorldBoss.panelOf)
	local level = State.Value({ "character", "level" })
	local mode = scope:Computed(function(use): string?
		local lv = use(level)
		return WorldBoss.panelOf(use(branch), use(zoneMap), if type(lv) == "number" then lv else nil)
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
	-- the channel to break while the boss fights; the panel shows it while open
	local channelOf = scope:Computed(function(use): any
		local b = use(current)
		return if b and b.phase == "active" and type(b.channel) == "table" then b.channel else nil
	end)
	local channel = scope:Computed(function(use): any
		return if use(active) then use(channelOf) else nil
	end)
	local standing = scope:Computed(function(use): boolean
		local p = use(phase)
		return use(full) and (p == "active" or p == "slain")
	end)
	-- the line on other maps is one header line: its click opens the map at the barrow (the guide is on its card)
	local guideShown = scope:Computed(function(use): boolean
		local m = use(mode)
		if m == "line" then
			return false
		end
		local p = use(phase)
		return use(full) and (p == "warn" or p == "active") and not use(inside)
	end)
	local button = scope:Computed(function(use): number
		return if use(touch) then BUTTON_TOUCH else BUTTON_PC
	end)
	-- the header folds the panel (one line of the column: Hud/PanelHeader's height)
	local header = PanelHeader.Height(scope)

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

	-- The panel's height with its rows open, or `folded` to the header line. Package A review (owner 2026-11-10,
	-- "things covering each other"): the column hears the player's own fold only (`open`); it folds a box to its line
	-- itself (Logic/HudStack), and a box built from its fold (`forced`) fed the column back: a Fusion loop that left the
	-- column with an old height, the panel over the tracker. What is drawn folds with the column too (`collapsed`).
	local function heightOf(use: Fusion.Use, folded: boolean): number
		local rows = { use(header) }
		local body = false
		local p = use(phase)
		if use(mode) == "full" and not folded then
			body = true
			table.insert(rows, LINE)
			if p == "active" then
				table.insert(rows, BAR)
				if use(channelOf) ~= nil then
					table.insert(rows, CHANNEL)
				end
			end
			if p == "active" or p == "slain" then
				table.insert(rows, LINE)
				table.insert(rows, REWARD)
			end
			-- "Guide" while outside the fighters' circle
			if (p == "warn" or p == "active") and not use(inside) then
				table.insert(rows, use(button))
			end
		end
		-- folded: the header line alone; open: the rows under it and PAD at the bottom
		local h = if body then PAD else 0
		for i, row in rows do
			h += row + (if i > 1 then GAP else 0)
		end
		return h
	end
	local height = scope:Computed(function(use): number
		return heightOf(use, use(collapsed))
	end)
	local shown = scope:Computed(function(use): boolean
		return use(current) ~= nil
	end)
	-- package A review (owner 2026-11-10): on a phone a line of the stack, PhoneHud.PANEL_WIDTH wide, so it stands
	-- beside the stack's '+N' chip (wider, it went behind the chip)
	local function widthOf(use: Fusion.Use): number
		return if use(PhoneLayout.Compact) then PhoneHud.PANEL_WIDTH elseif use(touch) then WIDTH_TOUCH else WIDTH_PC
	end
	-- owner 2026-10-21: moved by its tab, scaled by its corner (UI/HudDrag); a moved panel leaves the column
	local handle = HudDrag.new(scope, "worldBoss", function(use)
		return widthOf(use)
	end, function(use)
		return heightOf(use, not use(open))
	end)
	-- owner 2026-10-21: the built-in place in the HUD column, round the moved elements (UI/HudSlots)
	local slot = HudSlots.join(
		scope,
		"worldBoss",
		scope:Computed(function(use): HudSlots.Box
			local w, h = widthOf(use), heightOf(use, not use(open))
			return {
				shown = use(shown),
				w = w,
				h = h,
				line = use(header),
				custom = HudSlots.moved(use(handle.corner), w, h, use(handle.scale)),
			}
		end)
	)

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
	-- the header: "♛ boss" and one value (the HP while it fights, else the time to the start or to its leave); on other
	-- maps the whole line with the place goes behind the "i"
	local title = scope:Computed(function(use): string
		return `♛ {use(bossName)}`
	end)
	local value = scope:Computed(function(use): string
		local b = use(current)
		if not b then
			return ""
		end
		if use(mode) == "line" then
			local _, seconds = WorldBoss.lineOf(b, use(now))
			return Time.format(seconds or 0)
		end
		if b.phase == "active" then
			return `{use(hpPct)}%`
		elseif b.phase == "warn" then
			return Time.format(Time.remaining(b.startsAt or 0, use(now)))
		end
		return ""
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

	local body = scope:New("Frame")({
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = stroke, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingBottom = scope:Computed(function(use): UDim
					return UDim.new(0, if use(height) > use(header) then PAD else 0)
				end),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
			-- the header: a click folds / unfolds the full panel (the line on other maps opens the map)
			PanelHeader.new(scope, {
				LayoutOrder = 1,
				Title = title,
				Value = value,
				Open = scope:Computed(function(use): boolean
					return use(mode) == "full" and not use(collapsed)
				end),
				Info = scope:Computed(function(use): string
					local b = use(current)
					if not b or use(mode) ~= "line" then
						return ""
					end
					local map = Maps.get(b.map)
					local key, seconds = WorldBoss.lineOf(b, use(now))
					return Text.get(use, key or "hud.worldboss.line", {
						boss = use(bossName),
						time = Time.format(seconds or 0),
						place = Text.get(use, WorldBoss.spot().nameKey),
						map = if map then Text.get(use, map.nameKey) else b.map,
					})
				end),
				OnClick = function()
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
					if Fusion.peek(forced) then
						-- the column folded it: it stays open in the column before the others
						HudSlots.bring("worldBoss")
						Section.set("hudWorldBoss", true)
						return
					end
					Section.set("hudWorldBoss", not Fusion.peek(open))
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
	return HudDrag.frame(scope, handle, {
		Name = "WorldBossPanel",
		AnchorPoint = Vector2.zero,
		Position = HudSlots.position(scope, slot),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(widthOf(use), use(height))
		end),
		-- package A: not while it waits behind the column's '+N' chip
		Visible = HudSlots.visible(scope, slot, shown, handle.corner),
		Content = body,
	})
end

return WorldBossPanel
