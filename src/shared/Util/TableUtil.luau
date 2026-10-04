--!strict
-- Generic table helpers. Pure Luau.

local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[TableUtil.deepCopy(k)] = TableUtil.deepCopy(v)
	end
	return (copy :: any) :: T
end

function TableUtil.deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not TableUtil.deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- Returns a new table: shallow merge of `base` with `overrides` (overrides win).
function TableUtil.merge<T>(base: T, overrides: any): T
	local result = table.clone(base :: any)
	for k, v in overrides do
		result[k] = v
	end
	return result :: any
end

-- Fills keys missing in `target` with deep copies from `template` (recursively for nested tables).
-- Mutates and returns `target`. Used to reconcile saved data with newer templates.
function TableUtil.reconcile<T>(target: any, template: T): T
	for k, v in template :: any do
		if target[k] == nil then
			target[k] = TableUtil.deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil then
			TableUtil.reconcile(target[k], v)
		end
	end
	return target
end

function TableUtil.keys<K>(tbl: { [K]: any }): { K }
	local result = {}
	for k in tbl do
		table.insert(result, k)
	end
	return result
end

function TableUtil.count(tbl: { [any]: any }): number
	local n = 0
	for _ in tbl do
		n += 1
	end
	return n
end

return TableUtil
