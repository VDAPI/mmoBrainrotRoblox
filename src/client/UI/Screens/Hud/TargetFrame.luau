--!strict
-- Target frame at the top centre (DESIGN §23): name in the variant colour, level, elite badge, HP bar with
-- numbers (percentage for players) and distance. Polls the selected model ten times per second.
-- S157 (Logic/LevelLock): a monster over the player's level cap is greyed out with a lock and "Too high a level (max N)".
-- Owner 2026-11-10 ("things covering each other"; UI plan package A): on PC and a tablet the frame stands at the zone
-- map's target place, and while the dungeon's boss bar shows, an add or a player as the target stands under the bar
-- (Logic/HudZones `addFrame`; it lay under the bar); a phone's player menu is a 44 px "⋯" right of the frame
-- (Logic/PhoneHud `targetActions`; "Actions" under the cast bar reached into the M zone).
-- Final UI review 2026-11-10: a phone's effect icons stand in their own place (Logic/PhoneHud `targetEffects`, its
-- TARGET_ICONS), 4 px over the cast line (they reached 6 px into it); while the dungeon's boss strip stands at M's top
-- they go into the frame in place of the level line (they lay under the strip).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local EffectIcons = require(script.Parent.EffectIcons)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local LevelLock = require(ReplicatedStorage.Shared.Logic.LevelLock)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local PHONE_TARGET = assert(PhoneHud.place("target"))
local PHONE_ACTIONS = assert(PhoneHud.place("targetActions"))
local PHONE_EFFECTS = assert(PhoneHud.place("targetEffects"))
local ICONS = PhoneHud.TARGET_ICONS

local boss = State.Value({ "boss" }) -- DungeonController's boss bar (a phone: the strip at M's top)

export type Props = {
	Target: Fusion.Value<Model?>,
	-- Opens the player menu (S133: whisper, letter, trade, duel, party, guild, profile, friends, ignore, follow) for another
	-- player's character; the "Actions" button next to the frame makes it reachable by touch (S15; the "⋯" until S133).
	OnPlayerMenu: ((player: Player, at: Vector2) -> ())?,
}

type Info = {
	nameKey: string?, -- monsters: localization key
	name: string?, -- players: character name
	classKey: string?,
	variant: string,
	level: number,
	hp: number,
	maxHp: number,
	isPlayer: boolean,
	distance: number,
	cap: number?, -- S157: the highest level that may fight it (nil = no cap)
	locked: boolean, -- S157: the local player is over the cap
}

-- S136: the monster plate colours (Data/UiPalette.plate, >= 4.5:1 on the HUD tile)
local VARIANT_COLORS: { [string]: Color3 } = {
	normal = Theme.Plate.Normal,
	elite = Theme.Plate.Elite,
	elite2 = Theme.Plate.Elite2,
	boss = Theme.Plate.Boss,
}

local BADGES: { [string]: string } = { elite = "★", elite2 = "★★", boss = "♛" }

-- Attribute values are untyped; the server writes them, so read them as `any`.
local function attr(model: Model, name: string): any
	return model:GetAttribute(name)
end

local function read(model: Model): Info?
	if model.Parent == nil then
		return nil
	end
	local me = Players.LocalPlayer.Character
	local myRoot = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
	local distance = if myRoot then (model:GetPivot().Position - myRoot.Position).Magnitude else 0
	local monsterId = attr(model, "MonsterId")
	if type(monsterId) == "string" then
		local def = Monsters.get(monsterId)
		local variant = attr(model, "Variant") or "normal"
		local cap = attr(model, "CapLevel")
		local capped: number? = if type(cap) == "number" then cap else nil
		local myLevel = State.Get({ "character", "level" })
		return {
			nameKey = attr(model, "NameKey") or (if def then def.nameKeys[variant] or def.nameKeys.normal else nil),
			variant = variant,
			level = attr(model, "Level") or 1,
			hp = attr(model, "Hp") or 0,
			maxHp = attr(model, "MaxHp") or 1,
			isPlayer = false,
			distance = distance,
			cap = capped,
			locked = type(myLevel) == "number" and LevelLock.over(myLevel, capped),
		}
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local class = Classes.get(attr(model, "ClassId") or "")
	return {
		name = attr(model, "CharName") or model.Name,
		classKey = if class then class.nameKey else nil,
		variant = "normal",
		level = attr(model, "Level") or 1,
		hp = if humanoid then math.max(0, humanoid.Health) else 0,
		maxHp = 100,
		isPlayer = true,
		distance = distance,
		cap = nil,
		locked = false,
	}
end

local function TargetFrame(scope: Scope, props: Props): Instance
	local info = scope:Value(nil :: Info?)
	local elapsed = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed < 0.1 then
				return
			end
			elapsed = 0
			local model = Fusion.peek(props.Target)
			info:set(if model then read(model) else nil)
		end)
	)

	local hp = scope:Computed(function(use): number
		local i = use(info)
		return if i then i.hp else 0
	end)
	local maxHp = scope:Computed(function(use): number
		local i = use(info)
		return if i then i.maxHp else 1
	end)
	-- a phone under the dungeon's boss strip: the effect icons in the frame, in place of the level line
	local strip = scope:Computed(function(use): boolean
		return use(PhoneLayout.Compact) == true and type(use(boss)) == "table"
	end)

	return scope:New("Frame")({
		Name = "TargetFrame",
		-- W29: narrower, right of the portrait on a phone in landscape (Logic/PhoneHud)
		AnchorPoint = PhoneLayout.Anchor(scope, "target", Vector2.zero),
		Position = PhoneLayout.Position(
			scope,
			"target",
			scope:Computed(function(use): UDim2
				local zones = use(HudSlots.Zones)
				local rect = zones.addFrame or zones.target
				return if rect then UDim2.fromOffset(rect.left, rect.top) else UDim2.new()
			end)
		),
		Size = PhoneLayout.Size(scope, "target", UDim2.fromOffset(420, 92)),
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		-- A dungeon boss has its own bar at the top of the screen (DungeonController), so no second frame for it.
		Visible = scope:Computed(function(use): boolean
			local i = use(info)
			return i ~= nil and i.variant ~= "boss"
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("TextButton")({
				Name = "PlayerMenu",
				AnchorPoint = Vector2.new(0, 0),
				-- S133: a labelled "Actions" button (the bare "⋯" was not found by players); package A: a phone's 44 px
				-- "⋯" right of the frame (its place is measured from the frame's padded corner: 14 in, 8 down)
				Position = PhoneLayout.Pick(
					scope,
					UDim2.fromOffset(
						PHONE_ACTIONS.x - PHONE_TARGET.x - Theme.Padding.Medium,
						PHONE_ACTIONS.y - PHONE_TARGET.y - 8
					),
					UDim2.new(1, Theme.Padding.Medium + 8, 0, 0)
				),
				Size = PhoneLayout.Pick(
					scope,
					UDim2.fromOffset(PHONE_ACTIONS.w, PHONE_ACTIONS.h),
					UDim2.fromOffset(120, Theme.Size.MinTouch + 8)
				),
				-- S136: styled as a secondary iron button
				BackgroundColor3 = Theme.Iron.Raised,
				BackgroundTransparency = Theme.HudAlpha,
				Text = PhoneLayout.Pick(scope, "⋯", Text.T(scope, "social.actions")),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Iron.Text,
				Visible = scope:Computed(function(use): boolean
					local i = use(info)
					local model = use(props.Target)
					return props.OnPlayerMenu ~= nil
						and i ~= nil
						and i.isPlayer
						and model ~= nil
						and model ~= Players.LocalPlayer.Character
				end),
				[Fusion.OnEvent("Activated")] = function()
					local model = Fusion.peek(props.Target)
					local player = model and Players:GetPlayerFromCharacter(model)
					local open = props.OnPlayerMenu
					local camera = workspace.CurrentCamera
					if player and open and camera then
						-- The menu lives in an unscaled ScreenGui: open it just right of the frame.
						local size = camera.ViewportSize
						open(player, Vector2.new(size.X / 2 + size.X * 0.14, size.Y * 0.1))
					end
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
				},
			}),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = scope:Computed(function(use): Color3
					local i = use(info)
					return if i and i.variant ~= "normal" then VARIANT_COLORS[i.variant] else Theme.Brass.Line
				end),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, Theme.Padding.Medium),
				PaddingRight = UDim.new(0, Theme.Padding.Medium),
			}),
			scope:New("TextLabel")({
				Name = "Name",
				Size = UDim2.new(1, -70, 0, 28),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local i = use(info)
					if not i then
						return ""
					end
					local name = if i.nameKey then Text.get(use, i.nameKey) else (i.name or "?")
					local badge = BADGES[i.variant]
					local shown = if badge then `{badge} {name}` else name
					return if i.locked then `🔒 {shown}` else shown
				end),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = scope:Computed(function(use): Color3
					local i = use(info)
					if i and i.locked then
						return Theme.Iron.TextMuted -- S157: greyed out
					end
					return if i then VARIANT_COLORS[i.variant] or Theme.Iron.Text else Theme.Iron.Text
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Name = "Distance",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(70, 28),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local i = use(info)
					return if i then Text.get(use, "combat.distance", { distance = math.floor(i.distance) }) else ""
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			scope:New("TextLabel")({
				Name = "Level",
				Position = UDim2.fromOffset(0, ICONS.inside.y),
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(strip)
				end),
				Text = scope:Computed(function(use): string
					local i = use(info)
					if not i then
						return ""
					end
					local levelText = Text.get(use, "hud.level", { level = i.level })
					if i.classKey then
						return `{levelText} · {Text.get(use, i.classKey)}`
					end
					if i.locked and i.cap then
						return `{levelText} · {Text.get(use, "combat.overLevel", { max = i.cap })}`
					end
					if i.variant ~= "normal" then
						return `{levelText} · {Text.get(use, `variant.{i.variant}`)}`
					end
					return levelText
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					local i = use(info)
					return if i and i.locked then Theme.Iron.TextMuted else Theme.Iron.Text
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			-- PC and a tablet: under the frame
			EffectIcons(scope, {
				Model = props.Target,
				Position = UDim2.new(0, 0, 1, 10),
				Size = 26,
				Visible = scope:Computed(function(use): boolean
					return not use(PhoneLayout.Compact)
				end),
			}),
			-- a phone: in its own place (measured from the frame's padded corner, as the "⋯"), or in the frame
			EffectIcons(scope, {
				Model = props.Target,
				Position = UDim2.fromOffset(
					PHONE_EFFECTS.x - PHONE_TARGET.x - Theme.Padding.Medium,
					PHONE_EFFECTS.y - PHONE_TARGET.y - 8
				),
				Size = ICONS.size,
				Max = ICONS.max,
				Visible = scope:Computed(function(use): boolean
					return use(PhoneLayout.Compact) == true and not use(strip)
				end),
			}),
			EffectIcons(scope, {
				Model = props.Target,
				Position = UDim2.fromOffset(0, ICONS.inside.y),
				Size = ICONS.inside.size,
				Max = ICONS.inside.max,
				Caption = false,
				Visible = strip,
			}),
			Bar(scope, {
				Name = "Hp",
				Position = UDim2.fromOffset(0, 52),
				Size = UDim2.new(1, 0, 0, Theme.Size.BarHeight),
				Value = hp,
				Max = maxHp,
				Color = scope:Computed(function(use): Color3
					local i = use(info)
					return if i and i.locked then Theme.Iron.TextMuted else Theme.Resource.Hp
				end),
				ShowNumbers = false,
				Label = scope:Computed(function(use): string
					local i = use(info)
					if not i then
						return ""
					end
					if i.isPlayer then
						return `{math.ceil(i.hp)}%`
					end
					return `{math.ceil(i.hp)} / {i.maxHp}`
				end),
			}),
		},
	})
end

return TargetFrame
