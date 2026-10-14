--!strict
-- S52: files of the real art. assets/Weapons (weapon models saved from Studio as .rbxm, plus the local .glb sources
-- that git ignores) and art/icons/src (PNG sources of the picture atlases). Empty folders pass; a bad file is a
-- readable error, never a silent skip. The model validator is a pure function, checked on models that went through
-- serializeModel -> deserializeModel (old property names such as Decal.Texture only fail after that trip).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Atlas = require("../src/shared/Data/ItemIconAtlas")
local ItemIcons = require("../src/shared/Logic/ItemIcons")
local Items = require("../src/shared/Data/Items")
local Sheets = require("../src/shared/Data/ItemIconSheets")
local T = require("./Test")
local WeaponLooks = require("../src/shared/Data/WeaponLooks")

local MAX_PARTS = 12
local MODELS: { [string]: boolean } = {}
for _, asset in WeaponLooks.assets do
	MODELS[asset.model] = true
end

local function textureOf(inst: any): (boolean, string?)
	local ok, content = pcall(function()
		return inst.TextureContent
	end)
	if not ok then
		return false, nil
	end
	return true, if content and content.Uri ~= "" then content.Uri else nil
end

-- Problems of the instances of one .rbxm file (roots as deserializeModel returns them).
local function validate(roots: { any }): { string }
	local errors = {}
	local weapons: { any } = {}
	for _, root in roots do
		if root.ClassName == "Folder" then
			for _, child in root:GetChildren() do
				table.insert(weapons, child)
			end
		else
			table.insert(weapons, root)
		end
		local all = root:GetDescendants()
		table.insert(all, root)
		for _, inst in all do
			if inst:IsA("LuaSourceContainer") then
				table.insert(errors, `{inst:GetFullName()}: skrypt ({inst.ClassName}) jest zakazany`)
			elseif inst:IsA("Sound") then
				table.insert(errors, `{inst:GetFullName()}: dźwięk jest zakazany`)
			elseif inst:IsA("Decal") or inst:IsA("Texture") then
				local readable, uri = textureOf(inst)
				if not readable then
					table.insert(errors, `{inst:GetFullName()}: nie da się odczytać tekstury {inst.ClassName}`)
				elseif uri then
					table.insert(errors, `{inst:GetFullName()}: {inst.ClassName} z zewnętrznym id {uri}`)
				end
			end
		end
	end
	if #weapons == 0 then
		table.insert(errors, "brak modelu")
	end
	for _, weapon in weapons do
		if not MODELS[weapon.Name] then
			table.insert(errors, `{weapon.Name}: nazwa spoza WeaponLooks.assets (model = ...)`)
		end
		local parts = if weapon:IsA("BasePart") then 1 else 0
		for _, inst in weapon:GetDescendants() do
			if inst:IsA("BasePart") then
				parts += 1
			end
		end
		if parts == 0 then
			table.insert(errors, `{weapon.Name}: brak części (MeshPart)`)
		elseif parts > MAX_PARTS then
			table.insert(errors, `{weapon.Name}: {parts} części, najwyżej {MAX_PARTS}`)
		end
	end
	return errors
end

local function roundTrip(roots: { any }): { any }
	return roblox.deserializeModel(roblox.serializeModel(roots))
end

local function meshPart(name: string): any
	local part = roblox.Instance.new("MeshPart")
	part.Name = name
	part.Size = roblox.Vector3.new(0.3, 1, 0.2)
	roblox.Instance.new("SurfaceAppearance").Parent = part
	return part
end

-- Errors of every file under assets/Weapons (recursively; sub-folders need init.meta.json like the root).
local function scanWeapons(dir: string, errors: { string })
	if not fs.isDir(dir) then
		return
	end
	local names = fs.readDir(dir)
	if dir ~= "assets/Weapons" and not table.find(names, "init.meta.json") then
		table.insert(errors, `{dir}: brak init.meta.json (ignoreUnknownInstances)`)
	end
	for _, name in names do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			scanWeapons(path, errors)
		elseif name == "init.meta.json" or name == ".gitkeep" or string.match(name, "%.glb$") then
			continue -- .glb = local source for Import 3D (git ignores it)
		elseif string.match(name, "%.rbxm$") then
			local ok, roots = pcall(roblox.deserializeModel, fs.readFile(path))
			if not ok then
				table.insert(errors, `{path}: nie da się odczytać pliku .rbxm`)
				continue
			end
			for _, e in validate(roots) do
				table.insert(errors, `{path}: {e}`)
			end
		else
			table.insert(errors, `{path}: nieznany plik (dozwolone .rbxm z Studio i źródła .glb; nie .rbxmx)`)
		end
	end
end

-- Width and height of a PNG from its IHDR chunk, or nil when the file is not a PNG.
local function pngSize(path: string): (number?, number?)
	local data = fs.readFile(path)
	if string.sub(data, 1, 8) ~= "\137PNG\r\n\26\n" or string.sub(data, 13, 16) ~= "IHDR" then
		return nil, nil
	end
	return string.unpack(">I4I4", data, 17)
end

T.describe("Art files (S52)", function()
	T.it("the model validator rejects scripts, sounds, decals with ids and unknown names", function()
		T.expect(#validate(roundTrip({ meshPart("sword1h_1") }))).toBe(0)
		local pack = roblox.Instance.new("Folder")
		meshPart("sword1h_1").Parent = pack
		meshPart("bow_5").Parent = pack
		T.expect(#validate(roundTrip({ pack }))).toBe(0)
		local scripted = meshPart("sword1h_1")
		roblox.Instance.new("Script").Parent = scripted
		T.expect(#validate(roundTrip({ scripted }))).toBe(1)
		local loud = meshPart("sword1h_1")
		roblox.Instance.new("Sound").Parent = loud
		T.expect(#validate(roundTrip({ loud }))).toBe(1)
		local decal = meshPart("sword1h_1")
		local d = roblox.Instance.new("Decal")
		d.Texture = "rbxassetid://123"
		d.Parent = decal
		T.expect(#validate(roundTrip({ decal }))).toBe(1)
		local plain = meshPart("sword1h_1")
		roblox.Instance.new("Decal").Parent = plain
		T.expect(#validate(roundTrip({ plain }))).toBe(0)
		T.expect(#validate(roundTrip({ meshPart("sword9") }))).toBe(1)
		local empty = roblox.Instance.new("Model")
		empty.Name = "sword1h_1"
		T.expect(#validate(roundTrip({ empty }))).toBe(1)
	end)

	T.it("assets/Weapons holds only valid models and their sources", function()
		local errors = {}
		scanWeapons("assets/Weapons", errors)
		T.expect(table.concat(errors, "\n")).toBe("")
	end)

	T.it("art/icons/src: known keys, real PNGs of a usable size, all packed", function()
		local errors = {}
		local seen: { [string]: boolean } = {}
		local root = "art/icons/src"
		for _, group in (if fs.isDir(root) then fs.readDir(root) else {}) :: { string } do
			local dir = `{root}/{group}`
			if not fs.isDir(dir) then
				if group ~= "README.md" and group ~= ".gitkeep" then
					table.insert(errors, `{dir}: plik poza folderem grupy`)
				end
				continue
			end
			for _, name in fs.readDir(dir) do
				if name == ".gitkeep" or name == "README.md" then
					continue
				end
				local base, tier = string.match(name, "^([%a][%w_]*)@?(%d*)%.[ma]%.png$")
				if not base then
					base, tier = string.match(name, "^([%a][%w_]*)@?(%d*)%.png$")
				end
				if not base then
					table.insert(errors, `{dir}/{name}: zła nazwa`)
					continue
				end
				local key = `{group}/{base}` .. (if tier ~= "" then `@{tier}` else "")
				seen[key] = true
				if not Atlas.PNG[key] then
					table.insert(errors, `{dir}/{name}: brak w atlasie (uruchom py -3 tools/icons/import_png.py)`)
				end
				local w, h = pngSize(`{dir}/{name}`)
				if not w or not h then
					table.insert(errors, `{dir}/{name}: to nie jest PNG`)
				elseif not (w == Atlas.CELL and h == Atlas.CELL) and math.min(w, h) < 256 then
					table.insert(errors, `{dir}/{name}: {w}x{h} px (potrzeba boku >= 256 albo dokładnie {Atlas.CELL})`)
				end
			end
		end
		for key in Atlas.PNG do
			if not seen[key] then
				table.insert(errors, `{key}: w atlasie, ale bez pliku w {root} (uruchom packer)`)
			end
		end
		table.sort(errors)
		T.expect(table.concat(errors, "\n")).toBe("")
	end)

	T.it("every picture key is used by some item (or is a UI picture)", function()
		local used: { [string]: boolean } = {}
		for _, def in Items.byId do
			for _, c in ItemIcons.candidates(def) do
				used[c.key] = true
			end
		end
		local unused = {}
		-- S118: quest objective items ("quest/<item>") are not items; tests/itemicons checks their texts.
		for key in Atlas.PNG do
			local quest = string.sub(key, 1, 6) == "quest/"
			if not used[key] and not quest and not (string.sub(key, 1, 3) == "ui/" and Atlas.ICONS[key]) then
				table.insert(unused, key)
			end
		end
		table.sort(unused)
		T.expect(table.concat(unused, ", ")).toBe("")
	end)

	T.it("one id line and one 1024 px atlas file per sheet", function()
		T.expect(#Sheets).toBe(Atlas.SHEETS)
		T.expect(Atlas.SVG_SHEETS <= Atlas.SHEETS).toBe(true)
		for n = 1, Atlas.SHEETS do
			local w, h = pngSize(`art/icons/items_{n}.png`)
			T.expect(w == 1024 and h == 1024).toBe(true)
		end
		for _, icon in Atlas.PNG do
			for _, layer in icon.layers do
				T.expect(layer.s > Atlas.SVG_SHEETS and layer.s <= Atlas.SHEETS).toBe(true)
			end
		end
	end)
end)
