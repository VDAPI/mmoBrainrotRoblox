--!strict
-- Guild window, "Settings" tab: PvP protection between members (leader switches it), S159g: the banner (emblem and
-- colour, more with the guild level; the leader picks) and the rights table of the ranks below the leader (the leader
-- switches rights and sets daily bank limits, others read it), the chat channel hint, leave the guild, disband it
-- (leader, confirmed by typing the guild name).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Common = require(script.Parent.Common)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Guild = require(ReplicatedStorage.Shared.Logic.Guild)
local GuildBanners = require(ReplicatedStorage.Shared.Data.GuildBanners)
local GuildProgressData = require(ReplicatedStorage.Shared.Data.GuildProgress)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local CELL = 120 -- width of a rank column in the rights table
local ROW = 40

-- A horizontal row of square picker buttons (emblems or colours).
local function pickerRow(scope: Scope, order: number, children: { Instance }): Instance
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIGridLayout")({
				CellSize = UDim2.fromOffset(48, 48),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			children :: any,
		},
	})
end

local function bannerPicker(scope: Scope, guild: Fusion.Value<any>, isLeader: Fusion.Computed<boolean>): { Instance }
	local function current(use: Fusion.Use): (string, string, number)
		local g = use(guild)
		local e, c = Guild.banner(if type(g) == "table" then { banner = g.banner } else nil)
		return e, c, if type(g) == "table" then g.level or 1 else 1
	end
	local function pick(emblem: string?, colour: string?)
		local g = State.Get({ "guild" })
		local e, c = Guild.banner(if type(g) == "table" then { banner = g.banner } else nil)
		task.spawn(Common.invoke, "GuildSetBanner", emblem or e, colour or c)
	end
	local emblems = {}
	for i, def in GuildBanners.EMBLEMS do
		table.insert(
			emblems,
			scope:New("TextButton")({
				LayoutOrder = i,
				AutoButtonColor = false,
				BackgroundColor3 = scope:Computed(function(use): Color3
					local e = current(use)
					return if e == def.id then Theme.Paper.Selected else Theme.Paper.Raised
				end),
				Text = def.glyph,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = scope:Computed(function(use): Color3
					local _, _, level = current(use)
					return if level >= def.level then Theme.Paper.Heading else Theme.Paper.Rule
				end),
				Active = isLeader,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 8),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
				},
				[Fusion.OnEvent("Activated")] = function()
					if Fusion.peek(isLeader) then
						pick(def.id, nil)
					end
				end,
			})
		)
	end
	local colours = {}
	for i, def in GuildBanners.COLOURS do
		table.insert(
			colours,
			scope:New("TextButton")({
				LayoutOrder = i,
				AutoButtonColor = false,
				BackgroundColor3 = Theme.tint(def.hex),
				Text = scope:Computed(function(use): string
					local _, c, level = current(use)
					if level < def.level then
						return tostring(def.level)
					end
					return if c == def.id then "✔" else ""
				end),
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = Theme.Plain,
				TextStrokeTransparency = 0.3,
				Active = isLeader,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						Color = scope:Computed(function(use): Color3
							local _, c = current(use)
							return if c == def.id then Theme.Paper.Heading else Theme.Paper.Rule
						end),
						Thickness = 2,
					}),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 10),
						PaddingBottom = UDim.new(0, 10),
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
					}),
				},
				[Fusion.OnEvent("Activated")] = function()
					if Fusion.peek(isLeader) then
						pick(nil, def.id)
					end
				end,
			})
		)
	end
	return {
		Common.heading(scope, 20, Text.T(scope, "guild.banner.title")),
		Common.paragraph(
			scope,
			21,
			scope:Computed(function(use): string
				return Text.get(use, if use(isLeader) then "guild.banner.hint" else "guild.banner.hintMember")
			end)
		),
		pickerRow(scope, 22, emblems),
		pickerRow(scope, 23, colours),
	}
end

-- One cell of the rights table: a switch (leader) or a mark (others).
local function rightCell(
	scope: Scope,
	guild: Fusion.Value<any>,
	isLeader: Fusion.Computed<boolean>,
	rank: string,
	action: string,
	order: number
): Instance
	local on = scope:Computed(function(use): boolean
		local g = use(guild)
		return type(g) == "table" and Guild.can(rank, action :: any, g)
	end)
	return Button(scope, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(CELL - 6, ROW - 4),
		TextSize = Theme.TextSize.Small,
		Variant = scope:Computed(function(use): any
			return if use(on) then "primary" else "secondary"
		end),
		Disabled = scope:Computed(function(use): boolean
			return not use(isLeader)
		end),
		Text = scope:Computed(function(use): string
			return if use(on) then "✔" else "✕"
		end),
		OnClick = function()
			task.spawn(Common.invoke, "GuildSetPerm", rank, action, not Fusion.peek(on))
		end,
	})
end

local function limitCell(
	scope: Scope,
	guild: Fusion.Value<any>,
	isLeader: Fusion.Computed<boolean>,
	rank: string,
	kind: string,
	order: number,
	showModal: (spec: any) -> ()
): Instance
	local value = scope:Computed(function(use): number
		local g = use(guild)
		return Guild.limit(if type(g) == "table" then g else nil, rank, kind :: any)
	end)
	return Button(scope, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(CELL - 6, ROW - 4),
		TextSize = Theme.TextSize.Small,
		Disabled = scope:Computed(function(use): boolean
			return not use(isLeader)
		end),
		Text = scope:Computed(function(use): string
			local n = use(value)
			return if kind == "gold" then `◉ {Format.number(n)}` else tostring(n)
		end),
		OnClick = function()
			local max = if kind == "gold"
				then GuildProgressData.Rules.goldLimitMax
				else GuildProgressData.Rules.itemLimitMax
			showModal({
				Title = Text.now(`guild.rights.{kind}`),
				Message = Text.now("guild.rights.limitHint", {
					rank = Text.now(`guild.rank.{rank}`),
					max = Format.number(max),
				}),
				ConfirmText = Text.now("common.confirm"),
				CancelText = Text.now("common.cancel"),
				Input = { Placeholder = tostring(Fusion.peek(value)), MaxLength = 8 },
				OnConfirm = function(text: string): (boolean, string?)
					local n = tonumber(text)
					if not n then
						return false, Text.now("guild.error.amount")
					end
					return Common.modalInvoke("GuildSetLimit", rank, kind, math.floor(n))
				end,
			})
		end,
	})
end

local function rightsTable(
	scope: Scope,
	guild: Fusion.Value<any>,
	isLeader: Fusion.Computed<boolean>,
	showModal: (spec: any) -> ()
): { Instance }
	local function row(order: number, label: Fusion.UsedAs<string>, cells: { Instance }): Instance
		return scope:New("Frame")({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, ROW),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("TextLabel")({
					Size = UDim2.new(1, -CELL * #Guild.EDITABLE_RANKS, 1, 0),
					BackgroundTransparency = 1,
					Text = label,
					TextWrapped = true,
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				scope:New("Frame")({
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, CELL * #Guild.EDITABLE_RANKS, 1, 0),
					BackgroundTransparency = 1,
					[Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 6),
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						cells :: any,
					},
				}),
			},
		})
	end
	local header = {}
	for i, rank in Guild.EDITABLE_RANKS do
		table.insert(
			header,
			scope:New("TextLabel")({
				LayoutOrder = i,
				Size = UDim2.fromOffset(CELL - 6, ROW),
				BackgroundTransparency = 1,
				Text = Text.T(scope, `guild.rank.{rank}`),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Common.RANK_COLORS[rank] or Theme.Paper.Text,
			})
		)
	end
	local rows = {
		Common.heading(scope, 40, Text.T(scope, "guild.rights.title")),
		Common.paragraph(
			scope,
			41,
			scope:Computed(function(use): string
				return Text.get(use, if use(isLeader) then "guild.rights.hint" else "guild.rights.hintMember")
			end)
		),
		row(42, "", header),
	}
	for i, action in Guild.EDITABLE do
		local cells = {}
		for j, rank in Guild.EDITABLE_RANKS do
			table.insert(cells, rightCell(scope, guild, isLeader, rank, action, j))
		end
		table.insert(rows, row(42 + i, Text.T(scope, `guild.right.{action}`), cells))
	end
	for i, kind in { "gold", "items" } do
		local cells = {}
		for j, rank in Guild.EDITABLE_RANKS do
			table.insert(cells, limitCell(scope, guild, isLeader, rank, kind, j, showModal))
		end
		table.insert(rows, row(60 + i, Text.T(scope, `guild.rights.{kind}`), cells))
	end
	return rows
end

local function Settings(scope: Scope, showModal: (spec: any) -> ()): Instance
	local guild = State.Value({ "guild" })
	local protection = scope:Computed(function(use): boolean
		local g = use(guild)
		return type(g) ~= "table" or g.settings == nil or g.settings.guildPvpProtection ~= false
	end)
	local isLeader = scope:Computed(function(use): boolean
		local g = use(guild)
		return type(g) == "table" and g.myRank == "leader"
	end)

	return Common.page(scope, 10, {
		Common.heading(scope, 1, Text.T(scope, "guild.settings.pvp")),
		Common.paragraph(scope, 2, Text.T(scope, "guild.settings.pvpHint")),
		Button(scope, {
			LayoutOrder = 3,
			Size = UDim2.fromOffset(300, 46),
			Variant = scope:Computed(function(use): any
				return if use(protection) then "primary" else "secondary"
			end),
			Disabled = scope:Computed(function(use): boolean
				local g = use(guild)
				return not (type(g) == "table" and Guild.can(g.myRank, "settings", g))
			end),
			Text = scope:Computed(function(use): string
				return Text.get(use, if use(protection) then "guild.settings.pvpOn" else "guild.settings.pvpOff")
			end),
			OnClick = function()
				task.spawn(Common.invoke, "GuildSetting", "guildPvpProtection", not Fusion.peek(protection))
			end,
		}),
		Common.paragraph(scope, 4, Text.T(scope, "guild.settings.chatHint")),
		bannerPicker(scope, guild, isLeader) :: any,
		rightsTable(scope, guild, isLeader, showModal) :: any,
		Common.paragraph(
			scope,
			80,
			scope:Computed(function(use): string
				return if use(isLeader) then Text.get(use, "guild.settings.leaderHint") else ""
			end)
		),
		scope:New("Frame")({
			LayoutOrder = 81,
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundTransparency = 1,
			[Children] = {
				Button(scope, {
					Size = UDim2.fromOffset(220, 46),
					Variant = "danger",
					Text = Text.T(scope, "guild.leave"),
					OnClick = function()
						showModal({
							Title = Text.now("guild.leave"),
							Message = Text.now("guild.leave.confirm"),
							ConfirmText = Text.now("common.confirm"),
							CancelText = Text.now("common.cancel"),
							Variant = "danger",
							OnConfirm = function()
								return Common.modalInvoke("GuildLeave")
							end,
						})
					end,
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(240, 46),
					Variant = "danger",
					Visible = isLeader,
					Text = Text.T(scope, "guild.disband"),
					OnClick = function()
						local g = State.Get({ "guild" })
						if not g then
							return
						end
						showModal({
							Title = Text.now("guild.disband"),
							Message = Text.now("guild.disband.confirm", { name = g.name }),
							ConfirmText = Text.now("guild.disband"),
							CancelText = Text.now("common.cancel"),
							Variant = "danger",
							Input = { Placeholder = g.name, MustMatch = g.name, MaxLength = 20 },
							OnConfirm = function(text: string)
								return Common.modalInvoke("GuildDisband", text)
							end,
						})
					end,
				}),
			},
		}),
	})
end

return Settings
