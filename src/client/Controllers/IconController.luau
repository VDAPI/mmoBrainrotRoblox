--!strict
-- Item icon admin helpers on the client (S35): /icons (atlas state and the preload result of every sheet),
-- /icons glyph | art (switch between the old glyphs and the pictures, not saved), /icongrid <group> (a preview window
-- of every icon of a group in Common slots; "tiers <type>" = the 21 tiers of one base side by side).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.Parent.UI.IconState)
local ItemIcons = require(ReplicatedStorage.Shared.Logic.ItemIcons)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.UI.Components.ItemSlot)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Rng = require(ReplicatedStorage.Shared.Logic.Rng)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local IconController = {
	Name = "IconController",
	Deps = { "UIController" },
}

local UIController: any
local gridScope: any = nil

local SLOT = 52

-- Item ids of a /icongrid group, sorted ("eq" one per base type at tier 30, "uniq", "mat", "pot", "misc", or the
-- tiers of one base).
function IconController.GroupIds(group: string, baseType: string?): { string }
	local ids = {}
	for id, def in Items.byId do
		local key = ItemIcons.keyOf(def)
		local prefix = if key then string.match(key, "^(%a+)/") else nil
		if group == "tiers" then
			if def.type == baseType and def.tier and not def.fixedBonuses then
				table.insert(ids, id)
			end
		elseif group == "eq" then
			if prefix == "eq" and def.tier == 30 then
				table.insert(ids, id)
			end
		elseif group == "misc" then
			if prefix == "misc" or prefix == "tool" or prefix == "bless" then
				table.insert(ids, id)
			end
		elseif prefix == group then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local da, db = Items.get(a) :: Items.ItemDef, Items.get(b) :: Items.ItemDef
		if (da.tier or 0) ~= (db.tier or 0) then
			return (da.tier or 0) < (db.tier or 0)
		end
		return a < b
	end)
	return ids
end

local function closeGrid()
	if gridScope then
		gridScope:doCleanup()
		gridScope = nil
	end
end

local function openGrid(group: string, baseType: string?)
	closeGrid()
	local ids = IconController.GroupIds(group, baseType)
	if #ids == 0 then
		Toast.push(Text.now("admin.icongrid.empty", { group = group }), "warning")
		return
	end
	local scope = Fusion.scoped(Fusion)
	gridScope = scope
	local slots = {}
	for i, id in ids do
		local def = Items.get(id) :: Items.ItemDef
		local item = if def.category == "equipment"
			then ItemRoll.rollItem(id, def.tier or def.level, Rarities.COMMON, Rng.new(1), `icongrid:{id}`)
			else ItemRoll.makeStack(id, 1, `icongrid:{id}`)
		table.insert(
			slots,
			ItemSlot(scope, { SlotId = `view:icongrid:{id}`, Item = item, Size = SLOT, LayoutOrder = i })
		)
	end
	scope:New("Frame")({
		Name = "IconGrid",
		Parent = UIController.GetLayer("Modals"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(720, 520),
		BackgroundColor3 = Theme.Colors.Panel,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 2 }),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(16, 8),
				Size = UDim2.new(1, -80, 0, 32),
				BackgroundTransparency = 1,
				Text = Text.now("admin.icongrid.title", { group = baseType or group, n = #ids }),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.GoldBright,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("TextButton")({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 8),
				Size = UDim2.fromOffset(36, 32),
				BackgroundColor3 = Theme.Colors.PanelRaised,
				Text = "✕",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 18,
				TextColor3 = Theme.Colors.Text,
				[OnEvent("Activated")] = closeGrid,
				[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			}),
			scope:New("ScrollingFrame")({
				Position = UDim2.fromOffset(12, 48),
				Size = UDim2.new(1, -24, 1, -60),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 6,
				[Children] = {
					scope:New("UIGridLayout")({
						CellSize = UDim2.fromOffset(SLOT, SLOT),
						CellPadding = UDim2.fromOffset(8, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					slots :: any,
				},
			}),
		},
	})
end

local function status()
	local parts = {}
	for n = 1, ItemIcons.SHEETS do
		table.insert(parts, `{n}: {ItemIcons.sheet(n) or "—"} ({IconState.Status[n] or "none"})`)
	end
	Toast.push(
		Text.now("admin.icons.client", {
			ready = tostring(ItemIcons.ready()),
			loaded = tostring(Fusion.peek(IconState.Ok)),
			mode = Fusion.peek(IconState.Mode),
			sheets = table.concat(parts, " · "),
		}),
		"info",
		8
	)
end

function IconController.Init(registry)
	UIController = registry.Get("UIController")
	Net.On("AdminClient", function(action: any, arg: any)
		if action == "icons" then
			if arg == "glyph" or arg == "art" then
				IconState.Mode:set(arg)
			end
			status()
		elseif action == "icongrid" and type(arg) == "table" then
			openGrid(tostring(arg[1] or "eq"), if arg[2] then tostring(arg[2]) else nil)
		end
	end)
end

function IconController.Start() end

return IconController
