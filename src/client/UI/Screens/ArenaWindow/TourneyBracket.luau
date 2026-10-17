--!strict
-- The Champion's Tournament bracket (S130, DESIGN-17 §8) in the arena window: one column per round (round of 32 ...
-- final, Logic/Tourney.roundKey), a cell of 170 x 46 per match with both names (the winner bold in gold, the loser
-- dimmed), "field N" on a match being fought, "bye" / "walkover" in small print, the player's own match lit; thin frames
-- join every pair to its next match. A ScrollingFrame in both axes (32 players = 16 cells in the first round), scrolled
-- to the player's current round at the start. Only the state branch `tourney.live.view` (Logic/Bracket.view plus
-- names): no bracket logic on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tourney = require(ReplicatedStorage.Shared.Logic.Tourney)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use

export type Props = {
	Live: Fusion.UsedAs<any>, -- tourney.live
	MyKey: Fusion.UsedAs<string?>,
	LayoutOrder: number?,
	Height: Fusion.UsedAs<number>?,
}

local CELL_W, CELL_H = 170, 46
local GAP_X, GAP_Y = 44, 10
local HEADER = 26
local LINE = Theme.Paper.Border

local function roundTitle(use: Use, round: number, rounds: number): string
	local key = Tourney.roundKey(round, rounds)
	if key then
		return Text.get(use, key)
	end
	return Text.get(use, "tourney.round", { r = round, total = rounds })
end

-- The canvas of a view and the point to scroll to (the player's newest match).
local function measure(view: any, mine: string?): (Vector2, Vector2)
	if type(view) ~= "table" or type(view.matches) ~= "table" then
		return Vector2.zero, Vector2.zero
	end
	local rounds = tonumber(view.rounds) or 1
	local size = tonumber(view.size) or 2
	local slot = CELL_H + GAP_Y
	local counts: { [number]: number } = {}
	local myRound, myY = 1, 0
	for _, m in view.matches do
		counts[m.round] = (counts[m.round] or 0) + 1
		if mine ~= nil and (m.a == mine or m.b == mine) and m.round >= myRound then
			myRound = m.round
			myY = HEADER + (counts[m.round] - 0.5) * slot * (2 ^ (m.round - 1))
		end
	end
	local canvas = Vector2.new(rounds * (CELL_W + GAP_X), HEADER + (size / 2) * slot)
	local target = Vector2.new(math.max(0, (myRound - 1) * (CELL_W + GAP_X) - 20), math.max(0, myY - 120))
	return canvas, target
end

local function TourneyBracket(scope: Scope, props: Props): Instance
	local viewState = scope:Computed(function(use): any
		local live = use(props.Live)
		return if type(live) == "table" then live.view else nil
	end)
	local canvas = scope:Computed(function(use): Vector2
		local c = measure(use(viewState), use(props.MyKey))
		return c
	end)
	local scrollTo = scope:Computed(function(use): Vector2
		local _, t = measure(use(viewState), use(props.MyKey))
		return t
	end)

	local content = scope:Computed(function(use, s: Scope): any
		local view = use(viewState)
		if type(view) ~= "table" or type(view.matches) ~= "table" then
			return {}
		end
		local names = if type(view.names) == "table" then view.names else {}
		local mine = use(props.MyKey)
		local rounds = tonumber(view.rounds) or 1
		local slot = CELL_H + GAP_Y
		local items: { any } = {}
		local index: { [number]: number } = {} -- match id -> index within its round
		local counts: { [number]: number } = {}
		for _, m in view.matches do
			counts[m.round] = (counts[m.round] or 0) + 1
			index[m.id] = counts[m.round]
		end
		local function centreY(round: number, j: number): number
			local span = slot * (2 ^ (round - 1))
			return HEADER + (j - 0.5) * span
		end
		for r = 1, rounds do
			table.insert(
				items,
				s:New("TextLabel")({
					Position = UDim2.fromOffset((r - 1) * (CELL_W + GAP_X), 0),
					Size = UDim2.fromOffset(CELL_W, HEADER - 4),
					BackgroundTransparency = 1,
					Text = roundTitle(use, r, rounds),
					FontFace = Theme.Fonts.Display,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.Heading,
				})
			)
		end
		for _, m in view.matches do
			local r, j = m.round, index[m.id]
			local x = (r - 1) * (CELL_W + GAP_X)
			local cy = centreY(r, j)
			local own = mine ~= nil and (m.a == mine or m.b == mine)
			local function nameRow(order: number, key: string?): Instance
				local won = key ~= nil and m.winner == key
				local lost = key ~= nil and m.winner ~= nil and m.winner ~= key
				local text = if key then names[key] or "?" else "—"
				if key == nil and m.reason == "bye" and m.round == 1 then
					text = Text.get(use, "tourney.byeShort")
				end
				return s:New("TextLabel")({
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					Text = text,
					FontFace = if won then Theme.Fonts.BodyBold else Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = if won
						then Theme.Paper.Heading
						elseif lost then Theme.Paper.TextMuted
						else Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
			end
			local note = ""
			if m.field ~= nil and m.winner == nil then
				note = Text.get(use, "tourney.fieldShort", { n = m.field })
			elseif m.reason == "bye" then
				note = Text.get(use, "tourney.byeShort")
			elseif m.reason == "walkover" then
				note = Text.get(use, "tourney.walkoverShort")
			end
			table.insert(
				items,
				s:New("Frame")({
					Position = UDim2.fromOffset(x, cy - CELL_H / 2),
					Size = UDim2.fromOffset(CELL_W, CELL_H),
					BackgroundColor3 = if own then Theme.Paper.Hover else Theme.Paper.Raised,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIStroke")({
							Color = if own then Theme.Brass.Frame else Theme.Paper.Rule,
							Thickness = if own then 2 else 1,
						}),
						s:New("UIPadding")({ PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
						s:New("UIListLayout")({
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						nameRow(1, m.a),
						nameRow(2, m.b),
						s:New("TextLabel")({
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, 0, 0, 1),
							Size = UDim2.fromOffset(70, 20),
							BackgroundTransparency = 1,
							Text = note,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if m.field ~= nil and m.winner == nil
								then Theme.Paper.Warning
								else Theme.Paper.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Right,
							Visible = note ~= "",
						}),
					},
				})
			)
			-- the joints: out to the right, a vertical bar per pair, in to the next match
			if r < rounds then
				local midX = x + CELL_W + GAP_X / 2
				table.insert(
					items,
					s:New("Frame")({
						Position = UDim2.fromOffset(x + CELL_W, cy),
						Size = UDim2.fromOffset(GAP_X / 2, 1),
						BackgroundColor3 = LINE,
						BorderSizePixel = 0,
					})
				)
				if j % 2 == 1 then
					local other = centreY(r, j + 1)
					table.insert(
						items,
						s:New("Frame")({
							Position = UDim2.fromOffset(midX, cy),
							Size = UDim2.fromOffset(1, other - cy),
							BackgroundColor3 = LINE,
							BorderSizePixel = 0,
						})
					)
					table.insert(
						items,
						s:New("Frame")({
							Position = UDim2.fromOffset(midX, (cy + other) / 2),
							Size = UDim2.fromOffset(GAP_X / 2, 1),
							BackgroundColor3 = LINE,
							BorderSizePixel = 0,
						})
					)
				end
			end
		end
		return items
	end)

	local frame = scope:New("ScrollingFrame")({
		Name = "TourneyBracket",
		LayoutOrder = props.LayoutOrder,
		Size = scope:Computed(function(use): UDim2
			local h = if props.Height then use(props.Height) else 360
			return UDim2.new(1, 0, 0, h)
		end),
		BackgroundColor3 = Theme.Paper.Surface,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Paper.Rule,
		ScrollingDirection = Enum.ScrollingDirection.XY,
		CanvasSize = scope:Computed(function(use): UDim2
			local c = use(canvas)
			return UDim2.fromOffset(c.X + 8, c.Y + 8)
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("Frame")({
				Name = "Content",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(4, 4),
				Size = scope:Computed(function(use): UDim2
					local c = use(canvas)
					return UDim2.fromOffset(c.X, c.Y)
				end),
				[Children] = content :: any,
			}),
		},
	}) :: ScrollingFrame
	-- start at the player's current round (once per change of the view's shape)
	local lastTarget: Vector2? = nil
	scope:Observer(scrollTo):onBind(function()
		local target = Fusion.peek(scrollTo)
		if lastTarget == nil or (lastTarget - target).Magnitude > 1 then
			lastTarget = target
			frame.CanvasPosition = target
		end
	end)
	return frame
end

return TourneyBracket
