--!strict
-- One character slot on the selection screen: empty ("Create character") or occupied (name, class,
-- level, map, Play / Delete).
-- S121: an empty slot above Config.FreeCharacters without its passes is locked: a lock, "Extra character slot" and
-- "Unlock (n R$)" for the next missing pass (Data/Products.SLOT_PASSES; slot 5 first asks for slot 4), or "Soon"
-- without a pass id on a live server. An occupied slot is always a normal card (playing never needs the pass).
-- Owner 2026-11-10 (UI plan E, Logic/WorldLayout.characterSelect): the buttons ("Graj" and "Usuń", "Utwórz",
-- "Odblokuj") are pinned to the card's bottom and what stands over them is cut on a short card: a phone's card is
-- narrower, its emblem shrinks with the room and its texts are smaller, so the buttons never leave the screen.
-- UI package C (owner 2026-11-10, "too much text, things covering each other, nothing folds"): the buttons are the
-- card's footer, as a window's: a rule in the gap and one row of 52 ("Usuń" at its left, "Graj" in the rest), so the
-- card keeps 48 px more for its emblem and texts than with the two buttons stacked (52 + 8 + 40).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local WindowFrame = require(ReplicatedStorage.Shared.Logic.WindowFrame)
local WorldLayout = require(ReplicatedStorage.Shared.Logic.WorldLayout)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Slot: number,
	Summary: UsedAs<Types.SlotSummary?>,
	Busy: UsedAs<boolean>,
	OnCreate: () -> (),
	OnPlay: () -> (),
	OnDelete: (summary: Types.SlotSummary) -> (),
	-- S121: a locked empty slot and the pass to buy next for it (nil = open)
	Locked: UsedAs<boolean>?,
	Pass: UsedAs<string?>?,
	OnUnlock: ((passKey: string) -> ())?,
	-- owner 2026-11-10: the card's size, padding, emblem and buttons on this screen (Logic/WorldLayout)
	Layout: UsedAs<WorldLayout.CharacterSelect>,
}

local CARD = WorldLayout.CHAR_CARD
local FOOTER = WindowFrame.FOOTER
local FOOTER_GAP = WindowFrame.FOOTER_GAP

-- What stands over the buttons (`info`, cut on a short card) and the card's footer under it: the rule in the middle
-- of the gap and one row of buttons (Logic/WorldLayout.characterSelect's `play` and `delete`).
local function pinned(scope: Scope, info: { Instance }, actions: { Instance }, gap: number): { Instance }
	return {
		scope:New("Frame")({
			Name = "Info",
			LayoutOrder = 1,
			-- the card's list puts its CARD.gap (FOOTER_GAP) between this part and the footer
			Size = UDim2.new(1, 0, 1, -(FOOTER + FOOTER_GAP)),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			[Children] = {
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, gap),
				}),
				info :: any,
			},
		}),
		scope:New("Frame")({
			Name = "Footer",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, FOOTER),
			BackgroundTransparency = 1,
			[Children] = {
				-- the rule stands beside the buttons' row, never in its list (a list lays out every sibling)
				scope:New("Frame")({
					Name = "Rule",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromOffset(0, -FOOTER_GAP / 2),
					Size = UDim2.new(1, 0, 0, Theme.Stroke.Thin),
					BackgroundColor3 = Theme.Paper.Rule,
					BorderSizePixel = 0,
				}),
				scope:New("Frame")({
					Name = "Buttons",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					[Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, CARD.gap),
						}),
						actions :: any,
					},
				}),
			},
		}),
	}
end

local function label(scope: Scope, props: { [any]: any }): Instance
	local base: { [any]: any } = {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, props.Height or 26),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Paper.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	props.Height = nil
	for key, value in props do
		base[key] = value
	end
	return scope:New("TextLabel")(base)
end

local function emblem(scope: Scope, class: Classes.ClassDef?, layoutOrder: number, size: number): Instance
	local color = if class then Theme.readable(class.color, "paper") else Theme.Paper.Label
	return scope:New("Frame")({
		Name = "Emblem",
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(size, size),
		Visible = size > 0,
		BackgroundColor3 = Theme.Paper.Sunken,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			scope:New("UIStroke")({ Thickness = Theme.Stroke.Thick, Color = color }),
			-- S119: the class emblem once loaded (glyph or "+" otherwise).
			ArtIcon(scope, {
				Key = if class then UiArt.classEmblem(class.id) else nil,
				Glyph = if class then class.icon else "+",
				GlyphColor = color,
				ImageScale = 0.8,
				Size = UDim2.fromScale(1, 1),
				Label = {
					FontFace = Theme.Fonts.BodyBold,
					TextSize = if size < 84 then Theme.TextSize.Title else Theme.TextSize.Hero,
				},
			}),
		},
	})
end

local function occupied(scope: Scope, props: Props, summary: Types.SlotSummary, l: WorldLayout.CharacterSelect)
	local class = Classes.get(summary.class)
	local map = Maps.get(summary.map)
	local small = l.emblem < 84
	return pinned(scope, {
		emblem(scope, class, 1, l.emblem),
		label(scope, {
			Name = "CharName",
			LayoutOrder = 2,
			Height = if small then 32 else 40,
			Text = summary.name,
			FontFace = Theme.Fonts.Display,
			TextSize = if small then Theme.TextSize.Large else Theme.TextSize.Title,
			TextColor3 = Theme.Paper.Heading,
		}),
		label(scope, {
			Name = "ClassLevel",
			LayoutOrder = 3,
			Height = if small then 24 else 26,
			TextSize = if small then Theme.TextSize.Small else Theme.TextSize.Body,
			Text = scope:Computed(function(use): string
				local className = if class then Text.get(use, class.nameKey) else summary.class
				return Text.get(use, "charSelect.classLevel", { class = className, level = summary.level })
			end),
		}),
		label(scope, {
			Name = "Map",
			LayoutOrder = 4,
			Height = if small then 20 else 22,
			Text = Text.T(scope, if map then map.nameKey else "map.unknown"),
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Paper.TextMuted,
		}),
	}, {
		Button(scope, {
			Name = "Delete",
			LayoutOrder = 1,
			Text = Text.T(scope, "charSelect.delete"),
			Variant = "ghost",
			Size = UDim2.fromOffset(CARD.delete, FOOTER),
			Disabled = props.Busy,
			OnClick = function()
				props.OnDelete(summary)
			end,
		}),
		Button(scope, {
			Name = "Play",
			LayoutOrder = 2,
			Text = Text.T(scope, "charSelect.play"),
			Variant = "primary",
			Size = UDim2.new(1, -(CARD.delete + CARD.gap), 0, FOOTER),
			Disabled = props.Busy,
			OnClick = props.OnPlay,
		}),
	}, if small then 4 else Theme.Padding.Small)
end

local function empty(scope: Scope, props: Props, l: WorldLayout.CharacterSelect): { Instance }
	return pinned(scope, {
		emblem(scope, nil, 1, l.emblem),
		label(scope, {
			Name = "Empty",
			LayoutOrder = 2,
			Height = 40,
			Text = Text.T(scope, "charSelect.emptySlot"),
			FontFace = Theme.Fonts.Display,
			TextSize = Theme.TextSize.Large,
			TextColor3 = Theme.Paper.TextMuted,
		}),
	}, {
		Button(scope, {
			Name = "Create",
			LayoutOrder = 1,
			Text = Text.T(scope, "charSelect.createButton"),
			Variant = "secondary",
			Size = UDim2.new(1, 0, 0, FOOTER),
			Disabled = props.Busy,
			OnClick = props.OnCreate,
		}),
	}, Theme.Padding.Small)
end

-- S121: a locked empty slot.
local function locked(scope: Scope, props: Props, passKey: string, l: WorldLayout.CharacterSelect): { Instance }
	local pass = Products.getPass(passKey)
	local soon = pass == nil or Premium.robuxState(pass.passId, RunService:IsStudio()) == "soon"
	-- slot 5 without slot 4: the button buys slot 4 first and says so
	local needs = Products.SLOT_PASSES[props.Slot] or {}
	local needsEarlier = #needs > 1 and passKey ~= needs[#needs]
	return pinned(scope, {
		scope:New("Frame")({
			Name = "Emblem",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(l.emblem, l.emblem),
			Visible = l.emblem > 0,
			BackgroundColor3 = Theme.Paper.Sunken,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
				scope:New("UIStroke")({ Thickness = Theme.Stroke.Thick, Color = Theme.Paper.Rule }),
				scope:New("TextLabel")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "🔒",
					TextSize = Theme.TextSize.Title,
					FontFace = Theme.Fonts.BodyBold,
					TextColor3 = Theme.Paper.Label,
				}),
			},
		}),
		label(scope, {
			Name = "Locked",
			LayoutOrder = 2,
			Height = 56,
			Text = Text.T(scope, "charSelect.slotLocked"),
			FontFace = Theme.Fonts.Display,
			TextSize = Theme.TextSize.Large,
			TextColor3 = Theme.Paper.TextMuted,
			TextWrapped = true,
		}),
		label(scope, {
			Name = "Needs",
			LayoutOrder = 3,
			Height = 44,
			Text = Text.T(scope, if needsEarlier then "charSelect.slotNeeds4" else `premium.pass.{passKey}.desc`),
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Paper.TextMuted,
			TextWrapped = true,
		}),
	}, {
		Button(scope, {
			Name = "Unlock",
			LayoutOrder = 1,
			Text = if soon
				then Text.T(scope, "premium.soon")
				else Text.T(scope, "charSelect.unlock", { price = if pass then pass.robux else 0 }),
			Variant = "primary",
			Size = UDim2.new(1, 0, 0, FOOTER),
			Disabled = scope:Computed(function(use): boolean
				return soon or use(props.Busy)
			end),
			OnClick = function()
				if props.OnUnlock then
					props.OnUnlock(passKey)
				end
			end,
		}),
	}, Theme.Padding.Small)
end

local function SlotCard(scope: Scope, props: Props): Instance
	local hasCharacter = scope:Computed(function(use): boolean
		return use(props.Summary) ~= nil
	end)

	return scope:New("Frame")({
		Name = `Slot{props.Slot}`,
		LayoutOrder = props.Slot,
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(0, use(props.Layout).cardWidth, 1, -8)
		end),
		BackgroundColor3 = Theme.Paper.Surface,
		BackgroundTransparency = 0.08,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Large }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = Theme.Paper.Border,
				Transparency = scope:Computed(function(use): number
					return if use(hasCharacter) then 0.1 else 0.55
				end),
			}),
			scope:New("UISizeConstraint")({
				MaxSize = scope:Computed(function(use): Vector2
					return Vector2.new(use(props.Layout).cardWidth, CARD.maxHeight)
				end),
			}),
			scope:New("UIPadding")({
				PaddingTop = scope:Computed(function(use): UDim
					return UDim.new(0, use(props.Layout).padding)
				end),
				PaddingBottom = scope:Computed(function(use): UDim
					return UDim.new(0, use(props.Layout).padding)
				end),
				PaddingLeft = scope:Computed(function(use): UDim
					return UDim.new(0, use(props.Layout).padding)
				end),
				PaddingRight = scope:Computed(function(use): UDim
					return UDim.new(0, use(props.Layout).padding)
				end),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, CARD.gap),
			}),
			scope:Computed(function(use, innerScope: Scope): { Instance }
				local summary = use(props.Summary)
				local l = use(props.Layout)
				if summary then
					return occupied(innerScope, props, summary, l)
				end
				local passKey = if props.Pass ~= nil then use(props.Pass) else nil
				if props.Locked ~= nil and use(props.Locked) and passKey ~= nil then
					return locked(innerScope, props, passKey, l)
				end
				return empty(innerScope, props, l)
			end) :: any,
		},
	})
end

return SlotCard
