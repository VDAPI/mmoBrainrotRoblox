--!strict
-- Party finder board (S134f, DESIGN §17): the "Looking for a party" tab of the party window. On top "My listing":
-- kind -> target (default: the one nearest the player's level), the level band narrowed with -/+ (never wider than
-- the data's band, Logic/PartyFinder.clampBand), wanted classes, Post / Renew / Remove. Below, the listings of this
-- server (state branch `finder`, sent only while this tab is open: FinderWatch): target, band coloured by
-- Logic/LevelBand against the player, leader with class and level, party size, wanted classes, time left, Join (greyed
-- out with canJoin's reason, the same rule as the server) and Guide. No free text (moderation).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local Net = require(ReplicatedStorage.Shared.Net)
local PartyFinder = require(ReplicatedStorage.Shared.Logic.PartyFinder)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Kind = PartyFinder.Kind
type Listing = PartyFinder.Listing

export type Props = {
	-- Guide to a place (map-relative); nil = no "Guide" buttons.
	Guide: ((place: PartyFinder.Place, labelKey: string) -> ())?,
}

local ROW = 64
local MAX = Config.PartyFinder.maxMembers

local function invoke(name: string, ...: any): boolean
	local ok, err = Net.Invoke(name, ...)
	if not ok then
		Sounds.play("error")
		Toast.push(Text.now(err or "error.internal"), "error")
	end
	return ok
end

local function small(scope: Scope, props: { [string]: any }): Instance
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.BodyMedium,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Paper.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in props do
		base[key] = value
	end
	return scope:New("TextLabel")(base :: any)
end

local function PartyFinderTab(scope: Scope, props: Props): Instance
	local board = State.Value({ "finder" })
	local level = State.Value({ "character", "level" })
	local classId = State.Value({ "character", "class" })
	local party = State.Value({ "party" })
	local worldEvent = State.Value({ "worldEvent" })
	local myId = game:GetService("Players").LocalPlayer.UserId

	Net.Send("FinderWatch", true)
	table.insert(scope, function()
		Net.Send("FinderWatch", false)
	end)

	local now = scope:Value(Workspace:GetServerTimeNow())
	local acc = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt: number)
			acc += dt
			if acc >= 1 then
				acc = 0
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)

	-- My listing ----------------------------------------------------------------------------------------------
	local kind: Fusion.Value<Kind> = scope:Value("ground" :: Kind) :: any
	local targetIndex = scope:Value(1)
	local wantMin = scope:Value(nil :: number?)
	local wantMax = scope:Value(nil :: number?)
	local want = scope:Value({} :: { string })

	-- The targets of the kind (the Invasion: the running event only).
	local targets = scope:Computed(function(use): { PartyFinder.Target }
		local k = use(kind)
		if k == "invasion" then
			local e = use(worldEvent)
			if type(e) == "table" and e.kind == "invasion" and type(e.level) == "number" then
				return {
					{ kind = "invasion", id = e.id, nameKey = "finder.kind.invasion", level = e.level, top = e.level },
				}
			end
			return {}
		end
		return PartyFinder.targets(k :: Kind)
	end)
	local function pickNearest()
		local k = Fusion.peek(kind)
		local near = PartyFinder.nearest(k :: Kind, tonumber(Fusion.peek(level)) or 1)
		local list = Fusion.peek(targets)
		local index = 1
		for i, target in list do
			if near and target.id == near.id then
				index = i
			end
		end
		targetIndex:set(index)
		wantMin:set(nil)
		wantMax:set(nil)
	end
	pickNearest()
	local target = scope:Computed(function(use): PartyFinder.Target?
		local list = use(targets)
		return list[math.clamp(use(targetIndex), 1, math.max(1, #list))]
	end)
	local band = scope:Computed(function(use): { number }
		local t = use(target)
		if not t then
			return { 1, 1 }
		end
		local lo, hi = PartyFinder.bandFor(t.kind, t.level, t.top)
		local a, b = PartyFinder.clampBand(lo, hi, use(wantMin), use(wantMax))
		return { a, b, lo, hi }
	end)
	local mine = scope:Computed(function(use): number?
		local b = use(board)
		return if type(b) == "table" then b.mine else nil
	end)

	local function cycleKind(step: number)
		local kinds = PartyFinder.KINDS
		local index = table.find(kinds, Fusion.peek(kind)) or 1
		kind:set(kinds[(index - 1 + step) % #kinds + 1])
		pickNearest()
	end
	local function cycleTarget(step: number)
		local count = #Fusion.peek(targets)
		if count > 0 then
			targetIndex:set((Fusion.peek(targetIndex) - 1 + step) % count + 1)
			wantMin:set(nil)
			wantMax:set(nil)
		end
	end
	local function nudge(which: "min" | "max", step: number)
		local b = Fusion.peek(band)
		if which == "min" then
			wantMin:set(math.clamp(b[1] + step, b[3] or b[1], b[2]))
		else
			wantMax:set(math.clamp(b[2] + step, b[1], b[4] or b[2]))
		end
	end
	local function toggleClass(id: string)
		local list = table.clone(Fusion.peek(want))
		local at = table.find(list, id)
		if at then
			table.remove(list, at)
		elseif #list < Config.PartyFinder.maxWant then
			table.insert(list, id)
		end
		want:set(list)
	end
	local function postNow()
		local t = Fusion.peek(target)
		if not t then
			Toast.push(Text.now("finder.error.target"), "warning")
			return
		end
		local b = Fusion.peek(band)
		task.spawn(function()
			if invoke("FinderPost", t.kind, t.id, b[1], b[2], Fusion.peek(want)) then
				Sounds.play("click")
				Toast.push(Text.now("finder.posted"), "success")
			end
		end)
	end

	local function stepper(s: Scope, text: Fusion.UsedAs<string>, onLeft: () -> (), onRight: () -> (), width: number)
		return s:New("Frame")({
			Size = UDim2.fromOffset(width, 44),
			BackgroundTransparency = 1,
			[Children] = {
				Button(s, {
					Size = UDim2.fromOffset(44, 44),
					Text = "−",
					OnClick = onLeft,
				}),
				small(s, {
					Position = UDim2.fromOffset(48, 0),
					Size = UDim2.new(1, -96, 1, 0),
					Text = text,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = Theme.Paper.Text,
				}),
				Button(s, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(44, 44),
					Text = "+",
					OnClick = onRight,
				}),
			},
		})
	end

	local classButtons = {}
	for i, id in Classes.order do
		local class = Classes.get(id)
		table.insert(
			classButtons,
			Button(scope, {
				LayoutOrder = i,
				Size = UDim2.fromOffset(44, 44),
				Text = if class then class.icon else "?",
				Variant = scope:Computed(function(use): any
					return if table.find(use(want), id) then "primary" else "secondary"
				end),
				OnClick = function()
					toggleClass(id)
				end,
			})
		)
	end

	local myListing = scope:New("Frame")({
		Name = "Mine",
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Paper.Raised,
		BackgroundTransparency = 0.35,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			scope:New("UIGridLayout")({
				CellSize = UDim2.fromOffset(290, 44),
				CellPadding = UDim2.fromOffset(8, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			small(scope, {
				LayoutOrder = 0,
				Text = Text.T(scope, "finder.mine"),
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = Theme.Paper.Heading,
			}),
			small(scope, {
				LayoutOrder = 1,
				Text = scope:Computed(function(use): string
					local m = use(mine)
					return if m then Text.get(use, "finder.mineActive") else Text.get(use, "finder.mineNone")
				end),
				TextColor3 = Theme.Paper.TextMuted,
			}),
			stepper(
				scope,
				scope:Computed(function(use): string
					return Text.get(use, `finder.kind.{use(kind)}`)
				end),
				function()
					cycleKind(-1)
				end,
				function()
					cycleKind(1)
				end,
				290
			),
			stepper(
				scope,
				scope:Computed(function(use): string
					local t = use(target)
					if not t then
						return Text.get(use, "finder.noTarget")
					end
					return `{Text.get(use, t.nameKey)} ({t.level})`
				end),
				function()
					cycleTarget(-1)
				end,
				function()
					cycleTarget(1)
				end,
				290
			),
			stepper(
				scope,
				scope:Computed(function(use): string
					return Text.get(use, "finder.levelMin", { level = use(band)[1] })
				end),
				function()
					nudge("min", -1)
				end,
				function()
					nudge("min", 1)
				end,
				290
			),
			stepper(
				scope,
				scope:Computed(function(use): string
					return Text.get(use, "finder.levelMax", { level = use(band)[2] })
				end),
				function()
					nudge("max", -1)
				end,
				function()
					nudge("max", 1)
				end,
				290
			),
			scope:New("Frame")({
				LayoutOrder = 10,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					small(scope, {
						LayoutOrder = 0,
						Size = UDim2.fromOffset(90, 44),
						Text = Text.T(scope, "finder.want"),
						TextColor3 = Theme.Paper.TextMuted,
					}),
					classButtons :: any,
				},
			}),
			scope:New("Frame")({
				LayoutOrder = 11,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					Button(scope, {
						LayoutOrder = 1,
						Size = UDim2.fromOffset(140, 44),
						Variant = "primary",
						TextSize = Theme.TextSize.Small,
						Text = scope:Computed(function(use): string
							return Text.get(use, if use(mine) then "finder.renew" else "finder.post")
						end),
						OnClick = postNow,
					}),
					Button(scope, {
						LayoutOrder = 2,
						Size = UDim2.fromOffset(140, 44),
						Variant = "danger",
						TextSize = Theme.TextSize.Small,
						Text = Text.T(scope, "finder.remove"),
						Disabled = scope:Computed(function(use): boolean
							return use(mine) == nil
						end),
						OnClick = function()
							task.spawn(invoke, "FinderCancel")
						end,
					}),
				},
			}),
		},
	})

	-- The board ------------------------------------------------------------------------------------------------
	local filter = scope:Value("all")
	local filters = { "all", "boss", "elite2", "invasion", "ground" }
	local filterButtons = {}
	for i, id in filters do
		table.insert(
			filterButtons,
			Button(scope, {
				LayoutOrder = i,
				Size = UDim2.fromOffset(110, 40),
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, if id == "all" then "finder.all" else `finder.kind.{id}`),
				Variant = scope:Computed(function(use): any
					return if use(filter) == id then "primary" else "secondary"
				end),
				OnClick = function()
					filter:set(id)
				end,
			})
		)
	end

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local b = use(board)
		local out: { Instance } = {}
		local list: { Listing } = if type(b) == "table" and type(b.listings) == "table" then b.listings else {}
		local f = use(filter)
		local myLevel = tonumber(use(level)) or 1
		local joiner = {
			id = myId,
			level = myLevel,
			class = tostring(use(classId) or ""),
			inParty = type(use(party)) == "table",
		}
		local t = use(now)
		for i, listing in list do
			if f ~= "all" and listing.kind ~= f then
				continue
			end
			local ok, why = PartyFinder.canJoin(listing, joiner, t)
			local leaderClass = Classes.get(listing.leaderClass)
			local wantIcons = {}
			for _, id in listing.want do
				local class = Classes.get(id)
				table.insert(wantIcons, if class then class.icon else id)
			end
			local bandColor = Theme.readable(LevelBand.COLORS[LevelBand.of(listing.level, myLevel)], "paper")
			local place = listing.at
			local guide = props.Guide
			local kindLabel = Text.get(use, "finder.kind." .. listing.kind)
			local expires = Text.get(use, "finder.expires", { time = Time.format(math.max(0, listing.expiresAt - t)) })
			local levels = Text.get(use, "finder.level", { min = listing.minLevel, max = listing.maxLevel })
			local wanted = if #wantIcons > 0 then table.concat(wantIcons, " ") else Text.get(use, "finder.anyClass")
			local leaderIcon = if leaderClass then leaderClass.icon else ""
			local reason = if ok then "" else "  ·  " .. Text.get(use, why or "error.internal")
			table.insert(
				out,
				s:New("Frame")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, ROW),
					BackgroundColor3 = Theme.Paper.Raised,
					BackgroundTransparency = if ok then 0.35 else 0.6,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						small(s, {
							Position = UDim2.fromOffset(8, 4),
							Size = UDim2.new(1, -260, 0, 22),
							Text = `{kindLabel}: {Text.get(use, listing.nameKey)}`,
							FontFace = Theme.Fonts.BodyBold,
							TextColor3 = if ok then Theme.Paper.Heading else Theme.Paper.TextMuted,
						}),
						small(s, {
							Position = UDim2.fromOffset(8, 24),
							Size = UDim2.new(1, -260, 0, 18),
							Text = `{levels}  ·  {listing.size}/{MAX}  ·  {expires}`,
							TextColor3 = bandColor,
						}),
						small(s, {
							Position = UDim2.fromOffset(8, 42),
							Size = UDim2.new(1, -260, 0, 18),
							Text = `{leaderIcon} {listing.leaderName} ({listing.leaderLevel})  ·  {Text.get(
								use,
								"finder.want"
							)} {wanted}{reason}`,
							TextColor3 = if ok then Theme.Paper.Text else Theme.Paper.Warning,
						}),
						Button(s, {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -126, 0.5, 0),
							Size = UDim2.fromOffset(116, 44),
							TextSize = Theme.TextSize.Small,
							Text = Text.T(s, "finder.guide"),
							Visible = guide ~= nil and place ~= nil,
							OnClick = function()
								if guide and place then
									guide(place, listing.nameKey)
								end
							end,
						}),
						Button(s, {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -6, 0.5, 0),
							Size = UDim2.fromOffset(114, 44),
							Variant = "primary",
							TextSize = Theme.TextSize.Small,
							Text = Text.T(s, "finder.join"),
							Disabled = not ok,
							OnClick = function()
								task.spawn(function()
									if invoke("FinderJoin", listing.id) then
										Sounds.play("levelUp")
									end
								end)
							end,
						}),
					},
				})
			)
		end
		if #out == 0 then
			table.insert(
				out,
				small(s, {
					Size = UDim2.new(1, 0, 0, 40),
					Text = Text.get(use, "finder.none"),
					TextColor3 = Theme.Paper.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			)
		end
		return out
	end)

	return scope:New("ScrollingFrame")({
		Name = "PartyFinder",
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
			myListing,
			scope:New("ScrollingFrame")({
				Name = "Filter",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 48),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				ScrollingDirection = Enum.ScrollingDirection.X,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					filterButtons :: any,
				},
			}),
			scope:New("Frame")({
				Name = "Listings",
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
					rows :: any,
				},
			}),
		},
	})
end

return PartyFinderTab
