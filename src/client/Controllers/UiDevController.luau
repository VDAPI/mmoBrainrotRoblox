--!strict
-- Studio review 2026-10-21: the windows and an item's tooltip on an admin's client without mouse or keyboard. `/ui`
-- (Data/AdminCommands, Admin/Perf) sends its call here through "AdminClient"; the Studio MCP session calls the same
-- through the BindableFunction Players.LocalPlayer.UiCall (admins only, like AnimLabCall), which answers in JSON:
--   list                     the registered windows (WindowManager) and the open ones
--   open <window>            WindowManager.Open (a window that needs an NPC, a shop or a target opens without one)
--   close [window]           that window, or every window and the tooltip preview
--   tooltip <item> [rarity]  the item's tooltip lines (Logic/TooltipModel, what UI/Components/ItemTooltip draws) in
--                            the compact view and the full view (the details key, Alt) side by side, from a roll of
--                            the item at its level (rarity 1-5 or common / unique / heroic / legendary / mythic,
--                            legendary by default); the lines also go to the Output
--   state                    the open windows and whether the preview shows
-- Nothing here reaches players or the wiki: the texts of the preview are the tooltip's own.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Locale = require(ReplicatedStorage.Shared.Util.Locale)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Rng = require(ReplicatedStorage.Shared.Logic.Rng)
local State = require(script.Parent.Parent.UI.State)
local Theme = require(script.Parent.Parent.UI.Theme)
local TooltipModel = require(ReplicatedStorage.Shared.Logic.TooltipModel)

local UiDevController = {
	Name = "UiDevController",
	Deps = { "WindowManager" },
}

local WindowManager: any
local player = Players.LocalPlayer

local PREVIEW = "UiDevTooltip"
local WIDTH = 340 -- UI/Components/ItemTooltip
local RARITY_NAMES: { [string]: number } = {
	common = Rarities.COMMON,
	unique = Rarities.UNIQUE,
	heroic = Rarities.HEROIC,
	legendary = Rarities.LEGENDARY,
	mythic = Rarities.MYTHIC,
}
local TONES: { [string]: Color3 } = {
	muted = Theme.Iron.TextMuted,
	good = Theme.Iron.Success,
	bad = Theme.Iron.Danger,
	bonus = Theme.Iron.Link,
}
local SIZES: { [string]: number } = {
	large = Theme.TextSize.Large,
	body = Theme.TextSize.Body,
	small = Theme.TextSize.Small,
}

local preview: ScreenGui? = nil

local function rarityOf(text: string?): number
	local n = tonumber(text)
	if n then
		return math.clamp(math.floor(n), Rarities.COMMON, Rarities.MYTHIC)
	end
	return RARITY_NAMES[string.lower(text or "")] or Rarities.LEGENDARY
end

-- The lines of the item's tooltip in one view, as TooltipModel gives them to ItemTooltip.
local function linesOf(item: any, view: string): { TooltipModel.Line }
	local ctx: TooltipModel.Ctx = {
		lang = Locale.getLanguage(),
		level = State.Get({ "character", "level" }) or 1,
		class = State.Get({ "character", "class" }),
		input = "mouse",
		detailsKey = Keybinds.label("item_details"),
		view = view :: any,
	}
	return TooltipModel.build(item, Items.get(item.id), ctx).lines
end

local function closePreview()
	if preview then
		preview:Destroy()
		preview = nil
	end
end

local function column(parent: Instance, x: number, title: string, lines: { TooltipModel.Line })
	local frame = Instance.new("Frame")
	frame.Name = title
	frame.Position = UDim2.fromOffset(x, 80)
	frame.Size = UDim2.fromOffset(WIDTH, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Theme.Iron.Surface
	frame.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Brass.Frame
	stroke.Thickness = Theme.Size.FrameInner
	stroke.Parent = frame
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(padding :: any)[side] = UDim.new(0, 10)
	end
	padding.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = frame
	local heading = Instance.new("TextLabel")
	heading.LayoutOrder = 0
	heading.BackgroundTransparency = 1
	heading.Size = UDim2.fromScale(1, 0)
	heading.AutomaticSize = Enum.AutomaticSize.Y
	heading.FontFace = Theme.Fonts.BodyBold
	heading.TextSize = Theme.TextSize.Caption
	heading.TextColor3 = Theme.Iron.TextMuted
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Text = title
	heading.Parent = frame
	for order, entry in lines do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, if entry.role == "gap" then 4 else 0)
		label.AutomaticSize = if entry.role == "gap" then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
		label.RichText = true
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.FontFace = if entry.font == "heading"
			then Theme.Fonts.Display
			elseif entry.font == "bold" then Theme.Fonts.BodyBold
			else Theme.Fonts.Body
		label.TextSize = SIZES[entry.size or ""] or Theme.TextSize.Small
		label.TextColor3 = if entry.hex then Color3.fromHex(entry.hex) else TONES[entry.tone] or Theme.Iron.Text
		label.Text = if entry.role == "gap" then "" else entry.text
		label.Parent = frame
	end
	frame.Parent = parent
end

local function texts(lines: { TooltipModel.Line }): { string }
	local out = {}
	for _, entry in lines do
		if entry.role ~= "gap" then
			table.insert(out, entry.text)
		end
	end
	return out
end

local function showTooltip(itemId: string, rarityText: string?): { [string]: any }
	local def = Items.get(itemId)
	if not def then
		return { ok = false, error = `unknown item {itemId}` }
	end
	local rarity = rarityOf(rarityText)
	local ok, item = pcall(ItemRoll.rollItem, itemId, def.level, rarity, Rng.new(7), `uidev:{itemId}`)
	if not ok then
		return { ok = false, error = tostring(item) }
	end
	local compact, full = linesOf(item, "compact"), linesOf(item, "full")
	closePreview()
	local gui = Instance.new("ScreenGui")
	gui.Name = PREVIEW
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	column(gui, 20, `{itemId} · compact`, compact)
	column(gui, 40 + WIDTH, `{itemId} · full ({Keybinds.label("item_details")})`, full)
	gui.Parent = player:WaitForChild("PlayerGui")
	preview = gui
	local result =
		{ ok = true, item = itemId, rarity = (item :: any).rarity, compact = texts(compact), full = texts(full) }
	print("[UiDev] tooltip", HttpService:JSONEncode(result))
	return result
end

local function stateOf(): { [string]: any }
	local all, shown = WindowManager.Ids()
	return { ok = true, windows = #all, open = shown, preview = preview ~= nil }
end

local function run(op: string, id: string?, option: string?): { [string]: any }
	local target = if id and id ~= "" then id else nil
	if op == "list" then
		local all, shown = WindowManager.Ids()
		print(`[UiDev] windows ({#all}): {table.concat(all, ", ")}`)
		return { ok = true, windows = all, open = shown }
	elseif op == "open" then
		local all = WindowManager.Ids()
		if not target or not table.find(all, target) then
			return { ok = false, error = `unknown window {target or ""}` }
		end
		local ok, err = pcall(WindowManager.Open, target)
		if not ok then
			warn(`[UiDev] open {target}: {err}`)
			return { ok = false, error = tostring(err) }
		end
		return stateOf()
	elseif op == "close" then
		if target then
			WindowManager.Close(target)
		else
			WindowManager.CloseAll()
			closePreview()
		end
		return stateOf()
	elseif op == "tooltip" then
		if not target then
			return { ok = false, error = "no item" }
		end
		return showTooltip(target, if option ~= "" then option else nil)
	elseif op == "state" then
		return stateOf()
	end
	return { ok = false, error = `unknown op {op}` }
end

local function installCall()
	if player:FindFirstChild("UiCall") then
		return
	end
	local fn = Instance.new("BindableFunction")
	fn.Name = "UiCall"
	fn.OnInvoke = function(line: any): string
		local words = string.split(tostring(line), " ")
		local ok, result = pcall(run, words[1] or "", words[2], words[3])
		return HttpService:JSONEncode(if ok then result else { ok = false, error = tostring(result) })
	end
	fn.Parent = player
end

function UiDevController.Init(registry: any)
	WindowManager = registry.Get("WindowManager")
end

function UiDevController.Start()
	Net.On("AdminClient", function(action: any, args: any)
		if action ~= "ui" or type(args) ~= "table" then
			return
		end
		local op, id, option = args[1], args[2], args[3]
		if type(op) ~= "string" then
			return
		end
		local ok, result =
			pcall(run, op, if type(id) == "string" then id else nil, if type(option) == "string" then option else nil)
		if not ok then
			warn(`[UiDev] {tostring(result)}`)
		elseif result.ok == false then
			warn(`[UiDev] {result.error}`)
		end
	end)
	if player:GetAttribute("Admin") == true then
		installCall()
	end
	player:GetAttributeChangedSignal("Admin"):Connect(function()
		if player:GetAttribute("Admin") == true then
			installCall()
		end
	end)
end

return UiDevController
