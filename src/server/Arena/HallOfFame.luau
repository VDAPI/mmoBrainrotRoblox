--!strict
-- The arena Hall of Fame (S128, DESIGN-17 §6): the top Config.Arena.hofSize of every arena board (1v1 and 3v3, each
-- bracket) of a finished season, written once per season into the DataStore Config.Arena.hofStore under the season
-- key. The first server that builds it wins (UpdateAsync writes only when the key is missing); the others read the
-- same record. Without DataStore access (Studio, Lune) the store is in memory (Market/KeyStore). The city board
-- (ArenaService -> the part tagged "ArenaFameBoard") shows the record of the season before the current one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Config = require(ReplicatedStorage.Shared.Config)
local KeyStore = require(script.Parent.Parent.Market.KeyStore)

export type Row = { name: string, class: string?, guild: string?, rating: number }
export type Record = {
	season: string,
	at: number,
	boards: { [string]: { Row } }, -- board instance id ("arena_202611_40_59") -> the top rows
}
-- What a top read returns for one board instance id: the rows in order, nil when the read failed.
export type ReadTop = (boardId: string) -> { Row }?

local HallOfFame = {}

local store: KeyStore.KeyStore? = nil

-- ArenaService.Init hands in the DataStore access check (DataService.HasDataStoreAccess).
function HallOfFame.init(hasAccess: () -> boolean)
	store = KeyStore.new(Config.Arena.hofStore, hasAccess)
end

local function need(): KeyStore.KeyStore
	local s = store
	if not s then
		error("Arena/HallOfFame: init first")
	end
	return s
end

-- Every board instance of a season (both modes, every bracket).
function HallOfFame.boardsOf(season: string): { string }
	local out = {}
	for _, id in Arena.MODE_ORDER do
		local mode = Arena.MODES[id]
		for _, b in Arena.BRACKETS do
			table.insert(out, ArenaRules.boardId(mode, season, b.id))
		end
	end
	return out
end

-- (ok, record?): ok = false only when the store failed.
function HallOfFame.get(season: string): (boolean, Record?)
	local ok, value = need():get(season)
	if not ok then
		return false, nil
	end
	return true, if type(value) == "table" and type(value.boards) == "table" then value else nil
end

-- Builds the record of `season` from the top reads (yields). An existing record is never overwritten: the result is
-- the stored one. (ok, record?, count of rows).
function HallOfFame.build(season: string, readTop: ReadTop, now: number): (boolean, Record?, number)
	local boards: { [string]: { Row } } = {}
	local n = 0
	for _, id in HallOfFame.boardsOf(season) do
		local rows = readTop(id)
		if rows == nil then
			return false, nil, 0 -- a read failed: try again at the next check
		end
		local top = {}
		for i = 1, math.min(#rows, Config.Arena.hofSize) do
			table.insert(top, rows[i])
		end
		boards[id] = top
		n += #top
	end
	if n == 0 then
		-- nobody played that season (the first arena season has no season before it): no record, the board says so
		return true, nil, 0
	end
	local record: Record = { season = season, at = now, boards = boards }
	local ok, stored, err = need():update(season, function(current: any?): (any?, string?)
		if type(current) == "table" and type(current.boards) == "table" then
			return nil, "exists"
		end
		return record, nil
	end)
	if not ok and err ~= "exists" then
		return false, nil, 0
	end
	if not ok or stored == nil then
		-- somebody else wrote it first: read theirs
		local okGet, existing = HallOfFame.get(season)
		if not okGet or not existing then
			return false, nil, 0
		end
		local count = 0
		for _, rows in existing.boards do
			count += #rows
		end
		return true, existing, count
	end
	return true, stored, n
end

return HallOfFame
