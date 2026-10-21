--!strict
-- The title in the backpack window (owner 2026-10-21: "the title button is invisible; a click should show the list of
-- every title I own and let me pick one"). Replaces the S16 "◀ title ▶" cycler (ghost arrows that did not read as
-- buttons, and a cycle instead of a choice).
--   TitleChooser.Picker(scope, { LayoutOrder, Open, State, Touch }): the current title (medallion, colour, time left of
--     a timed title) and a clearly visible "Change title" button that opens the list.
--   TitleChooser.Panel(scope, { Open, State, Touch }): the list over the whole window (dimmed backdrop, tap outside or
--     "Close" closes it): "No title" first, then every unlocked title (Logic/Titles.choices) with its colour, where it
--     comes from (Titles.sourceOf) and the worn one marked. A row sends SetTitle; the server checks the title is
--     unlocked (TitleService, Titles.isUnlocked) and refuses a locked one.
-- `State` is shared by the two (TitleChooser.state): the unlocked list, the shown title and the clock of timed titles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ListRow = require(script.Parent.Parent.Parent.Components.ListRow)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local TitleText = require(script.Parent.Parent.Parent.TitleText)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Titles = require(ReplicatedStorage.Shared.Logic.Titles)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local TIMED_TICK = 30 -- S125: s between checks of the timed titles (the list and the time left)
local PANEL_WIDTH = 440
local PANEL_MAX_HEIGHT = 560
local DIM = 0.45

export type ChooserState = {
	character: any, -- Fusion state of { "character" }
	clock: any, -- Fusion.Value<number>
	choices: any, -- Fusion.Computed<{ Titles.Choice }>
	current: any, -- Fusion.Computed<string?>
	busy: any, -- Fusion.Value<boolean>
}

local TitleChooser = {}

function TitleChooser.state(scope: Scope): ChooserState
	local character = State.Value({ "character" })
	local vip = State.Value({ "vip", "active" }) -- S121: the VIP title
	local owned = State.Value({ "account", "cosmetics", "owned" }) -- S123: bought titles
	local achDone = State.Value({ "account", "ach", "done" }) -- S151: account achievement titles
	-- S125: timed titles need the time (the server clock with the /time offset), refreshed every TIMED_TICK s
	local clock = scope:Value(Clock.now())
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(TIMED_TICK)
			if alive then
				clock:set(Clock.now())
			end
		end
	end)
	local ctx = scope:Computed(function(use): Titles.Context
		return Titles.contextOf(
			{ cosmetics = { owned = use(owned) }, ach = { done = use(achDone) } },
			use(vip) == true,
			use(clock)
		)
	end)
	local choices = scope:Computed(function(use): { Titles.Choice }
		return Titles.choices(use(character), nil, use(ctx))
	end)
	local current = scope:Computed(function(use): string?
		for _, choice in use(choices) do
			if choice.current then
				return choice.id
			end
		end
		return nil
	end)
	return { character = character, clock = clock, choices = choices, current = current, busy = scope:Value(false) }
end

-- The name of a title as the nameplate writes it (an arena season title with its season), plus the time left of a
-- timed title when `withTime`.
local function titleName(use: Fusion.Use, st: ChooserState, def: TitleData.TitleDef, withTime: boolean): string
	if def.req.kind == "timed" and withTime then
		local untilTs = Titles.timedUntil(use(st.character), def.id) or 0
		local d, h = Time.split(untilTs - use(st.clock))
		return `{Text.get(use, def.nameKey)} {Text.get(use, "title.timedLeft", { d = d, h = h })}`
	end
	local args = Titles.argsOf(use(st.character), def.id)
	return TitleText.get(use, def, if args then args.season else nil)
end

export type PickerProps = {
	LayoutOrder: number,
	Open: Fusion.Value<boolean>,
	State: ChooserState,
	Touch: boolean,
}

-- The current title and the "Change title" button (secondary: a filled, framed button on the parchment).
function TitleChooser.Picker(scope: Scope, props: PickerProps): Instance
	local st = props.State
	local buttonHeight = if props.Touch then Theme.Size.MinTouch else 34
	local medal = scope:Computed(function(use): string?
		local id = use(st.current)
		return if id then UiArt.title(id) else nil
	end)
	local medalShown = ArtIcon.Shown(scope, medal)
	local count = scope:Computed(function(use): number
		return #use(st.choices) - 1
	end)
	return scope:New("Frame")({
		Name = "Title",
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 26 + 4 + buttonHeight),
		BackgroundTransparency = 1,
		[Children] = {
			-- S119: the title's medallion before its name once loaded (the name moves right by its width)
			ArtIcon.Image(scope, {
				Key = medal,
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.fromOffset(4, 1),
			}) :: any,
			scope:New("TextLabel")({
				Name = "Current",
				Position = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(if use(medalShown) then 32 else 4, 0)
				end),
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, if use(medalShown) then -36 else -8, 0, 26)
				end),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local id = use(st.current)
					local def = if id then TitleData.get(id) else nil
					if def then
						return `« {titleName(use, st, def, true)} »`
					end
					return Text.get(use, "title.none", { count = use(count) })
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					local id = use(st.current)
					local def = if id then TitleData.get(id) else nil
					return if def then Theme.readable(def.color, "paper") else Theme.Paper.TextMuted
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Button(scope, {
				Position = UDim2.fromOffset(0, 30),
				Size = UDim2.new(1, 0, 0, buttonHeight),
				Text = Text.T(scope, "title.change"),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				OnClick = function()
					props.Open:set(true)
				end,
			}),
		},
	})
end

export type PanelProps = {
	Open: Fusion.Value<boolean>,
	State: ChooserState,
	Touch: boolean,
}

-- The list of owned titles over the whole window.
function TitleChooser.Panel(scope: Scope, props: PanelProps): Instance
	local st = props.State
	local open = props.Open
	local function close()
		open:set(false)
	end
	local function choose(id: string?)
		if Fusion.peek(st.busy) then
			return
		end
		if id == Fusion.peek(st.current) then
			close()
			return
		end
		st.busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("SetTitle", id)
			st.busy:set(false)
			if ok then
				close()
			else
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end
	local rowHeight = Theme.Size.RowHeight + (if props.Touch then 4 else 0)
	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local out: { Instance } = {}
		for index, choice in use(st.choices) do
			local id = choice.id
			local def = if id then TitleData.get(id) else nil
			local sub: Fusion.UsedAs<string>
			local main: Fusion.UsedAs<string>
			if def then
				local key, args = Titles.sourceOf(def)
				sub = Text.T(s, key, args)
				main = s:Computed(function(use2): string
					return `<font color="{Theme.readableHex(def.color, "paper")}">{titleName(use2, st, def, true)}</font>`
				end)
			else
				sub = Text.T(s, "title.pick.noneSub")
				main = Text.T(s, "title.pick.none")
			end
			table.insert(
				out,
				ListRow(s, {
					Name = id or "None",
					LayoutOrder = index,
					Index = index,
					Height = rowHeight,
					RichText = true,
					Text = main,
					Sub = sub,
					Value = if choice.current then Text.T(s, "title.pick.current") else nil,
					Selected = choice.current,
					OnClick = function()
						choose(id)
					end,
				})
			)
		end
		return out
	end)
	local headerHeight = if props.Touch then Theme.Size.MinTouch else 40
	return scope:New("TextButton")({
		Name = "TitleChooser",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		BackgroundColor3 = Theme.Shade,
		BackgroundTransparency = DIM,
		AutoButtonColor = false,
		Text = "",
		Active = true,
		Visible = open,
		[OnEvent("Activated")] = close,
		[Children] = {
			scope:New("Frame")({
				Name = "Panel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = if props.Touch then UDim2.new(1, -24, 1, -16) else UDim2.new(0, PANEL_WIDTH, 1, -48),
				BackgroundColor3 = Theme.Paper.Surface,
				BorderSizePixel = 0,
				Active = true, -- clicks inside never reach the backdrop
				[Children] = {
					scope:New("UISizeConstraint")({
						MaxSize = Vector2.new(if props.Touch then 520 else PANEL_WIDTH, PANEL_MAX_HEIGHT),
					}),
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Theme.Brass.Frame,
						Thickness = 3,
					}),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, Theme.Padding.Medium),
						PaddingBottom = UDim.new(0, Theme.Padding.Medium),
						PaddingLeft = UDim.new(0, Theme.Padding.Medium),
						PaddingRight = UDim.new(0, Theme.Padding.Medium),
					}),
					scope:New("TextLabel")({
						Name = "Heading",
						Size = UDim2.new(1, -110, 0, headerHeight),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local n = #use(st.choices) - 1
							return `{Text.get(use, "title.pick.title")}  ·  {Text.get(
								use,
								"title.pick.count",
								{ count = n }
							)}`
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Paper.Heading,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(100, headerHeight),
						Text = Text.T(scope, "title.pick.close"),
						Variant = "secondary",
						TextSize = Theme.TextSize.Small,
						OnClick = close,
					}),
					scope:New("ScrollingFrame")({
						Name = "List",
						Position = UDim2.fromOffset(0, headerHeight + Theme.Padding.Small),
						Size = UDim2.new(1, 0, 1, -(headerHeight + Theme.Padding.Small)),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						ScrollBarThickness = if props.Touch then 6 else 4,
						ScrollBarImageColor3 = Theme.Paper.Label,
						[Children] = {
							scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
							rows :: any,
						},
					}),
				},
			}),
		},
	})
end

return TitleChooser
