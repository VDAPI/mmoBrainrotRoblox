--!strict
-- Character selection screen (DESIGN §4.1): three slots, creator, delete confirmation, language switch.
-- S121: Config.MaxCharacters slots (5): slots above Config.FreeCharacters are locked until their passes are owned
-- (Logic/Premium.slotOpen on the replicated `passes` branch); a locked slot buys its pass (BuyPass) or says "Soon".
-- Shown by ScreenController while the session phase is "loading" or "select".
-- Owner 2026-11-10 (UI plan E, Logic/WorldLayout.characterSelect): the screen is laid out from the size of its layer
-- (Screens, already under Roblox's top bar): on a phone the title and subtitle are smaller and the slot cards keep
-- "Graj" and "Usuń" on the screen (before, a fixed 150 px header pushed them under its bottom edge).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Creator = require(script.Creator)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LanguageToggle = require(script.Parent.Parent.Components.LanguageToggle)
local Net = require(ReplicatedStorage.Shared.Net)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local Scale = require(script.Parent.Parent.Scale)
local Sounds = require(script.Parent.Parent.Sounds)
local ServerModeView = require(script.Parent.Parent.ServerModeView)
local SlotCard = require(script.SlotCard)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldLayout = require(ReplicatedStorage.Shared.Logic.WorldLayout)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	ShowModal: (spec: any) -> (),
}

local function CharacterSelect(scope: Scope, props: Props): Instance
	local phase = State.Value({ "session", "phase" })
	local slots = State.Value({ "slots" })
	local passes = State.Value({ "passes" })
	local dataMock = State.Value({ "session", "dataMock" })

	-- owner 2026-11-10: the layer is the Screens one, under Roblox's top bar already (topBar 0)
	local layout = scope:Computed(function(use): WorldLayout.CharacterSelect
		local size: Vector2 = use(Scale.HudSize)
		return WorldLayout.characterSelect({ w = size.X, h = size.Y }, use(PhoneLayout.Compact), 0)
	end)

	-- nil = slot list, number = creator for that slot
	local creating = scope:Value(nil :: number?)
	local busy = scope:Value(false)

	-- S127: an arena server picks the character itself ("Entering the arena…"); after the way back the world server
	-- does the same for a while ("Back from the arena…"), then the list shows (a slot that is gone)
	local arenaServer = not ServerModeView.isWorld()
	local autoPick = scope:Value(arenaServer or ServerModeView.backFromArena())
	if not arenaServer and Fusion.peek(autoPick) then
		task.delay(15, function()
			pcall(function()
				autoPick:set(false)
			end)
		end)
	end
	local loading = scope:Computed(function(use): boolean
		return use(phase) ~= "select" or use(autoPick)
	end)

	-- The server answers within seconds; if it never does (server failed to start), say so instead of
	-- leaving "Loading your characters" up forever.
	local SERVER_TIMEOUT = 45
	local stalled = scope:Value(false)
	task.delay(SERVER_TIMEOUT, function()
		if Fusion.peek(phase) ~= "select" and not Fusion.peek(autoPick) then
			pcall(function()
				stalled:set(true)
			end)
			warn(`[CharacterSelect] no character list from the server after {SERVER_TIMEOUT} s`)
		end
	end)

	local function play(slot: number)
		if Fusion.peek(busy) then
			return
		end
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("PlayCharacter", slot)
			busy:set(false)
			if not ok then
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	local function askDelete(slot: number, summary: Types.SlotSummary)
		props.ShowModal({
			Title = Text.T(scope, "charSelect.deleteModal.title"),
			Message = Text.T(scope, "charSelect.deleteModal.message", { name = summary.name }),
			ConfirmText = Text.T(scope, "charSelect.deleteModal.confirm"),
			CancelText = Text.T(scope, "common.cancel"),
			Variant = "danger",
			Input = {
				Placeholder = summary.name,
				MustMatch = summary.name,
				MaxLength = Config.CharacterName.MaxLength,
			},
			OnConfirm = function(text: string): (boolean, string?)
				local ok, err = Net.Invoke("DeleteCharacter", slot, text)
				if ok then
					Toast.push(Text.now("charSelect.deleted", { name = summary.name }), "info")
					return true, nil
				end
				return false, Text.now(err or "error.internal")
			end,
		})
	end

	-- S121: buys the slot pass (the native prompt; simulated in Studio). The card unlocks when `passes` changes.
	local function unlock(passKey: string)
		task.spawn(function()
			local ok, err = Net.Invoke("BuyPass", passKey)
			if ok then
				if err then
					Toast.push(Text.now(err), "info")
				else
					Sounds.play("levelUp")
				end
			else
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	local function ownedPasses(use: Fusion.Use): { [string]: boolean }
		local owned = use(passes)
		return if type(owned) == "table" then owned else {}
	end

	local cards = {}
	for slot = 1, Config.MaxCharacters do
		table.insert(
			cards,
			SlotCard(scope, {
				Slot = slot,
				Summary = scope:Computed(function(use): Types.SlotSummary?
					local all = use(slots)
					return if type(all) == "table" then all[tostring(slot)] else nil
				end),
				Busy = busy,
				OnCreate = function()
					creating:set(slot)
				end,
				OnPlay = function()
					play(slot)
				end,
				OnDelete = function(summary)
					askDelete(slot, summary)
				end,
				Locked = scope:Computed(function(use): boolean
					return not Premium.slotOpen(slot, ownedPasses(use))
				end),
				Pass = scope:Computed(function(use): string?
					return Premium.slotPass(slot, ownedPasses(use))
				end),
				OnUnlock = unlock,
				Layout = layout,
			})
		)
	end

	local slotList = scope:New("ScrollingFrame")({
		Name = "Slots",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Brass.Line,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Large),
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.Padding.Large),
				PaddingRight = UDim.new(0, Theme.Padding.Large),
			}),
			cards :: any,
		},
	})

	return scope:New("Frame")({
		Name = "CharacterSelect",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Iron.Sunken, -- S136: a veil over the world: iron, the cards on it parchment
		BackgroundTransparency = 0.25,
		Active = true,
		[Children] = {
			scope:New("UIGradient")({
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.1),
					NumberSequenceKeypoint.new(0.45, 0.55),
					NumberSequenceKeypoint.new(1, 0.05),
				}),
			}),

			-- Header
			scope:New("TextLabel")({
				Name = "Title",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = scope:Computed(function(use): UDim2
					return UDim2.new(0.5, 0, 0, use(layout).titleTop)
				end),
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, -320, 0, use(layout).title)
				end),
				BackgroundTransparency = 1,
				Text = Config.GameName,
				FontFace = Theme.Fonts.Display,
				TextSize = scope:Computed(function(use): number
					return if use(PhoneLayout.Compact) then Theme.TextSize.Title else Theme.TextSize.Hero
				end),
				TextColor3 = Theme.Brass.Bright,
				TextStrokeColor3 = Theme.Shade,
				TextStrokeTransparency = 0.4,
			}),
			scope:New("TextLabel")({
				Name = "Subtitle",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = scope:Computed(function(use): UDim2
					return UDim2.new(0.5, 0, 0, use(layout).subtitleTop)
				end),
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, -320, 0, use(layout).subtitle)
				end),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					if use(autoPick) then
						return Text.get(use, if arenaServer then "arena.net.loading" else "arena.net.returningLoad")
					end
					if use(loading) then
						return Text.get(use, if use(stalled) then "charSelect.stalled" else "charSelect.loading")
					end
					if use(creating) then
						return Text.get(use, "charSelect.create.title", { slot = use(creating) })
					end
					return Text.get(use, "charSelect.subtitle")
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = scope:Computed(function(use): number
					return if use(PhoneLayout.Compact) then Theme.TextSize.Body else Theme.TextSize.Large
				end),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = Theme.Iron.Text,
				TextStrokeColor3 = Theme.Shade,
				TextStrokeTransparency = 0.4,
			}),
			LanguageToggle(scope, {
				Surface = "iron",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -Theme.Padding.Large, 0, Theme.Padding.Large),
			}),

			-- Body: slot list or creator
			scope:New("Frame")({
				Name = "Body",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = scope:Computed(function(use): UDim2
					return UDim2.new(0.5, 0, 0, use(layout).header)
				end),
				Size = scope:Computed(function(use): UDim2
					local l = use(layout)
					return UDim2.new(1, 0, 1, -(l.header + l.footer))
				end),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(loading)
				end),
				[Children] = scope:Computed(function(use, innerScope: Scope): Instance
					local slot = use(creating)
					if slot then
						return Creator(innerScope, {
							Slot = slot,
							OnDone = function(name: string?)
								creating:set(nil)
								if name then
									Toast.push(Text.now("charSelect.created", { name = name }), "success")
								end
							end,
						})
					end
					return slotList
				end),
			}),

			-- Footer: test-mode warning
			scope:New("TextLabel")({
				Name = "MockWarning",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = scope:Computed(function(use): UDim2
					return UDim2.new(0.5, 0, 1, if use(PhoneLayout.Compact) then -2 else -Theme.Padding.Medium)
				end),
				-- inside the footer of the layout (30 on a phone, 56 otherwise)
				Size = scope:Computed(function(use): UDim2
					return UDim2.new(1, -40, 0, math.min(30, use(layout).footer - 4))
				end),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(dataMock) == true
				end),
				Text = Text.T(scope, "charSelect.mockWarning"),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Warning,
				TextWrapped = true,
			}),
		},
	})
end

return CharacterSelect
