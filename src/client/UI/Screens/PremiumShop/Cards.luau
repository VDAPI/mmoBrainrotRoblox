--!strict
-- Shared pieces of the Dragon Shop tabs (S120): the entry card (S119 picture with today's glyph as the fallback, an
-- item picture, or a cosmetic tile), the buy buttons (shards and Robux with the "Soon" state, DESIGN-17 §0.8), section
-- headers, note lines and the Robux request.
-- 2026-10-21 (owner: too many detailed descriptions): a card shows one short subtitle; the full description goes to
-- `info`, an "i" after the title (Components/InfoTip: hover / click on PC, tap on a phone). A note can carry one too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Parent.Components.InfoTip)
local ItemIcon = require(script.Parent.Parent.Parent.Components.ItemIcon)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local ShopPayload = require(ReplicatedStorage.Shared.Logic.ShopPayload)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)
local UiArtState = require(script.Parent.Parent.Parent.UiArtState)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

local Cards = {}

-- What every tab gets from the window (init.luau).
export type Ctx = {
	ShowModal: (spec: any) -> (),
	OpenWardrobe: (start: { kind: string?, try: string? }?) -> (),
	Select: (tab: string) -> (),
	OpenVip: (() -> ())?, -- S121: the VIP window
	OpenSeason: (() -> ())?, -- S152b: the season pass window
	BuySeason: (() -> ())?, -- S152b: the purchase dialog of the season pass's premium track (UI/SeasonPassBuy)
}

export type CardSpec = {
	order: number,
	glyph: string, -- today's glyph (fallback of the picture)
	art: string?, -- S119: interface picture key (Logic/UiArt)
	item: Items.ItemDef?, -- an item picture instead (S118 ItemIcon)
	tileColor: Color3?, -- cosmetics: the tile in the cosmetic's colour
	title: UsedAs<string>,
	subtitle: UsedAs<string>?, -- nil: the title only (2026-10-21: the currency packs)
	info: UsedAs<string>?, -- 2026-10-21: the full description behind an "i" after the title
	badge: UsedAs<string>?, -- small green label next to the title (pack bonus)
	button: Instance?, -- the right side (one button or a frame with two)
	buttonWidth: number?, -- width the right side takes (default 190)
	tooltip: UsedAs<string>?, -- on the whole card (PC: hover, phone: long press)
	rich: boolean?, -- S123: the subtitle is rich text (an old price struck through)
	highlight: boolean?, -- W28: a brass frame instead of the thin rule (the VIP card)
}

-- W28: the card is a row (tile | text column | right side) in a UIListLayout and grows with its subtitle, so a long
-- description wraps instead of running under the buttons; MIN_HEIGHT keeps one-line cards even.
local MIN_HEIGHT = 76
local TILE = 56
local GAP = 12
local PAD = 10
local TITLE_HEIGHT = 26
local BADGE_RESERVE = 116
local RIGHT_HEIGHT = 56

local function tile(scope: Scope, spec: CardSpec): Instance
	if spec.item then
		return ItemIcon(scope, {
			Def = spec.item,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(TILE, TILE),
		})
	end
	local art = spec.art
	return scope:New("TextLabel")({
		Size = UDim2.fromOffset(TILE, TILE),
		BackgroundColor3 = spec.tileColor or Theme.Paper.Surface,
		Text = scope:Computed(function(use): string
			return if UiArtState.ready(use, art) then "" else spec.glyph
		end),
		TextScaled = true,
		FontFace = Theme.Fonts.BodyBold,
		TextColor3 = if spec.tileColor then Theme.Plain else Theme.Paper.Heading,
		TextStrokeTransparency = if spec.tileColor then 0.4 else 1,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			-- S119: the owner's picture over the square once loaded.
			ArtIcon.Image(scope, {
				Key = art,
				Size = UDim2.new(1, 12, 1, 12),
				Position = UDim2.fromOffset(-6, -6),
				Corner = if spec.tileColor then Theme.Corner.Small else nil,
			}),
		},
	})
end

function Cards.card(scope: Scope, spec: CardSpec): Instance
	local right = spec.buttonWidth or 190
	local hasBadge = spec.badge ~= nil
	local info = if spec.info ~= nil then InfoTip.new(scope, { Text = spec.info, LayoutOrder = 2 }) else nil
	-- pointing at the "i" swaps the card's mouse tooltip for the popover (never both on top of each other)
	local infoHit = if info then info:FindFirstChild("Hit") else nil
	if infoHit and infoHit:IsA("GuiObject") and spec.tooltip ~= nil then
		table.insert(
			scope,
			infoHit.MouseEnter:Connect(function()
				Tooltip.hide()
			end)
		)
	end
	local textColumn = scope:New("Frame")({
		Name = "Text",
		LayoutOrder = 2,
		Size = UDim2.new(1, -(TILE + right + GAP * 2), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 2),
			}),
			scope:New("Frame")({
				Name = "TitleRow",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
				BackgroundTransparency = 1,
				[Children] = {
					-- the title and its "i" right after it (the title shrinks and truncates first)
					scope:New("Frame")({
						Name = "Name",
						Size = UDim2.new(1, if hasBadge then -BADGE_RESERVE else 0, 1, 0),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 6),
							}),
							scope:New("TextLabel")({
								Name = "Title",
								LayoutOrder = 1,
								Size = UDim2.fromScale(0, 1),
								AutomaticSize = Enum.AutomaticSize.X,
								BackgroundTransparency = 1,
								Text = spec.title,
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = Theme.Paper.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								[Children] = scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink }),
							}),
							info :: any,
						},
					}),
					(if hasBadge
						then scope:New("TextLabel")({
							Name = "Badge",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							Size = UDim2.fromOffset(0, 22),
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundColor3 = Theme.Paper.Surface,
							BackgroundTransparency = 0.1,
							Text = spec.badge,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Small,
							TextColor3 = Theme.Paper.Success,
							[Children] = {
								scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
								scope:New("UIPadding")({
									PaddingLeft = UDim.new(0, 8),
									PaddingRight = UDim.new(0, 8),
								}),
								scope:New("UISizeConstraint")({
									MaxSize = Vector2.new(BADGE_RESERVE - 6, math.huge),
								}),
							},
						})
						else nil) :: any,
				},
			}),
			(if spec.subtitle ~= nil
				then scope:New("TextLabel")({
					Name = "Subtitle",
					LayoutOrder = 2,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = spec.subtitle,
					RichText = spec.rich == true,
					TextWrapped = true,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				})
				else nil) :: any,
		} :: any,
	})
	local frame = scope:New("Frame")({
		LayoutOrder = spec.order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Paper.Raised,
		BackgroundTransparency = 0.2,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = if spec.highlight then Theme.Brass.Frame else Theme.Paper.Rule,
				Thickness = if spec.highlight then Theme.Stroke.Normal else Theme.Stroke.Thin,
			}),
			scope:New("UISizeConstraint")({ MinSize = Vector2.new(0, MIN_HEIGHT) }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, PAD),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, GAP),
			}),
			scope:New("Frame")({
				Name = "Tile",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(TILE, TILE),
				BackgroundTransparency = 1,
				[Children] = { tile(scope, spec) },
			}),
			textColumn,
			-- The right side: the buttons keep their own anchor (right edge, centred) inside this holder.
			scope:New("Frame")({
				Name = "Right",
				LayoutOrder = 3,
				Size = UDim2.fromOffset(right, RIGHT_HEIGHT),
				BackgroundTransparency = 1,
				[Children] = { spec.button :: any },
			}),
		} :: any,
	}) :: Frame
	if spec.tooltip ~= nil then
		Tooltip.attach(scope, frame, spec.tooltip)
		-- The button takes the touch (and the hover) from the card: the same text there.
		if spec.button and spec.button:IsA("GuiObject") then
			Tooltip.attach(scope, spec.button, spec.tooltip)
		end
	end
	return frame
end

-- The 180 x 48 button on the right of a card.
function Cards.buyButton(scope: Scope, text: UsedAs<string>, disabled: UsedAs<boolean>?, onClick: () -> ()): Instance
	return Button(scope, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(180, 48),
		Variant = "primary",
		TextSize = Theme.TextSize.Small,
		Text = text,
		Disabled = disabled,
		OnClick = onClick,
	})
end

-- Whether the Robux product `id` can be bought here (Studio simulates; id 0 on a live server shows "Soon").
function Cards.robuxSoon(id: number): boolean
	return Premium.robuxState(id, RunService:IsStudio()) == "soon"
end

-- A Robux button: "R$ n" -> onBuy, "Owned" (disabled) while `owned`, "Soon" (disabled, with the hint) without an id
-- on a live server (DESIGN-17 §0.8). The purchase itself is the native Roblox prompt (no own confirmation).
function Cards.robuxButton(
	scope: Scope,
	id: number,
	robuxText: string,
	onBuy: () -> (),
	owned: UsedAs<boolean>?
): Instance
	local soon = Cards.robuxSoon(id)
	local button = Cards.buyButton(
		scope,
		scope:Computed(function(use): string
			if owned ~= nil and use(owned) == true then
				return Text.get(use, "premium.owned")
			end
			return if soon then Text.get(use, "premium.soon") else robuxText
		end),
		scope:Computed(function(use): boolean
			return soon or (owned ~= nil and use(owned) == true)
		end),
		onBuy
	)
	-- An owned pass (granted while its id is still 0) says "Owned" without the "soon" hint; the Passes tab rebuilds its
	-- cards when the owned passes change, so the value read now holds.
	if soon and not (owned ~= nil and Fusion.peek(owned) == true) then
		Tooltip.attach(scope, button :: GuiObject, Text.T(scope, "premium.soon.hint"))
	end
	return button
end

function Cards.sectionHeader(scope: Scope, order: number, textKey: string): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = Text.T(scope, textKey),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Paper.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})
end

-- One muted line of information (wraps). 2026-10-21: `infoKey` puts that longer text behind an "i" after the line.
function Cards.note(scope: Scope, order: number, textKey: string, infoKey: string?): Instance
	local line = scope:New("TextLabel")({
		LayoutOrder = 1,
		Size = if infoKey then UDim2.new() else UDim2.fromScale(1, 0),
		AutomaticSize = if infoKey then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = Text.T(scope, textKey),
		TextWrapped = true,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Paper.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		[Children] = if infoKey then scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink }) else nil,
	})
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIPadding")({ PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			line,
			(if infoKey then InfoTip.new(scope, { Text = Text.T(scope, infoKey), LayoutOrder = 2 }) else nil) :: any,
		},
	})
end

-- S121: error arguments from a handler's third result; "@key" values are localization keys (like toasts).
function Cards.resolveArgs(args: any): { [string]: any }?
	if type(args) ~= "table" then
		return nil
	end
	local out = {}
	for name, value in args do
		if type(value) == "string" and string.sub(value, 1, 1) == "@" then
			out[name] = Text.now(string.sub(value, 2))
		else
			out[name] = value
		end
	end
	return out
end

-- A Robux request (BuyProduct / BuyPass / BuySubscription): the server opens the native prompt (or simulates in
-- Studio).
function Cards.invoke(name: string, ...: any)
	local call = ShopPayload.pack(name, ...)
	if name == "BuyProduct" or name == "BuyPass" then
		Net.Send("PremiumFunnel", "shop", "item") -- S131: the shop funnel (the VIP funnel's prompt is the server's)
	end
	task.spawn(function()
		local ok, err, errArgs = Net.Invoke(call.remote, table.unpack(call.args, 1, call.n))
		if ok then
			if err then
				-- the native prompt is open (premium.prompted): no sound until something is granted
				Toast.push(Text.now(err), "info")
			else
				Sounds.play("levelUp") -- Studio: simulated and granted at once
			end
		else
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal", Cards.resolveArgs(errArgs)), "error")
		end
	end)
end

return Cards
