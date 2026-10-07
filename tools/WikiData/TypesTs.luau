--!strict
-- wiki/src/data/types.ts from the schema (S34): one interface per record, literal unions for the small sets taken
-- from the game data (rarity keys, elements, classes, slots, categories), one type per file and the Files map.

local Schema = require("./Schema")

local TypesTs = {}

TypesTs.HEADER = "// GENEROWANE przez tools/wikidump.luau — nie edytuj (zmiany: tools/WikiData/Schema i buildery).\n"

local function tsName(field: string): string
	if string.match(field, "^[%a_$][%w_$]*$") then
		return field
	end
	return '"' .. field .. '"'
end

local function tsType(t: Schema.T): string
	if type(t) == "string" then
		if t == "int" or t == "number" then
			return "number"
		elseif t == "bool" then
			return "boolean"
		elseif t == "name" then
			return "Name"
		elseif t == "data" then
			return "Json"
		end
		return "string"
	end
	local kind = (t :: any).kind
	if kind == "array" then
		local inner = tsType((t :: any).of)
		if string.find(inner, "[|&]") then
			inner = `({inner})`
		end
		return inner .. "[]"
	elseif kind == "map" then
		return `Record<string, {tsType((t :: any).of)}>`
	elseif kind == "record" then
		return (t :: any).name
	elseif kind == "enum" then
		return if Schema.enumValues((t :: any).name) then (t :: any).name else "string"
	end
	return "unknown"
end

local function refComment(t: Schema.T): string
	if type(t) == "string" and string.sub(t, 1, 4) == "ref:" then
		return ` // id in {string.sub(t, 5)}.json`
	end
	if type(t) == "table" and (t :: any).kind == "array" then
		local inner = (t :: any).of
		if type(inner) == "string" and string.sub(inner, 1, 4) == "ref:" then
			return ` // ids in {string.sub(inner, 5)}.json`
		end
	end
	return ""
end

local function sortedKeys(t: { [string]: any }): { string }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

function TypesTs.generate(): string
	local out = { TypesTs.HEADER }
	table.insert(out, "export type Name = { pl: string; en: string };")
	table.insert(out, "export type Json = string | number | boolean | null | Json[] | { [key: string]: Json };")
	table.insert(out, "")
	-- Enums used by the records.
	local enumNames: { [string]: boolean } = {}
	local records = Schema.records()
	for _, record in records do
		for _, field in Schema.fields(record) do
			local t: any = field.t
			while type(t) == "table" and (t.kind == "array" or t.kind == "map") do
				t = t.of
			end
			if type(t) == "table" and t.kind == "enum" and Schema.enumValues(t.name) then
				enumNames[t.name] = true
			end
		end
	end
	for _, name in sortedKeys(enumNames) do
		local values = {}
		for _, v in Schema.enumValues(name) :: { string } do
			table.insert(values, `"{v}"`)
		end
		table.insert(out, `export type {name} = {table.concat(values, " | ")};`)
	end
	table.insert(out, "")
	for _, name in sortedKeys(records) do
		table.insert(out, `export interface {name} \{`)
		for _, field in Schema.fields(records[name]) do
			local optional = if field.optional then "?" else ""
			table.insert(out, `  {tsName(field.name)}{optional}: {tsType(field.t)};{refComment(field.t)}`)
		end
		table.insert(out, "}")
		table.insert(out, "")
	end
	table.insert(out, "/** Every data file in wiki/src/data by name (<name>.json). */")
	table.insert(out, "export interface Files {")
	for _, file in sortedKeys(Schema.files) do
		table.insert(out, `  {tsName(file)}: {tsType(Schema.files[file])};`)
	end
	table.insert(out, "}")
	return table.concat(out, "\n") .. "\n"
end

-- Markdown table of the files for docs/WIKI.md §5: file -> top-level fields.
function TypesTs.markdown(): string
	local lines = { "| Plik | Pola najwyższego poziomu |", "|---|---|" }
	for _, file in sortedKeys(Schema.files) do
		local fields = {}
		for _, field in Schema.fields(Schema.files[file]) do
			table.insert(fields, `\`{field.name}\`: {tsType(field.t)}`)
		end
		table.insert(lines, `| \`{file}.json\` | {table.concat(fields, ", ")} |`)
	end
	return table.concat(lines, "\n")
end

return TypesTs
