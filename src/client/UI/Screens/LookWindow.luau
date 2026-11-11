--!strict
-- "Change appearance" (S132, DESIGN-17 §9a; window "look"): the preview of the current class look with the picked face,
-- skin and hair (UI/Components/LookPreview), the picker (UI/Components/LookPicker), the cost (the first change is free
-- from anywhere, then gold at the barber, Logic/CharacterLook.changeCost) and "Change appearance" (SetCharacterLook).
-- The button is greyed out with the reason while CharacterLook.canChange says no (the server checks it again). Opened
-- from the wardrobe and by the barber's dialog. Reads narrow state branches only.
-- Owner 2026-11-10 (UI plan L10): the preview (330 x 420) and the picker (440) with their gap needed 792 px in the
-- window's 776, so the picker ran under the window's edge. Now Logic/GearLayout.look places them from the content's
-- measured size: the preview scaled down to the room next to the picker, the picker scrolling on its own, side by side
-- on PC and on the phones. Review 2026-11-10: the size comes without the window's opening motion (UI/ViewSize).
-- Adoption stage (UI package D after C, 2026-11-10): the cost and "Zmień wygląd" stand in the window's Footer, pinned
-- under the content (the button was at the end of the scrolling picker, under the window's edge on a phone).
-- Review 2026-11-11 (owner 2026-11-10: "things covering each other"): the reason a change is not possible stands in
-- the footer too, under the price (it was the picker's last line, off screen on every phone); the price stays on top.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local CharacterLook = require(ReplicatedStorage.Shared.Logic.CharacterLook)
local CurrencyIcon = require(script.Parent.Parent.Components.CurrencyIcon)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GearLayout = require(ReplicatedStorage.Shared.Logic.GearLayout)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local LookPicker = require(script.Parent.Parent.Components.LookPicker)
local LookPreview = require(script.Parent.Parent.Components.LookPreview)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)
local Window = require(script.Parent.Parent.Components.Window)
local ViewSize = require(script.Parent.Parent.ViewSize)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

-- The server allows Npcs.INTERACT_RANGE + 4 studs (NpcService.Near); the client asks for a little less.
local NEAR_RANGE = Npcs.INTERACT_RANGE + 2
local NEAR_EVERY = 0.5
-- the body's size on PC (820 x 600, above the footer) until it is measured
local AREA_PC = { w = 776, h = 444 }

-- Next to an NPC offering the "look" service (the barber), like MountController.NearStable.
local function nearBarber(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Npcs")
	if not root or not folder then
		return false
	end
	for _, def in Npcs.list do
		if table.find(def.services, "look") then
			local model = folder:FindFirstChild(def.id)
			if model and model:IsA("Model") then
				local offset = model:GetPivot().Position - root.Position
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= NEAR_RANGE then
					return true
				end
			end
		end
	end
	return false
end

local function LookWindow(scope: Scope): Window.Parts
	local look = State.Value({ "character", "look" })
	local lookFree = State.Value({ "character", "lookFree" })
	local level = State.Value({ "character", "level" })
	local gold = State.Value({ "character", "gold" })
	local classId = State.Value({ "character", "class" })
	local classOutfits = State.Value({ "account", "cosmetics", "classOutfits" })
	local owned = State.Value({ "account", "cosmetics", "owned" })
	local dye = State.Value({ "account", "cosmetics", "equipped", "dye" })
	local avatar = State.Value({ "account", "settings", "robloxAvatar" })
	local near = scope:Value(nearBarber())
	local busy = scope:Value(false)

	local choice = scope:Value(CharacterLook.normalize(Fusion.peek(look)))
	local tab = scope:Value("face") -- W10: the picker's tab, the preview follows it
	scope:Observer(look):onChange(function()
		choice:set(CharacterLook.normalize(Fusion.peek(look)))
	end)

	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(NEAR_EVERY)
			local now = nearBarber()
			if alive and Fusion.peek(near) ~= now then
				near:set(now)
			end
		end
	end)

	local character = scope:Computed(function(use): any
		return { look = use(look), lookFree = use(lookFree) == true, level = use(level), gold = use(gold) }
	end)
	local check = scope:Computed(function(use): { ok: boolean, err: string?, cost: number }
		local ok, err, cost = CharacterLook.canChange(use(character), use(choice), use(near))
		return { ok = ok, err = err, cost = cost }
	end)
	local outfitId = scope:Computed(function(use): string?
		local c = use(classId)
		return CharacterLook.outfitOf(
			{ cosmetics = { classOutfits = use(classOutfits) or {}, owned = use(owned) or {} } },
			if type(c) == "string" then c else nil
		)
	end)

	local function apply()
		if not Fusion.peek(check).ok or Fusion.peek(busy) then
			return
		end
		local picked = CharacterLook.normalize(Fusion.peek(choice)) :: any
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke(
				"SetCharacterLook",
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
				Sounds.play("levelUp")
			else
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	-- the preview and the picker (GearLayout.look) from the content's own size
	local view = ViewSize.new(scope)
	local layout = scope:Computed(function(use): GearLayout.Look
		return GearLayout.look(use(view.size) or AREA_PC)
	end)
	local function at(pick: (GearLayout.Look) -> GearLayout.Rect): Fusion.Computed<UDim2>
		return scope:Computed(function(use): UDim2
			local r = pick(use(layout))
			return UDim2.fromOffset(r.left, r.top)
		end)
	end
	local function sized(pick: (GearLayout.Look) -> GearLayout.Rect): Fusion.Computed<UDim2>
		return scope:Computed(function(use): UDim2
			local r = pick(use(layout))
			return UDim2.fromOffset(r.right - r.left, r.bottom - r.top)
		end)
	end
	local function previewRect(l: GearLayout.Look): GearLayout.Rect
		return l.preview
	end
	local function pickerRect(l: GearLayout.Look): GearLayout.Rect
		return l.picker
	end

	local right = scope:New("Frame")({
		Name = "Picker",
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Medium),
			}),
			LookPicker(scope, { Look = choice, Tab = tab, LayoutOrder = 1 }), -- S135: still the legacy dark look
			-- 2026-10-21 (owner: too many detailed descriptions): one short line, what the avatar hides behind the "i"
			scope:New("Frame")({
				Name = "AvatarOn",
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(avatar) == true
				end),
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					scope:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.new(),
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Text = Text.T(scope, "look.avatarOn.short"),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = true,
						[Children] = scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink }),
					}),
					InfoTip.new(scope, { Text = Text.T(scope, "look.avatarOn"), LayoutOrder = 2 }),
				},
			}),
		},
	})

	local root = scope:New("Frame")({
		Name = "LookWindow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			view.ruler,
			LookPreview(scope, {
				Position = at(previewRect),
				Size = sized(previewRect),
				ClassId = classId,
				Look = choice,
				OutfitId = outfitId,
				Dye = dye,
				-- always the class look: the picked face, skin and hair show even while the avatar is on (look.avatarOn)
				Avatar = false,
				Focus = scope:Computed(function(use): string?
					local t = use(tab)
					return if t == "face" or t == "paint" then "face" else nil
				end),
			}),
			-- the picker scrolls next to the preview (the cost, the reason and the button stand in the footer)
			scope:New("ScrollingFrame")({
				Name = "PickerScroll",
				Position = at(pickerRect),
				Size = sized(pickerRect),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Paper.Rule,
				[Children] = {
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, Theme.Padding.Small),
						PaddingBottom = UDim.new(0, Theme.Padding.Medium),
					}),
					right,
				},
			}),
		},
	})
	view.watch(root)
	-- the footer's row (right-aligned): the cost line with the reason under it, then "Zmień wygląd" (GearLayout.look's
	-- cost and button)
	local function footerSize(pick: (GearLayout.Look) -> GearLayout.Rect): Fusion.Computed<UDim2>
		return scope:Computed(function(use): UDim2
			local r = pick(use(layout))
			return UDim2.fromOffset(r.right - r.left, r.bottom - r.top)
		end)
	end
	return {
		Content = root,
		Footer = {
			scope:New("Frame")({
				Name = "Cost",
				LayoutOrder = 1,
				Size = footerSize(function(l)
					return l.cost
				end),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					-- the price: one line of Body 20 next to the coin (tests/gearlayout.spec)
					scope:New("Frame")({
						Name = "Price",
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundTransparency = 1,
						[Children] = {
							CurrencyIcon(scope, {
								Currency = "gold",
								Size = UDim2.fromOffset(24, 24),
								AnchorPoint = Vector2.new(0, 0.5),
								Position = UDim2.fromScale(0, 0.5),
							}),
							scope:New("TextLabel")({
								Position = UDim2.fromOffset(30, 0),
								Size = UDim2.new(1, -30, 1, 0),
								BackgroundTransparency = 1,
								Text = scope:Computed(function(use): string
									local cost, free = CharacterLook.changeCost(use(character))
									if free then
										return Text.get(use, "look.cost.free")
									end
									return Text.get(use, "look.cost.gold", { gold = Format.number(cost) })
								end),
								FontFace = Theme.Fonts.BodyMedium,
								TextSize = Theme.TextSize.Body,
								TextColor3 = Theme.Paper.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),
						},
					}),
					-- why "Zmień wygląd" is greyed out, one line of Small 17 under the price: the current look is a
					-- hint (muted), the rest blocks the change (red)
					scope:New("TextLabel")({
						Name = "Why",
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						Visible = scope:Computed(function(use): boolean
							return use(check).err ~= nil
						end),
						Text = scope:Computed(function(use): string
							local err = use(check).err
							return if err then Text.get(use, err) else ""
						end),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = scope:Computed(function(use): Color3
							return if use(check).err == "look.error.same"
								then Theme.Paper.TextMuted
								else Theme.Paper.Danger
						end),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						[Children] = scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 30) }),
					}),
				},
			}),
			Button(scope, {
				LayoutOrder = 2,
				Size = footerSize(function(l)
					return l.button
				end),
				Variant = "primary",
				Text = Text.T(scope, "look.apply"),
				Disabled = scope:Computed(function(use): boolean
					return not use(check).ok or use(busy)
				end),
				OnClick = apply,
			}),
		},
	}
end

return LookWindow
