--!strict
-- Leak scanner of the wiki output (S34, docs/WIKI.md §1). scanKeys() runs in every build (keys that must never
-- appear: prices in Robux / Dragon Currency, product and pass ids); scan() also looks for secrets the caller passes
-- in (reward codes as whole words, administrator ids as whole numbers). Only tests/wikidump.spec loads the secrets
-- (Data/Codes, Config.AdminUserIds): the exporter never reads them.

local Leak = {}

Leak.FORBIDDEN_KEYS = { "productId", "passId", "robux", "price", "shards", "RespawnNowCost" }

local function sortedPaths(files: { [string]: string }): { string }
	local paths = {}
	for path in files do
		table.insert(paths, path)
	end
	table.sort(paths)
	return paths
end

local function escape(text: string): string
	return (string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Forbidden JSON keys ("price": ...) in any file.
function Leak.scanKeys(files: { [string]: string }): { string }
	local found = {}
	for _, path in sortedPaths(files) do
		local text = files[path]
		for _, key in Leak.FORBIDDEN_KEYS do
			if string.find(text, `"{key}"%s*:`) then
				table.insert(found, `{path}: key "{key}"`)
			end
		end
	end
	return found
end

-- Every problem: forbidden keys, `codes` as whole words (case-sensitive), `ids` as whole numbers.
function Leak.scan(files: { [string]: string }, secrets: { codes: { string }, ids: { number } }): { string }
	local found = Leak.scanKeys(files)
	for _, path in sortedPaths(files) do
		local text = files[path]
		for _, code in secrets.codes do
			if #code > 0 and string.find(text, "%f[%w_]" .. escape(code) .. "%f[^%w_]") then
				table.insert(found, `{path}: reward code {code}`)
			end
		end
		for _, id in secrets.ids do
			local digits = string.format("%d", id)
			if string.find(text, "%f[%d]" .. digits .. "%f[%D]") then
				table.insert(found, `{path}: administrator id {digits}`)
			end
		end
	end
	return found
end

return Leak
