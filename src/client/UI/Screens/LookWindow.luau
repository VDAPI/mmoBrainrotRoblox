--!strict
-- "Change appearance" (S132, DESIGN-17 §9a; window "look"): the preview of the current class look with the picked face,
-- skin and hair (UI/Components/LookPreview), the picker (UI/Components/LookPicker), the cost (the first change is free
-- from anywhere, then gold at the barber, Logic/CharacterLook.changeCost) and "Change appearance" (SetCharacterLook).
-- The button is greyed out with the reason while CharacterLook.canChange says no (the server checks it again). Opened
-- from the wardrobe and by the barber's dialog. Reads narrow state branches only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local CharacterLook = require(ReplicatedStorage.Shared.Logic.CharacterLook)
local CurrencyIcon = require(script.Parent.Parent.Components.CurrencyIcon)
local Device = require(script.Parent.Parent.Device)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LookPicker = require(script.Parent.Parent.Components.LookPicker)
local LookPreview = require(script.Parent.Parent.Components.LookPreview)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

-- The server allows Npcs.INTERACT_RANGE + 4 studs (NpcService.Near); the client asks for a little less.
local NEAR_RANGE = Npcs.INTERACT_RANGE + 2
local NEAR_EVERY = 0.5
local RIGHT = 440

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

local function LookWindow(scope: Scope): Instance
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
		local picked = Fusion.peek(choice)
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("SetCharacterLook", picked.face, picked.skin, picked.hair)
			busy:set(false)
			if ok then
				Sounds.play("levelUp")
			else
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	local previewSize = scope:Computed(function(use): UDim2
		return if use(Device.Touch) then UDim2.fromOffset(240, 280) else UDim2.fromOffset(330, 420)
	end)

	local right = scope:New("Frame")({
		Name = "Picker",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(RIGHT, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Medium),
			}),
			LookPicker(scope, { Look = choice, LayoutOrder = 1 }), -- S135: still the legacy dark look
			scope:New("Frame")({
				Name = "Cost",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				[Children] = {
					CurrencyIcon(scope, {
						Currency = "gold",
						Size = UDim2.fromOffset(24, 24),
						Position = UDim2.fromOffset(0, 3),
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
						TextWrapped = true,
					}),
				},
			}),
			scope:New("TextLabel")({
				Name = "AvatarOn",
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(avatar) == true
				end),
				Text = Text.T(scope, "look.avatarOn"),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			}),
			Button(scope, {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
				Variant = "primary",
				Text = Text.T(scope, "look.apply"),
				Disabled = scope:Computed(function(use): boolean
					return not use(check).ok or use(busy)
				end),
				OnClick = apply,
			}),
			scope:New("TextLabel")({
				Name = "Why",
				LayoutOrder = 5,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local err = use(check).err
					return if err then Text.get(use, err) else ""
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			}),
		},
	})

	return scope:New("ScrollingFrame")({
		Name = "LookWindow",
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
				FillDirection = scope:Computed(function(use): Enum.FillDirection
					return if use(Device.Touch) then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
				end),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Large),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Padding.Small),
				PaddingBottom = UDim.new(0, Theme.Padding.Medium),
			}),
			LookPreview(scope, {
				LayoutOrder = 1,
				Size = previewSize,
				ClassId = classId,
				Look = choice,
				OutfitId = outfitId,
				Dye = dye,
				-- always the class look: the picked face, skin and hair show even while the avatar is on (look.avatarOn)
				Avatar = false,
			}),
			right,
		},
	})
end

return LookWindow
