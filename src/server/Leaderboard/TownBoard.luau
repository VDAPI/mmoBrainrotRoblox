--!strict
-- The Hall of Fame board in the city (S124, DESIGN-17 §5), server side: the part tagged "FameBoard" (World/Layouts/city)
-- gets the panels of Data/Leaderboards.TOWN as JSON in the attribute `Panels` (Logic/Leaderboard.townPanels) and
-- `Mode` ("global" | "local"); every plaque tagged "FamePlinth" (attribute `Plinth` = i) gets `HeroName`, `ClassKey`
-- ("@class.<Id>.name") and `At` of entry `index` of its list, or none of them (an empty plinth). Updated when one of
-- these boards was read or changed, and once per Config.Leaderboard.refresh. The client writes the text
-- (FameBoardController). Nothing here yields.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Leaderboards = require(Shared.Data.Leaderboards)
local Log = require(Shared.Util.Log)

local log = Log.new("TownBoard")

local TownBoard = {}

type Read = (boardId: string) -> Leaderboard.Snapshot?
type ListOf = (boardId: string) -> { Leaderboard.ListEntry }?

local warned = false

local function update(read: Read, listOf: ListOf)
	local boards = CollectionService:GetTagged("FameBoard")
	local plaques = CollectionService:GetTagged("FamePlinth")
	if #boards == 0 and #plaques == 0 then
		if not warned then
			warned = true
			log:warn("no FameBoard / FamePlinth parts in the world: the Hall of Fame shows nothing")
		end
		return
	end
	local panels = Leaderboard.townPanels(Leaderboards.TOWN.panels, read)
	local ok, json = pcall(HttpService.JSONEncode, HttpService, panels)
	local mode = "global"
	for _, panel in Leaderboards.TOWN.panels do
		for _, id in panel.boards do
			local snap = read(id)
			if snap and snap.mode == "local" then
				mode = "local"
			end
		end
	end
	for _, board in boards do
		if ok then
			board:SetAttribute("Panels", json)
		end
		board:SetAttribute("Mode", mode)
	end
	for _, plaque in plaques do
		local index = plaque:GetAttribute("Plinth")
		local plinth = if type(index) == "number" then Leaderboards.TOWN.plinths[index] else nil
		local list = plinth and listOf(plinth.board)
		local entry = if plinth and list then list[plinth.index] else nil
		if entry then
			plaque:SetAttribute("HeroName", entry.n)
			plaque:SetAttribute("ClassKey", Leaderboard.classKey(entry.c))
			plaque:SetAttribute("At", entry.at)
		else
			plaque:SetAttribute("HeroName", nil)
			plaque:SetAttribute("ClassKey", nil)
			plaque:SetAttribute("At", nil)
		end
	end
end

-- Starts the updates: `read` gives a snapshot without waiting, `listOf` a cached list, `refreshed` fires
-- (instanceId) after a board read or change.
function TownBoard.start(read: Read, listOf: ListOf, refreshed: any)
	local watched: { [string]: boolean } = {}
	for _, panel in Leaderboards.TOWN.panels do
		for _, id in panel.boards do
			watched[id] = true
		end
	end
	for _, plinth in Leaderboards.TOWN.plinths do
		watched[plinth.board] = true
	end
	local scheduled = false
	local function schedule()
		if scheduled then
			return
		end
		scheduled = true
		task.delay(0.5, function()
			scheduled = false
			update(read, listOf)
		end)
	end
	refreshed:Connect(function(instanceId: string)
		if watched[instanceId] then
			schedule()
		end
	end)
	task.spawn(function()
		while true do
			schedule()
			task.wait(Config.Leaderboard.refresh)
		end
	end)
end

return TownBoard
