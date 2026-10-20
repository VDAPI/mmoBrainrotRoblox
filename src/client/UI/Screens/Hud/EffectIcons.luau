--!strict
-- Row of buff / debuff icons with seconds left, read from a model's "Effects" attribute
-- ("kind:expiresAt[:value];..." in server time, written by StatusEffectService, decoded by Logic/EffectStack).
-- The server sends one entry per kind (latest end, strongest value), so one icon per kind. Used under the
-- portrait and in the target frame.
-- S76: stacks above 1 (poison, bleed, armour break) show as a small number in the icon's bottom-right corner.
-- S72: the "Fury" / "FuryMax" attributes (Fury of the Berserker) add a counter "7/10" first in the row, gold when full.
-- S119: the owner's picture of the effect (Logic/UiArt.effect) once its atlas is loaded, the glyph otherwise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local EffectStack = require(ReplicatedStorage.Shared.Logic.EffectStack)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Model: Fusion.UsedAs<Model?>,
	Position: Fusion.UsedAs<UDim2>?,
	AnchorPoint: Vector2?,
	Size: number?,
}

-- lasting (S65): no seconds counter (markers that live until something breaks them).
type Glyph = { glyph: string, good: boolean, lasting: boolean? }
local UNKNOWN: Glyph = { glyph = "?", good = true }
local GLYPHS: { [string]: Glyph } = {
	stun = { glyph = "✶", good = false },
	root = { glyph = "⛓", good = false },
	slow = { glyph = "🐌", good = false },
	freeze = { glyph = "❄", good = false },
	bleed = { glyph = "🩸", good = false },
	poison = { glyph = "☠", good = false },
	burn = { glyph = "🔥", good = false },
	armorBreak = { glyph = "⛨", good = false },
	vulnerability = { glyph = "🎯", good = false },
	taunt = { glyph = "❗", good = false },
	invuln = { glyph = "☩", good = true },
	damageReduction = { glyph = "🛡", good = true },
	shield = { glyph = "◍", good = true },
	statBuff = { glyph = "▲", good = true },
	hot = { glyph = "❦", good = true },
	camouflage = { glyph = "🌫", good = true },
	nextShot = { glyph = "➶", good = true },
	guaranteedCrit = { glyph = "✦", good = true },
	manaShield = { glyph = "🔵", good = true },
	respawnShield = { glyph = "✧", good = true },
	intercept = { glyph = "⇆", good = true }, -- S61: a guard takes part of the blows
	misfortune = { glyph = "✗", good = false }, -- S61: misses regular attacks
	attackSlow = { glyph = "⧗", good = false }, -- S63: slower attacks
	weaken = { glyph = "⇓", good = false }, -- S63: deals less damage
	guardianAngel = { glyph = "✟", good = true }, -- S70: a lethal monster blow leaves 1 HP
	emberShield = { glyph = "🜂", good = true }, -- S140: melee attackers catch fire
	iceBarrier = { glyph = "⛉", good = true }, -- S141: melee attackers are slowed
	stormArmor = { glyph = "⛨", good = true }, -- S142: melee attackers are struck back
	chill = { glyph = "❆", good = false }, -- S141: the caster's chill counter (count in the corner)
	deepChill = { glyph = "✻", good = false }, -- S141: takes more damage from the source (bosses' freeze)
	nextBasic = { glyph = "➹", good = true }, -- S65: Full Draw, the next basic attack hits harder
	runeSeal = { glyph = "◈", good = true, lasting = true }, -- S65: glowing Runic Seal
	frostbite = { glyph = "❅", good = false }, -- S65: takes more damage from the source's ice
	fury = { glyph = "💢", good = true }, -- S72: Fury stacks (counter, not seconds)
	carnage = { glyph = "💀", good = true }, -- S72: Carnage, Fury holds and grows faster
	sighted = { glyph = "⌖", good = false }, -- S77: Draw a Bead, the source's hits on the bearer crit more
	arcaneCharge = { glyph = "❖", good = true }, -- S80: Arcane Charges (count in the corner)
	empowered = { glyph = "✪", good = true }, -- S80: Empowering Invocation (uses left in the corner)
}
-- S80 (ROZWOJ 12.5): counters, so the corner shows the count from a single stack
local ALWAYS_COUNT: { [string]: boolean } = { arcaneCharge = true, empowered = true, chill = true } -- S141: chill

-- S72: count / max / full only for the Fury counter.
type Entry = {
	kind: string,
	left: number,
	value: number?,
	stacks: number?, -- S76
	count: number?,
	max: number?,
	full: boolean?,
}

local function read(model: Model?): { Entry }
	if not model then
		return {}
	end
	local list: { Entry } = {}
	for _, shown in EffectStack.decode(model:GetAttribute("Effects"), Workspace:GetServerTimeNow()) do
		local stacks = if ALWAYS_COUNT[shown.kind] then shown.stacks or 1 else shown.stacks
		table.insert(list, { kind = shown.kind, left = shown.left, value = shown.value, stacks = stacks })
	end
	local stacks = model:GetAttribute("Fury")
	local max = model:GetAttribute("FuryMax")
	if type(stacks) == "number" and stacks > 0 then
		local cap = if type(max) == "number" then max else nil
		table.insert(list, 1, {
			kind = "fury",
			left = 0,
			count = stacks,
			max = cap,
			full = cap ~= nil and stacks >= cap,
		})
	end
	return list
end

local function EffectIcons(scope: Scope, props: Props): Instance
	local size = props.Size or 30
	local entries = scope:Value({} :: { Entry })
	local accumulator = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			accumulator += dt
			if accumulator < 0.25 then
				return
			end
			accumulator = 0
			entries:set(read(Fusion.peek(props.Model)))
		end)
	)

	return scope:New("Frame")({
		Name = "EffectIcons",
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = UDim2.fromOffset(size * 8 + 28, size + 14),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			scope:ForValues(entries, function(_use, s: Scope, entry: Entry): Instance
				local info = GLYPHS[entry.kind] or UNKNOWN
				local count = entry.count
				local full = entry.full == true
				local caption = if count
					then (if entry.max then `{count}/{entry.max}` else tostring(count))
					elseif info.lasting then ""
					elseif entry.left >= 10 then tostring(math.floor(entry.left))
					else string.format("%.1f", entry.left)
				-- S119: the effect's picture inside the good / bad frame once loaded (glyph otherwise).
				local artKey = UiArt.effect(entry.kind)
				local artShown = ArtIcon.Shown(s, artKey)
				local icon = s:New("Frame")({
					Name = entry.kind,
					Size = UDim2.fromOffset(size, size + 14),
					BackgroundTransparency = 1,
					[Children] = {
						s:New("TextLabel")({
							Size = UDim2.fromOffset(size, size),
							BackgroundColor3 = Theme.Iron.Surface,
							BackgroundTransparency = Theme.HudAlpha,
							Text = s:Computed(function(use): string
								return if use(artShown) then "" else info.glyph
							end),
							TextScaled = true,
							FontFace = Theme.Fonts.BodyBold,
							TextColor3 = if info.good then Theme.Iron.Success else Theme.Iron.Danger,
							[Children] = {
								s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
								ArtIcon.Image(s, { Key = artKey, Corner = Theme.Corner.Small }),
								s:New("UIStroke")({
									Color = if full
										then Theme.Brass.Bright
										elseif info.good then Theme.Iron.Success
										else Theme.Iron.Danger,
									Thickness = if full then 2 else 1,
								}),
								-- S76: stacks in the corner
								if entry.stacks and (entry.stacks > 1 or ALWAYS_COUNT[entry.kind])
									then s:New("TextLabel")({
										AnchorPoint = Vector2.new(1, 1),
										Position = UDim2.fromScale(1, 1),
										Size = UDim2.fromOffset(14, 12),
										BackgroundTransparency = 1,
										Text = tostring(entry.stacks),
										FontFace = Theme.Fonts.BodyBold,
										TextSize = Theme.TextSize.Caption,
										TextXAlignment = Enum.TextXAlignment.Right,
										TextColor3 = Theme.Iron.Text,
										TextStrokeTransparency = 0.3,
										ZIndex = 2,
									}) :: any
									else nil,
							} :: any,
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(0, size),
							Size = UDim2.fromOffset(size, 14),
							BackgroundTransparency = 1,
							Text = caption,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Caption,
							TextColor3 = if full then Theme.Brass.Bright else Theme.Iron.Text,
							TextStrokeTransparency = 0.3,
						}),
					},
				})
				local value = entry.value
				local tip = if value
					then s:Computed(function(use): string
						return Text.get(
							use,
							"effect.withValue",
							{ name = Text.get(use, `effect.{entry.kind}`), value = value }
						)
					end)
					else Text.T(s, `effect.{entry.kind}`)
				Tooltip.attach(s, icon :: GuiObject, tip)
				return icon
			end) :: any,
		},
	})
end

return EffectIcons
