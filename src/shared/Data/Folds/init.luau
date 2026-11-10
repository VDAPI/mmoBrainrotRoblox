--!strict
-- Fold defaults of the interface (owner 2026-11-10: "a lot of text, some things cover others, too detailed
-- descriptions, nothing can be collapsed"; docs/UI-ZASADY.md §4): every collapsible section's id and whether it stands
-- open by default, one file per area, so the HUD, the item windows and the world windows each edit only their own
-- file. Logic/SectionFold merges the areas in this order and raises an error on an id found in two of them: the
-- account keeps one choice per id, so two windows sharing an id would fold together.
-- A default is a boolean (every device) or { pc = boolean, phone = boolean }: "phone" is the phone layout
-- (UI/PhoneLayout.Compact: touch on a short screen), "pc" everything else, tablets included.

local Gear = require("@self/Gear")
local Hud = require("@self/Hud")
local Menu = require("@self/Menu")
local World = require("@self/World")

export type Default = boolean | { pc: boolean, phone: boolean }
export type Area = { name: string, folds: { [string]: Default } }

return table.freeze({
	{ name = "Hud", folds = Hud },
	{ name = "Gear", folds = Gear },
	{ name = "World", folds = World },
	{ name = "Menu", folds = Menu },
} :: { Area })
