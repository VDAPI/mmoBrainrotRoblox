--!strict
-- Wardrobe (DESIGN §22–23): a rotating preview of the own character in a ViewportFrame (with the selected
-- cosmetic tried on, or the pet next to it), categories (outfits, auras, trails, weapon effects, pets) and
-- per item: owned -> "Wear" / "Take off", otherwise the price in Dragon Shards and "Buy".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Components.Button)
local CosmeticLook = require(ReplicatedStorage.Shared.Util.CosmeticLook)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local PREVIEW = 330

local function invoke(name: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = Net.Invoke(name, table.unpack(args, 1, args.n))
		if ok then
			Sounds.play("levelUp")
		else
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

-- Clone of the local character without scripts, for the viewport.
local function cloneCharacter(): Model?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	local archivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = archivable
	if not clone then
		return nil
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	clone:PivotTo(CFrame.new())
	return clone
end

local function Wardrobe(scope: Scope): Fusion.Child
	local kind = scope:Value("outfit")
	local tried = scope:Value(nil :: string?) -- previewed (not yet equipped) cosmetic
	local account = State.Value({ "account" })
	local shards = State.Value({ "account", "dragonShards" })

	local function owns(acc: any, def: Cosmetics.Def): boolean
		if type(acc) ~= "table" then
			return false
		end
		local owned = if def.kind == "pet" then acc.pets.owned else acc.cosmetics.owned
		return owned[def.id] == true
	end
	local function equippedOf(acc: any, k: string): string?
		if type(acc) ~= "table" then
			return nil
		end
		return if k == "pet" then acc.pets.equipped else acc.cosmetics.equipped[k]
	end

	-- Preview ------------------------------------------------------------------------------------
	local viewport = scope:New("ViewportFrame")({
		Size = UDim2.fromOffset(PREVIEW, PREVIEW + 120),
		BackgroundColor3 = Theme.Colors.Background,
		Ambient = Color3.fromRGB(160, 150, 140),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1, -1),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim }),
		},
	}) :: ViewportFrame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	table.insert(scope, camera)

	local model: Model? = nil
	local pet: Model? = nil
	local function rebuild()
		if model then
			model:Destroy()
		end
		if pet then
			pet:Destroy()
			pet = nil
		end
		model = cloneCharacter()
		local acc = Fusion.peek(account)
		if not model or type(acc) ~= "table" then
			return
		end
		local look = table.clone(acc.cosmetics.equipped)
		local petId = acc.pets.equipped
		local trying = Fusion.peek(tried)
		local def = trying and Cosmetics.get(trying)
		if def then
			if def.kind == "pet" then
				petId = def.id
			else
				look[def.kind] = def.id
			end
		end
		CosmeticLook.applyAll(model, look)
		model.Parent = viewport
		if petId then
			pet = CosmeticLook.buildPet(petId)
			if pet then
				local lift = pet:GetAttribute("PetLift")
				pet:PivotTo(
					CFrame.new(2.6, -3 + (if type(lift) == "number" then lift else 1.2), 0.5)
						* CFrame.Angles(0, math.rad(200), 0)
				)
				pet.Parent = viewport
			end
		end
	end
	rebuild()
	scope:Observer(tried):onChange(rebuild)
	scope:Observer(account):onChange(rebuild)
	table.insert(scope, function()
		if model then
			model:Destroy()
		end
		if pet then
			pet:Destroy()
		end
	end)
	local angle = 0
	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt: number)
			angle += dt * 0.6
			camera.CFrame =
				CFrame.new(Vector3.new(math.sin(angle) * 11, 1.5, math.cos(angle) * 11), Vector3.new(0, 0.2, 0))
		end)
	)

	-- List ---------------------------------------------------------------------------------------
	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		local acc = use(account)
		local k = use(kind)
		local equipped = equippedOf(acc, k)
		local index = 0
		for _, def in Cosmetics.list do
			if def.kind ~= k then
				continue
			end
			index += 1
			local isOwned = owns(acc, def)
			local isOn = equipped == def.id
			local action = if isOn then "wardrobe.takeOff" elseif isOwned then "wardrobe.wear" else nil
			table.insert(
				list,
				s:New("TextButton")({
					LayoutOrder = index,
					Size = UDim2.new(1, 0, 0, 64),
					AutoButtonColor = false,
					Text = "",
					BackgroundColor3 = if use(tried) == def.id
						then Theme.Colors.PanelHover
						else Theme.Colors.PanelRaised,
					BackgroundTransparency = 0.2,
					[OnEvent("Activated")] = function()
						Sounds.play("click")
						tried:set(if Fusion.peek(tried) == def.id then nil else def.id)
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(8, 8),
							Size = UDim2.fromOffset(48, 48),
							BackgroundColor3 = Color3.fromHex(def.color),
							Text = def.icon,
							TextScaled = true,
							FontFace = Theme.Fonts.BodyBold,
							TextColor3 = Color3.new(1, 1, 1),
							TextStrokeTransparency = 0.4,
							[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(66, 8),
							Size = UDim2.new(1, -240, 0, 26),
							BackgroundTransparency = 1,
							Text = `{if isOn then "✔ " else ""}{Text.get(use, def.nameKey)}`,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = if isOn then Theme.Colors.GoldBright else Theme.Colors.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(66, 34),
							Size = UDim2.new(1, -240, 0, 22),
							BackgroundTransparency = 1,
							Text = if isOwned then Text.get(use, "premium.owned") else `◆ {Format.number(def.price)}`,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if isOwned then Theme.Colors.Success else Theme.Colors.Accent,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						Button(s, {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -8, 0.5, 0),
							Size = UDim2.fromOffset(150, 44),
							Variant = if action then "secondary" else "primary",
							TextSize = Theme.TextSize.Small,
							Text = Text.T(s, action or "wardrobe.buy"),
							Disabled = if action then false else (use(shards) or 0) < def.price,
							OnClick = function()
								if isOn then
									invoke("CosmeticEquip", def.kind, nil)
								elseif isOwned then
									invoke("CosmeticEquip", def.kind, def.id)
								else
									invoke("PremiumBuyCosmetic", def.id)
								end
							end,
						}),
					},
				})
			)
		end
		return list
	end)

	local tabs = {}
	for _, k in Cosmetics.kinds do
		table.insert(tabs, { id = k, label = Text.T(scope, `wardrobe.kind.{k}`) })
	end

	return {
		viewport :: Instance,
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(0, PREVIEW + 128),
			Size = UDim2.fromOffset(PREVIEW, 50),
			BackgroundTransparency = 1,
			Text = Text.T(scope, "wardrobe.hint"),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.TextMuted,
		}),
		scope:New("Frame")({
			Position = UDim2.fromOffset(PREVIEW + 16, 0),
			Size = UDim2.new(1, -(PREVIEW + 16), 1, 0),
			BackgroundTransparency = 1,
			[Children] = {
				Tabs(scope, { Selected = kind, Tabs = tabs }),
				scope:New("TextLabel")({
					Position = UDim2.fromOffset(0, 48),
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return `◆ {Format.number(use(shards) or 0)}`
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.Accent,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				scope:New("ScrollingFrame")({
					Position = UDim2.fromOffset(0, 80),
					Size = UDim2.new(1, 0, 1, -80),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 6,
					[Children] = {
						scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
						scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
						rows :: any,
					},
				}),
			},
		}),
	}
end

return Wardrobe
