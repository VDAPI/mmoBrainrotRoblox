--!strict
-- Character creator: class picker (4 cards) + name field with live validation (local rules instantly,
-- server availability after a short pause) + Create / Back.
-- S132 (DESIGN-17 §9a): the "Appearance" section under the classes: the preview of the picked class's outfit with the
-- picked face, skin and hair (UI/Components/LookPreview) next to the picker (UI/Components/LookPicker; one under the
-- other on a phone); CreateCharacter sends the look.
-- W10: the picker's tabs on the left (Face, Hair, Body, Paint), a larger preview on the right that turns with a drag and
-- comes close to the face on the Face and Paint tabs; CreateCharacter sends every field of the look.
-- Owner 2026-10-21 (too many detailed descriptions): a class card shows one short line (class.<id>.short), the full
-- description behind the "i" in its corner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local CharacterLook = require(ReplicatedStorage.Shared.Logic.CharacterLook)
local ClassLooks = require(ReplicatedStorage.Shared.Data.ClassLooks)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Parent.Components.InfoTip)
local LookPicker = require(script.Parent.Parent.Parent.Components.LookPicker)
local LookPreview = require(script.Parent.Parent.Parent.Components.LookPreview)
local NameRules = require(ReplicatedStorage.Shared.Logic.NameRules)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.Parent.UiArtState)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Slot: number,
	-- Called after a successful creation with the new name, or with nil when the player goes back.
	OnDone: (name: string?) -> (),
}

local CHECK_DELAY = 0.45
local CARD = Vector2.new(220, 270)

-- Name error messages carry the configured limits.
local NAME_ARGS = { min = Config.CharacterName.MinLength, max = Config.CharacterName.MaxLength }

local function classCard(scope: Scope, class: Classes.ClassDef, index: number, selected: Fusion.Value<string>): Instance
	local isSelected = scope:Computed(function(use): boolean
		return use(selected) == class.id
	end)
	local hovered = scope:Value(false)
	local color = Theme.readable(class.color, "paper")
	local portrait = UiArt.classPortrait(class.id)
	UiArtState.ensureKey(portrait)
	local portraitShown = ArtIcon.Shown(scope, portrait)

	return scope:New("TextButton")({
		Name = class.id,
		LayoutOrder = index,
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = scope:Computed(function(use): Color3
			if use(isSelected) then
				return Theme.Paper.Hover
			end
			return if use(hovered) then Theme.Paper.Raised else Theme.Paper.Surface
		end),
		[OnEvent("MouseEnter")] = function()
			hovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovered:set(false)
		end,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			selected:set(class.id)
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = scope:Computed(function(use): number
					return if use(isSelected) then Theme.Stroke.Thick else Theme.Stroke.Thin
				end),
				Color = scope:Computed(function(use): Color3
					return if use(isSelected) then Theme.Brass.Frame else Theme.Paper.Rule
				end),
			}),
			-- S119: the class portrait (2:3) as the card background, darkened, once loaded; without it the card is as
			-- before. The content sits in its own frame so the list layout does not move the portrait.
			ArtIcon.Image(scope, {
				Name = "Portrait",
				Key = portrait,
				ScaleType = Enum.ScaleType.Crop,
				Corner = Theme.Corner.Medium,
			}),
			scope:New("Frame")({
				Name = "Shade",
				Size = UDim2.fromScale(1, 1),
				-- S136: a parchment veil over the portrait, so the ink on the card stays readable
				BackgroundColor3 = Theme.Paper.Surface,
				BackgroundTransparency = scope:Computed(function(use): number
					if use(isSelected) then
						return 0.3
					end
					return if use(hovered) then 0.25 else 0.15
				end),
				Visible = portraitShown,
				[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			}),
			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, Theme.Padding.Medium),
						PaddingBottom = UDim.new(0, Theme.Padding.Medium),
						PaddingLeft = UDim.new(0, Theme.Padding.Medium),
						PaddingRight = UDim.new(0, Theme.Padding.Medium),
					}),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, Theme.Padding.Tiny),
					}),
					-- S119: the class emblem once loaded (glyph otherwise).
					ArtIcon(scope, {
						Name = "Icon",
						LayoutOrder = 1,
						Key = UiArt.classEmblem(class.id),
						Glyph = class.icon,
						GlyphColor = color,
						Size = UDim2.fromOffset(64, 64),
						Label = { FontFace = Theme.Fonts.BodyBold, TextSize = Theme.TextSize.Hero },
					}),
					scope:New("TextLabel")({
						Name = "ClassName",
						LayoutOrder = 2,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 32),
						Text = Text.T(scope, class.nameKey),
						FontFace = Theme.Fonts.Display,
						TextSize = Theme.TextSize.Large + 2,
						TextColor3 = Theme.Paper.Heading,
					}),
					scope:New("TextLabel")({
						Name = "Role",
						LayoutOrder = 3,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 22),
						Text = Text.T(scope, class.roleKey),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Small,
						TextColor3 = color,
					}),
					scope:New("TextLabel")({
						Name = "Description",
						LayoutOrder = 4,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 110),
						Text = Text.T(scope, `class.{class.id}.short`),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.TextMuted,
						TextWrapped = true,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
				},
			}),
			-- owner 2026-10-21: the full description of the class
			InfoTip.new(scope, {
				Name = "Info",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 8),
				Title = Text.T(scope, class.nameKey),
				Text = Text.T(scope, class.descKey),
			}),
		},
	})
end

local function Creator(scope: Scope, props: Props): Instance
	local selected = scope:Value(Classes.order[1] :: string)
	local name = scope:Value("")
	local errorKey = scope:Value(nil :: string?)
	local checking = scope:Value(false)
	local busy = scope:Value(false)
	local checkToken = 0
	-- S132: face, skin and hair of the new character
	local look = scope:Value(CharacterLook.normalize(ClassLooks.DEFAULT_LOOK))
	local tab = scope:Value("face")

	local localValid = scope:Computed(function(use): boolean
		return (NameRules.validate(use(name)))
	end)

	-- Live validation: shape errors right away, availability from the server after a pause.
	scope:Observer(name):onChange(function()
		checkToken += 1
		local token = checkToken
		local text = Fusion.peek(name)
		if text == "" then
			errorKey:set(nil)
			checking:set(false)
			return
		end
		local ok, reason = NameRules.validate(text)
		if not ok then
			errorKey:set(NameRules.errorKey(reason :: string))
			checking:set(false)
			return
		end
		errorKey:set(nil)
		checking:set(true)
		task.delay(CHECK_DELAY, function()
			if token ~= checkToken then
				return
			end
			local available, err = Net.Invoke("CheckName", text)
			if token ~= checkToken then
				return
			end
			checking:set(false)
			errorKey:set(if available then nil else err)
		end)
	end)

	local canCreate = scope:Computed(function(use): boolean
		return use(localValid) and not use(busy) and use(errorKey) == nil
	end)

	local function create()
		if not Fusion.peek(canCreate) then
			return
		end
		local text = Fusion.peek(name)
		busy:set(true)
		task.spawn(function()
			local picked = CharacterLook.normalize(Fusion.peek(look)) :: any
			local ok, err = Net.Invoke(
				"CreateCharacter",
				props.Slot,
				Fusion.peek(selected),
				text,
				picked.face,
				picked.skin,
				picked.hair,
				picked.hairColor,
				picked.brows,
				picked.beard,
				picked.build,
				picked.paint,
				picked.paintColor
			)
			busy:set(false)
			if ok then
				props.OnDone(text)
			else
				Sounds.play("error")
				errorKey:set(err or "error.internal")
			end
		end)
	end

	local cards = {}
	for index, classId: Types.ClassId in Classes.order do
		local class = Classes.get(classId)
		if class then
			table.insert(cards, classCard(scope, class, index, selected))
		end
	end

	return scope:New("ScrollingFrame")({
		Name = "Creator",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Rule,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, Theme.Padding.Medium),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Padding.Small),
				PaddingBottom = UDim.new(0, Theme.Padding.Large),
			}),
			scope:New("TextLabel")({
				Name = "Title",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 36),
				Text = Text.T(scope, "charSelect.create.chooseClass"),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Title,
				TextColor3 = Theme.Paper.Heading,
			}),
			scope:New("Frame")({
				Name = "Classes",
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Padding.Medium),
						Wraps = true,
					}),
					cards :: any,
				},
			}),
			-- S132: the appearance
			scope:New("TextLabel")({
				Name = "LookTitle",
				LayoutOrder = 3,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 32),
				Text = Text.T(scope, "charSelect.create.look"),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Paper.Heading,
			}),
			scope:New("Frame")({
				Name = "Look",
				LayoutOrder = 4,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = scope:Computed(function(use): Enum.FillDirection
							return if use(Device.Touch)
								then Enum.FillDirection.Vertical
								else Enum.FillDirection.Horizontal
						end),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Padding.Large),
					}),
					scope:New("Frame")({
						Name = "PreviewColumn",
						LayoutOrder = 2,
						BackgroundTransparency = 1,
						Size = scope:Computed(function(use): UDim2
							return if use(Device.Touch) then UDim2.fromOffset(280, 0) else UDim2.fromOffset(380, 0)
						end),
						AutomaticSize = Enum.AutomaticSize.Y,
						[Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, Theme.Padding.Tiny),
							}),
							LookPreview(scope, {
								LayoutOrder = 1,
								Size = scope:Computed(function(use): UDim2
									return if use(Device.Touch)
										then UDim2.fromOffset(280, 360)
										else UDim2.fromOffset(380, 500)
								end),
								ClassId = selected,
								Look = look,
								Focus = scope:Computed(function(use): string?
									local t = use(tab)
									return if t == "face" or t == "paint" then "face" else nil
								end),
							}),
							scope:New("TextLabel")({
								Name = "LookHint",
								LayoutOrder = 2,
								BackgroundTransparency = 1,
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								Text = Text.T(scope, "charSelect.create.lookHint"),
								FontFace = Theme.Fonts.Body,
								TextSize = Theme.TextSize.Small,
								TextColor3 = Theme.Paper.TextMuted,
								TextWrapped = true,
							}),
						},
					}),
					LookPicker(scope, {
						LayoutOrder = 1,
						Look = look,
						Tab = tab,
						Size = scope:Computed(function(use): UDim2
							return if use(Device.Touch) then UDim2.fromOffset(340, 0) else UDim2.fromOffset(500, 0)
						end),
					}),
				},
			}),
			scope:New("TextLabel")({
				Name = "NameLabel",
				LayoutOrder = 5,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(460, 26),
				Text = Text.T(scope, "charSelect.create.name"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			TextInput(scope, {
				Name = "NameInput",
				LayoutOrder = 6,
				Size = UDim2.fromOffset(460, Theme.Size.InputHeight + 22),
				Text = name,
				MaxLength = Config.CharacterName.MaxLength,
				Placeholder = Text.T(scope, "charSelect.create.namePlaceholder", NAME_ARGS),
				Error = scope:Computed(function(use): string?
					local key = use(errorKey)
					return if key then Text.get(use, key, NAME_ARGS) else nil
				end),
				OnSubmit = function()
					create()
				end,
			}),
			scope:New("TextLabel")({
				Name = "Status",
				LayoutOrder = 7,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(460, 20),
				Text = scope:Computed(function(use): string
					if use(checking) then
						return Text.get(use, "charSelect.create.checking")
					end
					if use(localValid) and use(errorKey) == nil then
						return Text.get(use, "charSelect.create.available")
					end
					return ""
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(checking) then Theme.Paper.TextMuted else Theme.Paper.Success
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("Frame")({
				Name = "Buttons",
				LayoutOrder = 8,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(460, Theme.Size.ButtonHeight),
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Padding.Medium),
					}),
					Button(scope, {
						LayoutOrder = 1,
						Text = Text.T(scope, "charSelect.create.back"),
						Variant = "ghost",
						Size = UDim2.new(0.4, -Theme.Padding.Medium / 2, 1, 0),
						Disabled = busy,
						OnClick = function()
							props.OnDone(nil)
						end,
					}),
					Button(scope, {
						LayoutOrder = 2,
						Text = Text.T(scope, "charSelect.create.submit"),
						Variant = "primary",
						Size = UDim2.new(0.6, -Theme.Padding.Medium / 2, 1, 0),
						Disabled = scope:Computed(function(use): boolean
							return not use(canCreate)
						end),
						OnClick = create,
					}),
				},
			}),
		},
	})
end

return Creator
