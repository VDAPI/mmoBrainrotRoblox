--!strict
-- Row of buff / debuff icons with seconds left, read from a model's "Effects" attribute
-- ("kind:expiresAt[:value];..." in server time, written by StatusEffectService, decoded by Logic/EffectStack).
-- The server sends one entry per kind (latest end, strongest value), so one icon per kind. Used under the
-- portrait and in the target frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EffectStack = require(ReplicatedStorage.Shared.Logic.EffectStack)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Model: Fusion.UsedAs<Model?>,
	Position: UDim2?,
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
	nextBasic = { glyph = "➹", good = true }, -- S65: Full Draw, the next basic attack hits harder
	runeSeal = { glyph = "◈", good = true, lasting = true }, -- S65: glowing Runic Seal
	frostbite = { glyph = "❅", good = false }, -- S65: takes more damage from the source's ice
}

type Entry = EffectStack.Shown

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
			local model = Fusion.peek(props.Model)
			entries:set(
				if model then EffectStack.decode(model:GetAttribute("Effects"), Workspace:GetServerTimeNow()) else {}
			)
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
				local icon = s:New("Frame")({
					Name = entry.kind,
					Size = UDim2.fromOffset(size, size + 14),
					BackgroundTransparency = 1,
					[Children] = {
						s:New("TextLabel")({
							Size = UDim2.fromOffset(size, size),
							BackgroundColor3 = Theme.Colors.Panel,
							BackgroundTransparency = 0.15,
							Text = info.glyph,
							TextScaled = true,
							FontFace = Theme.Fonts.BodyBold,
							TextColor3 = if info.good then Theme.Colors.Success else Theme.Colors.DangerHover,
							[Children] = {
								s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
								s:New("UIStroke")({
									Color = if info.good then Theme.Colors.Success else Theme.Colors.Danger,
									Thickness = 1,
								}),
							},
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(0, size),
							Size = UDim2.fromOffset(size, 14),
							BackgroundTransparency = 1,
							Text = if info.lasting
								then ""
								elseif entry.left >= 10 then tostring(math.floor(entry.left))
								else string.format("%.1f", entry.left),
							FontFace = Theme.Fonts.BodyBold,
							TextSize = 12,
							TextColor3 = Theme.Colors.Text,
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
