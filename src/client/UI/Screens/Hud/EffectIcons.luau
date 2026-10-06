--!strict
-- Row of buff / debuff icons with seconds left, read from a model's "Effects" attribute
-- ("kind:expiresAt;..." in server time, written by StatusEffectService). Used under the portrait and in the
-- target frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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

local GLYPHS: { [string]: { glyph: string, good: boolean } } = {
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
}

type Entry = { kind: string, left: number }

local function parse(raw: any, t: number): { Entry }
	local list = {}
	if type(raw) ~= "string" then
		return list
	end
	local seen: { [string]: boolean } = {}
	for part in string.gmatch(raw, "[^;]+") do
		local kind, expires = string.match(part, "^(%a+):([%d%.]+)$")
		local left = (tonumber(expires) or 0) - t
		if kind and left > 0 and not seen[kind] then
			seen[kind] = true
			table.insert(list, { kind = kind, left = left })
		end
	end
	table.sort(list, function(a, b)
		return a.kind < b.kind
	end)
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
			local model = Fusion.peek(props.Model)
			entries:set(if model then parse(model:GetAttribute("Effects"), Workspace:GetServerTimeNow()) else {})
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
				local info = GLYPHS[entry.kind] or { glyph = "?", good = true }
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
							Text = if entry.left >= 10
								then tostring(math.floor(entry.left))
								else string.format("%.1f", entry.left),
							FontFace = Theme.Fonts.BodyBold,
							TextSize = 12,
							TextColor3 = Theme.Colors.Text,
							TextStrokeTransparency = 0.3,
						}),
					},
				})
				Tooltip.attach(s, icon :: GuiObject, Text.T(s, `effect.{entry.kind}`))
				return icon
			end) :: any,
		},
	})
end

return EffectIcons
