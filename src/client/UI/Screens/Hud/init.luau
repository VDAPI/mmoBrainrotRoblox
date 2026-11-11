--!strict
-- In-game HUD skeleton (DESIGN §23): portrait with name/level and HP/Mana/Energy bars (top left), menu
-- buttons and map name (top right), skill + potion slots and the EXP bar (bottom).
-- Also hosts the zone banner, PvP toggle and death screen (sub-modules of this folder).
-- UI plan phase 1 (owner 2026-10-31, "too much information and too many options on one screen"): the menu is one row
-- of six buttons (Logic/HudMenu.BAR; the other windows are tiles of the game menu), the login reward and the season
-- pass show only while a reward waits, the achievements button and the emote slot left the HUD (N, T and the menu's
-- tiles open them).
-- UI plan phase 2: "something waits" in one row under the minimap (Hud/WaitingRow), the buffs in one row under the
-- portrait (the blessing, the elixirs and the effects), the cloak and the auto services behind one "Auto" button
-- (Hud/AutoGroup), the dot on the portrait is the PvP switch on PC, the menu bar, the tracker and the minimap's labels
-- step out of sight under an open window (UI/HudCover) and the EXP bar shows its percentage on hover only.
-- Owner 2026-11-10 ("too much text, things covering each other, nothing folds"; UI plan package A): on PC and a
-- tablet the portrait, the effects row, the menu, the cast line, the action bar and the EXP bar stand at the places of
-- the zone map (Logic/HudZones through UI/HudSlots.Zones; no offsets of their own here), the column's '+N' chip
-- (Hud/StackChip) lists what the column has no room for; a phone has one grid (Logic/PhoneHud): the Auto button and
-- the blessing, elixirs and effects in one row under the portrait, the drawer opening left of its button (never over
-- the PvP toggle).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AreaBanner = require(script.AreaBanner)
local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local AutoGroup = require(script.AutoGroup)
local AttackButton = require(script.AttackButton)
local Bar = require(script.Parent.Parent.Components.Bar)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local DeathScreen = require(script.DeathScreen)
local PremiumShop = require(script.Parent.PremiumShop)
local Device = require(script.Parent.Parent.Device)
local Exp = require(ReplicatedStorage.Shared.Logic.Exp)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudCover = require(script.Parent.Parent.HudCover)
local HudSlots = require(script.Parent.Parent.HudSlots)
local IconButton = require(script.Parent.Parent.Components.IconButton)
local Keybinds = require(script.Parent.Parent.Keybinds)
local LoginButton = require(script.LoginButton)
local LowHp = require(ReplicatedStorage.Shared.Logic.LowHp)
local LowHpVignette = require(script.LowHpVignette) -- S134f
local MailButton = require(script.MailButton) -- owner 2026-10-21
local LoginReward = require(ReplicatedStorage.Shared.Logic.LoginReward)
local PortraitFrame = require(script.Parent.Parent.Components.PortraitFrame)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local HudZones = require(ReplicatedStorage.Shared.Logic.HudZones)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local Scale = require(script.Parent.Parent.Scale)
local PotionBar = require(script.PotionBar)
local PotionPress = require(ReplicatedStorage.Shared.Logic.PotionPress)
local PvpDot = require(script.Parent.Parent.Components.PvpDot)
local PvpState = require(script.Parent.Parent.PvpState)
local PvpSwitch = require(script.Parent.Parent.PvpSwitch)
local SkillBar = require(script.SkillBar)
local SprintButton = require(script.SprintButton)
local BlessingBadge = require(script.BlessingBadge)
local BlessingIcon = require(script.BlessingIcon)
local Minimap = require(script.Minimap)
local MountButton = require(script.MountButton)
local NavBar = require(script.NavBar)
local CastBar = require(script.CastBar)
local ChatDock = require(script.ChatDock)
local EffectIcons = require(script.EffectIcons)
local MobileSkills = require(script.MobileSkills)
local PoolLabel = require(script.PoolLabel)
local PvpToggle = require(script.PvpToggle)
local SeasonButton = require(script.SeasonButton) -- S152b
local StackChip = require(script.StackChip) -- UI plan package A
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Components.Tooltip)
local TargetFrame = require(script.TargetFrame)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local WaitingRow = require(script.WaitingRow)
local ZoneBanner = require(script.ZoneBanner)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

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
	SkillCost: ((skillId: string) -> (number, string?))?, -- owner 2026-10-21: the cost badge of a slot
	SelectTarget: () -> (),
	OnPlayerMenu: ((player: Player, at: Vector2) -> ())?,
}

local SKILL_SLOTS = 10
local SLOT_SIZE = 56
local EFFECT_ICON = 30 -- UI plan phase 2: the effects row's icons (Hud/EffectIcons' default), the elixirs too
-- package A: a phone's effects row (220 wide after the Auto button) holds the blessing, the elixirs and this many
-- effect icons before '+N'
local EFFECTS_PHONE = 3
-- UI plan phase 4: the portrait is 340 x 110 (Logic/HudStack.PORTRAIT; it was 400 x 136): the emblem (68) with the
-- level on its lower edge, the PvP dot and the name in the top row, the three bars (20 tall, 4 apart) under the name.
local PORTRAIT = HudStack.PORTRAIT
local P = table.freeze({
	pad = 10,
	emblem = 68,
	level = { x = 44, y = 88, w = 56, h = 22 },
	dot = { x = 96, y = 18 },
	name = { x = 114, y = 4, h = 28 },
	bars = { x = 88, y = 36, h = 20, gap = 4 },
})

local function number(scope: Scope, path: { string }): Fusion.Computed<number>
	local value = State.Value(path)
	return scope:Computed(function(use): number
		local v = use(value)
		return if type(v) == "number" then v else 0
	end)
end

-- W28: the HP bar breathes on low health, on and off with the red vignette (Logic/LowHp, the same hysteresis and
-- the same setting `lowHpWarn`)
local function lowHpPulse(
	scope: Scope,
	hp: Fusion.Computed<number>,
	maxHp: Fusion.Computed<number>
): Fusion.Computed<boolean>
	local on = scope:Value(false)
	local function update()
		on:set((LowHp.state(Fusion.peek(hp), Fusion.peek(maxHp), Fusion.peek(on), Config.LowHp)))
	end
	update()
	scope:Observer(hp):onChange(update)
	scope:Observer(maxHp):onChange(update)
	local enabled = State.Value({ "account", "settings", "lowHpWarn" })
	return scope:Computed(function(use): boolean
		return use(on) and use(enabled) ~= false
	end)
end

-- UI plan phase 2 (plan §3 #2): the PvP dot on the portrait is the switch (a click in a yellow zone; UI/PvpSwitch, the
-- same request as the touch screens' toggle). Owner 2026-11-10 ("too much text"; UI plan package A): its tooltip is one
-- line, the state or the countdown ("Switching PvP: 7 s"); the zone's rules and, in a yellow zone, that the dot is the
-- switch are its details (the details key or a longer press). Package A review: a touch held for that tooltip
-- (Logic/PotionPress.TIP_HOLD) was reading it, so its release does not start a switch.
local function pvpSwitch(scope: Scope): Instance
	local state = PvpState.indicator(scope)
	local zone = State.Value({ "zone" })
	local pvp = State.Value({ "pvp" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local accumulator = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			accumulator += dt
			if accumulator >= 0.25 and Fusion.peek(state) == "switching" then
				accumulator = 0
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)
	local zoneType = scope:Computed(function(use): string
		local z = use(zone)
		return if type(z) == "table" and type(z.pvp) == "string" then z.pvp else "green"
	end)
	local pressedAt: number? = nil
	local button = scope:New("TextButton")({
		Name = "PvpSwitch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(P.dot.x, P.dot.y),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 2,
		[OnEvent("InputBegan")] = function(input: InputObject)
			pressedAt = if input.UserInputType == Enum.UserInputType.Touch then os.clock() else nil
		end,
		[OnEvent("Activated")] = function()
			local heldFor = if pressedAt then os.clock() - pressedAt else 0
			pressedAt = nil
			if Fusion.peek(zoneType) == "yellow" and heldFor < PotionPress.TIP_HOLD then
				PvpSwitch.request()
			end
		end,
		[Children] = PvpDot(scope, {
			State = state,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = 14,
			Tooltip = false,
		}),
	})
	Tooltip.attach(
		scope,
		button :: GuiObject,
		scope:Computed(function(use): string
			local p = use(pvp)
			if type(p) == "table" and type(p.switchAt) == "number" and p.pendingTarget ~= nil then
				local left = math.ceil(math.max(0, p.switchAt - use(now)))
				return Text.get(use, "pvp.dot.switchingIn", { seconds = left })
			end
			return Text.get(use, `pvp.dot.{use(state)}`)
		end),
		scope:Computed(function(use): string
			local z = use(zoneType)
			if z == "yellow" then
				return `{Text.get(use, "pvp.rules.yellow")}\n{Text.get(use, "pvp.dot.toggle")}`
			end
			return Text.get(use, `pvp.rules.{z}`)
		end)
	)
	return button
end

local function portrait(scope: Scope): Instance
	local name = State.Value({ "character", "name" })
	local hp = number(scope, { "character", "hp" })
	local maxHp = number(scope, { "derived", "values", "maxHp" })
	local level = number(scope, { "character", "level" })
	local classId = State.Value({ "character", "class" })
	local class = scope:Computed(function(use): Classes.ClassDef?
		return Classes.get(use(classId) or "")
	end)

	return scope:New("Frame")({
		Name = "Portrait",
		-- W29: scaled down in the corner on a phone in landscape (Logic/PhoneHud)
		Position = PhoneLayout.Position(scope, "portrait", HudSlots.at(scope, "portrait")),
		Size = UDim2.fromOffset(PORTRAIT.w, PORTRAIT.h),
		-- S136: an iron HUD tile with a 1 px brass edge
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		[Children] = {
			PhoneLayout.UIScale(scope, "portrait"),
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Brass.Line,
			}),
			-- S123: the portrait frame cosmetic (UI/Components/PortraitFrame; the class stroke without one)
			PortraitFrame(scope, {
				Name = "Emblem",
				Position = UDim2.fromOffset(P.pad, P.pad),
				Size = P.emblem,
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
				Position = UDim2.fromOffset(P.level.x, P.level.y),
				Size = UDim2.fromOffset(P.level.w, P.level.h),
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
			pvpSwitch(scope),
			-- Name row (S29): the name, then the active blessing's ✶ with its countdown.
			scope:New("Frame")({
				Name = "NameRow",
				Position = UDim2.fromOffset(P.name.x, P.name.y),
				Size = UDim2.new(1, -P.name.x - P.pad, 0, P.name.h),
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
					-- UI plan package A: a phone too shows the blessing first in the effects row (no slot by the name)
				},
			}),
			scope:New("Frame")({
				Name = "Bars",
				Position = UDim2.fromOffset(P.bars.x, P.bars.y),
				Size = UDim2.new(1, -P.bars.x - P.pad, 0, 3 * P.bars.h + 2 * P.bars.gap),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, P.bars.gap),
					}),
					Bar(scope, {
						Name = "Hp",
						Size = UDim2.new(1, 0, 0, P.bars.h),
						LayoutOrder = 1,
						Value = hp,
						Max = maxHp,
						Color = Theme.Resource.Hp,
						Label = Text.T(scope, "hud.hp"),
						ShowNumbers = true,
						Ghost = true, -- W28
						Pulse = lowHpPulse(scope, hp, maxHp),
					}),
					Bar(scope, {
						Name = "Mana",
						Size = UDim2.new(1, 0, 0, P.bars.h),
						LayoutOrder = 2,
						Value = number(scope, { "character", "mana" }),
						Max = number(scope, { "derived", "values", "maxMana" }),
						Color = Theme.Resource.Mana,
						Label = Text.T(scope, "hud.mana"),
						ShowNumbers = true,
					}),
					Bar(scope, {
						Name = "Energy",
						Size = UDim2.new(1, 0, 0, P.bars.h),
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

-- The menu's buttons (one set in the menu over the minimap, W29: another in the phone drawer; `after` runs after a
-- click: the drawer closes).
local function menuButtons(scope: Scope, props: Props, after: (() -> ())?): { Instance }
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
					if after then
						after()
					end
				end,
			})
		)
	end
	return buttons
end

local function menu(scope: Scope, props: Props): Instance
	local buttons = menuButtons(scope, props)
	-- UI plan phase 2: the buttons step out of sight under an open window (UI/HudCover); their frame keeps its height,
	-- so the minimap under it never moves
	local row = scope:New("Frame")({
		Name = "Row",
		Size = UDim2.fromOffset(0, Theme.Size.IconButton),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			buttons :: any,
		},
	}) :: Frame
	local covered = HudCover.covered(scope, row)
	scope:Observer(covered):onBind(function()
		row.Visible = not Fusion.peek(covered)
	end)
	local root = scope:New("Frame")({
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0),
		-- W29: on a phone in landscape only the scaled minimap and the guide bar (the buttons are in the drawer)
		Position = PhoneLayout.Position(scope, "minimap", HudSlots.point(scope, "menuBar", 1, 0)),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			-- owner 2026-10-20: one long row of 14 reached the middle of the screen and covered the target's / boss's
			-- health bar, so two rows; UI plan phase 1: six buttons (Logic/HudMenu.BAR) in one row right-aligned over the
			-- minimap (Logic/HudStack.RIGHT_TOP counts one row)
			scope:New("Frame")({
				Name = "Buttons",
				LayoutOrder = 1,
				Visible = PhoneLayout.Pick(scope, false, true),
				Size = UDim2.fromOffset(0, Theme.Size.IconButton),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
					}),
					row,
				},
			}),
			Minimap(scope, { ShowWindow = props.ShowWindow }),
			NavBar(scope, { ShowWindow = props.ShowWindow, StopGuide = props.StopGuide }),
			-- UI plan phase 2: "something waits" under the minimap (and the guide bar)
			WaitingRow(scope, {
				LayoutOrder = 4,
				LoginStatus = props.LoginStatus,
				LoginBadge = props.LoginBadge,
				OpenLogin = props.OpenLogin,
				OpenWindow = props.OpenWindow,
				ShowWindow = props.ShowWindow,
				Covered = covered,
			}),
		},
	}) :: Frame
	-- Studio check 2026-10-31: the PC column starts under the menu's real bottom edge (UI/HudSlots.MenuBottom)
	HudSlots.SetMenu(scope, root)
	return root
end

local function actionBar(scope: Scope, props: Props): Instance
	-- W29: on a phone in landscape the skill arc (MobileSkills) holds the same slots: only the potions stay
	local onBar = PhoneLayout.Pick(scope, false, true)
	local slots: { Instance } = {
		scope:New("Frame")({
			Name = "Skills",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(0, SLOT_SIZE),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Visible = onBar,
			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				SkillBar(scope, {
					Cast = props.CastSlot,
					Clear = props.ClearSlot,
					Usable = props.SkillUsable,
					Color = props.SkillColor,
					Cost = props.SkillCost,
					SlotSize = SLOT_SIZE,
				}) :: any,
			},
		}),
	}
	table.insert(
		slots,
		scope:New("Frame")({
			Name = "Gap",
			LayoutOrder = SKILL_SLOTS + 1,
			Size = UDim2.fromOffset(Theme.Padding.Large, SLOT_SIZE),
			BackgroundTransparency = 1,
			Visible = onBar,
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
	-- UI plan phase 1: the S123 emote wheel slot left the bar (T and the game menu's tile open the wheel)

	local bar = scope:New("Frame")({
		Name = "ActionBar",
		AnchorPoint = PhoneLayout.Anchor(scope, "potions", Vector2.new(0.5, 1)),
		Position = PhoneLayout.Position(scope, "potions", HudSlots.point(scope, "actionBar", 0.5, 1)),
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
	ChatDock(scope, bar :: GuiObject) -- UI plan phase 1: the chat in the lower left corner on PC, clear of the bar
	return bar
end

local function expBar(scope: Scope): Instance
	local level = number(scope, { "character", "level" })
	local exp = number(scope, { "character", "exp" })
	local need = scope:Computed(function(use): number
		local l = use(level)
		return if l >= Config.MaxLevel then 0 else Exp.expToNext(math.max(1, l))
	end)
	-- UI plan phase 2 (Studio audit 2026-10-31, too many numbers at rest): the percentage only while the pointer is over
	-- the bar (the tooltip adds the points); a touch screen shows it in the tooltip of a long press
	local hovered = scope:Value(false)
	local bar = Bar(scope, {
		Name = "Exp",
		-- UI plan phase 2: thinner and 2 lower (was 16 tall, 4 up): the chat in the lower left corner ends a few pixels
		-- above it (Studio 2026-10-31: they touched); package A: the zone map's EXP line (Logic/HudZones.EXP_BAR)
		Position = HudSlots.at(scope, "expBar"),
		Size = HudSlots.sizeOf(scope, "expBar"),
		Value = exp,
		Max = need,
		Color = Theme.Resource.Exp,
		ShowNumbers = false,
		Label = scope:Computed(function(use): string
			if not use(hovered) then
				return ""
			end
			if use(level) >= Config.MaxLevel then
				return Text.get(use, "hud.expMax")
			end
			local pct = Exp.progress(use(level), use(exp), Config.MaxLevel) * 100
			local mark = Text.get(use, "format.decimal") -- "45,3" in Polish
			return Text.get(use, "hud.expPct", { pct = (string.gsub(string.format("%.1f", pct), "%.", mark)) })
		end),
	})
	local strip = bar :: GuiObject
	table.insert(
		scope,
		strip.MouseEnter:Connect(function()
			hovered:set(true)
		end)
	)
	table.insert(
		scope,
		strip.MouseLeave:Connect(function()
			hovered:set(false)
		end)
	)
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

-- W29: the menu on a phone in landscape: a button left of the minimap opens the menu's buttons (and the login reward
-- and the season pass, which have no room on the HUD there) as a drawer under it. UI plan phase 1: the same six
-- buttons as the PC bar (the other windows are tiles behind its ☰), the login reward and the season pass only while a
-- reward waits; the drawer's button shows "!" while any of its buttons does.
local DRAWER_PER_ROW = 3
local DRAWER_EXTRA = 100 -- LayoutOrder of the reward buttons: after the bar's

local function drawer(scope: Scope, props: Props): { Instance }
	local open = scope:Value(false)
	local compact = PhoneLayout.Compact
	scope:Observer(compact):onChange(function()
		if not Fusion.peek(compact) then
			open:set(false)
		end
	end)
	local function close()
		open:set(false)
	end
	local cells: { Instance } = menuButtons(scope, props, close)
	local login: any = LoginButton(scope, {
		Status = props.LoginStatus,
		Badge = props.LoginBadge,
		Open = function()
			close()
			props.OpenLogin()
		end,
		Position = UDim2.new(),
	})
	login.LayoutOrder = DRAWER_EXTRA
	table.insert(cells, login)
	local season: any = SeasonButton(scope, {
		Open = function()
			close()
			props.OpenWindow("season")
		end,
		Position = UDim2.new(),
	})
	season.LayoutOrder = DRAWER_EXTRA + 1
	table.insert(cells, season)
	-- the "!" of the drawer's buttons (the ☰'s own covers every tile, the login reward and the season pass among them)
	local badges: { Fusion.UsedAs<boolean> } = {}
	for _, entry in props.Menu do
		if entry.badge then
			table.insert(badges, entry.badge(scope))
		end
	end
	local cell = Theme.Size.IconButton
	local toggle = PhoneHud.PLACES.menuToggle
	-- package A: the drawer opens left of its button, top-aligned with it (under it, it covered the PvP toggle)
	local drawerAt = scope:Computed(function(use): UDim2
		local place = use(PhoneLayout.Places).menuToggle
		local xs, xo, ys, yo = PhoneHud.udim(place)
		return UDim2.new(xs, xo - place.w - Theme.Padding.Small, ys, yo)
	end)
	return {
		IconButton(scope, {
			Name = "MenuToggle",
			Icon = "☰",
			Tooltip = Text.T(scope, "hud.menuDrawer"),
			Position = PhoneLayout.Position(scope, "menuToggle", UDim2.new()),
			AnchorPoint = PhoneLayout.Anchor(scope, "menuToggle", Vector2.zero),
			Size = UDim2.fromOffset(toggle.w, toggle.h),
			Active = open,
			Badge = scope:Computed(function(use): boolean
				if use(props.LoginBadge) == true then
					return true
				end
				for _, badge in badges do
					if use(badge) == true then
						return true
					end
				end
				return false
			end),
			Visible = compact,
			OnClick = function()
				open:set(not Fusion.peek(open))
			end,
		}),
		scope:New("Frame")({
			Name = "MenuDrawer",
			AnchorPoint = Vector2.new(1, 0),
			Position = drawerAt,
			Size = UDim2.fromOffset(DRAWER_PER_ROW * (cell + Theme.Padding.Small) + Theme.Padding.Small, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Iron.Surface,
			BackgroundTransparency = Theme.HudAlpha,
			ZIndex = 5,
			Visible = scope:Computed(function(use): boolean
				return use(compact) and use(open)
			end),
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, Theme.Padding.Small),
					PaddingBottom = UDim.new(0, Theme.Padding.Small),
					PaddingLeft = UDim.new(0, Theme.Padding.Small),
					PaddingRight = UDim.new(0, Theme.Padding.Small),
				}),
				scope:New("UIGridLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					FillDirectionMaxCells = DRAWER_PER_ROW,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					SortOrder = Enum.SortOrder.LayoutOrder,
					CellSize = UDim2.fromOffset(cell, cell),
					CellPadding = UDim2.fromOffset(Theme.Padding.Small, Theme.Padding.Small),
				}),
				cells :: any,
			},
		}),
	}
end

local function Hud(scope: Scope, props: Props): Instance
	local localPlayer = game:GetService("Players").LocalPlayer
	local myModel = scope:Value(localPlayer.Character)
	-- package A: the cast line holds the cast bar or the weapon pool's name (the bar wins)
	local cast = CastBar(scope) :: GuiObject
	local casting = scope:Value(cast.Visible)
	table.insert(
		scope,
		cast:GetPropertyChangedSignal("Visible"):Connect(function()
			casting:set(cast.Visible)
		end)
	)
	local phoneCastLine = scope:Computed(function(use): UDim2
		local place = use(PhoneLayout.Places).castBar
		return UDim2.fromOffset(place.x + place.w / 2, place.y + place.h)
	end)
	table.insert(
		scope,
		localPlayer.CharacterAdded:Connect(function(model)
			myModel:set(model)
		end)
	)
	return scope:New("Frame")({
		Name = "Hud",
		-- the HUD's own area (UI/Scale.HudSize: the layer's part on the screen), so what stands at its right edge stays
		-- MARGIN inside the screen (Studio check 2026-10-31)
		Size = scope:Computed(function(use): UDim2
			local size: Vector2 = use(Scale.HudSize)
			return UDim2.fromOffset(size.X, size.Y)
		end),
		BackgroundTransparency = 1,
		[Children] = {
			LowHpVignette(scope), -- S134f: under every other HUD element
			portrait(scope),
			-- UI plan phase 2 (one row of effects): PC and tablet show the blessing (✶ and its time), the elixirs and the
			-- returning bonus first in the effects row under the portrait; a phone keeps the elixirs at their own place and
			-- the blessing by the name
			scope:New("Frame")({
				Name = "EffectsRow",
				Position = PhoneLayout.Position(scope, "effects", HudSlots.at(scope, "effects")),
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					scope:New("Frame")({
						Name = "Blessing",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(0, 26),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						[Children] = BlessingBadge.new(scope, 1),
					}),
					scope:Hydrate(BlessingIcon(scope, UDim2.new(), EFFECT_ICON))({ LayoutOrder = 2 }),
					-- package A: at most HudZones.EFFECTS_CAP icons (a phone's row fewer), then '+N' with the rest
					scope:Hydrate(EffectIcons(scope, {
						Model = myModel,
						Size = EFFECT_ICON,
						Max = PhoneLayout.Pick(scope, EFFECTS_PHONE, HudZones.EFFECTS_CAP),
					}))({ LayoutOrder = 3 }),
				},
			}),
			-- UI plan phase 2: the Cloak of Luring, Auto Hunt and Auto Potions behind one "Auto" button right of the
			-- portrait (Hud/AutoGroup); package A: a phone has the same button at the start of the row under its
			-- portrait. The login reward and the season pass moved to the row under the minimap (Hud/WaitingRow).
			AutoGroup(scope) :: any,
			cast,
			MobileSkills(scope, {
				Cast = props.CastSlot,
				Color = props.SkillColor,
				Cost = props.SkillCost,
				SelectTarget = props.SelectTarget,
				AimStart = props.AimStart,
				AimMove = props.AimMove,
				AimEnd = props.AimEnd,
			}),
			menu(scope, props),
			drawer(scope, props) :: any,
			actionBar(scope, props),
			-- S139: the weapon pool's name over the bar for a moment after a weapon change (owner 2026-10-21: over
			-- the slots' cost plates too)
			-- package A: in the cast line with the cast bar, which wins while a cast runs
			PoolLabel(
				scope,
				PhoneLayout.Pick(scope, phoneCastLine, HudSlots.point(scope, "castLine", 0.5, 1)),
				casting
			),
			expBar(scope),
			TargetFrame(scope, { Target = props.Target, OnPlayerMenu = props.OnPlayerMenu }),
			-- package A: what the HUD column has no room for, behind '+N'
			StackChip(scope),
			-- package A: a phone's guide bar (the M zone or a line of the stack; the menu's bar is PC's)
			NavBar(scope, { ShowWindow = props.ShowWindow, StopGuide = props.StopGuide, Phone = true }),
			ZoneBanner(scope),
			AreaBanner(scope),
			AttackButton(scope, { OnAttack = props.OnAttack }),
			-- owner 2026-10-21: parcels waiting, over the target button on a phone; UI plan phase 2: PC and tablet in the
			-- row under the minimap (Hud/WaitingRow)
			MailButton(scope, {
				Open = function()
					props.ShowWindow("mail")
				end,
			}),
			SprintButton(scope, { Sprinting = props.Sprinting, OnToggle = props.OnSprint, Riding = props.Riding }),
			MountButton.Touch(scope, { Riding = props.Riding, Has = props.HasMount, OnToggle = props.OnMount }),
			PvpToggle(scope),
			DeathScreen(scope, {
				-- W28: "Top up" on the death screen opens the Dragon Shop on the currency tab
				OpenShop = function()
					PremiumShop.select("currency")
					props.OpenWindow("premium")
				end,
			}),
		},
	})
end

return Hud
