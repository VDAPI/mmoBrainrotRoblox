--!strict
-- Login reward window (S100, docs/DESIGN-15.md §5): the streak day, seven day cards with the reward at the
-- character's level (Logic/LoginReward.week), the claiming character and "Claim", or "Claimed today" with tomorrow's
-- day and a countdown to the next UTC day. After a claim the received reward is shown (the chest item with its full
-- tooltip). PC: the cards in one row; touch (fullscreen window): two rows of four, the footer pinned to the bottom.
-- Reads narrow state branches only (account.login, the character's level, class and name).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local CurrencyIcon = require(script.Parent.Parent.Components.CurrencyIcon)
local Device = require(script.Parent.Parent.Device)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local LoginReward = require(ReplicatedStorage.Shared.Logic.LoginReward)
local QuestRewards = require(script.Parent.Parent.Components.QuestRewards)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Claim: () -> (boolean, string?, any?), -- Net.Invoke("ClaimLoginReward")
	Close: () -> (),
}

type Result = { day: number, gold: number, items: { Types.ItemInstance }, mailed: boolean }

local HEADER = 48 -- title 26 + gap 2 + reset note 20; with FOOTER the PC cards fit the 424 px content in one row
local FOOTER = 132
local CARD_HEIGHT = 236
local CARD_HEIGHT_TOUCH = 150
local SLOT = 36
local CHEST_GLYPH = "▣"

local function label(scope: Scope, props: { [string]: any }): Instance
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Colors.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
	}
	for key, value in props do
		base[key] = value
	end
	return scope:New("TextLabel")(base :: any)
end

-- One day card: number, contents, state (claimed ✓ / today in gold / future).
local function card(
	scope: Scope,
	n: number,
	contents: LoginReward.Contents,
	classId: string,
	status: Fusion.UsedAs<LoginReward.Status>,
	pulse: Fusion.UsedAs<boolean>
): Instance
	local isToday = scope:Computed(function(use): boolean
		return use(status).day == n
	end)
	local done = scope:Computed(function(use): boolean
		local s = use(status)
		return n < s.day or (n == s.day and s.claimedToday)
	end)
	local reward = { exp = 0, gold = contents.gold, items = contents.items }
	local class = Classes.get(classId)
	return scope:New("Frame")({
		Name = `Day{n}`,
		LayoutOrder = n,
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if use(isToday) then Theme.Colors.PanelRaised else Theme.Colors.Panel
		end),
		BackgroundTransparency = scope:Computed(function(use): number
			return if use(done) and not use(isToday) then 0.55 else 0.05
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = scope:Computed(function(use): Color3
					return if use(isToday) then Theme.Colors.GoldBright else Theme.Colors.Border
				end),
				Thickness = scope:Tween(
					scope:Computed(function(use): number
						if not use(isToday) then
							return Theme.Stroke.Thin
						end
						return if use(pulse) then 6 else Theme.Stroke.Thick
					end),
					Theme.Anim.Slow
				),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			label(scope, {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 22),
				Text = scope:Computed(function(use): string
					local text = Text.get(use, "login.day", { n = n })
					return if use(done) then `{text}  ✓` else text
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = scope:Computed(function(use): Color3
					if use(isToday) then
						return Theme.Colors.GoldBright
					end
					return if use(done) then Theme.Colors.TextMuted else Theme.Colors.Parchment
				end),
			}),
			QuestRewards(scope, {
				Id = `login{n}`,
				Reward = reward :: any,
				SlotSize = SLOT,
				LayoutOrder = 2,
				Width = UDim.new(1, 0),
			}),
			if contents.chest
				then label(scope, {
					LayoutOrder = 3,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Text = scope:Computed(function(use): string
						local className = if class then Text.get(use, class.nameKey) else classId
						return `{CHEST_GLYPH} {Text.get(use, "login.chest", { class = className })}`
					end),
					TextColor3 = Theme.Colors.GoldBright,
					TextSize = 14,
				}) :: any
				else nil,
		},
	})
end

local function LoginRewardWindow(scope: Scope, props: Props): Instance
	local login = State.Value({ "account", "login" })
	local level = State.Value({ "character", "level" })
	local classId = State.Value({ "character", "class" })
	local name = State.Value({ "character", "name" })

	-- The clock (every second): only texts and the status change, nothing is rebuilt.
	local now = scope:Value(Clock.now())
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(1)
			if alive then
				now:set(Clock.now())
			end
		end
	end)

	local state = scope:Computed(function(use): LoginReward.State
		return LoginReward.sanitize(use(login))
	end)
	local status = scope:Computed(function(use): LoginReward.Status
		return LoginReward.status(use(state), Time.dayNumber(use(now)))
	end)
	local busy = scope:Value(false)
	local pulse = scope:Value(false)
	local result = scope:Value(nil :: Result?)
	local touch = Device.Touch

	local function claim()
		if Fusion.peek(busy) then
			return
		end
		busy:set(true)
		task.spawn(function()
			local ok, err, got = props.Claim()
			busy:set(false)
			if not ok then
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
				return
			end
			Sounds.play("levelUp")
			if type(got) == "table" then
				result:set(got :: Result)
			end
			pulse:set(true)
			task.delay(0.45, function()
				if alive then
					pulse:set(false)
				end
			end)
		end)
	end

	-- Cards: rebuilt only when the level or the class changes.
	local cards = scope:Computed(function(use, s: Scope): { Instance }
		local L = use(level)
		local c = use(classId)
		local lvl = if type(L) == "number" then L else 1
		local class = if type(c) == "string" then c else ""
		local list = {}
		for n, contents in LoginReward.week(lvl, class) do
			table.insert(list, card(s, n, contents, class, status, pulse))
		end
		return list
	end)

	local header = scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
			label(scope, {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 26),
				Text = scope:Computed(function(use): string
					return `{Text.get(use, "login.title")} · {Text.get(use, "login.streak", { day = use(status).day })}`
				end),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.GoldBright,
			}),
			label(scope, {
				LayoutOrder = 2,
				Text = Text.T(scope, "login.reset"),
				TextColor3 = Theme.Colors.Warning,
				Visible = scope:Computed(function(use): boolean
					return use(status).resets
				end),
			}),
		},
	})

	local cardArea = scope:New("ScrollingFrame")({
		Name = "Cards",
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.new(1, 0, 1, -(HEADER + FOOTER)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		[Children] = {
			scope:New("UIGridLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				CellPadding = UDim2.fromOffset(Theme.Padding.Small, Theme.Padding.Small),
				CellSize = scope:Computed(function(use): UDim2
					if use(touch) then
						return UDim2.new(0.25, -8, 0, CARD_HEIGHT_TOUCH)
					end
					return UDim2.new(1 / 7, -8, 0, CARD_HEIGHT)
				end),
			}),
			cards :: any,
		},
	})

	-- The received reward (after a claim in this window): gold, then each item with its tooltip.
	local received = scope:Computed(function(use, s: Scope): Instance?
		local got = use(result)
		if not got then
			return nil
		end
		local row: { Instance } = {
			label(s, {
				LayoutOrder = 0,
				Size = UDim2.fromOffset(0, SLOT),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = Text.T(s, "login.got"),
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = Theme.Colors.GoldBright,
			}),
		}
		if got.gold > 0 then
			-- Gold as its own auto-width chip (the item slots follow it in the row)
			table.insert(
				row,
				s:New("Frame")({
					Name = "Gold",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(0, SLOT),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					[Children] = {
						s:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 4),
						}),
						CurrencyIcon(s, { Currency = "gold", Size = UDim2.fromOffset(20, 20), LayoutOrder = 1 }),
						s:New("TextLabel")({
							LayoutOrder = 2,
							Size = UDim2.fromOffset(0, 20),
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							Text = Format.number(got.gold),
							FontFace = Theme.Fonts.BodyBold,
							TextSize = 16,
							TextColor3 = Theme.Colors.Parchment,
						}),
					},
				})
			)
		end
		for i, item in got.items do
			table.insert(
				row,
				ItemSlot(s, {
					SlotId = `view:login:got:{i}`,
					Item = item,
					Size = SLOT,
					LayoutOrder = 1 + i,
					TooltipCtx = { hints = false, merchantOpen = false },
				})
			)
		end
		return s:New("Frame")({
			Name = "Received",
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = {
				s:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Wraps = true,
					Padding = UDim.new(0, 8),
				}),
				row :: any,
			},
		})
	end)

	local claimable = scope:Computed(function(use): boolean
		return use(status).claimable
	end)
	local claimed = scope:Computed(function(use): boolean
		return use(status).claimedToday
	end)

	local footer = scope:New("Frame")({
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FOOTER),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 4),
			}),
			received :: any,
			label(scope, {
				LayoutOrder = 2,
				Text = Text.T(scope, "login.mailed"),
				TextColor3 = Theme.Colors.Warning,
				Visible = scope:Computed(function(use): boolean
					local got = use(result)
					return got ~= nil and got.mailed == true
				end),
			}),
			label(scope, {
				LayoutOrder = 3,
				Text = scope:Computed(function(use): string
					local L = use(level)
					return Text.get(use, "login.claimFor", {
						name = use(name) or "",
						level = if type(L) == "number" then L else 1,
					})
				end),
				TextColor3 = Theme.Colors.TextMuted,
				Visible = claimable,
			}),
			label(scope, {
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = scope:Computed(function(use): string
					local s = use(status)
					local tomorrow = if s.day >= LoginReward.DAYS
						then Text.get(use, "login.nextRestart")
						else Text.get(use, "login.next", { next = s.nextDay })
					local left = Time.format(Time.remaining(Time.nextDayAt(use(now)), use(now)))
					return `{Text.get(use, "login.claimed")} {tomorrow}\n{Text.get(use, "login.timer", { time = left })}`
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextColor3 = Theme.Colors.Parchment,
				Visible = claimed,
			}),
			Button(scope, {
				Name = "Claim",
				LayoutOrder = 5,
				Text = Text.T(scope, "login.claim"),
				Variant = "primary",
				Size = UDim2.fromOffset(220, Theme.Size.ButtonHeight),
				Disabled = busy,
				Visible = claimable,
				OnClick = claim,
			}),
		},
	})

	return scope:New("Frame")({
		Name = "LoginReward",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = { header, cardArea, footer },
	})
end

return LoginRewardWindow
