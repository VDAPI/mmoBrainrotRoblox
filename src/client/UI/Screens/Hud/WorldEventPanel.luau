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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudDrag = require(script.Parent.Parent.Parent.HudDrag)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
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
local TITLE = 22
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
	local height = scope:Computed(function(use): number
		local button = if use(touch) then BUTTON_TOUCH else BUTTON_PC
		local h = PAD * 2 + TITLE + LINE + button + GAP * 2
		if use(active) then
			h += BAR + LINE + MINE + GAP * 3
		end
		return h
	end)
	local handle = HudDrag.new(scope, "worldEvent", function(use)
		return if use(touch) then WIDTH_TOUCH else WIDTH_PC
	end)
	-- owner 2026-10-21: the built-in place in the HUD column, round the moved elements (UI/HudSlots)
	local slot = HudSlots.join(
		scope,
		"worldEvent",
		scope:Computed(function(use): HudSlots.Box
			local w, h = if use(touch) then WIDTH_TOUCH else WIDTH_PC, use(height)
			return {
				shown = use(current) ~= nil,
				w = w,
				h = h,
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

	local title = scope:Computed(function(use): string
		local e = use(current)
		local def = use(kindDef)
		if not e or not def then
			return ""
		end
		local area = Areas.areaById(e.area)
		local where = if area then Text.get(use, area.nameKey) else e.area
		return `{def.glyph} {Text.get(use, def.nameKey)} · {where}`
	end)
	local timeText = scope:Computed(function(use): string
		local e = use(current)
		if not e then
			return ""
		end
		local t = use(now)
		if e.phase == "warn" then
			return Text.get(use, "hud.event.startsIn", { time = Time.format(e.startsAt - t) })
		end
		return Text.get(use, "hud.event.timeLeft", { time = Time.format(e.endsAt - t) })
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
			return Text.get(use, "hud.event.phase", {
				phase = e.stage or 0,
				phases = e.stages or 0,
				alive = e.alive or 0,
				kills = e.kills or 0,
			})
		end
		return ""
	end)
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
				PaddingTop = UDim.new(0, PAD),
				PaddingBottom = UDim.new(0, PAD),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
			line(1, TITLE, title, color, Theme.TextSize.Small, Theme.Fonts.BodyBold),
			line(2, LINE, timeText, Theme.Iron.Text, Theme.TextSize.Small, Theme.Fonts.BodyMedium),
			scope:New("Frame")({
				Name = "Bar",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, BAR),
				BackgroundColor3 = Theme.Resource.Track,
				BorderSizePixel = 0,
				Visible = active,
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
			line(4, LINE, progressText, Theme.Iron.Text, Theme.TextSize.Small, Theme.Fonts.Body, active),
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
				active
			),
			Button(scope, {
				Surface = "iron", -- S135: on a dark HUD / overlay surface
				Name = "Guide",
				LayoutOrder = 6,
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
			return UDim2.fromOffset(if use(touch) then WIDTH_TOUCH else WIDTH_PC, use(height))
		end),
		Visible = scope:Computed(function(use): boolean
			return use(current) ~= nil
		end),
		Content = body,
	})
end

return WorldEventPanel
