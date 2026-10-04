--!strict
-- Character window (C), DESIGN §23: equipment silhouette on the left, primary stats with point
-- allocation and the grouped derived statistics on the right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local DerivedList = require(script.DerivedList)
local Equipment = require(script.Equipment)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local StatAllocator = require(script.StatAllocator)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local Titles = require(ReplicatedStorage.Shared.Logic.Titles)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local LEFT_WIDTH = 260
-- 4 stat rows (44 + 4) + points line + buttons + spacing.
local ALLOCATOR_HEIGHT = 290

-- "◀ title ▶" picker (S16): cycles through none + the unlocked titles, saved with SetTitle.
local function TitlePicker(scope: Scope, order: number): Instance
	local character = State.Value({ "character" })
	local unlocked = scope:Computed(function(use): { string }
		local c = use(character)
		return if c then Titles.unlocked(c) else {}
	end)
	local current = scope:Computed(function(use): string?
		local c = use(character)
		return if c then Titles.shown(c) else nil
	end)
	local function step(delta: number)
		local list = Fusion.peek(unlocked)
		if #list == 0 then
			Toast.push(Text.now("title.none.hint"), "info", 3)
			return
		end
		local index = 0 -- 0 = no title
		for i, id in list do
			if id == Fusion.peek(current) then
				index = i
			end
		end
		index = (index + delta) % (#list + 1)
		task.spawn(function()
			local ok, err = Net.Invoke("SetTitle", if index == 0 then nil else list[index])
			if not ok then
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end
	return scope:New("Frame")({
		Name = "Title",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		[Children] = {
			Button(scope, {
				Size = UDim2.fromOffset(34, 34),
				Text = "◀",
				Variant = "ghost",
				OnClick = function()
					step(-1)
				end,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(38, 0),
				Size = UDim2.new(1, -76, 1, 0),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local id = use(current)
					local def = if id then TitleData.get(id) else nil
					if def then
						return `« {Text.get(use, def.nameKey)} »`
					end
					return Text.get(use, "title.none", { count = #use(unlocked) })
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					local id = use(current)
					local def = if id then TitleData.get(id) else nil
					return if def then Color3.fromHex(def.color) else Theme.Colors.TextMuted
				end),
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(34, 34),
				Text = "▶",
				Variant = "ghost",
				OnClick = function()
					step(1)
				end,
			}),
		},
	})
end

local function CharacterWindow(scope: Scope): Fusion.Child
	local pending = scope:Value({} :: { [string]: number })
	local name = State.Value({ "character", "name" })
	local classId = State.Value({ "character", "class" })
	local level = State.Value({ "character", "level" })

	-- Any change of free points (confirm, level-up, reset) starts the allocation over.
	scope:Observer(State.Value({ "character", "statPoints" })):onChange(function()
		pending:set({})
	end)

	return {
		scope:New("Frame")({
			Name = "Left",
			Size = UDim2.new(0, LEFT_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, Theme.Padding.Small),
				}),
				scope:New("TextLabel")({
					Name = "CharName",
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 34),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return use(name) or ""
					end),
					FontFace = Theme.Fonts.Heading,
					TextSize = Theme.TextSize.Title,
					TextColor3 = Theme.Colors.Gold,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				scope:New("TextLabel")({
					Name = "ClassLevel",
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						local class = Classes.get(use(classId) or "")
						local className = if class then Text.get(use, class.nameKey) else ""
						return Text.get(use, "charSelect.classLevel", { class = className, level = use(level) or 1 })
					end),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.Parchment,
				}),
				TitlePicker(scope, 3),
				Equipment(scope, { LayoutOrder = 4 }),
			},
		}),
		scope:New("Frame")({
			Name = "Right",
			Position = UDim2.fromOffset(LEFT_WIDTH + Theme.Padding.Large, 0),
			Size = UDim2.new(1, -(LEFT_WIDTH + Theme.Padding.Large), 1, 0),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("Frame")({
					Name = "Allocator",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = StatAllocator(scope, { Pending = pending }),
				}),
				DerivedList(scope, {
					Pending = pending,
					Position = UDim2.fromOffset(0, ALLOCATOR_HEIGHT),
					Size = UDim2.new(1, 0, 1, -ALLOCATOR_HEIGHT),
				}) :: any,
			},
		}),
	}
end

return CharacterWindow
