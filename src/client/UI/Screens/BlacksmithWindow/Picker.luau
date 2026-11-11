--!strict
-- Forge: the item picker shared by the Upgrading and Transmute tabs (S134j, was inside Upgrade.luau): a target is an
-- equipped slot ("eq", slot) or a backpack index ("inv", "<n>"), resolved against the live state; the list shows the
-- equipped items first, then the backpack, filtered by the tab.
-- Review 2026-11-11 (owner 2026-11-10: "things covering each other"): the anvil tabs' footer line (Picker.status)
-- says why their pinned button is greyed out, else what it costs (Picker.price).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local SelectableSlot = require(script.Parent.Parent.Parent.Components.SelectableSlot)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Target = { location: string, key: string }

export type ListProps = {
	Prefix: string, -- unique id prefix of the list's slots ("up", "rr")
	Target: Fusion.Value<Target?>,
	Inventory: Fusion.UsedAs<any>,
	Equipment: Fusion.UsedAs<any>,
	Filter: (item: Types.ItemInstance) -> boolean, -- equipment only is already checked
	OnPick: (() -> ())?,
}

-- What a service takes (Logic/Upgrade.Cost, Logic/Transmog.Cost): the gold and the materials with their counts.
type Cost = { gold: number, materials: { { id: string, n: number } } }

export type StatusProps = {
	Reason: Fusion.UsedAs<string?>, -- the text key of why the button is greyed out; nil while nothing blocks it
	Hints: { [string]: boolean }, -- reasons that only say what to pick next: muted, not an error
	Price: Fusion.UsedAs<string>, -- shown while nothing blocks ("" with no item)
	Inset: Fusion.UsedAs<number>, -- the room the buttons right of the line take (their widths and the row's gaps)
}

local Picker = {}

-- Units of `itemId` in the backpack.
function Picker.count(inv: any, itemId: string): number
	local n = 0
	for _, item in inv or {} do
		if item.id == itemId then
			n += item.n
		end
	end
	return n
end

function Picker.resolve(target: Target?, inventory: any, equipment: any): Types.ItemInstance?
	if not target then
		return nil
	end
	if target.location == "eq" then
		return if type(equipment) == "table" then equipment[target.key] else nil
	end
	return if type(inventory) == "table" then inventory[target.key] else nil
end

-- The selectable slots of every equipment item passing `Filter`: equipped first, then the backpack.
function Picker.list(scope: Scope, props: ListProps): Fusion.Computed<{ Instance }>
	return scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		local order = 0
		local function add(location: string, key: string, candidate: Types.ItemInstance)
			order += 1
			table.insert(
				list,
				SelectableSlot(s, {
					Id = `{props.Prefix}:{location}:{key}`,
					LayoutOrder = order,
					Size = 56,
					Item = candidate,
					Selected = s:Computed(function(use2): boolean
						local t = use2(props.Target)
						return t ~= nil and t.location == location and t.key == key
					end),
					OnToggle = function()
						props.Target:set({ location = location, key = key })
						if props.OnPick then
							props.OnPick()
						end
					end,
				})
			)
		end
		local function fits(candidate: Types.ItemInstance): boolean
			local def = Items.get(candidate.id)
			return def ~= nil and def.category == "equipment" and props.Filter(candidate)
		end
		for slot, candidate in use(props.Equipment) or {} do
			if slot ~= "backpack" and fits(candidate) then
				add("eq", slot, candidate)
			end
		end
		local inventory = use(props.Inventory) or {}
		local keys = {}
		for key in inventory do
			table.insert(keys, tonumber(key) :: number)
		end
		table.sort(keys)
		for _, index in keys do
			local candidate = (inventory :: any)[tostring(index)]
			if candidate and fits(candidate) then
				add("inv", tostring(index), candidate)
			end
		end
		return list
	end)
end

-- The forging tension of both tabs: sparks flying from the anvil with a rising "hit" sound over `duration` seconds.
function Picker.sparks(holder: Instance?, duration: number)
	if not holder then
		return
	end
	for i = 1, 18 do
		task.delay(i * duration / 20, function()
			local spark = Instance.new("Frame")
			spark.AnchorPoint = Vector2.new(0.5, 0.5)
			spark.Position = UDim2.fromScale(0.5, 0.55)
			spark.Size = UDim2.fromOffset(6, 6)
			spark.BackgroundColor3 = Theme.Brass.Bright
			spark.BorderSizePixel = 0
			spark.ZIndex = 5
			spark.Parent = holder
			local angle = math.random() * math.pi * 2
			local distance = 60 + math.random() * 90
			TweenService:Create(spark, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, math.cos(angle) * distance, 0.55, math.sin(angle) * distance - 30),
				BackgroundTransparency = 1,
			}):Play()
			task.delay(0.55, function()
				spark:Destroy()
			end)
			Sounds.playPitched("hit", 0.8 + i * 0.07)
		end)
	end
end

-- Review 2026-11-11 (owner 2026-11-10: "things covering each other"): the anvil tabs' main buttons stand in the
-- window's footer, so the line saying what they wait for stands there too, first in the row, left of them: why the
-- button is greyed out (Danger; a "pick ..." hint muted) or, while it can be pressed, its price (UI-ZASADY §1: the
-- price and the error that blocks the action stay on top, next to the action button). The reason was the last line
-- of the anvil's scroll, below the fold on PC and on every phone. Small 17, at most two lines in the 52-px row
-- (tests/gearlayout.spec checks every reason and the dearest price on the narrowest phone).
function Picker.status(scope: Scope, props: StatusProps): Instance
	return scope:New("TextLabel")({
		Name = "Status",
		LayoutOrder = 0,
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(1, -use(props.Inset), 1, 0)
		end),
		BackgroundTransparency = 1,
		RichText = true,
		TextWrapped = true,
		Text = scope:Computed(function(use): string
			local why = use(props.Reason)
			return if why then Text.get(use, why) else use(props.Price)
		end),
		FontFace = Theme.Fonts.BodyMedium,
		TextSize = Theme.TextSize.Small,
		TextColor3 = scope:Computed(function(use): Color3
			local why = use(props.Reason)
			if why == nil then
				return Theme.Paper.Text
			end
			return if props.Hints[why] then Theme.Paper.TextMuted else Theme.Paper.Danger
		end),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- The price on the footer's line: the gold, then each material with how many it takes ("" without a cost). What the
-- player owns of each stays in the anvil's cost line, with where the stone comes from behind its "i".
function Picker.price(use: Fusion.Use, cost: Cost?): string
	if not cost then
		return ""
	end
	local parts = { `<font color="{Theme.hex(Theme.Paper.Heading)}">◉ {Format.number(cost.gold)}</font>` }
	for _, material in cost.materials do
		table.insert(parts, `{ItemText.get(use, material.id)} ×{material.n}`)
	end
	return table.concat(parts, "  ")
end

return Picker
