--!strict
-- Target frame at the top centre (DESIGN §23): name in the variant colour, level, elite badge, HP bar with
-- numbers (percentage for players) and distance. Polls the selected model ten times per second.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bar = require(script.Parent.Parent.Parent.Components.Bar)
local EffectIcons = require(script.Parent.EffectIcons)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Target: Fusion.Value<Model?>,
	-- Opens the player actions (party, trade, duel, guild, profile) for another player's character; the "⋯"
	-- button next to the frame makes them reachable by touch (S15).
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
}

local VARIANT_COLORS: { [string]: Color3 } = {
	normal = Color3.fromHex("#E8E4DA"),
	elite = Color3.fromHex("#E05A4A"),
	elite2 = Color3.fromHex("#C77BFF"),
	boss = Color3.fromHex("#FF9F1C"),
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
		return {
			nameKey = attr(model, "NameKey") or (if def then def.nameKeys[variant] or def.nameKeys.normal else nil),
			variant = variant,
			level = attr(model, "Level") or 1,
			hp = attr(model, "Hp") or 0,
			maxHp = attr(model, "MaxHp") or 1,
			isPlayer = false,
			distance = distance,
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

	return scope:New("Frame")({
		Name = "TargetFrame",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Theme.Padding.Large),
		Size = UDim2.fromOffset(420, 92),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.12,
		-- A dungeon boss has its own bar at the top of the screen (DungeonController), so no second frame for it.
		Visible = scope:Computed(function(use): boolean
			local i = use(info)
			return i ~= nil and i.variant ~= "boss"
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("TextButton")({
				Name = "PlayerMenu",
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(1, Theme.Padding.Medium + 8, 0, -8),
				Size = UDim2.fromOffset(Theme.Size.MinTouch + 8, Theme.Size.MinTouch + 8),
				BackgroundColor3 = Theme.Colors.Panel,
				BackgroundTransparency = 0.12,
				Text = "⋯",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 30,
				TextColor3 = Theme.Colors.GoldBright,
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
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					scope:New("UIStroke")({ Color = Theme.Colors.GoldDim }),
				},
			}),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = scope:Computed(function(use): Color3
					local i = use(info)
					return if i and i.variant ~= "normal" then VARIANT_COLORS[i.variant] else Theme.Colors.GoldDim
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
					return if badge then `{badge} {name}` else name
				end),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = scope:Computed(function(use): Color3
					local i = use(info)
					return if i then VARIANT_COLORS[i.variant] or Theme.Colors.Text else Theme.Colors.Text
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
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			scope:New("TextLabel")({
				Name = "Level",
				Position = UDim2.fromOffset(0, 28),
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local i = use(info)
					if not i then
						return ""
					end
					local levelText = Text.get(use, "hud.level", { level = i.level })
					if i.classKey then
						return `{levelText} · {Text.get(use, i.classKey)}`
					end
					if i.variant ~= "normal" then
						return `{levelText} · {Text.get(use, `variant.{i.variant}`)}`
					end
					return levelText
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Parchment,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			EffectIcons(scope, {
				Model = props.Target,
				Position = UDim2.new(0, 0, 1, 10),
				Size = 26,
			}),
			Bar(scope, {
				Name = "Hp",
				Position = UDim2.fromOffset(0, 52),
				Size = UDim2.new(1, 0, 0, Theme.Size.BarHeight),
				Value = hp,
				Max = maxHp,
				Color = Theme.Colors.Hp,
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
