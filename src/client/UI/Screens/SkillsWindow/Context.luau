--!strict
-- Shared state of the skills window (S59): narrow character branches (never the whole character, HP changes several
-- times a second), the views built from them and the window's own values (tab, selection, phone sheet, picker).
-- S137 (DESIGN-18 §12, the minimal window before S139): the bought ranks per pool, the pool shown in the Base tab (the
-- active one unless a pool tab is picked), the rank reservation of that pool ("+" / "-" before "Confirm", like
-- CharacterWindow/StatAllocator) and the free skill points left after it.

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
	free: Fusion.Computed<number>,
	attention: Fusion.Computed<PathView.Attention?>,
	paths: Fusion.Computed<{ PathData.PathDef }>,
	tab: Fusion.Value<string>, -- "base", a path id or "soon"
	activeTab: Fusion.Computed<string>, -- the tab shown (tab while it still fits the class)
	selected: Fusion.Value<Selection?>,
	sheet: Fusion.Value<boolean>, -- phone: the details sheet is open
	previewOpen: Fusion.Value<boolean>, -- phone: the sheet shows the 3D preview
	picking: Fusion.Value<string?>, -- skill waiting for a slot of the full bar (2 x 4 picker)
	bpError: Fusion.Value<BpError?>,
	-- S137
	ranks: Fusion.Value<any>,
	barPool: Fusion.Value<any>,
	respecFree: Fusion.Value<any>,
	activePool: Fusion.Computed<string?>, -- the pool of the equipped weapon
	viewPool: Fusion.Value<string?>, -- a pool tab picked in the Base tab (nil = the active pool)
	pool: Fusion.Computed<string?>, -- the pool the Base tab shows
	reserve: Fusion.Value<{ [string]: number }>, -- ranks reserved in `pool`, not sent yet
	planned: Fusion.Computed<Paths.Char?>, -- the character with the reservation bought (SkillPoints rules on it)
	skillFree: Fusion.Computed<number>, -- free skill points of `pool` after the reservation
	inventory: Fusion.Value<any>, -- S138: the backpack (the Scroll of Skill Renewal enables "Reset")
}

local Context = {}

local function startTab(): string
	local wanted = SkillsTab.take()
	if wanted then
		return wanted
	end
	-- S138: the leading direction's tab (Paths.mainOf), else the Base list
	local classId = State.Get({ "character", "class" })
	if type(classId) ~= "string" then
		return "base"
	end
	local main = Paths.mainOf({ class = classId, level = 1, path = State.Get({ "character", "path" }) })
	return if main then main else "base"
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
	local viewPool = scope:Value(nil :: string?)
	local pool = scope:Computed(function(use): string?
		local c = use(character)
		local wanted = use(viewPool)
		if c and wanted and SkillPools.valid(c.class, wanted) then
			return wanted
		end
		return use(activePool)
	end)
	local reserve = scope:Value({} :: { [string]: number })
	local planned = scope:Computed(function(use): Paths.Char?
		local c = use(character)
		local p = use(pool)
		if not c or not p then
			return c
		end
		local all: any = c.ranks
		local copy: { [string]: { [string]: number } } = {}
		if type(all) == "table" then
			for id, own in all do
				if type(own) == "table" then
					copy[id] = table.clone(own)
				end
			end
		end
		local own = copy[p] or {}
		for id, n in use(reserve) do
			own[id] = SkillPoints.bought(c, p, id) + n
		end
		copy[p] = own
		local view = table.clone(c :: any)
		view.ranks = copy
		return view
	end)
	local tab = scope:Value(startTab())
	local selected = scope:Value(nil :: Selection?)
	local sheet = scope:Value(false)

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
		paths = scope:Computed(function(use): { PathData.PathDef }
			local class = use(classId)
			return if type(class) == "string" then Paths.pathsOf(class) else {}
		end),
		tab = tab,
		activeTab = scope:Computed(function(use): string
			local wanted = use(tab)
			local class = use(classId)
			local id = if type(class) == "string" then class else ""
			if wanted == "soon" then
				return if Paths.classHasPaths(id) then "base" else "soon"
			end
			local def = PathData.get(wanted)
			return if def and def.class == id then wanted else "base"
		end),
		selected = selected,
		sheet = sheet,
		previewOpen = scope:Value(false),
		picking = scope:Value(nil :: string?),
		bpError = scope:Value(nil :: BpError?),
		ranks = ranks,
		barPool = barPool,
		respecFree = respecFree,
		inventory = State.Value({ "character", "inventory" }),
		activePool = activePool,
		viewPool = viewPool,
		pool = pool,
		reserve = reserve,
		planned = planned,
		skillFree = scope:Computed(function(use): number
			local c = use(planned)
			local p = use(pool)
			return if c and p then math.max(0, SkillPoints.free(c, p)) else 0
		end),
	}
	-- a reservation belongs to one pool and one state of the ranks
	scope:Observer(pool):onChange(function()
		reserve:set({})
	end)
	scope:Observer(ranks):onChange(function()
		reserve:set({})
	end)

	-- Another window may ask for a tab also while the window is open (S57 F3).
	scope:Observer(SkillsTab.Requested):onChange(function()
		local wanted = SkillsTab.take()
		if wanted then
			tab:set(wanted)
		end
	end)
	scope:Observer(classId):onChange(function()
		tab:set("base")
		selected:set(nil)
		sheet:set(false)
		viewPool:set(nil)
	end)
	return ctx
end

return Context
