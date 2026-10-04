--!strict
-- Character selection screen (DESIGN §4.1): three slots, creator, delete confirmation, language switch.
-- Shown by ScreenController while the session phase is "loading" or "select".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Creator = require(script.Creator)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LanguageToggle = require(script.Parent.Parent.Components.LanguageToggle)
local Net = require(ReplicatedStorage.Shared.Net)
local SlotCard = require(script.SlotCard)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	ShowModal: (spec: any) -> (),
}

local HEADER_HEIGHT = 150

local function CharacterSelect(scope: Scope, props: Props): Instance
	local phase = State.Value({ "session", "phase" })
	local slots = State.Value({ "slots" })
	local dataMock = State.Value({ "session", "dataMock" })

	-- nil = slot list, number = creator for that slot
	local creating = scope:Value(nil :: number?)
	local busy = scope:Value(false)

	local loading = scope:Computed(function(use): boolean
		return use(phase) ~= "select"
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
		ScrollBarImageColor3 = Theme.Colors.GoldDim,
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
		BackgroundColor3 = Theme.Colors.Background,
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
				Position = UDim2.new(0.5, 0, 0, 24),
				Size = UDim2.new(1, -320, 0, 72),
				BackgroundTransparency = 1,
				Text = Config.GameName,
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Hero,
				TextColor3 = Theme.Colors.Gold,
				TextStrokeColor3 = Theme.Colors.Background,
				TextStrokeTransparency = 0.4,
			}),
			scope:New("TextLabel")({
				Name = "Subtitle",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 100),
				Size = UDim2.new(1, -320, 0, 30),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					if use(loading) then
						return Text.get(use, "charSelect.loading")
					end
					if use(creating) then
						return Text.get(use, "charSelect.create.title", { slot = use(creating) })
					end
					return Text.get(use, "charSelect.subtitle")
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.Parchment,
			}),
			LanguageToggle(scope, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -Theme.Padding.Large, 0, Theme.Padding.Large),
			}),

			-- Body: slot list or creator
			scope:New("Frame")({
				Name = "Body",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, HEADER_HEIGHT),
				Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT - 56),
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
				Position = UDim2.new(0.5, 0, 1, -Theme.Padding.Medium),
				Size = UDim2.new(1, -40, 0, 30),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(dataMock) == true
				end),
				Text = Text.T(scope, "charSelect.mockWarning"),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Warning,
				TextWrapped = true,
			}),
		},
	})
end

return CharacterSelect
