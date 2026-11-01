--!strict
-- Catalog clothing 2026-11-01 (docs/WYGLAD-KLAS.md §3): the dev try-on of catalog items on the live character. Pure
-- (Lune): the parser of /trylook (Admin/Character), the body parts of a bundle (AssetService:GetBundleDetailsAsync
-- Items) and the text of a trial. CosmeticService keeps the trial per player and Logic/CharacterLook.resolve puts it over
-- the look. Every refusal is a key "admin.trylook.<why>" (PL and EN).
--   /trylook <id>[:<Type>[:<Order>]] ... [-<garment>] [-all] [-hair]   items over the look (layered when the type is)
--   /trylook body <name> | <bundle id> | [<head>] <torso> <leftArm> <rightArm> <leftLeg> <rightLeg> | off
--   /trylook clear                                                       the normal look again
--   /trylook                                                             what is tried now

local BodyLooks = require("../Data/BodyLooks")
local CharacterLook = require("./CharacterLook")

local TryLook = {}

export type Parsed = {
	kind: "show" | "clear" | "items" | "body",
	-- kind "items": the trial's items and what it takes off (replaces the tried items, keeps a tried body)
	pieces: { CharacterLook.CatalogPiece }?,
	hide: { string }?,
	bare: boolean?,
	hideHair: boolean?,
	-- kind "body": the parts (nil with no bundle = the game's own body again); `bundle` = a bundle the server still
	-- looks up (bodyFromBundle)
	body: { [string]: number }?,
	bundle: number?,
}

-- Body part fields of the five ids after `body` (the head stays the face's), and of six (the head first).
local FIVE = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }

-- An id typed in the chat: digits only (at most 19, an int64), above 0.
local function id(text: string): number?
	if not string.match(text, "^%d+$") or #text > 19 then
		return nil
	end
	local n = tonumber(text)
	return if n and n > 0 then n else nil
end

local function parseBody(args: { string }): (Parsed?, string?, { [string]: any }?)
	local rest = table.move(args, 2, #args, 1, {})
	if #rest == 1 then
		local word = string.lower(rest[1])
		if word == "off" then
			return { kind = "body" }, nil, nil
		end
		local preset = BodyLooks.trialBodies[word]
		if preset then
			if preset.bundle == BodyLooks.bundle then
				return { kind = "body" }, nil, nil -- the game's own body
			elseif preset.parts then
				return { kind = "body", body = table.clone(preset.parts) }, nil, nil
			end
			return { kind = "body", bundle = preset.bundle }, nil, nil
		end
		local bundle = id(rest[1])
		if bundle then
			return { kind = "body", bundle = bundle }, nil, nil
		end
		return nil, "admin.trylook.body", { value = rest[1] }
	end
	if #rest ~= 5 and #rest ~= 6 then
		return nil, "admin.trylook.body", { value = table.concat(rest, " ") }
	end
	local fields: { string } = if #rest == 6 then { "Head", table.unpack(FIVE) } else FIVE
	local body: { [string]: number } = {}
	for i, field in fields do
		local n = id(rest[i])
		if not n then
			return nil, "admin.trylook.body", { value = rest[i] }
		end
		body[field] = n
	end
	return { kind = "body", body = body }, nil, nil
end

-- (parsed, errorKey, errorArgs) for the arguments of /trylook.
function TryLook.parse(args: { string }): (Parsed?, string?, { [string]: any }?)
	local first = args[1]
	if first == nil then
		return { kind = "show" }, nil, nil
	end
	local word = string.lower(first)
	if word == "clear" then
		if #args > 1 then
			return nil, "admin.usage.trylook", nil
		end
		return { kind = "clear" }, nil, nil
	elseif word == "body" then
		return parseBody(args)
	end
	local pieces: { CharacterLook.CatalogPiece } = {}
	local hide: { string } = {}
	local out: Parsed = { kind = "items", pieces = pieces, hide = hide }
	for _, token in args do
		local name = string.match(token, "^%-(.+)$")
		if name then
			local lower = string.lower(name)
			if lower == "all" then
				out.bare = true
			elseif lower == "hair" then
				out.hideHair = true
			elseif CharacterLook.GARMENTS[lower] then
				table.insert(hide, lower)
			else
				return nil, "admin.trylook.garment", { name = name }
			end
		else
			local parts = string.split(token, ":")
			local n = id(parts[1])
			if not n or #parts > 3 then
				return nil, "admin.trylook.id", { value = token }
			end
			local typeName: string? = nil
			if parts[2] ~= nil then
				typeName = CharacterLook.catalogType(parts[2])
				if not typeName then
					return nil, "admin.trylook.type", { value = parts[2] }
				end
			end
			local order: number? = nil
			if parts[3] ~= nil then
				order = if string.match(parts[3], "^%d+$") and #parts[3] <= 3 then tonumber(parts[3]) else nil
				if order == nil then
					return nil, "admin.trylook.order", { value = parts[3] }
				end
			end
			table.insert(pieces, CharacterLook.catalogPiece(n, typeName, order) :: CharacterLook.CatalogPiece)
		end
	end
	return out, nil, nil
end

-- Bundle item types (Enum.AvatarAssetType names, GetBundleDetailsAsync Items[].AssetType) -> body part fields; the
-- head is left out (the face's head stays: Data/BodyLooks.heads are the heads of these bundles).
local BUNDLE_PARTS: { [string]: string } = {
	Torso = "Torso",
	LeftArm = "LeftArm",
	RightArm = "RightArm",
	LeftLeg = "LeftLeg",
	RightLeg = "RightLeg",
}

-- The body parts in a bundle's items, nil when it has none.
function TryLook.bodyFromBundle(items: any): { [string]: number }?
	if type(items) ~= "table" then
		return nil
	end
	local body: { [string]: number } = {}
	local found = false
	for _, item in items do
		local field = if type(item) == "table" and type(item.AssetType) == "string"
			then BUNDLE_PARTS[item.AssetType]
			else nil
		local n = if field and type(item.Id) == "number" and item.Id > 0 then item.Id else nil
		if field and n then
			body[field] = n
			found = true
		end
	end
	return if found then body else nil
end

-- The trial after a parsed "items" or "body" call on `trial` (the other half kept), nil when nothing is left.
function TryLook.merge(trial: CharacterLook.Trial?, parsed: Parsed): CharacterLook.Trial?
	local out: CharacterLook.Trial = if trial then table.clone(trial) else {}
	if parsed.kind == "body" then
		out.body = if parsed.body then table.clone(parsed.body) else nil
	elseif parsed.kind == "items" then
		out.pieces = if parsed.pieces and #parsed.pieces > 0 then parsed.pieces else nil
		out.hide = if parsed.hide and #parsed.hide > 0 then parsed.hide else nil
		out.bare = if parsed.bare then true else nil
		out.hideHair = if parsed.hideHair then true else nil
	end
	if out.pieces == nil and out.hide == nil and out.bare == nil and out.hideHair == nil and out.body == nil then
		return nil
	end
	return out
end

-- A short text of a trial for the chat ("" = nothing tried): items (id:Type@order), what is off, the body.
function TryLook.describe(trial: CharacterLook.Trial?): string
	if not trial then
		return ""
	end
	local parts: { string } = {}
	local items = {}
	for _, piece in (trial.pieces or {}) :: { CharacterLook.CatalogPiece } do
		table.insert(
			items,
			if piece.layered then `{piece.id}:{piece.type}@{piece.order}` else `{piece.id}:{piece.type}`
		)
	end
	if #items > 0 then
		table.insert(parts, table.concat(items, " "))
	end
	local off = table.clone(trial.hide or {})
	if trial.bare then
		table.insert(off, 1, "all")
	end
	if trial.hideHair then
		table.insert(off, "hair")
	end
	if #off > 0 then
		table.insert(parts, `-{table.concat(off, " -")}`)
	end
	if trial.body then
		local ids = {}
		for _, field in BodyLooks.PART_FIELDS do
			local n = trial.body[field]
			if n then
				table.insert(ids, `{field}={n}`)
			end
		end
		table.insert(parts, `body {table.concat(ids, " ")}`)
	end
	return table.concat(parts, "; ")
end

return TryLook
