--!strict
-- S133: the player menu (actions on another player). Header: PvP dot, character name with the guild tag, level and
-- class. Below: the entries of Logic/Social.menuEntries in their fixed order; an entry unavailable right now stays,
-- greyed out, with one line saying why. On a PC it opens at the mouse (kept inside the screen); on a touch screen it is
-- a bottom sheet with large buttons. Lives in an unscaled ScreenGui (PartyController), so pixels are screen pixels.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PvpDot = require(script.Parent.Parent.Components.PvpDot)
local PvpRules = require(ReplicatedStorage.Shared.Logic.PvpRules)
local Social = require(ReplicatedStorage.Shared.Logic.Social)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Target: Fusion.Value<Player?>,
	At: Fusion.UsedAs<Vector2>,
	Touch: Fusion.UsedAs<boolean>,
	-- What the local player knows about the target right now (Logic/Social.MenuContext).
	Context: (use: Fusion.Use, target: Player) -> Social.MenuContext,
	OnAction: (id: string, target: Player) -> (),
}

local PC_WIDTH = 260
local SHEET_MAX_WIDTH = 520
local ROW_PC = 38
local ROW_TOUCH = Theme.Size.MinTouch + 6

local function escape(text: string): string
	return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

-- Character name, guild tag, level, class and PvP state from the target's character attributes.
type Head = { name: string, tag: string?, level: number?, class: string?, pvp: string }

local function headOf(target: Player): Head
	local model = target.Character
	local function attr(name: string): any
		return if model then model:GetAttribute(name) else nil
	end
	local charName = attr("CharName")
	local tag = attr("GuildTag")
	local zone = attr("PvpZone")
	return {
		name = if type(charName) == "string" then charName else target.DisplayName,
		tag = if type(tag) == "string" and tag ~= "" then tag else nil,
		level = attr("Level"),
		class = attr("ClassId"),
		pvp = PvpRules.indicator(
			attr("PvpEnabled") == true,
			if type(zone) == "string" then zone :: any else nil,
			nil,
			nil,
			0
		),
	}
end

local function PlayerMenu(scope: Scope, props: Props): Instance
	-- Re-read the attributes a few times a second while the menu is open (they replicate with the character).
	local tick = scope:Value(0)
	local elapsed = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed >= 0.5 and Fusion.peek(props.Target) ~= nil then
				elapsed = 0
				tick:set(Fusion.peek(tick) + 1)
			end
		end)
	)

	local head = scope:Computed(function(use): Head?
		use(tick)
		local target = use(props.Target)
		return if target then headOf(target) else nil
	end)

	local entries = scope:Computed(function(use): { Social.MenuEntry }
		local target = use(props.Target)
		return if target then Social.menuEntries(props.Context(use, target)) else {}
	end)

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local touch = use(props.Touch)
		local height = if touch then ROW_TOUCH else ROW_PC
		local out = {}
		for i, e in use(entries) do
			local children: { Instance } = {
				s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
				Button(s, {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, height),
					TextSize = if touch then Theme.TextSize.Body else Theme.TextSize.Small,
					Variant = if e.id == "ignore" and e.labelKey == "social.menu.ignore" then "danger" else "secondary",
					Text = Text.T(s, e.labelKey),
					Disabled = not e.enabled,
					OnClick = function()
						local target = Fusion.peek(props.Target)
						props.Target:set(nil)
						if target and target.Parent == Players then
							props.OnAction(e.id, target)
						end
					end,
				}),
			}
			if e.reasonKey then
				table.insert(
					children,
					s:New("TextLabel")({
						LayoutOrder = 2,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						TextWrapped = true,
						Text = Text.T(s, e.reasonKey),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
					})
				)
			end
			table.insert(
				out,
				s:New("Frame")({
					Name = e.id,
					LayoutOrder = i,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = children,
				})
			)
		end
		return out
	end)

	local width = scope:Computed(function(use): number
		use(props.Target)
		if use(props.Touch) then
			return math.min(SHEET_MAX_WIDTH, viewport().X - 32)
		end
		return PC_WIDTH
	end)

	return scope:New("Frame")({
		Name = "PlayerMenu",
		AnchorPoint = scope:Computed(function(use): Vector2
			return if use(props.Touch) then Vector2.new(0.5, 1) else Vector2.zero
		end),
		Position = scope:Computed(function(use): UDim2
			if use(props.Touch) then
				return UDim2.new(0.5, 0, 1, -12)
			end
			local at = use(props.At)
			local size = viewport()
			local rowsHeight = #use(entries) * (ROW_PC + 6) + 80
			local x = math.clamp(at.X, 8, math.max(8, size.X - PC_WIDTH - 8))
			local y = math.clamp(at.Y, 8, math.max(8, size.Y - rowsHeight - 8))
			return UDim2.fromOffset(x, y)
		end),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(use(width), 0)
		end),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = scope:Computed(function(use): boolean
			return use(props.Target) ~= nil
		end),
		ZIndex = 20,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 1.5 }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			scope:New("Frame")({
				Name = "Header",
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundTransparency = 1,
				[Children] = {
					PvpDot(scope, {
						State = scope:Computed(function(use): string
							local h = use(head)
							return if h then h.pvp else "off"
						end),
						Position = UDim2.fromOffset(0, 13),
						Size = 14,
						Tooltip = false,
					}) :: Instance,
					scope:New("TextLabel")({
						Name = "Name",
						Position = UDim2.fromOffset(22, 0),
						Size = UDim2.new(1, -22, 0, 26),
						BackgroundTransparency = 1,
						RichText = true,
						Text = scope:Computed(function(use): string
							local h = use(head)
							if not h then
								return ""
							end
							local name = escape(h.name)
							if h.tag then
								return `<font color="#{Theme.Colors.Gold:ToHex()}">[{escape(h.tag)}]</font> {name}`
							end
							return name
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Colors.GoldBright,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					scope:New("TextLabel")({
						Name = "Level",
						Position = UDim2.fromOffset(22, 26),
						Size = UDim2.new(1, -22, 0, 22),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local h = use(head)
							if not h then
								return ""
							end
							local parts = {}
							if type(h.level) == "number" then
								table.insert(parts, Text.get(use, "hud.level", { level = h.level }))
							end
							local class = if type(h.class) == "string" then Classes.get(h.class) else nil
							if class then
								table.insert(parts, Text.get(use, class.nameKey))
							end
							return table.concat(parts, " · ")
						end),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.Parchment,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				} :: any,
			}),
			scope:New("ScrollingFrame")({
				Name = "Entries",
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UISizeConstraint")({
						MaxSize = scope:Computed(function(use): Vector2
							use(props.Target)
							return Vector2.new(math.huge, math.max(200, viewport().Y * 0.6))
						end),
					}),
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
					rows :: any,
				},
			}),
		},
	})
end

return PlayerMenu
