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
-- S123 (DESIGN-17 §4): two-level tabs (Data/Cosmetics.groups, then the group's kinds; both scroll sideways on a phone),
-- ownership through Logic/CosmeticRules (free emotes say "Free"), starter pack cosmetics say "In a pack: …" without a
-- button, the offer of the week marks its rows (the discounted one with the old price struck through; prices from
-- Logic/WeeklyOffer.priceOf, sent with the purchase). Per kind: a dye on the worn outfit in the preview (a line
-- without an outfit), the portrait frame tile, a chat line and bubble, the title over the character; titles are worn
-- with SetTitle ("Take off" hides the title), emotes and level-up effects preview on the own character in the world
-- (props.PreviewEmote / PreviewLevelUp, nobody else sees them).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Button = require(script.Parent.Parent.Components.Button)
local CosmeticLook = require(ReplicatedStorage.Shared.Util.CosmeticLook)
local CosmeticRules = require(ReplicatedStorage.Shared.Logic.CosmeticRules)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Device = require(script.Parent.Parent.Device)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MountLook = require(ReplicatedStorage.Shared.Util.MountLook)
local Mounts = require(ReplicatedStorage.Shared.Logic.Mounts)
local Net = require(ReplicatedStorage.Shared.Net)
local PortraitFrame = require(script.Parent.Parent.Components.PortraitFrame)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local PremiumConfirm = require(script.Parent.Parent.PremiumConfirm)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local Toast = require(script.Parent.Parent.Components.Toast)
local Tooltip = require(script.Parent.Parent.Components.Tooltip)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.UiArtState)
local WardrobeStart = require(script.Parent.Parent.WardrobeStart)
local WeeklyClock = require(script.Parent.Parent.WeeklyClock)
local WeeklyOffer = require(ReplicatedStorage.Shared.Logic.WeeklyOffer)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	-- S120: "Top up" (PremiumController.OpenShop("currency")); S121: a locked look opens the "passes" tab
	OpenShop: ((tab: string?) -> ())?,
	-- S123: local previews on the own character in the world (PremiumController: AnimationController.Emote,
	-- EffectsController.PlayLevelUp)
	PreviewEmote: ((emoteId: string) -> ())?,
	PreviewLevelUp: ((cosmeticId: string) -> ())?,
}

local PREVIEW = 330
local PREVIEW_HEIGHT = PREVIEW + 40 -- S121: room for the looks under the preview
local OUTFIT_TILE = 44
local TOP_UP_WIDTH = 100
local MOUNT_ORBIT = 15 -- S97: the camera further out for a mount
local CHARACTER_ORBIT = 11
-- S123: the kind tabs under the group tabs (a scrolling strip is ButtonHeightSmall + 6 high), then the balance
local KIND_TABS_Y = 50
local BALANCE_Y = 100

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
	elseif obtain and obtain.pack then
		-- S123: only in a starter pack
		return Text.get(use, "wardrobe.obtain.pack", { pack = Text.get(use, `premium.pack.{obtain.pack}`) })
	elseif obtain and obtain.vipMonth then
		-- S121: the VIP cosmetic of the month
		local year, month = Time.monthLabel(obtain.vipMonth)
		local label = if year and month then string.format("%02d.%04d", month, year) else obtain.vipMonth
		return Text.get(use, "wardrobe.obtain.vip", { month = label })
	elseif obtain and obtain.arena == "shop" then
		-- S128: the arena shop at the Arena Master (Arena Tokens)
		local entry = Arena.shopOf(def.id)
		return Text.get(use, "wardrobe.obtain.arena", { price = if entry then entry.price else 0 })
	elseif obtain and obtain.arena == "season" then
		return Text.get(use, "wardrobe.obtain.arenaSeason")
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
	-- S123: the group of the kind (two-level tabs)
	local function groupOf(k: string): string
		for _, group in Cosmetics.groups do
			if table.find(group.kinds, k :: any) then
				return group.id
			end
		end
		return Cosmetics.groups[1].id
	end
	local group = scope:Value(groupOf(Fusion.peek(kind)))
	local mountState = State.Value({ "character", "mounts" })
	local tried = scope:Value(if startTry then startTry.id else nil :: string?) -- previewed (not yet equipped) cosmetic
	local account = State.Value({ "account" })
	local shards = State.Value({ "account", "dragonShards" })

	local titleState = State.Value({ "character", "title" }) -- S123: bought titles are worn on the character
	local function owns(acc: any, def: Cosmetics.Def): boolean
		return CosmeticRules.owns(def, if type(acc) == "table" then acc else nil)
	end
	local function equippedOf(acc: any, k: string): string?
		if type(acc) ~= "table" then
			return nil
		end
		return if k == "pet" then acc.pets.equipped else acc.cosmetics.equipped[k]
	end
	local previewEmote = props and props.PreviewEmote
	local previewLevelUp = props and props.PreviewLevelUp
	-- S123: the local preview of an emote or a level-up effect (on the own character in the world)
	local function preview(def: Cosmetics.Def)
		if def.kind == "emote" and def.emote and previewEmote then
			previewEmote(def.emote)
		elseif def.kind == "levelup" and previewLevelUp then
			previewLevelUp(def.id)
		end
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
	-- S123: the purchase spec at the price of the week (sent along: the server refuses another price)
	local function buySpec(def: Cosmetics.Def, price: number, balance: number): PremiumConfirm.Spec
		return {
			name = Text.now(def.nameKey),
			desc = Text.now(`wardrobe.kind.{def.kind}`),
			price = price,
			shards = balance,
			remote = "PremiumBuyCosmetic",
			arg = def.id,
			arg2 = price,
		}
	end
	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		local acc = use(account)
		local k = use(kind)
		local now = use(WeeklyClock.WeekStart)
		local offer = WeeklyOffer.at(now)
		local equipped = if k == "title" then nil else equippedOf(acc, k)
		local wornTitle = use(titleState)
		local index = 0
		for _, def in Cosmetics.list do
			if def.kind ~= k then
				continue
			end
			index += 1
			local isOwned = owns(acc, def)
			local isOn = if k == "title" then def.title ~= nil and wornTitle == def.title else equipped == def.id
			local price = WeeklyOffer.priceOf(def.id, now) or def.price
			local inOffer = table.find(offer.items, def.id) ~= nil
			-- the main button: wear / take off / preview (owned emote) / buy
			local action = if isOn
				then "wardrobe.takeOff"
				elseif isOwned and k == "emote" then "wardrobe.preview"
				elseif isOwned then "wardrobe.wear"
				else nil
			-- S97: earned in the game (or S123: in a starter pack), not for sale: no button until owned
			local earned = def.obtain ~= nil and not isOwned
			-- S123: emotes and level-up effects also preview before buying (a second, smaller button)
			local hasPreview = (k == "emote" and not isOwned) or k == "levelup"
			local button = Button(s, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(150, 44),
				Variant = if action then "secondary" else "primary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(s, action or "wardrobe.buy"),
				Visible = not earned,
				Disabled = if action then false else (use(shards) or 0) < price,
				OnClick = function()
					if k == "emote" and isOwned then
						preview(def)
					elseif k == "title" and isOn then
						invoke("SetTitle", nil) -- hides the title (Titles.NONE)
					elseif k == "title" and isOwned then
						invoke("SetTitle", def.title)
					elseif isOn then
						invoke("CosmeticEquip", def.kind, nil)
					elseif isOwned then
						invoke("CosmeticEquip", def.kind, def.id)
					else
						-- S120: every purchase for Dragon Currency asks first.
						PremiumConfirm.ask(buySpec(def, price, Fusion.peek(shards) or 0))
					end
				end,
			})
			-- S120: price and balance after on the buy button (with the reason while it is greyed out), as in the shop.
			if action == nil and not earned then
				Tooltip.attach(
					s,
					button :: GuiObject,
					s:Computed(function(use2): string
						use2(Text.Lang)
						return PremiumConfirm.describe(buySpec(def, price, use2(shards) or 0), "tooltip")
					end)
				)
			end
			local previewButton = if hasPreview
				then Button(s, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -166, 0.5, 0),
					Size = UDim2.fromOffset(110, 44),
					Variant = "secondary",
					TextSize = Theme.TextSize.Small,
					Text = Text.T(s, "wardrobe.preview"),
					OnClick = function()
						preview(def)
					end,
				})
				else nil
			local textRight = if hasPreview then 360 else 240
			local priceText: string
			if isOwned and def.free == true then
				priceText = Text.get(use, "wardrobe.free")
			elseif isOwned then
				priceText = Text.get(use, "premium.owned")
			elseif earned then
				priceText = obtainText(use, def)
			elseif price < def.price then
				priceText = `◆ {Format.number(price)}  <s>{Format.number(def.price)}</s>  · {Text.get(
					use,
					"wardrobe.weekly"
				)}`
			elseif inOffer then
				priceText = `◆ {Format.number(price)}  · {Text.get(use, "wardrobe.weekly")}`
			else
				priceText = `◆ {Format.number(price)}`
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
							Size = UDim2.new(1, -textRight, 0, 26),
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
							Size = UDim2.new(1, -textRight, 0, 22),
							BackgroundTransparency = 1,
							RichText = true,
							Text = priceText,
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
						previewButton :: any,
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

	-- S123: two-level tabs: the groups, then the kinds of the chosen group (both scroll sideways on a phone)
	local groupTabs = {}
	for _, g in Cosmetics.groups do
		table.insert(groupTabs, { id = g.id, label = Text.T(scope, `wardrobe.group.{g.id}`) })
	end
	scope:Observer(group):onChange(function()
		local g = Fusion.peek(group)
		if groupOf(Fusion.peek(kind)) ~= g then
			for _, entry in Cosmetics.groups do
				if entry.id == g then
					kind:set(entry.kinds[1])
				end
			end
		end
	end)
	local kindTabs = scope:Computed(function(use, s: Scope): Instance
		local g = use(group)
		local tabs = {}
		for _, entry in Cosmetics.groups do
			if entry.id == g then
				for _, k in entry.kinds do
					table.insert(tabs, { id = k :: string, label = Text.T(s, `wardrobe.kind.{k}`) })
				end
			end
		end
		return Tabs(s, { Selected = kind, Tabs = tabs, Scroll = true, Position = UDim2.fromOffset(0, KIND_TABS_Y) })
	end)

	-- S123: what the tried-on (or worn) cosmetic of the open kind looks like, over the preview
	local function shownOf(use: Fusion.Use, k: string): Cosmetics.Def?
		local triedId = use(tried)
		local triedDef = if triedId then Cosmetics.get(triedId) else nil
		if triedDef and triedDef.kind == k then
			return triedDef
		end
		local acc = use(account)
		if k == "title" then
			local worn = use(titleState)
			local def = if type(worn) == "string" then TitleData.get(worn) else nil
			if def and (def.req :: any).kind == "cosmetic" then
				return Cosmetics.get((def.req :: any).id)
			end
			return nil
		end
		local id = equippedOf(acc, k)
		return if type(id) == "string" then Cosmetics.get(id) else nil
	end
	local charName = State.Value({ "character", "name" })
	local classId = State.Value({ "character", "class" })
	local overlay = scope:New("Frame")({
		Name = "PreviewOverlay",
		Size = UDim2.fromOffset(PREVIEW, PREVIEW_HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 5,
		[Children] = {
			-- the portrait frame
			PortraitFrame(scope, {
				Name = "FramePreview",
				Position = UDim2.fromOffset(10, 10),
				Size = 120,
				FrameId = scope:Computed(function(use): string?
					local def = shownOf(use, "frame")
					return if def then def.id else nil
				end),
				ClassColor = Theme.Colors.Gold,
				Visible = scope:Computed(function(use): boolean
					return use(kind) == "frame"
				end),
				Content = scope:New("TextLabel")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						local id = use(classId)
						local class = if type(id) == "string" then Classes.get(id) else nil
						return if class then class.icon else ""
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 56,
					TextColor3 = Theme.Colors.Gold,
				}),
			}),
			-- the title over the character (nameplate style)
			scope:New("TextLabel")({
				Name = "TitlePreview",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 16),
				Size = UDim2.new(1, -20, 0, 30),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(kind) == "title" and shownOf(use, "title") ~= nil
				end),
				Text = scope:Computed(function(use): string
					local def = shownOf(use, "title")
					local title = def and def.title and TitleData.get(def.title)
					return if title then `« {Text.get(use, title.nameKey)} »` else ""
				end),
				TextColor3 = scope:Computed(function(use): Color3
					local def = shownOf(use, "title")
					local title = def and def.title and TitleData.get(def.title)
					return if title then Color3.fromHex(title.color) else Theme.Colors.Text
				end),
				TextStrokeTransparency = 0.4,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Large,
			}),
			-- the chat line and the speech bubble
			scope:New("Frame")({
				Name = "ChatPreview",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.new(1, -20, 0, 92),
				BackgroundColor3 = Theme.Colors.Panel,
				BackgroundTransparency = 0.25,
				Visible = scope:Computed(function(use): boolean
					return use(kind) == "chatframe"
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(8, 4),
						Size = UDim2.new(1, -16, 0, 26),
						BackgroundTransparency = 1,
						RichText = true,
						Text = scope:Computed(function(use): string
							local decor = CosmeticRules.chatDecor(shownOf(use, "chatframe"))
							local name = use(charName) or ""
							local sample = Text.get(use, "wardrobe.chat.sample")
							if not decor then
								return `<b>{name}:</b> {sample}`
							end
							local c = Color3.fromHex(decor.color):ToHex()
							return `<font color="#{c}">{decor.left}</font><b>{name}</b><font color="#{c}">{decor.right}</font><b>:</b> {sample}`
						end),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(8, 36),
						Size = UDim2.new(1, -16, 0, 48),
						BackgroundColor3 = scope:Computed(function(use): Color3
							local bubble = CosmeticRules.bubble(shownOf(use, "chatframe"))
							return if bubble then Color3.fromHex(bubble.bg) else Color3.fromRGB(250, 250, 250)
						end),
						Text = Text.T(scope, "wardrobe.chat.sample"),
						TextWrapped = true,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = scope:Computed(function(use): Color3
							local bubble = CosmeticRules.bubble(shownOf(use, "chatframe"))
							return if bubble then Color3.fromHex(bubble.text) else Color3.fromRGB(30, 30, 30)
						end),
						[Children] = { scope:New("UICorner")({ CornerRadius = Theme.Corner.Large }) },
					}),
				},
			}),
			-- a dye needs a worn (or tried) outfit; emotes and level-up effects play in the world
			scope:New("TextLabel")({
				Name = "PreviewNote",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.new(1, -20, 0, 44),
				BackgroundColor3 = Theme.Colors.Panel,
				BackgroundTransparency = 0.25,
				Visible = scope:Computed(function(use): boolean
					local k = use(kind)
					if k == "emote" or k == "levelup" then
						return true
					end
					return k == "dye" and shownOf(use, "outfit") == nil
				end),
				Text = scope:Computed(function(use): string
					local k = use(kind)
					return Text.get(use, if k == "dye" then "wardrobe.dye.needOutfit" else "wardrobe.preview.world")
				end),
				TextWrapped = true,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Parchment,
				[Children] = { scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }) },
			}),
		},
	})
	return {
		viewport :: Instance,
		overlay,
		outfitRow,
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(0, HINT_Y),
			Size = UDim2.fromOffset(PREVIEW, 56),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return use(kind) ~= "mountskin"
			end),
			-- S123: the marks and gestures are seen by others (one more line)
			Text = scope:Computed(function(use): string
				local g = use(group)
				local hint = Text.get(use, "wardrobe.hint")
				return if g == "marks" or g == "gestures"
					then `{hint} {Text.get(use, "wardrobe.hint.social")}`
					else hint
			end),
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
				Tabs(scope, { Selected = group, Tabs = groupTabs, Scroll = true }),
				kindTabs :: any,
				scope:New("TextLabel")({
					Position = UDim2.fromOffset(0, BALANCE_Y + 4),
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
					Position = UDim2.new(1, 0, 0, BALANCE_Y),
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
						return UDim2.fromOffset(0, BALANCE_Y + (if use(Device.Touch) then 50 else 40))
					end),
					Size = scope:Computed(function(use): UDim2
						return UDim2.new(1, 0, 1, -(BALANCE_Y + (if use(Device.Touch) then 50 else 40)))
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
