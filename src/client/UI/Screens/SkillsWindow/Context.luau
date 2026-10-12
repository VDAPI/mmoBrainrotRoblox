--!strict
-- Shared state of the skills window (S59): narrow character branches (never the whole character, HP changes several
-- times a second), the views built from them and the window's own values (tab, selection, phone sheet, picker).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillsAttention = require(script.Parent.Parent.Parent.SkillsAttention)
local SkillsTab = require(script.Parent.Parent.Parent.SkillsTab)
local State = require(script.Parent.Parent.Parent.State)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Selection = { kind: "skill" | "node", id: string }
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
	picking: Fusion.Value<string?>, -- skill waiting for a slot of the full bar (2 x 5 picker)
	bpError: Fusion.Value<BpError?>,
}

local Context = {}

local function startTab(): string
	local wanted = SkillsTab.take()
	if wanted then
		return wanted
	end
	local state = State.Get({ "character", "path" })
	local main = if type(state) == "table" then state.main else nil
	return if type(main) == "string" then main else "base"
end

function Context.new(scope: Scope, props: Props): Ctx
	local classId = State.Value({ "character", "class" })
	local level = State.Value({ "character", "level" })
	local path = State.Value({ "character", "path" })
	local hotbar = State.Value({ "character", "hotbar" })
	local equipment = State.Value({ "character", "equipment" })

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
		}
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
	}

	-- The Scroll of a New Path asks for a tab also while the window is open (S57 F3).
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
	end)
	return ctx
end

return Context
