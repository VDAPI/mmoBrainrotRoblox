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
local CostBadge = require(script.Parent.Parent.Components.CostBadge) -- owner 2026-10-21: the cost plates over the bar
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
local LureButton = require(script.LureButton)
local AutoGrindButton = require(script.AutoGrindButton) -- S134d
local AutoPotionButton = require(script.AutoPotionButton) -- S134d
local LoginReward = require(ReplicatedStorage.Shared.Logic.LoginReward)
local PortraitFrame = require(script.Parent.Parent.Components.PortraitFrame)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local PotionBar = require(script.PotionBar)
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
-- same request as the touch screens' toggle); its tooltip tells the state, the countdown and that it can be clicked.
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
	local button = scope:New("TextButton")({
		Name = "PvpSwitch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(117, 22),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 2,
		[OnEvent("Activated")] = function()
			if Fusion.peek(zoneType) == "yellow" then
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
			local lines = { Text.get(use, `pvp.dot.{use(state)}`) }
			local p = use(pvp)
			if type(p) == "table" and type(p.switchAt) == "number" and p.pendingTarget ~= nil then
				local left = math.ceil(math.max(0, p.switchAt - use(now)))
				table.insert(lines, Text.get(use, "pvp.countdown", { seconds = left }))
			end
			if use(zoneType) == "yellow" then
				table.insert(lines, Text.get(use, "pvp.dot.click"))
			end
			return table.concat(lines, "\n")
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
		Position = PhoneLayout.Position(scope, "portrait", UDim2.fromOffset(Theme.Padding.Large, Theme.Padding.Large)),
		Size = UDim2.fromOffset(400, 136),
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
			pvpSwitch(scope),
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
					-- UI plan phase 2: a phone keeps the blessing by the name; PC and tablet show it first in the effects row
					scope:New("Frame")({
						Name = "BlessingSlot",
						LayoutOrder = 2,
						Size = UDim2.fromOffset(0, 26),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Visible = PhoneLayout.Compact,
						[Children] = BlessingBadge.new(scope, 1),
					}),
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
		Position = PhoneLayout.Position(scope, "minimap", UDim2.new(1, -Theme.Padding.Large, 0, Theme.Padding.Large)),
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
		Position = PhoneLayout.Position(scope, "potions", UDim2.new(0.5, 0, 1, -(14 + Theme.Padding.Medium))),
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
		AnchorPoint = Vector2.new(0.5, 1),
		-- UI plan phase 2: thinner and 2 lower (was 16 tall, 4 up): the chat in the lower left corner ends a few pixels
		-- above it (Studio 2026-10-31: they touched)
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, -8, 0, 10),
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
			return Text.get(use, "hud.expPct", { pct = string.format("%.1f", pct) })
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
local POOL = PhoneHud.PLACES.pool -- W29: the weapon pool label on a phone in landscape

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
	local xs, xo, ys, yo, ax, ay = PhoneHud.udim(toggle)
	return {
		IconButton(scope, {
			Name = "MenuToggle",
			Icon = "☰",
			Tooltip = Text.T(scope, "hud.menuDrawer"),
			Position = UDim2.new(xs, xo, ys, yo),
			AnchorPoint = Vector2.new(ax, ay),
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
			Position = UDim2.new(xs, xo, ys, yo + toggle.h + Theme.Padding.Small),
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
			-- UI plan phase 2 (one row of effects): PC and tablet show the blessing (✶ and its time), the elixirs and the
			-- returning bonus first in the effects row under the portrait; a phone keeps the elixirs at their own place and
			-- the blessing by the name
			scope:Hydrate(
				BlessingIcon(
					scope,
					PhoneLayout.Position(
						scope,
						"blessing",
						UDim2.fromOffset(Theme.Padding.Large + 400 + 12, Theme.Padding.Large + 4)
					)
				)
			)({ Visible = PhoneLayout.Compact }),
			scope:New("Frame")({
				Name = "EffectsRow",
				Position = PhoneLayout.Position(
					scope,
					"effects",
					UDim2.fromOffset(Theme.Padding.Large, Theme.Padding.Large + 136 + 6)
				),
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
						Visible = PhoneLayout.Pick(scope, false, true),
						[Children] = BlessingBadge.new(scope, 1),
					}),
					scope:Hydrate(BlessingIcon(scope, UDim2.new(), EFFECT_ICON))({
						LayoutOrder = 2,
						Visible = PhoneLayout.Pick(scope, false, true),
					}),
					scope:Hydrate(EffectIcons(scope, { Model = myModel, Size = EFFECT_ICON }))({ LayoutOrder = 3 }),
				},
			}),
			-- UI plan phase 2: the Cloak of Luring, Auto Hunt and Auto Potions behind one "Auto" button right of the
			-- portrait (PC and tablet, Hud/AutoGroup); a phone keeps the three at their places (Logic/PhoneHud). The login
			-- reward and the season pass moved to the row under the minimap (Hud/WaitingRow).
			AutoGroup(scope) :: any,
			scope:New("Frame")({
				Name = "PhoneAuto",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = PhoneLayout.Compact,
				[Children] = {
					LureButton(
						scope,
						PhoneLayout.Position(
							scope,
							"lure",
							UDim2.fromOffset(Theme.Padding.Large + 400 + 12 + 44 + 8, Theme.Padding.Large + 136 - 64)
						)
					),
					AutoGrindButton(
						scope,
						PhoneLayout.Position(
							scope,
							"autoGrind",
							UDim2.fromOffset(
								Theme.Padding.Large + 400 + 12 + 44 + 8 + 56,
								Theme.Padding.Large + 136 - 64
							)
						)
					),
					AutoPotionButton(
						scope,
						PhoneLayout.Position(
							scope,
							"autoPotion",
							UDim2.fromOffset(
								Theme.Padding.Large + 400 + 12 + 44 + 8 + 112,
								Theme.Padding.Large + 136 - 64
							)
						)
					),
				},
			}),
			CastBar(scope),
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
			PoolLabel(
				scope,
				PhoneLayout.Pick(
					scope,
					UDim2.fromOffset(POOL.x + POOL.w / 2, POOL.y + POOL.h),
					UDim2.new(
						0.5,
						0,
						1,
						-(14 + Theme.Padding.Medium + SLOT_SIZE + CostBadge.OVERHANG + Theme.Padding.Small)
					)
				)
			),
			expBar(scope),
			TargetFrame(scope, { Target = props.Target, OnPlayerMenu = props.OnPlayerMenu }),
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
