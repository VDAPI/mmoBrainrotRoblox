--!strict
-- World event panel (S101, docs/DESIGN-15.md §4): seen by the players on the event's map. The kind and the hunting
-- ground, the time to the start (warning) or to the end, the progress (S134d: the Invasion's phases with the live
-- monsters and the kills; then the commander's / champion's HP), the own contribution (counted for the reward or
-- not) and "Guide" (like ➤ of the quest tracker). PC: the right column over the quest tracker; touch: the left column
-- under the portrait and the effect icons, below the party frames when in a party (the right column holds the
-- minimap and the skill buttons). S149b: under the world boss panel when both show. Owner 2026-10-21: the column's
-- order and places come from UI/HudSlots (Logic/HudStack), round the elements the player moved.
-- Reads only the narrow branches `worldEvent` and `zone.map`; the clock ticks every 0.5 s like Elite2Timer.
-- Owner 2026-10-21 ("the invasion covers the map"): the PC place starts under the minimap with the quest tracker
-- (HudDrag.RIGHT_TOP), and the player moves the panel by its "≡" tab and scales it by "◢" (UI/HudDrag, HudLayout
-- `worldEvent`); a moved panel leaves the column, so the tracker stays where it is.
-- Owner 2026-11-10 (UI plan package A): the header is Hud/PanelHeader (the kind's glyph and name, the time left or to
-- the start); a click folds the panel to that line on the account (Section.state "hudWorldEvent", Data/Folds/Hud: open
-- on PC, folded on a phone), and the column folds it there too while it has no room (UI/HudSlots.forced).
-- Owner 2026-11-10 ("too much text"; UI plan package A, a HUD line at most 32 characters): the Invasion's line says
-- the phase ("Phase 2/6"), the bar under it the progress; the live monsters and the kills sit in the line's tooltip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudDrag = require(script.Parent.Parent.Parent.HudDrag)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local PanelHeader = require(script.Parent.PanelHeader)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local Section = require(script.Parent.Parent.Parent.Components.Section)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)
local WorldEvents = require(ReplicatedStorage.Shared.Logic.WorldEvents)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type GuideTarget = { map: string, x: number, z: number, labelKey: string }

export type Props = {
	Guide: (target: GuideTarget) -> (),
}

local WIDTH_PC = 280
local WIDTH_TOUCH = 220
local PAD = 8
local GAP = 3
local LINE = 20
local BAR = 8
local MINE = 30
local BUTTON_PC = 34
local BUTTON_TOUCH = 44

local function WorldEventPanel(scope: Scope, props: Props): Instance
	local event = State.Value({ "worldEvent" })
	local zoneMap = State.Value({ "zone", "map" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local clock = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			clock += dt
			if clock >= 0.5 then
				clock = 0
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)

	local current = scope:Computed(function(use): any
		local value = use(event)
		if type(value) ~= "table" or type(value.map) ~= "string" then
			return nil
		end
		return if use(zoneMap) == value.map then value else nil
	end)
	local active = scope:Computed(function(use): boolean
		local e = use(current)
		return e ~= nil and e.phase == "active"
	end)
	local kindDef = scope:Computed(function(use): WorldEvents.KindDef?
		local e = use(current)
		return if e then WorldEvents.kindOf(e.kind) else nil
	end)
	local color = scope:Computed(function(use): Color3
		local def = use(kindDef)
		return if def then Theme.readable(def.color, "hud") else Theme.Brass.Bright
	end)
	local touch = Device.Touch
	-- folded by the player (on the account) or by the column (no room)
	local open = Section.state(scope, "hudWorldEvent")
	local forced = HudSlots.forced(scope, "worldEvent")
	local folded = scope:Computed(function(use): boolean
		return not use(open) or use(forced)
	end)
	local unfolded = scope:Computed(function(use): boolean
		return not use(folded)
	end)
	local header = PanelHeader.Height(scope)
	-- The panel's height open, or `folded` to the header line. Package A review (owner 2026-11-10): the column hears
	-- the player's own fold only (`open`; it folds a box to its line itself, and a box built from its fold fed the
	-- column back: a Fusion loop that kept the panel out of the column or over the tracker); what is drawn folds with
	-- the column too (`folded`).
	local function heightOf(use: Fusion.Use, shut: boolean): number
		if shut then
			return use(header)
		end
		local button = if use(touch) then BUTTON_TOUCH else BUTTON_PC
		local h = use(header) + PAD + LINE + button + GAP * 2
		if use(active) then
			h += BAR + LINE + MINE + GAP * 3
		end
		return h
	end
	local height = scope:Computed(function(use): number
		return heightOf(use, use(folded))
	end)
	local activeOpen = scope:Computed(function(use): boolean
		return use(active) and not use(folded)
	end)
	-- package A review (owner 2026-11-10): on a phone a line of the stack, PhoneHud.PANEL_WIDTH wide, so it stands
	-- beside the stack's '+N' chip (wider, it went behind the chip)
	local function widthOf(use: Fusion.Use): number
		return if use(PhoneLayout.Compact) then PhoneHud.PANEL_WIDTH elseif use(touch) then WIDTH_TOUCH else WIDTH_PC
	end
	local handle = HudDrag.new(scope, "worldEvent", function(use)
		return widthOf(use)
	end, function(use)
		return heightOf(use, not use(open))
	end)
	-- owner 2026-10-21: the built-in place in the HUD column, round the moved elements (UI/HudSlots)
	local slot = HudSlots.join(
		scope,
		"worldEvent",
		scope:Computed(function(use): HudSlots.Box
			local w, h = widthOf(use), heightOf(use, not use(open))
			return {
				shown = use(current) ~= nil,
				w = w,
				h = h,
				line = use(header),
				custom = HudSlots.moved(use(handle.corner), w, h, use(handle.scale)),
			}
		end)
	)

	local function line(
		order: number,
		h: number,
		text: Fusion.UsedAs<string>,
		textColor: Fusion.UsedAs<Color3>,
		size: number,
		font: Font,
		visible: Fusion.UsedAs<boolean>?
	): Instance
		return scope:New("TextLabel")({
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, h),
			Text = text,
			TextColor3 = textColor,
			TextSize = size,
			FontFace = font,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = h > LINE,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Visible = visible,
		})
	end

	-- the header: the kind's glyph and name, and the time; the line under it: the hunting ground and the time in words
	local title = scope:Computed(function(use): string
		local def = use(kindDef)
		if not use(current) or not def then
			return ""
		end
		return `{def.glyph} {Text.get(use, def.nameKey)}`
	end)
	local value = scope:Computed(function(use): string
		local e = use(current)
		if not e then
			return ""
		end
		local t = use(now)
		return Time.format(math.max(0, (if e.phase == "warn" then e.startsAt else e.endsAt) - t))
	end)
	local timeText = scope:Computed(function(use): string
		local e = use(current)
		if not e then
			return ""
		end
		local area = Areas.areaById(e.area)
		local where = if area then Text.get(use, area.nameKey) else e.area
		local t = use(now)
		if e.phase == "warn" then
			return `{where} · {Text.get(use, "hud.event.startsIn", { time = Time.format(e.startsAt - t) })}`
		end
		return `{where} · {Text.get(use, "hud.event.timeLeft", { time = Time.format(e.endsAt - t) })}`
	end)
	local progress = scope:Computed(function(use): number
		local e = use(current)
		return if e then WorldEvents.progressOf(e, use(now)) else 0
	end)
	local progressText = scope:Computed(function(use): string
		local e = use(current)
		if not e or e.phase ~= "active" then
			return ""
		end
		if type(e.boss) == "string" then
			local pct = math.floor((tonumber(e.hp) or 1) * 100 + 0.5)
			return Text.get(use, "hud.event.boss", { name = Text.get(use, e.boss), pct = pct })
		end
		if e.kind == "invasion" then
			return Text.get(use, "hud.event.phase", { phase = e.stage or 0, total = e.stages or 0 })
		end
		return ""
	end)
	local progressLine =
		line(4, LINE, progressText, Theme.Iron.Text, Theme.TextSize.Small, Theme.Fonts.Body, activeOpen)
	Tooltip.attach(
		scope,
		progressLine :: GuiObject,
		scope:Computed(function(use): string
			local e = use(current)
			if e and e.kind == "invasion" and type(e.boss) ~= "string" then
				return Text.get(use, "hud.event.count", { left = e.alive or 0, kills = e.kills or 0 })
			end
			return use(progressText)
		end)
	)
	local mineOk = scope:Computed(function(use): boolean
		local e = use(current)
		return e ~= nil and type(e.mine) == "table" and e.mine.ok == true
	end)

	local body = scope:New("Frame")({
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = color, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingBottom = scope:Computed(function(use): UDim
					return UDim.new(0, if use(folded) then 0 else PAD)
				end),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
			PanelHeader.new(scope, {
				LayoutOrder = 1,
				Title = title,
				Value = value,
				Color = color,
				Open = unfolded,
				OnClick = function()
					if Fusion.peek(forced) then
						-- the column folded it: it stays open in the column before the others
						HudSlots.bring("worldEvent")
						Section.set("hudWorldEvent", true)
						return
					end
					Section.set("hudWorldEvent", not Fusion.peek(open))
				end,
			}),
			line(2, LINE, timeText, Theme.Iron.Text, Theme.TextSize.Small, Theme.Fonts.BodyMedium, unfolded),
			scope:New("Frame")({
				Name = "Bar",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, BAR),
				BackgroundColor3 = Theme.Resource.Track,
				BorderSizePixel = 0,
				Visible = activeOpen,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					-- W28: the brass edge of the resource bars (UI/Components/Bar)
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Theme.Brass.Line,
						Thickness = Theme.Stroke.Thin,
					}),
					scope:New("Frame")({
						Name = "Fill",
						BackgroundColor3 = color,
						BorderSizePixel = 0,
						Size = scope:Computed(function(use): UDim2
							return UDim2.fromScale(math.clamp(use(progress), 0, 1), 1)
						end),
						[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					}),
				},
			}),
			progressLine,
			line(
				5,
				MINE,
				scope:Computed(function(use): string
					return Text.get(use, if use(mineOk) then "hud.event.mineOk" else "hud.event.mineNo")
				end),
				scope:Computed(function(use): Color3
					return if use(mineOk) then Theme.Iron.Success else Theme.Iron.TextMuted
				end),
				Theme.TextSize.Small,
				Theme.Fonts.Body,
				activeOpen
			),
			Button(scope, {
				Surface = "iron", -- S135: on a dark HUD / overlay surface
				Name = "Guide",
				LayoutOrder = 6,
				Visible = unfolded,
				Text = Text.T(scope, "hud.event.guide"),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, if use(touch) then BUTTON_TOUCH else BUTTON_PC)
				end),
				OnClick = function()
					local e = Fusion.peek(current)
					local def = Fusion.peek(kindDef)
					if e and def then
						props.Guide({ map = e.map, x = e.x, z = e.z, labelKey = def.nameKey })
					end
				end,
			}),
		},
	})
	return HudDrag.frame(scope, handle, {
		Name = "WorldEventPanel",
		AnchorPoint = Vector2.zero,
		Position = HudSlots.position(scope, slot),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(widthOf(use), use(height))
		end),
		-- package A: not while it waits behind the column's '+N' chip
		Visible = HudSlots.visible(
			scope,
			slot,
			scope:Computed(function(use): boolean
				return use(current) ~= nil
			end),
			handle.corner
		),
		Content = body,
	})
end

return WorldEventPanel
