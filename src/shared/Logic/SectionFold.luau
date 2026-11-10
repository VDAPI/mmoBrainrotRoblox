--!strict
-- Collapsible sections (owner 2026-11-10: "a lot of text, some things cover others, too detailed descriptions, nothing
-- can be collapsed"): which sections of the interface stand open (UI/Components/Section). One account setting
-- (`account.settings.sections`, SetSetting "sections") keeps section id -> open, only for the sections the player
-- clicked; the others follow their default. Every section the client shows has its id in Data/Folds, so the server
-- keeps only known ids. Pure (Lune): tests/sectionfold.spec.
-- UI plan 2026-11-10 (docs/UI-ZASADY.md §4): a default may differ per device, { pc = true, phone = false } (a HUD panel
-- open on PC, one line on a phone). `compact` is the phone layout (UI/PhoneLayout.Compact); nil or false reads the PC
-- default, tablets included. The player's choice is one per account and wins on every device.

local Folds = require("../Data/Folds")

export type Default = Folds.Default

local SectionFold = {}

-- A boolean, or { pc, phone } with two booleans and nothing else (a typo such as `phnoe` must not pass as a default).
local function wellFormed(default: any): boolean
	if type(default) == "boolean" then
		return true
	end
	if type(default) ~= "table" or type(default.pc) ~= "boolean" or type(default.phone) ~= "boolean" then
		return false
	end
	for key in default do
		if key ~= "pc" and key ~= "phone" then
			return false
		end
	end
	return true
end

-- One id -> default table from the areas of Data/Folds. An id in two areas raises an error (both windows would fold
-- together under the one saved choice), and so does a default that is not a boolean or { pc, phone }.
function SectionFold.merge(areas: { Folds.Area }): { [string]: Default }
	local out: { [string]: Default } = {}
	local areaOf: { [string]: string } = {}
	for _, area in areas do
		for id, default in area.folds do
			local first = areaOf[id]
			if first then
				error(`Data/Folds: section "{id}" is in both {first} and {area.name}`)
			end
			if not wellFormed(default) then
				error(`Data/Folds.{area.name}: section "{id}" needs true, false or pc and phone booleans`)
			end
			areaOf[id] = area.name
			-- a frozen copy: an area file freezes its outer table, not the { pc, phone } pairs in it
			out[id] = if type(default) == "table"
				then table.freeze({ pc = default.pc, phone = default.phone })
				else default
		end
	end
	return table.freeze(out)
end

-- Section id -> open by default (Data/Folds: Hud, Gear, World, Menu).
SectionFold.DEFAULTS = SectionFold.merge(Folds)

function SectionFold.known(id: string): boolean
	return SectionFold.DEFAULTS[id] ~= nil
end

-- Whether section `id` stands open by default on this device (`compact`: the phone layout); false for an unknown id.
function SectionFold.default(id: string, compact: boolean?): boolean
	local default = SectionFold.DEFAULTS[id]
	if type(default) == "table" then
		return if compact then default.phone else default.pc
	end
	return default == true
end

-- Whether section `id` stands open under the saved setting on this device (anything else than a table, or than a
-- boolean under the id, reads as no choice: the device's default).
function SectionFold.isOpen(saved: any, id: string, compact: boolean?): boolean
	local value = if type(saved) == "table" then saved[id] else nil
	if type(value) == "boolean" then
		return value
	end
	return SectionFold.default(id, compact)
end

-- A choice the setting need not keep: the default on both devices.
local function defaultEverywhere(id: string, open: boolean): boolean
	return SectionFold.default(id, false) == open and SectionFold.default(id, true) == open
end

-- A new setting with section `id` open or folded as the player chose on this device (`compact`). It keeps the least:
-- unknown ids, non-booleans and choices equal to the default on both devices drop out, the other sections keep their
-- saved choices (a default is never written in their place), and a choice that changes nothing on this device is not
-- stored, so opening on PC what PC opens anyway leaves the phone's default alone.
function SectionFold.with(saved: any, id: string, open: boolean, compact: boolean?): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for known in SectionFold.DEFAULTS do
		local value = if type(saved) == "table" then saved[known] else nil
		if known == id and SectionFold.isOpen(saved, id, compact) ~= open then
			value = open
		end
		if type(value) == "boolean" and not defaultEverywhere(known, value) then
			out[known] = value
		end
	end
	return out
end

-- Two settings open the same sections, on PC and on a phone.
function SectionFold.same(a: any, b: any): boolean
	for id in SectionFold.DEFAULTS do
		if
			SectionFold.isOpen(a, id, false) ~= SectionFold.isOpen(b, id, false)
			or SectionFold.isOpen(a, id, true) ~= SectionFold.isOpen(b, id, true)
		then
			return false
		end
	end
	return true
end

-- Server validator of the setting: a table of known section ids to booleans (a choice is one boolean on every device).
function SectionFold.valid(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for key, open in value do
		if type(key) ~= "string" or not SectionFold.known(key) or type(open) ~= "boolean" then
			return false
		end
	end
	return true
end

return SectionFold
