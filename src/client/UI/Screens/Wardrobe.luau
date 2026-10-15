--!strict
-- Wardrobe (DESIGN §22–23): a rotating preview of the own character in a ViewportFrame (with the selected
-- cosmetic tried on, or the pet next to it), categories (outfits, auras, trails, weapon effects, pets) and
-- per item: owned -> "Wear" / "Take off", otherwise the price in Dragon Shards and "Buy".
-- S97: the "mountskin" tab previews the character's active mount (or the horse) in the tried-on / worn skin; skins
-- earned in the game (boss loot, quest rewards) show where they come from instead of a price and have no button
-- until owned. UI/WardrobeStart picks the first tab (the mounts window opens the mount skins).
-- S120: buying asks first (UI/PremiumConfirm: name, kind, price, balance after); "Top up" next to the balance opens the
-- Dragon Shop on the currency tab; WardrobeStart.try opens with a cosmetic tried on (the shop's "Try on").
-- S121: saved looks under the preview (Products.OUTFITS_PLUS tiles: saved with a colour dot, empty dimmed, locked
-- above Logic/Premium.outfitSlots with a lock that opens the shop's Passes tab), "Wear" (OutfitWear) and "Save current"
-- (OutfitSave, asking before overwriting); VIP cosmetics of the month say "VIP reward (11.2026)".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Button = require(script.Parent.Parent.Components.Button)
local CosmeticLook = require(ReplicatedStorage.Shared.Util.CosmeticLook)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Device = require(script.Parent.Parent.Device)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MountLook = require(ReplicatedStorage.Shared.Util.MountLook)
local Mounts = require(ReplicatedStorage.Shared.Logic.Mounts)
local Net = require(ReplicatedStorage.Shared.Net)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local PremiumConfirm = require(script.Parent.Parent.PremiumConfirm)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)
local Tooltip = require(script.Parent.Parent.Components.Tooltip)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.UiArtState)
local WardrobeStart = require(script.Parent.Parent.WardrobeStart)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	-- S120: "Top up" (PremiumController.OpenShop("currency")); S121: a locked look opens the "passes" tab
	OpenShop: ((tab: string?) -> ())?,
}

local PREVIEW = 330
local PREVIEW_HEIGHT = PREVIEW + 40 -- S121: room for the looks under the preview
local OUTFIT_TILE = 44
local TOP_UP_WIDTH = 100
local MOUNT_ORBIT = 15 -- S97: the camera further out for a mount
local CHARACTER_ORBIT = 11

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
	MountLook.strip(clone)
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

-- S97: where a skin earned in the game comes from ("Loot: Morvane", "Quest reward: Ride Home").
local function obtainText(use: Fusion.Use, def: Cosmetics.Def): string
	local obtain = def.obtain
	if obtain and obtain.boss then
		local boss = Bosses.get(obtain.boss)
		return Text.get(
			use,
			"wardrobe.obtain.boss",
			{ boss = if boss then Text.get(use, boss.nameKey) else obtain.boss }
		)
	elseif obtain and obtain.quest then
		return Text.get(use, "wardrobe.obtain.quest", { quest = Text.get(use, `quest.{obtain.quest}.title`) })
	elseif obtain and obtain.vipMonth then
		-- S121: the VIP cosmetic of the month
		local year, month = Time.monthLabel(obtain.vipMonth)
		local label = if year and month then string.format("%02d.%04d", month, year) else obtain.vipMonth
		return Text.get(use, "wardrobe.obtain.vip", { month = label })
	end
	return ""
end

local function Wardrobe(scope: Scope, props: Props?): Fusion.Child
	local start = WardrobeStart.kind
	local startTry = WardrobeStart.try and Cosmetics.get(WardrobeStart.try)
	WardrobeStart.kind = nil
	WardrobeStart.try = nil
	if startTry then
		start = startTry.kind -- S120: the tab of the tried-on cosmetic
	end
	local kind = scope:Value(if start and table.find(Cosmetics.kinds, start :: any) then start else "outfit")
	local mountState = State.Value({ "character", "mounts" })
	local tried = scope:Value(if startTry then startTry.id else nil :: string?) -- previewed (not yet equipped) cosmetic
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
		Size = UDim2.fromOffset(PREVIEW, PREVIEW_HEIGHT),
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
	local orbit = CHARACTER_ORBIT
	local function rebuild()
		if model then
			model:Destroy()
			model = nil
		end
		if pet then
			pet:Destroy()
			pet = nil
		end
		local acc = Fusion.peek(account)
		local triedId = Fusion.peek(tried)
		local triedDef = triedId and Cosmetics.get(triedId)
		-- S97: the mount skin tab (or a tried-on mount skin) shows the active mount instead of the character.
		if Fusion.peek(kind) == "mountskin" or (triedDef and triedDef.kind == "mountskin") then
			orbit = MOUNT_ORBIT
			local mountId = Mounts.activeOf(Fusion.peek(mountState)) or "mount_horse"
			local skinId = if triedDef and triedDef.kind == "mountskin"
				then triedDef.id
				elseif type(acc) == "table" then acc.cosmetics.equipped.mountskin
				else nil
			local mount = MountLook.preview(mountId, skinId)
			if mount then
				mount:PivotTo(mount:GetPivot() * CFrame.new(0, -3, 0))
				mount.Parent = viewport
				model = mount
			end
			return
		end
		orbit = CHARACTER_ORBIT
		model = cloneCharacter()
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
	scope:Observer(kind):onChange(rebuild)
	scope:Observer(mountState):onChange(function()
		if Fusion.peek(kind) == "mountskin" then
			rebuild()
		end
	end)
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
				CFrame.new(Vector3.new(math.sin(angle) * orbit, 1.5, math.cos(angle) * orbit), Vector3.new(0, 0.2, 0))
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
			-- S97: earned in the game, not for sale: no button until owned
			local earned = def.obtain ~= nil and not isOwned
			local button = Button(s, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(150, 44),
				Variant = if action then "secondary" else "primary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(s, action or "wardrobe.buy"),
				Visible = not earned,
				Disabled = if action then false else (use(shards) or 0) < def.price,
				OnClick = function()
					if isOn then
						invoke("CosmeticEquip", def.kind, nil)
					elseif isOwned then
						invoke("CosmeticEquip", def.kind, def.id)
					else
						-- S120: every purchase for Dragon Currency asks first.
						PremiumConfirm.ask({
							name = Text.now(def.nameKey),
							desc = Text.now(`wardrobe.kind.{def.kind}`),
							price = def.price,
							shards = Fusion.peek(shards) or 0,
							remote = "PremiumBuyCosmetic",
							arg = def.id,
						})
					end
				end,
			})
			-- S120: price and balance after on the buy button (with the reason while it is greyed out), as in the shop.
			if action == nil and not earned then
				Tooltip.attach(
					s,
					button :: GuiObject,
					s:Computed(function(use2): string
						return PremiumConfirm.describe({
							name = Text.get(use2, def.nameKey),
							desc = Text.get(use2, `wardrobe.kind.{def.kind}`),
							price = def.price,
							shards = use2(shards) or 0,
							remote = "PremiumBuyCosmetic",
							arg = def.id,
						}, "tooltip")
					end)
				)
			end
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
							Text = if UiArtState.ready(use, UiArt.cosmetic(def.id)) then "" else def.icon,
							TextScaled = true,
							FontFace = Theme.Fonts.BodyBold,
							TextColor3 = Color3.new(1, 1, 1),
							TextStrokeTransparency = 0.4,
							[Children] = {
								s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
								-- S119: the cosmetic's picture on its colour once loaded (mount skins: no files, glyph).
								ArtIcon.Image(s, { Key = UiArt.cosmetic(def.id), Corner = Theme.Corner.Small }),
							},
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
							Text = if isOwned
								then Text.get(use, "premium.owned")
								elseif earned then obtainText(use, def)
								else `◆ {Format.number(def.price)}`,
							FontFace = Theme.Fonts.Body,
							TextSize = Theme.TextSize.Small,
							TextColor3 = if isOwned
								then Theme.Colors.Success
								elseif earned then Theme.Colors.TextMuted
								else Theme.Colors.Accent,
							TextTruncate = Enum.TextTruncate.AtEnd,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						button,
					},
				})
			)
		end
		return list
	end)

	local openShop = props and props.OpenShop

	-- S121: saved looks ---------------------------------------------------------------------------
	local outfits = State.Value({ "account", "outfits" })
	local passes = State.Value({ "passes" })
	local selectedOutfit = scope:Value(1)
	local function outfitAt(list: any, i: number): any
		local outfit = if type(list) == "table" then list[i] else nil
		if type(outfit) ~= "table" or type(outfit.equipped) ~= "table" then
			return nil
		end
		if next(outfit.equipped) == nil and outfit.pet == nil then
			return nil
		end
		return outfit
	end
	local slots = scope:Computed(function(use): number
		local owned = use(passes)
		return Premium.outfitSlots(if type(owned) == "table" then owned else {})
	end)
	local function outfitNames(use: Fusion.Use, outfit: any): string
		local names = {}
		for _, k in Cosmetics.kinds do
			local id = if k == "pet" then outfit.pet else outfit.equipped[k]
			local def = if type(id) == "string" then Cosmetics.get(id) else nil
			if def then
				table.insert(names, Text.get(use, def.nameKey))
			end
		end
		return table.concat(names, ", ")
	end
	local tiles: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	}
	for i = 1, Products.OUTFITS_PLUS do
		local locked = scope:Computed(function(use): boolean
			return i > use(slots)
		end)
		local tile = scope:New("TextButton")({
			LayoutOrder = i,
			Size = UDim2.fromOffset(OUTFIT_TILE, OUTFIT_TILE),
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Colors.PanelRaised,
			BackgroundTransparency = scope:Computed(function(use): number
				return if outfitAt(use(outfits), i) == nil or use(locked) then 0.55 else 0.1
			end),
			Text = scope:Computed(function(use): string
				return if use(locked) then "🔒" else tostring(i)
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Body,
			TextColor3 = scope:Computed(function(use): Color3
				return if use(locked) then Theme.Colors.TextMuted else Theme.Colors.Text
			end),
			[OnEvent("Activated")] = function()
				Sounds.play("click")
				if Fusion.peek(locked) then
					-- the Wardrobe+ card is on the Passes tab (never a dead tile)
					if openShop then
						openShop("passes")
					else
						Toast.push(Text.now("wardrobe.error.outfitLocked"), "error")
					end
					return
				end
				selectedOutfit:set(i)
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = scope:Computed(function(use): Color3
						return if use(selectedOutfit) == i and not use(locked)
							then Theme.Colors.GoldBright
							else Theme.Colors.Border
					end),
					Thickness = scope:Computed(function(use): number
						return if use(selectedOutfit) == i and not use(locked)
							then Theme.Stroke.Thick
							else Theme.Stroke.Thin
					end),
				}),
				-- the colour of the saved outfit (or a gold dot) on a saved look
				scope:New("Frame")({
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -4, 1, -4),
					Size = UDim2.fromOffset(10, 10),
					Visible = scope:Computed(function(use): boolean
						return outfitAt(use(outfits), i) ~= nil and not use(locked)
					end),
					BackgroundColor3 = scope:Computed(function(use): Color3
						local outfit = outfitAt(use(outfits), i)
						local def = outfit and outfit.equipped.outfit and Cosmetics.get(outfit.equipped.outfit)
						return if def then Color3.fromHex(def.color) else Theme.Colors.GoldDim
					end),
					[Children] = { scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }) },
				}),
			},
		}) :: GuiObject
		Tooltip.attach(
			scope,
			tile,
			scope:Computed(function(use): string
				if use(locked) then
					return Text.get(use, "wardrobe.outfit.locked")
				end
				local outfit = outfitAt(use(outfits), i)
				if outfit == nil then
					return Text.get(use, "wardrobe.outfit.empty")
				end
				return outfitNames(use, outfit)
			end)
		)
		table.insert(tiles, tile)
	end
	local outfitRow = scope:New("Frame")({
		Position = UDim2.fromOffset(0, PREVIEW_HEIGHT + 6),
		Size = UDim2.fromOffset(PREVIEW, 22 + OUTFIT_TILE + 6 + 44),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "wardrobe.outfits"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("Frame")({
				Position = UDim2.fromOffset(0, 22),
				Size = UDim2.new(1, 0, 0, OUTFIT_TILE),
				BackgroundTransparency = 1,
				[Children] = tiles :: any,
			}),
			Button(scope, {
				Position = UDim2.fromOffset(0, 22 + OUTFIT_TILE + 6),
				Size = UDim2.new(0.5, -4, 0, 44),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "wardrobe.outfit.wear"),
				Disabled = scope:Computed(function(use): boolean
					local i = use(selectedOutfit)
					return outfitAt(use(outfits), i) == nil or i > use(slots)
				end),
				OnClick = function()
					invoke("OutfitWear", Fusion.peek(selectedOutfit))
				end,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 22 + OUTFIT_TILE + 6),
				Size = UDim2.new(0.5, -4, 0, 44),
				Variant = "primary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "wardrobe.outfit.save"),
				Disabled = scope:Computed(function(use): boolean
					return use(selectedOutfit) > use(slots)
				end),
				OnClick = function()
					local i = Fusion.peek(selectedOutfit)
					if outfitAt(Fusion.peek(outfits), i) == nil then
						invoke("OutfitSave", i)
						return
					end
					PremiumConfirm.modal({
						Title = Text.now("wardrobe.outfits"),
						Message = Text.now("wardrobe.outfit.overwrite", { n = i }),
						ConfirmText = Text.now("wardrobe.outfit.save"),
						CancelText = Text.now("common.cancel"),
						OnConfirm = function(_text: string): (boolean, string?)
							invoke("OutfitSave", i)
							return true, nil
						end,
					})
				end,
			}),
		},
	})
	local HINT_Y = PREVIEW_HEIGHT + 6 + 22 + OUTFIT_TILE + 6 + 44 + 6

	local tabs = {}
	for _, k in Cosmetics.kinds do
		table.insert(tabs, { id = k, label = Text.T(scope, `wardrobe.kind.{k}`) })
	end

	return {
		viewport :: Instance,
		outfitRow,
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(0, HINT_Y),
			Size = UDim2.fromOffset(PREVIEW, 50),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return use(kind) ~= "mountskin"
			end),
			Text = Text.T(scope, "wardrobe.hint"),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.TextMuted,
		}),
		-- S97: an extra line on the mount skin tab (the look works on every mount)
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(0, HINT_Y),
			Size = UDim2.fromOffset(PREVIEW, 50),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return use(kind) == "mountskin"
			end),
			Text = Text.T(scope, "wardrobe.mountskin.hint"),
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
					Size = UDim2.new(1, -(TOP_UP_WIDTH + 10), 0, 28),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return `◆ {Format.number(use(shards) or 0)}`
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.Accent,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				-- S120: "Top up" opens the Dragon Shop on the currency tab (44 px high on a phone).
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 44),
					Size = scope:Computed(function(use): UDim2
						return UDim2.fromOffset(TOP_UP_WIDTH, if use(Device.Touch) then Theme.Size.MinTouch else 36)
					end),
					Variant = "primary",
					TextSize = Theme.TextSize.Small,
					Text = Text.T(scope, "premium.topUp"),
					Visible = openShop ~= nil,
					OnClick = function()
						if openShop then
							openShop()
						end
					end,
				}),
				scope:New("ScrollingFrame")({
					Position = scope:Computed(function(use): UDim2
						return UDim2.fromOffset(0, if use(Device.Touch) then 94 else 84)
					end),
					Size = scope:Computed(function(use): UDim2
						return UDim2.new(1, 0, 1, if use(Device.Touch) then -94 else -84)
					end),
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
