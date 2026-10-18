--!strict
-- Season pass window (S152b, docs/DESIGN.md §21b; key win_season, the HUD button next to the login reward, the game
-- menu, the shop's card). Parchment (DESIGN §23). Header: the season's name, "ends in", the tier, the bar of the
-- current tier (brass on the dark track), the growing cap with the catch-up and "cap reached" badges. Tabs:
--   Rewards  both tracks by tier: PC a horizontal strip of tier columns (free over premium), a phone a vertical list
--            of tiers with two cells a row. A cell: the reward's picture, its name and its state (locked, to claim
--            with the green edge and a glowing brass frame, claimed ✓, the premium lock); the tooltip (iron) says
--            what it is. The strip opens on the first tier to claim.
--   How      the sources of points (Data/Seasons.POINTS), the limits and the catch-up in one paragraph, and the one
--            sentence "and VIP?" (season.vsVip, the shop says the same).
-- Actions: a cell to claim -> SeasonClaim, "Claim all" (more than one to claim) -> SeasonClaimAll, "Unlock premium"
-- (or a locked premium cell) -> the shop's confirmation (UI/SeasonPassBuy). After a season: its grace days ("claim
-- until") with the same strip, or "the next season soon". Everything shown comes from Logic/SeasonView over the
-- replicated account (UI/SeasonState); the server decides every claim and the purchase. Funnel `season` (S152b):
-- "open" when the window opens, "view" on the first look at the premium track (hover, a click or a scroll of the
-- strip), both only while the premium track can be bought.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local Bar = require(script.Parent.Parent.Components.Bar)
local Button = require(script.Parent.Parent.Components.Button)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Device = require(script.Parent.Parent.Device)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Lure = require(ReplicatedStorage.Shared.Logic.Lure)
local Net = require(ReplicatedStorage.Shared.Net)
local Season = require(ReplicatedStorage.Shared.Logic.Season)
local SeasonState = require(script.Parent.Parent.SeasonState)
local SeasonView = require(ReplicatedStorage.Shared.Logic.SeasonView)
local Seasons = require(ReplicatedStorage.Shared.Data.Seasons)
local SectionLabel = require(script.Parent.Parent.Components.SectionLabel)
local Sounds = require(script.Parent.Parent.Sounds)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Tooltip = require(script.Parent.Parent.Components.Tooltip)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.UiArtState)

local Children, OnEvent, OnChange = Fusion.Children, Fusion.OnEvent, Fusion.OnChange

type Scope = Fusion.Scope<typeof(Fusion)>
type View = SeasonView.View
type SeasonDef = Seasons.SeasonDef
type Reward = Seasons.Reward

export type Props = {
	-- SeasonClaim (tier, "free" | "premium", season id); errors become toasts in the controller
	Claim: (tier: number, track: string, seasonId: string) -> (),
	ClaimAll: () -> (), -- SeasonClaimAll
	Buy: () -> (), -- UI/SeasonPassBuy.ask
}

local HEADER = 128
local HEADER_TOUCH = 120
local TOOLBAR = Theme.Size.MinTouch
local GAP = Theme.Padding.Small
-- PC strip
local COL = 128
local TIER_ROW = 28
local CELL = 134
local SIDE = 112
-- phone list
local ROW = 96
local TIER_COL = 64
local ICON = 48
local PULSE_SPEED = 3 -- rad/s of the glowing frame
local LURE_GLYPH = "❂"

-- "×1,5" in Polish, "×1.5" in English (the catch-up multiplier of Data/Seasons).
local function mulText(use: Fusion.Use): string
	local text = string.format("%g", Seasons.CATCHUP.mul)
	if use(Text.Lang) == "pl" then
		text = (string.gsub(text, "%.", ","))
	end
	return `×{text}`
end

local function date(t: number): string
	local year, month, day = Time.civil(t)
	return string.format("%02d.%02d.%04d", day, month, year)
end

-- The reward's name (a cosmetic, n items, Cloak of Luring time).
local function rewardName(use: Fusion.Use, reward: Reward): string
	if reward.kind == "cosmetic" and reward.id then
		local def = Cosmetics.get(reward.id)
		return if def then Text.get(use, def.nameKey) else reward.id
	elseif reward.kind == "item" and reward.id then
		return Text.get(use, "season.reward.item", { item = ItemText.get(use, reward.id), n = reward.n or 1 })
	end
	local key, args = Lure.timeKey(reward.seconds or 0)
	return Text.get(use, "season.reward.lure", { time = Text.get(use, key, args) })
end

-- The tooltip of a reward (iron): its name, what it is, and the state of the cell.
local function rewardTip(use: Fusion.Use, reward: Reward, def: SeasonDef, cell: string, tier: number): string
	local lines = { rewardName(use, reward) }
	if reward.kind == "cosmetic" and reward.id then
		local cos = Cosmetics.get(reward.id)
		local kind = if cos then Text.get(use, `wardrobe.kind.{cos.kind}`) else ""
		table.insert(lines, Text.get(use, "season.tip.cosmetic", { kind = kind, season = Text.get(use, def.nameKey) }))
	elseif reward.kind == "item" then
		table.insert(lines, Text.get(use, "season.tip.item"))
	else
		table.insert(lines, Text.get(use, "season.tip.lure"))
	end
	if cell == "claimable" then
		table.insert(lines, Text.get(use, "season.cell.claimHint"))
	elseif cell == "noPremium" then
		table.insert(lines, Text.get(use, "season.cell.premiumHint"))
	elseif cell == "locked" then
		table.insert(lines, Text.get(use, "season.cell.lockedHint", { tier = tier }))
	end
	return table.concat(lines, "\n")
end

-- The picture of a reward in an `ICON` square.
local function rewardIcon(scope: Scope, reward: Reward, dim: Fusion.UsedAs<number>, props: { [string]: any }): Instance
	if reward.kind == "item" and reward.id then
		return ItemIcon(scope, {
			Def = Items.get(reward.id),
			Size = UDim2.fromOffset(ICON, ICON),
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			Transparency = dim,
		})
	elseif reward.kind == "cosmetic" and reward.id then
		local def = Cosmetics.get(reward.id)
		local key = UiArt.cosmetic(reward.id)
		return scope:New("TextLabel")({
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			Size = UDim2.fromOffset(ICON, ICON),
			BackgroundColor3 = if def then Theme.tint(def.color) else Theme.Paper.Sunken,
			BackgroundTransparency = dim,
			Text = scope:Computed(function(use): string
				return if UiArtState.ready(use, key) or not def then "" else def.icon
			end),
			TextScaled = true,
			FontFace = Theme.Fonts.BodyBold,
			TextColor3 = Theme.Plain,
			TextStrokeTransparency = 0.4,
			TextTransparency = dim,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 6),
				}),
				-- S119: the cosmetic's picture on its colour once loaded
				ArtIcon.Image(scope, {
					Key = key,
					Size = UDim2.new(1, 12, 1, 12),
					Position = UDim2.fromOffset(-6, -6),
					Corner = Theme.Corner.Small,
					Transparency = dim,
				}),
			},
		})
	end
	return ArtIcon(scope, {
		Key = UiArt.shop("lure"),
		Glyph = LURE_GLYPH,
		GlyphColor = Theme.Paper.Heading,
		Transparency = dim,
		Size = UDim2.fromOffset(ICON, ICON),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Label = { FontFace = Theme.Fonts.BodyBold, TextScaled = true },
	})
end

type Ctx = {
	props: Props,
	view: Fusion.UsedAs<View>,
	pulse: Fusion.Value<number>,
	markView: () -> (),
}

-- One cell of the strip (PC: picture over the name and the state; phone `wide`: picture left, texts right).
local function cell(scope: Scope, ctx: Ctx, def: SeasonDef, tier: number, track: Seasons.Track, wide: boolean): Instance
	local reward = Season.rewardOf(def, tier, track)
	if not reward then
		return scope:New("Frame")({
			Name = `{track}{tier}`,
			LayoutOrder = if track == "free" then 2 else 3,
			Size = if wide then UDim2.new(0.5, -GAP, 1, 0) else UDim2.new(1, 0, 0, CELL),
			BackgroundTransparency = 1,
		})
	end
	local reward0 = reward :: Reward
	local state = scope:Computed(function(use): SeasonView.Cell
		return SeasonView.cell(use(ctx.view), tier, track)
	end)
	local dim = scope:Computed(function(use): number
		return if use(state) == "claimed" then 0.45 else 0
	end)
	local statusText = scope:Computed(function(use): string
		local s = use(state)
		if s == "claimable" then
			return Text.get(use, "season.cell.claim")
		elseif s == "claimed" then
			return Text.get(use, "season.cell.claimed")
		elseif s == "noPremium" then
			return Text.get(use, "season.cell.premium")
		end
		return ""
	end)
	local statusColor = scope:Computed(function(use): Color3
		return if use(state) == "claimable" then Theme.Paper.Success else Theme.Paper.TextMuted
	end)
	local name = scope:Computed(function(use): string
		return rewardName(use, reward0)
	end)
	local textLeft = if wide then ICON + 16 else 6
	local nameLabel = scope:New("TextLabel")({
		Name = "Name",
		Position = if wide then UDim2.fromOffset(textLeft, 6) else UDim2.fromOffset(6, ICON + 12),
		Size = if wide then UDim2.new(1, -(textLeft + 6), 0, 44) else UDim2.new(1, -12, 0, 44),
		BackgroundTransparency = 1,
		Text = name,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = Theme.Fonts.BodyMedium,
		TextSize = Theme.TextSize.Small,
		TextColor3 = scope:Computed(function(use): Color3
			return if use(state) == "claimed" then Theme.Paper.TextMuted else Theme.Paper.Text
		end),
		TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local statusLabel = scope:New("TextLabel")({
		Name = "Status",
		AnchorPoint = Vector2.new(0, 1),
		Position = if wide then UDim2.new(0, textLeft, 1, -4) else UDim2.new(0, 6, 1, -4),
		Size = if wide then UDim2.new(1, -(textLeft + 6), 0, 22) else UDim2.new(1, -12, 0, 22),
		BackgroundTransparency = 1,
		Text = statusText,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = statusColor,
		TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
	})
	local button = scope:New("TextButton")({
		Name = `{track}{tier}`,
		LayoutOrder = if track == "free" then 2 else 3,
		Size = if wide then UDim2.new(0.5, -GAP, 1, 0) else UDim2.new(1, 0, 0, CELL),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = scope:Computed(function(use): Color3
			local s = use(state)
			if s == "claimable" then
				return Theme.Paper.Selected
			end
			return if s == "claimed" then Theme.Paper.Sunken else Theme.Paper.Raised
		end),
		[OnEvent("Activated")] = function()
			local s = Fusion.peek(state)
			if track == "premium" then
				ctx.markView()
			end
			if s == "claimable" then
				Sounds.play("click")
				ctx.props.Claim(tier, track, def.id)
			elseif s == "noPremium" and SeasonView.canBuy(Fusion.peek(ctx.view), SeasonState.now()) then
				Sounds.play("click")
				ctx.props.Buy()
			end
		end,
		[OnEvent("MouseEnter")] = function()
			if track == "premium" then
				ctx.markView()
			end
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			-- the informative edge: green (paper.accent, >= 3:1) on a cell to claim, the plain border otherwise
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = scope:Computed(function(use): Color3
					return if use(state) == "claimable" then Theme.Paper.Accent else Theme.Paper.Border
				end),
				Thickness = scope:Computed(function(use): number
					return if use(state) == "claimable" then Theme.Stroke.Thick else Theme.Stroke.Thin
				end),
			}),
			-- the decorative glow of a cell to claim (brass, pulsing; the edge above carries the information)
			scope:New("Frame")({
				Name = "Glow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 8, 1, 8),
				BackgroundTransparency = 1,
				Active = false,
				Visible = scope:Computed(function(use): boolean
					return use(state) == "claimable"
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Theme.Brass.Bright,
						Thickness = Theme.Stroke.Thick,
						Transparency = scope:Computed(function(use): number
							return 0.2 + 0.6 * use(ctx.pulse)
						end),
					}),
				},
			}),
			rewardIcon(scope, reward0, dim, {
				Position = if wide then UDim2.new(0, 8, 0.5, 0) else UDim2.new(0.5, 0, 0, 8),
				AnchorPoint = if wide then Vector2.new(0, 0.5) else Vector2.new(0.5, 0),
			}),
			nameLabel,
			statusLabel,
		},
	}) :: TextButton
	Tooltip.attach(
		scope,
		button,
		scope:Computed(function(use): string
			return rewardTip(use, reward0, def, use(state), tier)
		end)
	)
	return button
end

local function tierLabel(scope: Scope, ctx: Ctx, tier: number, size: UDim2): Instance
	return scope:New("TextLabel")({
		Name = "Tier",
		LayoutOrder = 1,
		Size = size,
		BackgroundTransparency = 1,
		Text = tostring(tier),
		FontFace = Theme.Fonts.Display,
		TextSize = Theme.TextSize.Body,
		TextColor3 = scope:Computed(function(use): Color3
			return if tier <= use(ctx.view).tier then Theme.Paper.Heading else Theme.Paper.TextMuted
		end),
	})
end

-- The track name on the left of the PC strip (premium: lock or ✓).
local function trackLabel(scope: Scope, ctx: Ctx, track: Seasons.Track, y: number): Instance
	return scope:New("TextLabel")({
		Name = `Track_{track}`,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(SIDE - GAP, CELL),
		BackgroundColor3 = Theme.Paper.Sunken,
		Text = scope:Computed(function(use): string
			if track == "free" then
				return Text.get(use, "season.track.free")
			end
			local owned = use(ctx.view).state.premium
			return Text.get(use, if owned then "season.track.premiumOwned" else "season.track.premiumLocked")
		end),
		TextWrapped = true,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Paper.Heading,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
		},
	})
end

-- Scrolls `frame` so that `offset` (px along the strip) is near its start, once its size is known.
local function scrollTo(frame: ScrollingFrame, offset: number, horizontal: boolean, done: () -> ())
	task.defer(function()
		local target = math.max(0, offset - (if horizontal then COL else ROW))
		frame.CanvasPosition = if horizontal then Vector2.new(target, 0) else Vector2.new(0, target)
		task.defer(done)
	end)
end

-- PC: a column per tier (the tier, the free cell, the premium cell) next to the fixed track names.
local function strip(scope: Scope, ctx: Ctx, def: SeasonDef, focus: number): Instance
	local columns: { Instance } = {}
	for tier = 1, def.tiers do
		table.insert(
			columns,
			scope:New("Frame")({
				Name = `Tier{tier}`,
				LayoutOrder = tier,
				Size = UDim2.new(0, COL, 1, -12),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
					tierLabel(scope, ctx, tier, UDim2.new(1, 0, 0, TIER_ROW)),
					cell(scope, ctx, def, tier, "free", false),
					cell(scope, ctx, def, tier, "premium", false),
				},
			})
		)
	end
	local ready = false
	local frame = scope:New("ScrollingFrame")({
		Name = "Strip",
		Position = UDim2.fromOffset(SIDE, 0),
		Size = UDim2.new(1, -SIDE, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.X,
		-- explicit (not AutomaticCanvasSize): scrollTo runs before the first layout pass and would be clamped to 0
		CanvasSize = UDim2.fromOffset(def.tiers * (COL + GAP) + 4, 0),
		[OnChange("CanvasPosition")] = function()
			if ready then
				ctx.markView()
			end
		end,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, GAP),
			}),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }),
			columns :: any,
		},
	}) :: ScrollingFrame
	scrollTo(frame, (focus - 1) * (COL + GAP), true, function()
		ready = true
	end)
	return scope:New("Frame")({
		Name = "Tracks",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			trackLabel(scope, ctx, "free", 4 + TIER_ROW + GAP),
			trackLabel(scope, ctx, "premium", 4 + TIER_ROW + GAP + CELL + GAP),
			frame,
		},
	})
end

-- Phone: a row per tier (the tier, the free cell, the premium cell) under a header row.
local function list(scope: Scope, ctx: Ctx, def: SeasonDef, focus: number): Instance
	local rows: { Instance } = {}
	for tier = 1, def.tiers do
		table.insert(
			rows,
			scope:New("Frame")({
				Name = `Tier{tier}`,
				LayoutOrder = tier,
				Size = UDim2.new(1, 0, 0, ROW),
				BackgroundTransparency = 1,
				[Children] = {
					tierLabel(scope, ctx, tier, UDim2.new(0, TIER_COL, 1, 0)),
					scope:New("Frame")({
						Name = "Cells",
						Position = UDim2.fromOffset(TIER_COL, 0),
						Size = UDim2.new(1, -TIER_COL, 1, 0),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, GAP),
							}),
							cell(scope, ctx, def, tier, "free", true),
							cell(scope, ctx, def, tier, "premium", true),
						},
					}),
				},
			})
		)
	end
	local heads = scope:New("Frame")({
		Name = "Heads",
		Size = UDim2.new(1, -12, 0, 28),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(TIER_COL, 0),
				Size = UDim2.new(0.5, -(TIER_COL // 2 + GAP), 1, 0),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "season.track.free"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("TextLabel")({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.5, -(TIER_COL // 2 + GAP), 1, 0),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local owned = use(ctx.view).state.premium
					return Text.get(use, if owned then "season.track.premiumOwned" else "season.track.premiumLocked")
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
	local ready = false
	local frame = scope:New("ScrollingFrame")({
		Name = "List",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.fromOffset(0, def.tiers * (ROW + GAP) + 4), -- explicit, as in strip()
		[OnChange("CanvasPosition")] = function()
			if ready then
				ctx.markView()
			end
		end,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4) }),
			rows :: any,
		},
	}) :: ScrollingFrame
	scrollTo(frame, (focus - 1) * (ROW + GAP), false, function()
		ready = true
	end)
	return scope:New("Frame")({
		Name = "Tracks",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = { heads, frame },
	})
end

-- A centred message (no season: "the next season soon").
local function soon(scope: Scope, ctx: Ctx): Instance
	return scope:New("Frame")({
		Name = "Soon",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, GAP),
			}),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, -40, 0, 36),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "season.soon"),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Paper.Heading,
			}),
			scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.new(1, -40, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local nextDef = use(ctx.view).next
					if not nextDef then
						return Text.get(use, "season.soon.desc")
					end
					return Text.get(use, "season.soon.next", {
						season = Text.get(use, nextDef.nameKey),
						date = date(nextDef.start),
					})
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Text,
			}),
		},
	})
end

local function paragraph(scope: Scope, order: number, text: Fusion.UsedAs<string>, color: Color3?): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextWrapped = true,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		TextColor3 = color or Theme.Paper.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- "How to earn points": the sources, the limits and the catch-up, and "and VIP?".
local function howTab(scope: Scope, ctx: Ctx): Instance
	local rows: { Instance } = {}
	for i, source in SeasonView.SOURCES do
		local points = Seasons.POINTS[source] or 0
		table.insert(
			rows,
			scope:New("Frame")({
				Name = source,
				LayoutOrder = 10 + i,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = if i % 2 == 0 then Theme.Paper.Sunken else Theme.Paper.Surface,
				[Children] = {
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
					scope:New("TextLabel")({
						Size = UDim2.new(1, -120, 1, 0),
						BackgroundTransparency = 1,
						Text = Text.T(scope, `season.source.{source}`),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					scope:New("TextLabel")({
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0, 120, 1, 0),
						BackgroundTransparency = 1,
						Text = Text.T(scope, "season.points", { n = Format.number(points) }),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Heading,
						TextXAlignment = Enum.TextXAlignment.Right,
					}),
				},
			})
		)
	end
	return scope:New("ScrollingFrame")({
		Name = "How",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4) }),
			SectionLabel(scope, { LayoutOrder = 1, Text = Text.T(scope, "season.how.sources") }),
			rows :: any,
			SectionLabel(scope, { LayoutOrder = 100, Text = Text.T(scope, "season.how.limitsTitle") }),
			paragraph(
				scope,
				101,
				scope:Computed(function(use): string
					return Text.get(use, "season.how.limits", {
						kill = Format.number(Seasons.LIMITS.killPerDay),
						week = Format.number(Seasons.LIMITS.weekCap),
						mul = mulText(use),
						behind = math.floor(Seasons.CATCHUP.behind * 100 + 0.5),
						tier = Format.number(Seasons.TIER_POINTS),
						days = Seasons.GRACE_DAYS,
					})
				end)
			),
			paragraph(
				scope,
				102,
				scope:Computed(function(use): string
					local v = use(ctx.view)
					if v.mode ~= "running" then
						return ""
					end
					return Text.get(use, "season.how.today", {
						kill = Format.number(v.kill),
						max = Format.number(Seasons.LIMITS.killPerDay),
					})
				end),
				Theme.Paper.TextMuted
			),
			SectionLabel(scope, { LayoutOrder = 200, Text = Text.T(scope, "season.vsVip.title") }),
			paragraph(scope, 201, Text.T(scope, "season.vsVip")),
		},
	})
end

local function badge(scope: Scope, order: number, text: Fusion.UsedAs<string>, color: Color3, visible: any): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Paper.Raised,
		Visible = visible,
		Text = text,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = color,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		},
	})
end

local function header(scope: Scope, ctx: Ctx): Instance
	local view = ctx.view
	local running = scope:Computed(function(use): boolean
		return use(view).mode == "running"
	end)
	local hasSeason = scope:Computed(function(use): boolean
		return use(view).def ~= nil
	end)
	return scope:New("Frame")({
		Name = "Header",
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(1, 0, 0, if use(Device.Touch) then HEADER_TOUCH else HEADER)
		end),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("TextLabel")({
				Name = "Season",
				Size = UDim2.new(1, -220, 0, 36),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local v = use(view)
					local def = v.def or v.next
					return if def then Text.get(use, def.nameKey) else Text.get(use, "season.window.title")
				end),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Title,
				TextColor3 = Theme.Paper.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Name = "Tier",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(220, 36),
				BackgroundTransparency = 1,
				Visible = hasSeason,
				Text = scope:Computed(function(use): string
					local v = use(view)
					return Text.get(use, "season.tier", { tier = v.tier, tiers = if v.def then v.def.tiers else 0 })
				end),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Paper.Heading,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			scope:New("TextLabel")({
				Name = "When",
				Position = UDim2.fromOffset(0, 38),
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local v = use(view)
					if v.mode == "running" then
						local d, h = SeasonView.daysHours(v.endsIn)
						return Text.get(use, "season.endsIn", { d = d, h = h })
					elseif v.mode == "grace" and v.def then
						return Text.get(use, "season.grace", {
							season = Text.get(use, v.def.nameKey),
							date = date((v.claimUntil :: number) - 1), -- claimUntil is the next day's 00:00 (Season.canClaim)
						})
					end
					return Text.get(use, "season.soon")
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Bar(scope, {
				Name = "Points",
				Position = UDim2.fromOffset(0, 64),
				Value = scope:Computed(function(use): number
					return use(view).progress
				end),
				Max = Seasons.TIER_POINTS,
				Color = Theme.Brass.Bright,
				Surface = "paper",
			}),
			scope:New("Frame")({
				Name = "Limits",
				Position = UDim2.fromOffset(0, 92),
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				Visible = running,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, GAP),
					}),
					scope:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.fromOffset(0, 24),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local v = use(view)
							return Text.get(use, "season.week", {
								points = Format.number(v.state.points),
								cap = Format.number(v.cap),
							})
						end),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Text,
					}),
					badge(
						scope,
						2,
						scope:Computed(function(use): string
							return Text.get(use, "season.catchup", { mul = mulText(use) })
						end),
						Theme.Paper.Success,
						scope:Computed(function(use): boolean
							return use(view).catchup
						end)
					),
					badge(
						scope,
						3,
						Text.T(scope, "season.capped"),
						Theme.Paper.Warning,
						scope:Computed(function(use): boolean
							return use(view).capped
						end)
					),
					badge(
						scope,
						4,
						Text.T(scope, "season.maxed"),
						Theme.Paper.Success,
						scope:Computed(function(use): boolean
							return use(view).maxed
						end)
					),
				},
			}),
		},
	})
end

local function SeasonPass(scope: Scope, props: Props): Instance
	local view = SeasonState.View
	local touch = Device.Touch
	local pulse = scope:Value(0)
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			pulse:set((math.sin(os.clock() * PULSE_SPEED) + 1) / 2)
		end)
	)
	-- S152b funnel `season`: opened, then the first look at the premium track (only while it can be bought)
	local function buyable(): boolean
		return SeasonView.canBuy(Fusion.peek(view), SeasonState.now())
	end
	if buyable() then
		Net.Send("PremiumFunnel", "season", "open")
	end
	local viewed = false
	local ctx: Ctx = {
		props = props,
		view = view,
		pulse = pulse,
		markView = function()
			if not viewed and buyable() then
				viewed = true
				Net.Send("PremiumFunnel", "season", "view")
			end
		end,
	}

	local selected = scope:Value("rewards")
	local headerHeight = scope:Computed(function(use): number
		return if use(touch) then HEADER_TOUCH else HEADER
	end)
	local claimCount = scope:Computed(function(use): number
		return SeasonView.claimCount(use(view))
	end)

	local toolbar = scope:New("Frame")({
		Name = "Toolbar",
		Position = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(0, use(headerHeight))
		end),
		Size = UDim2.new(1, 0, 0, TOOLBAR),
		BackgroundTransparency = 1,
		[Children] = {
			Tabs(scope, {
				Tabs = {
					{ id = "rewards", label = Text.T(scope, "season.tab.rewards") },
					{ id = "how", label = Text.T(scope, "season.tab.how") },
				},
				Selected = selected,
				Size = UDim2.new(0, 360, 1, 0),
			}),
			scope:New("Frame")({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(1, -372, 1, 0),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, GAP),
					}),
					Button(scope, {
						Name = "ClaimAll",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(200, Theme.Size.MinTouch),
						Variant = "secondary",
						TextSize = Theme.TextSize.Small,
						Text = scope:Computed(function(use): string
							return Text.get(use, "season.claimAll", { n = use(claimCount) })
						end),
						Visible = scope:Computed(function(use): boolean
							return SeasonView.claimAllShown(use(view))
						end),
						OnClick = props.ClaimAll,
					}),
					Button(scope, {
						Name = "Unlock",
						LayoutOrder = 2,
						Size = UDim2.fromOffset(220, Theme.Size.MinTouch),
						Variant = "primary",
						TextSize = Theme.TextSize.Small,
						Text = Text.T(scope, "season.unlock"),
						Visible = scope:Computed(function(use): boolean
							return SeasonView.canBuy(use(view), use(SeasonState.Now))
						end),
						OnClick = props.Buy,
					}),
				},
			}),
		},
	})

	-- The strip is rebuilt only when the season shown or the layout changes (the cells follow the view).
	local shownId = scope:Computed(function(use): string
		local v = use(view)
		return if v.def then v.def.id else ""
	end)
	local body = scope:Computed(function(use, s: Scope): Instance
		local tab = use(selected)
		local id = use(shownId)
		local isTouch = use(touch)
		if tab == "how" then
			return howTab(s, ctx)
		end
		local def = Seasons.get(id)
		if not def then
			return soon(s, ctx)
		end
		local focus = SeasonView.focusTier(Fusion.peek(view))
		return if isTouch then list(s, ctx, def, focus) else strip(s, ctx, def, focus)
	end)

	return scope:New("Frame")({
		Name = "SeasonPass",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			header(scope, ctx),
			toolbar,
			scope:New("Frame")({
				Name = "Body",
				Position = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(0, use(headerHeight) + TOOLBAR + GAP)
				end),
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, 0, 1, -(use(headerHeight) + TOOLBAR + GAP))
				end),
				BackgroundTransparency = 1,
				[Children] = body :: any,
			}),
		},
	})
end

return SeasonPass
