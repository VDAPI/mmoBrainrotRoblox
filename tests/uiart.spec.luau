--!strict
-- S119: interface pictures. The generated registry (Data/UiArt) only holds keys the game can ask for, its cells and
-- files are consistent with art/ui and the id file (Data/UiArtSheets), the key functions of Logic/UiArt, the glyph
-- fallback, painted map frames, and every ArtIcon in the client keeps today's glyph (`Glyph = ...`).
local fs = require("@lune/fs")

local Npcs = require("../src/shared/Data/Npcs")
local Registry = require("../src/shared/Data/UiArt")
local Sheets = require("../src/shared/Data/UiArtSheets")
local T = require("./Test")
local UiArt = require("../src/shared/Logic/UiArt")
local UiArtKeys = require("../src/shared/Logic/UiArtKeys")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local CATEGORY_OF_ATLAS: { [string]: { [string]: boolean } } = {
	skills = { skills = true },
	status = { status = true },
	emblems = { emblems = true },
	hud = { hud = true },
	map = { map = true },
	shop = { shop = true },
}
local SINGLE_CATEGORIES: { [string]: { w: number, h: number } } = {
	portrait = { w = 512, h = 768 },
	boss = { w = 512, h = 512 },
	dungeon = { w = 1024, h = 512 },
	painted = { w = 1024, h = 1024 },
}

-- Width and height of a PNG (IHDR) or a baseline / progressive JPEG (SOF0..SOF2), nil for anything else.
local function imageSize(path: string): (number?, number?)
	local data = fs.readFile(path)
	if string.sub(data, 1, 8) == "\137PNG\r\n\26\n" and string.sub(data, 13, 16) == "IHDR" then
		return string.unpack(">I4I4", data, 17)
	end
	if string.byte(data, 1) ~= 0xFF or string.byte(data, 2) ~= 0xD8 then
		return nil, nil
	end
	local i = 3
	while i < #data do
		if string.byte(data, i) ~= 0xFF then
			return nil, nil
		end
		local marker = string.byte(data, i + 1)
		local len = string.unpack(">I2", data, i + 2)
		if marker >= 0xC0 and marker <= 0xC2 then
			local h, w = string.unpack(">I2I2", data, i + 5)
			return w, h
		end
		i += 2 + len
	end
	return nil, nil
end

local function pathOf(file: string): string
	return if string.sub(file, -4) == ".jpg" then `art/ui/single/{file}` else `art/ui/{file}`
end

T.describe("UiArt registry (S119)", function()
	T.it("every key is a key the game asks for, in the category of its atlas or single kind", function()
		local all = UiArtKeys.all()
		for key, cell in Registry.ICONS do
			local cat = all[key]
			T.expect(cat ~= nil and CATEGORY_OF_ATLAS[cell.atlas] ~= nil and CATEGORY_OF_ATLAS[cell.atlas][cat] == true)
				.toBe(true)
		end
		for key, single in Registry.SINGLES do
			local cat = all[key]
			local size = if cat then SINGLE_CATEGORIES[cat] else nil
			if not size then
				error(`{key}: not a single picture key of the game`)
			end
			T.expect(single.w).toBe(size.w)
			T.expect(single.h).toBe(size.h)
		end
	end)

	T.it("effect keys come from effect.<kind> texts in both languages", function()
		local ids = UiArtKeys.ids()
		T.expect(#ids.effects > 20).toBe(true)
		for _, kind in ids.effects do
			T.expect(type((pl :: any)[`effect.{kind}`])).toBe("string")
			T.expect(type((en :: any)[`effect.{kind}`])).toBe("string")
		end
		T.expect(table.find(ids.effects, "withValue")).toBeNil()
	end)

	T.it("cells sit on the grid of their sheet without overlaps", function()
		local used: { [string]: string } = {}
		for key, cell in Registry.ICONS do
			T.expect(cell.x % Registry.CELL).toBe(0)
			T.expect(cell.y % Registry.CELL).toBe(0)
			T.expect(cell.x >= 0 and cell.x <= 1024 - Registry.CELL and cell.y >= 0 and cell.y <= 1024 - Registry.CELL)
				.toBe(true)
			local files = Registry.ATLASES[cell.atlas]
			T.expect(files ~= nil and files[cell.s] ~= nil).toBe(true)
			local slot = `{cell.atlas}:{cell.s}:{cell.x}:{cell.y}`
			if used[slot] then
				error(`{key} and {used[slot]} share {slot}`)
			end
			used[slot] = key
		end
	end)

	T.it("every file has an id row (empty or rbxassetid) and exists in art/ui with its size", function()
		local files: { [string]: boolean } = {}
		for _, list in Registry.ATLASES do
			for _, file in list do
				files[file] = true
				T.expect(Sheets[file] ~= nil).toBe(true)
				local w, h = imageSize(pathOf(file))
				T.expect(w).toBe(1024)
				T.expect(h).toBe(1024)
			end
		end
		for key, single in Registry.SINGLES do
			files[single.file] = true
			T.expect(Sheets[single.file] ~= nil).toBe(true)
			local w, h = imageSize(pathOf(single.file))
			if w ~= single.w or h ~= single.h then
				error(`{key}: {pathOf(single.file)} is {w}x{h}, registry {single.w}x{single.h}`)
			end
		end
		for file, id in Sheets do
			T.expect(files[file]).toBe(true)
			T.expect(id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil).toBe(true)
		end
	end)
end)

T.describe("Logic/UiArt keys (S119)", function()
	T.it("builds the key of every category", function()
		T.expect(UiArt.skill("charge")).toBe("umiejetnosci/skill_charge")
		T.expect(UiArt.effect("stun")).toBe("efekty/effect_stun")
		T.expect(UiArt.element("fire")).toBe("zywioly/element_fire")
		T.expect(UiArt.profile("exp")).toBe("profile/profile_exp")
		T.expect(UiArt.guildSkill("luck")).toBe("gildia/guild_luck")
		T.expect(UiArt.classEmblem("Warrior")).toBe("klasy/class_warrior")
		T.expect(UiArt.classPortrait("Cleric")).toBe("klasy/portrait_cleric")
		T.expect(UiArt.title("wanderer")).toBe("tytuly/title_wanderer")
		T.expect(UiArt.menu("map")).toBe("hud/menu_map")
		T.expect(UiArt.hud("pvp")).toBe("hud/pvp")
		T.expect(UiArt.slot("ring2")).toBe("hud/slot_ring")
		T.expect(UiArt.slot("helmet")).toBe("hud/slot_helmet")
		T.expect(UiArt.mapIcon("node", "bush")).toBe("mapa/map_herb")
		T.expect(UiArt.mapIcon("node", "fishing")).toBe("mapa/map_fishing")
		T.expect(UiArt.mapIcon("node", nil)).toBe("mapa/map_vein")
		T.expect(UiArt.mapIcon("portal")).toBe("mapa/map_portal")
		T.expect(UiArt.mapIcon("lair")).toBe("mapa/map_lair") -- S134i: Elite II hideouts
		T.expect(UiArt.service("shop")).toBe("mapa/service_shop")
		T.expect(UiArt.mark("flag")).toBe("mapa/mark_flag")
		T.expect(UiArt.map("meadows")).toBe("mapy/meadows")
		T.expect(UiArt.shop("vip")).toBe("sklep/pass_vip")
		T.expect(UiArt.shop("shards_100")).toBe("sklep/shards_100")
		T.expect(UiArt.shop("respawn")).toBe("sklep/respawn")
		T.expect(UiArt.cosmetic("pet_fox")).toBe("kosmetyki/pet_fox")
		T.expect(UiArt.boss("grimrok")).toBe("bossowie/boss_grimrok")
		T.expect(UiArt.dungeon("azgor")).toBe("lochy/dungeon_azgor")
	end)

	T.it("an NPC's icon is its first service besides talk, else the plain NPC", function()
		T.expect(UiArt.serviceOfNpc({ services = { "talk", "mounts" } })).toBe("mapa/service_mounts")
		T.expect(UiArt.serviceOfNpc({ services = { "shop", "heal" } })).toBe("mapa/service_shop")
		T.expect(UiArt.serviceOfNpc({ services = { "story" } })).toBe("mapa/service_story")
		T.expect(UiArt.serviceOfNpc({ services = { "talk" } })).toBe("mapa/map_npc")
		T.expect(UiArt.serviceOfNpc({ services = {} })).toBe("mapa/map_npc")
		for _, npc in Npcs.list do
			T.expect(string.sub(UiArt.serviceOfNpc(npc), 1, 5)).toBe("mapa/")
		end
	end)

	T.it("the menu ids match the HUD menu of ScreenController", function()
		local source = fs.readFile("src/client/Controllers/ScreenController.luau")
		local block = string.match(source, "local MENU: [^\n]*\n(.-)\n}") or ""
		local found = {}
		for id in string.gmatch(block, '%f[%w]id = "([%w_]+)"') do
			table.insert(found, id)
		end
		table.sort(found)
		local menus = table.clone(UiArt.MENUS)
		table.sort(menus)
		T.expect(found).toEqual(menus)
	end)

	T.it("falls back to glyphs without a cell or an id", function()
		T.expect(UiArt.idOf("ui_skills_01.png", {})).toBeNil()
		T.expect(UiArt.idOf("ui_skills_01.png", { ["ui_skills_01.png"] = "" })).toBeNil()
		T.expect(UiArt.idOf("x.png", { ["x.png"] = "rbxassetid://5" })).toBe("rbxassetid://5")
		T.expect(UiArt.cell("umiejetnosci/skill_doesNotExist")).toBeNil()
		T.expect(UiArt.fileOf("umiejetnosci/skill_doesNotExist")).toBeNil()
		T.expect(UiArt.STYLE.hud.tint).toBe(true)
		T.expect(UiArt.STYLE.map.tint).toBe(true)
		T.expect(UiArt.STYLE.skills.tint).toBe(false)
		T.expect(UiArt.tinted("umiejetnosci/skill_doesNotExist")).toBe(false)
		for key in Registry.ICONS do
			T.expect(UiArt.fileOf(key) ~= nil).toBe(true)
		end
	end)

	T.it("every painted map has a frame around the sketch centre", function()
		for key in Registry.SINGLES do
			local mapId = string.match(key, "^mapy/(.+)$")
			if mapId and mapId ~= "world" then
				local frame = UiArt.mapFrame(mapId)
				if not frame then
					error(`{key}: no MAP_FRAMES entry`)
				end
				T.expect(frame.size > 0).toBe(true)
				T.expect(frame.x0 < 0 and frame.x0 + frame.size > 0).toBe(true)
				T.expect(frame.z0 < 0 and frame.z0 + frame.size > 0).toBe(true)
			end
		end
	end)
end)

T.describe("ArtIcon fallback (S119)", function()
	T.it("every ArtIcon(...) call in the client gives its glyph", function()
		local missing = {}
		local function scan(dir: string)
			for _, name in fs.readDir(dir) do
				local path = `{dir}/{name}`
				if fs.isDir(path) then
					scan(path)
				elseif string.sub(name, -6) == ".luau" and name ~= "ArtIcon.luau" then
					local source = fs.readFile(path)
					local pos = 1
					while true do
						local s, e = string.find(source, "%f[%w%.]ArtIcon%(", pos)
						if not s then
							break
						end
						-- The props table of the call: up to the matching ")" of a balanced scan.
						local depth, i = 1, e + 1
						while depth > 0 and i <= #source do
							local c = string.sub(source, i, i)
							if c == "(" then
								depth += 1
							elseif c == ")" then
								depth -= 1
							end
							i += 1
						end
						local call = string.sub(source, e, i)
						if not string.find(call, "Glyph%s*=") then
							local line = select(2, string.gsub(string.sub(source, 1, s), "\n", "")) + 1
							table.insert(missing, `{path}:{line}`)
						end
						pos = i
					end
				end
			end
		end
		scan("src/client")
		if #missing > 0 then
			error(`ArtIcon without Glyph: {table.concat(missing, ", ")}`)
		end
	end)
end)
