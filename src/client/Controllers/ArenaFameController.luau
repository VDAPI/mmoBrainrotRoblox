--!strict
-- The arena Hall of Fame by the Ristalle (S128, DESIGN-17 §6), client side (wzór FameBoardController): the part tagged
-- "ArenaFameBoard" gets the writing from its attributes `Record` (JSON of the server's Arena/HallOfFame record of the
-- season before: board instance id -> the top rows) and `Mode`: the front face the 1 vs 1 boards, the back face the
-- 3 vs 3 boards (DECYZJE S128), four columns of the arena brackets with the top 10 each; without a record "The first
-- arena season is still under way" (arena.hof.empty). Each plaque tagged "ArenaFamePlinth" (`Plinth` = the bracket
-- index) shows the 1 vs 1 winner of its bracket (`HeroName`, `ClassKey`) or "—". A prompt opens the arena window.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use

local ArenaFameController = {
	Name = "ArenaFameController",
	Deps = { "ArenaController" },
}

local ArenaController: any

local rootScope = Fusion.scoped(Fusion)

local INK = Color3.fromHex("#F2E6C9")
local BOARD_PPS = 50
local PLAQUE_PPS = 60
local PROMPT_RANGE = 12
local ROWS = 10

local function decode(json: any): any?
	if type(json) ~= "string" then
		return nil
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and type(value) == "table" and type(value.boards) == "table" then value else nil
end

local function label(scope: Scope, props: { [string]: any }): Instance
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 14,
	}
	for k, v in props do
		base[k] = v
	end
	return scope:New("TextLabel")(base)
end

local function seasonText(use: Use, season: string): string
	local month, year = ArenaRules.seasonLabel(season)
	return Text.get(use, "arena.season.short", { month = month, year = year })
end

-- One face: the boards of one mode.
local function face(scope: Scope, record: Fusion.Value<any>, mode: Fusion.Value<any>, modeId: string): { any }
	local body = scope:Computed(function(use, s: Scope): { any }
		local r = use(record)
		local out: { any } = {}
		if not r then
			table.insert(
				out,
				label(s, {
					Position = UDim2.fromScale(0.03, 0.42),
					Size = UDim2.new(0.94, 0, 0, 30),
					Text = Text.get(use, "arena.hof.empty"),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = Theme.Colors.TextMuted,
					TextSize = 20,
				})
			)
			return out
		end
		local m = Arena.MODES[modeId]
		local width = 1 / #Arena.BRACKETS
		for i, b in Arena.BRACKETS do
			local x = (i - 1) * width + 0.01
			table.insert(
				out,
				label(s, {
					Position = UDim2.new(x, 0, 0, 46),
					Size = UDim2.new(width - 0.02, 0, 0, 18),
					Text = Text.get(use, "arena.hof.bracket", { min = b.min, max = b.max }),
					FontFace = Theme.Fonts.Heading,
					TextColor3 = Theme.Colors.GoldBright,
					TextSize = 15,
				})
			)
			local rows = r.boards[ArenaRules.boardId(m, r.season, b.id)] or {}
			for n = 1, math.max(1, math.min(#rows, ROWS)) do
				local row = rows[n]
				table.insert(
					out,
					label(s, {
						Position = UDim2.new(x, 0, 0, 68 + (n - 1) * 19),
						Size = UDim2.new(width - 0.02, 0, 0, 18),
						Text = if row then `{n}. {row.name}  ·  {row.rating}` else Text.get(use, "arena.hof.free"),
						TextColor3 = if row then INK else Theme.Colors.TextMuted,
						TextSize = 13,
					})
				)
			end
		end
		return out
	end)
	return {
		label(scope, {
			Position = UDim2.new(0.02, 0, 0, 8),
			Size = UDim2.new(0.66, 0, 0, 32),
			Text = scope:Computed(function(use): string
				local r = use(record)
				local title = if r
					then Text.get(use, "arena.hof.title", { season = seasonText(use, r.season) })
					else Text.get(use, "arena.hof.title", { season = "—" })
				return `{title} · {Text.get(use, `arena.mode.{modeId}`)}`
			end),
			FontFace = Theme.Fonts.Heading,
			TextColor3 = Theme.Colors.GoldBright,
			TextSize = 22,
		}),
		label(scope, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(0.98, 0, 0, 12),
			Size = UDim2.new(0.3, 0, 0, 16),
			Text = Text.T(scope, "arena.hof.local"),
			TextColor3 = Theme.Colors.Warning,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			Visible = scope:Computed(function(use): boolean
				return use(mode) == "local"
			end),
		}),
		body :: any,
	}
end

local function writeBoard(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("ArenaFameText") then
		return
	end
	local scope = rootScope:innerScope()
	part.Destroying:Connect(function()
		Fusion.doCleanup(scope)
	end)
	local record = scope:Value(decode(part:GetAttribute("Record")))
	local mode = scope:Value(part:GetAttribute("Mode"))
	table.insert(
		scope,
		part:GetAttributeChangedSignal("Record"):Connect(function()
			record:set(decode(part:GetAttribute("Record")))
		end)
	)
	table.insert(
		scope,
		part:GetAttributeChangedSignal("Mode"):Connect(function()
			mode:set(part:GetAttribute("Mode"))
		end)
	)
	for faceId, modeId in { [Enum.NormalId.Front] = "1v1", [Enum.NormalId.Back] = "3v3" } do
		scope:New("SurfaceGui")({
			Name = "ArenaFameText",
			Face = faceId,
			Adornee = part,
			Parent = part,
			LightInfluence = 0.4,
			PixelsPerStud = BOARD_PPS,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			MaxDistance = 90,
			[Children] = face(scope, record, mode, modeId),
		})
	end
	local prompt = scope:New("ProximityPrompt")({
		ActionText = Text.now("npc.service.arena"),
		ObjectText = Text.now("arena.hof.title", { season = "" }),
		HoldDuration = 0,
		MaxActivationDistance = PROMPT_RANGE,
		RequiresLineOfSight = false,
		Parent = part,
	}) :: ProximityPrompt
	Keybinds.bindPrompt(prompt, "interact")
	table.insert(
		scope,
		prompt.Triggered:Connect(function()
			ArenaController.Open()
		end)
	)
	scope:Observer(Text.Lang):onChange(function()
		prompt.ActionText = Text.now("npc.service.arena")
	end)
end

local function writePlaque(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("ArenaFameText") then
		return
	end
	local index = part:GetAttribute("Plinth")
	local bracket = if type(index) == "number" then Arena.BRACKETS[index] else nil
	local scope = rootScope:innerScope()
	part.Destroying:Connect(function()
		Fusion.doCleanup(scope)
	end)
	local hero = scope:Value(part:GetAttribute("HeroName"))
	table.insert(
		scope,
		part:GetAttributeChangedSignal("HeroName"):Connect(function()
			hero:set(part:GetAttribute("HeroName"))
		end)
	)
	local function row(order: number, text: any, size: number, color: any, font: Font?): Instance
		return scope:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, if order == 2 then 0.5 else 0.35),
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
		Name = "ArenaFameText",
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
					return Text.get(
						use,
						"arena.hof.plinth",
						{ bracket = if bracket then `{bracket.min}–{bracket.max}` else "" }
					)
				end),
				16,
				INK
			),
			row(
				2,
				scope:Computed(function(use): string
					local name = use(hero)
					return if type(name) == "string" and name ~= "" then name else Text.get(use, "arena.hof.free")
				end),
				24,
				scope:Computed(function(use): Color3
					local name = use(hero)
					return if type(name) == "string" and name ~= "" then Theme.Colors.GoldBright else INK
				end),
				Theme.Fonts.Heading
			),
		},
	})
end

function ArenaFameController.Init(registry)
	ArenaController = registry.Get("ArenaController")
end

function ArenaFameController.Start()
	for _, part in CollectionService:GetTagged("ArenaFameBoard") do
		task.spawn(writeBoard, part)
	end
	CollectionService:GetInstanceAddedSignal("ArenaFameBoard"):Connect(function(part)
		task.defer(writeBoard, part)
	end)
	for _, part in CollectionService:GetTagged("ArenaFamePlinth") do
		task.spawn(writePlaque, part)
	end
	CollectionService:GetInstanceAddedSignal("ArenaFamePlinth"):Connect(function(part)
		task.defer(writePlaque, part)
	end)
end

return ArenaFameController
