--!strict
-- In-game HUD skeleton (DESIGN §23): portrait with name/level and HP/Mana/Energy bars (top left), menu
-- buttons and map name (top right), skill + potion slots and the EXP bar (bottom).
-- Also hosts the zone banner, PvP toggle and death screen (sub-modules of this folder).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaBanner = require(script.AreaBanner)
local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local AttackButton = require(script.AttackButton)
local Bar = require(script.Parent.Parent.Components.Bar)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local DeathScreen = require(script.DeathScreen)
local Device = require(script.Parent.Parent.Device)
local Exp = require(ReplicatedStorage.Shared.Logic.Exp)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconButton = require(script.Parent.Parent.Components.IconButton)
local Keybinds = require(script.Parent.Parent.Keybinds)
local LoginButton = require(script.LoginButton)
local LowHpVignette = require(script.LowHpVignette) -- S134f
local LureButton = require(script.LureButton)
local AutoGrindButton = require(script.AutoGrindButton) -- S134d
local AutoPotionButton = require(script.AutoPotionButton) -- S134d
local LoginReward = require(ReplicatedStorage.Shared.Logic.LoginReward)
local PortraitFrame = require(script.Parent.Parent.Components.PortraitFrame)
local PotionBar = require(script.PotionBar)
local PvpDot = require(script.Parent.Parent.Components.PvpDot)
local PvpState = require(script.Parent.Parent.PvpState)
local SkillBar = require(script.SkillBar)
local SprintButton = require(script.SprintButton)
local BlessingBadge = require(script.BlessingBadge)
local BlessingIcon = require(script.BlessingIcon)
local Minimap = require(script.Minimap)
local MountButton = require(script.MountButton)
local NavBar = require(script.NavBar)
local CastBar = require(script.CastBar)
local EffectIcons = require(script.EffectIcons)
local EmoteButton = require(script.EmoteButton)
local MobileSkills = require(script.MobileSkills)
local PvpToggle = require(script.PvpToggle)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Components.Tooltip)
local TargetFrame = require(script.TargetFrame)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local ZoneBanner = require(script.ZoneBanner)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type MenuEntry = {
	id: string, -- window id
	icon: string,
	hotkey: string?, -- label shown on the button
	tooltipKey: string,
	badge: ((scope: Scope) -> Fusion.UsedAs<boolean>)?, -- S59: "!" on the button (skills window)
	visible: ((use: Fusion.Use) -> boolean)?, -- S97: the button shows only while this is true (nil: always)
}

export type Props = {
	Menu: { MenuEntry },
	OpenWindow: (id: string) -> (),
	ShowWindow: (id: string) -> (), -- S25: opens (never toggles) a window
	StopGuide: () -> (), -- S25: clears the guide target
	IsOpen: (id: string) -> Fusion.Value<boolean>,
	Target: Fusion.Value<Model?>,
	OnAttack: () -> (),
	Sprinting: Fusion.Value<boolean>,
	OnSprint: () -> (),
	-- S96: mounts (MountController): riding now, owns a mount, ride / dismount
	Riding: Fusion.UsedAs<any>,
	HasMount: Fusion.UsedAs<boolean>,
	OnMount: () -> (),
	-- S100: the login reward (LoginRewardController): today's streak status, a reward waits, open the window
	LoginStatus: Fusion.UsedAs<LoginReward.Status?>,
	LoginBadge: Fusion.UsedAs<boolean>,
	OpenLogin: () -> (),
	-- S123: the emote wheel (EmoteController.Toggle)
	OpenEmotes: () -> (),
	UsePotion: (kind: string) -> (),
	AssignPotion: (kind: string, itemId: string?) -> (),
	CastSlot: (slot: number) -> (),
	-- S28 touch aiming
	AimStart: ((slot: number) -> boolean)?,
	AimMove: ((slot: number, drag: Vector2) -> boolean)?,
	AimEnd: ((slot: number, cast: boolean) -> ())?,
	ClearSlot: (slot: number) -> (),
	SkillUsable: (skillId: string) -> (boolean, boolean, boolean),
	SkillColor: (skillId: string) -> Color3,
	SelectTarget: () -> (),
	OnPlayerMenu: ((player: Player, at: Vector2) -> ())?,
}

local SKILL_SLOTS = 10
local SLOT_SIZE = 56

local function number(scope: Scope, path: { string }): Fusion.Computed<number>
	local value = State.Value(path)
	return scope:Computed(function(use): number
		local v = use(value)
		return if type(v) == "number" then v else 0
	end)
end

local function portrait(scope: Scope): Instance
	local name = State.Value({ "character", "name" })
	local level = number(scope, { "character", "level" })
	local classId = State.Value({ "character", "class" })
	local class = scope:Computed(function(use): Classes.ClassDef?
		return Classes.get(use(classId) or "")
	end)

	return scope:New("Frame")({
		Name = "Portrait",
		Position = UDim2.fromOffset(Theme.Padding.Large, Theme.Padding.Large),
		Size = UDim2.fromOffset(400, 136),
		-- S136: an iron HUD tile with a 1 px brass edge
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Brass.Line,
			}),
			-- S123: the portrait frame cosmetic (UI/Components/PortraitFrame; the class stroke without one)
			PortraitFrame(scope, {
				Name = "Emblem",
				Position = UDim2.fromOffset(12, 12),
				Size = 84,
				FrameId = State.Value({ "account", "cosmetics", "equipped", "frame" }),
				ClassColor = scope:Computed(function(use): Color3
					local c = use(class)
					return if c then Theme.tint(c.color) else Theme.Brass.Bright
				end),
				-- S119: the class emblem (medallion) once loaded, the glyph otherwise.
				Content = ArtIcon(scope, {
					Key = scope:Computed(function(use): string?
						local c = use(class)
						return if c then UiArt.classEmblem(c.id) else nil
					end),
					Glyph = scope:Computed(function(use): string
						local c = use(class)
						return if c then c.icon else ""
					end),
					GlyphColor = scope:Computed(function(use): Color3
						local c = use(class)
						return if c then Theme.tint(c.color) else Theme.Brass.Bright
					end),
					ImageScale = 0.8,
					Size = UDim2.fromScale(1, 1),
					Label = { FontFace = Theme.Fonts.BodyBold, TextSize = Theme.TextSize.Hero },
				}),
			}),
			scope:New("TextLabel")({
				Name = "Level",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(54, 106),
				Size = UDim2.fromOffset(60, 24),
				BackgroundColor3 = Theme.Iron.Raised,
				Text = Text.T(scope, "hud.level", { level = level }),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				ZIndex = 2,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Theme.Brass.Line,
					}),
				},
			}),
			PvpDot(scope, {
				State = PvpState.indicator(scope),
				Position = UDim2.fromOffset(110, 22),
				Size = 14,
			}),
			-- Name row (S29): the name, then the active blessing's ✶ with its countdown.
			scope:New("Frame")({
				Name = "NameRow",
				Position = UDim2.fromOffset(130, 8),
				Size = UDim2.new(1, -142, 0, 28),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					scope:New("TextLabel")({
						Name = "CharName",
						LayoutOrder = 1,
						Size = UDim2.fromScale(0, 1),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return use(name) or ""
						end),
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Large,
						TextColor3 = Theme.Iron.Heading,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						[Children] = scope:New("UISizeConstraint")({ MaxSize = Vector2.new(170, 28) }),
					}),
					BlessingBadge.new(scope, 2),
				},
			}),
			scope:New("Frame")({
				Name = "Bars",
				Position = UDim2.fromOffset(110, 42),
				Size = UDim2.new(1, -122, 0, 3 * Theme.Size.BarHeight + 2 * 6),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					Bar(scope, {
						Name = "Hp",
						LayoutOrder = 1,
						Value = number(scope, { "character", "hp" }),
						Max = number(scope, { "derived", "values", "maxHp" }),
						Color = Theme.Resource.Hp,
						Label = Text.T(scope, "hud.hp"),
						ShowNumbers = true,
					}),
					Bar(scope, {
						Name = "Mana",
						LayoutOrder = 2,
						Value = number(scope, { "character", "mana" }),
						Max = number(scope, { "derived", "values", "maxMana" }),
						Color = Theme.Resource.Mana,
						Label = Text.T(scope, "hud.mana"),
						ShowNumbers = true,
					}),
					Bar(scope, {
						Name = "Energy",
						LayoutOrder = 3,
						Value = number(scope, { "character", "energy" }),
						Max = number(scope, { "derived", "values", "maxEnergy" }),
						Color = Theme.Resource.Energy,
						Label = Text.T(scope, "hud.energy"),
						ShowNumbers = true,
					}),
				},
			}),
		},
	})
end

local function menu(scope: Scope, props: Props): Instance
	local buttons = {}
	for index, entry in props.Menu do
		table.insert(
			buttons,
			IconButton(scope, {
				Name = entry.id,
				LayoutOrder = index,
				Icon = entry.icon,
				ArtKey = UiArt.menu(entry.id), -- S119
				Hotkey = if entry.hotkey then Keybinds.Label(scope, `win_{entry.id}`) else nil,
				Tooltip = Text.T(scope, entry.tooltipKey),
				-- FIX 2026-10-14: B's button stays lit for the backpack window itself (window id "character").
				Active = if entry.id == "inventory"
					then scope:Computed(function(use): boolean
						return use(props.IsOpen("inventory")) or use(props.IsOpen("character"))
					end)
					else props.IsOpen(entry.id),
				Badge = if entry.badge then entry.badge(scope) else nil,
				Visible = if entry.visible then scope:Computed(entry.visible) else nil,
				OnClick = function()
					props.OpenWindow(entry.id)
				end,
			})
		)
	end

	return scope:New("Frame")({
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Theme.Padding.Large, 0, Theme.Padding.Large),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			scope:New("Frame")({
				Name = "Buttons",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(0, Theme.Size.IconButton),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Padding.Small),
					}),
					buttons :: any,
				},
			}),
			Minimap(scope, { ShowWindow = props.ShowWindow }),
			NavBar(scope, { ShowWindow = props.ShowWindow, StopGuide = props.StopGuide }),
		},
	})
end

local function actionBar(scope: Scope, props: Props): Instance
	local slots: { Instance } = SkillBar(scope, {
		Cast = props.CastSlot,
		Clear = props.ClearSlot,
		Usable = props.SkillUsable,
		Color = props.SkillColor,
		SlotSize = SLOT_SIZE,
	})
	table.insert(
		slots,
		scope:New("Frame")({
			Name = "Gap",
			LayoutOrder = SKILL_SLOTS + 1,
			Size = UDim2.fromOffset(Theme.Padding.Large, SLOT_SIZE),
			BackgroundTransparency = 1,
		})
	)
	table.insert(
		slots,
		PotionBar(scope, {
			LayoutOrder = SKILL_SLOTS + 2,
			Use = props.UsePotion,
			Assign = props.AssignPotion,
		})
	)
	-- S96: the mount slot after the potions (PC only, once the character owns a mount)
	table.insert(
		slots,
		scope:New("Frame")({
			Name = "MountGap",
			LayoutOrder = SKILL_SLOTS + 3,
			Size = UDim2.fromOffset(Theme.Padding.Large, SLOT_SIZE),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return use(props.HasMount) == true and use(Device.Touch) ~= true
			end),
		})
	)
	table.insert(
		slots,
		MountButton.Slot(scope, {
			Riding = props.Riding,
			Has = props.HasMount,
			OnToggle = props.OnMount,
			LayoutOrder = SKILL_SLOTS + 4,
			SlotSize = SLOT_SIZE,
		})
	)
	-- S123: the emote wheel slot at the end (PC)
	table.insert(
		slots,
		EmoteButton.Slot(scope, { OnOpen = props.OpenEmotes, LayoutOrder = SKILL_SLOTS + 5, SlotSize = SLOT_SIZE })
	)

	return scope:New("Frame")({
		Name = "ActionBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(14 + Theme.Padding.Medium)),
		Size = UDim2.fromOffset(0, SLOT_SIZE),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			slots :: any,
		},
	})
end

local function expBar(scope: Scope): Instance
	local level = number(scope, { "character", "level" })
	local exp = number(scope, { "character", "exp" })
	local need = scope:Computed(function(use): number
		local l = use(level)
		return if l >= Config.MaxLevel then 0 else Exp.expToNext(math.max(1, l))
	end)
	local bar = Bar(scope, {
		Name = "Exp",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -8, 0, 16),
		Value = exp,
		Max = need,
		Color = Theme.Resource.Exp,
		ShowNumbers = false,
		Label = scope:Computed(function(use): string
			if use(level) >= Config.MaxLevel then
				return Text.get(use, "hud.expMax")
			end
			local pct = Exp.progress(use(level), use(exp), Config.MaxLevel) * 100
			return Text.get(use, "hud.expPct", { pct = string.format("%.1f", pct) })
		end),
	})
	Tooltip.attach(
		scope,
		bar :: GuiObject,
		scope:Computed(function(use): string
			return Text.get(use, "hud.expTooltip", {
				exp = Format.number(use(exp)),
				need = Format.number(use(need)),
			})
		end)
	)
	return bar
end

local function Hud(scope: Scope, props: Props): Instance
	local localPlayer = game:GetService("Players").LocalPlayer
	local myModel = scope:Value(localPlayer.Character)
	table.insert(
		scope,
		localPlayer.CharacterAdded:Connect(function(model)
			myModel:set(model)
		end)
	)
	return scope:New("Frame")({
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			LowHpVignette(scope), -- S134f: under every other HUD element
			portrait(scope),
			BlessingIcon(scope, UDim2.fromOffset(Theme.Padding.Large + 400 + 12, Theme.Padding.Large + 4)),
			-- S100: right of the portrait, aligned to its bottom (the elixirs end at ~90, the effect icons start at 164)
			LoginButton(scope, {
				Status = props.LoginStatus,
				Badge = props.LoginBadge,
				Open = props.OpenLogin,
				Position = UDim2.fromOffset(Theme.Padding.Large + 400 + 12, Theme.Padding.Large + 136 - 44),
			}),
			-- S122: the Cloak of Luring right of the login button, below the elixirs (only while it has time)
			LureButton(
				scope,
				UDim2.fromOffset(Theme.Padding.Large + 400 + 12 + 44 + 8, Theme.Padding.Large + 136 - 64)
			),
			-- S134d: Auto Hunt and Auto Potions right of the cloak (each only while the account has it)
			AutoGrindButton(
				scope,
				UDim2.fromOffset(Theme.Padding.Large + 400 + 12 + 44 + 8 + 56, Theme.Padding.Large + 136 - 64)
			),
			AutoPotionButton(
				scope,
				UDim2.fromOffset(Theme.Padding.Large + 400 + 12 + 44 + 8 + 112, Theme.Padding.Large + 136 - 64)
			),
			CastBar(scope),
			EffectIcons(scope, {
				Model = myModel,
				Position = UDim2.fromOffset(Theme.Padding.Large, Theme.Padding.Large + 136 + 6),
			}),
			MobileSkills(scope, {
				Cast = props.CastSlot,
				Color = props.SkillColor,
				SelectTarget = props.SelectTarget,
				AimStart = props.AimStart,
				AimMove = props.AimMove,
				AimEnd = props.AimEnd,
			}),
			menu(scope, props),
			actionBar(scope, props),
			expBar(scope),
			TargetFrame(scope, { Target = props.Target, OnPlayerMenu = props.OnPlayerMenu }),
			ZoneBanner(scope),
			AreaBanner(scope),
			AttackButton(scope, { OnAttack = props.OnAttack }),
			SprintButton(scope, { Sprinting = props.Sprinting, OnToggle = props.OnSprint, Riding = props.Riding }),
			MountButton.Touch(scope, { Riding = props.Riding, Has = props.HasMount, OnToggle = props.OnMount }),
			EmoteButton.Touch(scope, { OnOpen = props.OpenEmotes }),
			PvpToggle(scope),
			DeathScreen(scope),
		},
	})
end

return Hud
