--!strict
-- The Champions of Vaelthorn by the Ristalle (S130, DESIGN-17 §8), client side (the pattern of ArenaFameController):
-- the part tagged "TourneyFameBoard" gets the writing from its attributes `Hall` (JSON of Tourney/Hall: bracket ->
-- the last champions, newest first) and `Mode`: four columns of the arena brackets with up to
-- Data/Arena.TOURNEY.hallWeeks champions each (the tournament's date, the name, the class), the newest in gold; without
-- any "No one has won this title yet". Each plaque tagged "TourneyFamePlinth" (`Plinth` = the bracket index) under the
-- stone statue names the newest champion of its bracket (`HeroName`, `ClassKey`, `TourneyId`) or says it is free. A
-- prompt opens the tournament tab of the arena window.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type Use = Fusion.Use

local TourneyFameController = {
	Name = "TourneyFameController",
	Deps = { "ArenaController" },
}

local ArenaController: any

local rootScope = Fusion.scoped(Fusion)

local INK = Color3.fromHex("#F2E6C9")
local BOARD_PPS = 50
local PLAQUE_PPS = 60
local PROMPT_RANGE = 12

local function decode(json: any): any?
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
		TextSize = 14,
	}
	for k, v in props do
		base[k] = v
	end
	return scope:New("TextLabel")(base)
end

-- "DD.MM.YYYY" of a tournament id ("YYYYMMDD", a forced one "YYYYMMDDfHHMM").
local function dateOf(use: Use, id: any): string
	local y, m, d = string.match(tostring(id), "^(%d%d%d%d)(%d%d)(%d%d)")
	if not y then
		return ""
	end
	return Text.get(use, "leaderboard.date", { d = d, m = m, y = y })
end

local function face(scope: Scope, hall: Fusion.Value<any>, mode: Fusion.Value<any>): { any }
	local body = scope:Computed(function(use, s: Scope): { any }
		local h = use(hall)
		local out: { any } = {}
		local any = false
		if type(h) == "table" then
			for _, list in h do
				if type(list) == "table" and #list > 0 then
					any = true
				end
			end
		end
		if not any then
			table.insert(
				out,
				label(s, {
					Position = UDim2.fromScale(0.03, 0.42),
					Size = UDim2.new(0.94, 0, 0, 30),
					Text = Text.get(use, "tourney.hall.empty"),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = Theme.Paper.TextMuted,
					TextSize = 20,
				})
			)
			return out
		end
		local width = 1 / #Arena.BRACKETS
		for i, b in Arena.BRACKETS do
			local x = (i - 1) * width + 0.01
			table.insert(
				out,
				label(s, {
					Position = UDim2.new(x, 0, 0, 46),
					Size = UDim2.new(width - 0.02, 0, 0, 18),
					Text = `{b.min}–{b.max}`,
					FontFace = Theme.Fonts.Display,
					TextColor3 = Theme.Paper.Heading,
					TextSize = 15,
				})
			)
			local rows = if type(h) == "table" and type(h[b.id]) == "table" then h[b.id] else {}
			for n = 1, math.max(1, math.min(#rows, Arena.TOURNEY.hallWeeks)) do
				local row = rows[n]
				local text = if row
					then `{dateOf(use, row.id)}  {row.name} ({Text.get(use, `class.{row.class}.name`)})`
					else "—"
				table.insert(
					out,
					label(s, {
						Position = UDim2.new(x, 0, 0, 68 + (n - 1) * 38),
						Size = UDim2.new(width - 0.02, 0, 0, 34),
						Text = text,
						TextWrapped = true,
						TextTruncate = Enum.TextTruncate.None,
						TextColor3 = if row and n == 1 then Theme.Paper.Heading else INK,
						FontFace = if row and n == 1 then Theme.Fonts.BodyBold else Theme.Fonts.Body,
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
			Text = Text.T(scope, "tourney.hall"),
			FontFace = Theme.Fonts.Display,
			TextColor3 = Theme.Paper.Heading,
			TextSize = 22,
		}),
		label(scope, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(0.98, 0, 0, 12),
			Size = UDim2.new(0.3, 0, 0, 16),
			Text = Text.T(scope, "tourney.hall.local"),
			TextColor3 = Theme.Paper.Warning,
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
	if not part:IsA("BasePart") or part:FindFirstChild("TourneyFameText") then
		return
	end
	local scope = rootScope:innerScope()
	part.Destroying:Connect(function()
		Fusion.doCleanup(scope)
	end)
	local hall = scope:Value(decode(part:GetAttribute("Hall")))
	local mode = scope:Value(part:GetAttribute("Mode"))
	table.insert(
		scope,
		part:GetAttributeChangedSignal("Hall"):Connect(function()
			hall:set(decode(part:GetAttribute("Hall")))
		end)
	)
	table.insert(
		scope,
		part:GetAttributeChangedSignal("Mode"):Connect(function()
			mode:set(part:GetAttribute("Mode"))
		end)
	)
	for _, faceId in { Enum.NormalId.Front, Enum.NormalId.Back } do
		scope:New("SurfaceGui")({
			Name = "TourneyFameText",
			Face = faceId,
			Adornee = part,
			Parent = part,
			LightInfluence = 0.4,
			PixelsPerStud = BOARD_PPS,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			MaxDistance = 90,
			[Children] = face(scope, hall, mode),
		})
	end
	local prompt = scope:New("ProximityPrompt")({
		ActionText = Text.now("tourney.title"),
		ObjectText = Text.now("tourney.hall"),
		HoldDuration = 0,
		MaxActivationDistance = PROMPT_RANGE,
		RequiresLineOfSight = false,
		Parent = part,
	}) :: ProximityPrompt
	Keybinds.bindPrompt(prompt, "interact")
	table.insert(
		scope,
		prompt.Triggered:Connect(function()
			ArenaController.OpenTourney()
		end)
	)
	scope:Observer(Text.Lang):onChange(function()
		prompt.ActionText = Text.now("tourney.title")
		prompt.ObjectText = Text.now("tourney.hall")
	end)
end

local function writePlaque(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("TourneyFameText") then
		return
	end
	local index = part:GetAttribute("Plinth")
	local bracket = if type(index) == "number" then Arena.BRACKETS[index] else nil
	local scope = rootScope:innerScope()
	part.Destroying:Connect(function()
		Fusion.doCleanup(scope)
	end)
	local hero = scope:Value(part:GetAttribute("HeroName"))
	local id = scope:Value(part:GetAttribute("TourneyId"))
	table.insert(
		scope,
		part:GetAttributeChangedSignal("HeroName"):Connect(function()
			hero:set(part:GetAttribute("HeroName"))
		end)
	)
	table.insert(
		scope,
		part:GetAttributeChangedSignal("TourneyId"):Connect(function()
			id:set(part:GetAttribute("TourneyId"))
		end)
	)
	local range = if bracket then `{bracket.min}–{bracket.max}` else ""
	scope:New("SurfaceGui")({
		Name = "TourneyFameText",
		Face = Enum.NormalId.Front,
		Adornee = part,
		Parent = part,
		LightInfluence = 0.4,
		PixelsPerStud = PLAQUE_PPS,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		MaxDistance = 40,
		[Children] = {
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextScaled = true,
				TextWrapped = true,
				FontFace = Theme.Fonts.Display,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = scope:Computed(function(use): string
					local name = use(hero)
					if type(name) ~= "string" or name == "" then
						return `{range}\n{Text.get(use, "tourney.hall.empty")}`
					end
					return Text.get(
						use,
						"tourney.hall.plaque",
						{ name = name, range = range, date = dateOf(use, use(id)) }
					)
				end),
				TextColor3 = scope:Computed(function(use): Color3
					local name = use(hero)
					return if type(name) == "string" and name ~= "" then Theme.Paper.Heading else INK
				end),
				[Children] = scope:New("UITextSizeConstraint")({ MaxTextSize = 20 }),
			}),
		},
	})
end

function TourneyFameController.Init(registry)
	ArenaController = registry.Get("ArenaController")
end

function TourneyFameController.Start()
	for _, part in CollectionService:GetTagged("TourneyFameBoard") do
		task.spawn(writeBoard, part)
	end
	CollectionService:GetInstanceAddedSignal("TourneyFameBoard"):Connect(function(part)
		task.defer(writeBoard, part)
	end)
	for _, part in CollectionService:GetTagged("TourneyFamePlinth") do
		task.spawn(writePlaque, part)
	end
	CollectionService:GetInstanceAddedSignal("TourneyFamePlinth"):Connect(function(part)
		task.defer(writePlaque, part)
	end)
end

return TourneyFameController
