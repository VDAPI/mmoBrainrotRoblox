--!strict
-- Shared state of the skills window (S59): narrow character branches (never the whole character, HP changes several
-- times a second), the views built from them and the window's own values (tab, selection, phone sheet, picker).
-- S137 (DESIGN-18 §12): the bought ranks per pool and the rank reservation of the shown pool ("+" / "-" before
-- "Confirm", like CharacterWindow/StatAllocator).
-- S139 (the window 2.0): tabs are "pool:<poolId>" (one per weapon pool of the class, the equipped one first) and
-- "directions" (the class's directions, one shown at a time); the pool tree comes from Logic/PathView.poolView with the
-- reservation, the planned character from PathView.planned. A pool tab may be any pool of the class: ranks are
-- reserved and confirmed the same way, they work once its weapon is worn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillPoints = require(ReplicatedStorage.Shared.Logic.SkillPoints)
local SkillPools = require(ReplicatedStorage.Shared.Logic.SkillPools)
local SkillsAttention = require(script.Parent.Parent.Parent.SkillsAttention)
local SkillsTab = require(script.Parent.Parent.Parent.SkillsTab)
local State = require(script.Parent.Parent.Parent.State)

type Scope = Fusion.Scope<typeof(Fusion)>

-- FIX 2026-10-14: "path" = the path's own description (a click on its name in the tree tab).
export type Selection = { kind: "skill" | "node" | "path", id: string }
export type BpError = { key: string, err: string } -- key = Skills.choiceKey of the refused breakpoint
-- S139: the skill waiting for a slot of a full bar, and whose bar (a pool of the class)
export type Picking = { skillId: string, poolId: string }
export type Props = {
	ShowModal: (spec: any) -> (),
	Preview: ((model: Model, skillId: string) -> ())?,
}

export type Ctx = {
	props: Props,
	classId: Fusion.Value<any>,
	level: Fusion.Value<any>,
	path: Fusion.Value<any>,
	hotbar: Fusion.Value<any>,
	equipment: Fusion.Value<any>,
	weapon: Fusion.Value<any>, -- derived.weapon (Mage element, S18)
	character: Fusion.Computed<Paths.Char?>,
	weapons: Fusion.Computed<Paths.WeaponTypes>,
	free: Fusion.Computed<number>, -- free talent points (directions)
	attention: Fusion.Computed<PathView.Attention?>,
	paths: Fusion.Computed<{ PathData.PathDef }>,
	tab: Fusion.Value<string>, -- S139: "pool:<poolId>" or "directions"
	activeTab: Fusion.Computed<string>, -- the tab shown (a valid pool tab of the class, else the active pool's)
	onPools: Fusion.Computed<boolean>, -- a pool tab is shown
	direction: Fusion.Value<string?>, -- S139: the direction picked in the directions tab
	shownDirection: Fusion.Computed<string?>, -- the direction shown (picked, else the leading one, else the first)
	selected: Fusion.Value<Selection?>,
	sheet: Fusion.Value<boolean>, -- phone: the details sheet is open
	previewOpen: Fusion.Value<boolean>, -- the details show the 3D preview (PC panel, phone sheet)
	fullOpen: Fusion.Value<boolean>, -- S139: "Full description" unfolded
	picking: Fusion.Value<Picking?>,
	bpError: Fusion.Value<BpError?>,
	-- S137
	ranks: Fusion.Value<any>,
	barPool: Fusion.Value<any>,
	respecFree: Fusion.Value<any>,
	activePool: Fusion.Computed<string?>, -- the pool of the equipped weapon
	pool: Fusion.Computed<string?>, -- the pool of the shown pool tab (the active pool on the directions tab)
	reserve: Fusion.Value<{ [string]: number }>, -- ranks reserved in `pool`, not sent yet
	planned: Fusion.Computed<Paths.Char?>, -- the character with the reservation bought (SkillPoints rules on it)
	skillFree: Fusion.Computed<number>, -- free skill points of `pool` after the reservation
	poolView: Fusion.Computed<PathView.PoolView?>, -- S139: the tree of `pool`
	inventory: Fusion.Value<any>, -- S138: the backpack (the Scroll of Skill Renewal enables "Reset")
}

local Context = {}

Context.DIRECTIONS = "directions"

-- "pool:fire" -> "fire" (nil for another tab).
function Context.poolOfTab(tab: string): string?
	return string.match(tab, "^pool:(.+)$")
end

function Context.poolTab(poolId: string): string
	return `pool:{poolId}`
end

-- A tab another window asked for (SkillsTab): "directions", a direction id (the directions tab on it) or a pool tab.
local function wantedTab(wanted: string?, direction: Fusion.Value<string?>?): string?
	if wanted == nil then
		return nil
	end
	if wanted == Context.DIRECTIONS or Context.poolOfTab(wanted) then
		return wanted
	end
	if PathData.get(wanted) then
		if direction then
			direction:set(wanted)
		end
		return Context.DIRECTIONS
	end
	return nil
end

function Context.new(scope: Scope, props: Props): Ctx
	local classId = State.Value({ "character", "class" })
	local level = State.Value({ "character", "level" })
	local path = State.Value({ "character", "path" })
	local hotbar = State.Value({ "character", "hotbar" })
	local equipment = State.Value({ "character", "equipment" })
	local ranks = State.Value({ "character", "ranks" })
	local bars = State.Value({ "character", "bars" })
	local barPool = State.Value({ "character", "barPool" })
	local respecFree = State.Value({ "character", "respecFree" })

	local character = scope:Computed(function(use): Paths.Char?
		local class = use(classId)
		if type(class) ~= "string" or class == "" then
			return nil
		end
		local lvl = use(level)
		return {
			class = class,
			level = if type(lvl) == "number" then lvl else 1,
			path = use(path),
			hotbar = use(hotbar),
			equipment = use(equipment),
			ranks = use(ranks),
			bars = use(bars),
			barPool = use(barPool),
			respecFree = use(respecFree),
		} :: any
	end)
	local activePool = scope:Computed(function(use): string?
		local c = use(character)
		return if c then SkillPools.activePool(c) else nil
	end)
	local direction = scope:Value(nil :: string?)
	local tab = scope:Value(wantedTab(SkillsTab.take(), direction) or "")
	local activeTab = scope:Computed(function(use): string
		local wanted = use(tab)
		local c = use(character)
		if wanted == Context.DIRECTIONS then
			return wanted
		end
		local poolId = Context.poolOfTab(wanted)
		if c and poolId and SkillPools.valid(c.class, poolId) then
			return wanted
		end
		local active = use(activePool)
		return if active then Context.poolTab(active) else Context.DIRECTIONS
	end)
	local pool = scope:Computed(function(use): string?
		local poolId = Context.poolOfTab(use(activeTab))
		return poolId or use(activePool)
	end)
	local reserve = scope:Value({} :: { [string]: number })
	local planned = scope:Computed(function(use): Paths.Char?
		local c = use(character)
		local p = use(pool)
		if not c or not p then
			return c
		end
		return PathView.planned(c, p, use(reserve))
	end)
	local paths = scope:Computed(function(use): { PathData.PathDef }
		local class = use(classId)
		return if type(class) == "string" then Paths.pathsOf(class) else {}
	end)
	local selected = scope:Value(nil :: Selection?)
	local sheet = scope:Value(false)
	local fullOpen = scope:Value(false)

	local ctx: Ctx = {
		props = props,
		classId = classId,
		level = level,
		path = path,
		hotbar = hotbar,
		equipment = equipment,
		weapon = State.Value({ "derived", "weapon" }),
		character = character,
		weapons = scope:Computed(function(use): Paths.WeaponTypes
			return Paths.weaponTypesOf(use(equipment))
		end),
		free = scope:Computed(function(use): number
			local c = use(character)
			return if c then math.max(0, Paths.free(c)) else 0
		end),
		attention = SkillsAttention.attention(scope),
		paths = paths,
		tab = tab,
		activeTab = activeTab,
		onPools = scope:Computed(function(use): boolean
			return Context.poolOfTab(use(activeTab)) ~= nil
		end),
		direction = direction,
		shownDirection = scope:Computed(function(use): string?
			local list = use(paths)
			local wanted = use(direction)
			for _, def in list do
				if def.id == wanted then
					return wanted
				end
			end
			local c = use(character)
			local main = if c then Paths.mainOf(c) else nil
			if main then
				return main
			end
			return if list[1] then list[1].id else nil
		end),
		selected = selected,
		sheet = sheet,
		previewOpen = scope:Value(false),
		fullOpen = fullOpen,
		picking = scope:Value(nil :: Picking?),
		bpError = scope:Value(nil :: BpError?),
		ranks = ranks,
		barPool = barPool,
		respecFree = respecFree,
		inventory = State.Value({ "character", "inventory" }),
		activePool = activePool,
		pool = pool,
		reserve = reserve,
		planned = planned,
		skillFree = scope:Computed(function(use): number
			local c = use(planned)
			local p = use(pool)
			return if c and p then math.max(0, SkillPoints.free(c, p)) else 0
		end),
		poolView = scope:Computed(function(use): PathView.PoolView?
			local c = use(character)
			local p = use(pool)
			if not c or not p then
				return nil
			end
			return PathView.poolView(c, p, use(reserve))
		end),
	}
	-- a reservation belongs to one pool and one state of the ranks
	scope:Observer(pool):onChange(function()
		reserve:set({})
	end)
	scope:Observer(ranks):onChange(function()
		reserve:set({})
	end)
	-- the full description folds again for every new selection
	scope:Observer(selected):onChange(function()
		fullOpen:set(false)
	end)

	-- Another window may ask for a tab also while the window is open (S57 F3).
	scope:Observer(SkillsTab.Requested):onChange(function()
		local wanted = wantedTab(SkillsTab.take(), direction)
		if wanted then
			tab:set(wanted)
		end
	end)
	scope:Observer(classId):onChange(function()
		tab:set("")
		direction:set(nil)
		selected:set(nil)
		sheet:set(false)
	end)
	return ctx
end

return Context
