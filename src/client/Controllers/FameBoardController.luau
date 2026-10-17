--!strict
-- The Hall of Fame by the town hall (S124, DESIGN-17 §5), client side (wzór SignController): the part tagged "FameBoard"
-- gets the writing on both faces from its attributes `Panels` (JSON of Logic/Leaderboard.townPanels, set by the server's
-- Leaderboard/TownBoard) and `Mode`: the title, the highest levels on the left, the first heroes at the top level of
-- each class on the right (free places muted), "this server only" when the shared stores are off, and a hint; plus a
-- prompt that opens the Rankings window. Each plaque tagged "FamePlinth" shows its class, the hero's name (attribute
-- `HeroName`) or "Awaiting the first", and the date (`At`). Text follows the player's language; parts streamed in later
-- are handled too.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Leaderboard = require(ReplicatedStorage.Shared.Logic.Leaderboard)
local Leaderboards = require(ReplicatedStorage.Shared.Data.Leaderboards)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use

local FameBoardController = {
	Name = "FameBoardController",
	Deps = { "RankingsController" },
}

local RankingsController: any

local rootScope = Fusion.scoped(Fusion)

local INK = Color3.fromHex("#F2E6C9")
local BOARD_PPS = 50
local PLAQUE_PPS = 60
local PROMPT_RANGE = 12

local function decode(json: any): { Leaderboard.Panel }?
	if type(json) ~= "string" then
		return nil
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and type(value) == "table" then value else nil
end

local function label(scope: Scope, props: { [string]: any }): Instance
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 15,
	}
	for k, v in props do
		base[k] = v
	end
	return scope:New("TextLabel")(base)
end

local function classText(use: Use, key: string?): string
	if type(key) == "string" and string.sub(key, 1, 1) == "@" then
		return Text.get(use, string.sub(key, 2))
	end
	return ""
end

local function topRow(use: Use, row: Leaderboard.Row): string
	local name = if row.n ~= "" then row.n else Text.get(use, "leaderboard.unknown")
	local level = if row.p
		then Text.get(use, "leaderboard.levelPct", { level = row.l or 1, pct = row.p })
		else tostring(row.l or "")
	return `{row.r}. {name}  ·  {classText(use, row.c)}  ·  {level}`
end

-- The writing of one face of the board.
local function boardFace(scope: Scope, panels: Fusion.Value<any>, mode: Fusion.Value<any>): { any }
	local body = scope:Computed(function(use, s: Scope): { any }
		local data: { Leaderboard.Panel }? = use(panels)
		local out: { any } = {}
		if not data then
			table.insert(
				out,
				label(s, {
					Position = UDim2.fromScale(0.03, 0.4),
					Size = UDim2.new(0.94, 0, 0, 30),
					Text = Text.get(use, "leaderboard.loading"),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = Theme.Paper.TextMuted,
					TextSize = 20,
				})
			)
			return out
		end
		for _, panel in data do
			if panel.kind == "top" then
				local column = panel.columns[1]
				local rows = if column then column.rows else {}
				table.insert(
					out,
					label(s, {
						Position = UDim2.new(0.02, 0, 0, 44),
						Size = UDim2.new(0.38, 0, 0, 22),
						Text = Text.get(use, panel.titleKey),
						FontFace = Theme.Fonts.Display,
						TextColor3 = Theme.Paper.Heading,
						TextSize = 18,
					})
				)
				for i = 1, math.max(#rows, 1) do
					local row = rows[i]
					table.insert(
						out,
						label(s, {
							Position = UDim2.new(0.02, 0, 0, 68 + (i - 1) * 19),
							Size = UDim2.new(0.38, 0, 0, 18),
							Text = if row then topRow(use, row) else Text.get(use, "leaderboard.empty"),
							TextColor3 = if row then INK else Theme.Paper.TextMuted,
							TextSize = 14,
						})
					)
				end
			else
				local n = #panel.columns
				table.insert(
					out,
					label(s, {
						Position = UDim2.new(0.42, 0, 0, 44),
						Size = UDim2.new(0.56, 0, 0, 22),
						Text = Text.get(use, panel.titleKey),
						FontFace = Theme.Fonts.Display,
						TextColor3 = Theme.Paper.Heading,
						TextSize = 18,
					})
				)
				for c, column in panel.columns do
					local x = 0.42 + (c - 1) * 0.56 / math.max(n, 1)
					local width = 0.56 / math.max(n, 1) - 0.01
					table.insert(
						out,
						label(s, {
							Position = UDim2.new(x, 0, 0, 68),
							Size = UDim2.new(width, 0, 0, 18),
							Text = if column.titleKey then Text.get(use, column.titleKey) else "",
							FontFace = Theme.Fonts.BodyBold,
							TextSize = 14,
						})
					)
					for i = 1, Leaderboards.HOF_SIZE do
						local row = column.rows[i]
						table.insert(
							out,
							label(s, {
								Position = UDim2.new(x, 0, 0, 88 + (i - 1) * 18),
								Size = UDim2.new(width, 0, 0, 17),
								Text = if row then `{i}. {row.n}` else Text.get(use, "leaderboard.hof.free"),
								TextColor3 = if row then INK else Theme.Paper.TextMuted,
								TextSize = 13,
							})
						)
					end
				end
			end
		end
		return out
	end)
	return {
		label(scope, {
			Position = UDim2.new(0.02, 0, 0, 6),
			Size = UDim2.new(0.96, 0, 0, 34),
			Text = Text.T(scope, "town.fame.title"),
			FontFace = Theme.Fonts.Display,
			TextColor3 = Theme.Paper.Heading,
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		label(scope, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(0.98, 0, 0, 10),
			Size = UDim2.new(0.3, 0, 0, 16),
			Text = Text.T(scope, "leaderboard.local"),
			TextColor3 = Theme.Paper.Warning,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			Visible = scope:Computed(function(use): boolean
				return use(mode) == "local"
			end),
		}),
		body :: any,
		label(scope, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0.02, 0, 1, -4),
			Size = UDim2.new(0.96, 0, 0, 16),
			Text = Text.T(scope, "town.fame.hint"),
			TextColor3 = Theme.Paper.TextMuted,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	}
end

local function writeBoard(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("FameText") then
		return
	end
	local scope = rootScope:innerScope()
	part.Destroying:Connect(function()
		Fusion.doCleanup(scope)
	end)
	local panels = scope:Value(decode(part:GetAttribute("Panels")))
	local mode = scope:Value(part:GetAttribute("Mode"))
	table.insert(
		scope,
		part:GetAttributeChangedSignal("Panels"):Connect(function()
			panels:set(decode(part:GetAttribute("Panels")))
		end)
	)
	table.insert(
		scope,
		part:GetAttributeChangedSignal("Mode"):Connect(function()
			mode:set(part:GetAttribute("Mode"))
		end)
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		scope:New("SurfaceGui")({
			Name = "FameText",
			Face = face,
			Adornee = part,
			Parent = part,
			LightInfluence = 0.4,
			PixelsPerStud = BOARD_PPS,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			MaxDistance = 90,
			[Children] = boardFace(scope, panels, mode),
		})
	end
	local prompt = scope:New("ProximityPrompt")({
		ActionText = Text.now("leaderboard.prompt"),
		ObjectText = Text.now("town.fame.title"),
		HoldDuration = 0,
		MaxActivationDistance = PROMPT_RANGE,
		RequiresLineOfSight = false,
		Parent = part,
	}) :: ProximityPrompt
	Keybinds.bindPrompt(prompt, "interact")
	table.insert(
		scope,
		prompt.Triggered:Connect(function()
			RankingsController.Open()
		end)
	)
	scope:Observer(Text.Lang):onChange(function()
		prompt.ActionText = Text.now("leaderboard.prompt")
		prompt.ObjectText = Text.now("town.fame.title")
	end)
end

local function writePlaque(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("FameText") then
		return
	end
	local index = part:GetAttribute("Plinth")
	local plinth = if type(index) == "number" then Leaderboards.TOWN.plinths[index] else nil
	local board = plinth and Leaderboards.get(plinth.board)
	-- caption from the plinth data; class from the plaque (the hero's), else the board's class
	local captionKey = if plinth then plinth.captionKey else "town.fame.plinth"
	local boardClassKey = if board and board.class then `class.{board.class}.name` else nil
	local scope = rootScope:innerScope()
	part.Destroying:Connect(function()
		Fusion.doCleanup(scope)
	end)
	local hero = scope:Value(part:GetAttribute("HeroName"))
	local at = scope:Value(part:GetAttribute("At"))
	local heroClass = scope:Value(part:GetAttribute("ClassKey"))
	table.insert(
		scope,
		part:GetAttributeChangedSignal("ClassKey"):Connect(function()
			heroClass:set(part:GetAttribute("ClassKey"))
		end)
	)
	table.insert(
		scope,
		part:GetAttributeChangedSignal("HeroName"):Connect(function()
			hero:set(part:GetAttribute("HeroName"))
		end)
	)
	table.insert(
		scope,
		part:GetAttributeChangedSignal("At"):Connect(function()
			at:set(part:GetAttribute("At"))
		end)
	)
	local function row(order: number, text: any, size: number, color: any, font: Font?): Instance
		return scope:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, if order == 2 then 0.4 else 0.3),
			BackgroundTransparency = 1,
			Text = text,
			TextScaled = true,
			FontFace = font or Theme.Fonts.Body,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Center,
			[Children] = scope:New("UITextSizeConstraint")({ MaxTextSize = size }),
		})
	end
	scope:New("SurfaceGui")({
		Name = "FameText",
		Face = Enum.NormalId.Front,
		Adornee = part,
		Parent = part,
		LightInfluence = 0.4,
		PixelsPerStud = PLAQUE_PPS,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		MaxDistance = 40,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
			row(
				1,
				scope:Computed(function(use): string
					local key = use(heroClass)
					local classKey = if type(key) == "string" and string.sub(key, 1, 1) == "@"
						then string.sub(key, 2)
						else boardClassKey
					local class = if classKey then Text.get(use, classKey) else ""
					return Text.get(use, captionKey, { class = class })
				end),
				16,
				INK
			),
			row(
				2,
				scope:Computed(function(use): string
					local name = use(hero)
					return if type(name) == "string" and name ~= ""
						then name
						else Text.get(use, "town.fame.plinthEmpty")
				end),
				24,
				scope:Computed(function(use): Color3
					local name = use(hero)
					return if type(name) == "string" and name ~= "" then Theme.Paper.Heading else INK
				end),
				Theme.Fonts.Display
			),
			row(
				3,
				scope:Computed(function(use): string
					local t = use(at)
					return if type(t) == "number"
						then Text.get(use, "leaderboard.date", Leaderboard.dateParts(t))
						else ""
				end),
				14,
				INK
			),
		},
	})
end

function FameBoardController.Init(registry)
	RankingsController = registry.Get("RankingsController")
end

function FameBoardController.Start()
	for _, part in CollectionService:GetTagged("FameBoard") do
		task.spawn(writeBoard, part)
	end
	CollectionService:GetInstanceAddedSignal("FameBoard"):Connect(function(part)
		task.defer(writeBoard, part)
	end)
	for _, part in CollectionService:GetTagged("FamePlinth") do
		task.spawn(writePlaque, part)
	end
	CollectionService:GetInstanceAddedSignal("FamePlinth"):Connect(function(part)
		task.defer(writePlaque, part)
	end)
end

return FameBoardController
